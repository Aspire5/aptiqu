import { achievementFactsQuery, AchievementFacts, achievementOrder, liveAchievementWhere, presentAchievements } from '../achievements/achievement.service';
import { rankedQueryService } from '../pvp/ranked/ranked-query.service';
import { prisma } from '../../config/prisma';
import { yearCalendar, dateKey, performance } from './home.metrics';
import { homeStatsQuery, HomeStatsRow, latestHomeMatchQuery } from './home.queries';

export class HomeService {
  async getPublicProfileFacts(userId:string,now=new Date()) {
    const today=dateKey(now),start=`${today.slice(0,7)}-01`;
    const startUtc=new Date(`${start}T00:00:00+05:30`).toISOString();
    const endUtc=new Date(+new Date(`${today}T00:00:00+05:30`)+86400000).toISOString();
    const [stats,definitions,facts,lastMatch]=await prisma.$transaction([
      prisma.$queryRaw<HomeStatsRow[]>(homeStatsQuery(userId,startUtc,endUtc)),
      prisma.achievement.findMany({where:liveAchievementWhere,orderBy:achievementOrder,take:6}),
      prisma.$queryRaw<AchievementFacts[]>(achievementFactsQuery(userId,start,today)),
      prisma.$queryRaw<{result:string;correct:number;questions:number}[]>(latestHomeMatchQuery(userId)),
    ],{isolationLevel:'RepeatableRead'});
    const rows=stats.filter(row=>row.kind==='difficulty');
    const days=stats.filter(row=>row.kind==='day'&&row.date).map(row=>({date:row.date!,attempted:row.attempted,correct:row.correct}));
    return {today,performance:performance(rows),difficulty:rows.map(row=>({difficulty:row.difficulty,...performance([row])})),
      activity:yearCalendar(today,days).filter(day=>day.date.startsWith(today.slice(0,7))).map(day=>({...day,dailyChallengeCompleted:facts[0].dailyDates.includes(day.date)})),
      badges:presentAchievements(definitions,stats,facts[0]),ranked:lastMatch[0]??null};
  }
  // CACHE_CANDIDATE ref=C05 scope=user layer=redis ttl=5-10s owner=stats
  async getHome(userId: string, now = new Date()) {
    const today = dateKey(now);
    const start = `${today.slice(0, 4)}-01-01`;
    const startUtc = new Date(`${start}T00:00:00+05:30`).toISOString();
    const endUtc = new Date(new Date(`${today}T00:00:00+05:30`).getTime() + 86400000).toISOString();
    const [stats, resume, lastMatch, definitions, facts] = await prisma.$transaction([
      prisma.$queryRaw<HomeStatsRow[]>(homeStatsQuery(userId, startUtc, endUtc)),
      prisma.lessonSession.findFirst({
        where: { userId, status: { in: ['ACTIVE', 'PAUSED'] }, roadmapStepId: { not: null },
          script: { status: 'PUBLISHED' }, roadmapStep: { isActive: true, roadmap: { isActive: true }, subject: { isActive: true }, topic: { isActive: true }, scriptAssignments: { some: { status: 'PUBLISHED' } } } },
        orderBy: { lastActivityAt: 'desc' },
        select: { roadmapStepId: true, lastActivityAt: true, script: { select: { title: true } },
          roadmapStep: { select: { topic: { select: { name: true } } } } },
      }),
      prisma.$queryRaw<{ result: string; correct: number; questions: number }[]>(latestHomeMatchQuery(userId)),
      prisma.achievement.findMany({ where: liveAchievementWhere, orderBy: achievementOrder, take: 6 }),
      prisma.$queryRaw<AchievementFacts[]>(achievementFactsQuery(userId, start, today)),
    ], { isolationLevel: 'RepeatableRead' });
    const rows = stats.filter(r => r.kind === 'difficulty');
    const days = stats.filter(r => r.kind === 'day' && r.date !== null)
      .map(r => ({ date: r.date!, attempted: r.attempted, correct: r.correct }));
    const summary = performance(rows);
    return {
      timezone: 'Asia/Kolkata', today, performance: summary,
      difficulty: rows.map(r => ({ difficulty: r.difficulty, ...performance([r]) })),
      activity: yearCalendar(today, days).map(day => ({ ...day,
        dailyChallengeCompleted: facts[0].dailyDates.includes(day.date) })),
      resume: resume ? { stepId: resume.roadmapStepId, title: resume.script.title,
        topic: resume.roadmapStep?.topic.name, lastPlayedAt: resume.lastActivityAt } : null,
      badges: presentAchievements(definitions, stats, facts[0]),
      ranked: lastMatch[0] ?? null,
      rankedLeague: await rankedQueryService.compact(userId),
    };
  }
}
