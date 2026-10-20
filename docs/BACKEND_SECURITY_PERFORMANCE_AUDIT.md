# AptiQu — Backend security, performance and scalability audit

**Audit date: 20 October 2026 (Asia/Kolkata). Repository baseline: `9bdcd64` (`completed ranked mechanism`); working tree initially clean. Audit and planning only.**

## 1. Executive assessment

The backend has useful service-level ownership checks, parameterized SQL, explicit Ranked DTOs and a substantially improved durable Ranked settlement design. It is **not ready for an unrestricted public launch or unchanged PM2 cluster deployment**. Publication boundaries, lesson idempotency, competitive content release, Daily Challenge authority, cross-transaction XP and lifecycle ownership need correction first.

This is a repository-static assessment, not a penetration test or measured capacity report. No application was started; no database, Redis service, VPS or external AI endpoint was contacted. Local `.env` values were not inspected. No secret values are included. Only the two requested Markdown documents were created. The companion [implementation plan](/Users/shagunkumar/Desktop/aptiqu/docs/BACKEND_HARDENING_IMPLEMENTATION_PLAN.md) is a proposal, not implementation authorization.

| Verified inventory | Count |
|---|---:|
| Explicit unique HTTP method/path endpoints | **116** |
| HTTP methods | GET 48; POST 46; PUT 12; DELETE 10 |
| Access classes (mutually exclusive) | Public 5; authenticated learner 49; privileged admin 62 |
| Endpoints with an explicit application limit on the normal operation | **10** |
| Endpoints without an evident application request limit | **106** |
| Meaningful cache-candidate endpoints, conditional on fixes | **21** (C01–C21; includes two already cached Ranked reads) |
| High-risk and/or expensive endpoints marked in inventory | **62** (union; not a vulnerability count) |
| WebSocket inbound commands | **8**: PvP 5 + Social 3 |
| Server-to-client event types | PvP 9 + Social 4; 13 channel/event combinations (12 unique names) |
| Significant jobs/scheduled/startup operations | **15**, counted separately from socket maintenance timers |
| Findings | **41: Critical 0; High 17; Medium 22; Low 2** |

No Critical finding is assigned: no verified unauthenticated catalog dump, arbitrary SQL/command execution, embedded production secret or ordinary-user-to-admin role escalation was established. That does not reduce the urgency of the verified High findings.

### Top 10 Most Important Issues to Fix

1. **B01/B41:** Publication fallbacks expose review content; incomplete lesson sanitization can expose solution-bearing feedback/variations before an attempt.
2. **B02:** Lesson response idempotency is globally keyed by client action ID and returns before ownership checks.
3. **B03:** Unrestricted practice creation plus ten-question delivery permits systematic proprietary-bank extraction.
4. **B04:** Friendly-duel full-deck preload and active-source practice replays bypass fair timed answer release.
5. **B05/B06:** Daily Challenge lacks server deadline/day/order authority and serialized, recoverable finalization.
6. **B07/B08:** Lesson side effects and regular-practice XP do not commit atomically with their parent learning state.
7. **B09/B10/B14:** Large pre-auth bodies, incomplete HTTP/WS abuse controls and indefinitely authenticated PvP sockets expose resources/accounts.
8. **B15/B35:** Destructive admin paths conflict with historical/Ranked integrity, and operational schema instructions contradict the prepared SQL requirements.
9. **B18/B24:** Multiple processes duplicate singleton responsibilities; PvP is deliberately a single-owner runtime.
10. **B25/B26:** Readiness, shutdown ordering and database-pool budgeting do not establish safe rolling reloads.

**Public launch gates:** resolve B01–B10, B14 and B41; fence destructive B15 operations; establish a safe single-owner topology and schema verification (B18/B24/B25/B35); apply the essential privacy, error and operational protections in B11–B13/B32/B34/B36/B40. Deferred caching is not a launch gate.

## 2. Verified architecture and inspection boundary

The backend comprises **154 TypeScript files**, including tests/scripts. `backend/src/app.ts` creates Express; `backend/src/server.ts` creates one HTTP server, attaches `/ws/pvp` and `/ws/social`, connects Prisma, starts recovery/social workers, registers two IST crons, listens, then starts content synchronization. Importing queue modules instantiates their workers before bootstrap finishes. Controllers are generally thin, but older admin controllers and services accept TypeScript-shaped input without runtime schemas.

| Layer | Current source/evidence | Observed implementation |
|---|---|---|
| HTTP/middleware | [app.ts](/Users/shagunkumar/Desktop/aptiqu/backend/src/app.ts:13), [auth middleware](/Users/shagunkumar/Desktop/aptiqu/backend/src/middleware/auth.middleware.ts:9) | Express 4; permissive CORS; 80KB social parser then global 150MB JSON/urlencoded parser; Bearer JWT; URL/status/duration console logs; raw error messages |
| Identity | [auth.service.ts](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/auth/auth.service.ts:11), [jwt.ts](/Users/shagunkumar/Desktop/aptiqu/backend/src/utils/jwt.ts:10), [admin middleware](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.middleware.ts:12) | Google identity verification; opaque refresh tokens stored as SHA-256 hashes; own-user services; separate admin signing secret with unsafe fallback trust |
| Learning | [lesson session service](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/lesson/services/lesson-session.service.ts:15), [roadmap service](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/roadmap/services/roadmap-progression.service.ts:94) | Server transitions; one current node + reached history; Redis definitions/idempotency/locks; GET-triggered global roadmap reconciliation |
| Practice/Daily | [practice service](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/practice/services/practice-session.service.ts:24), [daily service](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/daily-challenge/daily-challenge.service.ts:335) | Bounded ten-question practice decks; Daily 1–3 questions by streak; answer masking; server-scored answers; inconsistent time/concurrency guarantees |
| Social | [routes](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/social/social.routes.ts:8), [transport](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/social/social.transport.ts:5) | Registration-gated routes, PostgreSQL friendships/duel seats, Redis limits/presence/pubsub; BullMQ deadlines; no shared-state memory fallback |
| Ranked | [match service](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/pvp/services/pvp-match.service.ts:31), [queue](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/pvp/ranked/ranked-queue.ts:111) | Frozen match snapshots, row locks, idempotent settlement/Elo/XP ledger; signed cursors; bounded caches; Redis owner-fenced matchmaking; local socket/timer routing |
| Admin/content | [admin routes](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts:19), [books controller](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/controllers/admin-books.controller.ts:9) | 63 total admin-module routes: one public login + 62 privileged; syllabus/questions/users/achievements/prompts/PDF ingestion; no export-named route, but paged questions/full scripts are export-equivalent |
| Database | [Prisma singleton](/Users/shagunkumar/Desktop/aptiqu/backend/src/config/prisma.ts:3), [schema](/Users/shagunkumar/Desktop/aptiqu/backend/prisma/schema.prisma:1), [prepared SQL](/Users/shagunkumar/Desktop/aptiqu/backend/prisma/changes/ranked-phase2.sql:206) | PostgreSQL schemas auth/users/gamification/learning; one runtime PrismaClient per process; supplemental constraints/triggers/partial indexes only in prepared SQL; deployment unverified |
| Async/AI | [content queue](/Users/shagunkumar/Desktop/aptiqu/backend/src/queues/content-generation.queue.ts:41), [book queue](/Users/shagunkumar/Desktop/aptiqu/backend/src/queues/book-ingestion.queue.ts:106), [Gemini](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/ai/gemini.provider.ts:59) | BullMQ queues plus process cron; Gemini calls in practice shortage, PvP admission shortage and privileged generation; lesson doubts are currently STUB; Daily generation currently selects MANUAL PYQs rather than calling Gemini |
| Assets/process ops | [storage service](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/services/book-storage.service.ts:13), [server lifecycle](/Users/shagunkumar/Desktop/aptiqu/backend/src/server.ts:81) | Local CWD-relative PDFs/pages; no Express static/download/sendFile mount found; no checked-in PM2 ecosystem/reverse-proxy/deployment configuration found |

Locked versions (from `backend/package-lock.json`, not caret lower bounds): Express 4.22.3; Prisma/client 6.19.3; ws 8.22.0; jsonwebtoken 9.0.3; BullMQ 6.3.11; ioredis 6.0.0; Multer 2.4.0; pdf-parse 2.4.5; Zod 3.25.76; Google auth library 9.15.1; Google GenAI 2.24.0; CORS 2.8.6. Node/PM2/PostgreSQL/Redis production versions, vulnerability-feed status and installed production dependency tree are unknown. The existing lockfile is not a vulnerability clearance.

Inspected backend entry points, all route registration files, controllers, key service/query/DTO paths, schema/native SQL, runtime/queues, environment loader/template key names, dependency manifests, tests and relevant operational plans. No Flutter or admin-dashboard frontend audit was performed. Client packaging/offline behavior is an explicit downstream verification item, not an asserted backend finding. Old plans were cross-checked: constant-time admin comparison and login limiter already exist; Daily `/start` no longer directly calls Gemini; Ranked replay membership/terminal guards and durable settlement are already implemented.

## 3. Complete HTTP API inventory

**Counting definition:** each explicitly registered HTTP method + normalized fully mounted path is one endpoint. `/health` is included. Trailing-slash aliases, implicit Express HEAD support for GET, CORS preflight/OPTIONS handling and catch-all 404/error middleware are excluded. No PATCH/HEAD/OPTIONS/ALL declarations were found. Paths are traced from `createApp` mounts (app.ts:49–57); admin `/books` is nested under the authenticated admin router (admin.routes.ts:24,106). No unresolved mount remains in this inventory. It describes source reachability, not a running deployment smoke test.

| Functional module | HTTP endpoints |
|---|---:|
| Health | 1 |
| Auth | 4 |
| User/Home/Achievements | 5 |
| Lessons | 7 |
| Roadmaps | 6 |
| Practice | 8 |
| PvP/Ranked | 6 |
| Daily Challenge | 4 |
| Social/Friendly duels | 12 |
| Admin (including books) | 63 (51 main + 12 books) |
| **Total** | **116** |

**Reading the matrix:** `N` = response caching not appropriate (mutation/security/liveness); `Q` = query optimization preferred; `R` = conditional review, no caching recommendation yet; `C01–C21` = meaningful candidate, subject to section 9. All rows also inherit B09 body parsing, B34 error/log/header posture and the absence of a global limiter. “None evident” means no application request-frequency limiter traced; bounded pagination/uniqueness is not counted as rate limiting, and upstream proxy limits are unknown. A marker identifies a risk/expensive path, not measured slowness.

### health (1)

Route declarations: [backend/src/app.ts](/Users/shagunkumar/Desktop/aptiqu/backend/src/app.ts). Handler symbols below resolve to the module controllers/services listed in the architecture and evidence register.

| ID | HTTP endpoint | Handler / registration evidence | Authentication and authorization | Purpose and important DB work | Sensitive/proprietary data | Validation | Explicit rate limit | Performance/security assessment | Cache |
|---|---|---|---|---|---|---|---|---|---|
| H001 | `GET /health` | [inline health handler](/Users/shagunkumar/Desktop/aptiqu/backend/src/app.ts:40) | Public | Liveness JSON; no DB | Operational only | None required | None evident | Liveness does not establish readiness B25 | N |

### auth (4)

Route declarations: [backend/src/modules/auth/auth.routes.ts](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/auth/auth.routes.ts). Handler symbols below resolve to the module controllers/services listed in the architecture and evidence register.

| ID | HTTP endpoint | Handler / registration evidence | Authentication and authorization | Purpose and important DB work | Sensitive/proprietary data | Validation | Explicit rate limit | Performance/security assessment | Cache |
|---|---|---|---|---|---|---|---|---|---|
| H002 | `POST /api/v1/auth/google` | [AuthController.googleLogin](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/auth/auth.routes.ts:9) | Public | Verify Google token; lookup/link/create User, Profile, Stats, Progress; insert RefreshToken | Identity + tokens + demographics | Zod token present; no length maximum | None evident | High-risk/expensive: Public auth abuse; email linking B10/B12 | N |
| H003 | `POST /api/v1/auth/refresh` | [AuthController.refreshToken](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/auth/auth.routes.ts:10) | Public | Hash lookup; delete and replace RefreshToken; sign access token | Tokens | Zod nonempty string; no length maximum | None evident | High-risk/expensive: Nonatomic rotation; abuse B10/B13 | N |
| H004 | `POST /api/v1/auth/logout` | [AuthController.logout](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/auth/auth.routes.ts:11) | Public | Delete matching RefreshToken hash | Success status | Optional body token; no schema | None evident | No access-token/WS revocation B13 | N |
| H005 | `POST /api/v1/auth/onboarding` | [AuthController.completeOnboarding](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/auth/auth.routes.ts:14) | User JWT; own profile | Upsert own Profile/Stats/Progress; mark registration complete | Own demographics | Zod names/enums/date/URL limits | None evident | Multi-write initialization; policy bounds B12/B37 | N |

### user (5)

Route declarations: [backend/src/modules/user/user.routes.ts](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/user/user.routes.ts). Handler symbols below resolve to the module controllers/services listed in the architecture and evidence register.

| ID | HTTP endpoint | Handler / registration evidence | Authentication and authorization | Purpose and important DB work | Sensitive/proprietary data | Validation | Explicit rate limit | Performance/security assessment | Cache |
|---|---|---|---|---|---|---|---|---|---|
| H006 | `GET /api/v1/user/home` | [inline → HomeService.getHome](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/user/user.routes.ts:12) | User JWT; own data; active catalog | Union answer aggregates, lesson resume, achievements, last match, Ranked standing | Own performance/activity | JWT identity only | None evident | High-risk/expensive: Repeated lifetime aggregation B27 | C05 |
| H007 | `GET /api/v1/user/achievements` | [inline → userAchievements](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/user/user.routes.ts:19) | User JWT; own data; active catalog | Answer/fact aggregates + paged definitions/count | Own progress + rules | Zod page 1..1000000; limit 1..50 | None evident | Lifetime aggregates repeat per page B27 | C06 |
| H008 | `GET /api/v1/user/profile` | [UserController.getProfile](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/user/user.routes.ts:29) | User JWT; own data; active catalog | Own User/Profile/Stats; XP; streak sync; optional full stats; Ranked | Own email/DOB/beliefs + metrics | summary literal true; identity from JWT | None evident | High-risk/expensive: Wide default; duplicate work; read writes B27/B28 | C07 |
| H009 | `GET /api/v1/user/progress` | [UserController.getProgress](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/user/user.routes.ts:30) | User JWT; own data; active catalog | Read or initialize own UserProgress | Own XP | JWT identity only | None evident | Lazy create race B07; private scope | C08 |
| H010 | `GET /api/v1/user/stats` | [UserController.getStats](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/user/user.routes.ts:31) | User JWT; own data; active catalog | Roadmap completions; all question/version totals; solved-question unions | Own metrics + catalog totals | JWT identity only | None evident | High-risk/expensive: Whole-catalog materialization and count defects B27/B28 | C09 |

### lesson (7)

Route declarations: [backend/src/modules/lesson/lesson.routes.ts](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/lesson/lesson.routes.ts). Handler symbols below resolve to the module controllers/services listed in the architecture and evidence register.

| ID | HTTP endpoint | Handler / registration evidence | Authentication and authorization | Purpose and important DB work | Sensitive/proprietary data | Validation | Explicit rate limit | Performance/security assessment | Cache |
|---|---|---|---|---|---|---|---|---|---|
| H011 | `GET /api/v1/lessons/active` | [LessonController.getActiveSession](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/lesson/lesson.routes.ts:10) | User JWT; own session (B02 exception) | Resolve/sync roadmap; assignments/version JSON; own events/history | Current lesson + own history | Optional step cast; no schema | None evident | High-risk/expensive: GET fanout; publication/authorization B01/B17 | R |
| H012 | `POST /api/v1/lessons/sessions` | [LessonController.startSession](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/lesson/lesson.routes.ts:11) | User JWT; own session (B02 exception) | Start/resume by slug/step; create Session/Event; Redis idempotency | Current lesson + own history | Zod action UUID; slug/step optional unbounded; restart raw bool | None evident | High-risk/expensive: Publication bypass + shared action cache B01/B02 | N |
| H013 | `GET /api/v1/lessons/sessions/:id` | [LessonController.getSession](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/lesson/lesson.routes.ts:12) | User JWT; own session (B02 exception) | Owned Session; cached version hydration; XP lookup | Current lesson | Service id+user lookup; param not UUID validated | None evident | High-risk/expensive: Solution-bearing optional fields B41; definition hydration on hits B33 | R |
| H014 | `POST /api/v1/lessons/sessions/:id/actions` | [LessonController.submitAction](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/lesson/lesson.routes.ts:13) | User JWT; own session (B02 exception) | Owned session; question attempt/XP/mastery; transition/Event/progression | Current lesson; answer after attempt | Zod state/node/action; answer/time bounds incomplete | None evident | High-risk/expensive: Unscoped cache and split commit B02/B07 | N |
| H015 | `POST /api/v1/lessons/sessions/:id/interrupts` | [LessonController.handleInterrupt](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/lesson/lesson.routes.ts:14) | User JWT; own session (B02 exception) | Owned session; STUB doubt answer; Conversation + Messages | Own conversation/current text | Zod action UUID + question <=500; node not enforced | None evident | No idempotent replay; DB amplification B07/B10 | N |
| H016 | `POST /api/v1/lessons/sessions/:id/pause` | [LessonController.pauseSession](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/lesson/lesson.routes.ts:15) | User JWT; own session (B02 exception) | Owned ACTIVE session updateMany | Status | Service id+user+status; no param schema | None evident | Zero updated rows still reported success B07 | N |
| H017 | `POST /api/v1/lessons/sessions/:id/resume` | [LessonController.resumeSession](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/lesson/lesson.routes.ts:16) | User JWT; own session (B02 exception) | Owned ACTIVE/PAUSED updateMany | Status | Service id+user+status; no param schema | None evident | Zero updated rows still reported success B07 | N |

### roadmap (6)

Route declarations: [backend/src/modules/roadmap/roadmap.routes.ts](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/roadmap/roadmap.routes.ts). Handler symbols below resolve to the module controllers/services listed in the architecture and evidence register.

| ID | HTTP endpoint | Handler / registration evidence | Authentication and authorization | Purpose and important DB work | Sensitive/proprietary data | Validation | Explicit rate limit | Performance/security assessment | Cache |
|---|---|---|---|---|---|---|---|---|---|
| H018 | `GET /api/v1/roadmaps` | [RoadmapController.listRoadmaps](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/roadmap/roadmap.routes.ts:10) | User JWT; own data; active catalog | Active roadmap + subjects; global syllabus reconciliation | Catalog metadata + own selection | JWT identity only | None evident | High-risk/expensive: GET causes global writes B01/B17 | C02 |
| H019 | `GET /api/v1/roadmaps/active` | [RoadmapController.getActiveRoadmap](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/roadmap/roadmap.routes.ts:11) | User JWT; own data; active catalog | Resolve/persist own active roadmap; sync; steps/sessions/progress | Catalog + own next step | JWT identity only | None evident | High-risk/expensive: Nested query fanout and GET writes B17 | R |
| H020 | `POST /api/v1/roadmaps/steps/:stepId/start` | [RoadmapController.startStepSession](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/roadmap/roadmap.routes.ts:12) | User JWT; own data; active catalog | Calls lesson start-by-step; Session/Event + cache | Current lesson + history | clientActionId truthiness only; no UUID/type schema | None evident | High-risk/expensive: Shared cache, publication/selection checks B01/B02 | N |
| H021 | `POST /api/v1/roadmaps/:roadmapId/select` | [RoadmapController.selectRoadmap](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/roadmap/roadmap.routes.ts:13) | User JWT; own data; active catalog | Resolve active roadmap; update own User | Own selection + metadata | Service active check; string casts | None evident | No prerequisite entitlement model evidenced | N |
| H022 | `GET /api/v1/roadmaps/:roadmapId` | [RoadmapController.getRoadmap](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/roadmap/roadmap.routes.ts:14) | User JWT; own data; active catalog | List all roadmaps then find one; runs sync | Catalog metadata + own selection | ID/slug cast + lookup | None evident | High-risk/expensive: Reads all for one; GET writes B17 | C03 |
| H023 | `GET /api/v1/roadmaps/:roadmapId/subjects/:subjectId/map` | [RoadmapController.getSubjectMap](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/roadmap/roadmap.routes.ts:15) | User JWT; own data; active catalog | Sync; topics/assignments/full version rows; completion histories | Catalog structure + own progress; no full tree DTO | Active lookup; fallback subject; no input schema | None evident | High-risk/expensive: Loads definitions not returned; publication B01/B17 | C04 |

### practice (8)

Route declarations: [backend/src/modules/practice/practice.routes.ts](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/practice/practice.routes.ts). Handler symbols below resolve to the module controllers/services listed in the architecture and evidence register.

