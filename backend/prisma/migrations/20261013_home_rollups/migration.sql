BEGIN;
-- Apply through the normal deployment process, never from the Home request.
-- Canonical submissions remain authoritative. Triggers run in the source transaction.
LOCK TABLE learning.question_attempts, learning.practice_session_questions,
 learning.daily_challenge_answers, learning.pvp_match_answers, learning.pvp_matches, learning.pvp_match_players IN SHARE ROW EXCLUSIVE MODE;
CREATE TABLE gamification.home_events (
 source text NOT NULL, source_id uuid NOT NULL,
 user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 day date NOT NULL, difficulty text NOT NULL,
 correct integer NOT NULL, timed integer NOT NULL DEFAULT 0, time_ms bigint NOT NULL DEFAULT 0,
 PRIMARY KEY(source, source_id)
);
CREATE TABLE gamification.home_totals (
 user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 difficulty text NOT NULL, attempted bigint NOT NULL DEFAULT 0,
 correct bigint NOT NULL DEFAULT 0, timed bigint NOT NULL DEFAULT 0, time_ms bigint NOT NULL DEFAULT 0,
 PRIMARY KEY(user_id, difficulty)
);
CREATE TABLE gamification.home_days (
 user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 day date NOT NULL, attempted bigint NOT NULL DEFAULT 0, correct bigint NOT NULL DEFAULT 0,
 PRIMARY KEY(user_id, day)
);
CREATE INDEX lesson_home_resume ON learning.lesson_sessions(user_id, last_activity_at DESC)
 WHERE status IN ('ACTIVE', 'PAUSED') AND roadmap_step_id IS NOT NULL;

CREATE FUNCTION gamification.home_event_delta() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE e record; sign integer;
BEGIN
 IF TG_OP = 'UPDATE' THEN
  IF OLD.user_id <> NEW.user_id THEN
   PERFORM pg_advisory_xact_lock(hashtextextended(LEAST(OLD.user_id::text,NEW.user_id::text),731));
   PERFORM pg_advisory_xact_lock(hashtextextended(GREATEST(OLD.user_id::text,NEW.user_id::text),731));
  END IF;
 END IF;
 FOR sign IN SELECT unnest(CASE TG_OP WHEN 'INSERT' THEN ARRAY[1] WHEN 'DELETE' THEN ARRAY[-1] ELSE ARRAY[-1,1] END) LOOP
  IF sign = -1 THEN e := OLD; ELSE e := NEW; END IF;
  -- Cascade deletion of a user must not recreate rows for that deleted user.
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id=e.user_id) THEN CONTINUE; END IF;
  -- Serialize all difficulty buckets for one user, including badge thresholds.
  PERFORM pg_advisory_xact_lock(hashtextextended(e.user_id::text, 731));
  INSERT INTO gamification.home_totals VALUES(e.user_id,e.difficulty,sign,sign*e.correct,sign*e.timed,sign*e.time_ms)
  ON CONFLICT(user_id,difficulty) DO UPDATE SET
   attempted=home_totals.attempted+EXCLUDED.attempted,
   correct=home_totals.correct+EXCLUDED.correct,
   timed=home_totals.timed+EXCLUDED.timed,
   time_ms=home_totals.time_ms+EXCLUDED.time_ms;
  INSERT INTO gamification.home_days VALUES(e.user_id,e.day,sign,sign*e.correct)
  ON CONFLICT(user_id,day) DO UPDATE SET
   attempted=home_days.attempted+EXCLUDED.attempted,correct=home_days.correct+EXCLUDED.correct;
 END LOOP;
 RETURN NULL;
END $$;
CREATE TRIGGER home_event_delta AFTER INSERT OR UPDATE OR DELETE ON gamification.home_events
 FOR EACH ROW EXECUTE FUNCTION gamification.home_event_delta();

