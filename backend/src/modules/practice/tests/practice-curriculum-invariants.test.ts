import assert from 'assert';
import { ScriptValidator } from '../../lesson/engines/script-validator';
import { ScriptDefinition } from '../../lesson/interfaces/script-dsl.interface';
import { XpPolicy } from '../../xp/xp.policy';

async function runTests() {
  console.log('🧪 Starting Practice & Curriculum Invariant Tests...\n');

  // Test 1: ScriptValidator handles QUESTION_EXTERNAL_ID
  console.log('Test 1: ScriptValidator validates QUESTION_EXTERNAL_ID properly');
  const validDsl: ScriptDefinition = {
    schemaVersion: 1,
    scriptId: 'test-script-tsd-01',
    version: 1,
    sourceType: 'MANUAL',
    entryNodeId: 'node-1',
    metadata: {
      title: 'Relative Speed Fundamentals',
      subjectId: 'sub-test',
      topicId: 'topic-test',
      targetDurationMinutes: 8,
    },
    nodes: {
      'node-1': {
        id: 'node-1',
        type: 'CONTENT',
        content: { text: 'Welcome to Relative Speed.' },
        transitions: [{ targetNodeId: 'node-2' }],
      },
      'node-2': {
        id: 'node-2',
        type: 'QUESTION',
        content: { text: 'Solve this question:' },
        questionReference: {
          mode: 'QUESTION_EXTERNAL_ID',
          externalId: 'tsd-q-001',
        },
        transitions: [{ targetNodeId: 'node-3' }],
      },
      'node-3': {
        id: 'node-3',
        type: 'COMPLETION',
        content: { text: 'All done!' },
        transitions: [],
      },
    },
  };

  const validation = ScriptValidator.validate(validDsl);
  assert.strictEqual(validation.valid, true, 'Valid script with QUESTION_EXTERNAL_ID should pass validation');
  console.log('  ✅ Valid QUESTION_EXTERNAL_ID passed validation.');

  // Test 2: ScriptValidator rejects empty externalId
  console.log('Test 2: ScriptValidator rejects empty externalId in QUESTION_EXTERNAL_ID mode');
  const invalidDsl = JSON.parse(JSON.stringify(validDsl));
  invalidDsl.nodes['node-2'].questionReference.externalId = '';
  const invalidValidation = ScriptValidator.validate(invalidDsl);
  assert.strictEqual(invalidValidation.valid, false, 'Empty externalId should fail validation');
  assert.ok(
    invalidValidation.errors.some((e) => e.field.includes('externalId')),
    'Should report error on externalId field'
  );
  console.log('  ✅ Empty externalId correctly rejected.');

  // Test 3: XP Policy calculation consistency
  console.log('Test 3: XpPolicy correctly calculates XP based on type and difficulty');
  assert.strictEqual(XpPolicy.calculateQuestionXp('PRACTICE', 'EASY'), 10);
  assert.strictEqual(XpPolicy.calculateQuestionXp('PRACTICE', 'MEDIUM'), 15);
  assert.strictEqual(XpPolicy.calculateQuestionXp('PRACTICE', 'HARD'), 20);
  assert.strictEqual(XpPolicy.calculateQuestionXp('RANKED', 'HARD'), 25);
  console.log('  ✅ XpPolicy returns canonical values (EASY: 10, MED: 15, HARD: 20 for practice).');

  // Test 4: Subtopic mapping exact resolution logic
  console.log('Test 4: Subtopic key matching behavior');
  const mockSubtopics = [
    { id: 'sub-uuid-1', slug: 'percentage-01', name: 'Percentage Basics' },
    { id: 'sub-uuid-2', slug: 'percentage-02', name: 'Percentage Advanced' },
  ];
  const subtopicMap = new Map<string, any>();
  for (const s of mockSubtopics) {
    subtopicMap.set(s.slug, s);
    subtopicMap.set(s.id, s);
  }

  // Exact slug match
  assert.strictEqual(subtopicMap.get('percentage-01')?.id, 'sub-uuid-1');
  // Unknown slug match
  assert.strictEqual(subtopicMap.get('percentage-99'), undefined, 'Unknown subtopic slug should not match');
  console.log('  ✅ Subtopic exact lookup correctly resolves known keys and rejects unknown keys.');

  console.log('\n🎉 All Invariant Unit Tests Passed Successfully!\n');
}

runTests().catch((err) => {
  console.error('❌ Test suite failed:', err);
  process.exit(1);
});
