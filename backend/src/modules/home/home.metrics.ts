export interface Counts { attempted: number; correct: number; timed: number; timeMs: number }
export function performance(rows: Counts[]) {
  const totals = rows.reduce((a, r) => ({ attempted: a.attempted + r.attempted,
    correct: a.correct + r.correct, timed: a.timed + r.timed, timeMs: a.timeMs + r.timeMs }),
    { attempted: 0, correct: 0, timed: 0, timeMs: 0 });
  return { ...totals, accuracy: totals.attempted ? totals.correct / totals.attempted : null,
    averageSolveTimeMs: totals.timed ? totals.timeMs / totals.timed : null };
}
export const badgeCatalog = [
  { id: 'first_answer', title: 'First step', description: 'Submit your first answer', target: 1 },
  { id: 'correct_25', title: 'Finding your stride', description: 'Get 25 answers correct', target: 25 },
  { id: 'hard_10', title: 'Challenge seeker', description: 'Get 10 hard answers correct', target: 10 },
] as const;
export function dateKey(now: Date) {
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Kolkata', year: 'numeric', month: '2-digit', day: '2-digit' }).format(now);
}
export function calendar(today: string, stored: { date: string; attempted: number; correct: number }[]) {
  const byDate = new Map(stored.map(d => [d.date, d]));
  const end = new Date(`${today}T00:00:00Z`);
  return Array.from({ length: 28 }, (_, i) => {
    const day = new Date(end.getTime() - (27 - i) * 86400000).toISOString().slice(0, 10);
    return byDate.get(day) ?? { date: day, attempted: 0, correct: 0 };
  });
}
