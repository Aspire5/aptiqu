-- Supplemental native Ranked guards AFTER Prisma 6 db push.
-- Manual execution only. See README.md. No table/data repair, reset or business changes.
-- Any error aborts this transaction. Existing mismatched objects are NEVER replaced.
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL search_path = pg_catalog, learning, pg_temp;

-- Stop application writers for the manual maintenance window first. These locks
-- serialize installers and prevent concurrent changes during validation/creation.
LOCK TABLE learning.pvp_match_answers, learning.pvp_match_players,
  learning.pvp_matches, learning.ranked_match_settlements,
  learning.ranked_player_seasons, learning.ranked_policies,
  learning.ranked_rating_changes, learning.ranked_seasons IN ACCESS EXCLUSIVE MODE;

-- Empty, session-only templates let PostgreSQL canonicalize CHECK/exclusion/index
-- definitions using the target's actual types/collations. LIKE copies no data,
-- defaults, indexes or CHECKs. No extension or permanent helper object is needed.
CREATE TEMP TABLE pvp_matches (LIKE learning.pvp_matches) ON COMMIT DROP;
CREATE TEMP TABLE ranked_match_settlements (LIKE learning.ranked_match_settlements) ON COMMIT DROP;
CREATE TEMP TABLE ranked_player_seasons (LIKE learning.ranked_player_seasons) ON COMMIT DROP;
CREATE TEMP TABLE ranked_rating_changes (LIKE learning.ranked_rating_changes) ON COMMIT DROP;
CREATE TEMP TABLE ranked_seasons (LIKE learning.ranked_seasons) ON COMMIT DROP;

DO $install_constraints$
DECLARE
  spec record;
  actual pg_constraint%ROWTYPE;
  expected pg_constraint%ROWTYPE;
  matches boolean;
