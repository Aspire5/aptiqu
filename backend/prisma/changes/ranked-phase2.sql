-- Prepared offline from the repository schema; NEVER executed by the app.
-- Review README.md and inspect live schema/legacy data before authorized use.
BEGIN;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM learning.pvp_match_answers a
    LEFT JOIN learning.pvp_match_players p ON (p.match_id,p.user_id)=(a.match_id,a.user_id)
    WHERE p.id IS NULL) THEN
    RAISE EXCEPTION 'Legacy answer/participant orphans require review; no rows were deleted';
  END IF;
END $$;

-- CreateEnum
CREATE TYPE "learning"."RankedRatingMode" AS ENUM ('LEGACY_UNRATED', 'RATED');

-- CreateEnum
CREATE TYPE "learning"."RankedSeasonState" AS ENUM ('OPEN', 'FINALIZING', 'FINALIZED');

-- CreateEnum
CREATE TYPE "learning"."RankedDisposition" AS ENUM ('RATED', 'VOID', 'LEGACY_UNRATED');

-- CreateEnum
CREATE TYPE "learning"."RankedLeague" AS ENUM ('UNRANKED', 'BRONZE', 'SILVER', 'GOLD', 'PLATINUM', 'DIAMOND');

-- AlterTable
ALTER TABLE "learning"."pvp_matches" ADD COLUMN     "hard_expires_at" TIMESTAMPTZ(3),
ADD COLUMN     "outcome_reason" VARCHAR(32),
ADD COLUMN     "question_snapshot" JSONB,
ADD COLUMN     "rating_mode" "learning"."RankedRatingMode" NOT NULL DEFAULT 'LEGACY_UNRATED',
ADD COLUMN     "season_assigned_at" TIMESTAMPTZ(3),
ADD COLUMN     "season_id" VARCHAR(7),
ADD COLUMN     "state_version" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "transition_deadline" TIMESTAMPTZ(3);

-- AlterTable
ALTER TABLE "learning"."pvp_match_players" ADD COLUMN     "disconnected_at" TIMESTAMPTZ(3);

