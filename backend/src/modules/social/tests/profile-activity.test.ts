import test from 'node:test';
import assert from 'node:assert/strict';
import { prisma } from '../../../config/prisma';
import { FriendsService } from '../friends.service';

test('profile activity uses IST month bounds, zero fills dates and preserves daily completions', async () => {
  const originalFind = prisma.user.findFirst;
  const originalRaw = prisma.$queryRaw;
  const originalChallenges = prisma.dailyChallengeParticipation.findMany;
  const originalTransaction = prisma.$transaction;
  let query: any;
  let challengeArgs: any;
  try {
    prisma.user.findFirst = (async () => ({ id: 'learner' })) as any;
    prisma.$queryRaw = ((input: any) => {
      query = input;
      return Promise.resolve([{ date: '2028-02-29', attempted: 4, correct: 3 }]);
    }) as any;
    prisma.dailyChallengeParticipation.findMany = ((input: any) => {
      challengeArgs = input;
      return Promise.resolve([{ dateString: '2028-02-29' }]);
    }) as any;
    prisma.$transaction = ((queries: any[]) => Promise.all(queries)) as any;
    const result = await new FriendsService().activity('learner', '2028-02');
    assert.equal(result.activity.length, 29);
    assert.deepEqual(result.activity[0], { date: '2028-02-01', attempted: 0, correct: 0, dailyChallengeCompleted: false });
    assert.deepEqual(result.activity[28], { date: '2028-02-29', attempted: 4, correct: 3, dailyChallengeCompleted: true });
    assert.ok(query.values.includes('2028-01-31T18:30:00.000Z'));
    assert.ok(query.values.includes('2028-02-29T18:30:00.000Z'));
    assert.deepEqual(challengeArgs.where, { userId: 'learner', status: 'COMPLETED', dateString: { gte: '2028-02-01', lt: '2028-03-01' } });
    await new FriendsService().activity('learner', '2026-12');
    assert.ok(query.values.includes('2026-12-31T18:30:00.000Z'));
    prisma.user.findFirst = (async () => null) as any;
    await assert.rejects(new FriendsService().activity('missing', '2028-02'), /Learner not found/);
  } finally {
    prisma.user.findFirst = originalFind;
    prisma.$queryRaw = originalRaw;
    prisma.dailyChallengeParticipation.findMany = originalChallenges;
    prisma.$transaction = originalTransaction;
  }
});
