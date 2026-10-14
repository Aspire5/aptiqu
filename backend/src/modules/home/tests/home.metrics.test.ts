import test from 'node:test';
import assert from 'node:assert/strict';
import { calendar, dateKey, performance } from '../home.metrics';
import { prisma } from '../../../config/prisma';
import { HomeService } from '../home.service';

test('empty results do not invent accuracy or solve time', () => {
  assert.deepEqual(performance([]), { attempted: 0, correct: 0, timed: 0, timeMs: 0, accuracy: null, averageSolveTimeMs: null });
});
test('accuracy and time use their own denominators, weighted across difficulties', () => {
  const result = performance([{ attempted: 10, correct: 8, timed: 2, timeMs: 6000 },
    { attempted: 2, correct: 1, timed: 1, timeMs: 9000 }]);
  assert.equal(result.accuracy, .75);
  assert.equal(result.averageSolveTimeMs, 5000);
  assert.equal(result.correct, 9);
});
test('IST activity date changes at 18:30 UTC, including year boundary', () => {
  assert.equal(dateKey(new Date('2026-12-31T18:29:59Z')), '2026-12-31');
  assert.equal(dateKey(new Date('2026-12-31T18:30:00Z')), '2027-01-01');
});
test('calendar is chronological, bounded, handles leap day and sparse history', () => {
  const days = calendar('2024-03-01', [{ date: '2024-02-29', attempted: 4, correct: 3 }]);
  assert.equal(days.length, 28);
  assert.deepEqual(days.at(-2), { date: '2024-02-29', attempted: 4, correct: 3 });
  assert.deepEqual(days.at(-1), { date: '2024-03-01', attempted: 0, correct: 0 });
  assert.equal(new Set(days.map(d => d.date)).size, 28);
});
test('Home derives its contract from aggregates, resume and latest match in one snapshot', async () => {
  const originalRaw = prisma.$queryRaw;
  const originalSession = prisma.lessonSession.findFirst;
  const originalTransaction = prisma.$transaction;
  const originalDefinitions = prisma.achievement.findMany;
  const facts = { dailyCompleted: 4, pvpWins: 2, bestStreak: 3, dailyDates: ['2026-10-14'] };
  let queries: { sql: string; values: unknown[] }[] = [];
  let fixture: unknown[] = [[], null, [], [], [facts]];
  const userId = '00000000-0000-0000-0000-000000000001';
  try {
    prisma.$queryRaw = ((query: { sql: string; values: unknown[] }) => {
      queries.push(query);
      return Promise.resolve([]);
    }) as typeof prisma.$queryRaw;
    prisma.lessonSession.findFirst = (() => Promise.resolve(null)) as typeof prisma.lessonSession.findFirst;
    prisma.achievement.findMany = (() => Promise.resolve([])) as typeof prisma.achievement.findMany;
    prisma.$transaction = (async (ops: unknown[], options: { isolationLevel: string }) => {
      assert.equal(ops.length, 5);
      assert.equal(options.isolationLevel, 'RepeatableRead');
      return fixture;
    }) as typeof prisma.$transaction;
    const service = new HomeService();
    const now = new Date('2026-10-13T18:30:00Z');
    const empty = await service.getHome(userId, now);
    assert.equal(empty.performance.accuracy, null);
    assert.equal(empty.resume, null);
    assert.equal(empty.ranked, null);
    assert.equal(empty.badges.every(b => !b.unlocked && b.progress === 0), true);
    assert.equal(empty.activity.length, 28);
    assert.equal(empty.today, '2026-10-14');
    assert.equal(queries.length, 3);
    // Dates are UTC boundaries of the 28 IST dates, including the final full day.
    assert.deepEqual(queries[0].values, [userId, userId, userId, userId,
      '2026-09-16T18:30:00.000Z', '2026-10-14T18:30:00.000Z']);
    assert.equal(queries.some(q => /gamification\.home_/.test(q.sql)), false);
    queries = [];
    fixture = [[
      { kind: 'difficulty', difficulty: 'HARD', date: null, attempted: 1000000, correct: 500000, timed: 10, timeMs: 15000 },
      { kind: 'source', source: 'PRACTICE', difficulty: 'HARD', date: null, attempted: 1000000, correct: 500000, timed: 10, timeMs: 15000 },
      { kind: 'difficulty', difficulty: 'UNKNOWN', date: null, attempted: 2, correct: 1, timed: 0, timeMs: 0 },
      { kind: 'day', difficulty: null, date: '2026-10-14', attempted: 10, correct: 5, timed: 1, timeMs: 5000 },
    ], { roadmapStepId: 'step', lastActivityAt: new Date(), script: { title: 'Factors' }, roadmapStep: { topic: { name: 'Numbers' } } },
      [{ result: 'Win', correct: 8, questions: 10 }],
      [{ id: 'custom-admin-rule', title: 'Custom milestone', description: 'Admin description', metric: 'CORRECT', source: 'PRACTICE', difficulty: 'HARD', target: 25 }], [facts]];
    const populated = await service.getHome(userId, now);
    assert.equal(populated.performance.attempted, 1000002);
    assert.equal(populated.performance.correct, 500001);
    assert.equal(populated.performance.accuracy, .5);
    assert.equal(populated.performance.averageSolveTimeMs, 1500);
    assert.equal(populated.difficulty.length, 2);
    assert.deepEqual(populated.activity.at(-1), { date: '2026-10-14', attempted: 10, correct: 5, dailyChallengeCompleted: true });
    assert.equal(populated.resume?.title, 'Factors');
    assert.equal(populated.ranked?.result, 'Win');
    assert.equal(populated.badges.every(b => b.unlocked && b.progress === b.target), true);
    // Corrected/deleted answers must be reflected without stale projection/badge rows.
    fixture = [[{ kind: 'source', source: 'PRACTICE', difficulty: 'HARD', date: null, attempted: 12, correct: 9, timed: 0, timeMs: 0 }], null, [],
      [{ id: 'custom-admin-rule', title: 'Custom milestone', description: 'Admin description', metric: 'CORRECT', source: 'PRACTICE', difficulty: 'HARD', target: 25 }], [facts]];
    const corrected = await service.getHome(userId, now);
    assert.equal(corrected.badges.find(b => b.id === 'custom-admin-rule')?.unlocked, false);
    assert.equal(corrected.badges.find(b => b.id === 'custom-admin-rule')?.progress, 9);
    assert.equal(corrected.performance.averageSolveTimeMs, null);
  } finally {
    prisma.$queryRaw = originalRaw;
    prisma.lessonSession.findFirst = originalSession;
    prisma.$transaction = originalTransaction;
    prisma.achievement.findMany = originalDefinitions;
  }
});
