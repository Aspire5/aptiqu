import { prisma } from '../../config/prisma';
import { badgeCatalog, calendar, dateKey, performance } from './home.metrics';
import { homeStatsQuery, HomeStatsRow, latestHomeMatchQuery } from './home.queries';

export class HomeService {
  async getHome(userId: string, now = new Date()) {
    const today = dateKey(now);
    const start = new Date(new Date(`${today}T00:00:00Z`).getTime() - 27 * 86400000).toISOString().slice(0, 10);
    const startUtc = new Date(`${start}T00:00:00+05:30`).toISOString();
    const endUtc = new Date(new Date(`${today}T00:00:00+05:30`).getTime() + 86400000).toISOString();
    const [stats, resume, lastMatch] = await prisma.$transaction([
      prisma.$queryRaw<HomeStatsRow[]>(homeStatsQuery(userId, startUtc, endUtc)),
      prisma.lessonSession.findFirst({
        where: { userId, status: { in: ['ACTIVE', 'PAUSED'] }, roadmapStepId: { not: null },
          script: { status: 'PUBLISHED' }, roadmapStep: { isActive: true, roadmap: { isActive: true }, subject: { isActive: true }, topic: { isActive: true }, scriptAssignments: { some: { status: 'PUBLISHED' } } } },
        orderBy: { lastActivityAt: 'desc' },
        select: { roadmapStepId: true, lastActivityAt: true, script: { select: { title: true } },
          roadmapStep: { select: { topic: { select: { name: true } } } } },
      }),
      prisma.$queryRaw<{ result: string; correct: number; questions: number }[]>(latestHomeMatchQuery(userId)),
    ], { isolationLevel: 'RepeatableRead' });
    const rows = stats.filter(r => r.kind === 'difficulty');
    const days = stats.filter(r => r.kind === 'day' && r.date !== null)
      .map(r => ({ date: r.date!, attempted: r.attempted, correct: r.correct }));
    const summary = performance(rows);
    return {
      timezone: 'Asia/Kolkata', today, performance: summary,
      difficulty: rows.map(r => ({ difficulty: r.difficulty, ...performance([r]) })),
      activity: calendar(today, days),
      resume: resume ? { stepId: resume.roadmapStepId, title: resume.script.title,
        topic: resume.roadmapStep?.topic.name, lastPlayedAt: resume.lastActivityAt } : null,
      badges: badgeCatalog.map(b => {
        const progress = Math.min(b.target, b.id === 'first_answer' ? summary.attempted : b.id === 'correct_25'
          ? summary.correct : rows.find(r => r.difficulty === 'HARD')?.correct ?? 0);
        return { ...b, unlocked: progress >= b.target, progress };
      }),
      ranked: lastMatch[0] ?? null,
    };
  }
}
