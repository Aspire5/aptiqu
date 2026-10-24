// Inert import regressions: no app, environment file, database or Redis is loaded.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { loader } = require('../../modules/pvp/tests/pvp-test-fixture.cjs');
const root = path.resolve(__dirname, '../../../..');
const source = file => path.join(root, 'backend/src', file);
function fixture(subtopics = [{ id: 'lesson', slug: 'lesson', topicId: 'topic', topic: { subjectId: 'subject' } }]) {
  const records = [];
  const db = {
    subtopic: { findMany: async () => subtopics },
    question: { findMany: async () => [], createMany: async ({ data }) => records.push(...data) },
    $transaction: async work => work(db),
  };
  const load = loader({
    crypto: { default: crypto },
    '../lesson/services/learning-transaction': { prisma: db },
    '../roadmap/services/catalog-mutation': { catalogMutation: async work => work() },
    '../roadmap/services/roadmap-progression.service': { roadmapProgressionService: {} },
    '../lesson/services/script-cache.service': { scriptCacheService: {} },
  });
  return { records, service: load(source('modules/admin/admin-questions.service.ts')).AdminQuestionsService };
}
const valid = () => ({ externalQuestionKey: 'fixture', externalSubtopicKey: 'lesson', prompt: 'What is 2 + 2?',
  options: ['3', '4', '5', '6'].map((text, i) => ({ id: 'ABCD'[i], text })), correctAnswer: 'B', explanation: '2 + 2 = 4.', estimatedTimeSeconds: 30 });
