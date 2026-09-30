import { prisma } from '../../config/prisma';
import { xpService } from '../xp/xp.service';
import { dailyChallengeService } from '../daily-challenge/daily-challenge.service';

export class UserService {
  /**
   * Retrieves user profile and gamification stats including XP and level progression.
   */
  async getProfile(userId: string) {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      include: {
        profile: true,
        gameStats: true,
      },
    });

    if (!user) {
      throw new Error('User not found');
    }

    const [xpProgress, streakSync] = await Promise.all([
      xpService.getUserProgress(userId),
      dailyChallengeService.syncUserStreak(userId),
    ]);

    return {
      id: user.id,
      email: user.email,
      isRegistrationComplete: user.isRegistrationComplete,
      firstName: user.profile?.firstName || '',
      lastName: user.profile?.lastName || '',
      dob: user.profile?.dob,
      gender: user.profile?.gender || '',
      religion: user.profile?.religion || '',
      country: user.profile?.country || '',
      avatarUrl: user.profile?.avatarUrl || '',
      // Gamification & XP stats
      level: xpProgress.level,
      totalXp: xpProgress.total,
      currentLevelStartXp: xpProgress.currentLevelStartXp,
      nextLevelStartXp: xpProgress.nextLevelStartXp,
      xpIntoCurrentLevel: xpProgress.xpIntoCurrentLevel,
      xpRequiredForNextLevel: xpProgress.xpRequiredForNextLevel,
      xpRemainingToNextLevel: xpProgress.xpRemainingToNextLevel,
      progress: xpProgress.progress,
      xp: xpProgress,
      streak: `${streakSync.currentStreak}d`,
      highestStreak: `${streakSync.highestStreak}d`,
      coins: streakSync.stats.coins,
      dailyChallengeDue: streakSync.isDue,
      dailyChallengeCompleted: streakSync.isCompletedToday,
      stats: await this.getUserStats(userId),
    };
  }

  /**
   * Cached curriculum questions map by nodeId.
   */
  private static questionsCache: {
    timestamp: number;
    map: Map<string, 'EASY' | 'MEDIUM' | 'HARD'>;
    totals: { easy: number; medium: number; hard: number };
  } | null = null;

  private async getQuestionTotals() {
    const now = Date.now();
    if (UserService.questionsCache && now - UserService.questionsCache.timestamp < 120000) {
      return UserService.questionsCache;
    }

    const map = new Map<string, 'EASY' | 'MEDIUM' | 'HARD'>();
    let easy = 0, medium = 0, hard = 0;

    // 1. All questions stored in the Question table (all banners: practice, script, daily challenge, pvp, admin)
    const dbQuestions = await prisma.question.findMany({
      where: { status: 'PUBLISHED' },
      select: { id: true, difficulty: true },
    });

    for (const q of dbQuestions) {
      const rawDiff = (q.difficulty || 'EASY').toUpperCase();
      const diff: 'EASY' | 'MEDIUM' | 'HARD' = rawDiff.includes('HARD')
        ? 'HARD'
        : rawDiff.includes('MED')
        ? 'MEDIUM'
        : 'EASY';
      map.set(q.id, diff);
      if (diff === 'HARD') hard++;
      else if (diff === 'MEDIUM') medium++;
      else easy++;
    }

    // 2. Published lesson script versions with inline question nodes that are NOT in prisma.question
    const versions = await prisma.lessonScriptVersion.findMany({
      where: { status: 'PUBLISHED' },
      select: { definition: true },
    });

    for (const v of versions) {
      const def = v.definition as any;
      if (def && def.nodes) {
        for (const [nodeId, node] of Object.entries(def.nodes) as [string, any][]) {
          if (node.type === 'QUESTION' || node.questionReference) {
            const refQuestionId = node.questionReference?.questionId;
            // If the node already references a questionId in the Question table, map nodeId -> that difficulty without incrementing total
            if (refQuestionId && map.has(refQuestionId)) {
              map.set(nodeId, map.get(refQuestionId)!);
              continue;
            }

            // If it's already mapped by nodeId, skip
            if (map.has(nodeId)) continue;

            const rawDiff = (
              node.questionReference?.inlineData?.difficulty ||
              node.difficulty ||
              'EASY'
            ).toUpperCase();
            const diff: 'EASY' | 'MEDIUM' | 'HARD' = rawDiff.includes('HARD')
              ? 'HARD'
              : rawDiff.includes('MED')
              ? 'MEDIUM'
              : 'EASY';
            map.set(nodeId, diff);
            if (diff === 'HARD') hard++;
            else if (diff === 'MEDIUM') medium++;
            else easy++;
          }
        }
      }
    }

    UserService.questionsCache = {
      timestamp: now,
      map,
      totals: { easy, medium, hard },
    };

    return UserService.questionsCache;
  }

  /**
   * Calculates curriculum topic completion and questions solved by difficulty across ALL banners.
   */
  async getUserStats(userId: string) {
    // 1. Unique topics across all roadmaps
    const allRoadmapSteps = await prisma.roadmapStep.findMany({
      where: { isRequired: true, isActive: true },
      select: { id: true, topicId: true },
    });

    const topicStepsMap = new Map<string, string[]>();
    for (const step of allRoadmapSteps) {
      const list = topicStepsMap.get(step.topicId) || [];
      list.push(step.id);
      topicStepsMap.set(step.topicId, list);
    }
    const totalTopics = topicStepsMap.size;

    const completedSteps = await prisma.userRoadmapStepProgress.findMany({
      where: { userId, status: 'COMPLETED' },
      select: { roadmapStepId: true },
    });
    const completedStepIdSet = new Set(completedSteps.map((s) => s.roadmapStepId));

    const completedTopicIds = new Set<string>();
    for (const [topicId, stepIds] of topicStepsMap.entries()) {
      if (stepIds.length > 0 && stepIds.every((id) => completedStepIdSet.has(id))) {
        completedTopicIds.add(topicId);
      }
    }

    // Also include topics rewarded via TOPIC_COMPLETION xp events
    const topicXpEvents = await prisma.xpEvent.findMany({
      where: { userId, sourceType: 'TOPIC_COMPLETION' },
      select: { topicId: true },
    });
    for (const ev of topicXpEvents) {
      if (ev.topicId) completedTopicIds.add(ev.topicId);
    }

    // 2. Questions solved by difficulty across ALL banners (scripts, practice, daily challenge, pvp)
    const { map, totals } = await this.getQuestionTotals();

    const [scriptAttempts, practiceAnswers, dailyAnswers, pvpAnswers, userProgress] =
      await Promise.all([
        // Banner 1: Interactive scripts
        prisma.questionAttempt.findMany({
          where: { userId, isCorrect: true },
          select: { questionId: true, nodeId: true },
        }),
        // Banner 2: Practice Sessions
        prisma.practiceSessionQuestion.findMany({
          where: { session: { userId }, isCorrect: true },
          select: { questionId: true },
        }),
        // Banner 3: Daily Challenge
        prisma.dailyChallengeAnswer.findMany({
          where: { participation: { userId }, isCorrect: true },
          select: { questionId: true },
        }),
        // Banner 4: Ranked PvP
        prisma.pvpMatchAnswer.findMany({
          where: { userId, isCorrect: true },
          select: { questionId: true },
        }),
        // Banner 5: User Question Progress (tracking practice/drills)
        prisma.userQuestionProgress.findMany({
          where: { userId, timesCorrect: { gt: 0 } },
          select: { questionId: true },
        }),
      ]);

    const solvedQuestionIds = new Set<string>();
    const solvedNodeIds = new Set<string>();

    for (const a of scriptAttempts) {
      if (a.questionId) solvedQuestionIds.add(a.questionId);
      if (a.nodeId) solvedNodeIds.add(a.nodeId);
    }
    for (const a of practiceAnswers) {
      if (a.questionId) solvedQuestionIds.add(a.questionId);
    }
    for (const a of dailyAnswers) {
      if (a.questionId) solvedQuestionIds.add(a.questionId);
    }
    for (const a of pvpAnswers) {
      if (a.questionId) solvedQuestionIds.add(a.questionId);
    }
    for (const a of userProgress) {
      if (a.questionId) solvedQuestionIds.add(a.questionId);
    }

    let solvedEasy = 0,
      solvedMedium = 0,
      solvedHard = 0;

    // Count solved DB questions
    for (const qId of solvedQuestionIds) {
      const diff = map.get(qId) || 'EASY';
      if (diff === 'HARD') solvedHard++;
      else if (diff === 'MEDIUM') solvedMedium++;
      else solvedEasy++;
    }

    // Count solved inline script nodes that aren't already covered by a questionId
    for (const nodeId of solvedNodeIds) {
      if (!solvedQuestionIds.has(nodeId) && map.has(nodeId)) {
        const diff = map.get(nodeId)!;
        if (diff === 'HARD') solvedHard++;
        else if (diff === 'MEDIUM') solvedMedium++;
        else solvedEasy++;
      }
    }

    const finalEasyTotal = Math.max(totals.easy, solvedEasy);
    const finalMediumTotal = Math.max(totals.medium, solvedMedium);
    const finalHardTotal = Math.max(totals.hard, solvedHard);

    return {
      topics: {
        completed: completedTopicIds.size,
        total: totalTopics,
      },
      questions: {
        easy: { solved: solvedEasy, total: finalEasyTotal },
        medium: { solved: solvedMedium, total: finalMediumTotal },
        hard: { solved: solvedHard, total: finalHardTotal },
      },
    };
  }

  /**
   * Retrieves standalone XP progression metrics.
   */
  async getProgress(userId: string) {
    return xpService.getUserProgress(userId);
  }
}