| ID | HTTP endpoint | Handler / registration evidence | Authentication and authorization | Purpose and important DB work | Sensitive/proprietary data | Validation | Explicit rate limit | Performance/security assessment | Cache |
|---|---|---|---|---|---|---|---|---|---|
| H024 | `GET /api/v1/practice/topics/live` | [PracticeController.getLiveTopics](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/practice/practice.routes.ts:13) | User JWT | Published script ids; topics/active subtopics | Whole live catalog metadata | JWT only; publication filters in service | None evident | Repeated catalog reads B03/B33 | C01 |
| H025 | `GET /api/v1/practice/history` | [PracticeController.getHistory](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/practice/practice.routes.ts:14) | User JWT | Own page+count; completed-session aggregates | Own history/statistics | page >=1; limit 1..50; no offset cap | None evident | Historical aggregate and deep offsets B27 | C10 |
| H026 | `POST /api/v1/practice/sessions` | [PracticeController.createSession](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/practice/practice.routes.ts:15) | User JWT; own session (B02 exception) | Resolve hierarchy; random/weakness SQL; optional AI; insert 10-question session | All 10 prompts/options/hints; masked solutions | Manual types; <=500 selected IDs; service live selection | None evident | High-risk/expensive: Unlimited catalog harvest and optional AI B03/B10/B30 | N |
| H027 | `GET /api/v1/practice/sessions/:sessionId` | [PracticeController.getSession](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/practice/practice.routes.ts:16) | User JWT; own session (B02 exception) | Owned session + 10 questions; replay chain verification | All 10 prompts; answered solutions | Service id+user; param cast | None evident | High-risk/expensive: Friendly preload before timer; bulk delivery B03/B04 | R |
| H028 | `POST /api/v1/practice/sessions/:sessionId/start-question` | [inline → startFriendlyQuestion](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/practice/practice.routes.ts:17) | User JWT; own session (B02 exception) | Owned active friendly session row lock; initialize questionStartedAt | Remaining timer | Service ownership/status; route raw id | None evident | High-risk/expensive: Timer starts after deck disclosure B04 | N |
| H029 | `POST /api/v1/practice/sessions/:sessionId/answer` | [PracticeController.submitAnswer](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/practice/practice.routes.ts:23) | User JWT; own session (B02 exception) | Current owned question; row locks; progress; completion XP/duel finalize | Current answer and explanations | String ids/options; time finite 0..86400000; option membership | None evident | High-risk/expensive: XP outside transaction; timing B04/B08 | N |
| H030 | `POST /api/v1/practice/sessions/:sessionId/abandon` | [PracticeController.abandonSession](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/practice/practice.routes.ts:24) | User JWT; own session (B02 exception) | Owned session status update; duel abandon if linked | Status/XP | Service ownership/status | None evident | Idempotent active-state update; no quota B10 | N |
| H031 | `POST /api/v1/practice/replay/:sessionId` | [PracticeController.replaySession](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/practice/practice.routes.ts:25) | User JWT; own session (B02 exception) | Owned source; create no-reward practice copy | All 10 masked prompts; answer reveal by submission | Replay chain guarded for PVP; no friendly terminal guard | None evident | High-risk/expensive: Active friendly replay releases solutions B04 | N |

### pvp (6)

Route declarations: [backend/src/modules/pvp/pvp.routes.ts](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/pvp/pvp.routes.ts). Handler symbols below resolve to the module controllers/services listed in the architecture and evidence register.

| ID | HTTP endpoint | Handler / registration evidence | Authentication and authorization | Purpose and important DB work | Sensitive/proprietary data | Validation | Explicit rate limit | Performance/security assessment | Cache |
|---|---|---|---|---|---|---|---|---|---|
| H032 | `GET /api/v1/pvp/ranked/me` | [RankedController.me](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/pvp/pvp.routes.ts:10) | User JWT; registered owner | Registered own season/standing/ordinal/active match in snapshot | Own rating/history status | Strict Zod season/fresh; bounded service | User-local shared 60/min | Existing 5s private cache; fresh bypass; ordinal count | C12 |
| H033 | `GET /api/v1/pvp/ranked/leaderboard` | [RankedController.leaderboard](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/pvp/pvp.routes.ts:11) | User JWT; registered owner | Eligible board page + per-row ordinal; profile names | Authorized public leaderboard | Strict Zod limit<=50 + signed cursor <=2048 | User-local shared 60/min | High-risk/expensive: Correlated rank counts B30; existing 5s top cache | C13 |
| H034 | `GET /api/v1/pvp/ranked/seasons` | [RankedController.seasons](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/pvp/pvp.routes.ts:12) | User JWT; registered owner | Own standings with season/policy; limit+1 | Own historical ratings | Strict Zod season before; limit<=24 | User-local shared 60/min | Bounded; possible private cache | C14 |
| H035 | `GET /api/v1/pvp/matches/:matchId` | [PvpController.getMatch](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/pvp/pvp.routes.ts:14) | User JWT; participant | Match/questions/answers + settlement; participant DTO snapshot | Current round + own result; no future answers | UUID; participant service; RepeatableRead | None evident | High-risk/expensive: Full internal deck fetch; polling abuse B10 | R |
| H036 | `GET /api/v1/pvp/history` | [PvpController.getPlayerHistory](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/pvp/pvp.routes.ts:15) | User JWT; registered owner | Own match page/count with opponent public summary and own rating | Own results + opponent public profile | Strict Zod page<=1000/limit<=50/offset<=10000 | User-local shared 60/min | Bounded query optimization first | Q |
| H037 | `POST /api/v1/pvp/replay/:matchId` | [PvpController.replayMatch](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/pvp/pvp.routes.ts:16) | User JWT; participant | Participant completed/settled match → no-reward PracticeSession | 10 masked prompts; solved feedback on answers | UUID; membership/terminal/settlement checked | None evident | New rows per replay; no quota B10; good Ranked release guard | N |

### daily-challenge (4)

Route declarations: [backend/src/modules/daily-challenge/daily-challenge.routes.ts](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/daily-challenge/daily-challenge.routes.ts). Handler symbols below resolve to the module controllers/services listed in the architecture and evidence register.

| ID | HTTP endpoint | Handler / registration evidence | Authentication and authorization | Purpose and important DB work | Sensitive/proprietary data | Validation | Explicit rate limit | Performance/security assessment | Cache |
|---|---|---|---|---|---|---|---|---|---|
| H038 | `GET /api/v1/daily-challenge/status` | [DailyChallengeController.getStatus](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/daily-challenge/daily-challenge.routes.ts:10) | User JWT; own data; active catalog | Streak sync/Stats; own participation + unused answers include | Own streak/status | JWT identity only | None evident | Repeated participation reads; may write on GET B27 | Q |
| H039 | `POST /api/v1/daily-challenge/start` | [DailyChallengeController.startChallenge](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/daily-challenge/daily-challenge.routes.ts:11) | User JWT; own data; active catalog | Existing script/deck; create/resume own Participation; enqueue prewarm if absent | 1..3 prompts upfront; answered solutions | Own date/finished check; source inventory | None evident | High-risk/expensive: Prewarm 503 converted to 400 B19; races B06 | N |
| H040 | `POST /api/v1/daily-challenge/answer` | [DailyChallengeController.submitAnswer](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/daily-challenge/daily-challenge.routes.ts:12) | User JWT; own data; active catalog | Owned Participation/deck; answer insert; totals; streak/coins/XP | Current correct answer + explanations | Truthy IDs/options; no option/time/day/order guard | None evident | High-risk/expensive: Timing/reward and concurrent completion B05/B06 | N |
| H041 | `GET /api/v1/daily-challenge/history` | [DailyChallengeController.getHistory](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/daily-challenge/daily-challenge.routes.ts:13) | User JWT; own data; active catalog | Own participations/count/answers; all completed avg rows | Own past question text/statistics | parseInt only; no lower/upper bounds | None evident | High-risk/expensive: Unbounded take/offset; full history avg B10/B27 | C11 |

### social (12)

Route declarations: [backend/src/modules/social/social.routes.ts](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/social/social.routes.ts). Handler symbols below resolve to the module controllers/services listed in the architecture and evidence register.

| ID | HTTP endpoint | Handler / registration evidence | Authentication and authorization | Purpose and important DB work | Sensitive/proprietary data | Validation | Explicit rate limit | Performance/security assessment | Cache |
|---|---|---|---|---|---|---|---|---|---|
| H042 | `GET /api/v1/social/friends` | [inline → friendsService.list](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/social/social.routes.ts:27) | User JWT + registered; own/participant | Own accepted friendships, 51 rows; public profiles/presence | Friend identities + presence | Zod cursor UUID/query<=254 | None evident | No explicit request limit; presence freshness | R |
| H043 | `GET /api/v1/social/search` | [inline → friendsService.search](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/social/social.routes.ts:28) | User JWT + registered; registered target/discovery | Parameterized name/email substring; ten users + relations | Discoverable learner identities; email-match inference | Zod query<=254; empty query short-circuits | User/Redis 60/min (nonempty) | High-risk/expensive: Broad substring scan + email discoverability B31/B32 | Q |
| H044 | `GET /api/v1/social/profiles/:id` | [inline → friendsService.profile](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/social/social.routes.ts:29) | User JWT + registered; registered target/discovery | Registered target; relation; full HomeService aggregate; presence | Any registered learner performance/coins/presence | UUID; registration; no friendship/privacy gate | User/Redis shared profile 60/min | High-risk/expensive: Cross-user expensive aggregate/privacy policy B27/B32 | R |
| H045 | `GET /api/v1/social/profiles/:id/activity` | [inline → friendsService.activity](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/social/social.routes.ts:30) | User JWT + registered; registered target/discovery | Registered target; monthly submission union + completions | Any registered learner month activity | UUID; month regex 2000..2099; no friendship gate | User/Redis shared profile 60/min | Privacy policy before private caching B32 | R |
| H046 | `POST /api/v1/social/friends/:id/invite` | [inline → friendsService.invite](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/social/social.routes.ts:35) | User JWT + registered; own/participant | Canonical pair + ordered user locks; pending caps | Own relationship | UUID; target registered; pending cap 100 | User/Redis 30/hour | Atomic pair; abuse limit per sender | N |
| H047 | `DELETE /api/v1/social/friends/:id` | [inline → friendsService.remove](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/social/social.routes.ts:36) | User JWT + registered; own/participant | Own pair removal; cancel pair pending duels/seats | Status | UUID; canonical pair | None evident | No independent rate cap; durable relation update | N |
| H048 | `POST /api/v1/social/friend-invitations/:id/respond` | [inline → friendsService.respond](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/social/social.routes.ts:37) | User JWT + registered; own/participant | Recipient/member; optimistic version; friendship+caps | Status | UUID + strict accept/version datetime | None evident | Good stale guard; no independent rate cap | N |
| H049 | `GET /api/v1/social/inbox` | [inline social inbox handler](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/social/social.routes.ts:38) | User JWT + registered; own/participant | Own pending friendships<=200, duel<=1 and seat | Own invitations | Own JWT + registration | None evident | Polling uncapped; persisted fallback strength | R |
| H050 | `POST /api/v1/social/duels` | [inline → duelsService.invite](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/social/social.routes.ts:51) | User JWT + registered; own/participant | Friendship + competitive availability; durable two seats; scheduling | Own invitation | Strict UUIDs/requestKey; scope<=500/live; booleans | User/Redis 10/min | High-risk/expensive: Lost scheduling after commit B20; content selected later | N |
| H051 | `GET /api/v1/social/duels/:id` | [inline → duelsService.get](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/social/social.routes.ts:56) | User JWT + registered; own/participant | Participant lookup; expiry mutation; sessions/public identities | Participant-only duel status | UUID + participation before expire | None evident | Read may expire session; polling uncapped | N |
| H052 | `POST /api/v1/social/duels/:id/respond` | [inline → duelsService.respond](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/social/social.routes.ts:57) | User JWT + registered; own/participant | Role-specific accept/reject/cancel; lock; snapshot; two sessions | Own session id/status | UUID; strict action; role/status/friendship | None evident | High-risk/expensive: Allocation race guarded; preload integrity B04; scheduling B20 | N |
| H053 | `POST /api/v1/social/duels/:id/leave` | [inline → duelsService.abandon](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/social/social.routes.ts:58) | User JWT + registered; own/participant | Participant lock; abandon duel/sessions; release seats | Status | UUID + participant/status guard | None evident | Critical durable state; do not cache | N |

### admin (51)

Route declarations: [backend/src/modules/admin/admin.routes.ts](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts). Handler symbols below resolve to the module controllers/services listed in the architecture and evidence register.

| ID | HTTP endpoint | Handler / registration evidence | Authentication and authorization | Purpose and important DB work | Sensitive/proprietary data | Validation | Explicit rate limit | Performance/security assessment | Cache |
|---|---|---|---|---|---|---|---|---|---|
| H054 | `POST /api/v1/admin/auth/login` | [AdminAuthController.login](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts:19) | Public | Compare ENV credentials; sign 24h admin JWT | Admin bearer token | Truthiness then String coercion | IP-local 5 failures/15min | High-risk/expensive: Process-local IP lockout; proxy policy B10/B11 | N |
| H055 | `GET /api/v1/admin/achievements/options` | [AdminAchievementsController.options](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts:26) | Admin JWT + ADMIN role | Return enums; no DB | Rule vocabulary | Admin only | None evident | Small static response | C16 |
| H056 | `GET /api/v1/admin/achievements` | [AdminAchievementsController.list](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts:27) | Admin JWT + ADMIN role | All-user submission distributions then page rule analytics | Aggregated learner analytics + rule drafts | Zod page/limit<=50/search/status | None evident | High-risk/expensive: Whole-history analytics B29 | C17 |
| H057 | `POST /api/v1/admin/achievements` | [AdminAchievementsController.create](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts:28) | Admin JWT + ADMIN role | Create Achievement definition | Admin rules | Strict Zod rule constraints | None evident | Versioned CRUD; add audit actor B34 | N |
| H058 | `PUT /api/v1/admin/achievements/:id` | [AdminAchievementsController.update](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts:29) | Admin JWT + ADMIN role | Conditional updateMany by version | Admin rules | UUID + strict rule/version | None evident | Good optimistic concurrency | N |
| H059 | `DELETE /api/v1/admin/achievements/:id` | [AdminAchievementsController.remove](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts:30) | Admin JWT + ADMIN role | Versioned soft archive or hard delete | Status | UUID/version; hard enum true/false | None evident | Privileged delete; actor log B34 | N |
| H060 | `POST /api/v1/admin/achievements/:id/restore` | [AdminAchievementsController.restore](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts:31) | Admin JWT + ADMIN role | Versioned restore inactive definition | Status | UUID/version | None evident | Explicit review before activation | N |
| H061 | `GET /api/v1/admin/auth/me` | [AdminAuthController.me](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts:34) | Admin JWT + ADMIN role | Token identity; no DB | Admin username/role | Admin JWT role | None evident | Shared-secret fallback B11 | N |
| H062 | `GET /api/v1/admin/dashboard/stats` | [AdminDashboardController.getStats](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts:37) | Admin JWT + ADMIN role | Overview + 23 time-bucket growth pairs + daily inventory/history + activity counts | Private operational analytics | Admin only; no query schema | None evident | High-risk/expensive: High query fanout and mixed timezones B28/B29 | C15 |
| H063 | `GET /api/v1/admin/syllabus` | [AdminSyllabusController.getSyllabus](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts:40) | Admin JWT + ADMIN role | All direct/linked subject/topic/subtopic trees + scripts/version metadata | Unpublished curriculum metadata | Admin only | None evident | High-risk/expensive: Nested overfetch/catalog breadth B29 | C18 |
| H064 | `POST /api/v1/admin/syllabus/subjects` | [AdminSyllabusController.createSubject](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts:43) | Admin JWT + ADMIN role | Create Subject; force roadmap sync | Curriculum | TS type only; derives slug | None evident | High-risk/expensive: No runtime schema; active default B16/B17 | N |
| H065 | `PUT /api/v1/admin/syllabus/subjects/:id` | [AdminSyllabusController.updateSubject](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts:44) | Admin JWT + ADMIN role | Prisma update(data=req.body); force sync | Curriculum | TS type only | None evident | High-risk/expensive: Runtime mass assignment surface B16 | N |
| H066 | `DELETE /api/v1/admin/syllabus/subjects/:id` | [AdminSyllabusController.deleteSubject](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts:45) | Admin JWT + ADMIN role | Soft deactivate; optional destructive related deletes; sync | Status | hard literal true; raw id | None evident | High-risk/expensive: Historical integrity B15 | N |
| H067 | `POST /api/v1/admin/syllabus/topics` | [AdminSyllabusController.createTopic](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts:48) | Admin JWT + ADMIN role | Create Topic; sync | Curriculum | TS type only | None evident | Bounds/hierarchy schema missing B16 | N |
| H068 | `PUT /api/v1/admin/syllabus/topics/:id` | [AdminSyllabusController.updateTopic](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts:49) | Admin JWT + ADMIN role | Topic update; sync | Curriculum | TS type only | None evident | Mass assignment review B16 | N |
| H069 | `DELETE /api/v1/admin/syllabus/topics/:id` | [AdminSyllabusController.deleteTopic](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts:50) | Admin JWT + ADMIN role | Soft deactivate or hard related deletes; sync | Status | hard literal true; raw id | None evident | High-risk/expensive: Historical integrity B15 | N |
| H070 | `POST /api/v1/admin/syllabus/subtopics` | [AdminSyllabusController.createSubtopic](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts:53) | Admin JWT + ADMIN role | Create Subtopic; sync | Curriculum | TS type only | None evident | Bounds/hierarchy schema missing B16 | N |
| H071 | `POST /api/v1/admin/syllabus/topics/:topicId/subtopics/import` | [AdminSyllabusController.importSubtopics](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts:54) | Admin JWT + ADMIN role | Validate names/ids/order; transaction createMany; sync | Curriculum | Service array/name/id checks; no request-size cap | None evident | Bulk memory/long write; B09/B16 | N |
| H072 | `PUT /api/v1/admin/syllabus/subtopics/:id` | [AdminSyllabusController.updateSubtopic](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts:55) | Admin JWT + ADMIN role | Spread body → Prisma update; sync | Curriculum | TS type only + slug trim | None evident | High-risk/expensive: Mass assignment surface B16 | N |
| H073 | `DELETE /api/v1/admin/syllabus/subtopics/:id` | [AdminSyllabusController.deleteSubtopic](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts:56) | Admin JWT + ADMIN role | Deactivate or delete question history/related content; sync | Status | hard literal true | None evident | High-risk/expensive: Historical integrity B15 | N |
| H074 | `PUT /api/v1/admin/syllabus/subjects/:subjectId/reorder-topics` | [AdminSyllabusController.reorderTopics](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts:59) | Admin JWT + ADMIN role | Per-id sequence updates for direct/link rows; sync | Status | Array only; scoped updateMany | None evident | Unbounded list; transaction loops B16/B29 | N |
| H075 | `PUT /api/v1/admin/syllabus/topics/:topicId/reorder-subtopics` | [AdminSyllabusController.reorderSubtopics](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts:60) | Admin JWT + ADMIN role | Per-id sequence updates; sync | Status | Array only; scoped updateMany | None evident | Unbounded list; transaction loops B16/B29 | N |
| H076 | `GET /api/v1/admin/syllabus/available-topics` | [AdminSyllabusController.getAvailableTopics](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts:63) | Admin JWT + ADMIN role | Read all available topic contexts | Curriculum metadata | Admin only | None evident | Unpaged metadata; query optimize first | Q |
| H077 | `GET /api/v1/admin/syllabus/available-subtopics` | [AdminSyllabusController.getAvailableSubtopics](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts:64) | Admin JWT + ADMIN role | Read all available subtopic contexts | Curriculum metadata | Admin only | None evident | Unpaged metadata; query optimize first | Q |
| H078 | `POST /api/v1/admin/syllabus/subjects/:subjectId/link-topic` | [AdminSyllabusController.linkTopic](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts:65) | Admin JWT + ADMIN role | Validate hierarchy; create/update SubjectTopic; sync | Curriculum | Truthy id + service lookups | None evident | No strict runtime schema B16 | N |
| H079 | `DELETE /api/v1/admin/syllabus/subjects/:subjectId/topics/:topicId/unlink` | [AdminSyllabusController.unlinkTopic](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts:66) | Admin JWT + ADMIN role | Delete link/deactivate derived relationship; sync | Status | Service IDs/lookups | None evident | Privileged relationship mutation | N |
| H080 | `POST /api/v1/admin/syllabus/topics/:topicId/link-subtopic` | [AdminSyllabusController.linkSubtopic](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts:67) | Admin JWT + ADMIN role | Create/update TopicSubtopic; sync | Curriculum | Truthy id + service lookups | None evident | No strict runtime schema B16 | N |
| H081 | `DELETE /api/v1/admin/syllabus/topics/:topicId/subtopics/:subtopicId/unlink` | [AdminSyllabusController.unlinkSubtopic](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts:68) | Admin JWT + ADMIN role | Remove subtopic link; sync | Status | Service IDs/lookups | None evident | Privileged relationship mutation | N |
| H082 | `GET /api/v1/admin/syllabus/scripts/:id` | [AdminSyllabusController.getScript](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts:71) | Admin JWT + ADMIN role | Script and ordered versions; full definitions | Full proprietary scripts/answers | Admin only; raw id | None evident | High-risk/expensive: Export-equivalent read; no rate cap B10 | R |
| H083 | `POST /api/v1/admin/syllabus/scripts` | [AdminSyllabusController.createScript](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts:72) | Admin JWT + ADMIN role | Create Script/Version; hydrate; invalidate/sync | Full script | Normalization/hydration; TS type; different gate than import | None evident | High-risk/expensive: Publication/integrity B01/B16 | N |
| H084 | `POST /api/v1/admin/syllabus/scripts/import` | [AdminSyllabusController.importScript](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts:73) | Admin JWT + ADMIN role | Validate references/ownership/graph; upsert version; sync/invalidate | Full imported script | Service ScriptValidator + hierarchy/reference checks | None evident | High-risk/expensive: Bulk JSON/review status inconsistency B01/B16 | N |
| H085 | `PUT /api/v1/admin/syllabus/scripts/:id` | [AdminSyllabusController.updateScript](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts:74) | Admin JWT + ADMIN role | New version/metadata; set pointer; hydration via global client | Full script | Normalization/hydration; no same ScriptValidator gate | None evident | High-risk/expensive: Version/publication + nested DB use B01/B16 | N |
| H086 | `GET /api/v1/admin/questions` | [AdminQuestionsController.listQuestions](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts:77) | Admin JWT + ADMIN role | Filtered Question page<=100 + count + hierarchy | Full answers/explanations + provenance | Numeric clamp; filters cast, enum not schema | None evident | High-risk/expensive: Bulk export by paging; bounded page not total budget B10 | R |
| H087 | `GET /api/v1/admin/questions/stats` | [AdminQuestionsController.getStats](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts:78) | Admin JWT + ADMIN role | Counts/groupBy + topic-level statistics | Inventory totals | Admin only | None evident | Repeated aggregates B29 | C19 |
| H088 | `POST /api/v1/admin/questions` | [AdminQuestionsController.createQuestion](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts:79) | Admin JWT + ADMIN role | Derive hierarchy; fingerprint check; insert Question | Full question/answer | TS type; hierarchy exists; no full structure validator | None evident | High-risk/expensive: Publication/content integrity B16 | N |
| H089 | `PUT /api/v1/admin/questions/:id` | [AdminQuestionsController.updateQuestion](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts:80) | Admin JWT + ADMIN role | Load/update Question; hierarchy; fingerprint | Full question/answer | Explicit fields; no full structure validator | None evident | High-risk/expensive: Mutable past practice/daily sources B16/B28 | N |
| H090 | `PUT /api/v1/admin/questions/:id/link` | [AdminQuestionsController.relinkQuestion](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts:81) | Admin JWT + ADMIN role | Derive target hierarchy; update Question | Full question/answer | Truthy target; service lookup | None evident | Cache invalidation/hierarchy consistency B33 | N |
| H091 | `DELETE /api/v1/admin/questions/:id` | [AdminQuestionsController.deleteQuestion](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts:82) | Admin JWT + ADMIN role | Transaction deletes answer/progress/set rows then Question | Status | Admin; raw id | None evident | High-risk/expensive: History destroyed or rated trigger rejects B15 | N |
| H092 | `POST /api/v1/admin/questions/bulk-import` | [AdminQuestionsController.bulkImport](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts:83) | Admin JWT + ADMIN role | Normalize full batch; dedupe; chunk creates inside 60s transaction | Import counts/errors | Nonempty array; service all-or-nothing checks; missing max items | None evident | High-risk/expensive: Long transaction/memory; differing answer validation B09/B16 | N |
| H093 | `POST /api/v1/admin/questions/generate` | [AdminController.triggerQuestionGeneration](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts:86) | Admin JWT + ADMIN role | Direct Gemini generator/reviewer + persist | Generated answers/content | Truthy subtopic; count number without safe cap | None evident | High-risk/expensive: Privileged cost/latency amplification B10/B22 | N |
| H094 | `POST /api/v1/admin/pvp-sets/generate` | [AdminController.triggerPvpSetGeneration](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts:87) | Admin JWT + ADMIN role | Direct Gemini + transaction insert set/questions | Full set/answers | Admin; fixed ten output target | None evident | High-risk/expensive: External calls inline; AI quota B22 | N |
| H095 | `POST /api/v1/admin/questions/manual` | [AdminController.createManualQuestion](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts:88) | Admin JWT + ADMIN role | Separate raw hierarchy/question insert by fingerprint | Full question/answer | Truthy fields only | None evident | High-risk/expensive: Duplicate weaker authoring path B16 | N |
| H096 | `GET /api/v1/admin/users` | [AdminUsersController.listUsers](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts:91) | Admin JWT + ADMIN role | User page<=100 + count; Profile/Stats/Progress | Email/beliefs + identifiers | Numeric clamps; search cast | None evident | Sensitive admin listing; deep offsets | R |
| H097 | `GET /api/v1/admin/users/stats` | [AdminUsersController.getUserStats](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts:92) | Admin JWT + ADMIN role | Counts + all profile demographics materialized in JS | Aggregated demographics | Admin only | None evident | High-risk/expensive: Global scan + naive enum grouping B28/B29 | C20 |
| H098 | `DELETE /api/v1/admin/users/:id` | [AdminUsersController.hardDeleteUser](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts:93) | Admin JWT + ADMIN role | Null winner references; delete User with cascades | Status contains deleted identity | Lookup + admin; no erasure policy | None evident | High-risk/expensive: Conflicts with Ranked RESTRICT/immutable records B15 | N |
| H099 | `PUT /api/v1/admin/config/timing` | [AdminController.updateTimingConfig](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts:96) | Admin JWT + ADMIN role | Mutate process-local TIME_CONFIG; no DB | Timing settings | typeof number only; no min/max/version | None evident | High-risk/expensive: Split-worker state + invalid game time B16/B23 | N |
| H100 | `GET /api/v1/admin/ai-prompts` | [AdminAiPromptsController.listPrompts](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts:99) | Admin JWT + ADMIN role | Lazy initialize prompts; list drafts/published templates | Proprietary AI instructions | Admin only | None evident | GET can write; local cache no cross-process invalidation B23 | R |
| H101 | `GET /api/v1/admin/ai-prompts/:key` | [AdminAiPromptsController.getPrompt](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts:100) | Admin JWT + ADMIN role | Lazy initialization; prompt row by key | Draft + live prompt | String cast; DB existence | None evident | Internal templates; role-gated; no bulk budget B10 | R |
| H102 | `PUT /api/v1/admin/ai-prompts/:key` | [AdminAiPromptsController.updateDraft](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts:101) | Admin JWT + ADMIN role | Update draftPrompt | Prompt draft | Nonempty trimmed string; no max length | None evident | Large payload B09; no optimistic edit version | N |
| H103 | `POST /api/v1/admin/ai-prompts/:key/publish` | [AdminAiPromptsController.publishPrompt](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts:102) | Admin JWT + ADMIN role | Copy draft to published; increment version; local cache update | Live prompt | Exists; no expected-version input | None evident | High-risk/expensive: Workers can use old prompt indefinitely B23 | N |
| H104 | `POST /api/v1/admin/ai-prompts/:key/reset-default` | [AdminAiPromptsController.resetToDefault](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.routes.ts:103) | Admin JWT + ADMIN role | Reset draft from code default | Prompt draft | Known default key | None evident | Reset only draft; sensible cache exclusion | N |

