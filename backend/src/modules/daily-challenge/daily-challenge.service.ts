import { log, safeError } from '../../observability/logger';
import { Prisma, GameStats } from '@prisma/client';
import { PublicError } from '../../security/errors';
import { prisma } from '../../config/prisma';
import { dailyChallengeGenerationService } from '../ai/services/daily-challenge-generation.service';
import { XpService } from '../xp/xp.service';
import { contentGenQueue } from '../../queues/content-generation.queue';

export interface TierInfo {
  tier: number;
  questionCount: number;
  difficulties: ('EASY' | 'MEDIUM' | 'HARD')[];
  title: string;
}

export class DailyChallengeService {
  constructor(private readonly db = prisma, private readonly now: () => Date = () => new Date()) {}

  private static instance: DailyChallengeService;

  public static getInstance(): DailyChallengeService {
    if (!DailyChallengeService.instance) {
      DailyChallengeService.instance = new DailyChallengeService();
    }
    return DailyChallengeService.instance;
  }

  /**
   * Helper to format IST (Asia/Kolkata, UTC+5:30) dates as "YYYY-MM-DD".
   * Daily streak day cycle starts and ends at 12:00 AM IST sharp.
   */
  public getIstDates(): { todayDate: string; yesterdayDate: string; msUntilMidnight: number; expiresAt: string } {
    const now = this.now();
    // Using Intl.DateTimeFormat with Asia/Kolkata to ensure exact IST date regardless of host system timezone
    const formatter = new Intl.DateTimeFormat('en-CA', {
      timeZone: 'Asia/Kolkata',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    });
    const todayDate = formatter.format(now); // e.g. "2026-10-01"

    const yesterdayObj = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    const yesterdayDate = formatter.format(yesterdayObj);

    // Calculate next midnight in IST (12:00 AM IST = 18:30 UTC of previous day)
    const [y, m, d] = todayDate.split('-').map(Number);
    const nextDayDate = new Date(Date.UTC(y, m - 1, d + 1));
    const nextDayStr = formatter.format(nextDayDate);
    const nextMidnightIst = new Date(`${nextDayStr}T00:00:00+05:30`);
    const msUntilMidnight = Math.max(0, nextMidnightIst.getTime() - now.getTime());

    return { todayDate, yesterdayDate, msUntilMidnight, expiresAt: nextMidnightIst.toISOString() };
  }

  /**
   * Backward-compatible alias for getIstDates.
   */
  public getUtcDates(): { todayDate: string; yesterdayDate: string; msUntilMidnight: number; expiresAt: string } {
    return this.getIstDates();
  }

  /**
   * Cron job execution running daily at 12:00 AM sharp IST.
   * 1. Check and reset streak of all missed attempts for anyone where streak >= 1.
   * 2. Check user availability across tiers:
   *    - Tier 1 (0-9 streak): Generate 1 EASY question script (if users exist)
   *    - Tier 2 (10-99 streak): Generate 1 EASY + 1 MEDIUM question script (if users exist)
   *    - Tier 3 (100+ streak): Generate 1 EASY + 1 MEDIUM + 1 HARD question script (if users exist)
   * 3. Lazy-load and avoid unnecessary AI calls where tiers have no users.
   */
  public async runMidnightIstCron() {
    log('info','daily_challenge_service.runMidnightIstCron.info');
    try {
      const { todayDate, yesterdayDate } = this.getIstDates();

      // 1. Reset streak to 0 for users who did not complete yesterday's daily challenge
      // In IST, at 00:00 IST todayDate, users whose lastDailyDate is NOT yesterdayDate missed it.
      const resetResult = await this.db.gameStats.updateMany({
        where: {
          streak: { gte: 1 },
          NOT: {
            lastDailyDate: {in:[yesterdayDate,todayDate]},
          },
        },
        data: {
          streak: 0,
        },
      });

      log('info','daily_challenge_service.runMidnightIstCron.info');

      // Expire any incomplete daily challenge participations from previous days
      await this.db.dailyChallengeParticipation.updateMany({
        where: {
          status: 'IN_PROGRESS',
          dateString: { not: todayDate },
        },
        data: {
          status: 'FAILED',
        },
      });

      // 2. Check user distribution by streak tiers
      const [tier1Users, tier2Users, tier3Users] = await Promise.all([
        this.db.gameStats.count({
          where: { streak: { gte: 0, lte: 9 } },
        }),
        this.db.gameStats.count({
          where: { streak: { gte: 10, lte: 99 } },
        }),
        this.db.gameStats.count({
          where: { streak: { gte: 100 } },
        }),
      ]);

      log('info','daily_challenge_service.runMidnightIstCron.info');

      // 3. Lazy-generate scripts only if active users exist in that tier (to avoid unnecessary AI API calls)
      if (tier1Users > 0) {
        log('info','daily_challenge_service.runMidnightIstCron.info');
        try {
          await dailyChallengeGenerationService.getOrGenerateDailyScript(todayDate, 1);
        } catch (err) {
          log('error','daily_challenge_service.runMidnightIstCron.error',safeError(err));
        }
      }

      if (tier2Users > 0) {
        log('info','daily_challenge_service.runMidnightIstCron.info');
        try {
          await dailyChallengeGenerationService.getOrGenerateDailyScript(todayDate, 2);
        } catch (err) {
          log('error','daily_challenge_service.runMidnightIstCron.error',safeError(err));
        }
      }

      if (tier3Users > 0) {
        log('info','daily_challenge_service.runMidnightIstCron.info');
        try {
          await dailyChallengeGenerationService.getOrGenerateDailyScript(todayDate, 3);
        } catch (err) {
          log('error','daily_challenge_service.runMidnightIstCron.error',safeError(err));
        }
      } else {
        log('info','daily_challenge_service.runMidnightIstCron.info');
      }

      log('info','daily_challenge_service.runMidnightIstCron.info');
    } catch (error) {
      log('error','daily_challenge_service.runMidnightIstCron.error',safeError(error));
    }
  }

