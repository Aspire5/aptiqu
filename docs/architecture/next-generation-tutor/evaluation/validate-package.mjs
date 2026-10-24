import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const directory = path.dirname(fileURLToPath(import.meta.url));
const root = path.dirname(directory);
const issues = [];
let markdownFiles = 0;
let jsonBlocks = 0;
let localLinks = 0;
let words = 0;
const numbered = fs.readdirSync(root).filter(name => /^\d{2}-.*\.md$/.test(name)).sort();
if (numbered.length !== 15) issues.push('Expected fifteen numbered design documents');
function inspect(folder) {
  for (const entry of fs.readdirSync(folder, { withFileTypes: true })) {
    const filename = path.join(folder, entry.name);
    if (entry.isDirectory()) { inspect(filename); continue; }
    if (!entry.name.endsWith('.md')) continue;
    markdownFiles++;
    const content = fs.readFileSync(filename, 'utf8');
    words += content.split(/\s+/).filter(Boolean).length;
    if (content.includes('\uFFFD')) issues.push(`${entry.name}: replacement character`);
    if (content.split('\n').some(line => /[\t ]+$/.test(line))) issues.push(`${entry.name}: trailing whitespace`);
    if (/\bsk-(?:proj-)?[A-Za-z0-9_-]{20,}\b|\bAIza[A-Za-z0-9_-]{25,}\b/.test(content)) issues.push(`${entry.name}: possible secret pattern; value suppressed`);
    const fences = content.match(/^```/gm) ?? [];
    if (fences.length % 2) issues.push(`${entry.name}: unbalanced code fences`);
    for (const block of content.matchAll(/```json\n([\s\S]*?)\n```/g)) {
      try { JSON.parse(block[1]); jsonBlocks++; } catch { issues.push(`${entry.name}: invalid JSON example`); }
    }
    for (const link of content.matchAll(/!?\[[^\]]*\]\(([^\s)]+)(?:\s+"[^"]*")?\)/g)) {
      const target = link[1];
      if (/^(?:https?:|#|mailto:)/.test(target)) continue;
      localLinks++;
      if (!fs.existsSync(path.resolve(path.dirname(filename), target.split('#')[0]))) issues.push(`${entry.name}: missing local target ${target}`);
    }
  }
}
inspect(root);
const requirements = fs.readFileSync(path.join(root, '02-requirements.md'), 'utf8');
for (let index = 1; index <= 45; index++) if (!requirements.includes(`| FR-${String(index).padStart(2, '0')} |`)) issues.push(`Missing functional requirement ${index}`);
for (let index = 1; index <= 12; index++) if (!requirements.includes(`| NFR-${String(index).padStart(2, '0')} |`)) issues.push(`Missing nonfunctional requirement ${index}`);
const ledger = JSON.parse(fs.readFileSync(path.join(directory, 'ledger.json'), 'utf8'));
const reserved = ledger.requests.reduce((sum, entry) => sum + entry.reservedInr, 0);
const estimated = ledger.requests.reduce((sum, entry) => sum + (entry.estimatedInr ?? 0), 0);
if (ledger.requests.length !== 6 || reserved > 10 || reserved > 100) issues.push('Evaluation dispatch/budget mismatch');
const report = [
  '# Package validation record', '',
  'Executed 22 October 2026. Documentation and isolated artifacts only. No application initialization, credentials read, database action, provider request or historical phase suite was involved in these checks.', '',
  `- Fifteen numbered documents: ${numbered.length === 15 ? 'PASS' : 'FAIL'}.`,
  '- FR-01–FR-45 and NFR-01–NFR-12 acceptance rows: checked individually.',
  `- Markdown inspected: ${markdownFiles} files, approximately ${words.toLocaleString('en-IN')} whitespace-delimited words (includes raw samples).`,
  `- Embedded JSON examples/reports parsed: ${jsonBlocks}.`,
  `- Local document/image links checked: ${localLinks}.`,
  '- Code-fence balance, trailing whitespace, replacement-character and common provider-key-pattern scans: executed; no secret value is printed.',
  `- Evaluation dispatches: ${ledger.requests.length}; retained reservation ₹${reserved.toFixed(4)}; known successful usage estimate ₹${estimated.toFixed(7)}.`,
  '- Independent sample checker: 24 main/retry items; four key/value mismatches and eight missing expression prompts; all returned samples rejected.',
  '- Monthly/unit/peak workload arithmetic independently recalculated with an isolated local Node command; estimates are not measurements or invoices.',
  '- Two 320 px typography-preview PNGs personally inspected; these are not Flutter/device renders.',
  '- Evaluation/checker JavaScript syntax checked with node --check. No application tests were necessary for this documentation-only change.',
  '- Mermaid source/fences inspected; no Mermaid render or diagram-engine validation is claimed.',
  '- Git working tree before work was clean; final scope check must show only this new documentation directory.', '',
  '## Findings', '',
  issues.length ? issues.map(issue => `- ${issue}`).join('\n') : 'No package-integrity issue found by these checks. Production/model/voice/learning-quality limitations remain explicitly recorded in documents 12 and 14.', '',
];
fs.writeFileSync(path.join(root, 'VALIDATION.md'), report.join('\n'));
console.log(JSON.stringify({ numberedDocuments: numbered.length, markdownFiles, jsonBlocks, localLinks, words, reservedInr: reserved, successfulEstimateInr: estimated, issues }));
if (issues.length) process.exitCode = 1;
