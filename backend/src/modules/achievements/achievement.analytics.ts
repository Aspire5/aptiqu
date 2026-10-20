import { Prisma } from '@prisma/client';
import { homeSubmissions } from '../home/home.queries';

// Read each source once, then compress user progress into distributions before
// joining definitions. No users x achievements Cartesian product or N+1 reads.
export function achievementAnalyticsQuery(page: number, limit: number, search: string, status: string) {
  const filter = status === 'ACTIVE' ? Prisma.sql`a.deleted_at IS NULL AND a.is_active`
    : status === 'ARCHIVED' ? Prisma.sql`a.deleted_at IS NOT NULL` : Prisma.sql`TRUE`;
  const term = `%${search.replace(/[\\%_]/g, '\\$&')}%`;
  return Prisma.sql`
    WITH selected_definitions AS (SELECT * FROM gamification.achievements a WHERE ${filter} AND (a.title ILIKE ${term} OR a.description ILIKE ${term})),
    eligible AS (SELECT id FROM auth.users WHERE is_registration_complete),
    source_answers AS (${homeSubmissions()}),
    submissions AS (SELECT *, CASE WHEN difficulty IN ('EASY', 'MEDIUM', 'HARD')
      THEN difficulty ELSE 'UNKNOWN' END AS normalized_difficulty FROM source_answers WHERE EXISTS (SELECT 1 FROM selected_definitions WHERE metric IN ('ATTEMPTED','CORRECT'))),
    answer_totals AS (
      SELECT s.user_id,
        CASE WHEN GROUPING(s.source) = 1 THEN 'ALL' ELSE s.source END AS source,
        CASE WHEN GROUPING(s.normalized_difficulty) = 1 THEN 'ANY' ELSE s.normalized_difficulty END AS difficulty,
        count(*) AS attempted, sum(s.correct) AS correct
      FROM submissions s JOIN eligible e ON e.id = s.user_id
      GROUP BY GROUPING SETS ((s.user_id, s.source, s.normalized_difficulty),
        (s.user_id, s.source), (s.user_id, s.normalized_difficulty), (s.user_id))
    ), user_metrics AS (
      SELECT t.user_id, v.metric, t.source, t.difficulty, v.value
      FROM answer_totals t CROSS JOIN LATERAL
        (VALUES ('ATTEMPTED', t.attempted), ('CORRECT', t.correct)) v(metric, value)
      UNION ALL
      SELECT p.user_id, 'DAILY_COMPLETED', 'ALL', 'ANY', count(*)
      FROM learning.daily_challenge_participations p JOIN eligible e ON e.id = p.user_id
      WHERE p.status = 'COMPLETED' AND EXISTS(SELECT 1 FROM selected_definitions WHERE metric='DAILY_COMPLETED') GROUP BY p.user_id
      UNION ALL
      SELECT p.user_id, 'PVP_WINS', 'ALL', 'ANY', count(*)
      FROM learning.pvp_match_players p JOIN learning.pvp_matches m ON m.id = p.match_id
      JOIN eligible e ON e.id = p.user_id
      WHERE m.status = 'COMPLETED' AND p.is_winner AND NOT m.is_tie AND EXISTS(SELECT 1 FROM selected_definitions WHERE metric='PVP_WINS') GROUP BY p.user_id
      UNION ALL
      SELECT s.user_id, 'BEST_STREAK', 'ALL', 'ANY', s.highest_streak::bigint
      FROM gamification.stats s JOIN eligible e ON e.id = s.user_id WHERE EXISTS(SELECT 1 FROM selected_definitions WHERE metric='BEST_STREAK')
    ), distribution AS (
      SELECT metric, source, difficulty, value, count(*) AS users
      FROM user_metrics WHERE value > 0 GROUP BY metric, source, difficulty, value
    ), analytics AS (
      SELECT a.*,
        COALESCE(sum(d.users) FILTER (WHERE d.value >= a.target), 0)::float8 AS completed,
        COALESCE(sum(d.users) FILTER (WHERE d.value < a.target), 0)::float8 AS "inProgress",
        (SELECT count(*)::float8 FROM eligible) AS "eligibleUsers"
      FROM selected_definitions a
      LEFT JOIN distribution d ON d.metric = a.metric::text AND d.source = a.source::text
        AND d.difficulty = COALESCE(a.difficulty::text, 'ANY')
      GROUP BY a.id,a.title,a.description,a.metric,a.source,a.difficulty,a.target,a.sort_order,a.is_active,a.deleted_at,a.version,a.created_at,a.updated_at
    ), result AS (
      SELECT id, title, description, metric, source, difficulty, target,
        sort_order AS "sortOrder", is_active AS "isActive", deleted_at AS "deletedAt",
        version, updated_at AS "updatedAt", completed, "inProgress", "eligibleUsers",
        "eligibleUsers" - completed - "inProgress" AS "notStarted"
      FROM analytics
    ), page_rows AS (
      SELECT * FROM result ORDER BY "sortOrder", id LIMIT ${limit} OFFSET ${(page - 1) * limit}
    )
    SELECT jsonb_build_object(
      'items', COALESCE((SELECT jsonb_agg(to_jsonb(p) ORDER BY p."sortOrder", p.id) FROM page_rows p), '[]'::jsonb),
      'total', (SELECT count(*) FROM result),
      'overall', jsonb_build_object(
        'definitions', (SELECT count(*) FROM result),
        'eligibleUsers', (SELECT count(*) FROM eligible),
        'completed', (SELECT COALESCE(sum(completed), 0) FROM result),
        'inProgress', (SELECT COALESCE(sum("inProgress"), 0) FROM result)
      )) AS payload`;
}