  /**
   * Resolves streak tier based on streak count:
   * Tier 1 (0 to 9 streak): 1 EASY question
   * Tier 2 (10 to 99 streak): 2 questions (1 EASY, 1 MEDIUM)
   * Tier 3 (100+ streak): 3 questions (1 EASY, 1 MEDIUM, 1 HARD)
   */
  public getTierInfo(streak: number): TierInfo {
    if (streak < 10) {
      return {
        tier: 1,
        questionCount: 1,
        difficulties: ['EASY'],
        title: 'Novice Duelist (Streak 0-9)',
      };
    } else if (streak < 100) {
      return {
        tier: 2,
        questionCount: 2,
        difficulties: ['EASY', 'MEDIUM'],
        title: 'Aptitude Veteran (Streak 10-99)',
      };
    } else {
      return {
        tier: 3,
        questionCount: 3,
        difficulties: ['EASY', 'MEDIUM', 'HARD'],
        title: 'Grandmaster (Streak 100+)',
      };
    }
  }

  /**
   * Authoritatively evaluates and synchronizes the user's streak status.
   * If user missed yesterday, streak resets to 0 (starting streak is 0).
   */
  public async syncUserStreak(userId: string, db?: Prisma.TransactionClient): Promise<{stats:GameStats;currentStreak:number;highestStreak:number;isCompletedToday:boolean;isDue:boolean;canAttempt:boolean;tierInfo:TierInfo;todayDate:string;msUntilMidnight:number;expiresAt:string}> {
    if (!db) return this.db.$transaction(async tx => {
      await XpService.getInstance().lockProgress(tx,userId);
      return this.syncUserStreak(userId,tx);
    });
    const { todayDate, yesterdayDate, msUntilMidnight, expiresAt } = this.getIstDates();

    let stats = await db.gameStats.findUnique({
      where: { userId },
    });

    if (!stats) {
      stats = await db.gameStats.create({
        data: {
          userId,
          streak: 0,
          highestStreak: 0,
          coins: 0,
        },
      });
    }

    const todayParticipation = await db.dailyChallengeParticipation.findUnique({
      where: {
        userId_dateString: {
          userId,
          dateString: todayDate,
        },
      },
      select: { status: true },
    });

    const hasFinishedToday =
      todayParticipation &&
      (todayParticipation.status === 'COMPLETED' ||
        todayParticipation.status === 'FAILED' ||
        todayParticipation.status === 'ABANDONED');

    let currentStreak = stats.streak;
    let isCompletedToday = stats.lastDailyDate === todayDate || todayParticipation?.status === 'COMPLETED';
    let isDue = false;
    let canAttempt = true;

    if (isCompletedToday || hasFinishedToday) {
      isDue = false;
      canAttempt = false;
    } else if (stats.lastDailyDate === yesterdayDate) {
      // Streak is actively intact from yesterday!
      isDue = true;
      canAttempt = true;
    } else if (stats.lastDailyDate === null) {
      // New user or never completed daily challenge
      currentStreak = 0;
      isDue = true;
      canAttempt = true;
    } else {
      // Missed yesterday! Streak is broken -> reset to 0
      if (stats.streak > 0) {
        stats = await db.gameStats.update({
          where: { userId },
          data: { streak: 0 },
        });
        currentStreak = 0;
      }
      isDue = true;
      canAttempt = true;
    }

    const tierInfo = this.getTierInfo(currentStreak);

    return {
      stats,
      currentStreak,
      highestStreak: stats.highestStreak,
      isCompletedToday,
      isDue,
      canAttempt,
      tierInfo,
      todayDate,
      msUntilMidnight,
      expiresAt,
    };
  }

