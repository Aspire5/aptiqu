import { prisma } from '../../config/prisma';
import { badgeCatalog, calendar, Counts, dateKey, performance } from './home.metrics';

export class HomeService {
  async getHome(userId: string, now = new Date()) {
    const today = dateKey(now);
    const start = new Date(new Date(`${today}T00:00:00Z`).getTime() - 27 * 86400000).toISOString().slice(0, 10);
    // Fixed-size aggregates and a single indexed latest-session lookup. No raw history scans.
    const [rows, days, badges, resume, lastMatch] = await prisma.$transaction([
      prisma.$queryRaw<(Counts & { difficulty: string })[]>`
        SELECT difficulty,attempted::float8,correct::float8,timed::float8,time_ms::float8 AS "timeMs"
        FROM gamification.home_totals WHERE user_id=${userId}::uuid AND attempted > 0`,
      prisma.$queryRaw<{ date: string; attempted: number; correct: number }[]>`
        SELECT day::text AS date,attempted::float8,correct::float8 FROM gamification.home_days
        WHERE user_id=${userId}::uuid AND day BETWEEN ${start}::date AND ${today}::date ORDER BY day`,
      prisma.$queryRaw<{ badge_id: string }[]>`SELECT badge_id FROM gamification.home_badges WHERE user_id=${userId}::uuid`,
      prisma.lessonSession.findFirst({
        where: { userId, status: { in: ['ACTIVE', 'PAUSED'] }, roadmapStepId: { not: null },
          script: { status: 'PUBLISHED' }, roadmapStep: { isActive: true, roadmap: { isActive: true }, subject: { isActive: true }, topic: { isActive: true }, scriptAssignments: { some: { status: 'PUBLISHED' } } } },
        orderBy: { lastActivityAt: 'desc' },
        select: { roadmapStepId: true, lastActivityAt: true, script: { select: { title: true } },
          roadmapStep: { select: { topic: { select: { name: true } } } } },
      }),
      prisma.$queryRaw<{ result: string; correct: number; questions: number }[]>`
        SELECT result,correct,questions FROM gamification.home_ranked WHERE user_id=${userId}::uuid`,
    ], { isolationLevel: 'RepeatableRead' });
    const summary = performance(rows);
    return {
      timezone: 'Asia/Kolkata', today, performance: summary,
      difficulty: rows.map(r => ({ difficulty: r.difficulty, ...performance([r]) })),
      activity: calendar(today, days),
      resume: resume ? { stepId: resume.roadmapStepId, title: resume.script.title,
        topic: resume.roadmapStep?.topic.name, lastPlayedAt: resume.lastActivityAt } : null,
      badges: badgeCatalog.map(b => ({ ...b, unlocked: badges.some(a => a.badge_id === b.id),
        progress: Math.min(b.target, b.id === 'first_answer' ? summary.attempted : b.id === 'correct_25'
          ? summary.correct : rows.find(r => r.difficulty === 'HARD')?.correct ?? 0) })),
      ranked: lastMatch[0] ?? null,
    };
  }
}
