-- Deployment validation: run ONLY on an explicitly authorized disposable PostgreSQL
-- database with repository migrations applied. All fixtures are rolled back.
BEGIN;
DO $$
DECLARE
 u uuid := gen_random_uuid(); ev uuid := gen_random_uuid();
 q uuid := gen_random_uuid(); session uuid := gen_random_uuid(); sq uuid := gen_random_uuid();
 n bigint; c bigint; t bigint; ms bigint;
BEGIN
 INSERT INTO auth.users(id,email,google_id,updated_at) VALUES(u,u::text||'@home-test.invalid',u::text,now());
 -- Ledger retries do not add twice. Corrections and removal adjust both projections.
 INSERT INTO gamification.home_events VALUES('test',ev,u,'2026-10-13','HARD',1,1,1200);
 INSERT INTO gamification.home_events VALUES('test',ev,u,'2026-10-13','HARD',1,1,1200) ON CONFLICT DO NOTHING;
 SELECT attempted,correct,timed,time_ms INTO n,c,t,ms FROM gamification.home_totals WHERE user_id=u AND difficulty='HARD';
 IF (n,c,t,ms) IS DISTINCT FROM (1::bigint,1::bigint,1::bigint,1200::bigint) THEN RAISE EXCEPTION 'duplicate or rollup error'; END IF;
 UPDATE gamification.home_events SET correct=0,timed=0,time_ms=0,day='2026-10-14' WHERE source='test' AND source_id=ev;
 SELECT attempted,correct INTO n,c FROM gamification.home_days WHERE user_id=u AND day='2026-10-13';
 IF (n,c) IS DISTINCT FROM (0::bigint,0::bigint) THEN RAISE EXCEPTION 'old day not reversed'; END IF;
 SELECT attempted,correct INTO n,c FROM gamification.home_days WHERE user_id=u AND day='2026-10-14';
 IF (n,c) IS DISTINCT FROM (1::bigint,0::bigint) THEN RAISE EXCEPTION 'new day not recorded'; END IF;
 DELETE FROM gamification.home_events WHERE source='test' AND source_id=ev;
 SELECT attempted INTO n FROM gamification.home_totals WHERE user_id=u AND difficulty='HARD';
 IF n <> 0 THEN RAISE EXCEPTION 'delete not reversed'; END IF;
 -- Real practice writes test the adapter, UTC-to-IST boundary and timeout exclusion.
 INSERT INTO learning.subjects(id,slug,name,updated_at) VALUES(u::text,u::text,'Test subject',now());
 INSERT INTO learning.topics(id,subject_id,slug,name,updated_at) VALUES(u::text,u::text,u::text,'Test topic',now());
 INSERT INTO learning.subtopics(id,topic_id,name,updated_at) VALUES(u::text,u::text,'Test subtopic',now());
 INSERT INTO learning.questions(id,subject_id,topic_id,subtopic_id,prompt,options,correct_answer,explanation,method,fingerprint,difficulty,updated_at)
 VALUES(q,u::text,u::text,u::text,'Test','[]','A','Test','Test',q::text,'EASY',now());
 INSERT INTO learning.practice_sessions(id,user_id,subject_id,topic_id,subtopic_ids,updated_at)
 VALUES(session,u,u::text,u::text,ARRAY[u::text],now());
 INSERT INTO learning.practice_session_questions(id,session_id,question_id,sequence) VALUES(sq,session,q,1);
 UPDATE learning.practice_session_questions SET is_answered=true,is_correct=true,user_selected_option_id='A',
 response_time_ms=4000,answered_at='2026-10-13 18:30:00' WHERE id=sq;
 SELECT attempted,correct INTO n,c FROM gamification.home_days WHERE user_id=u AND day='2026-10-14';
 IF (n,c) IS DISTINCT FROM (1::bigint,1::bigint) THEN RAISE EXCEPTION 'source or timezone error'; END IF;
 -- A repeated source update replaces the ledger entry, without increasing counts.
 UPDATE learning.practice_session_questions SET response_time_ms=4000 WHERE id=sq;
 SELECT attempted,correct,timed,time_ms INTO n,c,t,ms FROM gamification.home_totals WHERE user_id=u AND difficulty='EASY';
 IF (n,c,t,ms) IS DISTINCT FROM (1::bigint,1::bigint,1::bigint,4000::bigint) THEN RAISE EXCEPTION 'source retry double counted'; END IF;
 UPDATE learning.practice_session_questions SET user_selected_option_id='TIMEOUT',is_correct=false WHERE id=sq;
 SELECT attempted INTO n FROM gamification.home_totals WHERE user_id=u AND difficulty='EASY';
 IF n <> 0 THEN RAISE EXCEPTION 'timeout counted'; END IF;
 -- Persistent threshold awards are unique, and survive later corrections.
 INSERT INTO gamification.home_events(source,source_id,user_id,day,difficulty,correct)
 SELECT 'test',gen_random_uuid(),u,'2026-10-14','HARD',1 FROM generate_series(1,25);
 SELECT count(*) INTO n FROM gamification.home_badges WHERE user_id=u;
 IF n <> 3 THEN RAISE EXCEPTION 'badge threshold or uniqueness error'; END IF;
 DELETE FROM learning.practice_sessions WHERE id=session;
 DELETE FROM auth.users WHERE id=u;
 IF EXISTS(SELECT 1 FROM gamification.home_events WHERE user_id=u)
 OR EXISTS(SELECT 1 FROM gamification.home_totals WHERE user_id=u)
 OR EXISTS(SELECT 1 FROM gamification.home_days WHERE user_id=u)
 OR EXISTS(SELECT 1 FROM gamification.home_badges WHERE user_id=u) THEN RAISE EXCEPTION 'user cascade failed'; END IF;
END $$;
ROLLBACK;
