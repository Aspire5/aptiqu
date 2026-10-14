import { achievementFactsQuery, AchievementFacts, achievementOrder, liveAchievementWhere, presentAchievements } from '../achievements/achievement.service';
import { prisma } from '../../config/prisma';
import { calendar, dateKey, performance } from './home.metrics';
import { homeStatsQuery, HomeStatsRow, latestHomeMatchQuery } from './home.queries';

export class HomeService {
  async getHome(userId: string, now = new Date()) {
    const today = dateKey(now);
    const start = new Date(new Date(`${today}T00:00:00Z`).getTime() - 27 * 86400000).toISOString().slice(0, 10);
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
      activity: calendar(today, days).map(day => ({ ...day,
        dailyChallengeCompleted: facts[0].dailyDates.includes(day.date) })),
      resume: resume ? { stepId: resume.roadmapStepId, title: resume.script.title,
        topic: resume.roadmapStep?.topic.name, lastPlayedAt: resume.lastActivityAt } : null,
      badges: presentAchievements(definitions, stats, facts[0]),
      ranked: lastMatch[0] ?? null,
    };
  }
}
