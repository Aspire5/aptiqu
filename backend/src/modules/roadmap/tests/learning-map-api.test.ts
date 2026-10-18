import test from 'node:test';
import assert from 'node:assert/strict';
import { prisma } from '../../../config/prisma';
import { roadmapProgressionService as service } from '../services/roadmap-progression.service';

// Every DB operation used by this read is replaced. No DB or Redis connection.
test('map uses latest played session, exposes completion, and safely falls back for new/empty users', async t => {
  t.mock.method(service, 'syncRoadmapWithSyllabus', async () => {});
  // Prisma delegates are proxies; assign stubs directly and restore each one.
  function stub<T, K extends keyof T>(target: T, key: K, replacement: unknown) {
    const original = target[key];
    target[key] = replacement as T[K];
    t.after(() => { target[key] = original; });
  }
  stub(prisma.roadmap, 'findFirst', async () => ({ id: 'roadmap', name: 'Roadmap', slug: 'roadmap', course: 'general' }));
  stub(prisma.subject, 'findFirst', async () => ({ id: 'subject', slug: 'subject', name: 'Subject', description: null }));
  const step = (id: string) => ({
    id, sequence: Number(id), topic: { id, name: id, slug: id, subtopics: [], description: null },
    subtopic: null, importance: 'medium', teachingMinutes: 10, teachingDepth: 1,
    scriptAssignments: [{ id, scriptId: id, sequence: 1, publishedVersionId: id,
      script: { subtopicId: null, title: id, slug: id, publishedVersionId: id } }],
  });
  let steps = [step('1'), step('2'), step('3')];
  stub(prisma.roadmapStep, 'findMany', async () => steps);
  stub(prisma.lessonSession, 'findMany', async (args: { where: { status: unknown } }) =>
    args.where.status === 'COMPLETED' ? [{ scriptId: '2' }] : []);
  let lastPlayed: { roadmapStepId: string } | null = { roadmapStepId: '2' };
  const lastQuery = t.mock.fn(async (_args: unknown) => lastPlayed);
  stub(prisma.lessonSession, 'findFirst', lastQuery);
  const result = await service.getSubjectLearningMap('user', 'roadmap', 'subject');
  assert.equal(result.progress.activeStepId, '2');
  assert.equal(result.topics[1].state, 'COMPLETED');
  assert.equal(result.topics[1].subtopics[0].isCompleted, true);
  assert.equal(result.progress.completedTopics, 1);
  const query = lastQuery.mock.calls[0].arguments[0] as unknown as {
    where: { userId: string; roadmapId: string; roadmapStepId: { in: string[] }; status: { in: string[] } };
    orderBy: object[];
  };
  assert.equal(query.where.userId, 'user');
  assert.equal(query.where.roadmapId, 'roadmap');
  assert.deepEqual(query.where.roadmapStepId.in, ['1', '2', '3']);
  assert.ok(query.where.status.in.includes('COMPLETED'));
  assert.deepEqual(query.orderBy, [{ lastActivityAt: 'desc' }, { id: 'desc' }]);
  lastPlayed = null;
  assert.equal((await service.getSubjectLearningMap('new-user', 'roadmap', 'subject')).progress.activeStepId, '1');
  steps = [];
  const empty = await service.getSubjectLearningMap('new-user', 'roadmap', 'subject');
  assert.equal(empty.progress.activeStepId, null);
  assert.equal(empty.progress.completedTopics, 0);
  assert.equal(empty.topics.length, 0);
});
