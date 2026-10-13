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
test('Home contract has five bounded reads and handles empty/populated users', async () => {
  const originalRaw = prisma.$queryRaw;
  const originalSession = prisma.lessonSession.findFirst;
  const originalTransaction = prisma.$transaction;
  let queries: string[] = [];
  let fixture: unknown[] = [[], [], [], null, []];
  try {
    prisma.$queryRaw = ((strings: TemplateStringsArray) => {
      queries.push(strings.join('?'));
      return Promise.resolve([]);
    }) as typeof prisma.$queryRaw;
    prisma.lessonSession.findFirst = (() => Promise.resolve(null)) as typeof prisma.lessonSession.findFirst;
    prisma.$transaction = (async (ops: unknown[]) => { assert.equal(ops.length, 5); return fixture; }) as typeof prisma.$transaction;
    const service = new HomeService();
    const empty = await service.getHome('00000000-0000-0000-0000-000000000001', new Date('2026-10-13T12:00:00Z'));
    assert.equal(empty.performance.accuracy, null);
    assert.equal(empty.resume, null);
    assert.equal(empty.ranked, null);
    assert.equal(empty.badges.every(b => !b.unlocked), true);
    assert.equal(queries.some(q => /home_source_events|question_attempts|COUNT\(|SUM\(/i.test(q)), false);
    assert.equal(queries.filter(q => /home_days/.test(q)).length, 1);
    queries = [];
    fixture = [[{ difficulty: 'HARD', attempted: 1000000, correct: 500000, timed: 10, timeMs: 15000 }],
      [{ date: '2026-10-13', attempted: 10, correct: 5 }], [{ badge_id: 'hard_10' }],
      { roadmapStepId: 'step', lastActivityAt: new Date(), script: { title: 'Factors' }, roadmapStep: { topic: { name: 'Numbers' } } },
      [{ result: 'Win', correct: 8, questions: 10 }]];
    const populated = await service.getHome('00000000-0000-0000-0000-000000000001');
    assert.equal(populated.performance.accuracy, .5);
    assert.equal(populated.performance.averageSolveTimeMs, 1500);
    assert.equal(populated.resume?.title, 'Factors');
    assert.equal(populated.ranked?.result, 'Win');
    assert.equal(populated.badges.find(b => b.id === 'hard_10')?.unlocked, true);
    assert.equal(queries.length, 4);
  } finally {
    prisma.$queryRaw = originalRaw;
    prisma.lessonSession.findFirst = originalSession;
    prisma.$transaction = originalTransaction;
  }
});