  /**
   * Returns current Daily Challenge status, rules, and existing participation for today.
   */
  public async getStatus(userId: string) {
    const sync = await this.syncUserStreak(userId);
    const { msUntilMidnight, expiresAt } = this.getIstDates();

    // Check if user has an existing participation record for today
    const todayParticipation = await this.db.dailyChallengeParticipation.findUnique({
      where: {
        userId_dateString: {
          userId,
          dateString: sync.todayDate,
        },
      },
      include: {
        answers: {
          orderBy: { sequence: 'asc' },
        },
      },
    });

    const hasFinishedToday =
      todayParticipation &&
      (todayParticipation.status === 'COMPLETED' ||
        todayParticipation.status === 'FAILED' ||
        todayParticipation.status === 'ABANDONED');

    const canAttempt = !hasFinishedToday && sync.canAttempt;
    const isDue = !hasFinishedToday && sync.isDue;
    const isCompletedToday = sync.isCompletedToday || todayParticipation?.status === 'COMPLETED';

    return {
      streak: sync.currentStreak,
      highestStreak: sync.highestStreak,
      isDue,
      isCompletedToday,
      canAttempt,
      tier: sync.tierInfo.tier,
      tierTitle: sync.tierInfo.title,
      questionCount: sync.tierInfo.questionCount,
      difficulties: sync.tierInfo.difficulties,
      timeLimitPerQuestion: 60,
      hasHints: false,
      msUntilMidnight,
      expiresAt,
      todayParticipation: todayParticipation
        ? {
            id: todayParticipation.id,
            status: todayParticipation.status,
            correctCount: todayParticipation.correctCount,
            totalQuestions: todayParticipation.totalQuestions,
            totalTimeMs: todayParticipation.totalTimeMs,
            avgTimeMs: todayParticipation.avgTimeMs,
            xpAwarded: todayParticipation.xpAwarded,
            coinsAwarded: todayParticipation.coinsAwarded,
            completedAt: todayParticipation.completedAt,
          }
        : null,
    };
  }

