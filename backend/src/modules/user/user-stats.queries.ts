import { Prisma } from '@prisma/client';

// CACHE CANDIDATE: public inventory totals only, keyed by a committed catalog revision.
// Keep uncached until publication invalidation is explicit; solved counts are private and must stay user-scoped.
export function questionStatsQuery(userId:string) {
  return Prisma.sql`
  WITH published_versions AS (
    SELECT DISTINCT ON (s.id) s.id AS script_id,v.definition
    FROM learning.lesson_scripts s JOIN learning.lesson_script_versions v ON v.script_id=s.id
    WHERE s.status='PUBLISHED' AND v.status='PUBLISHED' ORDER BY s.id,v.version_number DESC
  ), definitions AS (
    SELECT script_id,COALESCE(definition->'script',definition->'subtopic'->'script',definition)->'nodes' AS nodes FROM published_versions
  ), nodes AS (
    SELECT d.script_id,n.key AS node_id,n.value AS node FROM definitions d
    CROSS JOIN LATERAL jsonb_each(CASE WHEN jsonb_typeof(d.nodes)='object' THEN d.nodes ELSE '{}'::jsonb END) n
    UNION ALL
    SELECT d.script_id,n.value->>'id',n.value FROM definitions d
    CROSS JOIN LATERAL jsonb_array_elements(CASE WHEN jsonb_typeof(d.nodes)='array' THEN d.nodes ELSE '[]'::jsonb END) n
  ), inline_inventory AS (
    SELECT n.script_id,n.node_id,COALESCE(n.node->'questionReference'->'inlineData'->>'difficulty','EASY') AS difficulty
    FROM nodes n WHERE n.node->>'type' IN ('QUESTION','CHOICE') AND n.node->'questionReference' IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM learning.questions q WHERE q.id::text=n.node->'questionReference'->>'questionId' OR q.external_key=n.node->'questionReference'->>'externalId')
  ), solved_ids AS (
    SELECT question_id FROM learning.question_attempts WHERE user_id=${userId}::uuid AND is_correct AND question_id IS NOT NULL
    UNION SELECT a.question_id FROM learning.practice_session_questions a JOIN learning.practice_sessions s ON s.id=a.session_id WHERE s.user_id=${userId}::uuid AND a.is_correct
    UNION SELECT a.question_id FROM learning.daily_challenge_answers a JOIN learning.daily_challenge_participations s ON s.id=a.participation_id WHERE s.user_id=${userId}::uuid AND a.is_correct
    UNION SELECT question_id FROM learning.pvp_match_answers WHERE user_id=${userId}::uuid AND is_correct
    UNION SELECT question_id FROM learning.user_question_progress WHERE user_id=${userId}::uuid AND times_correct>0
  ), inline_attempts AS (
    SELECT s.script_id,a.node_id,a.created_at,
      CASE WHEN jsonb_typeof(d.nodes)='object' THEN d.nodes->a.node_id
        WHEN jsonb_typeof(d.nodes)='array' THEN (SELECT value FROM jsonb_array_elements(d.nodes) WHERE value->>'id'=a.node_id LIMIT 1)
      END AS node
    FROM learning.question_attempts a JOIN learning.lesson_sessions s ON s.id=a.session_id
    JOIN learning.lesson_script_versions v ON v.id=s.script_version_id
    CROSS JOIN LATERAL (SELECT COALESCE(v.definition->'script',v.definition->'subtopic'->'script',v.definition)->'nodes' AS nodes) d
    WHERE a.user_id=${userId}::uuid AND a.is_correct AND a.question_id IS NULL
  ), solved_inline AS (
    SELECT DISTINCT ON (a.script_id,a.node_id) a.script_id,a.node_id,
      COALESCE(a.node->'questionReference'->'inlineData'->>'difficulty','EASY') AS difficulty
    FROM inline_attempts a WHERE a.node->>'type' IN ('QUESTION','CHOICE')
      AND NOT EXISTS (SELECT 1 FROM learning.questions q WHERE q.id::text=a.node->'questionReference'->>'questionId' OR q.external_key=a.node->'questionReference'->>'externalId')
    ORDER BY a.script_id,a.node_id,a.created_at DESC
  ), counts AS (
    SELECT 'total' AS kind,difficulty::text FROM learning.questions WHERE status='PUBLISHED'
    UNION ALL SELECT 'total',difficulty FROM inline_inventory
    UNION ALL SELECT 'solved',q.difficulty::text FROM learning.questions q JOIN solved_ids s ON s.question_id=q.id
    UNION ALL SELECT 'solved',difficulty FROM solved_inline
  ) SELECT kind,CASE WHEN upper(difficulty) IN ('EASY','MEDIUM','HARD') THEN upper(difficulty) ELSE 'EASY' END AS difficulty,count(*)::int AS count
    FROM counts GROUP BY 1,2`;
}
