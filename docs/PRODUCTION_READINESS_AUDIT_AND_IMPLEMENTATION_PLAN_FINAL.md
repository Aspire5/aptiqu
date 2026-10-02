# APTIQU PRODUCTION READINESS IMPLEMENTATION PLAN — FINAL (SOURCE OF TRUTH)
**Document Status:** Implementation Source of Truth (Engineering & Remediation Blueprint)  
**Target Platform:** Aptiqu Monorepo (`Flutter Mobile App`, `Node.js + Express + TypeScript Backend`, `PostgreSQL via Prisma`, `Redis Infrastructure`, `React Admin Dashboard`)  
**Target File:** `docs/PRODUCTION_READINESS_AUDIT_AND_IMPLEMENTATION_PLAN_FINAL.md`  
**Execution Directives:** Strict Engineering Fixes Only. No product behavior modifications. No premature over-engineering. Plan-only mode (No codebase edits).

---

## 1. EXECUTIVE SUMMARY & OWNER DECISION BOUNDARIES

This document represents the definitive, finalized production-readiness implementation plan for Aptiqu. Every audit finding and remediation step has been subjected to a strict **Source Verification vs. Runtime Inferred Risk** methodology. 

### 1.1 Non-Negotiable Owner Decisions
1. **Daily Streak Reset (Strictly 12:00 AM IST):**
   - The streak reset boundary is fixed at **12:00 AM Asia/Kolkata (IST)** for all users.
   - Per-user timezone tracking, international timezone adjustments, and dynamic local midnight resets are **explicitly rejected as an intentional product requirement**.
2. **Admin Authentication (.env-based only):**
   - Admin authentication continues using environment credentials (`ADMIN_USERNAME`, `ADMIN_PASSWORD`, `ADMIN_JWT_SECRET`).
   - We explicitly **reject** creating an `admin_users` database table, admin CRUD endpoints, or complex role/permission infrastructure.
   - Remediation is strictly limited to:
     - Enforcing `requiredEnv()` fail-fast startup checks when `.env` secrets are missing.
     - Completely removing hardcoded fallback credentials and secrets from source code.
     - Using constant-time comparisons (`crypto.timingSafeEqual`) to prevent timing attacks.
     - Mounting an in-memory login rate limiter on the admin login endpoint.
3. **Hard Delete Policy:**
   - Physical deletion (hard delete) of questions and users is an **intentional design decision**.
   - We do NOT introduce `deletedAt`, soft-delete models, or archival layers.
   - Technical remediation ensures that proper foreign-key indexes exist on referencing tables so that hard deletes do not cause slow sequential scans or table-level locks.
4. **Pragmatic Scaling (No Premature Million-User Optimization):**
   - Speculative infrastructure (materialized dashboard rollups, read replicas, database sharding, table partitioning) is **strictly deferred**.
   - Remediation focuses strictly on concrete architectural and performance issues visible in code today: unbounded memory loading, N+1 queries, missing indexes, unsafe transactions, and synchronous LLM calls inside user HTTP requests.
5. **No Invented Product Fallback Behaviors:**
   - **No "Adjacent Subtopic" Substitution in Practice:** If a user selects "Percentages", the system must never substitute questions from "Ratios" or other subtopics unless the existing product logic explicitly defines it. If sufficient valid questions cannot be provided according to existing rules, the system returns a clean availability state.
   - **Asynchronous LLM Generation for Both Practice and Daily Challenge:** Neither `POST /api/v1/practice/sessions` nor `POST /api/v1/daily-challenge/start` may synchronously await Google Gemini in the user HTTP request loop. Both workflows rely on BullMQ background workers and scheduled pre-warming.

---

## 2. SYSTEM ARCHITECTURE & COMPONENT MODEL

```
                                  +---------------------------------------+
                                  |         FLUTTER MOBILE CLIENT         |
                                  | - GetX Domain Controllers             |
                                  | - GoRouter (Declarative Routing)      |
                                  | - Dio Client (Domain HTTPS + WSS)     |
                                  +-------------------+-------------------+
                                                      |
                                     HTTPS / WSS (Domain URL)
                                                      |
                                                      v
+-----------------------+              +------------------------------------+
|    ADMIN DASHBOARD    |   HTTPS      |      NODE.JS / EXPRESS BACKEND     |
| - React 18 + Vite     |------------> | - Fail-Fast Startup (requiredEnv)  |
| - Corrected Routes    |              | - Centralized Prisma Transactions  |
| - Timing-Safe Auth    |              | - Decoupled Asynchronous Workers   |
+-----------------------+              +---------+----------------+---------+
                                                 |                |
                                     Prisma ORM  |                | ioredis (Exponential
                                                 v                |          Backoff Reconnect)
                                      +----------+-----+   +------v-------+
                                      |   POSTGRESQL   |   |    REDIS     |
                                      | - Multi-schema |   | - Mutex Locks|
                                      | - Target Index |   | - PvP State  |
                                      | - Hard Deletes |   | - BullMQ Qs  |
                                      +----------------+   +--------------+
```

