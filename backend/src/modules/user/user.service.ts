import { prisma } from '../../config/prisma';
import { xpService } from '../xp/xp.service';

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

    const xpProgress = await xpService.getUserProgress(userId);

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
      // NOTE: Streak is hardcoded to 0 for now as requested. Daily streak calculation logic will be handled later.
      streak: `${user.gameStats?.streak ?? 0}d`,
      // NOTE: Coins is hardcoded to 0 for now as requested. Coin rewards logic will be handled later.
      coins: user.gameStats?.coins ?? 0,
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
    if (UserService.questionsCache && now - UserService.questionsCache.timestamp < 300000) {
      return UserService.questionsCache;
    }

    const versions = await prisma.lessonScriptVersion.findMany({
      where: { status: 'PUBLISHED' },
      select: { definition: true },
    });

    const map = new Map<string, 'EASY' | 'MEDIUM' | 'HARD'>();
    let easy = 0, medium = 0, hard = 0;

    for (const v of versions) {
      const def = v.definition as any;
      if (def && def.nodes) {
        for (const [nodeId, node] of Object.entries(def.nodes) as [string, any][]) {
          if (node.type === 'QUESTION' || node.questionReference) {
            const rawDiff = (node.questionReference?.inlineData?.difficulty || node.difficulty || 'EASY').toUpperCase();
            const diff = rawDiff.includes('HARD') ? 'HARD' : rawDiff.includes('MED') ? 'MEDIUM' : 'EASY';
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
   * Calculates curriculum topic completion and questions solved by difficulty.
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

    // 2. Questions solved by difficulty
    const { map, totals } = await this.getQuestionTotals();

    const correctAttempts = await prisma.questionAttempt.findMany({
      where: { userId, isCorrect: true },
      select: { nodeId: true },
    });

    const solvedNodeIds = new Set(correctAttempts.map((a) => a.nodeId).filter(Boolean));

    let solvedEasy = 0, solvedMedium = 0, solvedHard = 0;
    for (const nodeId of solvedNodeIds) {
      const diff = map.get(nodeId) || 'EASY';
      if (diff === 'HARD') solvedHard++;
      else if (diff === 'MEDIUM') solvedMedium++;
      else solvedEasy++;
    }

    return {
      topics: {
        completed: completedTopicIds.size,
        total: totalTopics,
      },
      questions: {
        easy: { solved: solvedEasy, total: totals.easy },
        medium: { solved: solvedMedium, total: totals.medium },
        hard: { solved: solvedHard, total: totals.hard },
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

