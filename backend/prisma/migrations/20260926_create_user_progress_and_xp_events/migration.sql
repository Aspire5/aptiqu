-- CreateTable
CREATE TABLE IF NOT EXISTS "gamification"."user_progress" (
    "user_id" UUID NOT NULL,
    "total_xp" BIGINT NOT NULL DEFAULT 0,
    "level" INTEGER NOT NULL DEFAULT 1,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "user_progress_pkey" PRIMARY KEY ("user_id")
);

-- CreateTable
CREATE TABLE IF NOT EXISTS "gamification"."xp_events" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "amount" BIGINT NOT NULL,
    "source_type" TEXT NOT NULL,
    "source_id" TEXT,
    "roadmap_id" TEXT,
    "subject_id" TEXT,
    "topic_id" TEXT,
    "subtopic_id" TEXT,
    "question_id" TEXT,
    "lesson_session_id" UUID,
    "description" TEXT,
    "metadata" JSONB,
    "idempotency_key" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "xp_events_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX IF NOT EXISTS "xp_events_idempotency_key_key" ON "gamification"."xp_events"("idempotency_key");

-- CreateIndex
CREATE INDEX IF NOT EXISTS "xp_events_user_id_created_at_idx" ON "gamification"."xp_events"("user_id", "created_at" DESC);

-- CreateIndex
CREATE INDEX IF NOT EXISTS "xp_events_user_id_source_type_idx" ON "gamification"."xp_events"("user_id", "source_type");

-- AddForeignKey
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'user_progress_user_id_fkey'
    ) THEN
        ALTER TABLE "gamification"."user_progress" ADD CONSTRAINT "user_progress_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
    END IF;
END $$;

-- AddForeignKey
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'xp_events_user_id_fkey'
    ) THEN
        ALTER TABLE "gamification"."xp_events" ADD CONSTRAINT "xp_events_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
    END IF;
END $$;
