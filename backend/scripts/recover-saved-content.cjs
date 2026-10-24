#!/usr/bin/env node
// One-off, resumable recovery through authenticated production HTTP APIs only.
// No app/environment bootstrap, SQL, Prisma client, Redis, SSH or migrations.
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../..');
const output = path.join(root, 'docs/content-recovery/2026-10-23');
const apiRoot = 'https://aptiqu.in/api/v1/admin';
const tokenFile = '/private/tmp/aptiqu-import-token';
const mode = process.argv[2] || 'plan';
const stamp = () => new Date().toISOString();
const record = item => fs.appendFileSync(path.join(output, 'api-receipts.jsonl'), JSON.stringify({ at: stamp(), ...item }) + '\n');
const pause = ms => new Promise(resolve => setTimeout(resolve, ms));
const canonical = value => Array.isArray(value) ? value.map(canonical) : value && typeof value === 'object'
  ? Object.fromEntries(Object.keys(value).sort().map(key => [key, canonical(value[key])])) : value;
const same = (a, b) => JSON.stringify(canonical(a)) === JSON.stringify(canonical(b));
let nextQuestionWrite = 0;
async function request(route, method = 'GET', body, attempt = 0) {
  if (route === '/questions' && method === 'POST') {
    const slot = Math.max(Date.now(), nextQuestionWrite);
    nextQuestionWrite = slot + 400; // at most 150 writes/minute, below the API's 180 limit
    await pause(Math.max(0, slot - Date.now()));
  }
  const response = await fetch(apiRoot + route, {
    method, headers: { Authorization: 'Bearer ' + fs.readFileSync(tokenFile, 'utf8'), 'Content-Type': 'application/json' },
    ...(body ? { body: JSON.stringify(body) } : {}), signal: AbortSignal.timeout(90000),
  });
  const result = await response.json();
  if (response.status === 429 && attempt < 3) {
    const delay = Math.max(1, Number(response.headers.get('Retry-After')) || 60);
    console.log(`Rate limited; respecting Retry-After (${delay}s).`);
    await pause(delay * 1000);
    return request(route, method, body, attempt + 1);
  }
  if (!response.ok) throw Object.assign(new Error(`${method} ${route}: ${response.status} ${result.message}`), { status: response.status, result });
  return result.data;
}
function banks() {
  const rows = new Map();
  const base = path.join(root, 'books/SubTopics');
  for (const folder of fs.readdirSync(base).filter(x => /^SBT-RSA-0[1-3]-/.test(x)).sort()) {
    for (const type of ['Extracted Question Json', 'AI Question Json chunks']) {
      const dir = path.join(base, folder, type);
      if (!fs.existsSync(dir)) continue;
      for (const file of fs.readdirSync(dir).filter(x => x.endsWith('.json')).sort()) {
        for (const q of JSON.parse(fs.readFileSync(path.join(dir, file)))) {
          const old = rows.get(q.externalQuestionKey);
          if (old && JSON.stringify(old) !== JSON.stringify(q)) throw new Error(`Conflicting duplicate: ${q.externalQuestionKey}`);
          rows.set(q.externalQuestionKey, q);
        }
      }
    }
  }
  return [...rows.values()];
}
function questionPayload(q, subtopics) {
  const subtopic = subtopics.find(s => s.slug === q.externalSubtopicKey || s.id === q.externalSubtopicKey);
  if (!subtopic) throw new Error(`Missing subtopic ${q.externalSubtopicKey}`);
  const synthetic = q.provenance?.bookTitle === 'AptiQu Original Supplementary Questions';
  return {
    subtopicId: subtopic.id, externalKey: q.externalQuestionKey, pattern: q.pattern,
    prompt: q.prompt, options: q.options, correctAnswer: q.correctAnswer, hints: q.hints || [],
    explanation: q.explanation, method: q.method, difficulty: q.difficulty,
    estimatedTimeSeconds: q.estimatedTimeSeconds,
    calculationMode: ['WRITTEN', 'ALGEBRAIC'].includes(q.calculationMode) ? 'PEN_AND_PAPER' : q.calculationMode,
    status: ['DRAFT', 'REVIEW', 'PUBLISHED', 'ARCHIVED'].includes(q.status) ? q.status : 'PUBLISHED',
    sourceType: synthetic ? 'AI_GENERATED' : 'MANUAL', generationMethod: synthetic ? 'AI_SYNTHETIC' : 'AI_EXTRACTED',
    pyq: q.pyq, alternativeExplanation: q.alternativeExplanation, preferredSolution: q.preferredSolution,
    preferredReason: q.preferredReason, sourceBook: q.provenance?.bookTitle,
    sourceEdition: q.provenance?.edition, sourceChapter: q.provenance?.chapter, sourcePageRange: q.provenance?.pageRange,
  };
}
const legacy = [
  ['hcf-lcm-05-fractions', 'hcf_lcm_05_fractions.json', 4],
  ['hcf-lcm-07-number-construction', 'hcf_lcm_07_number_construction.json', 6],
  ['hcf-lcm-09-divisibility-bounds', 'hcf_lcm_09_divisibility_bounds.json', 8],
];
async function listQuestions() {
  const all = [];
  for (let page = 1; ; page++) {
    const data = await request(`/questions?limit=100&page=${page}`);
    all.push(...data.questions);
    if (all.length >= data.pagination.total || data.questions.length === 0) return all;
  }
}
async function main() {
  fs.mkdirSync(output, { recursive: true });
  const syllabus = await request('/syllabus');
  const subjects = syllabus.subjects;
  const topics = subjects.flatMap(s => s.topics);
  let subtopics = topics.flatMap(t => t.subtopics);
  const hcf = topics.find(t => t.name === 'H.C.F. and L.C.M. of Numbers');
  if (mode === 'subtopics') {
    for (const [key, file, sequence] of legacy) {
      if (subtopics.some(s => s.slug === key || s.id === key)) continue;
      const definition = JSON.parse(fs.readFileSync(path.join(root, 'books/SubTopics/SBT-RSA-02-HCF_and_LCM/Scripts', file)));
      const data = { id: key, slug: key, topicId: hcf.id, name: definition.metadata.title, description: definition.metadata.description, sequence };
      const result = await request('/syllabus/subtopics', 'POST', data);
      record({ action: 'create-subtopic', key, id: result.id });
      console.log('Created subtopic:', key);
    }
    return;
  }
  if (mode === 'repair-questions') {
    const existing = new Map((await listQuestions()).map(q => [q.externalKey, q]));
    let repaired = 0, pendingImport = 0;
    for (const row of banks()) {
      const payload = questionPayload(row, subtopics);
      const saved = existing.get(payload.externalKey);
      if (!saved) { pendingImport++; continue; }
      const changed = Object.keys(payload).filter(key => payload[key] !== undefined && JSON.stringify(saved[key]) !== JSON.stringify(payload[key]));
      if (!changed.length) continue;
      await request(`/questions/${saved.id}`, 'PUT', payload);
      record({ action: 'repair-question', key: payload.externalKey, id: saved.id, fields: changed });
      repaired++;
    }
    console.log(`Repaired ${repaired} question records to match reviewed source JSON; ${pendingImport} still pending import.`);
    return;
  }
  if (mode === 'questions') {
    const existing = await listQuestions();
    const byKey = new Map(existing.map(q => [q.externalKey, q]));
    const payloads = banks().map(q => questionPayload(q, subtopics));
    // Exercise the exact strict input validator with inert dependencies.
    const { loader } = require('../src/modules/pvp/tests/pvp-test-fixture.cjs');
    const { validateAdminQuestion } = loader({ '../../security/public-error': { publicFailure() {} } })(path.join(root, 'backend/src/modules/admin/admin-input.ts'));
    for (const payload of payloads) validateAdminQuestion(payload);
    const pending = payloads.filter(p => {
      const old = byKey.get(p.externalKey);
      if (!old) return true;
      for (const field of ['prompt', 'options', 'correctAnswer', 'subtopicId']) {
        if (JSON.stringify(old[field]) !== JSON.stringify(p[field])) throw new Error(`Existing question differs: ${p.externalKey} / ${field}`);
      }
      return false;
    });
    console.log(`Validated ${payloads.length}; existing ${existing.length}; pending ${pending.length}`);
    // Catalog writes serialize on the server. Two requests hide network latency
    // without creating unbounded pressure. Every successful ID is recorded.
    let cursor = 0, completed = 0, stopped = false;
    async function worker() {
      while (!stopped && cursor < pending.length) {
        const q = pending[cursor++];
        try {
          const result = await request('/questions', 'POST', q);
          record({ action: 'create-question', key: q.externalKey, id: result.id, subtopicId: result.subtopicId });
          completed++;
          if (completed % 50 === 0) console.log(`Created ${completed}/${pending.length}`);
        } catch (error) {
          stopped = true;
          record({ action: 'question-error', key: q.externalKey, status: error.status, message: error.message });
          throw error;
        }
      }
    }
    const results = await Promise.allSettled([worker(), worker()]);
    const failed = results.find(r => r.status === 'rejected');
    if (failed) throw failed.reason;
    console.log(`Created ${completed} questions.`, JSON.stringify(await request('/questions/stats')));
    return;
  }
  if (mode === 'scripts') {
    const jobs = fs.readdirSync(path.join(root, 'books/SubTopics/SBT-RSA-01-Number_System/Scripts')).filter(f => f.endsWith('.json')).sort().map(file => ({ folder: 'SBT-RSA-01-Number_System', file, key: file.slice(0, -5) }));
    jobs.push(...legacy.map(([key, file]) => ({ folder: 'SBT-RSA-02-HCF_and_LCM', key, file })));
    for (const { folder, file, key } of jobs) {
      const target = subtopics.find(s => s.slug === key || s.id === key);
      if (!target) throw new Error(`Missing script target: ${key}`);
      if (syllabus.scripts.some(s => s.subtopicId === target.id && s.status === 'PUBLISHED')) { console.log('Script already attached:', key); continue; }
      const definition = JSON.parse(fs.readFileSync(path.join(root, 'books/SubTopics', folder, 'Scripts', file)));
      const result = await request('/syllabus/scripts/import', 'POST', { topicId: target.topicId, subtopicId: target.id, definition, status: 'PUBLISHED' });
      record({ action: 'import-script', key, id: result.script.id, versionId: result.version.id });
      console.log('Attached script:', key);
    }
    return;
  }
  if (mode === 'verify') {
    const actual = await listQuestions();
    const expected = banks().map(q => questionPayload(q, subtopics));
    const byKey = new Map(actual.map(q => [q.externalKey, q]));
    const errors = [];
    for (const q of expected) {
      const saved = byKey.get(q.externalKey);
      if (!saved) { errors.push(`Missing question ${q.externalKey}`); continue; }
      for (const field of Object.keys(q)) {
        if (q[field] !== undefined && JSON.stringify(q[field]) !== JSON.stringify(saved[field])) errors.push(`${q.externalKey}: ${field} differs`);
      }
    }
    const gaps = topics.flatMap(t => t.subtopics.filter(st => !syllabus.scripts.some(s => s.subtopicId === st.id && s.status === 'PUBLISHED')).map(st => st.id));
    const { loader } = require('../src/modules/pvp/tests/pvp-test-fixture.cjs');
    const load = loader({ './learning-transaction': { prisma: {}, learningTransaction: () => null }, './redis.service': { redisService: {} } });
    const { scriptCacheService } = load(path.join(root, 'backend/src/modules/lesson/services/script-cache.service.ts'));
    const { ScriptValidator } = load(path.join(root, 'backend/src/modules/lesson/engines/script-validator.ts'));
    const restoredKeys = [
      ...fs.readdirSync(path.join(root, 'books/SubTopics/SBT-RSA-01-Number_System/Scripts')).filter(f => f.endsWith('.json')).map(f => f.slice(0, -5)),
      ...legacy.map(([key]) => key),
    ];
    const scriptErrors = [], verifiedScripts = [];
    for (const key of restoredKeys) {
      const attached = syllabus.scripts.find(s => s.subtopicId === key && s.status === 'PUBLISHED');
      if (!attached) { scriptErrors.push(`Missing script ${key}`); continue; }
      const details = await request(`/syllabus/scripts/${attached.id}`);
      const version = details.script.versions.find(v => v.id === details.script.publishedVersionId);
      if (!version || version.status !== 'PUBLISHED') { scriptErrors.push(`Missing published version ${key}`); continue; }
      const definition = scriptCacheService.normalizeScriptDefinition(version.definition);
      const validation = ScriptValidator.validate(definition);
      if (!validation.valid) scriptErrors.push(`${key}: ${JSON.stringify(validation.errors)}`);
      if (key !== 'ns-01-place-value-notation') {
        const sourceFile = key.startsWith('ns-')
          ? path.join(root, 'books/SubTopics/SBT-RSA-01-Number_System/Scripts', key + '.json')
          : path.join(root, 'books/SubTopics/SBT-RSA-02-HCF_and_LCM/Scripts', legacy.find(([id]) => id === key)[1]);
        const expectedDef = scriptCacheService.normalizeScriptDefinition(JSON.parse(fs.readFileSync(sourceFile)));
        if (!same(Object.keys(expectedDef.nodes).sort(), Object.keys(definition.nodes).sort()) || expectedDef.entryNodeId !== definition.entryNodeId)
          scriptErrors.push(`${key}: stored graph differs from reviewed source`);
        for (const node of Object.values(expectedDef.nodes)) {
          const saved = definition.nodes[node.id];
          if (!saved || saved.type !== node.type || !same(saved.transitions, node.transitions))
            scriptErrors.push(`${key}/${node.id}: stored node or transitions differ`);
          if (node.questionReference?.mode === 'INLINE' && !same(saved?.questionReference, node.questionReference))
            scriptErrors.push(`${key}/${node.id}: inline question differs from reviewed source`);
        }
      }
      for (const node of Object.values(definition.nodes)) {
        const ref = node.questionReference;
        if (ref?.mode !== 'QUESTION_EXTERNAL_ID') continue;
        const bank = byKey.get(ref.externalId);
        if (!bank || bank.subtopicId !== attached.subtopicId || ref.questionId !== bank.id) {
          scriptErrors.push(`${key}/${node.id}: question reference or hierarchy mismatch`); continue;
        }
        if (ref.inlineData.prompt !== bank.prompt || ref.inlineData.correctOptionId !== bank.correctAnswer ||
            JSON.stringify(ref.inlineData.options.map(o => ({ id: o.id, text: o.label }))) !== JSON.stringify(bank.options)) {
          scriptErrors.push(`${key}/${node.id}: pinned question snapshot differs`);
        }
      }
      verifiedScripts.push({ subtopicKey: key, scriptId: attached.id, versionId: version.id, nodes: Object.keys(definition.nodes).length });
    }
    const summary = { verifiedAt: stamp(), expectedQuestions: expected.length, actualQuestions: actual.length, questionErrors: errors, missingPublishedScripts: gaps,
      scriptErrors, verifiedScripts,
      publishedScripts: syllabus.scripts.filter(s => s.status === 'PUBLISHED').length,
      topicCounts: topics.map(t => ({ topic: t.name, subtopics: t.subtopics.length, questions: actual.filter(q => q.topicId === t.id).length })), stats: await request('/questions/stats') };
    fs.writeFileSync(path.join(output, 'production-verification.json'), JSON.stringify(summary, null, 2) + '\n');
    console.log(JSON.stringify({
      verifiedAt: summary.verifiedAt, expectedQuestions: expected.length, actualQuestions: actual.length,
      questionErrors: errors, missingPublishedScripts: gaps, scriptErrors,
      publishedScripts: summary.publishedScripts, inspectedScripts: verifiedScripts.length,
      populatedTopics: summary.topicCounts.filter(t => t.questions > 0), sources: summary.stats.bySource,
    }, null, 2));
    if (errors.length || gaps.length || scriptErrors.length || actual.length !== expected.length) process.exitCode = 1;
    return;
  }
  console.log(JSON.stringify({ uniqueSavedQuestions: banks().length, missingScripts: topics.flatMap(t => t.subtopics.filter(s => !syllabus.scripts.some(x => x.subtopicId === s.id)).map(s => s.id)) }, null, 2));
}
main().catch(error => { console.error(error.message); process.exitCode = 1; });