-- CreateTable
CREATE TABLE "learning"."ranked_policies" (
    "id" VARCHAR(64) NOT NULL,
    "elo_version" VARCHAR(32) NOT NULL,
    "league_version" VARCHAR(32) NOT NULL,
    "outcome_version" VARCHAR(32) NOT NULL,
    "config" JSONB NOT NULL,
    "config_hash" CHAR(64) NOT NULL,
    "approved_at" TIMESTAMPTZ(3),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ranked_policies_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "learning"."ranked_seasons" (
    "id" VARCHAR(7) NOT NULL,
    "timezone" VARCHAR(32) NOT NULL DEFAULT 'Asia/Kolkata',
    "starts_at" TIMESTAMPTZ(3) NOT NULL,
    "ends_at" TIMESTAMPTZ(3) NOT NULL,
    "policy_id" VARCHAR(64) NOT NULL,
    "settlement_state" "learning"."RankedSeasonState" NOT NULL DEFAULT 'OPEN',
    "eligible_count" INTEGER,
    "finalized_at" TIMESTAMPTZ(3),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ranked_seasons_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "learning"."ranked_player_seasons" (
    "season_id" VARCHAR(7) NOT NULL,
    "user_id" UUID NOT NULL,
    "seed_source_season_id" VARCHAR(7),
    "seed_rating" INTEGER NOT NULL,
    "rating" INTEGER NOT NULL,
    "peak_rating" INTEGER NOT NULL,
    "qualified_peak_rating" INTEGER,
    "career_rated_before" INTEGER NOT NULL,
    "placements_required" INTEGER NOT NULL,
    "played" INTEGER NOT NULL DEFAULT 0,
    "wins" INTEGER NOT NULL DEFAULT 0,
    "losses" INTEGER NOT NULL DEFAULT 0,
    "draws" INTEGER NOT NULL DEFAULT 0,
    "qualified_at" TIMESTAMPTZ(3),
    "version" INTEGER NOT NULL DEFAULT 0,
    "last_match_id" UUID,
    "last_played_at" TIMESTAMPTZ(3),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "final_rating" INTEGER,
    "final_peak_rating" INTEGER,
    "final_league" "learning"."RankedLeague",
    "final_position" INTEGER,
    "finalized_at" TIMESTAMPTZ(3),

    CONSTRAINT "ranked_player_seasons_pkey" PRIMARY KEY ("season_id","user_id")
);

-- CreateTable
CREATE TABLE "learning"."ranked_match_settlements" (
    "match_id" UUID NOT NULL,
    "season_id" VARCHAR(7),
    "policy_id" VARCHAR(64),
    "disposition" "learning"."RankedDisposition" NOT NULL,
    "outcome_hash" CHAR(64) NOT NULL,
    "result_schema_version" INTEGER NOT NULL DEFAULT 1,
    "result_snapshot" JSONB NOT NULL,
    "settled_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "ranked_match_settlements_pkey" PRIMARY KEY ("match_id")
);

-- CreateTable
CREATE TABLE "learning"."ranked_rating_changes" (
    "id" UUID NOT NULL,
    "match_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "season_id" VARCHAR(7) NOT NULL,
    "opponent_id" UUID NOT NULL,
    "rating_before" INTEGER NOT NULL,
    "opponent_rating_before" INTEGER NOT NULL,
    "delta" INTEGER NOT NULL,
    "rating_after" INTEGER NOT NULL,
    "score" DECIMAL(2,1) NOT NULL,
    "expected_score" DECIMAL(12,10) NOT NULL,
    "k_factor" INTEGER NOT NULL,
    "career_count_before" INTEGER NOT NULL,
    "season_version_after" INTEGER NOT NULL,
    "league_before" "learning"."RankedLeague" NOT NULL,
    "league_after" "learning"."RankedLeague" NOT NULL,
    "change_kind" VARCHAR(32) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ranked_rating_changes_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "ranked_policies_config_hash_key" ON "learning"."ranked_policies"("config_hash");

-- CreateIndex
CREATE UNIQUE INDEX "ranked_seasons_starts_at_key" ON "learning"."ranked_seasons"("starts_at");

-- CreateIndex
CREATE UNIQUE INDEX "ranked_seasons_ends_at_key" ON "learning"."ranked_seasons"("ends_at");

-- CreateIndex
CREATE INDEX "ranked_seasons_settlement_state_ends_at_idx" ON "learning"."ranked_seasons"("settlement_state", "ends_at");

-- CreateIndex
CREATE INDEX "ranked_player_seasons_user_id_season_id_idx" ON "learning"."ranked_player_seasons"("user_id", "season_id" DESC);

-- CreateIndex
CREATE INDEX "ranked_match_settlements_season_id_settled_at_idx" ON "learning"."ranked_match_settlements"("season_id", "settled_at");

-- CreateIndex
CREATE UNIQUE INDEX "ranked_rating_changes_match_id_user_id_key" ON "learning"."ranked_rating_changes"("match_id", "user_id");

-- CreateIndex
CREATE UNIQUE INDEX "ranked_rating_changes_season_id_user_id_season_version_afte_key" ON "learning"."ranked_rating_changes"("season_id", "user_id", "season_version_after");

-- CreateIndex
CREATE INDEX "pvp_matches_season_id_status_id_idx" ON "learning"."pvp_matches"("season_id", "status", "id");

-- CreateIndex
CREATE INDEX "pvp_matches_status_current_question_deadline_idx" ON "learning"."pvp_matches"("status", "current_question_deadline");

-- CreateIndex
CREATE INDEX "pvp_matches_status_transition_deadline_idx" ON "learning"."pvp_matches"("status", "transition_deadline");

-- AddForeignKey
ALTER TABLE "learning"."pvp_matches" ADD CONSTRAINT "pvp_matches_season_id_fkey" FOREIGN KEY ("season_id") REFERENCES "learning"."ranked_seasons"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "learning"."pvp_match_answers" ADD CONSTRAINT "pvp_match_answers_match_id_user_id_fkey" FOREIGN KEY ("match_id", "user_id") REFERENCES "learning"."pvp_match_players"("match_id", "user_id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "learning"."ranked_seasons" ADD CONSTRAINT "ranked_seasons_policy_id_fkey" FOREIGN KEY ("policy_id") REFERENCES "learning"."ranked_policies"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "learning"."ranked_player_seasons" ADD CONSTRAINT "ranked_player_seasons_season_id_fkey" FOREIGN KEY ("season_id") REFERENCES "learning"."ranked_seasons"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "learning"."ranked_player_seasons" ADD CONSTRAINT "ranked_player_seasons_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "learning"."ranked_player_seasons" ADD CONSTRAINT "ranked_player_seasons_seed_source_season_id_user_id_fkey" FOREIGN KEY ("seed_source_season_id", "user_id") REFERENCES "learning"."ranked_player_seasons"("season_id", "user_id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "learning"."ranked_player_seasons" ADD CONSTRAINT "ranked_player_seasons_last_match_id_fkey" FOREIGN KEY ("last_match_id") REFERENCES "learning"."pvp_matches"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "learning"."ranked_match_settlements" ADD CONSTRAINT "ranked_match_settlements_match_id_fkey" FOREIGN KEY ("match_id") REFERENCES "learning"."pvp_matches"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "learning"."ranked_match_settlements" ADD CONSTRAINT "ranked_match_settlements_season_id_fkey" FOREIGN KEY ("season_id") REFERENCES "learning"."ranked_seasons"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "learning"."ranked_match_settlements" ADD CONSTRAINT "ranked_match_settlements_policy_id_fkey" FOREIGN KEY ("policy_id") REFERENCES "learning"."ranked_policies"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "learning"."ranked_rating_changes" ADD CONSTRAINT "ranked_rating_changes_match_id_fkey" FOREIGN KEY ("match_id") REFERENCES "learning"."ranked_match_settlements"("match_id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "learning"."ranked_rating_changes" ADD CONSTRAINT "ranked_rating_changes_match_id_user_id_fkey" FOREIGN KEY ("match_id", "user_id") REFERENCES "learning"."pvp_match_players"("match_id", "user_id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "learning"."ranked_rating_changes" ADD CONSTRAINT "ranked_rating_changes_season_id_user_id_fkey" FOREIGN KEY ("season_id", "user_id") REFERENCES "learning"."ranked_player_seasons"("season_id", "user_id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- Prisma cannot express these CHECKs, partial indexes, exclusions or triggers.
ALTER TABLE learning.ranked_seasons
  ADD CONSTRAINT ranked_season_calendar CHECK (
    id ~ '^[0-9]{4}-(0[1-9]|1[0-2])$' AND timezone='Asia/Kolkata'
    AND starts_at=((id || '-01')::timestamp AT TIME ZONE 'Asia/Kolkata')
    AND ends_at=(((id || '-01')::timestamp + interval '1 month') AT TIME ZONE 'Asia/Kolkata')
    AND ends_at>starts_at),
  ADD CONSTRAINT ranked_season_nonoverlap EXCLUDE USING gist (tstzrange(starts_at,ends_at,'[)') WITH &&),
  ADD CONSTRAINT ranked_season_final_state CHECK (
    (settlement_state='FINALIZED')=(finalized_at IS NOT NULL)
    AND (eligible_count IS NULL OR eligible_count>=0)
    AND (settlement_state<>'FINALIZED' OR eligible_count IS NOT NULL));
ALTER TABLE learning.ranked_player_seasons
  ADD CONSTRAINT ranked_player_counts CHECK (
    career_rated_before>=0 AND placements_required>0 AND played>=0 AND wins>=0 AND losses>=0 AND draws>=0
    AND played=wins+losses+draws AND version=played),
  ADD CONSTRAINT ranked_player_seed CHECK (seed_source_season_id IS NULL OR seed_source_season_id<season_id),
  ADD CONSTRAINT ranked_player_peaks CHECK (peak_rating>=rating AND peak_rating>=seed_rating),
  ADD CONSTRAINT ranked_player_qualification CHECK (
    (qualified_at IS NOT NULL)=(played>=placements_required)
    AND ((qualified_at IS NULL AND qualified_peak_rating IS NULL)
      OR (qualified_at IS NOT NULL AND qualified_peak_rating IS NOT NULL AND qualified_peak_rating>=rating))),
  ADD CONSTRAINT ranked_player_archive CHECK (
    (final_position IS NULL OR (final_position>0 AND qualified_at IS NOT NULL))
    AND (finalized_at IS NULL OR (final_rating IS NOT NULL AND final_league IS NOT NULL
      AND ((qualified_at IS NULL AND final_league='UNRANKED' AND final_peak_rating IS NULL AND final_position IS NULL)
        OR (qualified_at IS NOT NULL AND final_league<>'UNRANKED' AND final_peak_rating IS NOT NULL AND final_position IS NOT NULL)))));
CREATE INDEX ranked_player_qualified_order ON learning.ranked_player_seasons(season_id,rating DESC,user_id ASC) WHERE qualified_at IS NOT NULL;
CREATE UNIQUE INDEX ranked_player_final_position ON learning.ranked_player_seasons(season_id,final_position) WHERE final_position IS NOT NULL;
ALTER TABLE learning.pvp_matches
  ADD CONSTRAINT ranked_match_assignment CHECK (
    (rating_mode='LEGACY_UNRATED' AND season_id IS NULL AND season_assigned_at IS NULL)
    OR (rating_mode='RATED' AND season_id IS NOT NULL AND season_assigned_at IS NOT NULL
      AND hard_expires_at IS NOT NULL AND question_snapshot IS NOT NULL
      AND coalesce(question_snapshot->>'version','')='1' AND coalesce(jsonb_array_length(question_snapshot->'questions'),0)=10
      AND total_questions=10)),
  ADD CONSTRAINT ranked_match_version CHECK (state_version>=0),
  ADD CONSTRAINT ranked_match_reason CHECK (outcome_reason IS NULL OR outcome_reason IN ('NORMAL','SYSTEM_VOID'));
ALTER TABLE learning.ranked_rating_changes
  ADD CONSTRAINT ranked_change_math CHECK (
    rating_after::bigint=rating_before::bigint+delta::bigint AND score IN (0,0.5,1)
    AND expected_score BETWEEN 0 AND 1 AND k_factor>0 AND career_count_before>=0 AND season_version_after>0
    AND user_id<>opponent_id AND change_kind IN ('NONE','PLACEMENT_COMPLETE','PROMOTION','DEMOTION')),
  ADD CONSTRAINT ranked_change_opponent FOREIGN KEY (match_id,opponent_id)
    REFERENCES learning.pvp_match_players(match_id,user_id) ON DELETE RESTRICT;
ALTER TABLE learning.ranked_match_settlements
  ADD CONSTRAINT ranked_settlement_shape CHECK (
    result_schema_version=1 AND jsonb_typeof(result_snapshot)='object'
    AND outcome_hash ~ '^[a-f0-9]{64}$'
    AND (disposition<>'RATED' OR (season_id IS NOT NULL AND policy_id IS NOT NULL)));

CREATE FUNCTION learning.ranked_deny_audit_mutation() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'Ranked audit evidence is immutable'; END $$;
CREATE TRIGGER ranked_policy_immutable BEFORE UPDATE OR DELETE ON learning.ranked_policies
  FOR EACH ROW EXECUTE FUNCTION learning.ranked_deny_audit_mutation();
CREATE TRIGGER ranked_settlement_immutable BEFORE UPDATE OR DELETE ON learning.ranked_match_settlements
  FOR EACH ROW EXECUTE FUNCTION learning.ranked_deny_audit_mutation();
CREATE TRIGGER ranked_change_immutable BEFORE UPDATE OR DELETE ON learning.ranked_rating_changes
  FOR EACH ROW EXECUTE FUNCTION learning.ranked_deny_audit_mutation();

CREATE FUNCTION learning.ranked_freeze_identity() RETURNS trigger LANGUAGE plpgsql AS $$
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
END $$;
CREATE TRIGGER ranked_match_identity BEFORE UPDATE ON learning.pvp_matches FOR EACH ROW EXECUTE FUNCTION learning.ranked_freeze_identity();
CREATE TRIGGER ranked_season_identity BEFORE UPDATE ON learning.ranked_seasons FOR EACH ROW EXECUTE FUNCTION learning.ranked_freeze_identity();
CREATE TRIGGER ranked_standing_archive BEFORE UPDATE ON learning.ranked_player_seasons FOR EACH ROW EXECUTE FUNCTION learning.ranked_freeze_identity();

-- Cross-table invariants must be deferred until the complete transaction exists.
CREATE FUNCTION learning.ranked_check_settlement() RETURNS trigger LANGUAGE plpgsql AS $$
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
END $$;
CREATE CONSTRAINT TRIGGER ranked_match_integrity AFTER INSERT OR UPDATE ON learning.pvp_matches DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION learning.ranked_check_settlement();
CREATE CONSTRAINT TRIGGER ranked_settlement_integrity AFTER INSERT ON learning.ranked_match_settlements DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION learning.ranked_check_settlement();
CREATE CONSTRAINT TRIGGER ranked_ledger_integrity AFTER INSERT ON learning.ranked_rating_changes DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION learning.ranked_check_settlement();
CREATE FUNCTION learning.ranked_freeze_answer() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM learning.pvp_matches WHERE id=OLD.match_id AND rating_mode='RATED') THEN
    RAISE EXCEPTION 'Rated answer evidence is immutable';
  END IF;
  IF TG_OP='DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER ranked_answer_immutable BEFORE UPDATE OR DELETE ON learning.pvp_match_answers FOR EACH ROW EXECUTE FUNCTION learning.ranked_freeze_answer();
CREATE INDEX pvp_matches_status_hard_expires_at_idx ON learning.pvp_matches(status,hard_expires_at);
CREATE INDEX ranked_rating_changes_user_id_created_at_id_idx ON learning.ranked_rating_changes(user_id,created_at DESC,id DESC);
COMMIT;
