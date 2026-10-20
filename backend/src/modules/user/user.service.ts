import { questionStatsQuery } from './user-stats.queries';
import { rankedQueryService } from '../pvp/ranked/ranked-query.service';
import { prisma } from '../../config/prisma';
import { xpService } from '../xp/xp.service';
import { dailyChallengeService } from '../daily-challenge/daily-challenge.service';

export class UserService {
  /**
   * Retrieves user profile and gamification stats including XP and level progression.
   */
  // CACHE_CANDIDATE ref=C07 scope=user layer=redis ttl=5-10s owner=stats
  async getProfile(userId: string, includeStats = true) {
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
      streak: streakSync.currentStreak,
      streakCount: streakSync.currentStreak,
      highestStreak: streakSync.highestStreak,
      coins: streakSync.stats.coins,
      dailyChallengeDue: streakSync.isDue,
      dailyChallengeCompleted: streakSync.isCompletedToday,
      dailyChallenge: {
        isAvailable: streakSync.canAttempt,
        isDue: streakSync.isDue,
        isCompletedToday: streakSync.isCompletedToday,
        streak: streakSync.currentStreak,
        tier: streakSync.tierInfo.tier,
        tierTitle: streakSync.tierInfo.title,
        questionCount: streakSync.tierInfo.questionCount,
        timeRemainingMs: streakSync.msUntilMidnight,
        expiresAt: streakSync.expiresAt,
      },
      rankedLeague: await rankedQueryService.compact(userId),
      stats: includeStats ? await this.getUserStats(userId) : undefined,
    };
  }

  /**
   * Calculates curriculum topic completion and questions solved by difficulty across ALL banners.
   */
  // CACHE_CANDIDATE ref=C09 scope=user layer=redis ttl=10-30s owner=stats
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
      distinct: ['topicId'],
    });
    for (const ev of topicXpEvents) {
      if (ev.topicId) completedTopicIds.add(ev.topicId);
    }

    const counts=await prisma.$queryRaw<Array<{kind:string;difficulty:string;count:number}>>(questionStatsQuery(userId));
    const value=(kind:string,difficulty:string)=>Number(counts.find(row=>row.kind===kind&&row.difficulty===difficulty)?.count??0);
    const solvedEasy=value('solved','EASY'),solvedMedium=value('solved','MEDIUM'),solvedHard=value('solved','HARD');
    const finalEasyTotal=Math.max(value('total','EASY'),solvedEasy);
    const finalMediumTotal=Math.max(value('total','MEDIUM'),solvedMedium);
    const finalHardTotal=Math.max(value('total','HARD'),solvedHard);

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
  // CACHE_CANDIDATE ref=C08 scope=user layer=redis ttl=5s owner=xp
  async getProgress(userId: string) {
    return xpService.getUserProgress(userId);
  }
}