### admin-books (12)

Route declarations: [backend/src/modules/admin/routes/admin-books.routes.ts](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/routes/admin-books.routes.ts). Handler symbols below resolve to the module controllers/services listed in the architecture and evidence register.

| ID | HTTP endpoint | Handler / registration evidence | Authentication and authorization | Purpose and important DB work | Sensitive/proprietary data | Validation | Explicit rate limit | Performance/security assessment | Cache |
|---|---|---|---|---|---|---|---|---|---|
| H105 | `POST /api/v1/admin/books/upload` | [AdminBooksController.uploadBook](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/routes/admin-books.routes.ts:42) | Admin JWT + ADMIN role | Multer disk file; checksum; create Subject/Book; copy PDF; enqueue | Book metadata/path on duplicate | Multer 150MB; PDF magic; title truthiness | None evident | High-risk/expensive: Disk/memory; duplicate jobs; cleanup B18/B36 | N |
| H106 | `GET /api/v1/admin/books` | [AdminBooksController.listBooks](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/routes/admin-books.routes.ts:43) | Admin JWT + ADMIN role | Book page<=50/count with subject counts | Storage path/metadata + proprietary source identity | Numeric clamp; unvalidated status enum | None evident | Sensitive storage metadata; deep offsets | R |
| H107 | `GET /api/v1/admin/books/:id` | [AdminBooksController.getBook](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/routes/admin-books.routes.ts:44) | Admin JWT + ADMIN role | Full Book + subject tree + all jobs | Proprietary metadata/paths/job details | Lookup; raw id | None evident | High-risk/expensive: Jobs/tree overfetch B29/B40 | R |
| H108 | `GET /api/v1/admin/books/:id/status` | [AdminBooksController.getStatus](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/routes/admin-books.routes.ts:45) | Admin JWT + ADMIN role | Book, counts, all job history; calculate stage progress | Private processing errors/metadata | Lookup; raw id | None evident | Frequent polling expensive B19/B29 | C21 |
| H109 | `GET /api/v1/admin/books/:id/topics` | [AdminBooksController.getTopics](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/routes/admin-books.routes.ts:46) | Admin JWT + ADMIN role | Book subject topics + counts and detected metadata | Draft catalog | Lookup; raw id | None evident | Unbounded subject-sized list | R |
| H110 | `PUT /api/v1/admin/books/:id/topics` | [AdminBooksController.updateTopics](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/routes/admin-books.routes.ts:47) | Admin JWT + ADMIN role | Loop updates arbitrary topic ids from body | Status | Array only; book path not bound to topic writes | None evident | High-risk/expensive: Parent id mismatch/partial writes B16 | N |
| H111 | `GET /api/v1/admin/books/:id/subtopics` | [AdminBooksController.getSubtopics](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/routes/admin-books.routes.ts:48) | Admin JWT + ADMIN role | Subtopics + counts by query topicId | Draft catalog | Truthy query topicId; book id unused | None evident | Parent id misleading B16 | R |
| H112 | `GET /api/v1/admin/books/:id/content-preview` | [AdminBooksController.getContentPreview](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/routes/admin-books.routes.ts:49) | Admin JWT + ADMIN role | Latest script/version + <=20 questions by subtopic | Full drafts/answers | Truthy subtopicId; book id unused | None evident | High-risk/expensive: Export-equivalent read; parent mismatch B16 | R |
| H113 | `POST /api/v1/admin/books/:id/publish` | [AdminBooksController.publishBook](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/routes/admin-books.routes.ts:50) | Admin JWT + ADMIN role | Activate subject/topics/subtopics; publish all script versions/questions | Published counts | Book exists; no reviewed-status gate | None evident | High-risk/expensive: Bulk publishes archived/draft content B01/B16 | N |
| H114 | `POST /api/v1/admin/books/:id/retry` | [AdminBooksController.retryStage](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/routes/admin-books.routes.ts:51) | Admin JWT + ADMIN role | Add arbitrary job name; no fixed id | Job acknowledgment | stage fallback; no allowlist or concurrency guard | None evident | High-risk/expensive: Duplicate work; unknown jobs succeed B18/B19 | N |
| H115 | `POST /api/v1/admin/books/:id/cancel` | [AdminBooksController.cancelProcessing](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/routes/admin-books.routes.ts:52) | Admin JWT + ADMIN role | Set local cancellation; remove jobs; mark Book failed | Status | Book exists | None evident | High-risk/expensive: Other worker may continue B18 | N |
| H116 | `DELETE /api/v1/admin/books/:id` | [AdminBooksController.deleteBook](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/routes/admin-books.routes.ts:53) | Admin JWT + ADMIN role | Cancel; 150ms wait; many independent DB deletes; disk cleanup | Status | Lookup; hardDeleteSubject literal true | None evident | High-risk/expensive: Partial destructive purge; rated history B15/B18 | N |

### Registration reachability, overlap and obsolete surfaces

No duplicate explicit method/path pairs were found. Literal `/active`, `/history`, `/ranked/*` and admin `/questions/stats` registrations are not shadowed by a conflicting wildcard of the same method. The admin book router has no own auth middleware but inherits authenticateAdmin from the parent before its mount; it is not public. Public admin login is intentionally registered before that middleware. Runtime feature flags can return 503 for Ranked reads/admission without removing those implemented endpoints.

Semantic overlap: `POST /admin/questions/manual` is a weaker alternative to `POST /admin/questions`; lesson start is exposed through both lesson sessions and roadmap step start with different validation; books subtopic/preview handlers ignore the book path ID and operate on query IDs. Consolidate contracts as A09 while retaining backward compatibility. No endpoint is proven obsolete solely from its name. Non-routed AI/question/XP/Home/achievement services are invoked through registered callers; CLI seed/flow scripts, workers and private helpers are not extra APIs. Daily's legacy normalization/AI imports are residual code, not proof that Daily runtime currently calls AI. No mounted export/download/static-file endpoint was found. Source mounting is verified; deployment reachability, reverse-proxy aliases and client usage are unverified.

## 4. WebSocket command/event inventory

WebSocket upgrades are **not counted as HTTP API endpoints**. Both paths use `noServer` upgrade dispatch; unknown upgrade paths are destroyed. PvP max payload is 8192 bytes, Social 4096 bytes. Neither path shows an Origin allowlist or pre-upgrade IP/connection admission budget. Bearer tokens are not cookies, so absence of Origin checking alone does not establish cookie-based cross-site session hijacking.

| Channel / inbound command | Handler/source | Authentication/authorization and validation | Data/work and assessment |
|---|---|---|---|
| `/ws/pvp` AUTH_INIT | pvp.protocol.ts:5; pvp.socket.ts:84 | Strict Zod token <=4096; signature verified; one identity binding; 3s auth deadline | AUTH_SUCCESS; optional query-token handshake also supported; no later JWT expiry enforcement B14 |
| `/ws/pvp` JOIN_MATCHMAKING | pvp.socket.ts:165 | Bound current socket; user budget 6/10s; registered/available account and capability/service checks | Redis owner/lease queue or legacy global queue/local fallback; may generate PvP set inline B10/B22/B24 |
| `/ws/pvp` LEAVE_MATCHMAKING | pvp.socket.ts:198 | Same user budget; strict optional empty payload; token-fenced cancel | Claim wins over cancel; transport state local; global legacy queue lacks owner routing |
| `/ws/pvp` RECONNECT_MATCH | pvp.socket.ts:225 | UUID; service validates participant before connection mutation/DTO | Rebuilds local routing/timer from persisted state; no per-command budget B10/B14 |
| `/ws/pvp` SUBMIT_ANSWER | pvp.socket.ts:216; pvp-match.service.ts:328 | UUID/index 0..9/option<=32; membership; server ingress timestamp; immutable duplicate answer | ACK contains own selection, not correctness; answer/result release only on round close; no generic message limit B10 |
| `/ws/social` AUTH_INIT | social.socket.ts:47 | Token<=4000; UUID identity; registered account; local and Redis max 5 connections/user; 3s deadline | AUTH_SUCCESS; Redis presence lease; revalidates JWT on heartbeat; generic invalid-session close |
| `/ws/social` HEARTBEAT | social.socket.ts:61 | Authenticated; ignores heartbeats <10s; renew checks token; server closes expiry/70s inactivity | Presence refresh and optional PRESENCE; no per-IP pre-auth flood budget |
| `/ws/social` WATCH_FRIENDS | social.socket.ts:65 | Redis 60/min/user; UUID array<=50; DB accepted-friend intersection | PRESENCE only for accepted watched friends; cached watch membership not rechecked each renewal after unfriend B32 |

**Outbound events:** PvP: `AUTH_SUCCESS`, `QUEUE_STATUS`, `MATCH_FOUND`, `QUESTION_STARTED`, `ANSWER_ACCEPTED`, `QUESTION_ENDED`, `MATCH_RECONNECTED`, `MATCH_COMPLETED`, `ERROR` (9). Social: `AUTH_SUCCESS`, `PRESENCE`, `INBOX_CHANGED`, `DUEL_CHANGED` (4). Only `AUTH_SUCCESS` is shared between the channels: **12 unique names across 13 channel/event combinations**. Ping/pong/close frames are protocol mechanics, not extra application commands. Query-token handshake is an authentication variant, not a sixth PvP command. Social notification IDs are hints; authoritative state remains in HTTP/DB.

## 5. Significant jobs, schedules and workers

Count = distinct operational responsibilities/job-name branches. Composite book full-pipeline is one branch plus seven individually callable stage branches. Worker concurrency and socket maintenance are shown separately, not added again.

| ID | Operation / registration | Trigger/owner | Persistence, retry, risk |
|---|---|---|---|
| J01 | content-generation: `generate-subtopic-questions` (content-generation.queue.ts:64) | BullMQ; every importing server starts worker; concurrency 2/process | Three attempts/backoff 5s; shared Redis lock may expire/fall back; failures retained indefinitely |
| J02 | content-generation: `prewarm-daily-challenge` (:77) | Cron/emergency queue; same worker | MANUAL-PYQ assembly for three tiers; inner tier errors swallowed, so job may appear successful B19 |
| J03 | book-ingestion: `process-full-book` (book-ingestion.queue.ts:120) | Upload/retry; concurrency 1 **per process** | Seven stages; page/topic checkpoints; one attempt; DB progress; timestamp job IDs allow duplicate book work |
| J04 | book-ingestion: `parse-pages` (:205) | Admin retry | PDF parse; local full file/page storage; same cancellation/error weaknesses |
| J05 | book-ingestion: `detect-topics` (:210) | Admin retry | AI discovery + database writes |
| J06 | book-ingestion: `discover-subtopics` (:215) | Admin retry | AI discovery over topics |
| J07 | book-ingestion: `extract-questions` (:220) | Admin retry | AI extraction + records |
| J08 | book-ingestion: `classify-questions` (:225) | Admin retry | AI classification + record updates |
| J09 | book-ingestion: `generate-scripts` (:230) | Admin retry | AI generation + versions; cancellation local |
| J10 | book-ingestion: `validate-content` (:235) | Admin retry | Structural/content review; progress states |
| J11 | social-deadlines: `expire` (social.worker.ts:9) | Delayed invitation 60s / match 24h; concurrency 20/process | Attempts 5 exponential 1s; conditional DB expiry is idempotent; scheduling loss not reconciled B20 |
| J12 | Daily rollover/streak maintenance (server.ts:33) | Midnight Asia/Kolkata in every server process | Bulk stats/participation updates + tier assembly; no shared singleton lease; no durable missed-day run record |
| J13 | Daily next-day prewarm enqueue (server.ts:50) | 23:00 Asia/Kolkata in every server process | Date-based job ID reduces simultaneous duplicate enqueue, not globally exactly-once execution after removal |
| J14 | Ranked recovery + season maintenance (ranked-worker.ts:14) | Every server; 1s ticks; no overlap within worker; season maintenance >=60s | Due-ID keyset page<=100; DB locks/ledger fence state mutations; broadcasts/timers still local; duplicate scans across workers |
| J15 | RS Aggarwal startup sync (server.ts:76; rs-aggarwal-startup-sync.service.ts:39) | After listen in every server | Reads repository books/SubTopics; mutates/imports missing curriculum; no durable run owner or startup opt-out |

Socket maintenance: PvP queue scan 1s, heartbeat/lease refresh 15s, claim renew 15s, per-round timers; Social heartbeat 30s/presence leases. These are additional **timers**, not additional job types in the 15 count. `setImmediate` post-import invalidation/sync (admin-questions.service.ts:596) is untracked asynchronous work: it may be lost on shutdown and is covered by B19/B25.

Book and content queue processors are not sandboxed into another process. `async` makes I/O cooperative; it does not move synchronous PDF/file/JSON work off the Express event loop. BullMQ competing consumers can safely claim distinct jobs, but they do not automatically serialize **different jobs for the same book**, enforce a global provider quota, or make a process-local cancellation set shared.

## 6. Authentication, authorization and untrusted-input assessment

### Identity and session boundaries

Access tokens are signed with a required environment secret and verified for signature/expiry by jsonwebtoken; refresh tokens are opaque random values with only SHA-256 hashes stored. Tokens are returned in JSON, not set as cookies; there is no cookie auth route in the inspected backend. CSRF defenses for a future cookie/session flow must be designed with that change. CORS restrictions are useful for allowed browser origins, but cannot authorize mobile clients or stop authenticated scraping.

Ordinary learner tokens have no ADMIN role claim. The admin verifier's fallback to `JWT_ACCESS_SECRET` therefore **does not by itself let an ordinary learner token become admin**; it unnecessarily broadens the signing trust boundary (B11). Admin tokens last 24h, have no evident revocation/version model, and all privileged operations use the same ADMIN role. Constant-time hashed comparison already exists; do not repeat the old audit's claim that plain string comparison remains.

Service ownership is generally good: lesson/practice loads include userId; Ranked participant checks precede serialization and reconnect mutation; social duel/recipient checks are in services; Ranked replay requires completion and rated settlement. Exceptions: B02's cache return precedes ownership; publication checks are inconsistent (B01); social cross-user profiles expose a broad discoverable profile by design but no privacy policy is enforced (B32). Do not invent a paid entitlement system or sequential lesson gate: current maps deliberately expose available topics. Preserve free choice of **published** available lessons unless product policy explicitly changes; prevent review/archive access and define anti-scraping budgets separately.

