-- Additive change; NOT executed automatically. Apply under the database change policy.
-- Run enum changes before transactions that use their new values.
ALTER TYPE learning."QuestionSourceType" ADD VALUE IF NOT EXISTS 'Luna';
ALTER TYPE learning."FriendlyDuelStatus" ADD VALUE IF NOT EXISTS 'PREPARING';

BEGIN;
ALTER TABLE learning.questions ADD COLUMN IF NOT EXISTS reference_question_id uuid;
ALTER TABLE learning.questions ADD COLUMN IF NOT EXISTS reference_snapshot jsonb;
ALTER TABLE learning.questions ADD COLUMN IF NOT EXISTS generation_profile text;
ALTER TABLE learning.practice_sessions ADD COLUMN IF NOT EXISTS question_snapshot jsonb;
CREATE TABLE IF NOT EXISTS learning.question_preparations (
  id uuid PRIMARY KEY,
  request_key text NOT NULL UNIQUE,
  user_ids uuid[] NOT NULL,
  mode text NOT NULL CHECK (mode IN ('PRACTICE','RANKED','UNRANKED','FRIENDLY')),
  tier text NOT NULL CHECK (tier IN ('UNRANKED','BRONZE','SILVER','GOLD','PLATINUM','DIAMOND')),
  state text NOT NULL DEFAULT 'QUEUED' CHECK (state IN ('QUEUED','GENERATING','REVIEWING','REPAIRING','REREVIEWING','SAVING','READY','FAILED','CANCELLED','EXPIRED')),
  version integer NOT NULL DEFAULT 0,
  scope jsonb NOT NULL,
  manifest jsonb,
  call_count integer NOT NULL DEFAULT 0 CHECK (call_count BETWEEN 0 AND 4),
  usage jsonb NOT NULL DEFAULT '[]',
  worker_token uuid,
  result_set_id uuid,
  result_session_id uuid,
  result_snapshot jsonb,
  error_code text,
  deadline timestamp(3) NOT NULL,
  created_at timestamp(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CHECK (cardinality(user_ids) BETWEEN 1 AND 2)
);
CREATE INDEX IF NOT EXISTS question_preparations_state_deadline_idx ON learning.question_preparations(state,deadline);
CREATE INDEX IF NOT EXISTS question_preparations_user_ids_idx ON learning.question_preparations USING gin(user_ids);
COMMIT;
