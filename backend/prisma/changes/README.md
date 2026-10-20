# Ranked Phase 2 database change preparation

**Historical change preparation.** Local hardening verification subsequently installed the supplemental guards in dedicated disposable fixtures. No VPS/remote database was contacted or verified. The Stage 3 bootstrap checks required guard metadata; it does not execute this SQL or prove full definition drift.

This repository uses a manual schema workflow and has no Prisma migration baseline. `ranked-phase2.sql` is an additive, single-transaction change generated offline from the pre-Phase-2 schema, followed by reviewed supplemental constraints/indexes/triggers. It is not an automatically applicable migration and is deliberately outside `prisma/migrations`.

Before any separately authorized execution:

1. Inspect the actual target schema against the repository baseline. Resolve drift in a reviewed change; do not blindly run this file on a partially upgraded database. Take the normal recoverable backup. The SQL is intentionally not rerunnable.
2. Audit legacy answer/participant orphans, question-set validity, duplicate seats and unresolved active matches. The script aborts on orphan answers; it does not delete or repair historical rows. Existing matches receive `LEGACY_UNRATED` with a null season. No old ratings or XP are reconstructed.
3. Apply/test the reviewed SQL on an explicitly authorized disposable PostgreSQL database first. Do not use the historical destructive cleanup example in the backend README. Do not replace this file with `prisma db push`: Prisma does not represent its CHECKs, exclusion, partial indexes and deferred/immutability triggers.
4. Run the opt-in integration suite below, review actual locking, rollback and archive SQL behavior, then authorize the production change separately. New backend code requires the additive schema even when rated admission is off. Apply schema before switching the backend version; keep one PvP WebSocket host for v1.
5. Only after DB verification/release approval, configure `RANKED_ADMISSION_ENABLED=true`, `RANKED_LEAGUES_READ_ENABLED=true`, `RANKED_SKILL_MATCHMAKING_ENABLED=true` and an explicit `RANKED_LAUNCH_SEASON=YYYY-MM`, with compatible clients and verified Redis queue availability. The default is off. Future launch months keep admission unrated until their start. No launch date was selected or enabled here. Runtime maintenance creates the approved `ranked-v1` policy and launch-through-current-plus-two months; it lazily creates player rows at actual rated admission.

Do not change the OS, Node process, database or session timezone: all remain **UTC**. Season boundaries are explicit `Asia/Kolkata` monthly instants stored as `timestamptz(3)`. Existing timestamp-without-time-zone columns remain UTC by convention and are not reinterpreted or rewritten.

## Policy and operational behavior

The user approved the Phase 1 numeric defaults, monthly rating carry and system-failure voids in the Phase 2 conversation. The immutable config includes K64 before 20 lifetime games/K32 afterward; seed 1200; initial/monthly qualification 10/3; Silver 1000, Gold 1200, Platinum 1450, Diamond 1700; half-away-from-zero integer rounding; no floor or extra bonuses. Each season pins its policy. New policy versions require reviewed source changes and a new ID/config; no policy-edit endpoint exists. `approved_at` records installation of the approved policy, not a fabricated exact time of the user's reply.

A normal match retains its ready/60-second/3-second transition deadlines. Recovery first closes due rounds and settles recoverable final-round evidence. A 15-minute hard admission expiry bounds unrecoverable unfinished games; those become `CANCELLED/SYSTEM_VOID` with a VOID settlement, zero Elo and zero XP. Ordinary disconnects continue timed gameplay. Equal score/time still draws. Temporary DB/XP failures are retried rather than guessed as losses or converted into voids when complete valid evidence exists.

Disabling admission never disables settlement/recovery/archival for already admitted rated matches. A rollback must retain these obligations; do not downgrade to code that ignores them. No destructive down script is provided. Completed pre-upgrade history stays unchanged and has no synthetic ledger header. Legacy in-flight matches are recovered unrated and may receive a terminal legacy/void header when actually resolved.

The shared competitive mutex uses ordered `FOR NO KEY UPDATE` on users, then the match, season share lock, ordered standings, ordered XP progress and stats. The season finalizer takes the season update lock and writes standings, without taking user locks. It waits for every assigned match's terminal disposition and atomically freezes final positions/counts/ratings/qualified peaks/leagues. Phase 2 introduces no rewards or live leaderboard API; Phase 3 supplies the read APIs described below.

