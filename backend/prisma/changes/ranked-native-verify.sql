-- READ ONLY: mirrors startup requirements, with extra function/trigger/index checks.
-- Run with psql -v connection_budget=<actual DATABASE_CONNECTION_BUDGET> (README.md).
-- OK_METADATA is NOT a full proof of constraint-expression equivalence or data
-- consistency. The installer checks definitions strictly; definitions are also
-- returned here for review. This script creates/changes no objects or rows.
BEGIN READ ONLY;
SET LOCAL search_path = pg_catalog, learning, pg_temp;
WITH
required_columns(table_name,column_name) AS (VALUES
  ('lesson_action_receipts','request_hash'),
  ('daily_challenge_participations','question_started_at'),
  ('daily_challenge_participations','question_deadline'),
  ('daily_challenge_answers','question_started_at'),
  ('daily_challenge_answers','question_deadline'),
  ('daily_challenge_answers','requested_option_id'),
  ('daily_challenge_answers','response'),
  ('book_sources','processing_epoch'),
  ('book_sources','processing_cancelled'),
  ('book_sources','processing_token'),
  ('book_sources','processing_heartbeat'),
  ('generation_leases','expires_at'),
  ('ai_prompts','draft_revision'),
  ('practice_timing_policy','version')
),
required_constraints(table_name,object_name,kind) AS (VALUES
  ('ranked_seasons','ranked_season_calendar','c'),
  ('ranked_seasons','ranked_season_nonoverlap','x'),
  ('ranked_seasons','ranked_season_final_state','c'),
  ('ranked_player_seasons','ranked_player_counts','c'),
  ('ranked_player_seasons','ranked_player_seed','c'),
  ('ranked_player_seasons','ranked_player_peaks','c'),
  ('ranked_player_seasons','ranked_player_qualification','c'),
  ('ranked_player_seasons','ranked_player_archive','c'),
  ('pvp_matches','ranked_match_assignment','c'),
  ('pvp_matches','ranked_match_version','c'),
  ('pvp_matches','ranked_match_reason','c'),
  ('ranked_rating_changes','ranked_change_math','c'),
  ('ranked_rating_changes','ranked_change_opponent','f'),
  ('ranked_match_settlements','ranked_settlement_shape','c')
),
required_functions(object_name,body) AS (VALUES
  ('ranked_deny_audit_mutation',$body$
BEGIN RAISE EXCEPTION 'Ranked audit evidence is immutable'; END $body$),
  ('ranked_freeze_identity',$body$
BEGIN
  IF TG_TABLE_NAME='pvp_matches' THEN
    IF (NEW.rating_mode,NEW.season_id,NEW.season_assigned_at,NEW.question_snapshot,NEW.question_set_id)
      IS DISTINCT FROM (OLD.rating_mode,OLD.season_id,OLD.season_assigned_at,OLD.question_snapshot,OLD.question_set_id)
      OR (OLD.hard_expires_at IS NOT NULL AND NEW.hard_expires_at IS DISTINCT FROM OLD.hard_expires_at) THEN
      RAISE EXCEPTION 'Match admission identity/content is immutable';
    END IF;
  ELSIF TG_TABLE_NAME='ranked_seasons' THEN
    IF (NEW.id,NEW.timezone,NEW.starts_at,NEW.ends_at,NEW.policy_id)
      IS DISTINCT FROM (OLD.id,OLD.timezone,OLD.starts_at,OLD.ends_at,OLD.policy_id)
      OR OLD.settlement_state='FINALIZED' THEN RAISE EXCEPTION 'Season identity/archive is immutable'; END IF;
  ELSE
    IF OLD.finalized_at IS NOT NULL THEN RAISE EXCEPTION 'Archived standing is immutable'; END IF;
    IF (NEW.season_id,NEW.user_id,NEW.seed_source_season_id,NEW.seed_rating,NEW.career_rated_before,NEW.placements_required)
      IS DISTINCT FROM (OLD.season_id,OLD.user_id,OLD.seed_source_season_id,OLD.seed_rating,OLD.career_rated_before,OLD.placements_required)
      THEN RAISE EXCEPTION 'Standing seed/qualification identity is immutable'; END IF;
  END IF;
  RETURN NEW;
END $body$),
  ('ranked_check_settlement',$body$
DECLARE mid uuid; m learning.pvp_matches%ROWTYPE; h learning.ranked_match_settlements%ROWTYPE; n integer;
BEGIN
  IF TG_TABLE_NAME='pvp_matches' THEN mid:=NEW.id; ELSE mid:=NEW.match_id; END IF;
  SELECT * INTO m FROM learning.pvp_matches WHERE id=mid;
  SELECT * INTO h FROM learning.ranked_match_settlements WHERE match_id=mid;
  IF m.rating_mode='RATED' THEN
    IF (SELECT count(*) FROM learning.pvp_match_players WHERE match_id=mid)<>2 THEN RAISE EXCEPTION 'Rated match requires two participants'; END IF;
    IF NOT EXISTS (SELECT 1 FROM learning.ranked_seasons s WHERE s.id=m.season_id
      AND m.season_assigned_at>=s.starts_at AND m.season_assigned_at<s.ends_at) THEN RAISE EXCEPTION 'Admission is outside season'; END IF;
    IF m.status IN ('COMPLETED','CANCELLED') AND h.match_id IS NULL THEN RAISE EXCEPTION 'Rated outcome requires settlement'; END IF;
  END IF;
  IF h.match_id IS NOT NULL THEN
    IF h.season_id IS DISTINCT FROM m.season_id THEN RAISE EXCEPTION 'Settlement season mismatch'; END IF;
    IF h.season_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM learning.ranked_seasons s WHERE s.id=h.season_id AND s.policy_id=h.policy_id) THEN RAISE EXCEPTION 'Settlement policy mismatch'; END IF;
    SELECT count(*) INTO n FROM learning.ranked_rating_changes WHERE match_id=mid;
    IF h.disposition='RATED' THEN
      IF n<>2 OR m.rating_mode<>'RATED' OR m.status<>'COMPLETED' THEN RAISE EXCEPTION 'Rated result requires two changes and completed match'; END IF;
      IF EXISTS (SELECT 1 FROM learning.ranked_rating_changes c WHERE c.match_id=mid AND c.season_id IS DISTINCT FROM m.season_id) THEN RAISE EXCEPTION 'Ledger season mismatch'; END IF;
    ELSIF n<>0 THEN RAISE EXCEPTION 'Unrated result cannot contain rating changes';
    END IF;
    IF h.disposition='VOID' AND (m.status<>'CANCELLED' OR m.outcome_reason<>'SYSTEM_VOID') THEN RAISE EXCEPTION 'Invalid void outcome'; END IF;
    IF h.disposition='LEGACY_UNRATED' AND (m.rating_mode<>'LEGACY_UNRATED' OR m.status<>'COMPLETED') THEN RAISE EXCEPTION 'Invalid legacy outcome'; END IF;
    IF m.winner_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM learning.pvp_match_players p WHERE p.match_id=mid AND p.user_id=m.winner_id) THEN RAISE EXCEPTION 'Winner is not a participant'; END IF;
  END IF;
  RETURN NULL;
