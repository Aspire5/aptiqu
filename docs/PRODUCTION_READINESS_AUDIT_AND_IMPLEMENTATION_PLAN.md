# APTIQU PRODUCTION READINESS IMPLEMENTATION PLAN — REVISED
**Document Status:** Final Technical Blueprint (Engineering & Remediation Plan)  
**Target Platform:** Aptiqu Monorepo (`Flutter Mobile App`, `Node.js + Express + TypeScript Backend`, `PostgreSQL via Prisma`, `Redis Infrastructure`, `React Admin Dashboard`)  
**Architecture Baseline:** Real-World Production Readiness (Single/Dual Node VPS, High Reliability, Pragmatic Scale)

---

## 1. UPDATED EXECUTIVE SUMMARY & SYSTEM OVERVIEW

The Aptiqu platform is a functional gamified education system featuring interactive lessons, an AI tutor playground, syllabus constellation roadmaps, practice drills, real-time ranked PvP duels, a daily streak challenge, and an administrative content studio.

Following an architectural review and owner calibration pass, the remediation scope has been refocused from speculative "1M-user" over-engineering to **practical production reliability, robust security, database correctness, and seamless user experiences**.

### Key Decisions Incorporated
1. **Daily Streak Reset:** Fixed strictly to **12:00 AM IST (Asia/Kolkata)** for all users. International per-user timezones are explicitly out of scope and removed from bug findings.
2. **Admin Authentication:** Retained as `.env`-based authentication. We explicitly **reject** creating an `admin_users` table or database-backed identity subsystem. Remediation focuses strictly on removing hardcoded fallback credentials, enforcing fail-fast startup checks when `.env` secrets are missing, preventing timing attacks, and enforcing rate limiting.
3. **Physical Deletions (Hard Delete):** Hard delete is an **intentional design decision** and will be maintained. Remediation will not introduce soft deletion (`deletedAt`) or complex archiving layers.
4. **Pragmatic Scaling vs. Premature Optimization:** Heavy analytical rollups, materialized aggregation views, and microservice infrastructure are **deferred**. Instead, we address concrete performance defects: in-memory loading of unbounded tables, N+1 query patterns, missing foreign key indexes, and synchronous LLM generation inside user-facing HTTP request loops.

---

## 2. UPDATED FEATURE & MODULE INVENTORY

The platform consists of 8 active modules mapped across Frontend, API, Backend, Database, and Infrastructure:

