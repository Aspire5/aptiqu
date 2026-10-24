import type { PrismaClient } from '@prisma/client';
const columns = [
    ['lesson_action_receipts', 'request_hash'], ['daily_challenge_participations', 'question_started_at'], ['daily_challenge_participations', 'question_deadline'],
    ['daily_challenge_answers', 'question_started_at'], ['daily_challenge_answers', 'question_deadline'], ['daily_challenge_answers', 'requested_option_id'], ['daily_challenge_answers', 'response'],
    ['book_sources', 'processing_epoch'], ['book_sources', 'processing_cancelled'], ['book_sources', 'processing_token'], ['book_sources', 'processing_heartbeat'],
    ['generation_leases', 'expires_at'], ['ai_prompts', 'draft_revision'], ['practice_timing_policy', 'version'],
    ['question_preparations','manifest'], ['question_preparations','call_count'], ['question_preparations','worker_token'], ['question_preparations','result_snapshot'],
    ['questions','reference_snapshot'], ['questions','generation_profile'], ['practice_sessions','question_snapshot'],
].map(([table, column]) => ({ table, column }));
const triggers = [['ranked_policies', 'ranked_policy_immutable'], ['ranked_match_settlements', 'ranked_settlement_immutable'], ['ranked_rating_changes', 'ranked_change_immutable'], ['pvp_matches', 'ranked_match_identity'], ['ranked_seasons', 'ranked_season_identity'], ['ranked_player_seasons', 'ranked_standing_archive'], ['pvp_match_answers', 'ranked_answer_immutable'], ['pvp_matches', 'ranked_match_integrity'], ['ranked_match_settlements', 'ranked_settlement_integrity'], ['ranked_rating_changes', 'ranked_ledger_integrity']].map(([table, name]) => ({ table, name }));
const constraints = [['ranked_seasons', 'ranked_season_calendar'], ['ranked_seasons', 'ranked_season_nonoverlap'], ['ranked_seasons', 'ranked_season_final_state'], ['ranked_player_seasons', 'ranked_player_counts'], ['ranked_player_seasons', 'ranked_player_seed'], ['ranked_player_seasons', 'ranked_player_peaks'], ['ranked_player_seasons', 'ranked_player_qualification'], ['ranked_player_seasons', 'ranked_player_archive'], ['pvp_matches', 'ranked_match_assignment'], ['pvp_matches', 'ranked_match_version'], ['pvp_matches', 'ranked_match_reason'], ['ranked_rating_changes', 'ranked_change_math'], ['ranked_rating_changes', 'ranked_change_opponent'], ['ranked_match_settlements', 'ranked_settlement_shape']].map(([table, name]) => ({ table, name }));
// Read-only startup compatibility check, not a migration or proof of full SQL drift.
export async function assertDatabaseContract(db: Pick<PrismaClient, '$queryRaw'>, connectionBudget = 1) {
    const missing = await db.$queryRaw<Array<{
        kind: string;
    }>> `
    WITH columns AS (SELECT * FROM jsonb_to_recordset(${JSON.stringify(columns)}::jsonb) AS r("table" text,"column" text)),
    triggers AS (SELECT * FROM jsonb_to_recordset(${JSON.stringify(triggers)}::jsonb) AS r("table" text,name text)),
    constraints AS (SELECT * FROM jsonb_to_recordset(${JSON.stringify(constraints)}::jsonb) AS r("table" text,name text))
    SELECT 'column' AS kind FROM columns r WHERE NOT EXISTS (SELECT 1 FROM information_schema.columns c WHERE c.table_schema='learning' AND c.table_name=r."table" AND c.column_name=r."column")
    UNION ALL SELECT 'trigger' FROM triggers r WHERE NOT EXISTS (
      SELECT 1 FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='learning' AND c.relname=r."table" AND t.tgname=r.name AND t.tgenabled IN ('O','A')
        AND (r.name NOT LIKE '%integrity' OR t.tgdeferrable AND t.tginitdeferred))
    UNION ALL SELECT 'constraint' FROM constraints r WHERE NOT EXISTS (
      SELECT 1 FROM pg_constraint k JOIN pg_class c ON c.oid=k.conrelid JOIN pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='learning' AND c.relname=r."table" AND k.conname=r.name AND k.convalidated)
    UNION ALL SELECT 'index' FROM (VALUES ('ranked_player_qualified_order'),('ranked_player_final_position')) r(name) WHERE NOT EXISTS (
      SELECT 1 FROM pg_index i JOIN pg_class c ON c.oid=i.indexrelid JOIN pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='learning' AND c.relname=r.name AND i.indisvalid)
    UNION ALL SELECT 'pool_budget' WHERE ${connectionBudget} > current_setting('max_connections')::int-current_setting('superuser_reserved_connections')::int-COALESCE(current_setting('reserved_connections',true),'0')::int
    UNION ALL SELECT 'assignment_unique' WHERE NOT EXISTS (
      SELECT 1 FROM pg_index i JOIN pg_class c ON c.oid=i.indrelid JOIN pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='learning' AND c.relname='script_assignments' AND i.indisunique AND i.indisvalid AND i.indpred IS NULL
      AND ARRAY(SELECT a.attname::text FROM unnest(i.indkey) WITH ORDINALITY k(num,ord) JOIN pg_attribute a ON a.attrelid=c.oid AND a.attnum=k.num ORDER BY k.ord)=ARRAY['roadmap_step_id','script_id'])`;
    if (missing.length)
        throw Object.assign(new Error('Database schema, native Ranked guards or pool budget are incompatible; review the runtime runbook'), { code: missing.some(row => row.kind === 'pool_budget') ? 'DATABASE_POOL_BUDGET_EXCEEDED' : 'SCHEMA_INCOMPATIBLE' });
}
