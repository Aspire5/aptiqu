# AptiQu Backend API — Release & Update Log

All notable changes, version updates, and migration notes for the AptiQu Node.js/TypeScript backend services.

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