BEGIN
  FOR spec IN SELECT * FROM (VALUES
    ('ranked_seasons', 'ranked_season_calendar', $definition$CHECK (
    id ~ '^[0-9]{4}-(0[1-9]|1[0-2])$' AND timezone='Asia/Kolkata'
    AND starts_at=((id || '-01')::timestamp AT TIME ZONE 'Asia/Kolkata')
    AND ends_at=(((id || '-01')::timestamp + interval '1 month') AT TIME ZONE 'Asia/Kolkata')
    AND ends_at>starts_at)$definition$),
    ('ranked_seasons', 'ranked_season_nonoverlap', $definition$EXCLUDE USING gist (tstzrange(starts_at,ends_at,'[)') WITH &&)$definition$),
    ('ranked_seasons', 'ranked_season_final_state', $definition$CHECK (
    (settlement_state='FINALIZED')=(finalized_at IS NOT NULL)
    AND (eligible_count IS NULL OR eligible_count>=0)
    AND (settlement_state<>'FINALIZED' OR eligible_count IS NOT NULL))$definition$),
    ('ranked_player_seasons', 'ranked_player_counts', $definition$CHECK (
    career_rated_before>=0 AND placements_required>0 AND played>=0 AND wins>=0 AND losses>=0 AND draws>=0
    AND played=wins+losses+draws AND version=played)$definition$),
    ('ranked_player_seasons', 'ranked_player_seed', $definition$CHECK (seed_source_season_id IS NULL OR seed_source_season_id<season_id)$definition$),
    ('ranked_player_seasons', 'ranked_player_peaks', $definition$CHECK (peak_rating>=rating AND peak_rating>=seed_rating)$definition$),
    ('ranked_player_seasons', 'ranked_player_qualification', $definition$CHECK (
    (qualified_at IS NOT NULL)=(played>=placements_required)
    AND ((qualified_at IS NULL AND qualified_peak_rating IS NULL)
      OR (qualified_at IS NOT NULL AND qualified_peak_rating IS NOT NULL AND qualified_peak_rating>=rating)))$definition$),
    ('ranked_player_seasons', 'ranked_player_archive', $definition$CHECK (
    (final_position IS NULL OR (final_position>0 AND qualified_at IS NOT NULL))
    AND (finalized_at IS NULL OR (final_rating IS NOT NULL AND final_league IS NOT NULL
      AND ((qualified_at IS NULL AND final_league='UNRANKED' AND final_peak_rating IS NULL AND final_position IS NULL)
        OR (qualified_at IS NOT NULL AND final_league<>'UNRANKED' AND final_peak_rating IS NOT NULL AND final_position IS NOT NULL)))))$definition$),
    ('pvp_matches', 'ranked_match_assignment', $definition$CHECK (
    (rating_mode='LEGACY_UNRATED' AND season_id IS NULL AND season_assigned_at IS NULL)
    OR (rating_mode='RATED' AND season_id IS NOT NULL AND season_assigned_at IS NOT NULL
      AND hard_expires_at IS NOT NULL AND question_snapshot IS NOT NULL
      AND coalesce(question_snapshot->>'version','')='1' AND coalesce(jsonb_array_length(question_snapshot->'questions'),0)=10
      AND total_questions=10))$definition$),
    ('pvp_matches', 'ranked_match_version', $definition$CHECK (state_version>=0)$definition$),
    ('pvp_matches', 'ranked_match_reason', $definition$CHECK (outcome_reason IS NULL OR outcome_reason IN ('NORMAL','SYSTEM_VOID'))$definition$),
    ('ranked_rating_changes', 'ranked_change_math', $definition$CHECK (
    rating_after::bigint=rating_before::bigint+delta::bigint AND score IN (0,0.5,1)
    AND expected_score BETWEEN 0 AND 1 AND k_factor>0 AND career_count_before>=0 AND season_version_after>0
    AND user_id<>opponent_id AND change_kind IN ('NONE','PLACEMENT_COMPLETE','PROMOTION','DEMOTION'))$definition$),
    ('ranked_rating_changes', 'ranked_change_opponent', $definition$FOREIGN KEY (match_id,opponent_id)
    REFERENCES learning.pvp_match_players(match_id,user_id) ON DELETE RESTRICT$definition$),
    ('ranked_match_settlements', 'ranked_settlement_shape', $definition$CHECK (
    result_schema_version=1 AND jsonb_typeof(result_snapshot)='object'
    AND outcome_hash ~ '^[a-f0-9]{64}$'
    AND (disposition<>'RATED' OR (season_id IS NOT NULL AND policy_id IS NOT NULL)))$definition$)
  ) AS required(table_name, object_name, definition)
  LOOP
    SELECT c.* INTO actual FROM pg_constraint c
      WHERE c.conrelid=to_regclass(format('learning.%I',spec.table_name))
        AND c.conname=spec.object_name;

    IF spec.object_name='ranked_change_opponent' THEN
      -- Temporary tables cannot reference permanent tables: compare this FK's
      -- complete key/action/deferral identity directly instead of using a template.
      matches := actual.contype='f'
        AND actual.confrelid='learning.pvp_match_players'::regclass
        AND ARRAY(SELECT a.attname::text FROM unnest(actual.conkey) WITH ORDINALITY k(num,ord)
          JOIN pg_attribute a ON a.attrelid=actual.conrelid AND a.attnum=k.num ORDER BY k.ord)
          = ARRAY['match_id','opponent_id']
        AND ARRAY(SELECT a.attname::text FROM unnest(actual.confkey) WITH ORDINALITY k(num,ord)
          JOIN pg_attribute a ON a.attrelid=actual.confrelid AND a.attnum=k.num ORDER BY k.ord)
          = ARRAY['match_id','user_id']
        AND actual.confmatchtype='s' AND actual.confupdtype='a' AND actual.confdeltype='r'
        AND NOT actual.condeferrable AND NOT actual.condeferred;
    ELSE
      EXECUTE format('ALTER TABLE pg_temp.%I ADD CONSTRAINT %I %s',
        spec.table_name,spec.object_name,spec.definition);
      SELECT c.* INTO STRICT expected FROM pg_constraint c
        WHERE c.conrelid=to_regclass(format('pg_temp.%I',spec.table_name))
          AND c.conname=spec.object_name;
      matches := actual.contype=expected.contype
        AND actual.condeferrable=expected.condeferrable AND actual.condeferred=expected.condeferred
        AND actual.connoinherit=expected.connoinherit
        AND pg_get_constraintdef(actual.oid,false)=pg_get_constraintdef(expected.oid,false);
    END IF;

    IF actual.oid IS NULL THEN
      EXECUTE format('ALTER TABLE learning.%I ADD CONSTRAINT %I %s',
        spec.table_name,spec.object_name,spec.definition);
      RAISE NOTICE 'Installed constraint learning.%.%',spec.table_name,spec.object_name;
    ELSIF matches IS DISTINCT FROM true OR NOT actual.convalidated
      OR NOT actual.conislocal OR actual.coninhcount<>0
      OR NOT coalesce((to_jsonb(actual)->>'conenforced')::boolean,true)
      OR (actual.contype='x' AND NOT EXISTS (SELECT 1 FROM pg_index i
        WHERE i.indexrelid=actual.conindid AND i.indisvalid AND i.indisready AND i.indislive))
      OR EXISTS (SELECT 1 FROM pg_trigger t WHERE t.tgconstraint=actual.oid AND t.tgenabled NOT IN ('O','A'))
    THEN
      RAISE EXCEPTION 'Incompatible or unvalidated constraint learning.%.%: %',
        spec.table_name,spec.object_name,pg_get_constraintdef(actual.oid,false);
    ELSE
      RAISE NOTICE 'Matching constraint learning.%.%',spec.table_name,spec.object_name;
    END IF;
  END LOOP;
