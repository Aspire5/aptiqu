const fs = require('fs');
const input = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const nodes = {};
const tutor = (text) => ({ text, avatarPersona: 'TUTOR' });
function choice(id, q, next, remedial) {
  const options = q.options.map(([id, label]) => ({ id, label }));
  const transitions = remedial
    ? [{ targetNodeId: next, condition: { field: 'isCorrect', operator: 'EQUALS', value: true } }, { targetNodeId: remedial, condition: { field: 'isCorrect', operator: 'EQUALS', value: false } }]
    : [{ targetNodeId: next }];
  return { id, type: 'CHOICE', content: tutor(q.prompt), input: { type: 'CHOICE', options }, transitions, questionReference: { mode: 'INLINE', inlineData: { prompt: q.prompt, questionType: 'PRACTICE', correctOptionId: q.answer, options, hints: q.hints, explanation: q.explanation, difficulty: 'MEDIUM', xp: 10 } } };
}
nodes.start = { id: 'start', type: 'CONTENT', content: tutor(input.opening), transitions: [{ targetNodeId: input.lessons[0].id }] };
for (let i = 0; i < input.lessons.length; i++) {
  const lesson = input.lessons[i];
  if (!lesson.q || !lesson.q.retry) throw new Error(`Lesson ${lesson.id} needs q and q.retry`);
  const next = input.lessons[i + 1]?.id || 'final_recap';
  const qid = `q_${lesson.id}`, remedialId = `remedy_${lesson.id}`, retryId = `retry_${lesson.id}`;
  nodes[lesson.id] = { id: lesson.id, type: 'CONTENT', content: tutor(lesson.text), transitions: [{ targetNodeId: qid }] };
  nodes[qid] = choice(qid, lesson.q, next, remedialId);
  nodes[remedialId] = { id: remedialId, type: 'CONTENT', content: tutor(lesson.remedy), transitions: [{ targetNodeId: retryId }] };
  nodes[retryId] = choice(retryId, lesson.q.retry, next, null);
}
nodes.final_recap = { id: 'final_recap', type: 'COMPLETION', content: tutor(input.recap), transitions: [] };
const out = { schemaVersion: 1, scriptId: `script-${input.key}`, version: 1, sourceType: 'MANUAL', entryNodeId: 'start', metadata: { title: input.title, description: input.description, targetDurationMinutes: input.duration, teachingApproach: input.approach, sourceScope: input.sourceScope }, nodes };
const output = `books/SubTopics/SBT-RSA-03-Decimal_Fractions/Scripts/${input.key}.json`;
fs.writeFileSync(output, JSON.stringify(out, null, 2) + '\n', 'utf8');
console.log(`${output}: ${Object.keys(nodes).length} nodes, ${Object.values(nodes).filter(n => n.type === 'CHOICE').length} choice nodes`);
