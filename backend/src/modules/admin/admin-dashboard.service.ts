import { growthQuery, activityQuery } from './admin-analytics.queries';
import { dateKey } from '../home/home.metrics';
import { prisma } from '../../config/prisma';

export class AdminDashboardService {
  /**
   * Fetches high-level SaaS overview stats
   */
  public static async getOverviewStats() {
    const now = new Date();
    const twentyFourHoursAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    const todayString = dateKey(now);

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

    const dailyChallengeInventory = await AdminDashboardService.getDailyChallengeInventoryStatus();

    return {
      totalUsers,
      activeUsers24h,
      dailyStreak: {
        dateString: todayString,
        attemptedCount: todayAttempts,
        passedCount: todayPassed,
        passRate: todayPassRate,
      },
      dailyChallengeInventory,
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
    // CACHE CANDIDATE: short admin aggregate snapshot, keyed by IST day and report contract.
    const rows=await prisma.$queryRaw<Array<{kind:string;label:string;date:string;registered:number;active:number}>>(growthQuery());
    const group=(kind:string)=>rows.filter(row=>row.kind===kind).map(({label,date,registered,active})=>kind==='daily'?{label,date,registered,active}:{label,registered,active});
    return {daily:group('daily'),weekly:group('weekly'),monthly:group('monthly')};
  }

  /**
   * Daily Streak Challenge historic performance table
   */
  public static async getDailyStreakHistory(limit = 14) {
    const rows=await prisma.$queryRaw<Array<{dateString:string;tier:number;questionCount:number;totalAttempts:number;passedCount:number;failedCount:number;avgTimeSeconds:number}>>`
      SELECT p.date_string AS "dateString",max(s.tier)::int AS tier,max(p.total_questions)::int AS "questionCount",count(*)::int AS "totalAttempts",
        count(*) FILTER(WHERE p.status='COMPLETED')::int AS "passedCount",count(*) FILTER(WHERE p.status IN ('FAILED','ABANDONED'))::int AS "failedCount",
        COALESCE(round(avg(p.total_time_ms)/1000),0)::int AS "avgTimeSeconds"
      FROM learning.daily_challenge_participations p JOIN learning.daily_challenge_scripts s ON s.id=p.script_id
      GROUP BY p.date_string ORDER BY p.date_string DESC LIMIT ${Math.min(60,Math.max(1,limit))}`;
    return rows.map(row=>{const passRate=Math.round(row.passedCount/row.totalAttempts*100);return {...row,title:`Daily Challenge (${row.dateString})`,passRate,relativeDifficulty:passRate>=75?'EASIER':passRate<45?'HARDER':'NORMAL'};});
  }

  /**
   * Activity breakdown time-series (PvP, Practice, Scripts, Replays) for last 7 days
   */
  public static async getActivityTrends() {
    const rows=await prisma.$queryRaw<Array<{date:string;label:string;pvp:number;practice:number;scripts:number;replays:number}>>(activityQuery());
    return rows.map(row=>({...row,label:row.label.split(',')[0]}));
  }

  /**
   * Checks the remaining inventory of unused MANUAL PYQ questions available for Daily Challenges.
   * If any difficulty pool is exhausted (0) or low (< 5), flags an alert for the admin dashboard.
   */
  public static async getDailyChallengeInventoryStatus() {
    const [easyCount, mediumCount, hardCount] = await Promise.all([
      prisma.question.count({
        where: {
          sourceType: 'MANUAL',
          status: 'PUBLISHED',
          pyq: { not: null },
          difficulty: 'EASY',
          dailyChallengeScriptQuestions: { none: {} },
        },
      }),
      prisma.question.count({
        where: {
          sourceType: 'MANUAL',
          status: 'PUBLISHED',
          pyq: { not: null },
          difficulty: 'MEDIUM',
          dailyChallengeScriptQuestions: { none: {} },
        },
      }),
      prisma.question.count({
        where: {
          sourceType: 'MANUAL',
          status: 'PUBLISHED',
          pyq: { not: null },
          difficulty: 'HARD',
          dailyChallengeScriptQuestions: { none: {} },
        },
      }),
    ]);

    const isDepleted = easyCount === 0 || mediumCount === 0 || hardCount === 0;
    const isLow = easyCount < 5 || mediumCount < 5 || hardCount < 5;

    let status: 'CRITICAL' | 'WARNING' | 'HEALTHY' = 'HEALTHY';
    let alertMessage: string | null = null;

    if (isDepleted) {
      status = 'CRITICAL';
      const depletedDiffs = [
        ...(easyCount === 0 ? ['EASY'] : []),
        ...(mediumCount === 0 ? ['MEDIUM'] : []),
        ...(hardCount === 0 ? ['HARD'] : []),
      ];
      alertMessage = `CRITICAL: Manual PYQ inventory depleted for ${depletedDiffs.join(', ')}. Daily Challenge generation will halt until new manual PYQs are imported.`;
    } else if (isLow) {
      status = 'WARNING';
      alertMessage = `WARNING: Manual PYQ inventory is running low (EASY: ${easyCount}, MEDIUM: ${mediumCount}, HARD: ${hardCount}). Consider importing more manual PYQs.`;
    }

    return {
      status,
      isDepleted,
      isLow,
      alertMessage,
      counts: {
        EASY: easyCount,
        MEDIUM: mediumCount,
        HARD: hardCount,
        total: easyCount + mediumCount + hardCount,
      },
    };
  }
}