END
$install_constraints$;

-- Only the two native partial indexes. The other historical indexes are Prisma-managed.
CREATE INDEX ranked_player_qualified_order ON pg_temp.ranked_player_seasons(season_id,rating DESC,user_id ASC) WHERE qualified_at IS NOT NULL;
CREATE UNIQUE INDEX ranked_player_final_position ON pg_temp.ranked_player_seasons(season_id,final_position) WHERE final_position IS NOT NULL;

DO $install_indexes$
DECLARE
  spec record;
  actual_oid oid;
  matches boolean;
BEGIN
  FOR spec IN SELECT * FROM (VALUES
    ('ranked_player_qualified_order', 'CREATE INDEX ranked_player_qualified_order ON learning.ranked_player_seasons(season_id,rating DESC,user_id ASC) WHERE qualified_at IS NOT NULL'),
    ('ranked_player_final_position', 'CREATE UNIQUE INDEX ranked_player_final_position ON learning.ranked_player_seasons(season_id,final_position) WHERE final_position IS NOT NULL')
  ) AS required(object_name,definition)
  LOOP
    actual_oid := to_regclass(format('learning.%I',spec.object_name));
    IF actual_oid IS NULL THEN
      EXECUTE spec.definition;
      RAISE NOTICE 'Installed index learning.%',spec.object_name;
    ELSE
      SELECT a.indrelid='learning.ranked_player_seasons'::regclass
        AND ac.relkind='i' AND ac.relam=ec.relam
        AND a.indisvalid AND a.indisready AND a.indislive AND a.indimmediate
        AND NOT a.indisprimary AND NOT a.indisexclusion
        AND a.indisunique=e.indisunique AND a.indnatts=e.indnatts AND a.indnkeyatts=e.indnkeyatts
        AND a.indclass=e.indclass AND a.indcollation=e.indcollation AND a.indoption=e.indoption
        AND a.indexprs IS NULL
        AND coalesce((to_jsonb(a)->>'indnullsnotdistinct')::boolean,false)=false
        AND pg_get_expr(a.indpred,a.indrelid,false)=pg_get_expr(e.indpred,e.indrelid,false)
        AND ARRAY(SELECT pg_get_indexdef(a.indexrelid,k,false) FROM generate_series(1,a.indnatts) k)
          = ARRAY(SELECT pg_get_indexdef(e.indexrelid,k,false) FROM generate_series(1,e.indnatts) k)
        AND ac.reloptions IS NOT DISTINCT FROM ec.reloptions
      INTO matches
      FROM pg_index a JOIN pg_class ac ON ac.oid=a.indexrelid
      CROSS JOIN pg_index e JOIN pg_class ec ON ec.oid=e.indexrelid
      WHERE a.indexrelid=actual_oid AND e.indexrelid=to_regclass(format('pg_temp.%I',spec.object_name));
      IF matches IS DISTINCT FROM true THEN
        RAISE EXCEPTION 'Incompatible or invalid index learning.% (OID %); no object was replaced',spec.object_name,actual_oid;
      END IF;
      RAISE NOTICE 'Matching index learning.%',spec.object_name;
    END IF;
  END LOOP;
END
$install_indexes$;

-- Bodies below are unchanged from ranked-phase2.sql. Only create when absent;
-- even a differently formatted existing body requires explicit review.
DO $install_functions$
DECLARE
  spec record;
  actual pg_proc%ROWTYPE;
