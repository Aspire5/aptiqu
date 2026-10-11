const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require('typescript');
const { Prisma } = require('@prisma/client');

// Execute the production selector with isolated dependencies. No database, Redis,
// queues, or AI connections are constructed or accessed by these tests.
function setup(batches, progress = []) {
  const questions = Array.from({length: 15}, (_, i) => ({id: 'q'+i, subtopicId: 's1', pattern: 'addition'}));
  let generated = 0, progressCalls = 0;
  const queries = [];
  const prisma = {
    $queryRaw: async sql => { if (sql.sql.includes('WITH performance')) { progressCalls++; return progress.map(p=>({...p.question, timesSeen:p.timesSeen, timesCorrect:p.timesCorrect})); } queries.push(sql); return (batches.shift() || []).map(id => ({id})); },
    question: {findMany: async args => questions.filter(q => args.where.id.in.includes(q.id))},
    userQuestionProgress: {findMany: async () => { progressCalls++; return progress; }},
  };
  const deps = {
    '@prisma/client': {Prisma},
    '../../../config/prisma': {prisma},
    '../../ai/services/question-generation.service': {questionGenerationService: {generateQuestionsForSubtopic: async (id, count, pattern) => { generated++; assert.equal(id, 's1'); assert.equal(pattern, 'addition'); return [{id:'new', subtopicId: id, pattern}]; }}},
    '../../curriculum/services/live-curriculum.service': {LiveCurriculumService: {getAllLiveCurriculumUniverse: async () => [{subtopics:[{id:'s1'},{id:'s2'}]}]}},
  };
  const filename = path.join(__dirname, '../services/practice-selection.service.ts');
  const source = ts.transpileModule(fs.readFileSync(filename,'utf8'), {compilerOptions:{module:ts.ModuleKind.CommonJS, target:ts.ScriptTarget.ES2022}}).outputText;
  const exports = {};
  vm.runInNewContext(source, {exports, require: id => { assert.ok(id in deps, 'Unexpected dependency '+id); return deps[id]; }, console, Math, Set, Map});
  return {service: exports.practiceSelectionService, queries, generated: () => generated, progressCalls: () => progressCalls};
}
const ids = n => Array.from({length:n}, (_, i) => 'q'+i);
test('random mode draws ten unseen questions without AI or weakness queries', async () => {
  const s=setup([ids(10)]); const result=await s.service.selectQuestionsForPractice('user',['s1','s2']);
  assert.equal(result.length,10); assert.equal(new Set(result.map(q=>q.id)).size,10);
  assert.equal(s.generated(),0); assert.equal(s.progressCalls(),0);
  const sql=s.queries[0].sql;
  assert.ok(sql.includes('ORDER BY random() LIMIT')); 
  assert.match(sql,/question_attempts/); assert.match(sql,/practice_session_questions/); assert.match(sql,/pvp_match_answers/);
  assert.doesNotMatch(sql,/difficulty =|source_type =/);
});
test('existing repeats fill a shortage without automatic AI', async () => {
  const s=setup([ids(7),['q7','q8','q9']]); const result=await s.service.selectQuestionsForPractice('user',['s1']);
  assert.equal(result.length,10); assert.equal(s.generated(),0);
  assert.match(s.queries[1].sql,/q.id NOT IN/); assert.doesNotMatch(s.queries[1].sql,/NOT EXISTS/);
});
test('custom shortage rejects rather than returning fewer or broadening scope', async () => {
  const s=setup([ids(3),[]]); await assert.rejects(()=>s.service.selectQuestionsForPractice('user',['s1']),/at least 10/);
  assert.equal(s.generated(),0); assert.ok(s.queries.every(q=>!q.values.includes('s2')));
});
test('smart picks target weak patterns and generate a bounded variation only on shortage', async () => {
  const s=setup([[],ids(9)], [{timesSeen:4,timesCorrect:1,question:{subtopicId:'s1',pattern:'addition'}}]);
  const result=await s.service.selectQuestionsForPractice('user',['s1'],10,true);
  assert.equal(result.length,10); assert.equal(s.generated(),1); assert.ok(result.some(q=>q.id==='new'));
  assert.match(s.queries[0].sql,/q.pattern =/);
});
test('smart picks without performance history stay random and never invent targets', async () => {
  const s=setup([ids(10)]); await s.service.selectQuestionsForPractice('user',['s1'],10,true);
  assert.equal(s.generated(),0);
});
test('locked scope and non-ten counts are rejected', async () => {
  const s=setup([]); await assert.rejects(()=>s.service.selectQuestionsForPractice('user',['locked']),/available subtopics/);
  await assert.rejects(()=>s.service.selectQuestionsForPractice('user',['s1'],5),/exactly 10/);
  assert.equal(s.queries.length,0);
});
