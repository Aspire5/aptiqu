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
    const now = new Date();
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
    console.log('[DailyStreakCron] Running midnight IST streak evaluation and maintenance...');
    try {
      const { todayDate, yesterdayDate } = this.getIstDates();

      // 1. Reset streak to 0 for users who did not complete yesterday's daily challenge
      // In IST, at 00:00 IST todayDate, users whose lastDailyDate is NOT yesterdayDate missed it.
      const resetResult = await prisma.gameStats.updateMany({
        where: {
          streak: { gte: 1 },
          NOT: {
            lastDailyDate: yesterdayDate,
          },
        },
        data: {
          streak: 0,
        },
      });

      console.log(
        `[DailyStreakCron] Reset streak to 0 for ${resetResult.count} users who missed the daily challenge on ${yesterdayDate}.`
      );

      // Expire any incomplete daily challenge participations from previous days
      await prisma.dailyChallengeParticipation.updateMany({
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
        prisma.gameStats.count({
          where: { streak: { gte: 0, lte: 9 } },
        }),
        prisma.gameStats.count({
          where: { streak: { gte: 10, lte: 99 } },
        }),
        prisma.gameStats.count({
          where: { streak: { gte: 100 } },
        }),
      ]);

      console.log(
        `[DailyStreakCron] User tier distribution for ${todayDate}: Tier 1 (0-9)=${tier1Users}, Tier 2 (10-99)=${tier2Users}, Tier 3 (100+)=${tier3Users}`
      );

      // 3. Lazy-generate scripts only if active users exist in that tier (to avoid unnecessary AI API calls)
      if (tier1Users > 0) {
        console.log(`[DailyStreakCron] Pre-generating Tier 1 Daily Script for ${todayDate}...`);
        try {
          await dailyChallengeGenerationService.getOrGenerateDailyScript(todayDate, 1);
        } catch (err) {
          console.error(`[DailyStreakCron] Error generating Tier 1 script:`, err);
        }
      }

      if (tier2Users > 0) {
        console.log(`[DailyStreakCron] Pre-generating Tier 2 Daily Script for ${todayDate}...`);
        try {
          await dailyChallengeGenerationService.getOrGenerateDailyScript(todayDate, 2);
        } catch (err) {
          console.error(`[DailyStreakCron] Error generating Tier 2 script:`, err);
        }
      }

      if (tier3Users > 0) {
        console.log(`[DailyStreakCron] Pre-generating Tier 3 Daily Script for ${todayDate}...`);
        try {
          await dailyChallengeGenerationService.getOrGenerateDailyScript(todayDate, 3);
        } catch (err) {
          console.error(`[DailyStreakCron] Error generating Tier 3 script:`, err);
        }
      } else {
        console.log(`[DailyStreakCron] 0 users in Tier 3 (100+ streak). Skipping Tier 3 script generation to save AI API costs.`);
      }

      console.log(`[DailyStreakCron] Completed midnight IST challenge rollover successfully.`);
    } catch (error) {
      console.error('[DailyStreakCron] Error during midnight IST cron execution:', error);
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
  public async syncUserStreak(userId: string) {
    const { todayDate, yesterdayDate, msUntilMidnight, expiresAt } = this.getIstDates();

    let stats = await prisma.gameStats.findUnique({
      where: { userId },
    });

    if (!stats) {
      stats = await prisma.gameStats.create({
        data: {
          userId,
          streak: 0,
          highestStreak: 0,
          coins: 0,
        },
      });
    }

    const todayParticipation = await prisma.dailyChallengeParticipation.findUnique({
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
        stats = await prisma.gameStats.update({
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
    const todayParticipation = await prisma.dailyChallengeParticipation.findUnique({
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
    const sync = await this.syncUserStreak(userId);

    // If already completed today, block starting a new one
    if (sync.isCompletedToday) {
      throw new Error('Daily Challenge already completed for today. Come back tomorrow!');
    }

    // Check if an existing participation is already in progress
    let participation = await prisma.dailyChallengeParticipation.findUnique({
      where: {
        userId_dateString: {
          userId,
          dateString: sync.todayDate,
        },
      },
      include: {
        script: {
          include: {
            questions: {
              include: { question: true },
              orderBy: { sequence: 'asc' },
            },
          },
        },
        answers: {
          orderBy: { sequence: 'asc' },
        },
      },
    });

    if (participation && participation.status !== 'IN_PROGRESS') {
      throw new Error('Daily Challenge already attempted for today. Come back tomorrow!');
    }

    if (!participation) {
      // 1. Fetch today's pre-warmed tier script from DB (never block user HTTP request on Gemini)
      const script = await prisma.dailyChallengeScript.findUnique({
        where: {
          dateString_tier: {
            dateString: sync.todayDate,
            tier: sync.tierInfo.tier,
          },
        },
        include: {
          questions: {
            include: { question: true },
            orderBy: { sequence: 'asc' },
          },
        },
      });

      if (!script) {
        // Enqueue emergency background generation without blocking user HTTP request
        contentGenQueue.add('prewarm-daily-challenge', { targetDate: sync.todayDate }, {
          jobId: `emergency:daily:${sync.todayDate}`,
          removeOnComplete: true,
        }).catch((err) => {
          console.warn('[DailyChallenge] Failed to enqueue emergency prewarm job:', err);
        });

        const err: any = new Error(
          "Today's Daily Challenge is currently being prepared. Please check back in a few minutes."
        );
        err.statusCode = 503;
        err.code = 'DAILY_CHALLENGE_PREPARING';
        throw err;
      }

      // 2. Create participation record
      participation = await prisma.dailyChallengeParticipation.create({
        data: {
          userId,
          scriptId: script.id,
          dateString: sync.todayDate,
          status: 'IN_PROGRESS',
          totalQuestions: script.questionCount,
          streakAtAttempt: sync.currentStreak,
        },
        include: {
          script: {
            include: {
              questions: {
                include: { question: true },
                orderBy: { sequence: 'asc' },
              },
            },
          },
          answers: {
            orderBy: { sequence: 'asc' },
          },
        },
      });
    }

    // Sanitize questions: strip out correctAnswer, hints, explanation for unanswered questions
    const answeredMap = new Map(participation.answers.map((a) => [a.questionId, a]));

    const sanitizedQuestions = participation.script.questions.map((sq) => {
      const answer = answeredMap.get(sq.questionId);
      const isAnswered = !!answer;

      return {
        sequence: sq.sequence,
        difficulty: sq.difficulty,
        timeLimit: sq.timeLimit,
        isAnswered,
        userSelectedOptionId: answer?.selectedOptionId,
        isCorrect: answer?.isCorrect,
        responseTimeMs: answer?.responseTimeMs,
        question: {
          id: sq.question.id,
          prompt: sq.question.prompt,
          options: sq.question.options,
          difficulty: sq.question.difficulty,
          estimatedTimeSeconds: 60,
          calculationMode: sq.question.calculationMode,
          pyq: sq.question.pyq,
          // Exclude hints strictly for daily challenge!
          hints: [],
          // Reveal explanation and answer only if already answered
          correctAnswer: isAnswered ? sq.question.correctAnswer : undefined,
          explanation: isAnswered ? sq.question.explanation : undefined,
          method: isAnswered ? sq.question.method : undefined,
          alternativeExplanation: isAnswered ? sq.question.alternativeExplanation : undefined,
          preferredSolution: isAnswered ? sq.question.preferredSolution : undefined,
          preferredReason: isAnswered ? sq.question.preferredReason : undefined,
        },
      };
    });

    return {
      participationId: participation.id,
      dateString: participation.dateString,
      status: participation.status,
      currentStreak: sync.currentStreak,
      tier: sync.tierInfo.tier,
      totalQuestions: participation.totalQuestions,
      timeLimitPerQuestion: 60,
      questions: sanitizedQuestions,
    };
  }

  /**
   * Submits an answer for a specific question in the Daily Challenge.
   */
  public async submitAnswer(params: {
    userId: string;
    participationId: string;
    questionId: string;
    selectedOptionId: string;
    responseTimeMs: number;
  }) {
    const { userId, participationId, questionId, selectedOptionId, responseTimeMs } = params;

    const participation = await prisma.dailyChallengeParticipation.findFirst({
      where: { id: participationId, userId },
      include: {
        script: {
          include: {
            questions: {
              include: { question: true },
              orderBy: { sequence: 'asc' },
            },
          },
        },
        answers: true,
      },
    });

    if (!participation) {
      throw new Error(`Daily Challenge participation "${participationId}" not found.`);
    }

    if (participation.status !== 'IN_PROGRESS') {
      throw new Error(`Daily Challenge is already ${participation.status}. Answers closed.`);
    }

    const scriptQuestion = participation.script.questions.find(
      (sq) => sq.questionId === questionId
    );
    if (!scriptQuestion) {
      throw new Error(`Question "${questionId}" does not belong to this Daily Challenge.`);
    }

    const alreadyAnswered = participation.answers.some((a) => a.questionId === questionId);
    if (alreadyAnswered) {
      throw new Error(`Question "${questionId}" has already been answered.`);
    }

    const question = scriptQuestion.question;
    const isCorrect =
      selectedOptionId.trim().toUpperCase() === question.correctAnswer.trim().toUpperCase();

    return await prisma.$transaction(async (tx) => {
      // 1. Record Answer
      await tx.dailyChallengeAnswer.create({
        data: {
          participationId: participation.id,
          questionId,
          sequence: scriptQuestion.sequence,
          selectedOptionId: selectedOptionId.trim().toUpperCase(),
          isCorrect,
          responseTimeMs,
        },
      });

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
              lastDailyCompletedAt: new Date(),
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
              completedAt: new Date(),
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
              completedAt: new Date(),
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

      return {
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
    });
  }

  /**
   * Retrieves paginated history of daily challenge attempts for user.
   */
  public async getHistory(userId: string, page = 1, limit = 10) {
    const skip = (page - 1) * limit;

    const [items, totalCount, stats] = await Promise.all([
      prisma.dailyChallengeParticipation.findMany({
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
      prisma.dailyChallengeParticipation.count({ where: { userId } }),
      prisma.gameStats.findUnique({ where: { userId } }),
    ]);

    // Calculate overall average solve time across completed attempts
    const completedAttempts = await prisma.dailyChallengeParticipation.findMany({
      where: { userId, status: 'COMPLETED' },
      select: { avgTimeMs: true },
    });

    const overallAvgTimeMs =
      completedAttempts.length > 0
        ? Math.round(
            completedAttempts.reduce((sum, a) => sum + a.avgTimeMs, 0) / completedAttempts.length
          )
        : 0;

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
        totalCompleted: completedAttempts.length,
        overallAvgTimeMs,
      },
    };
  }
}

export const dailyChallengeService = DailyChallengeService.getInstance();