```text
===================================================================================================
1. AUTHENTICATION & ONBOARDING
===================================================================================================
Flutter:
  - Screens: LoginScreen (lib/features/auth), SignUpScreen (lib/features/onboarding)
  - Controllers: AuthController, SignUpController
Admin:
  - Screen: LoginPage (admin-dashboard/src/pages/LoginPage.tsx)
APIs:
  - POST /api/v1/auth/google
  - POST /api/v1/auth/onboarding
  - POST /api/v1/auth/refresh
  - POST /api/v1/auth/logout
  - POST /api/v1/admin/auth/login
  - GET  /api/v1/admin/auth/me
Backend:
  - Modules: auth.controller.ts, auth.service.ts, admin-auth.controller.ts
  - Helpers: google.ts, jwt.ts, crypto.ts
Database Tables:
  - auth.users, auth.refresh_tokens, users.profiles, gamification.stats, gamification.user_progress
Redis: None (tokens verified via JWT secret & DB hash)
Queues / Workers: None

===================================================================================================
2. USER PROFILE & GAMIFICATION SUMMARY
===================================================================================================
Flutter:
  - Screens: ProfileScreen (lib/features/profile), TopBarZone (lib/features/home)
  - Controllers: AuthController, XpController
Admin:
  - Screen: UsersPage (admin-dashboard/src/pages/UsersPage.tsx)
APIs:
  - GET /api/v1/user/profile
  - GET /api/v1/user/progress
  - GET /api/v1/user/stats
Backend:
  - Modules: user.controller.ts, user.service.ts, xp.service.ts, xp.policy.ts
Database Tables:
  - auth.users, users.profiles, gamification.stats, gamification.user_progress, gamification.xp_events
Redis: In-memory/Redis 2-min cache for question count totals

===================================================================================================
3. CURRICULUM, ROADMAPS & CONSTELLATION MAP
===================================================================================================
Flutter:
  - Screens: ConstellationRoadmapView, SubjectPlayCardsView (lib/features/home/presentation/widgets)
  - Controller: HomeController
Admin:
  - Screen: SyllabusPage (admin-dashboard/src/pages/SyllabusPage.tsx)
APIs:
  - GET  /api/v1/roadmaps
  - GET  /api/v1/roadmaps/active
  - POST /api/v1/roadmaps/steps/:stepId/start
  - POST /api/v1/roadmaps/:roadmapId/select
  - GET  /api/v1/roadmaps/:roadmapId
  - GET  /api/v1/roadmaps/:roadmapId/subjects/:subjectId/map
Backend:
  - Modules: roadmap.controller.ts, roadmap-progression.service.ts, live-curriculum.service.ts
Database Tables:
  - learning.roadmaps, learning.roadmap_subjects, learning.roadmap_steps, learning.subjects,
    learning.topics, learning.subtopics, learning.subject_topics, learning.topic_subtopics,
    learning.script_assignments, learning.user_roadmap_step_progress
Redis: Cached curriculum resolution

===================================================================================================
4. INTERACTIVE LESSON FEED (AI TUTOR)
===================================================================================================
Flutter:
  - Screens: LessonFeedScreen (lib/features/lesson/views), ChatPlaygroundZone (lib/features/home)
  - Controller: LessonFeedController
Admin:
  - Screen: SyllabusPage (Script Inspector & Version Editor)
APIs:
  - GET  /api/v1/lessons/active
  - POST /api/v1/lessons/sessions
  - GET  /api/v1/lessons/sessions/:id
  - POST /api/v1/lessons/sessions/:id/actions
  - POST /api/v1/lessons/sessions/:id/interrupts
  - POST /api/v1/lessons/sessions/:id/pause
  - POST /api/v1/lessons/sessions/:id/resume
Backend:
  - Modules: lesson.controller.ts, lesson-session.service.ts, transition-engine.ts, script-cache.service.ts
Database Tables:
  - learning.lesson_scripts, learning.lesson_script_versions, learning.lesson_sessions,
    learning.lesson_events, learning.question_attempts, learning.student_concept_mastery,
    gamification.xp_events, gamification.user_progress
Redis:
  - `idemp:action:<clientActionId>` (Action idempotency cache)
  - `lock:session:<sessionId>` (Session update mutex)

===================================================================================================
5. PRACTICE MODE / QUICK DRILLS
===================================================================================================
Flutter:
  - Screens: PracticeCatalogView, PracticeSessionScreen (lib/features/practice/views)
  - Controllers: PracticeCatalogController, PracticeSessionController
Admin:
  - Screen: QuestionsPage (admin-dashboard/src/pages/QuestionsPage.tsx)
APIs:
  - GET  /api/v1/practice/topics/live
  - GET  /api/v1/practice/history
  - POST /api/v1/practice/sessions
  - GET  /api/v1/practice/sessions/:sessionId
  - POST /api/v1/practice/sessions/:sessionId/answer
  - POST /api/v1/practice/sessions/:sessionId/abandon
  - POST /api/v1/practice/replay/:sessionId
Backend:
  - Modules: practice.controller.ts, practice-session.service.ts, practice-selection.service.ts,
    question-generation.service.ts
Database Tables:
  - learning.practice_sessions, learning.practice_session_questions, learning.questions,
    learning.user_question_progress, gamification.xp_events, gamification.user_progress
Redis:
  - `LOCK:SHORTAGE_GEN:<subtopicId>` (Distributed lock during question synthesis)
Queues / Workers: Target for BullMQ question pre-warming queue

===================================================================================================
6. REAL-TIME RANKED PVP DUELS
===================================================================================================
Flutter:
  - Screens: PvpLobbyView, PvpArenaScreen (lib/features/pvp/views)
  - Controllers: PvpLobbyController, PvpArenaController
  - Service: PvpSocketService
APIs / WebSocket:
  - WS   /ws/pvp
  - GET  /api/v1/pvp/matches/:matchId
  - GET  /api/v1/pvp/history
  - POST /api/v1/pvp/replay/:matchId
Backend:
  - Modules: pvp.socket.ts, pvp.controller.ts, pvp-match.service.ts, pvp-set-generation.service.ts
Database Tables:
  - learning.pvp_question_sets, learning.pvp_question_set_questions, learning.pvp_matches,
    learning.pvp_match_players, learning.pvp_match_answers, learning.pvp_player_set_history,
    gamification.xp_events, gamification.user_progress
Redis: Target for matchmaking queues and shared ephemeral match state

===================================================================================================
7. DAILY CHALLENGE & STREAK SYSTEM
===================================================================================================
Flutter:
  - Screens: DailyStreakHubScreen, DailyChallengeQuizScreen (lib/features/daily_challenge)
  - Controller: DailyChallengeController
Admin:
  - Screen: DashboardPage (Daily Inventory Depletion Alert Banner)
APIs:
  - GET  /api/v1/daily-challenge/status
  - POST /api/v1/daily-challenge/start
  - POST /api/v1/daily-challenge/answer
  - GET  /api/v1/daily-challenge/history
Backend:
  - Modules: daily-challenge.controller.ts, daily-challenge.service.ts, daily-challenge-generation.service.ts
Database Tables:
  - learning.daily_challenge_scripts, learning.daily_challenge_script_questions,
    learning.daily_challenge_participations, learning.daily_challenge_answers,
    learning.questions, gamification.stats, gamification.xp_events, gamification.user_progress
Cron: Midnight IST cron job for streak reset and lazy/pre-warmed script rollover

===================================================================================================
8. ADMIN STUDIO & CONTENT CMS
===================================================================================================
Admin:
  - Screens: DashboardPage, SyllabusPage, QuestionsPage, UsersPage, AiPromptsPage
APIs:
  - 35 endpoints under /api/v1/admin/*
Backend:
  - Modules: admin.routes.ts, admin-auth, admin-dashboard, admin-syllabus, admin-questions,
    admin-users, admin-ai-prompts controllers & services
Database Tables:
  - Complete read/write access to all 4 schemas
Redis: Dynamic timing configurations
```

---

# 3. UPDATED ARCHITECTURE MODEL

```
                                  +---------------------------------------+
                                  |         FLUTTER MOBILE CLIENT         |
                                  | - GetX Controllers (Domain State)     |
                                  | - GoRouter (Unified Declarative Stack)|
                                  | - Dio Client (HTTPS + Token Rotate)   |
                                  +-------------------+-------------------+
                                                      |
                                     HTTPS / WSS (Domain URL)
                                                      |
                                                      v
+-----------------------+              +------------------------------------+
|    ADMIN DASHBOARD    |   HTTPS      |      NODE.JS / EXPRESS BACKEND     |
| - React 18 + Vite     |------------> | - Fail-Fast Config (requiredEnv)   |
| - Fixed Route Paths   |              | - Centralized Prisma Transactions  |
| - Timing-Safe Auth    |              | - PvP Socket Coordinator           |
+-----------------------+              +---------+----------------+---------+
                                                 |                |
                                     Prisma ORM  |                | ioredis (Exponential
                                                 v                |          Backoff Reconnect)
                                      +----------+-----+   +------v-------+
                                      |   POSTGRESQL   |   |    REDIS     |
                                      | - Multi-schema |   | - Mutex Locks|
                                      | - Target Index |   | - PvP State  |
                                      | - Cascade Fixes|   | - BullMQ Qs  |
                                      +----------------+   +--------------+
```