  /**
   * Starts or resumes today's Daily Challenge for the user.
   * Lazily triggers AI generation if today's script for this tier does not exist yet.
   */
  public async startDailyChallenge(userId: string) {
    try {
      return await this.db.$transaction(async tx => {
        await XpService.getInstance().lockProgress(tx,userId);
        const sync = await this.syncUserStreak(userId,tx);
        const include = {script:{include:{questions:{include:{question:true},orderBy:{sequence:'asc' as const}}}},answers:{orderBy:{sequence:'asc' as const}}};
        let participation = await tx.dailyChallengeParticipation.findUnique({where:{userId_dateString:{userId,dateString:sync.todayDate}},include});
        if (participation && participation.status !== 'IN_PROGRESS' || !participation && !sync.canAttempt) throw new PublicError('Daily Challenge already attempted today','DAILY_CLOSED',409);
        if (!participation) {
          const script = await tx.dailyChallengeScript.findUnique({where:{dateString_tier:{dateString:sync.todayDate,tier:sync.tierInfo.tier}},include:{questions:{include:{question:{include:{subject:true,topic:true,subtopic:true}}}}}});
          if (!script) throw new PublicError("Today's Daily Challenge is being prepared. Please retry later.",'DAILY_CHALLENGE_PREPARING',503);
          if (script.questions.length !== script.questionCount || script.questions.some(({question:q}) => q.status !== 'PUBLISHED' || !q.subject.isActive || !q.topic.isActive || !q.subtopic.isActive)) throw new PublicError('Daily Challenge content is unavailable','DAILY_UNAVAILABLE',503);
          participation = await tx.dailyChallengeParticipation.create({data:{userId,scriptId:script.id,dateString:sync.todayDate,totalQuestions:script.questionCount,streakAtAttempt:sync.currentStreak},include});
        }
        const sequence = participation.answers.length + 1;
        const current = participation.script.questions.find(q => q.sequence === sequence);
        if (!current) throw new PublicError('Daily question unavailable','DAILY_UNAVAILABLE',503);
        if (!participation.questionStartedAt) {
          const startedAt = this.now();
          const deadline = new Date(Math.min(startedAt.getTime()+current.timeLimit*1000,new Date(sync.expiresAt).getTime()));
          participation = {...participation,...await tx.dailyChallengeParticipation.update({where:{id:participation.id},data:{questionStartedAt:startedAt,questionDeadline:deadline}})};
        }
        const answers = new Map(participation.answers.map(a => [a.sequence,a]));
        const questions = participation.script.questions.filter(q => q.sequence <= sequence).map(sq => {
          const answer = answers.get(sq.sequence);
          const q = sq.question;
          return {sequence:sq.sequence,difficulty:sq.difficulty,timeLimit:sq.timeLimit,isAnswered:!!answer,
            userSelectedOptionId:answer?.selectedOptionId,isCorrect:answer?.isCorrect,responseTimeMs:answer?.responseTimeMs,
            question:{id:q.id,prompt:q.prompt,options:Array.isArray(q.options) ? (q.options as any[]).map(o => ({id:o.id,text:o.text ?? o.label})) : [],difficulty:q.difficulty,estimatedTimeSeconds:sq.timeLimit,calculationMode:q.calculationMode,pyq:q.pyq,hints:[],
              ...(answer ? {correctAnswer:q.correctAnswer,explanation:q.explanation,method:q.method,alternativeExplanation:q.alternativeExplanation,preferredSolution:q.preferredSolution,preferredReason:q.preferredReason} : {})}};
        });
        return {participationId:participation.id,dateString:participation.dateString,status:participation.status,currentStreak:sync.currentStreak,tier:sync.tierInfo.tier,totalQuestions:participation.totalQuestions,timeLimitPerQuestion:60,
          serverNow:this.now().toISOString(),questionStartedAt:participation.questionStartedAt,questionDeadline:participation.questionDeadline,questions};
      });
    } catch (err) {
      if (err instanceof PublicError && err.code === 'DAILY_CHALLENGE_PREPARING') {
        const {todayDate} = this.getIstDates();
        void contentGenQueue.add('prewarm-daily-challenge',{targetDate:todayDate},{jobId:`emergency-daily-${todayDate}`,removeOnComplete:true}).catch(() => {});
      }
      throw err;
    }
  }