The recovery worker scans at most 100 due IDs per tick with a keyset cursor, runs without overlapping itself, and reconciles seasons once per minute. Timers/socket maps are routing caches. Delivery remains recoverable through authenticated existing GET/reconnect; there is no distributed socket routing. Phase 3 adds a versioned Redis queue separately from this database change. A missed completion send cannot undo a committed settlement.

Audit relationships use RESTRICT and immutable policy/header/ledger triggers. The admin API includes destructive user deletion; it can conflict with these restrictions. Its redesign is explicitly excluded from backend hardening, and a future erasure workflow must reconcile anonymization/retention deliberately. Do not bypass them with a new cascade. This is a rollout review item, not authorization to erase data.

## Opt-in PostgreSQL verification

`npm run test:pvp:postgres` **skips by default** and never falls back to `DATABASE_URL` or loads `.env`. To run after separate DB authorization, supply all of:

- `RANKED_ALLOW_DATABASE_TESTS=true`
- `RANKED_TEST_DATABASE_URL` pointing to an isolated local database named `aptiqu_ranked_test` or `aptiqu_ranked_test_<suffix>`
- `RANKED_TEST_SET_ID` identifying a seeded valid ten-question set in that disposable DB

The existing baseline and reviewed Phase 2 SQL must already be present. The suite performs real data writes, uses two independent clients for same-match races, injects post-XP failure, reconstructs a service after a simulated restart, and verifies actual PostgreSQL constraints and archive SQL. It creates uniquely identified test users/matches, retains audit evidence, and performs no DDL, migration, destructive reset, or automatic cleanup. Use a fresh disposable DB for each run and remove that DB only under its separately authorized setup/teardown workflow. Some archival fixture rows are intentionally test-created rather than produced by a full month of gameplay.

Passing the default in-memory tests or Prisma validation is **not** evidence that this PostgreSQL suite passed. Actual SQL deployment, concurrency/locking and rollout remain unverified until the opt-in suite is authorized and run.

## Phase 3 source and activation prerequisites

Phase 3 adds no SQL/schema changes. It depends on the unapplied additive Phase 2 change above, even while admission is disabled. Implemented routes, cache/cursor behavior, client capability gating, queue leases and configurable windows are documented in `docs/RANKED_LEAGUES_PHASE_3_API.md` from the repository root.

Reads and skill matchmaking default off. `RANKED_ADMISSION_DRAIN=true` pauses new search/admission while settlement/recovery/archive continue. Keep the VPS/process/database/session timezones UTC. Set a separately managed `RANKED_CURSOR_SECRET` of at least 32 characters (or the existing `JWT_ACCESS_SECRET` fallback). No secret, flag or launch month was changed by this implementation.

The opt-in PostgreSQL suite additionally prepares actual live-board SQL ordinal/page movement, finalized board/history reads and admission commit-acknowledgement recovery. It still requires the separately authorized prepared disposable DB and content fixture above. Before activation, also review EXPLAIN/query latency for bounded live page plus correlated ordinal counts; no measurements have been taken.

### Opt-in Redis verification

`npm run test:pvp:redis` skips unless separately authorized and supplied with both:

- `RANKED_ALLOW_REDIS_TESTS=true`
- `RANKED_TEST_REDIS_URL` targeting an already available isolated local Redis database index **10–15**

There is no fallback to ordinary `REDIS_URL`, no server setup and no `FLUSHDB`/`FLUSHALL`. The suite uses random namespaced keys and deletes only its own four keys afterward. It checks actual Lua duplicate JOIN age, stale cancellation ownership, symmetric first-minute widening, foreign-process fencing, competing claims, claim-winning cancellation, renewal, safe cleanup and expiry beyond a bounded pruning backlog. Runtime v1 still requires one PvP WebSocket host; process fencing does not supply cross-host routing.

Both optional suites were explicitly run in **skip mode**, with their allow flags forced false. Their syntax/default skip behavior passed; actual PostgreSQL operations, Redis Lua compilation/execution and failure/concurrency evidence remain outstanding. Inert unit tests and TypeScript builds do not replace those checks. No local service, VPS connection, migration or deployment was performed.
