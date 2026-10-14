import test from 'node:test';
import assert from 'node:assert/strict';
import { achievementInput, achievementProgress } from '../achievement.rules';
import { achievementAnalyticsQuery } from '../achievement.analytics';
import { HomeStatsRow } from '../../home/home.queries';
import { prisma } from '../../../config/prisma';
import { AdminAchievementsController } from '../../admin/admin-achievements.controller';
import { Request, Response } from 'express';
const rule = { title: 'Admin-authored name', description: 'Admin-authored description', metric: 'CORRECT' as const,
  source: 'PRACTICE' as const, difficulty: 'HARD' as const, target: 7, sortOrder: 0, isActive: true };
const facts = { dailyCompleted: 5, pvpWins: 3, bestStreak: 9 };
const rows: HomeStatsRow[] = [
  { kind: 'source', source: 'PRACTICE', difficulty: 'HARD', date: null, attempted: 9, correct: 7, timed: 0, timeMs: 0 },
  { kind: 'source', source: 'LESSON', difficulty: 'HARD', date: null, attempted: 2, correct: 1, timed: 0, timeMs: 0 },
  { kind: 'source', source: 'PRACTICE', difficulty: 'EASY', date: null, attempted: 5, correct: 4, timed: 0, timeMs: 0 },
  { kind: 'difficulty', source: null, difficulty: 'HARD', date: null, attempted: 11, correct: 8, timed: 0, timeMs: 0 },
];
test('rules validate positive integer targets and reject impossible filter combinations', () => {
  assert.equal(achievementInput.safeParse(rule).success, true);
  for (const target of [0, -1, 1.2, Infinity, 2147483648]) assert.equal(achievementInput.safeParse({ ...rule, target }).success, false);
  assert.equal(achievementInput.safeParse({ ...rule, metric: 'SQL_INJECTION' }).success, false);
  assert.equal(achievementInput.safeParse({ ...rule, metric: 'PVP_WINS' }).success, false);
  assert.equal(achievementInput.safeParse({ ...rule, title: '  ' }).success, false);
});
test('arbitrary database targets and source/difficulty filters drive progress without double counting', () => {
  assert.deepEqual(achievementProgress(rule, rows, facts), { progress: 7, unlocked: true });
  assert.deepEqual(achievementProgress({ ...rule, target: 8 }, rows, facts), { progress: 7, unlocked: false });
  assert.deepEqual(achievementProgress({ ...rule, source: 'ALL', difficulty: null, target: 50 }, rows, facts), { progress: 12, unlocked: false });
  assert.deepEqual(achievementProgress({ ...rule, metric: 'ATTEMPTED', difficulty: null, target: 50 }, rows, facts), { progress: 14, unlocked: false });
  assert.deepEqual(achievementProgress(rule, [], facts), { progress: 0, unlocked: false });
  for (const [metric, progress] of [['DAILY_COMPLETED', 5], ['PVP_WINS', 3], ['BEST_STREAK', 9]] as const) {
    assert.deepEqual(achievementProgress({ ...rule, metric, source: 'ALL', difficulty: null, target: 100 }, [], facts), { progress, unlocked: false });
  }
});
test('admin analytics bind search, including literal wildcard characters, and paginate SQL results', () => {
  const query = achievementAnalyticsQuery(2, 20, "'_%", 'ARCHIVED');
  assert.equal(query.sql.includes("'_%"), false);
  assert.equal(query.values.at(-1), 20);
  assert.equal(query.values.includes("%'\\_\\%%"), true);
  assert.match(query.sql, /WHERE value > 0/);
});
test('soft delete, restore and hard delete use version checks; stale edits return conflict', async () => {
  const oldUpdate = prisma.achievement.updateMany; const oldDelete = prisma.achievement.deleteMany;
  let update: any; let deletion: any;
  const id = '00000000-0000-4000-8000-000000000001';
  const req = { params: { id }, body: { version: 2 }, query: {} } as unknown as Request;
  let status = 200;
  const res = { status(code: number) { status = code; return this; }, json() { return this; } } as unknown as Response;
  try {
    prisma.achievement.updateMany = (async (args: any) => { update = args; return { count: 1 }; }) as typeof oldUpdate;
    prisma.achievement.deleteMany = (async (args: any) => { deletion = args; return { count: 1 }; }) as typeof oldDelete;
    await AdminAchievementsController.remove(req, res);
    assert.equal(update.where.version, 2); assert.equal(update.data.isActive, false); assert.ok(update.data.deletedAt instanceof Date);
    await AdminAchievementsController.restore(req, res);
    assert.equal(update.data.deletedAt, null); assert.equal(update.data.isActive, false);
    req.query = { hard: 'true' }; await AdminAchievementsController.remove(req, res);
    assert.deepEqual(deletion.where, { id, version: 2 });
    req.body = { ...rule, version: 2 };
    prisma.achievement.updateMany = (async () => ({ count: 0 })) as typeof oldUpdate;
    await AdminAchievementsController.update(req, res); assert.equal(status, 409);
  } finally { prisma.achievement.updateMany = oldUpdate; prisma.achievement.deleteMany = oldDelete; }
});