---

## 3. FINDING VALIDATION MATRIX

Every audit finding is classified under strict criteria:
- **VERIFIED FROM SOURCE:** Directly observable in code text.
- **INFERRED RISK / REQUIRES RUNTIME VALIDATION:** Likely defect based on code structure; exact impact or failure condition requires a specific runtime test.
- **INTENTIONAL DESIGN:** Explicit business or operational choice confirmed by the owner.
- **DEFERRED:** Valid architectural optimization not needed for current production scale.

| Finding ID | Finding | Evidence (File & Lines) | Classification | Confidence | Runtime Test Required? | Recommended Action |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **SEC-01** | Google OAuth sandbox bypass in production code | [google.ts:21-34](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/utils/google.ts#L21-L34) | **VERIFIED SECURITY ISSUE** | 100% | Yes — Google OAuth authentication test with mock token | **Delete bypass completely.** Verify token via Google API ticket in all environments. |
| **SEC-02** | Hardcoded admin credentials & fallback secrets | [env.ts:9-28](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/config/env.ts#L9-L28) | **VERIFIED SECURITY ISSUE** | 100% | Yes — Startup failure test without required env vars | **Enforce `requiredEnv()`**. Fail fast on boot if env vars are missing. No DB admin table. |
| **SEC-03** | Plain HTTP backend URL on mobile client | [dio_client.dart:12](file:///Users/shagunkumar/Desktop/aptiqu/lib/core/network/dio_client.dart#L12) | **VERIFIED SECURITY ISSUE** | 100% | Yes — Network traffic SSL inspection test | Replace `http://15.252.71.142:5001/api/v1` with domain HTTPS endpoint. |
| **SEC-04** | Admin password comparison timing attack | [admin-auth.controller.ts:20](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin-auth.controller.ts#L20) | **VERIFIED SECURITY ISSUE** | 100% | No — Verified from source code inspection (`===` comparison) | Use `crypto.timingSafeEqual()` on SHA-256 hashes of credentials. Mount rate-limiter. |
| **SEC-05** | WebSocket auth token in URL query parameter | [pvp_socket_service.dart:36](file:///Users/shagunkumar/Desktop/aptiqu/lib/features/pvp/services/pvp_socket_service.dart#L36) | **VERIFIED SECURITY ISSUE** | 100% | Yes — Unauthorized match-access integration test | Pass token in initial WS message handshake (`AUTH_INIT`) rather than URL query string. |
| **SEC-06** | IDOR on PvP Match Details | [pvp.controller.ts:25](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/pvp/pvp.controller.ts#L25) | **VERIFIED SECURITY ISSUE** | 95% | Yes — Cross-player unauthorized match access test | Verify `req.userId` is a member of `match.players` or caller is admin. |
| **DAT-01** | Nested Prisma Transaction Deadlock Hazard | [daily-challenge.service.ts:501, 567](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/daily-challenge/daily-challenge.service.ts#L501) & [xp.service.ts:74](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/xp/xp.service.ts#L74) | **VERIFIED DATA INTEGRITY ISSUE** | 100% | Yes — Concurrent transaction test (20 simultaneous /answer submissions) | Pass existing `tx` client into `awardXp(input, tx)`. Remove inner `$transaction`. |
| **DAT-02** | BigInt serialization crash risk | [schema.prisma:102](file:///Users/shagunkumar/Desktop/aptiqu/backend/prisma/schema.prisma#L102) & [xp.service.ts:39](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/xp/xp.service.ts#L39) | **VERIFIED DATA INTEGRITY ISSUE** | 100% | Yes — JSON response serialization test | Explicit serialization contract: Always convert `BigInt` to JS `Number` in DTOs. |
| **DAT-03** | Streak format mismatch (`Int` vs `'0d'`) | [auth.service.ts:119](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/auth/auth.service.ts#L119) vs [daily-challenge.service.ts:301](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/daily-challenge/daily-challenge.service.ts#L301) | **VERIFIED DATA INTEGRITY ISSUE** | 100% | Yes — Dart JSON deserialization unit test | Standardize API to return raw integer `streak: number`. Format as `'Xd'` in Flutter UI only. |
| **DAT-04** | Missing `preferredSolution` field in Flutter | [daily_challenge_models.dart:122](file:///Users/shagunkumar/Desktop/aptiqu/lib/features/daily_challenge/models/daily_challenge_models.dart#L122) | **VERIFIED DATA INTEGRITY ISSUE** | 100% | Yes — Flutter model deserialization test | Add `preferredSolution` string to Dart models and deserialize from API response. |
| **PERF-01**| Synchronous Gemini call in Practice creation | [practice-selection.service.ts:126](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/practice/services/practice-selection.service.ts#L126) | **VERIFIED PERFORMANCE ISSUE** | 100% | Yes — Concurrent practice-start latency load test | Never block HTTP request on Gemini. Serve existing valid questions; dispatch BullMQ job. |
| **PERF-02**| Synchronous Gemini call in Daily Challenge `/start` | [daily-challenge.service.ts:370-375](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/daily-challenge/daily-challenge.service.ts#L370-L375) | **VERIFIED PERFORMANCE ISSUE** | 100% | Yes — Daily Challenge /start latency test under missing cache | Pre-generate tomorrow's script at 23:00 IST via BullMQ. Never block `/start` on LLM. |
| **PERF-03**| In-memory full-table scan on PvP set select | [pvp-match.service.ts:93-104](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/pvp/services/pvp-match.service.ts#L93-L104) | **VERIFIED PERFORMANCE ISSUE** | 100% | Yes — Database query EXPLAIN ANALYZE | Replace `findMany({ include: ... })` with targeted SQL query selecting unseen set ID. |
| **PERF-04**| In-memory aggregation across 5 tables for stats | [user.service.ts:198-225](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/user/user.service.ts#L198-L225) | **VERIFIED PERFORMANCE ISSUE** | 100% | Yes — Database query EXPLAIN ANALYZE | Replace multi-table array deduplication with SQL `COUNT(DISTINCT questionId)`. |
| **PERF-05**| Missing foreign key indexes on high-churn tables | [schema.prisma:521, 588, 648, 977](file:///Users/shagunkumar/Desktop/aptiqu/backend/prisma/schema.prisma#L521) | **VERIFIED PERFORMANCE ISSUE** | 95% | Yes — EXPLAIN ANALYZE on cascade delete | Add justified indexes on `questionId` in session/answer tables to accelerate cascade deletes. |
| **ARCH-01**| PvP sockets & matchmaking in process RAM | [pvp.socket.ts:23-25](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/pvp/pvp.socket.ts#L23-L25) | **VERIFIED ARCHITECTURAL ISSUE** | 100% | Yes — Clustered two-node PvP duel test | Move matchmaking queue to Redis Sorted Set. Keep socket connections local. |
| **ARCH-02**| Unsafe Redis lock release (Lock Stomping) | [concurrency-lock.service.ts:16-19](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/concurrency/concurrency-lock.service.ts#L16-L19) | **VERIFIED ARCHITECTURAL ISSUE** | 100% | Yes — Lock expiration + overlapping request race test | Release lock using Lua script checking unique ownership UUID. |
| **ARCH-03**| Unbounded local `Map` fallback in RedisService | [redis.service.ts:8, 51-57](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/lesson/services/redis.service.ts#L8) | **VERIFIED ARCHITECTURAL ISSUE** | 100% | Yes — Redis disconnection failure test | Remove silent local map fallback for locks. Enforce exponential reconnect on ioredis. |
| **ARCH-04**| Fragmented Flutter navigation (Get.to vs GoRouter) | [pvp_lobby_controller.dart:183](file:///Users/shagunkumar/Desktop/aptiqu/lib/features/pvp/controllers/pvp_lobby_controller.dart#L183) | **VERIFIED ARCHITECTURAL ISSUE** | 100% | Yes — Flutter deep link and navigation back-stack test | Register `/practice-session` & `/pvp-arena` in `AppRouter`. Remove raw `MaterialPageRoute` pushes. |
| **UI-01**  | Admin Dashboard unlinking 404 URL mismatch | [api.ts:74, 78](file:///Users/shagunkumar/Desktop/aptiqu/admin-dashboard/src/services/api.ts#L74) vs [admin.routes.ts:56, 58](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts#L56) | **VERIFIED BUG** | 100% | Yes — Admin topic/subtopic unlinking integration test | Fix frontend Axios URLs to match backend `/unlink` routes. |
| **UI-02**  | Silent token wipe on transient startup network lag | [auth_controller.dart:53-54](file:///Users/shagunkumar/Desktop/aptiqu/lib/features/auth/presentation/controllers/auth_controller.dart#L53-L54) | **VERIFIED BUG** | 95% | Yes — Mobile startup timeout test | Only clear tokens on explicit 401 `TOKEN_EXPIRED`. Retain tokens on connection errors. |
| **UI-03**  | Hardcoded domain entity fallback `'ga-qa-01'` | [home_controller.dart:278](file:///Users/shagunkumar/Desktop/aptiqu/lib/features/home/presentation/controllers/home_controller.dart#L278) | **VERIFIED BUG** | 90% | Yes — Empty curriculum syllabus rendering test | Handle empty syllabus explicitly with user-facing message instead of magic entity ID. |
| **UI-04**  | Duplicated XP math in Flutter | [home_controller.dart:115-124](file:///Users/shagunkumar/Desktop/aptiqu/lib/features/home/presentation/controllers/home_controller.dart#L115-L124) | **VERIFIED ARCHITECTURAL ISSUE** | 95% | No — Verified from source code inspection | Backend is sole authority on awarded XP. Client only renders returned values. |
| **DES-01** | Midnight IST Streak Boundary | [daily-challenge.service.ts:26-47](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/daily-challenge/daily-challenge.service.ts#L26-L47) | **INTENTIONAL DESIGN** | 100% | No — Intentional business rule confirmed by owner | **Accept as product requirement.** Retain 12:00 AM IST reset. |
| **DES-02** | Hard Delete of Users/Questions | [admin-questions.service.ts:320-334](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin-questions.service.ts#L320-L334) | **INTENTIONAL DESIGN** | 100% | No — Intentional business rule confirmed by owner | **Accept as product requirement.** Maintain physical deletion. |
| **DEF-01** | Admin Dashboard 50+ relational counting queries | [admin-dashboard.service.ts:17-80](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin-dashboard.service.ts#L17-L80) | **DEFERRED** | 80% | Post-launch load test | Mark as deferred scale item. Lightweight count indexes used now; avoid materialized tables. |

---

## 4. DETAILED ENGINEERING AUDIT FINDINGS

### 4.1 Security & Authentication Findings
1. **Google OAuth Sandbox Bypass ([google.ts:21-34](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/utils/google.ts#L21-L34)):**
   - *Source-Verified Fact:* An active branch `if (idToken.startsWith('mock_test_token_'))` synthesizes a valid user payload for arbitrary email strings without contacting Google token verification endpoints.
   - *Impact:* Critical vulnerability allowing total account takeover in production.
   - *Remediation:* Completely delete lines 21–34. Verify all ID tokens through the Google OAuth API ticket mechanism in all environments.
2. **Hardcoded Fallbacks in Configuration ([env.ts:9-28](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/config/env.ts#L9-L28)):**
   - *Source-Verified Fact:* Defaults exist for `ADMIN_USERNAME`, `ADMIN_PASSWORD`, `ADMIN_JWT_SECRET`, and `JWT_ACCESS_SECRET`.
   - *Remediation:* Implement `requiredEnv(key: string): string` in `backend/src/config/env.ts`. Fail fast and terminate backend process on boot if any required secret is missing.
3. **Admin Credential Comparison & Rate Limiting ([admin-auth.controller.ts:20](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin-auth.controller.ts#L20)):**
   - *Source-Verified Fact:* Direct `===` string comparison against environment variables. No rate limiter attached to `POST /api/v1/admin/auth/login`.
   - *Remediation:* Hash credentials with SHA-256 and compare using `crypto.timingSafeEqual()`. Mount an in-memory rate limiter (5 attempts / 15 minutes).
4. **Plain HTTP Mobile Client ([dio_client.dart:12](file:///Users/shagunkumar/Desktop/aptiqu/lib/core/network/dio_client.dart#L12)):**
   - *Source-Verified Fact:* Client hardcodes `http://15.252.71.142:5001/api/v1`.
   - *Remediation:* Change `defaultBaseUrl` to use HTTPS with TLS termination.
5. **WebSocket Authentication via Query Parameter ([pvp_socket_service.dart:36](file:///Users/shagunkumar/Desktop/aptiqu/lib/features/pvp/services/pvp_socket_service.dart#L36)):**
   - *Source-Verified Fact:* `ws://.../ws/pvp?token=$token` transmits JWT in URL query string, exposing tokens to access logs and proxies.
   - *Remediation:* Transmit token in the initial WebSocket frame payload: `{ type: 'AUTH_INIT', payload: { token } }`.
6. **IDOR on PvP Match Details ([pvp.controller.ts:25](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/pvp/pvp.controller.ts#L25)):**
   - *Source-Verified Fact:* `getMatch` fetches match by ID without verifying if the requesting user is a player in that match.
   - *Remediation:* Ensure `match.players.some(p => p.userId === req.userId)` or caller is admin. Return 403 Forbidden otherwise.

### 4.2 Data Integrity, Modeling & Transactions
1. **Nested Prisma Transaction Deadlock ([daily-challenge.service.ts:501-574](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/daily-challenge/daily-challenge.service.ts#L501-L574) & [xp.service.ts:74](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/xp/xp.service.ts#L74)):**
   - *Source-Verified Fact:* `dailyChallengeService.submitAnswer` opens `prisma.$transaction(async (tx) => ...)`. Inside `tx`, it invokes `XpService.getInstance().awardXp(...)`, which immediately opens a second `prisma.$transaction`.
   - *Inferred Risk:* Nested `$transaction` calls against the same connection pool can cause thread starvation and deadlocks under concurrent load. Furthermore, if the outer transaction rolls back, the inner XP transaction may have already committed.
   - *Remediation:* Refactor `awardXp(input, txClient?: Prisma.TransactionClient)` to accept and execute on the parent transaction client.
2. **Streak API Inconsistency ([auth.service.ts:119](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/auth/auth.service.ts#L119) vs [daily-challenge.service.ts:301](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/daily-challenge/daily-challenge.service.ts#L301)):**
   - *Source-Verified Fact:* `auth.service.ts` returns `streak: '0d'`, while `daily-challenge.service.ts` returns `streak: 0`.
   - *Remediation:* Standardize all backend APIs to return integer `streak: number`. Format `'Xd'` in Flutter UI only.
3. **Missing `preferredSolution` in Mobile Models ([daily_challenge_models.dart:122](file:///Users/shagunkumar/Desktop/aptiqu/lib/features/daily_challenge/models/daily_challenge_models.dart#L122)):**
   - *Source-Verified Fact:* Backend supplies `preferredSolution` (`BOOK` or `ALTERNATIVE`), but Flutter Dart models omit it.
   - *Remediation:* Add `preferredSolution` to Dart question models and display solution badge in quiz review screens.
4. **Hardcoded Domain Entity Fallback `'ga-qa-01'` ([home_controller.dart:278](file:///Users/shagunkumar/Desktop/aptiqu/lib/features/home/presentation/controllers/home_controller.dart#L278)):**
   - *Source-Verified Fact:* Fallback ID `'ga-qa-01'` is used when no topic is available.
   - *Remediation:* Return an explicit empty state when no topics are available; never invoke a hardcoded topic ID.

### 4.3 Database & Performance Findings
1. **Synchronous LLM Calls in User Request Loops:**
   - *Source-Verified Fact:*
     - Practice: [practice-selection.service.ts:126-130](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/practice/services/practice-selection.service.ts#L126-L130) triggers Gemini synchronously when questions are low.
     - Daily Challenge: [daily-challenge.service.ts:370-375](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/daily-challenge/daily-challenge.service.ts#L370-L375) triggers Gemini synchronously inside `POST /api/v1/daily-challenge/start` if today's script is missing.
   - *Inferred Risk:* External LLM calls have unpredictable latency (often 3–15+ seconds). Blocking Express worker threads can cause request queue saturation, 504 gateway timeouts, and 429 rate limit errors from Gemini.
   - *Remediation:* Decouple Gemini calls completely from HTTP handlers.
     - Practice: Serve available questions strictly matching current rules. If inventory is below threshold, dispatch BullMQ background job. Never substitute adjacent subtopics.
     - Daily Challenge: Pre-generate tomorrow's scripts at 23:00 IST via scheduled BullMQ worker. If script is missing at `/start`, return a clear availability state rather than blocking the user.
2. **In-Memory Table Scans for PvP Question Sets ([pvp-match.service.ts:93-104](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/pvp/services/pvp-match.service.ts#L93-L104)):**
   - *Source-Verified Fact:* Calls `findMany({ where: { status: 'PUBLISHED' }, include: { playerHistory: true, setQuestions: ... } })` to pull all question sets into Node memory, then filters in JavaScript.
   - *Remediation:* Query the database directly for a single unplayed set using SQL `NOT EXISTS`.
3. **In-Memory Question Count Aggregation ([user.service.ts:198-225](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/user/user.service.ts#L198-L225)):**
   - *Source-Verified Fact:* Loads rows across 5 tables into Node arrays on every profile view.
   - *Remediation:* Replace array loops with database aggregation using SQL `COUNT(DISTINCT "question_id")`.
4. **Missing Foreign Key Indexes ([schema.prisma](file:///Users/shagunkumar/Desktop/aptiqu/backend/prisma/schema.prisma)):**
   - Add justified indexes on `questionId` across session and answer tables to eliminate sequential scans during cascade deletes and joins.

### 4.4 Redis & Real-Time Runtime Findings
1. **PvP Matchmaking & Match Clocks in Process RAM ([pvp.socket.ts:23-25](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/pvp/pvp.socket.ts#L23-L25)):**
   - *Source-Verified Fact:* `matchmakingQueue` and `activeMatches` are in-memory variables.
   - *Impact:* Multiple backend processes cannot match players against each other.
   - *Remediation:* Store matchmaking queue in a Redis Sorted Set (`ZADD pvp:matchmaking <timestamp> <userId>`). Coordinate active duels via Redis state.
2. **Unsafe Mutex Lock Release ([concurrency-lock.service.ts:16-19](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/concurrency/concurrency-lock.service.ts#L16-L19)):**
   - *Source-Verified Fact:* `releaseLock` runs unconditional `del(lockKey)`.
   - *Remediation:* Acquire locks with a unique UUID token (`SET key token PX ttl NX`) and release via a Lua script checking token equality.
3. **Unbounded Local Map Fallback in RedisService ([redis.service.ts:8, 51-57](file:///Users/shagunkumar/Desktop/aptiqu/backend/src/modules/lesson/services/redis.service.ts#L8)):**
   - *Source-Verified Fact:* Falls back to a local `Map` when Redis is disconnected without purging expired keys.
   - *Remediation:* Configure ioredis with exponential reconnects (`retryStrategy: (t) => Math.min(t * 100, 3000)`). If Redis is unreachable, fail fast for distributed locks rather than running uncoordinated local locks.

### 4.5 Mobile & Admin Integration Findings
1. **Admin Dashboard Route Path Mismatches ([api.ts:74, 78](file:///Users/shagunkumar/Desktop/aptiqu/admin-dashboard/src/services/api.ts#L74)):**
   - *Source-Verified Fact:* Frontend Axios calls `DELETE /syllabus/subjects/${subjectId}/link-topic/${topicId}`, while backend router expects `DELETE /syllabus/subjects/:subjectId/topics/:topicId/unlink`.
   - *Remediation:* Correct frontend Axios URL paths in `admin-dashboard/src/services/api.ts`.
2. **Silent Token Wipe on Mobile Startup ([auth_controller.dart:53-54](file:///Users/shagunkumar/Desktop/aptiqu/lib/features/auth/presentation/controllers/auth_controller.dart#L53-L54)):**
   - *Source-Verified Fact:* Any catch block in `checkInitialAuth()` calls `clearTokens()`. A transient timeout on startup logs out the user.
   - *Remediation:* Catch `DioException` and only clear tokens if response status is HTTP 401 with code `TOKEN_EXPIRED`.
3. **Fragmented Navigation Stack ([pvp_lobby_controller.dart:183](file:///Users/shagunkumar/Desktop/aptiqu/lib/features/pvp/controllers/pvp_lobby_controller.dart#L183)):**
   - *Source-Verified Fact:* Practice sessions and PvP duels are pushed via `Navigator.push(MaterialPageRoute(...))` bypassing GoRouter.
   - *Remediation:* Declare `/practice-session` and `/pvp-arena` routes in `AppRouter` and navigate using `context.pushNamed(...)`.

---

## 5. PRACTICE & DAILY CHALLENGE ASYNCHRONOUS ARCHITECTURES

### 5.1 Practice Generation Flow (Strict Topic Fidelity)

**Principle:** Do NOT introduce adjacent-subtopic substitution. The user's requested topic and subtopic semantics must be strictly preserved.

```text
User requests practice session
              ↓
   Check valid question inventory
              ↓
           Enough?
        ├── YES ──> Create session immediately (<200ms)
        │
        └── NO
             ↓
   Trigger deduplicated background BullMQ job:
   `contentGenQueue.add('generate-subtopic-questions', { subtopicId })`
             ↓
   Use only valid questions matching current selection rules
             ↓
   Are there enough valid questions to form a valid session?
        ├── YES ──> Create session & return
        │
        └── NO  ──> Return clean availability response:
                    HTTP 422 / 503 {
                      success: false,
                      code: 'QUESTIONS_BEING_PREPARED',
                      message: 'Questions for this subtopic are currently being prepared. Please check back shortly.'
                    }
                    (NEVER block on Gemini, NEVER substitute other topics)
```

### 5.2 Daily Challenge Pre-Generation Flow

**Principle:** User `/start` request must NEVER wait for Gemini. Pre-generate ahead of time.

```text
23:00 IST (Nightly Cron)
              ↓
BullMQ scheduled pre-warming job:
`contentGenQueue.add('prewarm-daily-challenge', { targetDate: tomorrowDateString })`
              ↓
AI Worker calls Gemini
              ↓
Validate schema + deduplicate against recent history
              ↓
Persist to database (`learning.daily_challenges`)
              ↓
00:00 IST (Midnight IST)
              ↓
Challenge becomes active for all users
```

**User Request Flow:**
```text
Flutter Client
      ↓
GET /api/v1/daily-challenge/status
      ↓
POST /api/v1/daily-challenge/start
      ↓
Read already-stored challenge from database
      ↓
Return question set to user (<150ms)
(Never waits for Gemini)
```

**Generation Failure Handling (What if 00:00 IST arrives without a pre-generated challenge?):**
If pre-generation failed due to network or LLM outage:
1. When `/start` is called, backend checks if challenge exists for today's IST date.
2. If missing, immediately trigger an emergency BullMQ generation job with deduplication lock `daily_gen:YYYY-MM-DD`.
3. Do NOT make the user HTTP request wait. Return:
   ```json
   {
     "success": false,
     "code": "DAILY_CHALLENGE_PREPARING",
     "message": "Today's Daily Challenge is being generated. Please check back in a few minutes."
   }
   ```
4. Flutter client displays a friendly "Preparing today's challenge" state with a manual refresh button.
5. Do NOT invent alternate mock challenges or alter curriculum rules.

---

## 6. REVISED 8-PHASE IMPLEMENTATION ROADMAP

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
**Goal:** Establish definitive cross-layer type contracts, status codes, and configuration standards.

1. **Environment Configuration Helper (`backend/src/config/env.ts`):**
   - Implement `requiredEnv(key: string): string` to read `process.env`.
   - If key is undefined or empty string, immediately throw:
     ```ts
     new Error(`[FATAL] Missing required environment variable: ${key}`);
     ```
   - Enforce this helper for `ADMIN_USERNAME`, `ADMIN_PASSWORD`, `ADMIN_JWT_SECRET`, `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`, `DATABASE_URL`.
2. **API Data Type & Normalization Standards:**
   - Standardize `streak` as integer `number` across all API responses.
   - Standardize XP amounts as integer `number` in JSON payloads.
   - Standardize error responses to `{ success: false, message: string, code: string }`.

---

### Phase 1 — Critical Security & Credential Hardening
**Goal:** Eliminate authentication backdoors, enforce secure admin logins, and secure token transmission.

1. **Delete Google Sandbox Bypass (`backend/src/utils/google.ts`):**
   - Remove lines 21–34 (`if (idToken.startsWith('mock_test_token_'))`).
   - Authenticate all requests via `client.verifyIdToken({ idToken, audience: validAudiences })`.
2. **Harden Admin Authentication (`backend/src/modules/admin/admin-auth.controller.ts`):**
   - Compare credentials using constant-time evaluation to prevent timing attacks:
     ```ts
     const userHash = crypto.createHash('sha256').update(String(username)).digest();
     const expectedUserHash = crypto.createHash('sha256').update(ENV.ADMIN_USERNAME).digest();
     const passHash = crypto.createHash('sha256').update(String(password)).digest();
     const expectedPassHash = crypto.createHash('sha256').update(ENV.ADMIN_PASSWORD).digest();

     if (!crypto.timingSafeEqual(userHash, expectedUserHash) || !crypto.timingSafeEqual(passHash, expectedPassHash)) {
       res.status(401).json({ success: false, message: 'Invalid admin credentials', code: 'INVALID_CREDENTIALS' });
       return;
     }
     ```
   - Attach an in-memory rate limiter to `POST /api/v1/admin/auth/login` (5 attempts / 15 minutes).
3. **Fix IDOR on PvP Matches (`backend/src/modules/pvp/pvp.controller.ts`):**
   - In `getMatch`, verify `match.players.some(p => p.userId === req.userId)`. Return 403 Forbidden if the requester is not a participant in the match and not admin.
4. **Enforce HTTPS / WSS on Client (`lib/core/network/dio_client.dart`):**
   - Switch `defaultBaseUrl` to use HTTPS with TLS termination.
   - Update WebSocket URL in `lib/features/pvp/services/pvp_socket_service.dart` to `wss://`.
5. **Secure WebSocket Token Handshake:**
   - Remove `?token=` query parameter from WebSocket connection URL.
   - Upon connection, client immediately sends an initial `{ type: 'AUTH_INIT', payload: { token } }` frame.
   - Socket server verifies JWT; if valid, assigns `ws.userId = payload.userId`. If invalid or not received within 3 seconds, closes connection with code 4001.

---

### Phase 2 — Data Correctness, Entity Modeling & Transactions
**Goal:** Prevent transaction deadlocks, resolve field omissions, and remove magic entity fallbacks.

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
**Goal:** Eliminate full-table memory loading and sequential scan locks.

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
**Goal:** Decouple user HTTP requests from synchronous Gemini LLM execution across Practice and Daily Challenge.

1. **Install and Configure BullMQ:**
   - Install `bullmq` in `backend/package.json`.
   - Create queue instance `content-generation.queue.ts` connecting to Redis with concurrency = 2.
2. **Practice Generation Architecture (`practice-selection.service.ts`):**
   - When active questions in a subtopic fall below 10:
     - Dispatch background job:
       ```ts
       contentGenQueue.add('generate-subtopic-questions', { subtopicId }, {
         jobId: `subtopic:${subtopicId}`,
         removeOnComplete: true,
       });
       ```
     - Serve the current user using valid questions according to current selection rules.
     - **Do NOT introduce adjacent-subtopic substitution.** If sufficient valid questions cannot be provided under current selection rules, return a clean availability response. Never block the HTTP request waiting on Gemini.
3. **Daily Challenge Pre-Warming Architecture (`daily-challenge.service.ts`):**
   - Pre-generate tomorrow's scripts at 23:00 IST via scheduled BullMQ worker:
     ```ts
     contentGenQueue.add('prewarm-daily-challenge', { targetDate: tomorrowDateString }, {
       jobId: `prewarm:daily:${tomorrowDateString}`,
       removeOnComplete: true,
     });
     ```
   - In `POST /api/v1/daily-challenge/start`, read the already-stored script. Never wait synchronously for Gemini.
   - If a script is missing at midnight due to worker failure, return a clean availability error state rather than blocking the user's HTTP request.

---

### Phase 5 — Redis Runtime, Distributed Locks & PvP Synchronization
**Goal:** Stabilize Redis connection, implement safe mutex locks, and support dual-node PvP duels.

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
**Goal:** Align routes, prevent startup token wipes, and unify Flutter navigation.

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
**Goal:** Validate all fixes under integration and stress conditions.

1. **Security & Authentication Tests:**
   - Verify `mock_test_token_` string is rejected by `POST /api/v1/auth/google` with HTTP 401.
   - Verify server refuses to start if `JWT_ACCESS_SECRET` or `ADMIN_PASSWORD` is missing from environment.
   - Verify timing-safe comparison on admin login.
2. **Transaction Concurrency Test:**
   - Execute 20 concurrent requests to `POST /api/v1/daily-challenge/answer` with completing answers. Verify zero deadlocks on the Prisma connection pool and atomic XP award.
3. **Asynchronous Generation Verification:**
   - Start practice in an unseeded subtopic. Verify request returns immediately (<500ms) with available questions while BullMQ job processes generation in background.
   - Verify Daily Challenge `/start` returns immediately (<500ms) using pre-generated scripts.
4. **Clustered PvP Test:**
   - Connect Player 1 to instance A and Player 2 to instance B. Verify matchmaking pairs players and duel questions advance synchronously.

---

## 7. DEFERRED SCALE ROADMAP (FUTURE SCALE — NOT REQUIRED NOW)

The following items are intentionally deferred until significant production usage demands them:

| Scale Feature | Reason for Deferral | Trigger Condition |
| :--- | :--- | :--- |
| **Materialized Dashboard Analytics** | Relational counting queries are tolerable at modest administrative traffic. Adding rollup cron jobs introduces maintenance overhead prematurely. | Admin dashboard response time exceeds 2.5 seconds on representative data. |
| **Database Read Replicas** | Single PostgreSQL instance handles thousands of queries/sec with proper indexing. | DB CPU exceeds 70% sustained utilization during non-peak hours. |
| **Partitioning of User Question History** | Indexes on `(userId, questionId)` are sufficient for tens of thousands of attempts. | `learning.question_attempts` exceeds 20 million rows. |
| **Multi-Region Socket Architecture** | Aptiqu's target user base is primarily focused on India. Single region (e.g. AWS ap-south-1 Mumbai) provides <50ms latency across target geography. | Significant user base expansion outside India. |

---

## 8. FINAL PRODUCTION READINESS CHECKLIST

Before launching to live users:

- [ ] All `mock_test_token_` sandbox bypass code deleted from `google.ts`.
- [ ] No hardcoded fallback credentials or secrets exist in `env.ts`. Server throws fatal error if secrets are missing.
- [ ] Mobile `DioClient` points to valid HTTPS domain with TLS certificate.
- [ ] Admin login uses `crypto.timingSafeEqual()` and is rate-limited.
- [ ] `XpService.awardXp` accepts optional transaction client, resolving nested transaction deadlocks.
- [ ] `findMany` over entire PvP sets and question attempts replaced with SQL queries.
- [ ] Justified foreign key indexes added to `schema.prisma` and applied via migration.
- [ ] Practice question shortage triggers asynchronous BullMQ background job instead of synchronous HTTP block.
- [ ] Daily Challenge pre-generates next day's script at 23:00 IST via BullMQ; `/start` never blocks on Gemini.
- [ ] No adjacent-subtopic question substitution is introduced in Practice.
- [ ] Redis mutex locking uses unique UUID tokens with Lua verification.
- [ ] Admin dashboard unlinking URLs fixed to prevent 404s.
- [ ] Flutter `checkInitialAuth` does not clear tokens on transient network timeouts.
- [ ] Practice and PvP screens registered in GoRouter.
- [ ] Daily streak challenge resets cleanly at midnight IST for all users.
