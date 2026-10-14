import { Prisma } from '@prisma/client';
import { Counts } from './home.metrics';

export interface HomeStatsRow extends Counts {
  kind: 'difficulty' | 'day';
  difficulty: string | null;
  date: string | null;
}

// Filter each source by user before joining. PostgreSQL aggregates submissions
// once for lifetime difficulty metrics and the recent activity calendar; the API
// receives at most four difficulty rows and 28 daily rows, never raw answers.
export function homeStatsQuery(userId: string, startUtc: string, endUtc: string) {
  return Prisma.sql`
    WITH submissions AS (
      SELECT a.created_at AS happened_at,
        COALESCE(q.difficulty::text,
          upper(v.definition->'nodes'->a.node_id->'questionReference'->'inlineData'->>'difficulty'),
          'UNKNOWN') AS difficulty,
        a.is_correct::int AS correct, 0 AS timed, 0::bigint AS time_ms
      FROM learning.question_attempts a
      JOIN learning.lesson_sessions s ON s.id = a.session_id
      JOIN learning.lesson_script_versions v ON v.id = s.script_version_id
      LEFT JOIN learning.questions q ON q.id = a.question_id
      WHERE a.user_id = ${userId}::uuid

      UNION ALL
      SELECT a.answered_at, q.difficulty::text, COALESCE(a.is_correct::int, 0),
        COALESCE((NOT s.is_replay AND a.is_correct AND a.response_time_ms > 0)::int, 0),
        CASE WHEN NOT s.is_replay AND a.is_correct AND a.response_time_ms > 0
          THEN a.response_time_ms ELSE 0 END
      FROM learning.practice_sessions s
      JOIN learning.practice_session_questions a ON a.session_id = s.id
      JOIN learning.questions q ON q.id = a.question_id
      WHERE s.user_id = ${userId}::uuid AND a.is_answered
        AND a.answered_at IS NOT NULL AND a.user_selected_option_id IS NOT NULL
        AND a.user_selected_option_id <> 'TIMEOUT'

      UNION ALL
      SELECT a.answered_at, q.difficulty::text, a.is_correct::int,
        (a.is_correct AND a.response_time_ms > 0)::int,
        CASE WHEN a.is_correct AND a.response_time_ms > 0 THEN a.response_time_ms ELSE 0 END
      FROM learning.daily_challenge_participations s
      JOIN learning.daily_challenge_answers a ON a.participation_id = s.id
      JOIN learning.questions q ON q.id = a.question_id
      WHERE s.user_id = ${userId}::uuid AND a.selected_option_id IS NOT NULL
        AND a.selected_option_id <> 'TIMEOUT'

      UNION ALL
      SELECT a.server_received_at, q.difficulty::text, a.is_correct::int,
        (a.is_correct AND NOT a.is_late AND a.response_time_ms > 0)::int,
        CASE WHEN a.is_correct AND NOT a.is_late AND a.response_time_ms > 0
          THEN a.response_time_ms ELSE 0 END
      FROM learning.pvp_match_answers a
      JOIN learning.questions q ON q.id = a.question_id
      WHERE a.user_id = ${userId}::uuid AND a.selected_option_id IS NOT NULL
        AND a.selected_option_id <> 'TIMEOUT'
    ), normalized AS (
      SELECT CASE WHEN difficulty IN ('EASY', 'MEDIUM', 'HARD')
        THEN difficulty ELSE 'UNKNOWN' END AS difficulty,
        CASE WHEN happened_at >= ${startUtc}::timestamp AND happened_at < ${endUtc}::timestamp
          THEN (happened_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Kolkata')::date END AS day,
        correct, timed, time_ms
      FROM submissions
    )
    SELECT CASE WHEN GROUPING(day) = 1 THEN 'difficulty' ELSE 'day' END AS kind,
      difficulty, day::text AS date, count(*)::float8 AS attempted,
      sum(correct)::float8 AS correct, sum(timed)::float8 AS timed,
      sum(time_ms)::float8 AS "timeMs"
    FROM normalized
    GROUP BY GROUPING SETS ((difficulty), (day))
    HAVING GROUPING(day) = 1 OR day IS NOT NULL
    ORDER BY kind, difficulty, day`;
}

export function latestHomeMatchQuery(userId: string) {
  return Prisma.sql`
    SELECT CASE WHEN m.is_tie THEN 'Draw' WHEN p.is_winner THEN 'Win' ELSE 'Loss' END AS result,
      p.score AS correct, m.total_questions AS questions
    FROM learning.pvp_match_players p
    JOIN learning.pvp_matches m ON m.id = p.match_id
    WHERE p.user_id = ${userId}::uuid AND m.status = 'COMPLETED'
    ORDER BY COALESCE(m.ended_at, m.created_at) DESC, m.id DESC
    LIMIT 1`;
}