test('bulk import accepts valid admin fields and persists the server-computed fingerprint', async () => {
  const { service, records } = fixture();
  const result = await service.bulkImport([valid()]);
  assert.equal(result.successCount, 1);
  assert.equal(records.length, 1);
  assert.match(records[0].fingerprint, /^[a-f0-9]{64}$/);
  assert.equal(records[0].correctAnswer, 'B');
});
test('bulk import still rejects duplicate options or an unsupported E answer before any write', async () => {
  for (const mutate of [q => { q.options[3].text = '4'; }, q => { q.correctAnswer = 'E'; }]) {
    const { service, records } = fixture();
    const q = valid(); mutate(q);
    await assert.rejects(() => service.bulkImport([q]));
    assert.equal(records.length, 0);
  }
});
function savedQuestions() {
  const rows = new Map();
  for (const folder of fs.readdirSync(path.join(root, 'books/SubTopics')).filter(f => /^SBT-RSA-0[1-3]-/.test(f))) {
    for (const type of ['Extracted Question Json', 'AI Question Json chunks']) {
      const dir = path.join(root, 'books/SubTopics', folder, type);
      if (!fs.existsSync(dir)) continue;
      for (const file of fs.readdirSync(dir).filter(f => f.endsWith('.json'))) {
        for (const q of JSON.parse(fs.readFileSync(path.join(dir, file)))) {
          if (rows.has(q.externalQuestionKey)) assert.deepEqual(rows.get(q.externalQuestionKey), q, 'Copied banks must agree');
          rows.set(q.externalQuestionKey, q);
        }
      }
    }
  }
  return rows;
}
test('all 1636 unique saved questions pass the actual bulk service and preserve keys and hierarchy', async () => {
  const rows = savedQuestions();
  assert.equal(rows.size, 1636);
  const subtopics = [...new Set([...rows.values()].map(q => q.externalSubtopicKey))].map(key => ({ id: key, slug: key, topicId: key.split('-')[0], topic: { subjectId: 'saved-book' } }));
  const { service, records } = fixture(subtopics);
  const result = await service.bulkImport([...rows.values()]);
  assert.equal(result.successCount, rows.size);
  assert.equal(new Set(records.map(q => q.externalKey)).size, rows.size);
  assert.equal(new Set(records.map(q => q.fingerprint)).size, rows.size);
  for (const record of records) {
    assert.equal(record.subtopicId, rows.get(record.externalKey).externalSubtopicKey);
    assert.ok(['MENTAL', 'LIGHT_PEN_AND_PAPER', 'PEN_AND_PAPER'].includes(rows.get(record.externalKey).calculationMode));
  }
});
test('saved prime-factor counts expand composite bases before counting multiplicity', () => {
  function factors(n) {
    let count = 0;
    for (let p = 2; p * p <= n; p++) while (n % p === 0) { n /= p; count++; }
    return count + (n > 1 ? 1 : 0);
  }
  for (const q of savedQuestions().values()) {
    if (q.pattern !== 'COUNT_PRIME_FACTORS_WITH_MULTIPLICITY') continue;
    const terms = [...q.prompt.matchAll(/(\d+)\^(\d+)/g)];
    const single = q.prompt.match(/does (\d+) have/);
    const expected = terms.length ? terms.reduce((sum, [, base, power]) => sum + factors(Number(base)) * Number(power), 0) : factors(Number(single[1]));
    const matches = q.options.filter(o => Number(o.text) === expected);
    assert.equal(matches.length, 1, q.externalQuestionKey);
    assert.equal(matches[0].id, q.correctAnswer, q.externalQuestionKey);
  }
});
test('saved options do not contain equivalent fractions or decimals', () => {
  const gcd = (a, b) => b ? gcd(b, a % b) : a;
  for (const q of savedQuestions().values()) {
    const seen = new Set();
    for (const option of q.options) {
      const text = option.text.trim().replaceAll(',', '');
      let numerator, denominator;
      if (/^[+-]?\d+\/\d+$/.test(text)) [numerator, denominator] = text.split('/').map(BigInt);
      else if (/^[+-]?\d+(?:\.\d+)?$/.test(text)) {
        const decimals = text.split('.')[1]?.length || 0;
        numerator = BigInt(text.replace('.', '')); denominator = 10n ** BigInt(decimals);
      } else continue;
      const factor = gcd(numerator < 0n ? -numerator : numerator, denominator);
      const identity = `${numerator / factor}/${denominator / factor}`;
      assert.ok(!seen.has(identity), `${q.externalQuestionKey}: equivalent option ${option.id}`);
      seen.add(identity);
    }
  }
});
test('restored scripts have valid graphs, matching displayed questions and resolvable bank references', () => {
  const load = loader({ './learning-transaction': { prisma: {}, learningTransaction: () => null }, './redis.service': { redisService: {} } });
  const { scriptCacheService } = load(source('modules/lesson/services/script-cache.service.ts'));
  const { ScriptValidator } = load(source('modules/lesson/engines/script-validator.ts'));
  const rows = savedQuestions();
  const jobs = fs.readdirSync(path.join(root, 'books/SubTopics/SBT-RSA-01-Number_System/Scripts')).filter(f => f.endsWith('.json')).map(file => ['SBT-RSA-01-Number_System', file]);
  for (const file of ['hcf_lcm_05_fractions.json', 'hcf_lcm_07_number_construction.json', 'hcf_lcm_09_divisibility_bounds.json']) jobs.push(['SBT-RSA-02-HCF_and_LCM', file]);
  for (const [folder, file] of jobs) {
    const raw = JSON.parse(fs.readFileSync(path.join(root, 'books/SubTopics', folder, 'Scripts', file)));
    const def = scriptCacheService.normalizeScriptDefinition(raw);
    const validation = ScriptValidator.validate(def);
    assert.equal(validation.valid, true, `${file}: ${JSON.stringify(validation.errors)}`);
    for (const node of Object.values(def.nodes)) {
      const ref = node.questionReference;
      if (ref?.mode === 'QUESTION_EXTERNAL_ID') {
        assert.ok(rows.has(ref.externalId), `${file}: missing ${ref.externalId}`);
        assert.equal(rows.get(ref.externalId).externalSubtopicKey, file.replace('.json', ''));
      }
      if (ref?.mode === 'INLINE' && node.input?.options) {
        assert.deepEqual(node.input.options, ref.inlineData.options, `${file}: displayed choices differ at ${node.id}`);
        assert.equal(node.content.text, ref.inlineData.prompt, `${file}: displayed prompt differs at ${node.id}`);
      }
    }
  }
});
test('normalization keeps completion terminal after stored object keys change order', () => {
  const load = loader({ './learning-transaction': { prisma: {}, learningTransaction: () => null }, './redis.service': { redisService: {} } });
  const { scriptCacheService } = load(source('modules/lesson/services/script-cache.service.ts'));
  const raw = { scriptId: 'fixture', entryNodeId: 'start', nodes: {
    finish: { id: 'finish', type: 'COMPLETION', transitions: [] },
    start: { id: 'start', type: 'CONTENT', transitions: [{ targetNodeId: 'finish' }] },
  } };
  const normalized = scriptCacheService.normalizeScriptDefinition(raw);
  assert.equal(normalized.nodes.finish.transitions.length, 0);
  assert.equal(normalized.nodes.start.transitions[0].targetNodeId, 'finish');
});