HTTP `authenticateJwt` trusts the typed decoded object without validating UUID/email/issuer/audience/algorithm profile or checking account state. Most record services naturally fail nonexistent users, and Social/Ranked explicitly require registration; those extra guards are not uniform across learning. Google verifies ID-token audiences configured by ENV, but backend linking by email does not additionally require `email_verified` or an explicit linking policy (B12). No exploit with a forged Google signature was established.

### Injection and input review

- **SQL:** no `$queryRawUnsafe`, `$executeRawUnsafe`, request-built `Prisma.raw`, dynamic SQL identifiers from input, or string-executed DB query was found. Tagged templates/`Prisma.sql`/`Prisma.join` parameterize inputs; identifier variants come from fixed program branches. See section 10 for every notable raw-SQL family. SQL-heavy does not mean injectable.
- **Command execution/SSRF:** no production child-process command execution or user-selected URL fetch was found in backend services. Google/Gemini SDK destinations are not request-supplied hosts. Profile avatarUrl is stored, not fetched server-side in the inspected backend; future proxying would need SSRF controls. CLI/test scripts are not mounted HTTP routes.
- **Paths/uploads:** Multer writes a generated prefix plus sanitized filename; magic `%PDF` checked and file checksum streamed. Storage helpers join raw bookId but HTTP destructive storage paths are reached after DB lookup; no verified unauthenticated traversal chain. Require UUID/path containment as defense in depth, not a claimed traversal exploit. PDF magic does not establish safe page expansion/runtime cost. Missing-title/failed saves can leave temporary files (B36). Never publicly serve `storage` or repository roots.
- **Prototype/object handling:** no confirmed public prototype-pollution exploit was established. Generic dictionaries used for demographic grouping are fragile for special property names; use Map/null-prototype records (B28). Admin TypeScript argument interfaces are erased at runtime; direct `data`/spread-body Prisma calls allow unintended model/nested properties if valid ORM shapes are supplied by an admin (B16).
- **Validation/DoS:** social schemas, Ranked protocol/cursors, practice array/time bounds, and achievement constraints are strengths. Legacy admin, daily pagination/answer payloads and lesson action fields remain inconsistent; global 150MB parsing occurs before authentication (B09/B10). No concrete catastrophic-backtracking regex chain was established; large-input/JSON/PDF CPU-memory risks are credible without alleging ReDoS.
- **Dashboard-rendered input:** backend returns untrusted names, prompts, Markdown and AI/PDF content as JSON. No backend HTML template sink found. Admin-dashboard escaping, Markdown sanitization and token storage require a separate frontend boundary review; no frontend XSS vulnerability is claimed here.

## 7. Proprietary educational-content threat model

### Assets and realistic adversaries

Protect unpublished scripts, full question/answer banks, lesson graphs and curated explanations/provenance. Relevant adversaries are unauthenticated resource exhausters, ordinary accounts collecting content, cooperating competitive accounts, a stolen admin credential, and anyone who receives a release bundle/repository/backup containing private material.

| Path | Verified current exposure | Attacker capability / limiting control | Practical protection |
|---|---|---|---|
| Lesson start/roadmap | REVIEW/latest-version fallbacks and cached slug publication lookup can bypass intended publication/activity boundary (B01) | Normal account with discovered slug/step can select material; no need for admin | Central published-version/hierarchy rule; pinned versions; explicit learner DTO; honor intentional published-topic free choice |
| Current lesson/action/history | Current node plus reached history; top-level answers/explanations removed, but supported feedback/variation solutions remain (B41) | User can advance legitimately and record what is delivered; no complete-tree public endpoint found | Keep server transitions, whitelist public node fields, bind idempotency to owner/session/request; per-user content budgets |
| Practice sessions | All ten prompts/options/hints delivered immediately; repeated new sessions prefer unseen questions | Normal registered or token-bearing account can repeatedly allocate sessions; arbitrary valid selection by subtopic; answers revealed after any accepted current answer | Bound active/new sessions and distinct-question delivery, current-question delivery + small authorized prefetch; answer reveal after authoritative attempt; telemetry |
| Daily | One daily 1..3-question deck; answers after submission; candidate hierarchy activity not checked (B01) | Lower catalog throughput; same date/tier shared across users; cooperating users can share answers | Server timing/date/attempt rules; no claim to prevent copying an already delivered shared challenge |
| Ranked | Only current question in DTO; both-answer/deadline round close releases feedback; completed participant-only replay | Reuse of already seen set remains observable; no active replay bypass found | Retain frozen snapshots/participant checks; budget reconnect/snapshot reads; avoid shared live/answer caches |
| Friendly duel | Full deck before timer; active practice replay allowed | Participant can inspect future prompts or obtain replay feedback before contest closes (B04) | Authoritative delivery starts timer; prevent friendly replay until terminal authorized reveal; frozen source preservation |
| Admin reads | Paged `/admin/questions`, full script/version reads, book previews, prompts; all ADMIN-gated | Stolen/admin account can enumerate full content; absence of export-named API does not prevent export | Strong admin auth, budgets, actor logs, bounded exports/queries, no bearer tokens in URLs; private/no-store |
| Static files/release/backups | No Express static mount found; six original PDFs and six page JSONs are Git-tracked under backend/storage | Repository/release recipients receive them; public repository/proxy exposure is **unknown** | Private storage root outside releases, private backups, scoped proxy roots, artifact allowlist; audit history only if authorized |

**Can one ordinary account harvest a large proportion of the catalog?** The code permits repeated ten-question practice allocations with unseen-first selection and no request/daily distinct-content quota. This is a credible extraction path for a substantial portion of the **published, live, practice-eligible** question pool. It is not proof every stored question or unpublished lesson is reachable: live filters, current published availability and inventory size limit coverage. Lesson publication mistakes broaden potential exposure; no measured extraction percentage is claimed.

Roadmap/practice catalog endpoints return metadata and IDs/slugs rather than full lesson trees. That helps legitimate navigation but makes enumeration easier. Random UUIDs do not authorize access once IDs are exposed. Cache shared **server-internal immutable content**, then derive the current authorized DTO per user/session/reveal state. Never cache a fully solved response as a shared question key.

Preserve good latency with a server-internal definition cache and small next-unit prefetch only after explicit authorization. The backend shows no documented offline authorization contract; decide allowed offline units, expiry/revocation trade-offs, device/user storage isolation and sync/retry semantics before changing delivery. Flutter asset manifests, bundled JSON, APK/IPA contents, client preload and local persistence were not inspected because this task is backend-only; verify artifact exclusion in a separately scoped packaging check. Delivered text/pictures can be copied or intercepted on a controlled device. Encryption/obfuscation/pinning cannot make displayed content unextractable.

## 8. Abuse controls and initial policies

Current explicit HTTP limits are exactly the ten rows identified in section 3: public admin login; four Ranked read/history routes; Social nonempty search, two profile routes, friend invite and duel invite. Admin login uses local-IP state 5 failed attempts/15min with no global bound/eviction; `req.ip` proxy trust is not configured. Ranked read budget 60/min/user is shared across four handlers **within one process**, not across PM2 workers. Social budgets use Redis `INCR`/TTL and fail closed when unavailable. Presence connections are shared-limited to5/user; watches 60/min; PvP only JOIN/LEAVE share 6/10s. These are not global flood protection.

Proposed starting policies below are **unmeasured proposals**, to tune in authorized staging using normal traffic and metrics. Config bounds must prevent accidentally disabling them. Rate-limit before expensive parsing/queries when possible; return 429 with Retry-After; use 503 for required backing-control outages.

| Operation | Proposed starting policy | Dimensions and caveats |
|---|---|---|
| Public Google login | Per-IP30/min burst 10 plus provider/account failure signals after token verification | Broad IP circuit breaker only; preserve carrier-NAT fairness; no indiscriminate CAPTCHA |
| Refresh | Per token/session 10/min; per-user 30/min; broad IP60/min | Atomic rotation/replay-family handling; do not log token hashes/raw tokens as identifiers |
| Admin login |5 failures/15min per normalized account + generous secondary IP budget; progressive cooldown | Shared Redis state; trusted proxy allowlist; missing/invalid input also bounded; no spoofable trust-proxy blanket setting |
| Private reads | Per-user 120/min baseline, separate heavy summary 30/min | Bound cost rather than multiplying one tiny limit across every Home/Profile request; IP fallback for pre-auth traffic |
| Practice create/replay | Initially 6/min burst 2; e.g.60 new sessions/day and configurable active-session cap | Track distinct question IDs/user/day and sustained catalog traversal; choose legitimate study allowance from UX evidence before enforcement |
| Lesson start/actions | Starts 10/min; actions 120/min/user plus session serialization | No false completion from throttling; answer retries idempotent; measure fast learners and assistive clients |
| Daily | Starts 10/min; answers 20/min; only valid current date/attempt/question | One DB participation/day remains authority, not rate limit substitute |
| Search/profile | Retain 60/min, tighten heavy profile 30/min if needed; short query cost floor | Avoid broad single-character email substring lookups; cache only after visibility policy |
| WebSocket | Pre-upgrade IP/connection admission; per-account connections; authenticated message budget e.g.60/10s; reconnect 6/10s | Separate malformed-message/byte budget and bounded in-flight work; allow protocol ACK/heartbeat; expire auth; do not punish shared NAT solely by IP |
| AI/content admin | Separate global provider request/token/spend budget plus per-admin generation admissions | Queue cost work; bounded count/job uniqueness/backlog; daily hard cost ceiling; reserve interactive capacity |

A single VPS with multiple processes still needs shared counters for account/operation budgets. Reuse existing Redis; cache failures may fall back to a bounded local cache, but authoritative locks, admission and competitive state cannot silently become process-local.

## 9. API caching eligibility and safety matrix

There are **21 endpoint candidates** below, not 21 cache implementations approved. Existing Ranked `/me` and first leaderboard page already have bounded 5s process caches with in-flight coalescing/epoch fencing; do not double-count them as uncached defects. `R`, `Q`, `N` on every other inventory row provides that endpoint's classification. All TTLs below are proposed maximums; measure hit ratio and p95 query cost before adding a layer. Redis is the first shared-cache option; no new cache service is justified.

| Cache ID / exact GET path | What / preferred layer / proposed TTL | Key dimensions and privacy | Invalidation / stale risk / benefit and justification |
|---|---|---|---|
| C01 `/api/v1/practice/topics/live` | Live navigation metadata; Redis or bounded process cache;30–60s | curriculum revision, publication/visibility policy, locale if introduced; authenticate before lookup | Subject/topic/subtopic activity or script publication changes; never include script trees/answers; high repeated catalog reuse |
| C02 `/api/v1/roadmaps` | Static catalog composition plus private selected marker; Redis static fragment 60s | catalog revision; own selected roadmap separately keyed user | Publish/reorder/link/activity/selection; remove GET sync first; safe static/private split avoids leaking another user's selection |
| C03 `/api/v1/roadmaps/:roadmapId` | Same catalog fragment as C02, resolve one roadmap;60s | resolved roadmap ID, catalog revision, user selection overlay | Same ownership; avoid cache per unvalidated arbitrary string; eliminates list-all-for-one work |
| C04 `/api/v1/roadmaps/:roadmapId/subjects/:subjectId/map` | Static map fragment 60s plus private progress 5–10s | resolved IDs, curriculum revision, user/progress version, publication policy | Completion/pause/restart and syllabus edits; never cache a whole mixed response under subject only; optimized projections first |
| C05 `/api/v1/user/home` | User aggregate snapshot; Redis/private 5–10s or request coalescing | userID, IST date/year, metrics version | Attempt/session/duel/daily/XP/badge changes; near-real-time progress; avoid query repeated across overlapping screens |
| C06 `/api/v1/user/achievements` | Rule definitions shared 60s; own metric summary 5–10s | user, page/limit, definitions revision, progress version | Definition edit/archive/restore and any metric write; pagination must not recompute all facts if same summary reusable |
| C07 `/api/v1/user/profile` | Private projection 5–10s; identity fragment longer only with invalidation | user, summary flag, privacy/schema version, IST day | Onboarding/profile/XP/streak/coins changes; remove required read-side writes first; never CDN/shared account data |
| C08 `/api/v1/user/progress` | Own progress read;5s private/coalesce | user + progress version | XP commit; lazy init must precede cache; bypass immediately after authoritative award |
| C09 `/api/v1/user/stats` | Corrected stats; private 10–30s; server catalog totals by revision | user, stats version, catalog revision | Question/step/attempt/XP edits; fix B28 counts first; do not cache wrong whole-catalog materialization |
| C10 `/api/v1/practice/history` | Own bounded history page + summary 5–10s | user, cursor or bounded page/limit, metric version | Creation/answer/abandon/completion/replay; recent page staleness acceptable only if UI knows how to refresh; bound cardinality |
| C11 `/api/v1/daily-challenge/history` | Own bounded history 5–30s | user, normalized pagination, IST date/version | Daily answer/finalization/streak rollover; replace all-row average with SQL first; no answers from another user |
| C12 `/api/v1/pvp/ranked/me` | Existing process cache<=5s; future Redis only if justified | user, season, policy, observation time/version | Admission/settlement/archive; `fresh=1` bypass; keep season-boundary TTL and auth-before-cache; short observation not authority |
| C13 `/api/v1/pvp/ranked/leaderboard` | Existing first-page process cache<=5s; Redis shared snapshot if measured need | resolved season, policy, page size, live/final mode; cursor pages remain uncached initially | Settlement/profile/season finalization; no private standing in key/value; live pages move; signed cursor lifetime applies |
| C14 `/api/v1/pvp/ranked/seasons` | Own bounded season history 10–30s; finalized row fragments longer | user, before, limit, policy/revision, archive status | Settlements/finalization/current-month boundary; no cache of pending state as permanent |
| C15 `/api/v1/admin/dashboard/stats` | Admin-only aggregate snapshot 15–60s Redis | authorized role, metrics revision, IST date/timezone and normalized filters | Eventual refresh or counted writes; display asOf; protection first; high query fanout reuse |
| C16 `/api/v1/admin/achievements/options` | Immutable enum response; bounded process cache or ETag; build lifetime | build/schema version; admin gate remains | Deployment/enum change; tiny response, low priority; not a reason to introduce Redis |
| C17 `/api/v1/admin/achievements` | Aggregate facts/distributions 30–60s rather than unbounded whole response | role, definition revision, metric snapshot, normalized search/page/status | Rule and answer-metric writes; no draft/analytics in public cache; materialize only if measured history size warrants |
| C18 `/api/v1/admin/syllabus` | Draft-inclusive metadata snapshot 10–30s; Redis admin namespace | role, catalog revision; learner cache must be separate | Any admin syllabus/script/link/publication edit; stale editor data must not overwrite versioned changes |
| C19 `/api/v1/admin/questions/stats` | Inventory group counts 15–60s Redis | role, inventory revision, filter contract if added | Question import/update/archive/generation/delete; no question answers in cached totals |
| C20 `/api/v1/admin/users/stats` | DB GROUP BY result 30–60s | admin role, demographics schema/version | Registration/onboarding/erasure; avoid caching raw profile rows; optional if dashboard frequency low |
| C21 `/api/v1/admin/books/:id/status` | Compact latest stage projection 1–3s/coalesce | admin role, validated bookID, job/run version | Job status/progress/cancel/delete; stale success dangerous; bound keyspace and do not cache 404/failed dependency as success |

Important exclusions: token endpoints, lesson actions/start/doubt, all mutations, HTTP health/readiness, live Ranked snapshots/answers/ACKs, social inbox/presence/live duel state and admin destructive commands. Lesson definition and published AI-prompt caches are **internal data caches**, not authorization decisions or response caches. Social profiles/activity require B32 visibility policy before recommending any cache; friend presence should not become a stale cached “online” promise. HTTP no-store and a correctly scoped server-internal cache can coexist.


## 10. PostgreSQL, raw SQL and expensive query assessment

### Schema and integrity

Schema indexes already cover major ownership paths: unique refresh hash/user; lesson `(userId,status)`, `(userId,lastActivityAt DESC)`, `(scriptId,userId)`, `(userId,roadmapStepId)`; question-attempt `(userId,questionId)`; practice `(userId,status)`, `(userId,createdAt DESC)`, `(userId,isReplay,createdAt DESC)`; practice question `(sessionId,sequence)` unique + `(questionId)`; question progress `(userId,questionId)` unique; PvP participant `(matchId,userId)` unique and user/history indexes; PvP answer `(matchId,userId,questionIndex)` unique; Daily participation `(userId,dateString)` unique and `(userId,startedAt DESC)`; Daily answer `(participationId,sequence)` unique; canonical friendship pair unique; friendly seat user primary key; XP idempotency key unique.

These are meaningful protections. They do not replace serialized cross-row finalization. Questions carry independent subject/topic/subtopic FKs, but FKs alone do not prove the three records form one hierarchy. Script subject/topic/subtopic fields are plain strings without those hierarchy relations; publishedVersionId is unique but not a schema FK tying the pointer to a same-script published version. Some services derive hierarchy; weaker legacy creation/update paths do not consistently do so. `ScriptAssignment` has no unique `(roadmapStepId,scriptId)` constraint, despite find-then-create synchronization (B16/B17).

Prepared Ranked SQL adds partial indexes, CHECKs, deferred integrity triggers, immutability triggers and restrictive references not expressed by Prisma. Its existence is not evidence they are installed. User erasure and question/book deletion conflict with those constraints or destroy legacy evidence (B15). Do not drop constraints to make deletion succeed. Operational schema documentation must be reconciled before release (B35).

JSONB stores lesson graphs, snapshots, question options/hints, source metadata and job detail. No blanket GIN index recommendation: current paths mostly retrieve by owning PK then inspect JSON; JSON indexes add storage/write cost without a demonstrated query predicate. Frozen match snapshots should remain immutable; store explicit metadata projections rather than reading every version definition for navigation or catalog counts.

### Every notable runtime raw-SQL family

All source locations below are under `backend/src/modules/`. Every family uses tagged templates or `Prisma.sql` values. No unsafe interpolation was found. SQL text variants are fixed branches, not request-supplied identifiers. `evalLua`/Redis `eval` executes fixed Lua, not JavaScript or request-selected source.

| Location / symbols and lines | Shape / safety / performance or integrity consideration |
|---|---|
| `home/home.queries.ts:13,63,84` homeSubmissions/homeStatsQuery/latestHomeMatchQuery; `home.service.ts:14,22,24` call sites | Four source UNION ALL; bound user filters; grouping sets; recent match join/order. Broad lifetime work is intentional for lifetime stats, not cured by date-only index. Preserve timeout/replay semantics |
| `achievements/achievement.service.ts:9,29`; `achievement.analytics.ts:6`; `admin/admin-achievements.controller.ts:23` | Bound scalar facts + all-user distribution CTE; escaped ILIKE terms; page/limit bound. Global analysis may scan all answer history before pagination |
| `user/user.service.ts:201,217` | Bound user union of solved question IDs; distinct node IDs. Injection-safe; node identity/double counting and whole-catalog preparation incorrect/expensive B28 |
| `practice/services/practice-selection.service.ts:28,48` | Bound IN lists/exclusion fragments; four anti-history probes; random sort; weakness union. Potential scan/sort/probe work grows with eligible pool |
| `practice/services/practice-session.service.ts:407,412,443,578` | Bound UUID row locks + advisory hash lock; rows scoped to session/duel. Collision causes extra serialization, not privilege bypass. XP call must use same tx |
| `social/friend-search.ts:8`; `friends.service.ts:40,84` | Escaped parameterized name/email substring search and month aggregates. Leading wildcard not served by current prefix index; email-match inference remains |
| `social/duel.selection.ts:19` | Bound scope/user weakness aggregates; finite generated query shape; duplicate evidence semantics should be checked |
| `social/user-lock.ts:9`; `duels.service.ts:22,52,107,114,148` | Fixed ordered user/duel/question locks; atomic conditional expiry/accept updates; dynamic value lists use Prisma.join, not raw strings |
| `pvp/services/pvp-match.service.ts:157,180,209` | Published-set selection with count/anti-history/inactive content joins; oldest-updated eligible set selection; validate eligible-set indexes/selectivity in staging |
| `pvp/services/pvp-match.service.ts:288,455,526` | Bound match row lock, keyset due-work scan, season share lock. Due-query OR branches and correlated current-round count require real plans; scans multiply with workers |
| `pvp/ranked/ranked-queries.ts:6`; `ranked-query.service.ts:83` | Bound live/final board with fixed column/order branches; signed values; per-row ordinal subquery on live pages; known page limit prevents unbounded result but not prefix counting cost |
| `pvp/ranked/ranked-settlement.service.ts:14,19` | Bound season share and ordered standing FOR UPDATE; central atomic ledger/XP transaction |
| `pvp/ranked/ranked-season.service.ts:20,49,85,95,101` | Fixed advisory key, season locks, set-based archive rank/update; verify transaction size and lock duration at real season cardinality; not an injection issue |
| `pvp/ranked/ranked-transaction.ts:20` | Fixed DB clock query; server time; no input |
| `xp/xp.service.ts:23,25` | Bound UUID INSERT ON CONFLICT and FOR UPDATE progress lock; caller tx propagation determines atomicity |

### Performance/query opportunity register

All cost assessments are **static risks**, not measured latency. Qualitative benefits require authorized benchmark/EXPLAIN confirmation. A hundred concurrent **active callers** is an example load condition;100,000 registered users does not imply that concurrency.

