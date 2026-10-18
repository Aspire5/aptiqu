import test from 'node:test';
import assert from 'node:assert/strict';
import { buildSubtopicProgress } from '../services/learning-map-progress';

const subtopics = [
  { id: 'a', slug: 'alpha', name: 'Alpha', sequence: 1 },
  { id: 'b', slug: 'beta', name: 'Beta', sequence: 2 },
];
function assignment(id: string, subtopicId: string | null, sequence: number, published = true) {
  return {
    id: `assignment-${id}`, scriptId: id, sequence,
    publishedVersionId: published ? `version-${id}` : null,
    script: { slug: `script-${id}`, title: id, subtopicId, publishedVersionId: null },
  };
}

test('explicit identity beats sequence when assignments and syllabus are reordered', () => {
  const progress = buildSubtopicProgress(subtopics,
    [assignment('beta', 'b', 1), assignment('alpha', 'a', 2)], new Set(['alpha']));
  assert.equal(progress.totalSubtopics, 2);
  assert.equal(progress.completedSubtopics, 1);
  assert.equal(progress.subtopics[0].scriptId, 'alpha');
  assert.equal(progress.subtopics[0].isCompleted, true);
  assert.equal(progress.subtopics[1].isCompleted, false);
  assert.equal(progress.isCompleted, false);
});

test('legacy slug identity is reserved before a sequence fallback can reuse it', () => {
  const progress = buildSubtopicProgress(subtopics,
    [assignment('beta', null, 1)], new Set(['beta']));
  assert.equal(progress.subtopics[0].isLocked, true);
  assert.equal(progress.subtopics[1].scriptId, 'beta');
  assert.equal(progress.completedSubtopics, 1);
});

test('legacy scripts without a subtopic identity still match by sequence', () => {
  const progress = buildSubtopicProgress(subtopics,
    [assignment('old-a', null, 1), assignment('old-b', null, 2)], new Set(['old-b']));
  assert.equal(progress.subtopics[1].isCompleted, true);
  assert.equal(progress.subtopics[0].isCompleted, false);
});

test('unpublished and missing scripts are unavailable and cannot complete a topic', () => {
  const progress = buildSubtopicProgress(subtopics,
    [assignment('alpha', 'a', 1), assignment('beta', 'b', 2, false)], new Set(['alpha', 'beta']));
  assert.equal(progress.completedSubtopics, 1);
  assert.equal(progress.subtopics[1].isLocked, true);
  assert.equal(progress.subtopics[1].scriptSlug, undefined);
  assert.equal(progress.isCompleted, false);
});

test('completed history survives a replay and requires every subtopic', () => {
  const assignments = [assignment('alpha', 'a', 1), assignment('beta', 'b', 2)];
  const progress = buildSubtopicProgress(subtopics, assignments, new Set(['alpha', 'beta']));
  assert.equal(progress.isCompleted, true);
  assert.ok(progress.subtopics.every(st => st.canReplay));
});

test('empty topics have no invented lessons or completion', () => {
  const progress = buildSubtopicProgress([], [], new Set());
  assert.equal(progress.totalSubtopics, 0);
  assert.equal(progress.hasPlayableContent, false);
  assert.equal(progress.isCompleted, false);
});

test('script-only legacy topics and null subtopic slugs are supported', () => {
  const script = assignment('alpha', 'a', 1);
  assert.equal(buildSubtopicProgress([], [script], new Set(['alpha'])).isCompleted, true);
  assert.equal(buildSubtopicProgress([{ ...subtopics[0], slug: null }], [script], new Set(['alpha'])).isCompleted, true);
});
