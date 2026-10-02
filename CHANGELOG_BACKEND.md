# AptiQu Backend API — Release & Update Log

All notable changes, version updates, and migration notes for the AptiQu Node.js/TypeScript backend services.

---

## [1.3.0] — 2026-10-02

### AI Prompts Management & Dynamic Server Execution
* **AiPrompt Prisma Model:** Added `AiPrompt` model (`@@schema("learning")`) supporting `key`, `title`, `description`, `category`, `draftPrompt`, `publishedPrompt`, `version`, `isLive`, and `lastPublishedAt`.
* **AiPromptService & In-Memory Cache:**
  * Implemented `AiPromptService` with zero-restart hot-swapping: reads from memory cache and syncs on boot.
  * `saveDraft`: Persists modified drafts without affecting live server execution.
  * `publishPrompt`: Copies draft to published, increments version, and updates memory cache instantly.
* **Dynamic Generation Services:**
  * `QuestionGenerationService`: Dynamically queries `PRACTICE_GENERATION` prompt from `AiPromptService`.
  * `PvpSetGenerationService`: Dynamically queries `PVP_GENERATION` prompt from `AiPromptService`.
  * `AdminAiPromptsController`: Registered REST endpoints under `/api/v1/admin/ai-prompts` for list, get, draft update, publish, and reset.
* **Daily Challenge Inventory Depletion Monitoring:**
  * Added `AdminDashboardService.getDailyChallengeInventoryStatus()` monitoring remaining unused manual PYQ counts per difficulty (`EASY`, `MEDIUM`, `HARD`).
  * Emits `CRITICAL` or `WARNING` status alerts to admin dashboard when inventory is depleted or low.
* **Roadmap Progression Invariant:** Fixed `getNextStepOrScript` to return `SCRIPT_NOT_PUBLISHED` when the next active step in sequence does not have published content.

---

## [1.2.0] — 2026-10-02

### Book Curriculum, PYQ Provenance & Dual Solutions
* **Prisma Schema Extensions:**
  * Added `externalKey` (unique text identifier) to `Question` for stable script cross-referencing.
  * Added `pyq` string column for competitive exam tags (`"exam_name (year), ..."`).
  * Added provenance metadata: `sourceBook`, `sourceEdition`, `sourceChapter`, `sourcePageRange`.
  * Added dual-solution fields: `alternativeExplanation`, `preferredSolution` (`BOOK` | `ALTERNATIVE`), and `preferredReason`.
  * Added `QuestionGenerationMethod` enum (`HUMAN_MANUAL`, `AI_EXTRACTED`, `AI_SYNTHETIC`).
  * Enforced database-level unique constraint `@@unique([questionId])` on `DailyChallengeScriptQuestion` to guarantee no question is ever repeated in daily challenges.
* **Practice Question Selection Invariant:**
  * Replaced in-memory filtering with database-level scalable query checking `userQuestionProgress` with `timesCorrect > 0`.
  * Enforced strict curriculum invariant: serves 100% `MANUAL` questions (unsolved first, reinforcement second) while any unsolved manual question exists in a topic. AI questions are only served when 100% of manual questions have been correctly solved.
* **Daily Challenge Curated Candidate Selection:**
  * Swapped synthetic question generation for authoritative candidate queries: strictly `MANUAL`, `PUBLISHED`, `pyq != null`, and `dailyChallengeScriptQuestions: { none: {} }`.
  * Preserves `Asia/Kolkata` midnight boundary and halts creation if candidate pool is depleted.
* **Strict Script Import & Verification API:**
  * Added `POST /api/v1/admin/syllabus/scripts/import` verifying that all `QUESTION_EXTERNAL_ID` references exist in the database, belong to the target topic, and belong to the target subtopic prior to persisting.
* **Bulk Question Ingestion:**
  * Batched subtopic lookup by ID and slug with strict error rejection on unknown keys.
  * Defaults imported curriculum items to `REVIEW` status and `sourceType: MANUAL`.

---

## [1.1.0] — 2026-10-01

### Curriculum Reordering & Reusability
* **Prisma Schema Update:** Added `sequence` field to `Topic` and introduced `SubjectTopic` and `TopicSubtopic` join models with unique compound keys.
* **Non-Alphabetical Study Sequence:** Replaced alphabetical topic queries with sequence-based sorting preserving pedagogical study order.
* **Topic & Subtopic Reusability APIs:** Added endpoints to link, unlink, reorder, and discover reusable topics and subtopics without data duplication or deletion.
* **Safe Unlink Protocol:** Unlinking an entity dissociates the parent-child relation while preserving underlying questions, scripts, and stats.

### Midnight IST Streak Cron & Lazy AI Generation
* **12:00 AM IST Cron Job:** Scheduled daily midnight IST (`18:30 UTC`) maintenance job using `node-cron` with `{ timezone: 'Asia/Kolkata' }`.
* **Atomic Broken Streak Reset:** Automatically resets streaks to 0 for users with `streak >= 1` who missed yesterday's daily challenge.
* **Lazy AI Script Generation:** Pre-generates daily challenge scripts across tiers (Tier 1: 1 Easy; Tier 2: 1 Easy + 1 Med; Tier 3: 1 Easy + 1 Med + 1 Hard) only if active users exist in that tier, saving expensive AI API calls.
* **Profile API Timer Enriched:** `getProfile` and `getStatus` return `timeRemainingMs` and `expiresAt` ISO timestamps for frontend countdowns.

---

## [1.0.0] — 2026-10-01 (Production Release)

### Core Services & Security
* **Authentication Engine:** Production Google OAuth ID token verification via `google-auth-library`.
* **Session Lifecycle:** 7-day refresh token rotation with atomic revocation on `/auth/logout`.
* **Database & ORM:** PostgreSQL schema powered by Prisma with complete models for users, game profiles, roadmaps, topics, subtopics, lessons, questions, and matchmaking state.
* **Real-time Matchmaking:** WebSocket server and Redis queue managing 1v1 PvP ranked duels with tick synchronization.

### API Capabilities
* **Progression System:** Level-up thresholds, XP curves, and streak multipliers.
* **Practice Drills:** Dynamic question retrieval by subject, topic, and difficulty rating.
* **Daily Challenge Arena:** Synchronized daily aptitude challenge with streak verification and coins/XP distribution.
* **Analytics Endpoints:** Administrative aggregated metrics for user registrations, active daily cohorts, challenge completion ratios, and curriculum progression.