| Operation / evidence | Cost driver and load trigger | Grounded proposal / trade-off | Verification |
|---|---|---|---|
| Roadmap/lesson active/map: roadmap service 94–347,610–635; lesson service 80–103,933–955 | GET may scan global subject graph and perform per-topic/per-script writes every 4s per process; maps include full version JSON not returned | Move reconciliation to explicit publish/change operation or one durable worker; project version metadata; unique assignments; batch changed rows. Trade-off eventual catalog revision propagation | Query count/request and rows/bytes before/after across small/large curriculum; concurrent publish/read fixtures |
| Home/achievements/social profile: home.service 8–39; queries 63–81; achievement service 29–36; friends.service 62–72 | Same lifetime answers aggregated repeatedly; profile fetch reuses full Home incl unused resume/ranked fields; high-frequency × historical depth | Share user metric observation or small summary, narrow target-profile service, coalesce 5–10s. Keep canonical source semantics; defer durable rollups until measured | Per-route p50/p95, SQL calls/time/buffers vs number of attempts; verify same user/date snapshots |
| Legacy profile/stats: user.service 80–154,160–240 | Published catalog IDs + every published JSON version loaded on cold 2-minute cache; map repeated per process; solved union after catalog pass | Count via projections/SQL metadata; same-script version identity; eliminate nested duplicate stats request; correct source semantics before cache | Cold/warm memory delta, event-loop lag, response correctness with same nodeID in different scripts and repository refs |
| Admin dashboard: controller 10–15; dashboard.service 89–181,265–308 | Growth 7 days +4 weeks +12 months each 2 count queries =46; activity 7×4 =28; >74 counts before overview/daily work; time buckets sequential inside loops | Set-based date buckets/source aggregates; reuse totals; short authorized snapshot. Do not simply run all counts concurrently against one VPS | Query count, wall time, DB CPU/buffers on seeded staging; same IST boundary totals |
| Admin achievements/users: achievement.analytics 6–69; admin-users.service 89–147 | Global history distribution and raw demographics materialized before page/JS grouping | Reuse distribution snapshots if needed; DB GROUP BY; existing distribution design already avoids users×achievements Cartesian join | EXPLAIN and row counts; bounded JS heap; matching categories, including Non-Binary/special keys |
| Practice creation: selection.service 24–43,48–89 | ORDER BY random over eligible pool, four unseen anti-probes; repeated choose calls and catalog retrieval; optional inline AI | Index real filters/history probes; keep random fairness; compare sampled bucket/rotation approach only if needed. Reuse catalog revision | Plans for narrow/broad subtopics and high-history users; generation budget; verify 10 distinct/unseen-first/fallback behavior |
| PvP snapshots/admission: pvp.dto 6–10; match service 155–265,275–289 | Full question-set + all question rows/answers read for current-only DTO; expensive repeated reconnect/snapshot; on-demand generation at shortage | Select snapshot/needed fields directly; bound polls; prewarm sets via one owner; don't cache authoritative state | SQL calls/response bytes vs internal read bytes; hot-match contention; ensure hidden answers remain hidden |
| Live leaderboard: ranked-queries 6–20 | Per returned row counts higher-ranked prefix, even with partial order index; deep cursor pages expensive | First use prepared partial index and actual plan; compute common prefix once/page or ranking snapshot when scale justifies. Cursor reflects live movement | Authorized EXPLAIN for top/deep 50 at staged season sizes; ordinal/tie/cursor correctness |
| Histories: daily.service 698–735; practice.service 748–766 | Daily unbounded take/offset and fetch-all completed avg; practice repeated count/aggregate per page | Enforce bounds; SQL AVG; keyset if deep paging demand; reuse private summary | Pagination boundaries/negative/huge inputs; stable tie order; memory independent of lifetime count |
| PDF/book work: pdf-parser 182,237,288; book-storage 168 | Full 150MB file and parsed text, synchronous file copies/JSON loops in HTTP process; heavy ingestion competes with games | Isolate worker process; async streaming I/O; page/text/resource limits; durable progress and private disk | Representative authorized PDFs; event-loop delay and RSS; cancel/restart and disk-full tests |

### Index candidates grounded in the actual shapes

Candidate definitions are design sketches, **not migrations or an instruction to execute SQL**. Verify installed indexes first; avoid duplicating equivalent existing prefixes. Favor changes with a useful measured plan and record write/storage overhead.

| ID | Query/filter/order | Existing coverage | Candidate / reason / cost |
|---|---|---|---|
| IX01 | practice unseen `user_id,question_id` probe on PvP answers | `(userId,isCorrect)` and questionId indexes; match unique starts with matchId | `(user_id,question_id)` if anti-probe scans many per user; extra index per answer write; user-leading prefix may also aid user stats |
| IX02 | published question by subtopic/status/pattern + bounded ID selection | `(subtopicId,sourceType,status,difficulty)` has intervening sourceType; no pattern order | Compare partial `(subtopic_id,id) WHERE status='PUBLISHED'` plus optional `(subtopic_id,pattern,id)` only for meaningful pattern selectivity; not one index per filter |
| IX03 | Social `search_name LIKE '%term%' OR lower(email) LIKE '%term%'` | searchName text_pattern_ops prefix index; unique raw email | First change product/email query semantics (B32); if substring search remains, authorized pg_trgm expression/name GIN indexes can serve it. Extension/storage/write cost; no automatic extension install |
| IX04 | lesson latest status/step and completed distinct scripts | separate user/status, user/activity, user/step | Compare `(user_id,roadmap_step_id,status,last_activity_at DESC)` or narrow partial active-session index; completed `(user_id,script_id)` partial if justified; avoid all variants together |
| IX05 | due friendly ACTIVE matches after lost delayed jobs | `(status,expiresAt)` applies invitation; no matchExpiresAt index | Partial `(match_expires_at,id) WHERE status='ACTIVE'` for reconciliation; minimal active subset, extra lifecycle writes |
| IX06 | ordered script-assignment identity in synchronization | `(roadmapStepId,sequence)` only | Unique `(roadmap_step_id,script_id)` after authorized duplicate audit; integrity benefit as well as lookup; decide duplicates as product rule before constraint |
| IX07 | live qualified leaderboard order | **Prepared SQL already has** `(season_id,rating DESC,user_id) WHERE qualified_at IS NOT NULL`; final_position partial unique | Verify deployed IX, do not recommend same index as missing. Final archived rating-order page may benefit `(season_id,final_rating DESC,user_id) WHERE final_position IS NOT NULL`, or query by final_position after measuring |
| IX08 | global time-bucket analytics after grouped rewrite | many user-leading indexes cannot directly serve date-only filters | Compare selective createdAt/startedAt/answeredAt indexes or BRIN on large append-only tables **only after** rewrite/plans; each global index costs writes and disk |

Potential redundancy: `(bookId,pageNumber)` unique has bookId prefix and `BookPage @@index([bookId])` may be redundant. Daily `(dateString,tier)` unique similarly covers a dateString prefix; separate dateString index might be unnecessary. Check index sizes/usage and query plans before removing; a narrower index may still be useful. Indexing every FK blindly is not recommended.

## 11. Connection pooling, transactions and contention

Exactly **one `new PrismaClient` in runtime source** (`config/prisma.ts:3`), reused by default-constructed services; no per-request clients found. Test-only independent clients are not production pools. Server calls `$connect` once and `$disconnect` on shutdown. Async jobs/crons in the same process share that pool; a separately started worker would create its own pool. Pool size/timeouts can be embedded in DATABASE_URL, whose values were deliberately not inspected. No explicit pool settings are enforced in checked-in configuration, so actual pool limits are unknown.