---

# 4. FINDING VALIDATION MATRIX

Every finding from the initial audit has been reassessed against source evidence, owner decisions, and actual risk:

| Finding ID | Finding | Evidence (File & Line) | Classification | Confidence | Needs Testing? | Recommended Action |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **SEC-01** | Google OAuth sandbox bypass | [google.ts:21-34](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/utils/google.ts#L21-L34) | **VERIFIED SECURITY ISSUE** | 100% | Yes (OAuth unit test) | **Delete bypass completely.** Verify token via Google API ticket in all environments. |
| **SEC-02** | Hardcoded admin credentials & fallback secrets | [env.ts:9-28](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/config/env.ts#L9-L28) | **VERIFIED SECURITY ISSUE** | 100% | Yes (Startup validation) | **Enforce `requiredEnv()`**. Fail fast on boot if env vars are missing. Remove DB admin table proposal. |
| **SEC-03** | Plain HTTP backend URL | [dio_client.dart:12](file:///Users/shagunkumar/Desktop/aptiqu/lib/core/network/dio_client.dart#L12) | **VERIFIED SECURITY ISSUE** | 100% | Yes (SSL inspection) | Replace `http://15.252.71.142:5001/api/v1` with domain HTTPS endpoint. |
| **SEC-04** | Admin password comparison timing attack | [admin-auth.controller.ts:20](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin-auth.controller.ts#L20) | **VERIFIED SECURITY ISSUE** | 100% | No | Use `crypto.timingSafeEqual()` with SHA-256 hashes of credentials. |
| **SEC-05** | WebSocket auth token in URL query parameter | [pvp_socket_service.dart:36](file:///Users/shagunkumar/Desktop/aptiqu/lib/features/pvp/services/pvp_socket_service.dart#L36) | **VERIFIED SECURITY ISSUE** | 100% | Yes | Pass token in initial WS message handshake (`AUTH_INIT`) or short-lived ticket. |
| **SEC-06** | IDOR on PvP Match Details | [pvp.controller.ts:25](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/pvp/pvp.controller.ts#L25) | **VERIFIED SECURITY ISSUE** | 95% | Yes (Access test) | Verify `req.userId` is a member of `match.players` or caller is admin. |
| **DAT-01** | Nested Prisma Transaction Deadlock Hazard | [daily-challenge.service.ts:501, 567](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/daily-challenge/daily-challenge.service.ts#L501) & [xp.service.ts:74](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/xp/xp.service.ts#L74) | **VERIFIED DATA INTEGRITY ISSUE** | 100% | Yes (Concurrency test) | Pass existing `tx` client into `awardXp(input, tx)`. Remove inner `$transaction`. |
| **DAT-02** | BigInt serialization crash risk | [schema.prisma:102](file:///Users/shagunkumar/Desktop/aptiqu/backend/prisma/schema.prisma#L102) & [xp.service.ts:39](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/xp/xp.service.ts#L39) | **VERIFIED DATA INTEGRITY ISSUE** | 100% | Yes | Explicit serialization contract: Always convert `BigInt` to JS `Number` in DTOs. |
| **DAT-03** | Streak format mismatch (`Int` vs `'0d'`) | [auth.service.ts:119](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/auth/auth.service.ts#L119) vs [daily-challenge.service.ts:301](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/daily-challenge/daily-challenge.service.ts#L301) | **VERIFIED DATA INTEGRITY ISSUE** | 100% | Yes (Model parsing) | Standardize API to return raw integer `streak: number`. Format as `'Xd'` in Flutter UI only. |
| **DAT-04** | Missing `preferredSolution` field in Flutter | [daily_challenge_models.dart:122](file:///Users/shagunkumar/Desktop/aptiqu/lib/features/daily_challenge/models/daily_challenge_models.dart#L122) | **VERIFIED DATA INTEGRITY ISSUE** | 100% | Yes | Add `preferredSolution` string to Dart models and deserialize from API response. |
| **PERF-01**| Synchronous LLM generation in HTTP path | [practice-selection.service.ts:126](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/practice/services/practice-selection.service.ts#L126) | **VERIFIED PERFORMANCE ISSUE** | 100% | Yes (Load benchmark) | Never block HTTP request on Gemini. Serve existing inventory and dispatch BullMQ background job. |
| **PERF-02**| In-memory full-table scan on PvP set select | [pvp-match.service.ts:93-104](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/pvp/services/pvp-match.service.ts#L93-L104) | **VERIFIED PERFORMANCE ISSUE** | 100% | Yes | Replace `findMany({ include: ... })` with targeted SQL query selecting unseen set ID. |
| **PERF-03**| In-memory aggregation across 5 tables for stats | [user.service.ts:198-225](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/user/user.service.ts#L198-L225) | **VERIFIED PERFORMANCE ISSUE** | 100% | Yes | Replace multi-table array deduplication with SQL `COUNT(DISTINCT questionId)`. |
| **PERF-04**| Missing foreign key indexes on high-churn tables | [schema.prisma:521, 588, 648, 977](file:///Users/shagunkumar/Desktop/aptiqu/backend/prisma/schema.prisma#L521) | **VERIFIED PERFORMANCE ISSUE** | 95% | Yes (EXPLAIN ANALYZE) | Add justified indexes on `questionId` in session/answer tables to accelerate cascade deletes. |
| **ARCH-01**| PvP sockets & matchmaking in process RAM | [pvp.socket.ts:23-25](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/pvp/pvp.socket.ts#L23-L25) | **VERIFIED ARCHITECTURAL ISSUE** | 100% | Yes (Multi-node duel) | Move matchmaking queue to Redis Sorted Set. Keep socket connections local. |
| **ARCH-02**| Unsafe Redis lock release (Lock Stomping) | [concurrency-lock.service.ts:16-19](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/concurrency/concurrency-lock.service.ts#L16-L19) | **VERIFIED ARCHITECTURAL ISSUE** | 100% | Yes | Release lock using Lua script checking unique ownership UUID. |
| **ARCH-03**| Unbounded local `Map` fallback in RedisService | [redis.service.ts:8, 51-57](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/lesson/services/redis.service.ts#L8) | **VERIFIED ARCHITECTURAL ISSUE** | 100% | Yes | Remove silent local map fallback for locks. Enforce exponential reconnect on ioredis. |
| **ARCH-04**| Fragmented Flutter navigation (Get.to vs GoRouter) | [pvp_lobby_controller.dart:183](file:///Users/shagunkumar/Desktop/aptiqu/lib/features/pvp/controllers/pvp_lobby_controller.dart#L183) | **VERIFIED ARCHITECTURAL ISSUE** | 100% | Yes | Register `/practice-session` & `/pvp-arena` in `AppRouter`. Remove raw `MaterialPageRoute` pushes. |
| **UI-01**  | Admin Dashboard unlinking 404 URL mismatch | [api.ts:74, 78](file:///Users/shagunkumar/Desktop/aptiqu/admin-dashboard/src/services/api.ts#L74) vs [admin.routes.ts:56, 58](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts#L56) | **VERIFIED BUG** | 100% | Yes | Fix frontend Axios URLs to match backend `/unlink` routes. |
| **UI-02**  | Silent token wipe on transient startup network lag | [auth_controller.dart:53-54](file:///Users/shagunkumar/Desktop/aptiqu/lib/features/auth/presentation/controllers/auth_controller.dart#L53-L54) | **VERIFIED BUG** | 95% | Yes | Only clear tokens on explicit 401 `TOKEN_EXPIRED`. Retain tokens on connection errors. |
| **UI-03**  | Hardcoded domain entity fallback `'ga-qa-01'` | [home_controller.dart:278](file:///Users/shagunkumar/Desktop/aptiqu/lib/features/home/presentation/controllers/home_controller.dart#L278) | **VERIFIED BUG** | 90% | Yes | Handle empty syllabus explicitly with user-facing message instead of magic entity ID. |
| **UI-04**  | Duplicated XP math in Flutter | [home_controller.dart:115-124](file:///Users/shagunkumar/Desktop/aptiqu/lib/features/home/presentation/controllers/home_controller.dart#L115-L124) | **VERIFIED ARCHITECTURAL ISSUE** | 95% | No | Backend is sole authority on awarded XP. Client only renders returned values. |
| **DES-01** | Midnight IST Streak Boundary | [daily-challenge.service.ts:26-47](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/daily-challenge/daily-challenge.service.ts#L26-L47) | **INTENTIONAL DESIGN DECISION** | 100% | No | **Accept as product requirement.** Remove from bug findings. |
| **DES-02** | Hard Delete of Users/Questions | [admin-questions.service.ts:320-334](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin-questions.service.ts#L320-L334) | **INTENTIONAL DESIGN DECISION** | 100% | No | **Accept as product requirement.** Maintain physical deletion. |
| **DEF-01** | Admin Dashboard 50+ relational counting queries | [admin-dashboard.service.ts:17-80](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin-dashboard.service.ts#L17-L80) | **DEFERRED** | 80% | Post-launch | Mark as deferred scale item. Optimize lightweight counts now; avoid materialized tables. |

---

## 5. DETAILED AUDIT FINDINGS BY DOMAIN

### 5.1 Security Findings
1. **Google OAuth Sandbox Bypass ([google.ts:21-34](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/utils/google.ts#L21-L34)):**
   - *Current Code:* `if (idToken.startsWith('mock_test_token_'))` generates an authenticated session for any email suffix provided in the token string.
   - *Risk:* Anyone can spoof an administrative or student account in production without credentials.
   - *Remediation:* Remove lines 21–34. Authenticate strictly via `client.verifyIdToken`.
2. **Hardcoded Fallbacks in Configuration ([env.ts:9-28](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/config/env.ts#L9-L28)):**
   - *Current Code:* Fallbacks exist for `ADMIN_USERNAME`, `ADMIN_PASSWORD`, `ADMIN_JWT_SECRET`, and `JWT_ACCESS_SECRET`.
   - *Risk:* If `.env` is omitted or misconfigured, production runs with known default secrets.
   - *Remediation:* Implement a strict `requiredEnv(key: string): string` validator that throws a fatal error on boot if any secret is missing.
3. **Admin Credential Comparison & Rate Limiting ([admin-auth.controller.ts:20](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin-auth.controller.ts#L20)):**
   - *Current Code:* Standard `===` string comparison against environment variables. No rate limiter attached to `POST /api/v1/admin/auth/login`.
   - *Remediation:* Hash input with `crypto.createHash('sha256')` and compare using `crypto.timingSafeEqual()`. Mount an in-memory rate limiter (5 failed attempts per 15 minutes).
4. **Plain HTTP Communication ([dio_client.dart:12](file:///Users/shagunkumar/Desktop/aptiqu/lib/core/network/dio_client.dart#L12)):**
   - *Current Code:* Hardcoded to `http://15.252.71.142:5001/api/v1`.
   - *Remediation:* Switch to domain-level HTTPS (`https://api.aptiqu.com/api/v1`) with TLS certificate termination.

### 5.2 Correctness & Data Flow Findings
1. **Nested Prisma Transaction Deadlock ([daily-challenge.service.ts:501-574](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/daily-challenge/daily-challenge.service.ts#L501-L574) & [xp.service.ts:74](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/xp/xp.service.ts#L74)):**
   - *Current Code:* `dailyChallengeService.submitAnswer` opens `prisma.$transaction(async (tx) => ...)`. Inside `tx`, it invokes `XpService.getInstance().awardXp(...)`, which immediately opens a second `prisma.$transaction`.
   - *Risk:* Under concurrent answers, threads exhaust the Prisma connection pool, causing deadlocks or rolled-back state where XP is permanently committed while the challenge record is marked failed.
   - *Remediation:* Refactor `awardXp(input, txClient?: Prisma.TransactionClient)` to reuse the parent transaction client.
2. **Streak API Inconsistency ([auth.service.ts:119](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/auth/auth.service.ts#L119) vs [daily-challenge.service.ts:301](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/daily-challenge/daily-challenge.service.ts#L301)):**
   - *Current Code:* Some endpoints return streak as a string `'0d'` while others return a number `0`.
   - *Remediation:* Standardize all backend APIs to return machine-readable numbers (`streak: number`). Let Flutter format `'Xd'` visually.
3. **Missing `preferredSolution` in Mobile Models ([daily_challenge_models.dart:122](file:///Users/shagunkumar/Desktop/aptiqu/lib/features/daily_challenge/models/daily_challenge_models.dart#L122)):**
   - *Current Code:* Backend returns `preferredSolution` (`BOOK` or `ALTERNATIVE`), but Flutter models omit the field.
   - *Remediation:* Add `preferredSolution` to Dart question models and display the solution badge in the quiz review UI.
4. **Hardcoded Entity Fallback `'ga-qa-01'` ([home_controller.dart:278](file:///Users/shagunkumar/Desktop/aptiqu/lib/features/home/presentation/controllers/home_controller.dart#L278)):**
   - *Current Code:* `availableTopic?.roadmapStepId ?? 'ga-qa-01'`. If syllabus is empty or loading fails, the client attempts to start a non-existent step.
   - *Remediation:* Replace fallback with explicit null checking and display an empty/error state.

### 5.3 Performance & Database Findings
1. **Synchronous LLM Calls in User HTTP Loops ([practice-selection.service.ts:126-130](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/practice/services/practice-selection.service.ts#L126-L130)):**
   - *Current Code:* When question inventory in a subtopic is low, `selectQuestionsForPractice` awaits Gemini generation directly inside the user's request.
   - *Risk:* Takes 5–20 seconds, frequently causing Dio client timeouts (30s) and Gemini rate limit errors under concurrent requests.
   - *Remediation:* Serve current available questions (or fill from adjacent subtopics). Dispatch an asynchronous BullMQ job to replenish inventory in the background.
2. **In-Memory Table Scans for PvP Question Sets ([pvp-match.service.ts:93-104](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/pvp/services/pvp-match.service.ts#L93-L104)):**
   - *Current Code:* Calls `findMany({ where: { status: 'PUBLISHED' }, include: { playerHistory: true, setQuestions: ... } })` to pull all question sets into memory, then filters in JavaScript.
   - *Remediation:* Query the database directly for a single unplayed set:
     ```sql
     SELECT id FROM learning.pvp_question_sets qs
     WHERE qs.status = 'PUBLISHED'
       AND NOT EXISTS (
         SELECT 1 FROM learning.pvp_player_set_history h
         WHERE h.question_set_id = qs.id AND h.user_id IN ($1, $2)
       )
     ORDER BY qs.updated_at ASC LIMIT 1;
     ```
3. **In-Memory Question Count Aggregation ([user.service.ts:198-225](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/user/user.service.ts#L198-L225)):**
   - *Current Code:* Loads thousands of rows across 5 tables into Node arrays on every profile view.
   - *Remediation:* Replace array loops with database aggregation (`COUNT(DISTINCT "question_id")`).
4. **Missing Foreign Key Indexes ([schema.prisma](file:///Users/shagunkumar/Desktop/aptiqu/backend/prisma/schema.prisma)):**
   - Add justified indexes to eliminate sequential scans during deletes and joins:
     - `learning.practice_session_questions(questionId)`
     - `learning.pvp_question_set_questions(questionId)`
     - `learning.pvp_match_answers(questionId)`
     - `learning.daily_challenge_answers(questionId)`
     - `auth.refresh_tokens(userId)`

### 5.4 Redis & Real-Time Runtime Findings
1. **PvP Matchmaking & Match Clocks in Process RAM ([pvp.socket.ts:23-25](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/pvp/pvp.socket.ts#L23-L25)):**
   - *Current Code:* `matchmakingQueue` and `activeMatches` are in-memory variables.
   - *Risk:* Server restart destroys active duels. Multiple server processes cannot match players against each other.
   - *Remediation:* Store matchmaking tickets in a Redis Sorted Set (`ZADD pvp:matchmaking <timestamp> <userId>`) and publish match state events via Redis.
2. **Unsafe Mutex Lock Release ([concurrency-lock.service.ts:16-19](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/concurrency/concurrency-lock.service.ts#L16-L19)):**
   - *Current Code:* `releaseLock` runs unconditional `del(lockKey)`. If request A times out and request B acquires the lock, request A's completion deletes request B's active lock.
   - *Remediation:* Acquire locks with a UUID token (`SET key token PX ttl NX`) and release via a Lua script checking token equality.
3. **Unbounded Local Map Fallback in RedisService ([redis.service.ts:8, 51-57](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/lesson/services/redis.service.ts#L8)):**
   - *Current Code:* Falls back to a local `Map` when Redis is disconnected without purging expired keys.
   - *Remediation:* Configure ioredis with exponential reconnects (`retryStrategy: (t) => Math.min(t * 100, 3000)`). If Redis is unreachable, fail fast for distributed locks rather than running uncoordinated local locks.

### 5.5 Mobile & Admin Integration Findings
1. **Admin Dashboard Route Path Mismatches ([api.ts:74, 78](file:///Users/shagunkumar/Desktop/aptiqu/admin-dashboard/src/services/api.ts#L74)):**
   - *Current Code:* Frontend Axios calls `DELETE /syllabus/subjects/${subjectId}/link-topic/${topicId}`, while backend router expects `DELETE /syllabus/subjects/:subjectId/topics/:topicId/unlink`.
   - *Remediation:* Correct frontend Axios URL paths in `admin-dashboard/src/services/api.ts`.
2. **Silent Token Wipe on Mobile Startup ([auth_controller.dart:53-54](file:///Users/shagunkumar/Desktop/aptiqu/lib/features/auth/presentation/controllers/auth_controller.dart#L53-L54)):**
   - *Current Code:* Any catch block in `checkInitialAuth()` calls `clearTokens()`. A transient timeout on startup logs out the user.
   - *Remediation:* Catch `DioException` and only clear tokens if response status is HTTP 401 with code `TOKEN_EXPIRED`.
3. **Fragmented Navigation Stack ([pvp_lobby_controller.dart:183](file:///Users/shagunkumar/Desktop/aptiqu/lib/features/pvp/controllers/pvp_lobby_controller.dart#L183)):**
   - *Current Code:* Practice sessions and PvP duels are pushed via `Navigator.push(MaterialPageRoute(...))` bypassing GoRouter.
   - *Remediation:* Declare `/practice-session` and `/pvp-arena` routes in `AppRouter` and navigate using `context.pushNamed(...)`.

---

# 6. ACTIONABLE IMPLEMENTATION PLAN (BY PHASES)

```text
PHASE 0: Contract, Architecture & Safety Baseline
   │
   ▼
PHASE 1: Critical Security & Credential Hardening
   │
   ▼
PHASE 2: Data Correctness, Entity Modeling & Transactions
   │
   ▼
PHASE 3: Database Indexing & Query Optimization
   │
   ▼
PHASE 4: Background Jobs & Asynchronous Content Generation
   │
   ▼
PHASE 5: Redis Runtime, Distributed Locks & PvP Synchronization
   │
   ▼
PHASE 6: Mobile & Admin Studio Integration
   │
   ▼
PHASE 7: Comprehensive System Testing & Verification
```

---

### Phase 0 — Contract, Architecture & Safety Baseline
**Objective:** Establish definitive cross-layer type contracts, status codes, and configuration standards.

1. **Environment Configuration Helper (`backend/src/config/env.ts`):**
   - Implement `requiredEnv(key: string): string` to read `process.env`.
   - If key is undefined or empty string, immediately throw `new Error(`[FATAL] Missing required environment variable: ${key}`)`.
   - Enforce this for `ADMIN_USERNAME`, `ADMIN_PASSWORD`, `ADMIN_JWT_SECRET`, `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`, `DATABASE_URL`.
2. **API Data Type & Normalization Standards:**
   - Standardize `streak` as integer `number` across all API responses.
   - Standardize XP amounts as integer `number` in JSON payloads.
   - Standardize error responses to `{ success: false, message: string, code: string }`.

---

### Phase 1 — Critical Security & Credential Hardening
**Objective:** Eliminate authentication backdoors, enforce secure admin logins, and secure token transmission.

1. **Delete Google Sandbox Bypass (`backend/src/utils/google.ts`):**
   - Remove the `if (idToken.startsWith('mock_test_token_'))` block completely.
   - Verify every token using `client.verifyIdToken({ idToken, audience: validAudiences })`.
2. **Harden Admin Authentication (`backend/src/modules/admin/admin-auth.controller.ts`):**
   - Use constant-time comparison to prevent timing attacks:
     ```ts
     const userHash = crypto.createHash('sha256').update(String(username)).digest();
     const expectedUserHash = crypto.createHash('sha256').update(ENV.ADMIN_USERNAME).digest();
     const passHash = crypto.createHash('sha256').update(String(password)).digest();
     const expectedPassHash = crypto.createHash('sha256').update(ENV.ADMIN_PASSWORD).digest();

     if (!crypto.timingSafeEqual(userHash, expectedUserHash) || !crypto.timingSafeEqual(passHash, expectedPassHash)) {
       res.status(401).json({ success: false, message: 'Invalid admin credentials' });
       return;
     }
     ```
   - Attach an in-memory rate limiter to `POST /api/v1/admin/auth/login` (5 attempts / 15 minutes).
3. **Fix IDOR on PvP Matches (`backend/src/modules/pvp/pvp.controller.ts`):**
   - In `getMatch`, verify `match.players.some(p => p.userId === req.userId)`. Return 403 Forbidden if the requester is not a participant in the match.
4. **Enforce HTTPS / WSS on Client (`lib/core/network/dio_client.dart`):**
   - Switch `defaultBaseUrl` to use HTTPS with TLS termination.
   - Update WebSocket URL in `lib/features/pvp/services/pvp_socket_service.dart` to `wss://`.
5. **Secure WebSocket Token Handshake:**
   - Remove `?token=` query parameter from WebSocket connection URL.
   - Upon connection, client immediately sends an initial `{ type: 'AUTH_INIT', payload: { token } }` frame.
   - Socket server verifies JWT; if valid, assigns `ws.userId = payload.userId`. If invalid or not received within 3 seconds, closes connection with code 4001.

---

### Phase 2 — Data Correctness, Entity Modeling & Transactions
**Objective:** Prevent transaction deadlocks, resolve field omissions, and remove magic entity fallbacks.

1. **Centralize Prisma Transaction Re-use (`backend/src/modules/xp/xp.service.ts`):**
   - Update signature:
     ```ts
     public async awardXp(input: AwardXpInput, txClient?: Prisma.TransactionClient): Promise<AwardXpResult>
     ```
   - If `txClient` is provided, execute XP operations on `txClient`. If omitted, wrap in `prisma.$transaction`.
   - Update `backend/src/modules/daily-challenge/daily-challenge.service.ts` at line 567:
     ```ts
     await XpService.getInstance().awardXp({ ... }, tx);
     ```
2. **Propagate Dual Solution Fields to Flutter:**
   - In `lib/features/daily_challenge/models/daily_challenge_models.dart` and `lib/features/practice/models/practice_models.dart`, add `final String? preferredSolution;` to question models and parse from JSON (`json['preferredSolution']`).
3. **Eliminate Magic Fallback IDs (`lib/features/home/presentation/controllers/home_controller.dart`):**
   - Replace line 278 `availableTopic?.roadmapStepId ?? 'ga-qa-01'` with:
     ```dart
     final stepId = availableTopic?.roadmapStepId;
     if (stepId == null) {
       roadmapError.value = 'No lessons available for this topic yet.';
       return;
     }
     ```
4. **Remove Duplicated XP Formulas in Client (`lib/features/home/presentation/controllers/home_controller.dart`):**
   - Remove `calculateQuestionXp` in Dart. Use the authoritative `node.xp` or API response values directly.

---

### Phase 3 — Database Indexing & Query Optimization
**Objective:** Eliminate full-table memory loading and sequential scan locks.

1. **Add Foreign Key Indexes in `backend/prisma/schema.prisma`:**
   ```prisma
   // learning.practice_session_questions
   @@index([questionId])

   // learning.pvp_question_set_questions
   @@index([questionId])

   // learning.pvp_match_answers
   @@index([questionId])
   @@index([userId, isCorrect])

   // learning.daily_challenge_answers
   @@index([questionId])

   // auth.refresh_tokens
   @@index([userId])
   @@index([expiresAt])

   // gamification.stats
   @@index([streak])
   @@index([lastDailyDate])
   ```
2. **Optimize PvP Question Set Selection (`backend/src/modules/pvp/services/pvp-match.service.ts`):**
   - Replace in-memory array filtering with targeted SQL:
     ```ts
     const sets = await prisma.$queryRaw<Array<{ id: string }>>`
       SELECT qs.id FROM learning.pvp_question_sets qs
       WHERE qs.status = 'PUBLISHED'
         AND NOT EXISTS (
           SELECT 1 FROM learning.pvp_player_set_history h
           WHERE h.question_set_id = qs.id AND h.user_id IN (${player1Id}::uuid, ${player2Id}::uuid)
         )
       ORDER BY qs.updated_at ASC LIMIT 1;
     `;
     ```
3. **Optimize User Question Solved Counts (`backend/src/modules/user/user.service.ts`):**
   - Replace 5-table array queries with database aggregation using SQL `COUNT(DISTINCT question_id)`.
4. **Batch Admin Question Bulk Import (`backend/src/modules/admin/admin-questions.service.ts`):**
   - Replace single-row insert loop with `prisma.question.createMany({ data: acceptedRecords, skipDuplicates: true })`.

---

### Phase 4 — Background Jobs & Asynchronous Content Generation
**Objective:** Decouple user HTTP requests from synchronous Gemini LLM execution.

1. **Install and Configure BullMQ:**
   - Install `bullmq` in `backend/package.json`.
   - Create queue instance `content-generation.queue.ts` connecting to Redis with concurrency = 2.
2. **Decouple Practice Generation from HTTP Requests (`practice-selection.service.ts`):**
   - When active questions in a subtopic fall below 10, dispatch job:
     ```ts
     contentGenQueue.add('generate-subtopic-questions', { subtopicId }, {
       jobId: `subtopic:${subtopicId}`,
       removeOnComplete: true,
     });
     ```
   - Serve the current user using existing questions or reinforcement questions from adjacent subtopics. Never block the HTTP request waiting on Gemini.
3. **Worker Processing:**
   - Worker picks up job, runs `questionGenerationService.generateQuestionsForSubtopic`, validates structure, and stores questions in PostgreSQL.

---

### Phase 5 — Redis Runtime, Distributed Locks & PvP Synchronization
**Objective:** Stabilize Redis connection, implement safe mutex locks, and support dual-node PvP duels.

1. **Configure ioredis Reconnect Strategy (`backend/src/modules/lesson/services/redis.service.ts`):**
   - Replace `retryStrategy: () => null` with:
     ```ts
     retryStrategy: (times) => Math.min(times * 100, 3000)
     ```
   - Remove local `memoryFallback` map for locks. If Redis is unavailable, lock acquisition fails fast.
2. **Implement Safe Distributed Mutex (`backend/src/modules/concurrency/concurrency-lock.service.ts`):**
   - Use token-verified release:
     ```ts
     public static async acquireLock(scopeKey: string, ttlMs = 60000): Promise<string | null> {
       const lockKey = `LOCK:${scopeKey}`;
       const token = crypto.randomUUID();
       const ok = await redisService.setNxToken(lockKey, token, ttlMs);
       return ok ? token : null;
     }

     public static async releaseLock(scopeKey: string, token: string): Promise<void> {
       const lockKey = `LOCK:${scopeKey}`;
       const lua = `
         if redis.call("get", KEYS[1]) == ARGV[1] then
           return redis.call("del", KEYS[1])
         else
           return 0
         end
       `;
       await redisService.eval(lua, [lockKey], [token]);
     }
     ```
3. **Redis Matchmaking Queue for PvP Duels (`backend/src/modules/pvp/pvp.socket.ts`):**
   - Store queued players in a Redis Sorted Set (`ZADD pvp:matchmaking <timestamp> <userId>`).
   - Run matchmaking coordinator on Redis state so players connected to different instances can pair and launch duels.

---

### Phase 6 — Mobile & Admin Studio Integration
**Objective:** Align routes, prevent startup token wipes, and unify Flutter navigation.

1. **Fix Admin Dashboard Route URLs (`admin-dashboard/src/services/api.ts`):**
   - Update lines 74 & 78:
     ```ts
     unlinkTopic: (subjectId: string, topicId: string) =>
       apiClient.delete(`/syllabus/subjects/${subjectId}/topics/${topicId}/unlink`),
     unlinkSubtopic: (topicId: string, subtopicId: string) =>
       apiClient.delete(`/syllabus/topics/${topicId}/subtopics/${subtopicId}/unlink`),
     ```
2. **Resilient Mobile Startup Authentication (`lib/features/auth/presentation/controllers/auth_controller.dart`):**
   - In `checkInitialAuth()`, distinguish connection errors from auth failures:
     ```dart
     } on DioException catch (e) {
       if (e.response?.statusCode == 401) {
         await dioClient.clearTokens();
       }
       // On connection timeout or 500 error, do NOT clear tokens
     }
     ```
3. **Register Missing Routes in GoRouter (`lib/core/routing/app_router.dart`):**
   - Add routes for `AppRoutes.practiceSession` and `AppRoutes.pvpArena`.
   - Update `PracticeCatalogController` and `PvpLobbyController` to navigate via `context.pushNamed(...)`.

---

### Phase 7 — Comprehensive System Testing & Verification
**Objective:** Validate all fixes under integration and stress conditions.

1. **Security & Authentication Tests:**
   - Verify `mock_test_token_` string is rejected by `POST /api/v1/auth/google` with HTTP 401.
   - Verify server refuses to start if `JWT_ACCESS_SECRET` or `ADMIN_PASSWORD` is missing from environment.
   - Verify timing-safe comparison on admin login.
2. **Transaction Concurrency Test:**
   - Execute 20 concurrent requests to `POST /api/v1/daily-challenge/answer` with completing answers. Verify zero deadlocks on the Prisma connection pool and atomic XP award.
3. **Asynchronous Generation Verification:**
   - Start practice in an unseeded subtopic. Verify request returns immediately (<500ms) with available questions while BullMQ job processes generation in background.
4. **Clustered PvP Test:**
   - Connect Player 1 to instance A and Player 2 to instance B. Verify matchmaking pairs players and duel questions advance synchronously.

---

## 7. DEFERRED SCALE ROADMAP (FUTURE SCALE — NOT REQUIRED NOW)

The following items are intentionally deferred until significant production usage demands them:

| Scale Feature | Reason for Deferral | Trigger Condition |
| :--- | :--- | :--- |
| **Materialized Dashboard Analytics** | 50+ relational counting queries are tolerable at modest administrative traffic. Adding rollup cron jobs introduces maintenance overhead prematurely. | Admin dashboard response time exceeds 2.5 seconds on representative data. |
| **Database Read Replicas** | Single PostgreSQL instance handles thousands of queries/sec with proper indexing. | DB CPU exceeds 70% sustained utilization during non-peak hours. |
| **Partitioning of User Question History** | Indexes on `(userId, questionId)` are sufficient for tens of thousands of attempts. | `learning.question_attempts` exceeds 20 million rows. |
| **Multi-Region Socket Architecture** | Aptiqu's target user base is primarily focused on India. Single region (e.g. AWS ap-south-1 Mumbai) provides <50ms latency across target geography. | Significant user base expansion outside India. |

---

## 8. PRODUCTION READINESS CHECKLIST

Before launching to live users:

- [ ] All `mock_test_token_` sandbox bypass code deleted from `google.ts`.
- [ ] No hardcoded fallback credentials or secrets exist in `env.ts`. Server throws fatal error if secrets are missing.
- [ ] Mobile `DioClient` points to valid HTTPS domain with TLS certificate.
- [ ] Admin login uses `crypto.timingSafeEqual()` and is rate-limited.
- [ ] `XpService.awardXp` accepts optional transaction client, resolving nested transaction deadlocks.
- [ ] `findMany` over entire PvP sets and question attempts replaced with SQL queries.
- [ ] Justified foreign key indexes added to `schema.prisma` and applied via migration.
- [ ] Practice question shortage triggers asynchronous BullMQ background job instead of synchronous HTTP block.
- [ ] Redis mutex locking uses unique UUID tokens with Lua verification.
- [ ] Admin dashboard unlinking URLs fixed to prevent 404s.
- [ ] Flutter `checkInitialAuth` does not clear tokens on transient network timeouts.
- [ ] Practice and PvP screens registered in GoRouter.
- [ ] Daily streak challenge resets cleanly at midnight IST for all users.
