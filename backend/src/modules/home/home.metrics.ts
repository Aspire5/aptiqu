export interface Counts { attempted: number; correct: number; timed: number; timeMs: number }
export function performance(rows: Counts[]) {
  const totals = rows.reduce((a, r) => ({ attempted: a.attempted + r.attempted,
    correct: a.correct + r.correct, timed: a.timed + r.timed, timeMs: a.timeMs + r.timeMs }),
    { attempted: 0, correct: 0, timed: 0, timeMs: 0 });
  return { ...totals, accuracy: totals.attempted ? totals.correct / totals.attempted : null,
    averageSolveTimeMs: totals.timed ? totals.timeMs / totals.timed : null };
}
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

// Bounded payload: at most 366 daily aggregates, never raw attempts.
export function yearCalendar(today: string, stored: { date: string; attempted: number; correct: number }[]) {
  const byDate = new Map(stored.map(d => [d.date, d]));
  const year = Number(today.slice(0, 4));
  const start = Date.UTC(year, 0, 1), end = Date.UTC(year + 1, 0, 1);
  return Array.from({ length: (end - start) / 86400000 }, (_, i) => {
    const date = new Date(start + i * 86400000).toISOString().slice(0, 10);
    return byDate.get(date) ?? { date, attempted: 0, correct: 0 };
  });
}