  /**
   * Submits an answer for a specific question in the Daily Challenge.
   */
  public async submitAnswer(params: {
    userId: string; participationId: string; questionId: string; selectedOptionId: string;
    responseTimeMs?: number; receivedAt?: Date;
  }) {
    const {userId,participationId,questionId} = params;
    const requestedOptionId = params.selectedOptionId.trim().toUpperCase();
    const receivedAt = params.receivedAt ?? this.now(); // Captured by HTTP ingress, never a body timestamp.
    return this.db.$transaction(async tx => {
      // Match all reward paths' progress -> stats order, and serialize today's starts and settlement.
      await XpService.getInstance().lockProgress(tx,userId);
      await tx.$queryRaw`SELECT id FROM learning.daily_challenge_participations WHERE id=${participationId}::uuid AND user_id=${userId}::uuid FOR UPDATE`;
      const participation = await tx.dailyChallengeParticipation.findFirst({where:{id:participationId,userId},include:{script:{include:{questions:{include:{question:true},orderBy:{sequence:'asc'}}}},answers:true}});
      if (!participation) throw new PublicError('Daily Challenge not found','NOT_FOUND',404);
      const previous = participation.answers.find(a => a.questionId === questionId);
      if (previous) {
        if (previous.requestedOptionId !== requestedOptionId) throw new PublicError('This question already has a different answer','ANSWER_CONFLICT',409);
        return previous.response;
      }
      if (participation.dateString !== this.getIstDates().todayDate || participation.dateString !== new Intl.DateTimeFormat('en-CA',{timeZone:'Asia/Kolkata',year:'numeric',month:'2-digit',day:'2-digit'}).format(receivedAt)) throw new PublicError('Daily Challenge day has ended','DAILY_EXPIRED',409);
      if (participation.status !== 'IN_PROGRESS') throw new PublicError('Daily Challenge is closed','DAILY_CLOSED',409);
      const scriptQuestion = participation.script.questions.find(q => q.questionId === questionId);
      if (!scriptQuestion || scriptQuestion.sequence !== participation.answers.length + 1) throw new PublicError('Answer the current question first','QUESTION_ORDER',409);
      const question = scriptQuestion.question;
      const options = Array.isArray(question.options) ? question.options as Array<any> : [];
      if (requestedOptionId !== 'TIMEOUT' && !options.some(o => typeof o.id === 'string' && o.id.toUpperCase() === requestedOptionId)) throw new PublicError('Invalid answer option','INVALID_OPTION');
      const startedAt = participation.questionStartedAt;
      const deadline = participation.questionDeadline;
      if (!startedAt || !deadline || receivedAt < startedAt) throw new PublicError('Start the current question first','QUESTION_NOT_STARTED',409);
      const expired = receivedAt.getTime() >= deadline.getTime();
      if (requestedOptionId === 'TIMEOUT' && !expired) throw new PublicError('Question has not expired','QUESTION_NOT_EXPIRED',409);
      const selectedOptionId = expired ? 'TIMEOUT' : requestedOptionId;
      const isCorrect = !expired && selectedOptionId === question.correctAnswer.trim().toUpperCase();
      // TODO: Server-measured Daily Challenge response times include network latency; consider latency fairness in a future competitive leaderboard revision.
      // Aggregate totalTimeMs is the sum of question durations; feedback/next-question delays are excluded.
      const responseTimeMs = Math.max(0,Math.min(receivedAt.getTime(),deadline.getTime())-startedAt.getTime());
      const accepted = await tx.dailyChallengeAnswer.create({data:{participationId,questionId,sequence:scriptQuestion.sequence,selectedOptionId,requestedOptionId,isCorrect,responseTimeMs,questionStartedAt:startedAt,questionDeadline:deadline,answeredAt:receivedAt,response:{}}});
      // 2. Fetch all answers for this participation
      const allAnswers = await tx.dailyChallengeAnswer.findMany({
        where: { participationId: participation.id },
      });

      const answeredCount = allAnswers.length;
      const isComplete = answeredCount === participation.totalQuestions;
      const correctCount = allAnswers.filter((a) => a.isCorrect).length;
      const totalTimeMs = allAnswers.reduce((sum, a) => sum + a.responseTimeMs, 0);
      const avgTimeMs = answeredCount > 0 ? Math.round(totalTimeMs / answeredCount) : 0;

      let streakResult = {
        streak: participation.streakAtAttempt,
        highestStreak: participation.streakAtAttempt,
        streakIncremented: false,
        xpAwarded: 0,
        coinsAwarded: 0,
      };

      if (isComplete) {
        // All reward transactions use progress -> stats lock order.
        await XpService.getInstance().lockProgress(tx, userId);
        const stats = await tx.gameStats.findUnique({
          where: { userId },
        });

        const isAllCorrect = correctCount === participation.totalQuestions;

        if (isAllCorrect) {
          // Success! User got ALL questions right in the challenge!
          const prevStreak = stats?.streak ?? 0;
          const newStreak = prevStreak + 1;
          const newHighestStreak = Math.max(stats?.highestStreak ?? 0, newStreak);

          // Coins: exactly 10x number of questions in challenge (1 -> 10, 3 -> 30)
          const totalCoins = participation.totalQuestions * 10;

          // XP: Base 50 + streak bonus (scaled with new streak)
          const baseXp = 50;
          const streakBonusXp = Math.min(newStreak * 10, 500);
          const totalXp = baseXp + streakBonusXp;

          // Update GameStats
          await tx.gameStats.update({
            where: { userId },
            data: {
              streak: newStreak,
              highestStreak: newHighestStreak,
              coins: { increment: totalCoins },
              lastDailyCompletedAt: receivedAt,
              lastDailyDate: participation.dateString,
            },
          });

          // Award XP authoritatively within parent transaction
          await XpService.getInstance().awardXp(
            {
              userId,
              amount: totalXp,
              sourceType: 'DAILY_CHALLENGE',
              sourceId: participation.id,
              idempotencyKey: `daily:challenge:${participation.id}`,
              description: `Completed Day ${newStreak} Daily Streak Challenge`,
            },
            tx
          );

          // Update participation
          await tx.dailyChallengeParticipation.update({
            where: { id: participation.id },
            data: {
              status: 'COMPLETED',
              correctCount,
              totalTimeMs,
              avgTimeMs,
              streakIncremented: true,
              xpAwarded: totalXp,
              coinsAwarded: totalCoins,
              completedAt: receivedAt,
            },
          });

          streakResult = {
            streak: newStreak,
            highestStreak: newHighestStreak,
            streakIncremented: true,
            xpAwarded: totalXp,
            coinsAwarded: totalCoins,
          };
        } else {
          // All or None: If user missed any question or timed out, streak resets to 0.
          // Zero XP, Zero Coins.
          await tx.gameStats.update({
            where: { userId },
            data: {
              streak: 0,
              lastDailyDate: participation.dateString,
            },
          });

          await tx.dailyChallengeParticipation.update({
            where: { id: participation.id },
            data: {
              status: 'FAILED',
              correctCount,
              totalTimeMs,
              avgTimeMs,
              streakIncremented: false,
              xpAwarded: 0,
              coinsAwarded: 0,
              completedAt: receivedAt,
            },
          });

          streakResult = {
            streak: 0,
            highestStreak: stats?.highestStreak ?? 0,
            streakIncremented: false,
            xpAwarded: 0,
            coinsAwarded: 0,
          };
        }
      } else {
        // Partially answered, update intermediate counts
        await tx.dailyChallengeParticipation.update({
          where: { id: participation.id },
          data: {
            correctCount,
            totalTimeMs,
            avgTimeMs,
          },
        });
      }

      const response = {
        responseTimeMs,
        isCorrect,
        correctAnswer: question.correctAnswer,
        explanation: question.explanation,
        method: question.method,
        alternativeExplanation: question.alternativeExplanation,
        preferredSolution: question.preferredSolution,
        preferredReason: question.preferredReason,
        sequence: scriptQuestion.sequence,
        isComplete,
        answeredCount,
        totalQuestions: participation.totalQuestions,
        correctCount,
        avgTimeMs,
        ...streakResult,
      };
      await tx.dailyChallengeAnswer.update({where:{id:accepted.id},data:{response:JSON.parse(JSON.stringify(response))}});
      await tx.dailyChallengeParticipation.update({where:{id:participation.id},data:{questionStartedAt:null,questionDeadline:null}});
      return response;
    });
  }

