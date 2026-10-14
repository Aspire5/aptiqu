import { Prisma } from '@prisma/client';
import { prisma } from '../../config/prisma';
import { homeStatsQuery, HomeStatsRow } from '../home/home.queries';
import { achievementProgress, Rule } from './achievement.rules';

export interface AchievementFacts {
  dailyCompleted: number; pvpWins: number; bestStreak: number; dailyDates: string[];
}
export function achievementFactsQuery(userId: string, start: string, today: string) {
  return Prisma.sql`
    SELECT (SELECT count(*)::float8 FROM learning.daily_challenge_participations
      WHERE user_id = ${userId}::uuid AND status = 'COMPLETED') AS "dailyCompleted",
      (SELECT count(*)::float8 FROM learning.pvp_match_players p
        JOIN learning.pvp_matches m ON m.id = p.match_id
        WHERE p.user_id = ${userId}::uuid AND p.is_winner AND NOT m.is_tie AND m.status = 'COMPLETED') AS "pvpWins",
      COALESCE((SELECT highest_streak FROM gamification.stats WHERE user_id = ${userId}::uuid), 0) AS "bestStreak",
      COALESCE((SELECT jsonb_agg(date_string ORDER BY date_string)
        FROM learning.daily_challenge_participations
        WHERE user_id = ${userId}::uuid AND status = 'COMPLETED'
          AND date_string BETWEEN ${start} AND ${today}), '[]'::jsonb) AS "dailyDates"`;
}
export function presentAchievements(definitions: (Rule & { id: string })[], stats: HomeStatsRow[], facts: AchievementFacts) {
  return definitions.map(rule => ({ id: rule.id, title: rule.title, description: rule.description,
    target: rule.target, ...achievementProgress(rule, stats, facts) }));
}
export const liveAchievementWhere = { isActive: true, deletedAt: null };
export const achievementOrder = [{ sortOrder: 'asc' as const }, { id: 'asc' as const }];

export async function userAchievements(userId: string, page: number, limit: number) {
  const [stats, facts, definitions, total] = await prisma.$transaction([
    prisma.$queryRaw<HomeStatsRow[]>(homeStatsQuery(userId, '1970-01-01', '1970-01-01')),
    prisma.$queryRaw<AchievementFacts[]>(achievementFactsQuery(userId, '1970-01-01', '1970-01-01')),
    prisma.achievement.findMany({ where: liveAchievementWhere, orderBy: achievementOrder,
      skip: (page - 1) * limit, take: limit }),
    prisma.achievement.count({ where: liveAchievementWhere }),
  ], { isolationLevel: 'RepeatableRead' });
  return { items: presentAchievements(definitions, stats, facts[0]), total, page, limit, hasMore: page * limit < total };
}
