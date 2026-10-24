import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const directory = path.dirname(fileURLToPath(import.meta.url));
function greatestCommonDivisor(left, right) {
  while (right) [left, right] = [right, left % right];
  return left < 0n ? -left : left;
}
function fraction(numerator, denominator = 1n) {
  if (!denominator) throw new Error('ZERO_DIVISOR');
  const divisor = greatestCommonDivisor(numerator, denominator);
  const sign = denominator < 0n ? -1n : 1n;
  return [numerator / divisor * sign, denominator / divisor * sign];
}
function combine(left, operator, right) {
  const [leftNumerator, leftDenominator] = left;
  const [rightNumerator, rightDenominator] = right;
  if (operator === '+') return fraction(leftNumerator * rightDenominator + rightNumerator * leftDenominator, leftDenominator * rightDenominator);
  if (operator === '-') return fraction(leftNumerator * rightDenominator - rightNumerator * leftDenominator, leftDenominator * rightDenominator);
  if (operator === '*') return fraction(leftNumerator * rightNumerator, leftDenominator * rightDenominator);
  return fraction(leftNumerator * rightDenominator, leftDenominator * rightNumerator);
}
function evaluate(expression) {
  const normalized = expression.replaceAll('×', '*').replaceAll('÷', '/').replaceAll('−', '-').replace(/\s+/g, '');
  if (!/^\d+(?:[+*/-]\d+)*$/.test(normalized)) throw new Error('UNSUPPORTED_GRAMMAR');
  const tokens = normalized.match(/\d+|[+*/-]/g);
  let cursor = 0;
  function product() {
    let value = fraction(BigInt(tokens[cursor++]));
    while (['*', '/'].includes(tokens[cursor])) value = combine(value, tokens[cursor++], fraction(BigInt(tokens[cursor++])));
    return value;
  }
  let value = product();
  while (cursor < tokens.length) value = combine(value, tokens[cursor++], product());
  return value[1] === 1n ? String(value[0]) : `${value[0]}/${value[1]}`;
}
const known = [
  ['18 ÷ 3 × 2', '28 ÷ 7 × 3'],
  ['48 ÷ 4 ÷ 3', '60 ÷ 5 ÷ 3'],
  ['6 × 8 ÷ 4', '7 × 6 ÷ 3'],
  ['30 − 24 ÷ 4 × 2 + 5', '40 − 36 ÷ 6 × 3 + 2'],
];
const lines = ['# Offline evaluation checks', '', 'This checks a deliberately limited four-operation positive-integer grammar with exact rational arithmetic, never JavaScript eval. It is not the proposed production verifier or a teaching-quality certification.', ''];
let itemCount = 0;
let mismatches = 0;
let missingPrompts = 0;
for (const filename of fs.readdirSync(directory).filter(name => /^sample-.*\.md$/.test(name)).sort()) {
  const sample = JSON.parse(fs.readFileSync(path.join(directory, filename), 'utf8').match(/```json\n([\s\S]*?)\n```/)[1]);
  const screens = sample.screens;
  const ids = screens.map(screen => screen.id);
  if (new Set(ids).size !== ids.length) throw new Error('DUPLICATE_SCREEN_ID');
  lines.push(`## ${filename}`, '', `JSON parsed; ${screens.length} uniquely identified screens; ${screens.filter(screen => screen.kind === 'check').length} main checks.`, '', '| Item | Expression in prompt | Independently evaluated value | Stored key / labelled value | Result |', '|---|---|---|---|---|');
  const counts = { a: 0, b: 0, c: 0, d: 0 };
  const revised = filename.startsWith('sample-6-');
  screens.filter(screen => screen.kind === 'check').forEach((screen, checkIndex) => {
    for (const [variantIndex, item] of [screen, screen.retry].entries()) {
      itemCount++;
      const prompt = variantIndex ? item.prompt : item.text;
      const match = prompt.match(/\d+(?:\s*[×÷+−-]\s*\d+)+/);
      const expression = match?.[0] ?? (revised ? known[checkIndex][variantIndex] : null);
      if (!expression) throw new Error('NO_EVALUATABLE_FIXTURE');
      const expected = evaluate(expression);
      const selected = item.options.find(option => option.id === item.correctOptionId);
      const matching = item.options.filter(option => evaluate(option.label) === expected);
      const keyValid = selected && evaluate(selected.label) === expected && matching.length === 1;
      if (!keyValid) mismatches++;
      if (!match) missingPrompts++;
      counts[item.correctOptionId]++;
      const result = [keyValid ? 'key agrees' : 'BLOCK: answer mismatch', match ? 'prompt present' : 'BLOCK: expression missing'].join('; ');
      lines.push(`| ${screen.id}${variantIndex ? ' retry' : ''} | ${match ? expression : 'MISSING; expected fixture: ' + expression} | ${expected} | ${item.correctOptionId} / ${selected?.label ?? 'missing'} | ${result} |`);
    }
  });
  lines.push('', `Stored answer positions across all eight items: ${Object.entries(counts).map(([key, count]) => `${key.toUpperCase()}=${count}`).join(', ')}.`, '', 'Other language, reasoning, scope, repetition, analogy and phone-layout findings require the manual review in document 12.', '');
}
lines.push('## Totals', '', `${itemCount} main/retry items inspected; ${mismatches} stored-key/value mismatches; ${missingPrompts} prompts missing their expression. No sample is release-approved.`, '');
fs.writeFileSync(path.join(directory, 'OFFLINE_CHECKS.md'), lines.join('\n'));
console.log(JSON.stringify({ itemCount, mismatches, missingPrompts, report: 'OFFLINE_CHECKS.md', networkCalls: 0, secretsRead: false }));
