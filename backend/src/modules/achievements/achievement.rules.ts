import { AchievementMetric, AchievementSource } from '@prisma/client';
import { z } from 'zod';
import { HomeStatsRow } from '../home/home.queries';

export const achievementInput = z.object({
  title: z.string().trim().min(1).max(120),
  description: z.string().trim().min(1).max(500),
  metric: z.nativeEnum(AchievementMetric),
  source: z.nativeEnum(AchievementSource),
  difficulty: z.enum(['EASY', 'MEDIUM', 'HARD']).nullable(),
  target: z.number().int().min(1).max(2147483647),
  sortOrder: z.number().int().min(0).max(2147483647),
  isActive: z.boolean(),
}).strict().superRefine((value, ctx) => {
  if (!['ATTEMPTED', 'CORRECT'].includes(value.metric) && (value.source !== 'ALL' || value.difficulty !== null)) {
    ctx.addIssue({ code: 'custom', message: 'Source and difficulty filters apply only to answer metrics.' });
  }
});
export const achievementUpdate = achievementInput.innerType().extend({ version: z.number().int().positive() })
  .superRefine((value, ctx) => {
    if (!['ATTEMPTED', 'CORRECT'].includes(value.metric) && (value.source !== 'ALL' || value.difficulty !== null)) {
      ctx.addIssue({ code: 'custom', message: 'Source and difficulty filters apply only to answer metrics.' });
    }
  });
export const achievementOptions = {
  metrics: Object.values(AchievementMetric), sources: Object.values(AchievementSource),
  difficulties: ['EASY', 'MEDIUM', 'HARD'],
};
export type Rule = z.infer<typeof achievementInput>;

export function achievementProgress(rule: Pick<Rule, 'metric' | 'source' | 'difficulty' | 'target'>,
  rows: HomeStatsRow[], facts: { dailyCompleted: number; pvpWins: number; bestStreak: number }) {
  let value: number;
  if (rule.metric === 'DAILY_COMPLETED') value = facts.dailyCompleted;
  else if (rule.metric === 'PVP_WINS') value = facts.pvpWins;
  else if (rule.metric === 'BEST_STREAK') value = facts.bestStreak;
  else value = rows.filter(row => row.kind === 'source'
    && (rule.source === 'ALL' || row.source === rule.source)
    && (rule.difficulty === null || row.difficulty === rule.difficulty))
    .reduce((total, row) => total + (rule.metric === 'ATTEMPTED' ? row.attempted : row.correct), 0);
  const progress = Math.min(rule.target, Math.max(0, value));
  return { progress, unlocked: progress >= rule.target };
}