-- This view is for migration/reconciliation only, never used on the read path.
CREATE VIEW gamification.home_source_events AS
 SELECT 'lesson'::text source,a.id source_id,a.user_id,a.created_at happened_at,
  COALESCE(q.difficulty::text, upper(v.definition->'nodes'->a.node_id->'questionReference'->'inlineData'->>'difficulty'), 'UNKNOWN') difficulty,
  COALESCE(a.is_correct::int,0) correct,0 timed,0::bigint time_ms
 FROM learning.question_attempts a
 JOIN learning.lesson_sessions s ON s.id=a.session_id
 JOIN learning.lesson_script_versions v ON v.id=s.script_version_id
 LEFT JOIN learning.questions q ON q.id=a.question_id
 UNION ALL
 SELECT 'practice',a.id,s.user_id,a.answered_at,q.difficulty::text,COALESCE(a.is_correct::int,0),
  (NOT s.is_replay AND a.is_correct AND a.response_time_ms > 0 AND a.user_selected_option_id <> 'TIMEOUT')::int,
  CASE WHEN NOT s.is_replay AND a.is_correct AND a.response_time_ms > 0 AND a.user_selected_option_id <> 'TIMEOUT' THEN a.response_time_ms ELSE 0 END
 FROM learning.practice_session_questions a JOIN learning.practice_sessions s ON s.id=a.session_id
 JOIN learning.questions q ON q.id=a.question_id WHERE a.is_answered AND a.answered_at IS NOT NULL AND a.user_selected_option_id IS NOT NULL AND a.user_selected_option_id <> 'TIMEOUT'
 UNION ALL
 SELECT 'daily',a.id,s.user_id,a.answered_at,q.difficulty::text,COALESCE(a.is_correct::int,0),
  (a.is_correct AND a.response_time_ms > 0 AND a.selected_option_id IS NOT NULL AND a.selected_option_id <> 'TIMEOUT')::int,
  CASE WHEN a.is_correct AND a.response_time_ms > 0 AND a.selected_option_id IS NOT NULL AND a.selected_option_id <> 'TIMEOUT' THEN a.response_time_ms ELSE 0 END
 FROM learning.daily_challenge_answers a JOIN learning.daily_challenge_participations s ON s.id=a.participation_id
 JOIN learning.questions q ON q.id=a.question_id
 WHERE a.selected_option_id IS NOT NULL AND a.selected_option_id <> 'TIMEOUT'
 UNION ALL
 SELECT 'pvp',a.id,a.user_id,a.server_received_at,q.difficulty::text,COALESCE(a.is_correct::int,0),
  (a.is_correct AND NOT a.is_late AND a.response_time_ms > 0 AND a.selected_option_id IS NOT NULL)::int,
  CASE WHEN a.is_correct AND NOT a.is_late AND a.response_time_ms > 0 AND a.selected_option_id IS NOT NULL THEN a.response_time_ms ELSE 0 END
 FROM learning.pvp_match_answers a JOIN learning.questions q ON q.id=a.question_id
 WHERE a.selected_option_id IS NOT NULL AND a.selected_option_id <> 'TIMEOUT';

