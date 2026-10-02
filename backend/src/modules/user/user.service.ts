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

    const [solvedCounts, distinctNodes] = await Promise.all([
      prisma.$queryRaw<Array<{ difficulty: string; count: number }>>`
        SELECT q.difficulty::text, COUNT(DISTINCT q.id)::int as count
        FROM learning.questions q
        WHERE q.id IN (
          SELECT question_id FROM learning.question_attempts WHERE user_id = ${userId}::uuid AND is_correct = true AND question_id IS NOT NULL
          UNION
          SELECT psq.question_id FROM learning.practice_session_questions psq JOIN learning.practice_sessions ps ON psq.session_id = ps.id WHERE ps.user_id = ${userId}::uuid AND psq.is_correct = true
          UNION
          SELECT dca.question_id FROM learning.daily_challenge_answers dca JOIN learning.daily_challenge_participations dcp ON dca.participation_id = dcp.id WHERE dcp.user_id = ${userId}::uuid AND dca.is_correct = true
          UNION
          SELECT question_id FROM learning.pvp_match_answers WHERE user_id = ${userId}::uuid AND is_correct = true
          UNION
          SELECT question_id FROM learning.user_question_progress WHERE user_id = ${userId}::uuid AND times_correct > 0
        )
        GROUP BY q.difficulty;
      `,
      prisma.$queryRaw<Array<{ node_id: string }>>`
        SELECT DISTINCT node_id FROM learning.question_attempts
        WHERE user_id = ${userId}::uuid AND is_correct = true AND node_id IS NOT NULL;
      `,
    ]);

    let solvedEasy = 0,
      solvedMedium = 0,
      solvedHard = 0;

    for (const row of solvedCounts) {
      if (row.difficulty === 'HARD') solvedHard = Number(row.count);
      else if (row.difficulty === 'MEDIUM') solvedMedium = Number(row.count);
      else solvedEasy = Number(row.count);
    }

    // Count solved inline script nodes that aren't database question records
    for (const row of distinctNodes) {
      if (row.node_id && map.has(row.node_id)) {
        const diff = map.get(row.node_id)!;
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

