import { prisma } from '../../config/prisma';

export class AdminDashboardService {
  /**
   * Fetches high-level SaaS overview stats
   */
  public static async getOverviewStats() {
    const now = new Date();
    const twentyFourHoursAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    const todayString = now.toISOString().slice(0, 10);

    // 1. Total users registered
    const totalUsers = await prisma.user.count();

    // 2. Active users in last 24h
    // Users who registered or had session/game activity in the last 24 hours
    const activeUsers24h = await prisma.user.count({
      where: {
        OR: [
          { updatedAt: { gte: twentyFourHoursAgo } },
          { lessonSessions: { some: { startedAt: { gte: twentyFourHoursAgo } } } },
          { practiceSessions: { some: { createdAt: { gte: twentyFourHoursAgo } } } },
          { pvpMatchParticipations: { some: { joinedAt: { gte: twentyFourHoursAgo } } } },
          { dailyChallengeParticipations: { some: { startedAt: { gte: twentyFourHoursAgo } } } },
        ],
      },
    });

    // 3. Daily streak challenge today
    const [todayAttempts, todayPassed] = await Promise.all([
      prisma.dailyChallengeParticipation.count({
        where: { dateString: todayString },
      }),
      prisma.dailyChallengeParticipation.count({
        where: { dateString: todayString, status: 'COMPLETED' },
      }),
    ]);
    const todayPassRate = todayAttempts > 0 ? Math.round((todayPassed / todayAttempts) * 100) : 0;

    // 4. Activity counts
    const [
      pvpMatchesTotal,
      pvpMatchesCompleted,
      practiceSessionsTotal,
      scriptsCompleted,
      matchesReplayed,
      aiQuestionsCount,
      aiMessagesCount,
    ] = await Promise.all([
      prisma.pvpMatch.count(),
      prisma.pvpMatch.count({ where: { status: 'COMPLETED' } }),
      prisma.practiceSession.count(),
      prisma.lessonSession.count({ where: { status: 'COMPLETED' } }),
      prisma.practiceSession.count({ where: { isReplay: true } }),
      prisma.question.count({ where: { sourceType: 'AI_GENERATED' } }),
      prisma.aiMessage.count(),
    ]);

    return {
      totalUsers,
      activeUsers24h,
      dailyStreak: {
        dateString: todayString,
        attemptedCount: todayAttempts,
        passedCount: todayPassed,
        passRate: todayPassRate,
      },
      activity: {
        pvpMatchesPlayed: pvpMatchesTotal,
        pvpMatchesCompleted,
        practiceMatchesPlayed: practiceSessionsTotal,
        scriptsCompleted,
        matchesReplayed,
        aiQuestionsGenerated: aiQuestionsCount,
        aiApiCallsMade: aiMessagesCount + aiQuestionsCount, // conversations + question generations
      },
    };
  }

  /**
   * Generates user growth & activity trend data for:
   * - Daily (last 7 days)
   * - Weekly (last 4 weeks)
   * - Monthly (last 12 months)
   */
  public static async getUserGrowthTrends() {
    const now = new Date();

    // 1. Daily for 7 days
    const dailyData: Array<{ label: string; date: string; registered: number; active: number }> = [];
    for (let i = 6; i >= 0; i--) {
      const d = new Date(now);
      d.setDate(d.getDate() - i);
      const startOfDay = new Date(d.getFullYear(), d.getMonth(), d.getDate(), 0, 0, 0);
      const endOfDay = new Date(d.getFullYear(), d.getMonth(), d.getDate(), 23, 59, 59, 999);
      const dayLabel = startOfDay.toLocaleDateString('en-US', { weekday: 'short', month: 'numeric', day: 'numeric' });

      const [reg, act] = await Promise.all([
        prisma.user.count({
          where: {
            createdAt: { gte: startOfDay, lte: endOfDay },
          },
        }),
        prisma.user.count({
          where: {
            OR: [
              { createdAt: { gte: startOfDay, lte: endOfDay } },
              { updatedAt: { gte: startOfDay, lte: endOfDay } },
              { lessonSessions: { some: { startedAt: { gte: startOfDay, lte: endOfDay } } } },
              { practiceSessions: { some: { createdAt: { gte: startOfDay, lte: endOfDay } } } },
              { dailyChallengeParticipations: { some: { startedAt: { gte: startOfDay, lte: endOfDay } } } },
            ],
          },
        }),
      ]);

      dailyData.push({
        label: dayLabel,
        date: startOfDay.toISOString().slice(0, 10),
        registered: reg,
        active: act,
      });
    }

    // 2. Weekly for 4 weeks
    const weeklyData: Array<{ label: string; registered: number; active: number }> = [];
    for (let w = 3; w >= 0; w--) {
      const weekStart = new Date(now.getTime() - (w + 1) * 7 * 24 * 60 * 60 * 1000);
      const weekEnd = new Date(now.getTime() - w * 7 * 24 * 60 * 60 * 1000);
      const label = `Week ${4 - w}`;

      const [reg, act] = await Promise.all([
        prisma.user.count({
          where: { createdAt: { gte: weekStart, lt: weekEnd } },
        }),
        prisma.user.count({
          where: {
            OR: [
              { createdAt: { gte: weekStart, lt: weekEnd } },
              { updatedAt: { gte: weekStart, lt: weekEnd } },
            ],
          },
        }),
      ]);

      weeklyData.push({ label, registered: reg, active: act });
    }

    // 3. Monthly for 12 months
    const monthlyData: Array<{ label: string; registered: number; active: number }> = [];
    for (let m = 11; m >= 0; m--) {
      const targetMonth = new Date(now.getFullYear(), now.getMonth() - m, 1);
      const nextMonth = new Date(targetMonth.getFullYear(), targetMonth.getMonth() + 1, 1);
      const label = targetMonth.toLocaleDateString('en-US', { month: 'short', year: '2-digit' });

      const [reg, act] = await Promise.all([
        prisma.user.count({
          where: { createdAt: { gte: targetMonth, lt: nextMonth } },
        }),
        prisma.user.count({
          where: {
            OR: [
              { createdAt: { gte: targetMonth, lt: nextMonth } },
              { updatedAt: { gte: targetMonth, lt: nextMonth } },
            ],
          },
        }),
      ]);

      monthlyData.push({ label, registered: reg, active: act });
    }

    return {
      daily: dailyData,
      weekly: weeklyData,
      monthly: monthlyData,
    };
  }

