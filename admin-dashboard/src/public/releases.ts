import changelog from '../../../CHANGELOG.md?raw';

// Keep the public timeline derived from the canonical Markdown, never a second history.
export const milestones = [...changelog.matchAll(/^## \[(0\.\d+\.\d+)\] — (\d{4}-\d{2}-\d{2}) · (.+)\n([\s\S]*?)(?=^## |$(?![\s\S]))/gm)].map((match) => ({
  version: match[1],
  date: match[2],
  title: match[3],
  highlights: [...match[4].matchAll(/^- (.+)$/gm)].map((bullet) => bullet[1]),
}));