Prisma v6 uses its own pool; official v6 docs describe the default physical-core-derived pool size and `connection_limit`/`pool_timeout`. **Do not apply Prisma v7 adapter defaults to this v6.19.3 code.** [Prisma v6 connection pool](https://www.prisma.io/docs/orm/v6/prisma-client/setup-and-configuration/databases-connections/connection-pool).

Define `M`=PostgreSQL max_connections, `R`=database/operator reserves, `O`=backup/maintenance/other client budget, `H`=simultaneous HTTP pools (including old+new overlap), `PH`=each HTTP pool size, `Wj`/`Pj`=worker counts/pool sizes. Require:

`H × PH + Σ(Wj × Pj) + O <= M − R`

Then impose a **lower practical CPU/RAM/I/O concurrency budget**; do not treat the arithmetic ceiling as a throughput target. On one VPS Node, PG and Redis compete for the same cores/memory. More connections can increase context switching, per-query memory and lock contention. PostgreSQL sizes some resources with max_connections; raising it is not free. [PostgreSQL connection settings](https://www.postgresql.org/docs/current/runtime-config-connection.html).

Illustration only: if a measured instance allows M100, reserve R15, O10, two HTTP workers with 5 connections plus one extra HTTP pool during rolling replacement use 15, a realtime owner 5, one jobs pool 3 and scheduler 2 use another 10:35 total including O, within 85 available. This is **not** a recommendation that AptiQu should use 100 connections or those process counts. If all HTTP workers overlap instead of one, budget all old/new pools; if process roles are combined, do not double-count them. Keep per-worker env override/role connection budget and acquisition timeout explicit.

Long transactions: bulk import timeout 60s; book publishing/cleanup and season archive may touch many rows; regular practice unexpectedly calls standalone XP inside a held parent tx (B08); admin script hydration can use global Prisma inside a parent tx. Fix propagation and narrow DB work before increasing pools. Preserve ordered competitive locks and progress-before-stats conventions. Bound waits, classify/retry serialization/deadlock errors using stable idempotency keys; do not retry arbitrary side effects indiscriminately.

PgBouncer is **deferred** unless measurements show idle process pools consuming most of the connection budget after tuning or unavoidable process counts require multiplexing. Validate Prisma v6 transaction pooling/prepared-statement compatibility, advisory transaction locks and tooling access on staging if adopted. It does not fix slow SQL, excessive transactions or row contention.

## 12. PM2 Cluster Mode readiness

| Subsystem | Classification | Evidence / condition |
|---|---|---|
| Pure JWT verification/stateless HTTP controller execution | Cluster-safe with conditions | Same validated secret/key policy and contract across versions; fix revocation and any app state assumptions |
| Prisma singleton | Cluster-safe with configuration | One pool/process; aggregate pool sizing and reload overlap B26 |
| Redis-backed Social pubsub/presence/limits | Cluster-safe with conditions | Subscriber per process routes own sockets; shared connection cap; verify outage/resubscribe/backpressure and privacy behavior |
| Social friendship/duel seat transactions | Cluster-safe with conditions | Ordered user locks, version checks, unique seats; delayed-job reconciliation still missing B20 |
| Ranked DB outcomes/XP/ledger | Requires runtime verification | Locks, duplicate fences, immutable snapshots implemented; supplemental SQL deployment and real race tests unverified |
| Ranked skill queue | **Not whole-system cluster-safe** | Redis Lua only pairs `ownerId` matches (ranked-queue.ts:79,88,113); new process partitions pool; local queueOwners/socket checks; cross-process socket replacement absent |
| Legacy matchmaking | **Not currently cluster-safe** | Shared global zset pops users before local socket lookup; foreign-process player pair rejected/discarded; memory fallback partitions queue |
| PvP sockets, timers, connection status and broadcasts | **Not currently cluster-safe** | Maps local; no pubsub dispatch; reconnect on another worker can create overlapping routing/timers/status; DB locks preserve state transitions but not transport continuity/fairness |
| Ranked recovery/season work | Cluster-safe state with conditions; duplicated transport work | Nonoverlap only per process; DB fences protect commits, not duplicate scans/broadcasts/timer scheduling; retain one realtime owner initially |
| Lesson locks/idempotency | **Not currently cluster-safe** | Unscoped key, fixed-value 3s lock + unconditional DEL + memory fallback; no DB compare-and-swap B02/B07 |
| AI prompt cache | **Not currently cluster-consistent** | Indefinite per-process cache, publish invalidates only serving process B23 |
| Admin login/read budgets | Not shared across workers | Admin/Ranked limit capacity multiplies; evictions/restart reset; B10 |
| Runtime timing endpoint | **Not currently cluster-safe** | Changes TIME_CONFIG only in receiving process and resets on restart; no versioned match snapshot B16/B23 |
| Book ingestion/cancellation | **Not currently cluster-safe** | Worker 1/process is not global 1; timestamp jobs allow same-book work; cancellation Set local B18 |
| Cron/startup reconciliation | **Not currently cluster-safe** | Registered/run per process, cron handles not stopped, startup writes after listen B17/B18/B25 |
| Short-lived observation caches | Cluster-safe with conditions | Bounded stale observations acceptable only when explicitly read-only; invalidations local and TTL honoured; no shared auth state |

**Recommendation now:** retain PM2 and **one application/PvP owner process**, after urgent correctness/security fixes. This is the simplest honest initial topology. It does not solve heavy PDF contention: separate content processing into one PM2 worker once imports/roles are made inert, then measure HTTP/DB demand.

**Prepare next, implement only if needed:** HTTP-only workers under PM2 cluster, one PvP/recovery owner with `/ws/pvp` routed to its dedicated localhost port, one bounded jobs process with one scheduler responsibility. Social may remain with the owner or use its existing per-process pubsub after tests. A local reverse proxy can terminate TLS, serve the admin static build and route realtime paths. PM2 already balances a shared HTTP cluster port; a second application load-balancer layer is not required for HTTP multicore. A proxy is useful for TLS/security/path routing, not to pretend Redis fixes PvP ownership. Sticky sessions alone still partition pairing and do not coordinate duplicate singleton jobs.

**Defer:** distributed socket ownership/election, Redis match transport bus, cross-VPS routing, PgBouncer absent pressure, Kubernetes/microservices/sharding. Owner-fenced skill queues are a safety fence for v1, not completed distributed matchmaking.

## 13. Redis, job reliability and graceful degradation

Authoritative Ranked outcomes and XP are DB-backed; normal Social notifications are transient hints and a missed pubsub message can be recovered by inbox/state reads. Do not introduce a durable event platform for every online indicator. Critical settlement/progression/rewards need transactional idempotency and recovery (B06–B08); optional notifications may be dropped with clear telemetry.

Redis outage policies differ: Social refuses required coordination; ranked skill queue refuses admission; legacy queue and generic lesson/AI locks fall back to process memory. That generic fallback is unsafe for ownership and has no bounded capacity/sweeper; stale entries expire only on lookup. Separate cache degradation from locks/admission. `ConcurrencyLockService` uses unique-token compare/delete when Redis is available, but its fallback token is not removed by failed Lua release; fixed TTL can expire during a long Gemini generator/reviewer/retry chain (B22).

Two queue-specific URL parsers discard Redis username, database index and `rediss:` TLS, while other integrations use ioredis's full URL. Invalid URLs silently fall back tolocalhost. This can produce queues in the wrong Redis DB or failed/insecure authentication, depending on deployment; no TLS deployment was inspected (B21).

Book catches ordinary processor errors and returns `{success:false}`; BullMQ sees a resolved processor, so completed/remove-on-complete behavior can erase failure evidence. Unknown job names also resolve success. Daily prewarm catches each tier failure and still resolves. BullMQ marks thrown `Error` failures and applies configured attempts/backoff; a return value is not an exception. [BullMQ failure/retry contract](https://docs.bullmq.io/guide/retrying-failing-jobs). Persist operation status and propagate appropriate failures while keeping explicitly cancelled jobs distinct; don't enable automatic billable book retries against the current one-attempt policy without review.

## 14. Zero-downtime and rolling-reload readiness

`SIGINT`/`SIGTERM` handlers exist and call `server.close`; this is a useful start. It is **not evidence of a safe rolling application deployment**:

- `/health` always returns 200 and does not express startup dependency readiness or shutdown drain. No separate readiness endpoint or `process.send('ready')` handoff exists. Queue workers are created at module import; Social/Ranked start before listen; curriculum import runs after accepting traffic.
- Cron handles are not retained/stopped. The social Redis transport closes before accepted HTTP handlers and the Social deadline worker finish, so in-flight operations may need a resource already shut down. Shutdown has no single-entry guard, bounded deadline, tracked in-flight mutations or `finally` safety.
- PvP sends close 1001 but does not await full socket drain/termination; closes timers rather than live connection handoff. Recovery can resume persisted deadlines/state; users still disconnect and can miss rounds/deadlines. Closing/reopening preserves some state, not continuous play.
- Book/Gemini work may exceed a supervisor kill timeout. No explicit work checkpoints/drain admission ensure a long job can resume without duplicated side effects. Generic Redis client is not explicitly quit; process.exit eventually tears it down.
- Rolling overlap duplicates cron/startup/import responsibilities, uses more pools and may serve incompatible state/DTO/policy versions. Prepared SQL explicitly requires additive schema before code and retention of settlement duties during rollback.

PM2 documents reload with fallback to restart when its reload timeout is exceeded; graceful cleanup/readiness options require application participation. [PM2 cluster reload](https://pm2.keymetrics.io/docs/usage/cluster-mode/), [PM2 start/shutdown controls](https://pm2.keymetrics.io/docs/usage/signals-clean-restart/). Those controls are future configuration proposals; no PM2 settings are verified here.

| Guarantee | Current assessment | Low-complexity target |
|---|---|---|
| Graceful application shutdown | Partial; incomplete ordering/deadlines | Stop admission/schedulers, finish accepted HTTP/DB operations, pause/drain workers, close sockets/transports, then DB; bounded final termination |
| Zero-downtime HTTP deployment | **Not established / not currently safe to promise** | After role separation, compatible schema/DTOs, readiness-gated replacement and measured request draining, PM2 can roll HTTP workers |
| Continuous active PvP sessions | **No** | Drain new matchmaking, let current games settle with existing owner, then restart owner; give planned reconnect semantics; defer handoff design |
| VPS/OS/PG/Redis high availability | **No** | One machine is one failure domain; backups/restore and reboot runbook reduce recovery time, not eliminate outage |

A single-instance fork restart has an application gap. Do not turn on multiple copies of this combined entry point to claim zero HTTP downtime. After planned separation, reload HTTP independently; keep PvP owner alive until its games settle. Compatible additive schema changes and old/new coexistence are required, with rollback preserving admitted match policy/ledger obligations. No CI/CD implementation is proposed.

## 15. Environment values, secrets and hardcoded-code inconsistencies

**No embedded production secret was identified in the inspected backend source/manifests.** Required JWT/admin/database credentials already come from ENV. Google/Gemini keys are environment lookups. The format scan produced no production source key/private-key/JWT/credential-URL hit; the credential-shaped `.env.example` URL is an example configuration, not proof of a real secret. `.env` is ignored and not tracked in the current Git index; its values and Git history were not opened. This is scoped assurance, not a guarantee no secret ever existed in history or production. No credentials need to be copied into this report or chat.

Actual gaps to plan:

| Current location | Problem / intended destination |
|---|---|
| `config/env.ts:13–36`; `.env.example` key list | No schema for finite port/enum/secret length/distinctness/duration/Redis protocol/conditional OAuth+AI availability. Template lacks Gemini and all runtime Ranked configuration keys; add placeholders/documentation without values |
| `utils/jwt.ts:25`; `auth.service.ts:81,245` | Refresh lifetime hardcoded 7 days; `JWT_REFRESH_EXPIRATION` is read but ignored; `JWT_REFRESH_SECRET` is required but unused because tokens are opaque. Use one validated refresh TTL and remove/deprecate unused key, not invent refresh JWT encryption |
| `admin.middleware.ts:16,24–25` |24h admin expiry hardcoded; use validated ADMIN_JWT_EXPIRATION; remove user-secret fallback rather than externalizing the unsafe behavior |
| `app.ts:17–20`; `admin-books.routes.ts:10,30` | Allowed origins, trusted proxy/bind policy, ordinary/admin body budgets, upload limits and private storage root belong in bounded deployment ENV config |
| `server.ts:29–76`; queue module constructors | No explicit runtime role/startup sync/worker enable gates. Add validated role/enable settings and pool budgets; move imports side effects into explicit startup factories |
| `gemini.provider.ts:8,77–102`; generation services | Provider spacing/concurrency/timeouts/retries/cost caps should be configurable operational limits. Zero thinking budget becomes 1024 via `\|\|`; generated provenance hardcodes model rather than actual ENV/model result |
| `pvp/ranked/*` process.env accesses | Existing admission/read/matchmaking/drain/season/cursor/window ENV knobs bypass central loader; validate together, preserve intentional default-off gates and UTC host/DB convention |
| `book-storage.service.ts:14–15`; `rs-aggarwal-startup-sync.service.ts:8–9` | CWD/repository-relative storage/import source roots and name-based target selection; ENV for deployment roots/enable flag, stable catalog/subject identity in reviewed data/config |
| `lesson.service` defaults (lesson-session.service.ts:929); `practice-session.service.ts:168`; roadmap service 117 | Hardcoded curriculum fallbacks can serve/mutate unintended content; resolve explicit database defaults/availability, not dozens of ENV syllabus IDs |
| `inventory.config.ts`; timing endpoint; RANKED_POLICY; XP policies | Game rules/timing/rewards/content counts are versioned product policy. Keep approved constants or persisted pinned configuration; ENV is not a replacement for consistent policy snapshots, migrations or an editor |
| `daily`/`home` explicit Asia/Kolkata dates | IST learner day is a product contract, not a secret or deployment accident. Keep canonical shared date helper; do not make each service independently configurable or change OS timezone |

A concrete migration register, proposed ENV names, safe defaults/requiredness, tests and compatibility steps appear in the plan. Moving a literal to ENV alone does not make it secure; validate, bound, keep secrets private and scope process overrides.

## 16. Observability, operational hardening and recovery

Current request logs include method, original URL, status and duration after body parsing; some modules have defensive generic errors and optional-subsystem status. Missing evidence: structured request IDs/route templates, consistent error classification/redaction, latency percentiles, event-loop lag/RSS, pool wait/timeout and lock/deadlock counters, Redis readiness/reconnects, socket admission/message/disconnect counts, queue age/failures and settlement reconciliation lag, content-delivery telemetry and admin actor audit trails. Parser failures arrive before the HTTP logger. Arbitrary query text in URLs and raw exception objects/messages can expose identifiers/internal SQL/paths/content (B34).

Minimum one-VPS baseline: JSON logs with request ID, normalized route, duration/status, coarse error code and pseudonymous user/actor ID; explicit token/authorization/URL-secret redaction; bounded log retention/rotation; basic CPU/RSS/event-loop/pool/Redis/job metrics; alerts for auth/429 spikes, stalled reconciliation, queue backlog, persistent failed prewarm, repeated restart and low disk. Use request-level sampling for high-volume success paths, never log complete lesson definitions/answers/tokens. Query diagnostics should record duration/fingerprint without raw parameter values.

No production reverse-proxy config, certificate/firewall/DB role grants/Redis ACLs/file modes/backups were available or accessed. Do **not** conclude TLS, localhost isolation or restore coverage exist or are absent. Before launch, verify TLS termination and WS upgrades; private backend/PG/Redis listeners; least-privileged runtime DB role distinct from schema owner; Redis ACL/persistence/maxmemory policy appropriate to queues; private storage and secrets modes; encrypted off-machine backups with tested restore and retention; free-disk monitoring; read-only deployment files and log rotation. A local backup on the same VPS is insufficient disaster recovery. An off-machine encrypted backup is compatible with a single serving VPS.

## 17. Single-VPS scaling recommendation

Scale vertically first. PostgreSQL query/index/transaction work, content delivery limits and worker isolation matter more initially than maximizing Node process count. Reserve RAM for PG working set/page cache, Redis durable queues/leases, Node RSS and PDF expansion, OS, logs and backups; prevent AI ingestion from using all CPU/I/O. Configure role-specific memory ceilings and global AI/job concurrency based on measurements. Redis eviction must not silently delete durable jobs/coordination to make room for opportunistic caches; use bounded cache namespaces/TTLs and assess Redis memory policy before response caching.

**Worthwhile now:** security/integrity fixes, one PvP owner, no startup catalog mutation on every HTTP worker, dedicated bounded content worker, request/input quotas, known DB pool budget, restore/drain runbooks and essential diagnostics. **Prepare but defer activation:** HTTP-only PM2 cluster role, read-cache interfaces/revision invalidation, compatible additive DB deployment process and per-role pool overrides. **Defer until measured demand:** PgBouncer, durable rollups/ranking snapshots beyond small caches, cross-process PvP transport ownership, extra servers and distributed architecture.

Capacity validation later should use a separate authorized staging workload with realistic learned history/catalog sizes and user behavior: Home/Profile navigation, lessons/actions, practice creation, matchmaking, live answers and an isolated book job. Record p50/p95/p99, event-loop lag, RSS, PG CPU/I/O/buffers/locks/pool waits, Redis memory/latency, socket disconnects and job lag.100,000 accounts is a storage/retention aspiration, not a simultaneous connection target. No VPS size or RPS capacity can honestly be selected from source alone.

## 18. Existing strengths to preserve

- Required core environment credentials fail fast; no production literal secret found; opaque high-entropy hashed refresh tokens; Google SDK verifies identity tokens.
- Constant-time admin comparison and existing login attempt control; separate admin signing secret and explicit role check (remove fallback trust).
- Most learner record access is user-scoped at service boundary. Social roles/registration/ordered locks/unique seats and Ranked participant-only DTOs are real controls.
- Ranked server-ingress time, strict protocol limits, frozen question snapshots, round-release gating, duplicate immutable answers, durable deadlines/recovery and atomic outcome/Elo/XP/ledger are substantial improvements.
- Parameterized SQL throughout inspected runtime queries; escaped search wildcard text; safe fixed SQL fragments; bounded Ranked cursors/read pages and DTOs.
- Central XP ledger/idempotency/progress lock, configurable-policy version pinning for Ranked, RepeatableRead observation, bounded 5s Ranked caches with coalescing and in-flight invalidation fences.
- Daily `/start` uses existing inventory and emergency background assembly rather than an external AI call; practice random-mode shortage does not automatically generate; Social notifications recover through persisted HTTP state.
- Upload disk streaming, sanitized file names, PDF header check, streaming checksum, unique fingerprints/external keys and strict script import validation; these need consistent application, not replacement.
- Existing pure/mock test suites and explicit opt-in PostgreSQL/Redis integration guards. Read-only TypeScript compilation passed for the current checkout.


## 19. Consolidated evidence-based findings register

Severity is realistic impact, not a count of possible attacks. “Verified” means source/control-flow evidence; no runtime exploit, query plan or production configuration was verified. Each finding maps to plan actions in the companion document. Source references below are current checkout anchors, not claims that a live server runs these exact lines.

| ID | Severity | Category | Finding | Complexity |
|---|---|---|---|---|
| B01 | High | Content authorization | Learner publication boundary is inconsistent | Large |
| B02 | High | Authorization/idempotency | Lesson response cache is not scoped to owner, operation or session | Medium |
| B03 | High | Content abuse | Published question bank can be harvested by ordinary session creation | Large |
| B04 | High | Competitive integrity | Friendly duel preloading and replay bypass fair timing/reveal | Large |
| B05 | High | Daily integrity | Daily answers trust client timing and omit current-day/order/option checks | Large |
| B06 | High | Concurrency/recovery | Daily multi-question completion is not serialized or reconciled | Medium |
| B07 | High | Transactional learning | Lesson side effects commit before transition; locks fail open | Large |
| B08 | High | Rewards/pooling | Regular practice opens standalone XP transaction inside parent transaction | Small |
| B09 | High | Resource exhaustion | Most routes parse 150MB bodies before authentication | Small |
| B10 | High | Abuse prevention | HTTP/WS/AI budgets are incomplete and some are process-local | Medium |
| B11 | Medium | Token/admin security | Admin trust fallback and token validation are too broad | Medium |
| B12 | Medium | Identity policy | Google email linking and account eligibility policy need tightening | Medium |
| B13 | Medium | Session reliability | Refresh rotation/expiry and logout lifecycle are inconsistent | Medium |
| B14 | High | Realtime authentication | PvP socket never expires its authenticated JWT | Medium |
| B15 | High | Data retention/integrity | Admin destructive workflows conflict with historical and Ranked evidence | Large |
| B16 | Medium | Validation/config integrity | Privileged authoring paths enforce different contracts | Large |
| B17 | High | Read-path reliability/performance | Roadmap GETs perform global synchronization with unsafe local throttling | Large |
| B18 | High | Job ownership | Book/cron/startup work relies on process-local singleton assumptions | Large |
| B19 | Medium | Job failure contracts | Failed jobs and unavailable Daily start can look successful or misclassified | Medium |
| B20 | Medium | Social recovery | Delayed-job enqueue loss can strand friendly reservations | Medium |
| B21 | Medium | Redis configuration | Queue Redis URL parsing discards security and routing options | Small |
| B22 | Medium | AI cost/concurrency | Provider throttle and generation leases do not bound shared work | Medium |
| B23 | Medium | Cross-process configuration | Published prompts/timing updates are inconsistent across processes | Medium |
| B24 | High | PM2/realtime topology | Combined application is not safe for unchanged PM2 cluster | Large |
| B25 | High | Lifecycle/deployment | Shutdown/readiness do not establish rolling-reload safety | Large |
| B26 | Medium | Database capacity | Pool configuration is not budgeted across roles/reloads | Small |
| B27 | Medium | Read efficiency | Frequent personal/profile endpoints repeat historical/catalog work | Medium |
| B28 | Medium | Metrics consistency | Legacy statistics conflate node identities and reporting contracts | Medium |
| B29 | Medium | Admin efficiency | Admin analytics and catalog reads overfetch or repeat many queries | Medium |
| B30 | Medium | Query/index performance | Question selection and live ranking need plan-guided tuning | Medium |
| B31 | Medium | Search efficiency | Leading-wildcard learner search bypasses current prefix index | Medium |
| B32 | Medium | Privacy/authorization policy | Social discoverability and presence checks are inconsistent | Medium |
| B33 | Medium | Cache correctness | Script cache still hydrates all question references and has stale/lock gaps | Medium |
| B34 | Medium | Error/log/cache privacy | Generic errors/logs and response headers expose unnecessary detail | Medium |
| B35 | Medium | Schema/release compatibility | README db-push workflow contradicts Ranked SQL requirements | Medium |
| B36 | Medium | Operations/resource recovery | Operational isolation, resource bounds and restore evidence are incomplete | Medium |
| B37 | Medium | Environment/configuration | ENV schema and hardcoded operational settings are inconsistent | Medium |
| B38 | Low | Provenance/maintainability | AI records report a hardcoded model/prompt version | Small |
| B39 | Low | Verification/tooling | Default test command can write DB; key regression coverage unproven | Small |
| B40 | Medium | Artifact/content confidentiality | Private source PDFs and page JSON are tracked in backend storage | Small |
| B41 | High | Answer confidentiality | Lesson sanitizer retains supported solution-bearing feedback and variations | Medium |

### B01 — Learner publication boundary is inconsistent

**High · Content authorization · Complexity: Large.** Affected: Lesson/roadmap start, active/map; admin publish.

**Evidence:** [backend/src/modules/roadmap/services/roadmap-progression.service.ts:287](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/roadmap/services/roadmap-progression.service.ts:287), [backend/src/modules/lesson/services/lesson-session.service.ts:148](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/lesson/services/lesson-session.service.ts:148), [backend/src/modules/lesson/services/script-cache.service.ts:16](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/lesson/services/script-cache.service.ts:16), [backend/src/modules/admin/services/book-publishing.service.ts:75](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/services/book-publishing.service.ts:75).

**Observed:** Sync selects PUBLISHED or REVIEW scripts and latest version regardless of version status, then writes PUBLISHED assignments. Start fallback accepts REVIEW/direct script; slug cache checks a published version but not parent script/hierarchy activity. Book publishing marks all versions/questions published.

**Additional question-publication evidence:** [Daily candidate query](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/ai/services/daily-challenge-generation.service.ts:116) filters question PUBLISHED but not active subject/topic/subtopic. [PvP set selection](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/pvp/services/pvp-match.service.ts:157) checks set publication and active hierarchy, but not each question status; [freezeQuestions](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/pvp/ranked/ranked-questions.ts:13) validates structure, not publication. A question archived after set creation can therefore enter a new match; Daily can select from inactive hierarchy. These are admission gaps, not authorization to mutate already admitted frozen match evidence.

**Impact and trigger:** A normal account can play review/archived/inactive material where those data states exist; cached resolution may retain revoked publication. This is not evidence that all catalog entries exist or are externally reachable.

**Confidence:** Verified code; exposure requires corresponding stored states.

**Remedy:** One central learner publication rule, same-script pinned published version and active hierarchy; remove review/latest-any fallbacks and broad publish-all transitions; retain intentional free choice of published topics.

### B02 — Lesson response cache is not scoped to owner, operation or session

**High · Authorization/idempotency · Complexity: Medium.** Affected: Lesson starts/actions; roadmap step start.

**Evidence:** [backend/src/modules/lesson/services/lesson-session.service.ts:74](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/lesson/services/lesson-session.service.ts:74), [backend/src/modules/lesson/services/lesson-session.service.ts:429](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/lesson/services/lesson-session.service.ts:429), [backend/src/modules/lesson/services/lesson-session.service.ts:570](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/lesson/services/lesson-session.service.ts:570), [backend/src/modules/roadmap/roadmap.controller.ts:135](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/roadmap/roadmap.controller.ts:135).

**Observed:** idemp:action:<clientActionId> returns cached response before any ownership/resource check. Roadmap start checks only truthiness, unlike lesson UUID validation.

**Impact and trigger:** Knowledge/reuse of another action key can disclose its response; same-user cross-session/operation key reuse returns unrelated content/state. UUID randomness reduces guessing but does not supply ownership. No live cache enumeration attempted.

**Confidence:** Verified key/check ordering; cross-user leak conditional on shared/known action ID.

**Remedy:** Authorize first; key by user+operation+session and request hash; durable idempotency record in same mutation transaction; validate all entry points and reject key/payload conflict.

### B03 — Published question bank can be harvested by ordinary session creation

**High · Content abuse · Complexity: Large.** Affected: Practice create/get/answer/live catalog.

**Evidence:** [backend/src/modules/practice/services/practice-session.service.ts:283](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/practice/services/practice-session.service.ts:283), [backend/src/modules/practice/services/practice-selection.service.ts:28](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/practice/services/practice-selection.service.ts:28), [backend/src/modules/practice/practice.routes.ts:13](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/practice/practice.routes.ts:13).

**Observed:** Every session returns ten prompts/options/hints, prefers unseen allocations, and can be created without an active/new-session or distinct-content quota. Any accepted answer releases that question solution.

**Impact and trigger:** Normal-account repeated legitimate-looking requests can cover a large practice-eligible live bank and later collect explanations. Does not prove access to every unpublished question.

**Confidence:** Verified delivery/no evident controls; achievable fraction needs inventory/runtime evidence.

**Remedy:** Bound new/active sessions and distinct deliveries, current-unit DTO/prefetch contract, user-scoped scraping telemetry and enforceable budgets; no client encryption claim.

### B04 — Friendly duel preloading and replay bypass fair timing/reveal

**High · Competitive integrity · Complexity: Large.** Affected: Practice session get/start-question/replay/answer used by friendly duels.

**Evidence:** [backend/src/modules/practice/services/practice-session.service.ts:284](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/practice/services/practice-session.service.ts:284), [backend/src/modules/practice/services/practice-session.service.ts:576](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/practice/services/practice-session.service.ts:576), [backend/src/modules/practice/services/practice-session.service.ts:623](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/practice/services/practice-session.service.ts:623), [backend/src/modules/practice/services/practice-session.service.ts:240](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/practice/services/practice-session.service.ts:240).

**Observed:** All ten prompts arrive before questionStartedAt is initialized. Replay traverses PRACTICE ancestry without checking original friendly-duel terminal state; clone can reveal answers while source contest remains active and may use mutable question rows.

**Impact and trigger:** An authorized participant can inspect future questions before starting timers or obtain practice solution feedback before the contest ends. Ranked replay has a separate correct terminal guard; do not remove it.

**Confidence:** Verified code path; not exercised against live matches.

**Remedy:** Deliver current question when starting its authoritative timer; freeze permitted future prefetch policy; require friendly source terminal/reveal eligibility at create/read/answer through replay chains and preserve frozen content.

### B05 — Daily answers trust client timing and omit current-day/order/option checks

**High · Daily integrity · Complexity: Large.** Affected: Daily start/answer.

**Evidence:** [backend/src/modules/daily-challenge/daily-challenge.controller.ts:69](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/daily-challenge/daily-challenge.controller.ts:69), [backend/src/modules/daily-challenge/daily-challenge.service.ts:490](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/daily-challenge/daily-challenge.service.ts:490).

**Observed:** Only participation ownership/status/membership/duplicate checks precede scoring. No deadline/day/current sequence or option-membership validation; responseTimeMs supplied by client is persisted. Whole daily deck is preloaded.

**Impact and trigger:** Client can report invalid/negative times or submit beyond intended timing/date until another process closes status. Statistics and challenge fairness suffer; actual timing bypass does not let arbitrary incorrect answers become correct.

**Confidence:** Verified missing authority; midnight extension depends on cron timing/outage.

**Remedy:** Persist server question delivery/start/deadline, validate finite bounded time only as telemetry, current IST date and sequence/options; consistent timeout/reveal contract.

### B06 — Daily multi-question completion is not serialized or reconciled

**High · Concurrency/recovery · Complexity: Medium.** Affected: Daily answer/start; rollover.

**Evidence:** [backend/src/modules/daily-challenge/daily-challenge.service.ts:404](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/daily-challenge/daily-challenge.service.ts:404), [backend/src/modules/daily-challenge/daily-challenge.service.ts:529](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/daily-challenge/daily-challenge.service.ts:529), [backend/prisma/schema.prisma:1039](/Users/shagunkumar/Desktop/aptiqu/backend/prisma/schema.prisma:1039).

**Observed:** Status and existing answers are read outside tx; different answers insert/count/update without locking participation or rechecking status. Unique sequence prevents duplicate same-question writes, not cross-question finalization race.

**Impact and trigger:** Concurrent answers can each count incomplete views and leave an all-answered participation IN_PROGRESS or stale summary; failure/start races lack idempotent recovery. Do not assert unlimited duplicate coin awards without additional evidence.

**Confidence:** Verified transaction shape; exact interleaving needs isolated DB test.

**Remedy:** Lock owned participation before all validation/count/finalization; idempotent completion, retry-safe start/upsert and bounded reconciliation of unfinished/expired records.

### B07 — Lesson side effects commit before transition; locks fail open

**High · Transactional learning · Complexity: Large.** Affected: Lesson actions/start/interrupt/pause/resume; mastery.

**Evidence:** [backend/src/modules/lesson/services/lesson-session.service.ts:576](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/lesson/services/lesson-session.service.ts:576), [backend/src/modules/lesson/services/lesson-session.service.ts:644](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/lesson/services/lesson-session.service.ts:644), [backend/src/modules/lesson/services/lesson-session.service.ts:692](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/lesson/services/lesson-session.service.ts:692), [backend/src/modules/lesson/services/mastery.service.ts:13](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/lesson/services/mastery.service.ts:13), [backend/src/modules/lesson/services/redis.service.ts:97](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/lesson/services/redis.service.ts:97).

**Observed:** Attempts, XP and mastery occur before session/Event transaction; cache response is written after later progression work. Lock fixed value 1 expires 3s and unconditional DEL may delete a successor; Redis loss uses local locks. Version checked before unconditional update rather than SQL CAS.

**Impact and trigger:** Crash/delay/concurrent request can award XP without advancing, strand an action due to unique attempt ID, overwrite newer state or lose mastery counts. Interrupt action IDs not used for idempotency; pause/resume report success for zero rows.

**Confidence:** Verified split writes/checks; exact races require DB tests.

**Remedy:** Use one owned session row-lock/CAS transaction for attempts/mastery/XP/Event/progression as appropriate; durable result/recovery; optional token-owned cache locks only; explicit no-op semantics.

### B08 — Regular practice opens standalone XP transaction inside parent transaction

**High · Rewards/pooling · Complexity: Small.** Affected: Practice final answer.

**Evidence:** [backend/src/modules/practice/services/practice-session.service.ts:402](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/practice/services/practice-session.service.ts:402), [backend/src/modules/practice/services/practice-session.service.ts:511](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/practice/services/practice-session.service.ts:511), [backend/src/modules/xp/xp.service.ts:62](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/xp/xp.service.ts:62).

**Observed:** awardXp is called without tx although the practice transaction still holds session/advisory locks. XP service supports a txClient and other competitive callers pass it.

**Impact and trigger:** XP may commit while final answer/session update rolls back; under pool saturation parents can hold all pool connections while waiting for nested awards. This is not fixed by merely enlarging the pool.

**Confidence:** Verified call boundary; pool exhaustion magnitude depends on limits/concurrency.

**Remedy:** Pass tx into centralized award; unify commit of answer/session/reward; rollback injection and pool-size 1 regression verification in isolated DB.

### B09 — Most routes parse 150MB bodies before authentication

**High · Resource exhaustion · Complexity: Small.** Affected: All HTTP except smaller Social parser.

**Evidence:** [backend/src/app.ts:18](/Users/shagunkumar/Desktop/aptiqu/backend/src/app.ts:18), [backend/src/modules/admin/routes/admin-books.routes.ts:27](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/routes/admin-books.routes.ts:27).

**Observed:** Global JSON/urlencoded 150mb parsers precede JWT/admin checks; Social has 80kb special parser. Large upload allowance is incorrectly also ordinary API parser policy.

**Impact and trigger:** Unauthenticated large bodies can allocate large buffers/objects and block JSON work on a single VPS; simultaneous requests amplify RAM/CPU. No attack traffic sent.

**Confidence:** Verified middleware ordering/limits; proxy upper limit unknown.

**Remedy:** Small global body budget, route-specific admin import limits after authentication; separate streamed PDF upload; bounded field/array sizes; consistent 413.

### B10 — HTTP/WS/AI budgets are incomplete and some are process-local

**High · Abuse prevention · Complexity: Medium.** Affected: 106 HTTP endpoints; PvP commands and generation paths.

**Evidence:** [backend/src/modules/admin/admin-auth.controller.ts:6](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin-auth.controller.ts:6), [backend/src/modules/pvp/ranked/ranked-rate-limit.ts:3](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/pvp/ranked/ranked-rate-limit.ts:3), [backend/src/modules/pvp/pvp.socket.ts:78](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/pvp/pvp.socket.ts:78), [backend/src/modules/practice/services/practice-selection.service.ts:76](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/practice/services/practice-selection.service.ts:76).

**Observed:** Only 10 HTTP operations have explicit limits. No general socket-message/in-flight/reconnect/pre-upgrade budget. Admin limiter Map unbounded; Ranked limits per process; auth/refresh and billable shortage paths lack shared account/provider budgets.

**Impact and trigger:** Flooding/content scraping/cost amplification and map growth; PM2 multiplies local allowances. IP-only protection can also lock out shared mobile networks, especially behind an unconfigured proxy.

**Confidence:** Verified control inventory; actual proxy/provider controls unknown.

**Remedy:** Shared operation/user limits with broad IP safety net, trusted proxy policy, bounded state, connection/byte/in-flight budgets, per-provider cost cap and clear Retry-After.

### B11 — Admin trust fallback and token validation are too broad

**Medium · Token/admin security · Complexity: Medium.** Affected: Admin auth; common JWT utility.

**Evidence:** [backend/src/modules/admin/admin.middleware.ts:12](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.middleware.ts:12), [backend/src/utils/jwt.ts:17](/Users/shagunkumar/Desktop/aptiqu/backend/src/utils/jwt.ts:17).

**Observed:** Admin verifier retries user access secret, accepts cast payload, tokens 24h; no issuer/audience/purpose/explicit algorithm profile or revocation. Common verifier also casts payload.

**Impact and trigger:** Compromise/misuse of user signing trust has admin implications if ADMIN payload issued; normal learner tokens lack ADMIN and are rejected. Stolen admin token long-lived; no verified escalation from an ordinary token.

**Confidence:** Verified checks; exploit conditions depend on signing-secret compromise/issuance mistake.

**Remedy:** Remove fallback; strong distinct keys; explicit issuer/audience/algorithm/payload purpose schema; bounded configurable expiry and revocation/version strategy for privileged sessions.

### B12 — Google email linking and account eligibility policy need tightening

**Medium · Identity policy · Complexity: Medium.** Affected: Google login/onboarding; learner middleware.

**Evidence:** [backend/src/utils/google.ts:27](/Users/shagunkumar/Desktop/aptiqu/backend/src/utils/google.ts:27), [backend/src/modules/auth/auth.service.ts:23](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/auth/auth.service.ts:23), [backend/src/middleware/auth.middleware.ts:27](/Users/shagunkumar/Desktop/aptiqu/backend/src/middleware/auth.middleware.ts:27).

**Observed:** SDK verifies configured audience; service links existing email to googleId without explicit verified-email/link-account policy. Common middleware lacks registered/deleted-session-state validation; Social/Ranked add it separately.

**Impact and trigger:** Unexpected linking/provider configuration or incomplete account access can diverge across features. No forged Google token or takeover was proven; empty OAuth config is a startup/config failure risk.

**Confidence:** Verified absence of local policy; upstream identity guarantees/runtime configuration require confirmation.

**Remedy:** Require reviewed verified identity/link policy, mandatory audiences when auth enabled, uniform eligibility where product requires it; keep subject as primary identity; avoid accidental email-based relinking.

### B13 — Refresh rotation/expiry and logout lifecycle are inconsistent

**Medium · Session reliability · Complexity: Medium.** Affected: Auth refresh/logout; token store.

**Evidence:** [backend/src/modules/auth/auth.service.ts:224](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/auth/auth.service.ts:224), [backend/src/utils/jwt.ts:25](/Users/shagunkumar/Desktop/aptiqu/backend/src/utils/jwt.ts:25), [backend/src/config/env.ts:17](/Users/shagunkumar/Desktop/aptiqu/backend/src/config/env.ts:17).

**Observed:** Delete old and create new tokens are separate writes. Both callers hardcode 7days; configured refresh expiry/secret unused. Logout deletes only supplied refresh hash; no expired-token maintenance found.

**Impact and trigger:** Failure between delete/create loses session; concurrent refresh can fail unexpectedly; expired tokens accumulate; access JWT and existing socket survive logout until separate expiry policy.

**Confidence:** Verified code; stateless access expiry after logout can be acceptable only as documented contract.

**Remedy:** Atomic one-time consume/rotation, session-family/replay policy and retry recovery; one opaque-token TTL; maintenance; decide bounded access revocation and socket invalidation.

### B14 — PvP socket never expires its authenticated JWT

**High · Realtime authentication · Complexity: Medium.** Affected: PvP query-token and AUTH_INIT sessions.

**Evidence:** [backend/src/modules/pvp/pvp.socket.ts:69](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/pvp/pvp.socket.ts:69), [backend/src/modules/pvp/pvp.socket.ts:92](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/pvp/pvp.socket.ts:92), [backend/src/modules/pvp/pvp.socket.ts:121](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/pvp/pvp.socket.ts:121), [backend/src/modules/social/social.socket.ts:32](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/social/social.socket.ts:32).

**Observed:** PvP verifies once and stores only userId; heartbeat only checks liveness. Social explicitly rechecks token and closes at expiry.

**Impact and trigger:** A connection opened with a short-lived/stolen token can continue commands indefinitely while alive, even after token expiry/logout/deletion unless a later service rejects the account.

**Confidence:** Verified missing expiry recheck; no live token used.

**Remedy:** Track token expiry/session identity; expire/re-authenticate connections, enforce session invalidation/account eligibility at privileged commands, prefer AUTH_INIT over query tokens.

### B15 — Admin destructive workflows conflict with historical and Ranked evidence

**High · Data retention/integrity · Complexity: Large.** Affected: Question/book/curriculum/user delete endpoints.

**Evidence:** [backend/src/modules/admin/admin-questions.service.ts:323](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin-questions.service.ts:323), [backend/src/modules/admin/controllers/admin-books.controller.ts:553](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/controllers/admin-books.controller.ts:553), [backend/src/modules/admin/controllers/admin-books.controller.ts:687](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/controllers/admin-books.controller.ts:687), [backend/src/modules/admin/admin-users.service.ts:166](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin-users.service.ts:166), [backend/prisma/changes/ranked-phase 2.sql:258](/Users/shagunkumar/Desktop/aptiqu/backend/prisma/changes/ranked-phase2.sql:258).

**Observed:** Question deletion erases attempts/set/deck references; book purge uses independent writes and 150ms cancellation wait, includes sourceBook title matching. User deletion claims cascades but Ranked relations RESTRICT and ledger/answer triggers prohibit changes.

**Impact and trigger:** Authorized mistaken delete can destroy legacy learning history or partially purge before a rated constraint rejects. Same-title source matching can widen scope; actual SQL guards installed unknown.

**Confidence:** Verified source/schema conflict; applied-trigger behavior requires DB evidence.

**Remedy:** Prefer archival; fence destructive endpoints; reviewed anonymization/retention for identities, historical snapshots/evidence preservation and transactional/batched resumable deletion with real owner stop acknowledgment.

### B16 — Privileged authoring paths enforce different contracts

**Medium · Validation/config integrity · Complexity: Large.** Affected: Admin syllabus/questions/books/timing.

**Evidence:** [backend/src/modules/admin/admin-syllabus.service.ts:190](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin-syllabus.service.ts:190), [backend/src/modules/admin/admin-syllabus.service.ts:447](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin-syllabus.service.ts:447), [backend/src/modules/admin/admin-syllabus.service.ts:589](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin-syllabus.service.ts:589), [backend/src/modules/admin/admin.controller.ts:45](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.controller.ts:45), [backend/src/modules/admin/controllers/admin-books.controller.ts:351](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/controllers/admin-books.controller.ts:351).

**Observed:** Prisma receives raw/spread request body in some updates; create/update/manual/import differ in graph/answer checks. Books topic/preview paths do not bind query/body IDs to book. Timing accepts any number, including negative; mutates live global settings.

**Impact and trigger:** Admin mistakes/compromised account can inject invalid hierarchy/content/options/nested writes or invalid gameplay duration. Role check means this is not ordinary-user mass assignment.

**Confidence:** Verified runtime-validation gaps.

**Remedy:** Strict boundary schemas and field allowlists; shared content validation/publish gate; bound parent ownership; validate timing ranges and persist versioned policy pinned to matches.

### B17 — Roadmap GETs perform global synchronization with unsafe local throttling

**High · Read-path reliability/performance · Complexity: Large.** Affected: Roadmap reads; lesson active/start; admin sync.

**Evidence:** [backend/src/modules/roadmap/services/roadmap-progression.service.ts:94](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/roadmap/services/roadmap-progression.service.ts:94), [backend/src/modules/roadmap/services/roadmap-progression.service.ts:312](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/roadmap/services/roadmap-progression.service.ts:312), [backend/src/modules/roadmap/services/roadmap-progression.service.ts:388](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/roadmap/services/roadmap-progression.service.ts:388), [backend/prisma/schema.prisma:911](/Users/shagunkumar/Desktop/aptiqu/backend/prisma/schema.prisma:911).

**Observed:** 4s lastSyncTime is process-local/global across roadmapIDs; set before work ends; errors swallowed. Nested full syllabus scan/writes; assignment find-then-create lacks unique identity.

**Impact and trigger:** Concurrent readers/workers can observe partial graphs, miss target roadmap sync, duplicate assignments or repeatedly do broad work. Expensive 100-user reading risk is static, not measured latency.

**Confidence:** Verified writes/race shape; query cost runtime-dependent.

**Remedy:** Move sync to publish-driven bounded durable task or explicit admin operation, unique assignment identity, single-owner/durable revisions, transactional readiness and projection-only GET.

### B18 — Book/cron/startup work relies on process-local singleton assumptions

**High · Job ownership · Complexity: Large.** Affected: Combined entry point; book upload/retry/cancel/delete.

**Evidence:** [backend/src/server.ts:29](/Users/shagunkumar/Desktop/aptiqu/backend/src/server.ts:29), [backend/src/server.ts:33](/Users/shagunkumar/Desktop/aptiqu/backend/src/server.ts:33), [backend/src/server.ts:76](/Users/shagunkumar/Desktop/aptiqu/backend/src/server.ts:76), [backend/src/queues/book-ingestion.queue.ts:280](/Users/shagunkumar/Desktop/aptiqu/backend/src/queues/book-ingestion.queue.ts:280), [backend/src/modules/admin/services/book-cancellation.service.ts:3](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/services/book-cancellation.service.ts:3).

**Observed:** Every server imports/starts workers, crons and startup import. concurrency 1 is per worker; timestamp/automatic job IDs allow same-book duplicate jobs. Cancellation local Set; no worker acknowledgment before purge.

**Impact and trigger:** PM2 copies/reload overlap multiply billable work and competing content mutations; cancel/delete can race a remote process or long in-flight AI call.

**Confidence:** Verified lifecycle and job identity; multi-process behavior inferred from process isolation.

**Remedy:** Explicit inert factories/roles, one scheduler/import owner, stable book/run/stage dedupe and durable cancellation/leases checked before writes; stop acknowledgment.

### B19 — Failed jobs and unavailable Daily start can look successful or misclassified

**Medium · Job failure contracts · Complexity: Medium.** Affected: Book/content queue; daily start/prewarm.

**Evidence:** [backend/src/queues/book-ingestion.queue.ts:240](/Users/shagunkumar/Desktop/aptiqu/backend/src/queues/book-ingestion.queue.ts:240), [backend/src/queues/book-ingestion.queue.ts:275](/Users/shagunkumar/Desktop/aptiqu/backend/src/queues/book-ingestion.queue.ts:275), [backend/src/queues/content-generation.queue.ts:90](/Users/shagunkumar/Desktop/aptiqu/backend/src/queues/content-generation.queue.ts:90), [backend/src/modules/ai/services/daily-challenge-generation.service.ts:295](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/ai/services/daily-challenge-generation.service.ts:295), [backend/src/modules/daily-challenge/daily-challenge.controller.ts:49](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/daily-challenge/daily-challenge.controller.ts:49).

**Observed:** Processors resolve false/unknown job names; prewarm swallows tier failures; removeOnComplete erases jobs. Daily preparing 503 thrown by service always serialized 400. Failed queue records retained forever elsewhere; untracked setImmediate sync.

**Impact and trigger:** Operator sees misleading completion; retry/alert behavior fails; clients do not get stable retryable preparing contract; Redis growth on retained failures.

**Confidence:** Verified control flow; BullMQ exception semantics confirmed by official docs.

**Remedy:** Throw typed Error for real failures, preserve explicit cancellation outcome and per-stage status, allowlist jobs, bounded retention/retry/backlog; preserve 503/code/Retry-After and track required async work.

### B20 — Delayed-job enqueue loss can strand friendly reservations

**Medium · Social recovery · Complexity: Medium.** Affected: Duel invite/accept and social worker.

**Evidence:** [backend/src/modules/social/duels.service.ts:64](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/social/duels.service.ts:64), [backend/src/modules/social/duels.service.ts:128](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/social/duels.service.ts:128), [backend/src/modules/social/duels.service.ts:20](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/social/duels.service.ts:20), [backend/src/modules/social/social.worker.ts:14](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/social/social.worker.ts:14).

**Observed:** DB commit precedes schedule; enqueue/cleanup errors swallowed; no startup/periodic sweep. Expiry also runs on get and selected invite paths, not all active seat lookups.

**Impact and trigger:** Redis/process failure after commit can leave expired pending/active seat blocking Ranked or new duel until the old duel is specifically read/expired; ordinary missed notifications alone do not corrupt DB.

**Confidence:** Verified recovery gap; schedule failures require outage/interruption.

**Remedy:** Bounded due-record reconciliation and startup repair, idempotent durable schedule/outbox only if needed; preserve conditional expiry/unique seat invariants.

### B21 — Queue Redis URL parsing discards security and routing options

**Medium · Redis configuration · Complexity: Small.** Affected: Book/content queues vs Social/lesson Redis.

**Evidence:** [backend/src/queues/book-ingestion.queue.ts:13](/Users/shagunkumar/Desktop/aptiqu/backend/src/queues/book-ingestion.queue.ts:13), [backend/src/queues/content-generation.queue.ts:6](/Users/shagunkumar/Desktop/aptiqu/backend/src/queues/content-generation.queue.ts:6).

**Observed:** Manual URL parsers copy host/port/password only; omit username/database/TLS and silently fallbacklocalhost on parse failure. Other integrations use complete ENV URL.

**Impact and trigger:** Configured rediss/ACL/nonzero-DB deployment may connect incorrectly, fail or use plaintext despite intended TLS. Actual deployment connection scheme unknown.

**Confidence:** Verified parser fields; concrete exposure depends on configuration.

**Remedy:** One validated full-URL ioredis/BullMQ connection factory; explicit TLS/ACL/DB support and fail-fast invalid URLs; test escaped credentials without logging them.

### B22 — Provider throttle and generation leases do not bound shared work

**Medium · AI cost/concurrency · Complexity: Medium.** Affected: Gemini; shortage generation; PvP admission.

**Evidence:** [backend/src/modules/ai/gemini.provider.ts:49](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/ai/gemini.provider.ts:49), [backend/src/modules/ai/gemini.provider.ts:99](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/ai/gemini.provider.ts:99), [backend/src/modules/ai/services/pvp-set-generation.service.ts:30](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/ai/services/pvp-set-generation.service.ts:30), [backend/src/modules/ai/services/question-generation.service.ts:66](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/ai/services/question-generation.service.ts:66), [backend/src/modules/concurrency/concurrency-lock.service.ts:19](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/concurrency/concurrency-lock.service.ts:19).

**Observed:** Timestamp throttle is not a queued mutex and not global. Promise.race timeout neither aborts external request nor clears timeout on success. Fixed generation lease may expire across generator/reviewer/retry chain; generic Redis outage falls back locally.

**Impact and trigger:** Concurrent callers/PM2 workers may burst provider usage, duplicate generation, retain timers or time out while billable request continues. A2.5s gap implies 24 starts/min, not comment 15/min.

**Confidence:** Verified code risk; provider behavior/actual quotas unmeasured.

**Remedy:** Shared provider concurrency/request/token budget, cancellation-capable SDK timeout, cleared timers, renewable token-owned leases or DB/job fences and generation off interactive paths.

### B23 — Published prompts/timing updates are inconsistent across processes

**Medium · Cross-process configuration · Complexity: Medium.** Affected: Admin prompt publish/config timing; AI consumers.

**Evidence:** [backend/src/modules/ai/services/ai-prompt.service.ts:264](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/ai/services/ai-prompt.service.ts:264), [backend/src/modules/ai/services/ai-prompt.service.ts:316](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/ai/services/ai-prompt.service.ts:316), [backend/src/modules/ai/services/ai-prompt.service.ts:433](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/ai/services/ai-prompt.service.ts:433), [backend/src/modules/admin/admin.controller.ts:100](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin.controller.ts:100).

**Observed:** Prompt cache has no TTL/version poll and only publisher process is refreshed; timing changes only local mutable object and disappears on restart. Prompt init is find-then-create with a local boolean.

**Impact and trigger:** Workers may use old templates indefinitely after published success; gameplay timing differs across workers/restarts; concurrent default initialization races.

**Confidence:** Verified local state; divergence conditional on multiple processes or restart.

**Remedy:** DB authoritative versioned prompt/config policy, bounded version refresh or Redis invalidation with expiry fallback, startup single-flight/upsert; snapshot gameplay policy rather than ENV mutable rules.

### B24 — Combined application is not safe for unchanged PM2 cluster

**High · PM2/realtime topology · Complexity: Large.** Affected: PvP matchmaking/broadcasts/reconnect/timers/recovery.

**Evidence:** [backend/src/modules/pvp/pvp.socket.ts:28](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/pvp/pvp.socket.ts:28), [backend/src/modules/pvp/pvp.socket.ts:338](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/pvp/pvp.socket.ts:338), [backend/src/modules/pvp/ranked/ranked-queue.ts:79](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/pvp/ranked/ranked-queue.ts:79), [backend/src/modules/pvp/ranked/ranked-worker.ts:5](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/pvp/ranked/ranked-worker.ts:5).

**Observed:** Local socket/match maps, connection replacement and timers; skill queue intentionally same-owner only; legacy global queue pops before checking local sockets; recovery runs per server.

**Impact and trigger:** Cluster partitions ranked matching, discards remote legacy pairs, duplicates scans/timers and has no global socket takeover. DB locking helps outcome integrity but cannot deliver to sockets in another process.

**Confidence:** Verified architecture; not a claim atomic DB settlement is absent.

**Remedy:** One PvP/recovery owner now; split HTTP-only/job roles before HTTP cluster; route WS path to owner; defer coordinated multi-owner PvP until measured need.

### B25 — Shutdown/readiness do not establish rolling-reload safety

**High · Lifecycle/deployment · Complexity: Large.** Affected: Server lifecycle; all jobs/sockets.

**Evidence:** [backend/src/server.ts:72](/Users/shagunkumar/Desktop/aptiqu/backend/src/server.ts:72), [backend/src/server.ts:81](/Users/shagunkumar/Desktop/aptiqu/backend/src/server.ts:81), [backend/src/app.ts:40](/Users/shagunkumar/Desktop/aptiqu/backend/src/app.ts:40), [backend/src/modules/pvp/pvp.socket.ts:132](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/pvp/pvp.socket.ts:132), [backend/src/modules/social/social.socket.ts:93](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/social/social.socket.ts:93).

**Observed:** Always-healthy endpoint; no ready handoff; post-listen catalog mutation; cron not stopped; social Redis closed before HTTP/worker drain; sockets close without full drain; no bounded single-entry shutdown; standalone Redis left until exit.

**Impact and trigger:** Accepted requests/jobs can fail mid-drain, supervisor timeout kill can interrupt long jobs, and PvP disconnects continue authoritative clocks. Rolling overlap repeats singleton side effects.

**Confidence:** Verified ordering; supervisor kill/readiness settings unknown.

**Remedy:** Role-specific readiness, drain flag, stop schedules/admission first, track accepted work, bounded shutdown with final cleanup, socket reconnect contract, compatible additive schema/version rollback.

### B26 — Pool configuration is not budgeted across roles/reloads

**Medium · Database capacity · Complexity: Small.** Affected: All Prisma consumers/PM2 planning.

**Evidence:** [backend/src/config/prisma.ts:3](/Users/shagunkumar/Desktop/aptiqu/backend/src/config/prisma.ts:3), [backend/prisma/schema.prisma:3](/Users/shagunkumar/Desktop/aptiqu/backend/prisma/schema.prisma:3), [backend/src/server.ts:19](/Users/shagunkumar/Desktop/aptiqu/backend/src/server.ts:19).

**Observed:** One shared PrismaClient/process is good; no enforced/documented per-role pool budget or reload-overlap sizing. DATABASE_URL contents not inspected; actual limit may already be set.

**Impact and trigger:** Multiple pools can overcommit local PG connections/RAM or leave parents waiting; more cores/processes do not imply unlimited query parallelism.

**Confidence:** Verified source configuration boundary; actual exhaustion unverified.

**Remedy:** Use measured PG usable budget and role-specific connection_limit/pool_timeout with overlap; address nested tx first; PgBouncer only if evidence justifies.

### B27 — Frequent personal/profile endpoints repeat historical/catalog work

**Medium · Read efficiency · Complexity: Medium.** Affected: User Home/Profile/Stats/Achievements, Social profile, histories.

**Evidence:** [backend/src/modules/home/home.service.ts:13](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/home/home.service.ts:13), [backend/src/modules/user/user.service.ts:80](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/user/user.service.ts:80), [backend/src/modules/social/friends.service.ts:66](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/social/friends.service.ts:66), [backend/src/modules/daily-challenge/daily-challenge.service.ts:726](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/daily-challenge/daily-challenge.service.ts:726).

**Observed:** Lifetime source aggregates repeated per navigation/page; Social profile invokes broad Home; stats cold cache fetches all published definitions; Daily average fetches every completed row.

**Impact and trigger:** Historical growth × frequent access can increase DB CPU/serialization/heap on one VPS. Source complexity is not a measured slow API.

**Confidence:** Verified work shapes; latency/load requires staging.

**Remedy:** Narrow projections/SQL aggregates/shared observation service, coalescing and conditional private short TTL after correctness; durable rollups only with measured need.

### B28 — Legacy statistics conflate node identities and reporting contracts

**Medium · Metrics consistency · Complexity: Medium.** Affected: User stats, Home history dimensions, admin demographics/dates.

**Evidence:** [backend/src/modules/user/user.service.ts:117](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/user/user.service.ts:117), [backend/src/modules/user/user.service.ts:217](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/user/user.service.ts:217), [backend/src/modules/home/home.queries.ts:49](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/home/home.queries.ts:49), [backend/src/modules/admin/admin-users.service.ts:109](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin-users.service.ts:109), [backend/src/modules/admin/admin-dashboard.service.ts:10](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin-dashboard.service.ts:10).

**Observed:** Node map keyed only nodeId across scripts; repository-reference node is both solved DB question and mapped node; SQL distinct node lacks script identity. Home PvP difficulty joins mutable current question instead of snapshot. Dashboard uses UTC/host dates versus IST; gender grouping misses Non-Binary; demographic maps use plain objects.

**Impact and trigger:** Counts can double-count or merge unrelated questions; historical difficulty changes after edit; reports disagree around midnight and categories. Not all differences are wrong: Home attempted vs profile unique-solved are different concepts and should be labeled.

**Confidence:** Verified identity/category/date code; representative fixture comparison needed.

**Remedy:** Canonical identity(source/script/version/node or question), avoid repository duplicate count, intentional metric definitions, snapshot-consistent history, shared IST bucket helper and safe GROUP BY/Map.

### B29 — Admin analytics and catalog reads overfetch or repeat many queries

**Medium · Admin efficiency · Complexity: Medium.** Affected: Admin dashboard/achievements/users/syllabus/book status.

**Evidence:** [backend/src/modules/admin/admin-dashboard.service.ts:89](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin-dashboard.service.ts:89), [backend/src/modules/achievements/achievement.analytics.ts:10](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/achievements/achievement.analytics.ts:10), [backend/src/modules/admin/admin-users.service.ts:99](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin-users.service.ts:99), [backend/src/modules/admin/controllers/admin-books.controller.ts:192](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/controllers/admin-books.controller.ts:192).

**Observed:** At least 74 time-bucket counts before overview work; global answer distributions before achievement page; full demographic rows and all job history/tree loads. Existing achievement distribution avoids Cartesian blowup, but not history scan.

**Impact and trigger:** Polling/admin navigation competes with live learner PG workload; high cost even with small HTTP response; no runtime latency measured.

**Confidence:** Verified static query counts/shapes.

**Remedy:** Set-based grouped buckets/DB demographics, latest-job projections, bounded catalog paging and admin-only short snapshots where justified; avoid unbounded Promise.all fanout.

### B30 — Question selection and live ranking need plan-guided tuning

**Medium · Query/index performance · Complexity: Medium.** Affected: Practice/PvP set admission, Ranked leaderboard.

**Evidence:** [backend/src/modules/practice/services/practice-selection.service.ts:28](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/practice/services/practice-selection.service.ts:28), [backend/src/modules/pvp/services/pvp-match.service.ts:157](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/pvp/services/pvp-match.service.ts:157), [backend/src/modules/pvp/ranked/ranked-queries.ts:10](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/pvp/ranked/ranked-queries.ts:10), [backend/prisma/schema.prisma:401](/Users/shagunkumar/Desktop/aptiqu/backend/prisma/schema.prisma:401).

**Observed:** Random sort plus anti-probes; question composite index interposes sourceType; no PvP(user,question) anti-probe index. Live board computes higher-ranked count per page row. Prepared qualified-order partial index already exists as SQL source.

**Impact and trigger:** Large eligible pools/history/seasons can raise CPU/buffers and delay admissions/board reads; no benchmark/explain provided.

**Confidence:** Verified query/index source; optimizer cost/in-use index unknown.

**Remedy:** Verify deployed indexes, authorized EXPLAIN; targeted IX01/02/07 and query rewrite; preserve selection fairness/rank/tie behavior; measure write/storage overhead.

### B31 — Leading-wildcard learner search bypasses current prefix index

**Medium · Search efficiency · Complexity: Medium.** Affected: Social search.

**Evidence:** [backend/src/modules/social/friend-search.ts:8](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/social/friend-search.ts:8), [backend/prisma/schema.prisma:88](/Users/shagunkumar/Desktop/aptiqu/backend/prisma/schema.prisma:88).

**Observed:** Query matches %term% across name or lower(email), sorts relevance and limits 10; prefix text_pattern_ops index does not satisfy arbitrary contains; min query can be1 char.

**Impact and trigger:** High user count and frequent short search can scan/sort many rows despite a bounded response.60/min Redis limit limits requests, not query cost.

**Confidence:** Verified predicate/index mismatch; plan/runtime unknown.

**Remedy:** Choose prefix/name and exact email semantics first; if substring needed, measured pg_trgm indexes/min query length, debounce contract and bounded scan budget.

### B32 — Social discoverability and presence checks are inconsistent

**Medium · Privacy/authorization policy · Complexity: Medium.** Affected: Social search/profile/activity; watched presence.

**Evidence:** [backend/src/modules/social/friends.service.ts:62](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/social/friends.service.ts:62), [backend/src/modules/social/social.routes.ts:30](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/social/social.routes.ts:30), [backend/src/modules/social/social.socket.ts:65](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/social/social.socket.ts:65), [backend/src/modules/social/social.socket.ts:42](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/social/social.socket.ts:42).

**Observed:** Any registered caller can view target profile, coins/performance/month activity and presence; list/search presence restricts to accepted friends. Email substring contributes discovery though email not serialized. Watched friend list checked once, not renewed after relationship removal.

**Impact and trigger:** User behavior/presence may be exposed beyond expectation; email-match inference; stale watcher can retain presence after unfriend. Product public-profile policy is not documented here, so broad profile access alone is not automatically IDOR.

**Confidence:** Verified inconsistent policy; intended profile visibility requires product decision.

**Remedy:** Define public vs friend-only fields, bind activity/presence authorization in services, exact-email discovery policy; revalidate watch membership or invalidate on relation change before cache.

### B33 — Script cache still hydrates all question references and has stale/lock gaps

**Medium · Cache correctness · Complexity: Medium.** Affected: Lesson active/get/action and admin edits.

**Evidence:** [backend/src/modules/lesson/services/script-cache.service.ts:153](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/lesson/services/script-cache.service.ts:153), [backend/src/modules/lesson/services/question-hydration.service.ts:47](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/lesson/services/question-hydration.service.ts:47), [backend/src/modules/admin/admin-questions.service.ts:229](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/admin-questions.service.ts:229).

**Observed:** Definition cache hits normalize and hydrate whole definition from DB again. Load lock expires 2s, non-owner also proceeds then DEL; question edits lack universal dependent-cache invalidation. Cached slug resolves without current publication gate.

**Impact and trigger:** Cache does not eliminate recurring hydration; mixed frozen version/current question data and stale publication can produce inconsistent lessons. Publication security is B01; this item covers efficiency/freshness.

**Confidence:** Verified code; actual hit/race frequency unmeasured.

**Remedy:** Internal immutable hydrated version or explicit question revision contract; authorization before reuse; safe single-flight/owner-token lock; reverse dependency/revision invalidation.

### B34 — Generic errors/logs and response headers expose unnecessary detail

**Medium · Error/log/cache privacy · Complexity: Medium.** Affected: App/auth/admin/most private HTTP.

**Evidence:** [backend/src/app.ts:23](/Users/shagunkumar/Desktop/aptiqu/backend/src/app.ts:23), [backend/src/app.ts:69](/Users/shagunkumar/Desktop/aptiqu/backend/src/app.ts:69), [backend/src/modules/auth/auth.controller.ts:32](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/auth/auth.controller.ts:32), [backend/src/modules/ai/gemini.provider.ts:138](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/ai/gemini.provider.ts:138), [backend/src/modules/pvp/pvp.controller.ts:22](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/pvp/pvp.controller.ts:22).

**Observed:** Logger records originalUrl; many catches serialize err.message/raw code and log whole error; AI parse error includes output preview. Ranked explicitly private/no-store; most auth/private/admin responses have no cache policy; no app security headers.

**Impact and trigger:** Internal paths/SQL/content snippets/URL query identifiers may leak; token URL handshake may be logged upstream (not by Express HTTP logger). Missing Cache-Control is hardening, not proof a shared proxy cached private bodies.

**Confidence:** Verified source outputs; actual log/proxy exposure unknown.

**Remedy:** Typed public error mapping; structured redacted route logs/admin actor audit; no-store sensitive responses; deliberate security headers/CORS/origin/trust proxy with TLS deployment verification.

### B35 — README db-push workflow contradicts Ranked SQL requirements

**Medium · Schema/release compatibility · Complexity: Medium.** Affected: Backend deployment instructions/schema.

**Evidence:** [backend/README.md:3](/Users/shagunkumar/Desktop/aptiqu/backend/README.md:3), [backend/prisma/changes/README.md:5](/Users/shagunkumar/Desktop/aptiqu/backend/prisma/changes/README.md:5), [backend/prisma/changes/ranked-phase 2.sql:206](/Users/shagunkumar/Desktop/aptiqu/backend/prisma/changes/ranked-phase2.sql:206).

**Observed:** Main README recommends db push and historical destructive cleanup; Ranked README says prepared additive SQL is required and Prisma cannot represent critical triggers/indexes. No migration baseline; actual target state not inspected.

**Impact and trigger:** An operator may deploy code without constraints/indexes or execute stale cleanup; old/new versions and account deletion assumptions incompatible. Not evidence SQL is missing on actual VPS.

**Confidence:** Verified documentation/source conflict; deployment status unverified.

**Remedy:** One explicit additive reviewed schema/release runbook, catalog verification and disposable DB integration prerequisite; preserve ledger policies during rollback; no production changes in audit.

### B36 — Operational isolation, resource bounds and restore evidence are incomplete

**Medium · Operations/resource recovery · Complexity: Medium.** Affected: PDF/storage/server diagnostics/deployment.

**Evidence:** [backend/src/modules/admin/services/pdf-parser.service.ts:182](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/services/pdf-parser.service.ts:182), [backend/src/modules/admin/services/book-storage.service.ts:168](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/services/book-storage.service.ts:168), [backend/src/modules/admin/controllers/admin-books.controller.ts:21](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/controllers/admin-books.controller.ts:21), [backend/src/server.ts:81](/Users/shagunkumar/Desktop/aptiqu/backend/src/server.ts:81).

**Observed:** PDF fully read and synchronous writes/copy share process; invalid title after upload leaves file; no checked-in storage quota/temp sweeper/log/backup/monitoring/least-privilege runbook. Production controls were not accessed.

**Impact and trigger:** Large trusted-admin files can disrupt games, disk/failed jobs/logs grow and recovery is unproven. Missing repository evidence is not proof backups/firewalls do not exist.

**Confidence:** Verified local resource behavior; production posture requires confirmation.

**Remedy:** Separate bounded worker, async IO/page expansion/temp cleanup/disk quotas, minimal metrics/rotation/alerts and independently verified encrypted backup+restore/private network/roles/file modes.

### B37 — ENV schema and hardcoded operational settings are inconsistent

**Medium · Environment/configuration · Complexity: Medium.** Affected: env loader/template; runtime flags/storage/provider limits.

**Evidence:** [backend/src/config/env.ts:12](/Users/shagunkumar/Desktop/aptiqu/backend/src/config/env.ts:12), [backend/.env.example:1](/Users/shagunkumar/Desktop/aptiqu/backend/.env.example:1), [backend/src/modules/ai/gemini.provider.ts:77](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/ai/gemini.provider.ts:77), [backend/src/modules/pvp/ranked/ranked-matchmaking-policy.ts:12](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/pvp/ranked/ranked-matchmaking-policy.ts:12).

**Observed:** Loader only checks nonempty core secrets; PORT/budgets parse without safe bounds. Ranked accesses env elsewhere; template omits keys. thinkingBudget 0 is overridden via ||. Storage roots/roles/body caps/admin expiry operational settings embedded.

**Impact and trigger:** Misconfiguration can fail open/degrade/retry unexpectedly or prevent intended deployment; secrets already in ENV, so do not invent a leaked-key finding.

**Confidence:** Verified config usage/template names; .env values not read.

**Remedy:** Central typed validation and documented bounded operational ENV; meaningful feature requirements/distinct strong keys; remove dead refresh key; keep business policy/data out of ENV.

### B38 — AI records report a hardcoded model/prompt version

**Low · Provenance/maintainability · Complexity: Small.** Affected: Question and PvP generation.

**Evidence:** [backend/src/modules/ai/services/question-generation.service.ts:199](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/ai/services/question-generation.service.ts:199), [backend/src/modules/ai/services/pvp-set-generation.service.ts:195](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/ai/services/pvp-set-generation.service.ts:195), [backend/src/modules/ai/services/pvp-set-generation.service.ts:230](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/ai/services/pvp-set-generation.service.ts:230), [backend/src/modules/ai/gemini.provider.ts:82](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/ai/gemini.provider.ts:82).

**Observed:** Actual model chosen from ENV but generationModel and prompt version stored as fixed strings even when published prompt/version differs.

**Impact and trigger:** Operators cannot reliably trace which model/prompt produced disputed educational content after configuration changes.

**Confidence:** Verified source mismatch; no model call executed.

**Remedy:** Return provider execution metadata and persist resolved model plus published prompt id/version/checksum; do not add a second independent provenance ENV variable.

### B39 — Default test command can write DB; key regression coverage unproven

**Low · Verification/tooling · Complexity: Small.** Affected: package scripts/test suites/dependency policy.

**Evidence:** [backend/package.json:13](/Users/shagunkumar/Desktop/aptiqu/backend/package.json:13), [backend/src/modules/roadmap/tests/roadmap-progression.test.ts:28](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/roadmap/tests/roadmap-progression.test.ts:28), [backend/src/modules/pvp/tests/ranked-postgres.integration.cjs:1](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/pvp/tests/ranked-postgres.integration.cjs:1).

**Observed:** npm test runs a roadmap script creating users through ordinary Prisma/env; other tests mix mocks and DB work. Ranked integrations explicitly opt in. No auth/lesson security regression gate or current dependency vulnerability report established.

**Impact and trigger:** A future reviewer may run default tests against unintended DB; typecheck/mock passes do not prove real lock/SQL/dependency safety.

**Confidence:** Verified test entry points; suites not run in this audit.

**Remedy:** Separate inert tests from explicit isolated-service integrations, explicit URL/allow guards, regression cases from findings, pinned supported runtime/lockfile vulnerability checks with no application install scripts.

### B40 — Private source PDFs and page JSON are tracked in backend storage

**Medium · Artifact/content confidentiality · Complexity: Small.** Affected: backend release/repository/storage boundary.

**Evidence:** [backend/storage/books](/Users/shagunkumar/Desktop/aptiqu/backend/storage/books), [backend/src/modules/admin/services/book-storage.service.ts:14](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/admin/services/book-storage.service.ts:14), [.gitignore:1](/Users/shagunkumar/Desktop/aptiqu/.gitignore:1).

**Observed:** Git index contains six original.pdf and six page_0001.json files under backend/storage; storage defaults inside CWD. No Express static mount exists.

**Impact and trigger:** Repository/release sharing includes these copies; wildcard proxy/static publishing or public repository could expose source content. Repository visibility/proxy roots/backups were not inspected.

**Confidence:** Verified tracked paths; public exposure conditional/unverified.

**Remedy:** Move runtime storage outside code/release root, artifact allowlist and ignore rules; authorized review of retained copies/history if needed; private file serving/backups; do not blindly delete source material.

### B41 — Lesson sanitizer retains supported solution-bearing feedback and variations

**High · Answer confidentiality · Complexity: Medium.** Affected: lesson active/get/start/action/history DTOs, including the roadmap start alias.

**Evidence:** [sanitizeNode](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/lesson/services/lesson-session.service.ts:28), [QuestionInlineData and QuestionVariation](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/lesson/interfaces/script-dsl.interface.ts:24), [incorrect-answer evaluation](/Users/shagunkumar/Desktop/aptiqu/backend/src/modules/lesson/services/question.service.ts:30).

**Observed:** Sanitization deep-clones the complete node and deletes a short list of top-level inline solution fields. It does not remove `incorrectExplanation` or `variations`. The supported `variations` schema includes each variation's `correctOptionId` and `explanation`; `incorrectExplanation` is intended post-answer feedback and may state the answer. These fields survive before submission. The inspected seed JSON has no examples of these two fields, so live affected-row prevalence is unknown; the serializer gap is verified in source.

**Impact and trigger:** A normal learner receiving a published inline node with these supported fields can obtain solution-bearing feedback or variation answer keys before the authorized attempt. No catalog-wide/public exposure is implied, and arbitrary explanatory text needs content-aware policy rather than a misleading guarantee of automatic semantic redaction.

**Confidence:** Verified schema/serializer behavior; stored content prevalence and exact answer content require authorized data evidence. No live session was accessed.

**Remedy:** Replace deletion-based serialization with a recursive allowlist of current public question fields; keep all solution-bearing feedback/variation data server-side until its specific reveal is authorized. Scope each variation as a separate server-selected question, never send its full private object. Add recursive DTO regression fixtures across every successful/reached-history path.

## 20. Unknowns and exact safe follow-up verification

These are verification requests for a future **separately authorized** task, not permission to perform them now.

| Unknown | Safe evidence/procedure to request | Decision it changes |
|---|---|---|
| Deployed schema/native Ranked constraints | Read-only catalog export of constraints/indexes/triggers, sanitized schema version; compare to prepared SQL, then separately authorized isolated DB race suite | Whether durable rating/answer guarantees are actually enforced; release prerequisites B35 |
| Query plans/cardinality | Sanitized counts/histograms and authorized staging EXPLAIN (ANALYZE, BUFFERS) for **SELECT-only** query shapes, with statement timeout and representative synthetic data | IX01–IX08, caching justification and query rewrites; ANALYZE executes the query, so never aim it at mutation SQL casually |
| VPS sizing/runtime topology | Sanitized CPU/RAM/disk/Node/PG/Redis/PM2 versions, process counts and limits; no secrets/env dump | Role allocation, pool/RAM budgets, provider concurrency and shutdown deadline |
| Pool URLs/connections | Credential-redacted pool parameters, max_connections/reserves and aggregated active/waiting connections; no database access in this audit | Whether actual pool is already tuned or overcommitted |
| Proxy/TLS/network/permissions | Sanitized proxy listeners/location roots, trusted hops, body/timeout/WS policies, firewall/listener/DB-role/Redis-ACL/file-mode evidence | B09/B10/B21/B34/B36/B40 deployment risk; do not infer it from localhost log text |
| Credential lifecycle | Confirm key lengths/distinctness, ENV provisioning/rotation/revocation process without revealing values; authorized secret scan in private CI/repository history if needed | Key separation, blast radius and whether rotation is required; no confirmed embedded secret means no blind rotation requirement |
| Real locking/recovery | Explicit isolated disposable PG/Redis test environments and allow flags; run guarded integrations plus new Daily/lesson/practice/friendly regressions | Runtime atomicity/deadlock/lease/reload claims; no tests against DATABASE_URL by default |
| Traffic/cost/caching | Coarse route frequency/p95, history size, provider request/token budgets, current allowed study behavior | Tune proposed rates/TTLs and decide if more HTTP workers/cache/rollups justified |
| Dependency security | Fresh advisory scan of the locked tree with vetted official advisories; supported runtime matrix; no package install required for report | Security patch priorities; cannot declare dependency tree clean from old lockfile alone |
| Content delivery/privacy | Product decision for discoverable profile/presence/email search, published-topic free choice, prefetch/offline units; separate client packaging manifest audit | B03/B04/B32 contract and safe private-cache dimensions |
| Backups/reload/rollback | Restore drill evidence in isolated target, encrypted off-machine retention/recovery objectives; authorized staging reload/drain test with real WS clients | Honest recovery/reload promise; one VPS still lacks server-failure HA |

**Checks actually performed:** static mount/controller/service/DTO/schema/SQL/config/test/operational-document inspection; route resolution/count cross-check; redacted literal-pattern scan and tracked-file inventory; local `backend/node_modules/.bin/tsc --noEmit --project backend/tsconfig.json` passed. No packages installed, npm test/DB/Redis integrations run, services started, secrets opened, migrations executed, VPS connected, traffic generated, AI called or deployment changed. This audit is not a live security clearance. Only the two requested documents are task outputs.