  /**
   * Retrieves paginated history of daily challenge attempts for user.
   */
  // CACHE_CANDIDATE ref=C11 scope=user layer=redis ttl=5-30s owner=daily
  public async getHistory(userId: string, page = 1, limit = 10) {
    const skip = (page - 1) * limit;

    const [items, totalCount, stats] = await Promise.all([
      this.db.dailyChallengeParticipation.findMany({
        where: { userId },
        skip,
        take: limit,
        orderBy: { startedAt: 'desc' },
        include: {
          answers: {
            orderBy: { sequence: 'asc' },
            include: {
              question: {
                select: {
                  prompt: true,
                  difficulty: true,
                },
              },
            },
          },
        },
      }),
      this.db.dailyChallengeParticipation.count({ where: { userId } }),
      this.db.gameStats.findUnique({ where: { userId } }),
    ]);

    // Calculate overall average solve time across completed attempts
    const completedAttempts = await this.db.dailyChallengeParticipation.aggregate({
      where:{userId,status:'COMPLETED'},_avg:{avgTimeMs:true},_count:{_all:true},
    });
    const overallAvgTimeMs=Math.round(completedAttempts._avg.avgTimeMs??0);

    return {
      history: items.map((p) => ({
        id: p.id,
        dateString: p.dateString,
        status: p.status,
        correctCount: p.correctCount,
        totalQuestions: p.totalQuestions,
        totalTimeMs: p.totalTimeMs,
        avgTimeMs: p.avgTimeMs,
        streakAtAttempt: p.streakAtAttempt,
        streakIncremented: p.streakIncremented,
        xpAwarded: p.xpAwarded,
        coinsAwarded: p.coinsAwarded,
        startedAt: p.startedAt,
        completedAt: p.completedAt,
        answers: p.answers.map((a) => ({
          sequence: a.sequence,
          isCorrect: a.isCorrect,
          responseTimeMs: a.responseTimeMs,
          questionPrompt: a.question.prompt,
          difficulty: a.question.difficulty,
        })),
      })),
      pagination: {
        page,
        limit,
        totalCount,
        totalPages: Math.ceil(totalCount / limit),
      },
      stats: {
        currentStreak: stats?.streak ?? 0,
        highestStreak: stats?.highestStreak ?? 0,
        totalCompleted: completedAttempts._count._all,
        overallAvgTimeMs,
      },
    };
  }
}

export const dailyChallengeService = DailyChallengeService.getInstance();