  /**
   * Daily Streak Challenge historic performance table
   */
  public static async getDailyStreakHistory(limit = 14) {
    const participations = await prisma.dailyChallengeParticipation.findMany({
      orderBy: { startedAt: 'desc' },
      take: 500,
      include: {
        script: {
          select: { dateString: true, tier: true, questionCount: true },
        },
      },
    });

    const byDate = new Map<string, {
      dateString: string;
      title: string;
      tier: number;
      questionCount: number;
      totalAttempts: number;
      passedCount: number;
      failedCount: number;
      totalTimeMsSum: number;
    }>();

    for (const p of participations) {
      const existing = byDate.get(p.dateString) || {
        dateString: p.dateString,
        title: `Daily Challenge (${p.dateString})`,
        tier: p.script?.tier || 1,
        questionCount: p.script?.questionCount || p.totalQuestions || 1,
        totalAttempts: 0,
        passedCount: 0,
        failedCount: 0,
        totalTimeMsSum: 0,
      };

      existing.totalAttempts++;
      if (p.status === 'COMPLETED') {
        existing.passedCount++;
      } else {
        existing.failedCount++;
      }
      existing.totalTimeMsSum += p.totalTimeMs || 0;

      byDate.set(p.dateString, existing);
    }

    const history = Array.from(byDate.values())
      .slice(0, limit)
      .map((item) => {
        const passRate = item.totalAttempts > 0
          ? Math.round((item.passedCount / item.totalAttempts) * 100)
          : 0;
        const avgTimeSeconds = item.totalAttempts > 0
          ? Math.round(item.totalTimeMsSum / item.totalAttempts / 1000)
          : 0;

        let relativeDifficulty = 'NORMAL';
        if (passRate >= 75) relativeDifficulty = 'EASIER';
        else if (passRate < 45) relativeDifficulty = 'HARDER';

        return {
          dateString: item.dateString,
          title: item.title,
          tier: item.tier,
          questionCount: item.questionCount,
          totalAttempts: item.totalAttempts,
          passedCount: item.passedCount,
          failedCount: item.failedCount,
          passRate,
          avgTimeSeconds,
          relativeDifficulty,
        };
      });

    return history;
  }

  /**
   * Activity breakdown time-series (PvP, Practice, Scripts, Replays) for last 7 days
   */
  public static async getActivityTrends() {
    const now = new Date();
    const days: Array<{
      label: string;
      date: string;
      pvp: number;
      practice: number;
      scripts: number;
      replays: number;
    }> = [];

    for (let i = 6; i >= 0; i--) {
      const d = new Date(now);
      d.setDate(d.getDate() - i);
      const startOfDay = new Date(d.getFullYear(), d.getMonth(), d.getDate(), 0, 0, 0);
      const endOfDay = new Date(d.getFullYear(), d.getMonth(), d.getDate(), 23, 59, 59, 999);
      const label = startOfDay.toLocaleDateString('en-US', { weekday: 'short' });

      const [pvp, practice, scripts, replays] = await Promise.all([
        prisma.pvpMatch.count({
          where: { createdAt: { gte: startOfDay, lte: endOfDay } },
        }),
        prisma.practiceSession.count({
          where: { createdAt: { gte: startOfDay, lte: endOfDay } },
        }),
        prisma.lessonSession.count({
          where: { startedAt: { gte: startOfDay, lte: endOfDay }, status: 'COMPLETED' },
        }),
        prisma.practiceSession.count({
          where: { createdAt: { gte: startOfDay, lte: endOfDay }, isReplay: true },
        }),
      ]);

      days.push({
        label,
        date: startOfDay.toISOString().slice(0, 10),
        pvp,
        practice,
        scripts,
        replays,
      });
    }

    return days;
  }
}