CREATE FUNCTION gamification.sync_home_submission() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP = 'DELETE' THEN
  DELETE FROM gamification.home_events WHERE source=TG_ARGV[0] AND source_id=OLD.id;
 ELSE
  INSERT INTO gamification.home_events(source,source_id,user_id,day,difficulty,correct,timed,time_ms)
  SELECT source,source_id,user_id,(happened_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Kolkata')::date,
   CASE WHEN difficulty IN ('EASY','MEDIUM','HARD') THEN difficulty ELSE 'UNKNOWN' END,
   correct,COALESCE(timed,0),time_ms
  FROM gamification.home_source_events WHERE source=TG_ARGV[0] AND source_id=NEW.id
  ON CONFLICT(source,source_id) DO UPDATE SET
   user_id=EXCLUDED.user_id,day=EXCLUDED.day,difficulty=EXCLUDED.difficulty,correct=EXCLUDED.correct,
   timed=EXCLUDED.timed,time_ms=EXCLUDED.time_ms;
  IF NOT FOUND THEN DELETE FROM gamification.home_events WHERE source=TG_ARGV[0] AND source_id=NEW.id; END IF;
 END IF;
 RETURN NULL;
END $$;
CREATE TRIGGER home_submission AFTER INSERT OR UPDATE OR DELETE ON learning.question_attempts
 FOR EACH ROW EXECUTE FUNCTION gamification.sync_home_submission('lesson');
CREATE TRIGGER home_submission AFTER INSERT OR UPDATE OR DELETE ON learning.practice_session_questions
 FOR EACH ROW EXECUTE FUNCTION gamification.sync_home_submission('practice');
CREATE TRIGGER home_submission AFTER INSERT OR UPDATE OR DELETE ON learning.daily_challenge_answers
 FOR EACH ROW EXECUTE FUNCTION gamification.sync_home_submission('daily');
CREATE TRIGGER home_submission AFTER INSERT OR UPDATE OR DELETE ON learning.pvp_match_answers
 FOR EACH ROW EXECUTE FUNCTION gamification.sync_home_submission('pvp');

-- Set-based historical import; exact source IDs prevent duplicate reconstruction.
INSERT INTO gamification.home_events(source,source_id,user_id,day,difficulty,correct,timed,time_ms)
SELECT source,source_id,user_id,(happened_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Kolkata')::date,
 CASE WHEN difficulty IN ('EASY','MEDIUM','HARD') THEN difficulty ELSE 'UNKNOWN' END,
 correct,COALESCE(timed,0),time_ms FROM gamification.home_source_events;

CREATE TABLE gamification.home_badges (
 user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 badge_id text NOT NULL, PRIMARY KEY(user_id,badge_id)
);
CREATE FUNCTION gamification.award_home_badges() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 INSERT INTO gamification.home_badges(user_id,badge_id)
 SELECT NEW.user_id,b.id FROM (VALUES ('first_answer',1),('correct_25',25),('hard_10',10)) b(id,target)
 WHERE CASE b.id WHEN 'first_answer' THEN
  (SELECT COALESCE(sum(attempted),0) FROM gamification.home_totals WHERE user_id=NEW.user_id)
 WHEN 'correct_25' THEN
  (SELECT COALESCE(sum(correct),0) FROM gamification.home_totals WHERE user_id=NEW.user_id)
 ELSE (SELECT COALESCE(sum(correct),0) FROM gamification.home_totals WHERE user_id=NEW.user_id AND difficulty='HARD') END >= b.target
 ON CONFLICT DO NOTHING;
 RETURN NULL;
END $$;
CREATE TRIGGER home_badges AFTER INSERT OR UPDATE ON gamification.home_totals
 FOR EACH ROW EXECUTE FUNCTION gamification.award_home_badges();
INSERT INTO gamification.home_badges
SELECT user_id,'first_answer' FROM gamification.home_totals GROUP BY user_id HAVING sum(attempted)>=1
UNION ALL SELECT user_id,'correct_25' FROM gamification.home_totals GROUP BY user_id HAVING sum(correct)>=25
UNION ALL SELECT user_id,'hard_10' FROM gamification.home_totals WHERE difficulty='HARD' AND correct>=10;

CREATE TABLE gamification.home_ranked (
 user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
 match_id uuid NOT NULL REFERENCES learning.pvp_matches(id) ON DELETE CASCADE,
 played_at timestamp(3) NOT NULL, result text NOT NULL, correct integer NOT NULL, questions integer NOT NULL
);
CREATE FUNCTION gamification.sync_home_ranked() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF NEW.status = 'COMPLETED' THEN
  INSERT INTO gamification.home_ranked
  SELECT p.user_id,NEW.id,COALESCE(NEW.ended_at,NEW.created_at),
   CASE WHEN NEW.is_tie THEN 'Draw' WHEN p.is_winner THEN 'Win' ELSE 'Loss' END,p.score,NEW.total_questions
  FROM learning.pvp_match_players p WHERE p.match_id=NEW.id
  ON CONFLICT(user_id) DO UPDATE SET match_id=EXCLUDED.match_id,played_at=EXCLUDED.played_at,
   result=EXCLUDED.result,correct=EXCLUDED.correct,questions=EXCLUDED.questions
  WHERE EXCLUDED.played_at >= home_ranked.played_at;
 ELSE
  DELETE FROM gamification.home_ranked WHERE match_id=NEW.id;
 END IF;
 RETURN NULL;
END $$;
CREATE TRIGGER home_ranked AFTER INSERT OR UPDATE ON learning.pvp_matches
 FOR EACH ROW EXECUTE FUNCTION gamification.sync_home_ranked();
INSERT INTO gamification.home_ranked
SELECT DISTINCT ON (p.user_id) p.user_id,m.id,COALESCE(m.ended_at,m.created_at),
 CASE WHEN m.is_tie THEN 'Draw' WHEN p.is_winner THEN 'Win' ELSE 'Loss' END,p.score,m.total_questions
FROM learning.pvp_match_players p JOIN learning.pvp_matches m ON m.id=p.match_id
WHERE m.status='COMPLETED' ORDER BY p.user_id,COALESCE(m.ended_at,m.created_at) DESC,m.id;

COMMIT;