BEGIN
  FOR spec IN SELECT * FROM (VALUES
    ('ranked_deny_audit_mutation', $body$
BEGIN RAISE EXCEPTION 'Ranked audit evidence is immutable'; END $body$),
    ('ranked_freeze_identity', $body$
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
    ('ranked_check_settlement', $body$
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
    ('ranked_freeze_answer', $body$
BEGIN
  IF EXISTS (SELECT 1 FROM learning.pvp_matches WHERE id=OLD.match_id AND rating_mode='RATED') THEN
    RAISE EXCEPTION 'Rated answer evidence is immutable';
  END IF;
  IF TG_OP='DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END $body$)
  ) AS required(object_name,body)
  LOOP
    SELECT p.* INTO actual FROM pg_proc p
      WHERE p.oid=to_regprocedure(format('learning.%I()',spec.object_name));
    IF actual.oid IS NULL THEN
      EXECUTE format('CREATE FUNCTION learning.%I() RETURNS trigger LANGUAGE plpgsql AS %L',spec.object_name,spec.body);
      RAISE NOTICE 'Installed function learning.%()',spec.object_name;
    ELSIF actual.prorettype<>'trigger'::regtype OR actual.prokind<>'f'
      OR actual.prolang<>(SELECT oid FROM pg_language WHERE lanname='plpgsql')
      OR actual.prosecdef OR actual.proisstrict OR actual.proretset OR actual.proleakproof
      OR actual.provolatile<>'v' OR actual.proparallel<>'u'
      OR actual.proconfig IS NOT NULL OR actual.probin IS NOT NULL
      OR btrim(actual.prosrc,E' \t\r\n')<>btrim(spec.body,E' \t\r\n')
    THEN
      RAISE EXCEPTION 'Incompatible function learning.%(); review body/attributes explicitly',spec.object_name;
    ELSE
      RAISE NOTICE 'Matching function learning.%()',spec.object_name;
    END IF;
  END LOOP;
END
$install_functions$;

DO $install_triggers$
DECLARE
  spec record;
  actual pg_trigger%ROWTYPE;
BEGIN
  FOR spec IN SELECT * FROM (VALUES
    ('ranked_policies', 'ranked_policy_immutable', 'ranked_deny_audit_mutation', 27, false, 'BEFORE UPDATE OR DELETE'),
    ('ranked_match_settlements', 'ranked_settlement_immutable', 'ranked_deny_audit_mutation', 27, false, 'BEFORE UPDATE OR DELETE'),
    ('ranked_rating_changes', 'ranked_change_immutable', 'ranked_deny_audit_mutation', 27, false, 'BEFORE UPDATE OR DELETE'),
    ('pvp_matches', 'ranked_match_identity', 'ranked_freeze_identity', 19, false, 'BEFORE UPDATE'),
    ('ranked_seasons', 'ranked_season_identity', 'ranked_freeze_identity', 19, false, 'BEFORE UPDATE'),
    ('ranked_player_seasons', 'ranked_standing_archive', 'ranked_freeze_identity', 19, false, 'BEFORE UPDATE'),
    ('pvp_matches', 'ranked_match_integrity', 'ranked_check_settlement', 21, true, 'AFTER INSERT OR UPDATE'),
    ('ranked_match_settlements', 'ranked_settlement_integrity', 'ranked_check_settlement', 5, true, 'AFTER INSERT'),
    ('ranked_rating_changes', 'ranked_ledger_integrity', 'ranked_check_settlement', 5, true, 'AFTER INSERT'),
    ('pvp_match_answers', 'ranked_answer_immutable', 'ranked_freeze_answer', 27, false, 'BEFORE UPDATE OR DELETE')
  ) AS required(table_name,object_name,function_name,event_mask,deferred,events)
  LOOP
    SELECT t.* INTO actual FROM pg_trigger t
      WHERE t.tgrelid=to_regclass(format('learning.%I',spec.table_name)) AND t.tgname=spec.object_name;
    IF actual.oid IS NULL THEN
      EXECUTE format('CREATE %sTRIGGER %I %s ON learning.%I %s FOR EACH ROW EXECUTE FUNCTION learning.%I()',
        CASE WHEN spec.deferred THEN 'CONSTRAINT ' ELSE '' END,
        spec.object_name,spec.events,spec.table_name,
        CASE WHEN spec.deferred THEN 'DEFERRABLE INITIALLY DEFERRED' ELSE '' END,spec.function_name);
      RAISE NOTICE 'Installed trigger learning.%.%',spec.table_name,spec.object_name;
    ELSIF actual.tgfoid<>to_regprocedure(format('learning.%I()',spec.function_name))
      OR actual.tgtype<>spec.event_mask OR actual.tgenabled NOT IN ('O','A')
      OR actual.tgisinternal OR actual.tgparentid<>0
      OR actual.tgdeferrable<>spec.deferred OR actual.tginitdeferred<>spec.deferred
      OR (actual.tgconstraint<>0)<>spec.deferred
      OR actual.tgconstrrelid<>0 OR actual.tgconstrindid<>0
      OR actual.tgnargs<>0 OR actual.tgargs<>''::bytea OR actual.tgattr<>''::int2vector
      OR actual.tgqual IS NOT NULL OR actual.tgoldtable IS NOT NULL OR actual.tgnewtable IS NOT NULL
    THEN
      RAISE EXCEPTION 'Incompatible or disabled trigger learning.%.%: %',
        spec.table_name,spec.object_name,pg_get_triggerdef(actual.oid,false);
    ELSE
      RAISE NOTICE 'Matching trigger learning.%.%',spec.table_name,spec.object_name;
    END IF;
  END LOOP;
END
$install_triggers$;

COMMIT;