END $body$),
  ('ranked_freeze_answer',$body$
BEGIN
  IF EXISTS (SELECT 1 FROM learning.pvp_matches WHERE id=OLD.match_id AND rating_mode='RATED') THEN
    RAISE EXCEPTION 'Rated answer evidence is immutable';
  END IF;
  IF TG_OP='DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END $body$)
),
required_triggers(table_name,object_name,function_name,event_mask,deferred) AS (VALUES
  ('ranked_policies','ranked_policy_immutable','ranked_deny_audit_mutation',27,false),
  ('ranked_match_settlements','ranked_settlement_immutable','ranked_deny_audit_mutation',27,false),
  ('ranked_rating_changes','ranked_change_immutable','ranked_deny_audit_mutation',27,false),
  ('pvp_matches','ranked_match_identity','ranked_freeze_identity',19,false),
  ('ranked_seasons','ranked_season_identity','ranked_freeze_identity',19,false),
  ('ranked_player_seasons','ranked_standing_archive','ranked_freeze_identity',19,false),
  ('pvp_matches','ranked_match_integrity','ranked_check_settlement',21,true),
  ('ranked_match_settlements','ranked_settlement_integrity','ranked_check_settlement',5,true),
  ('ranked_rating_changes','ranked_ledger_integrity','ranked_check_settlement',5,true),
  ('pvp_match_answers','ranked_answer_immutable','ranked_freeze_answer',27,false)
),
required_indexes(object_name,key_names,options,is_unique,predicate) AS (VALUES
  ('ranked_player_qualified_order',ARRAY['season_id','rating','user_id'],'0 3 0',false,'qualified_at IS NOT NULL'),
  ('ranked_player_final_position',ARRAY['season_id','final_position'],'0 0',true,'final_position IS NOT NULL')
),
checks AS (
  SELECT 'column' AS kind, 'learning.'||r.table_name||'.'||r.column_name AS object_name,
    CASE WHEN c.column_name IS NULL THEN 'MISSING' ELSE 'OK_METADATA' END AS status,
    c.data_type AS definition
  FROM required_columns r LEFT JOIN information_schema.columns c
    ON c.table_schema='learning' AND c.table_name=r.table_name AND c.column_name=r.column_name
  UNION ALL
  SELECT 'constraint','learning.'||r.table_name||'.'||r.object_name,
    CASE WHEN c.oid IS NULL THEN 'MISSING'
      WHEN c.contype::text<>r.kind OR NOT c.convalidated OR NOT c.conislocal OR c.coninhcount<>0
        OR NOT coalesce((to_jsonb(c)->>'conenforced')::boolean,true)
        OR c.condeferrable OR c.condeferred
        OR (c.contype='x' AND NOT EXISTS (SELECT 1 FROM pg_index i
          WHERE i.indexrelid=c.conindid AND i.indisvalid AND i.indisready AND i.indislive))
        OR EXISTS (SELECT 1 FROM pg_trigger t WHERE t.tgconstraint=c.oid AND t.tgenabled NOT IN ('O','A'))
        THEN 'INVALID' ELSE 'OK_METADATA' END,
    pg_get_constraintdef(c.oid,false)
  FROM required_constraints r LEFT JOIN pg_constraint c
    ON c.conrelid=to_regclass(format('learning.%I',r.table_name)) AND c.conname=r.object_name
  UNION ALL
  SELECT 'function','learning.'||r.object_name||'()',
    CASE WHEN p.oid IS NULL THEN 'MISSING'
      WHEN p.prorettype<>'trigger'::regtype OR p.prokind<>'f'
        OR p.prolang<>(SELECT oid FROM pg_language WHERE lanname='plpgsql')
        OR p.prosecdef OR p.proisstrict OR p.proretset OR p.proleakproof
        OR p.provolatile<>'v' OR p.proparallel<>'u' OR p.proconfig IS NOT NULL OR p.probin IS NOT NULL
        OR btrim(p.prosrc,E' \t\r\n')<>btrim(r.body,E' \t\r\n')
        THEN 'INVALID' ELSE 'OK_METADATA' END,
    CASE WHEN p.prokind='f' THEN pg_get_functiondef(p.oid) END
  FROM required_functions r LEFT JOIN pg_proc p
    ON p.oid=to_regprocedure(format('learning.%I()',r.object_name))
  UNION ALL
  SELECT 'trigger','learning.'||r.table_name||'.'||r.object_name,
    CASE WHEN t.oid IS NULL THEN 'MISSING'
      WHEN t.tgfoid IS DISTINCT FROM to_regprocedure(format('learning.%I()',r.function_name))::oid
        OR t.tgtype<>r.event_mask OR t.tgenabled NOT IN ('O','A')
        OR t.tgisinternal OR t.tgparentid<>0
        OR t.tgdeferrable<>r.deferred OR t.tginitdeferred<>r.deferred OR (t.tgconstraint<>0)<>r.deferred
        OR t.tgconstrrelid<>0 OR t.tgconstrindid<>0
        OR t.tgnargs<>0 OR t.tgargs<>''::bytea OR t.tgattr<>''::int2vector
        OR t.tgqual IS NOT NULL OR t.tgoldtable IS NOT NULL OR t.tgnewtable IS NOT NULL
        THEN 'INVALID' ELSE 'OK_METADATA' END,
    pg_get_triggerdef(t.oid,false)
  FROM required_triggers r LEFT JOIN pg_trigger t
    ON t.tgrelid=to_regclass(format('learning.%I',r.table_name)) AND t.tgname=r.object_name
  UNION ALL
  SELECT 'index','learning.'||r.object_name,
    CASE WHEN c.oid IS NULL THEN 'MISSING'
      WHEN i.indexrelid IS NULL THEN 'INVALID'
      WHEN i.indrelid IS DISTINCT FROM to_regclass('learning.ranked_player_seasons')::oid
        OR NOT i.indisvalid OR NOT i.indisready OR NOT i.indislive OR NOT i.indimmediate
        OR c.relkind<>'i' OR am.amname<>'btree' OR i.indisprimary OR i.indisexclusion
        OR i.indisunique<>r.is_unique OR i.indnatts<>cardinality(r.key_names) OR i.indnkeyatts<>i.indnatts
        OR i.indexprs IS NOT NULL OR i.indoption::text<>r.options
        OR coalesce((to_jsonb(i)->>'indnullsnotdistinct')::boolean,false)
        OR pg_get_expr(i.indpred,i.indrelid,false) IS NULL
        OR pg_get_expr(i.indpred,i.indrelid,false) NOT IN (r.predicate,'('||r.predicate||')')
        OR ARRAY(SELECT a.attname::text FROM unnest(i.indkey) WITH ORDINALITY k(num,ord)
          JOIN pg_attribute a ON a.attrelid=i.indrelid AND a.attnum=k.num ORDER BY k.ord)<>r.key_names
        THEN 'INVALID' ELSE 'OK_METADATA' END,
    CASE WHEN i.indexrelid IS NOT NULL THEN pg_get_indexdef(i.indexrelid) END
  FROM required_indexes r LEFT JOIN pg_class c
    ON c.oid=to_regclass(format('learning.%I',r.object_name))
  LEFT JOIN pg_index i ON i.indexrelid=c.oid LEFT JOIN pg_am am ON am.oid=c.relam
  UNION ALL
  SELECT 'assignment_unique','learning.script_assignments(roadmap_step_id,script_id)',
    CASE WHEN EXISTS (
      SELECT 1 FROM pg_index i WHERE i.indrelid=to_regclass('learning.script_assignments')
        AND i.indisunique AND i.indisvalid AND i.indpred IS NULL
        AND ARRAY(SELECT a.attname::text FROM unnest(i.indkey) WITH ORDINALITY k(num,ord)
          JOIN pg_attribute a ON a.attrelid=i.indrelid AND a.attnum=k.num ORDER BY k.ord)
          = ARRAY['roadmap_step_id','script_id']
    ) THEN 'OK_METADATA' ELSE 'MISSING_OR_INVALID' END,
    'Prisma-managed unique index; installer does not create it'
  UNION ALL
  SELECT 'pool_budget','DATABASE_CONNECTION_BUDGET',
    CASE WHEN :'connection_budget'::integer>0 AND :'connection_budget'::integer <=
      current_setting('max_connections')::int-current_setting('superuser_reserved_connections')::int
        -coalesce(current_setting('reserved_connections',true),'0')::int
      THEN 'OK_METADATA' ELSE 'INVALID' END,
    format('declared=%s; max=%s; superuser_reserved=%s; reserved=%s', :'connection_budget',
      current_setting('max_connections'),current_setting('superuser_reserved_connections'),
      coalesce(current_setting('reserved_connections',true),'0'))
)
SELECT kind,object_name,status,definition FROM checks
ORDER BY (status<>'OK_METADATA') DESC,kind,object_name;
COMMIT;
