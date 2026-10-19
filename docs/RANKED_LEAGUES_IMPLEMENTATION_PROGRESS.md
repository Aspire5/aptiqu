# Ranked Leagues implementation progress

Updated 20 October 2026 (IST). **Phases 1–4 source work is complete. Phase 4 is ready for manual review. Actual PostgreSQL/Redis integration, native-device verification and rollout remain outstanding under the recorded environment/release boundaries.**

| Phase | Scope | Status |
|---|---|---|
| 1 | PvP integrity, pure Elo/qualification/league rules and IST calendar | Completed; foundation retained |
| 2 | Database models/constraints, seasons/history, atomic Elo + XP, durable restart recovery | Authorized source work completed; DB application/integration pending separate authorization |
| 3 | Ranked APIs, seasonal global positions/leaderboards, Elo-aware matchmaking | Authorized source work and focused verification complete; real SQL/Lua verification pending separate authorization |
| 4 | League badges/screens, animations, final integration/release checklist | Authorized Flutter source, fixture integration/renders and local build complete; manual review/live integration pending, no release |

## Phase 4 implemented

- Added typed Ranked models/repository, the six supplied badge mappings and explicit asset registration. Home's existing Ranked region and own Profile consume optional league summaries while retaining the legacy Home response fallback, identity/Appearance placement and separate XP fields.
- Connected lobby standing/resume/pending-result behavior, capability 1, server widening/PAIRING/cancel state, paged Elo/void history and accurate score/time rules. Added guarded leaderboard/month/history routes, own-standing strip, live-page dedup/cursor resets, closing/finalized results and owner/season/request fences. A read outage does not disable healthy backend admission.
- Added committed own Elo/qualification/result presentation, stable event/version handling and a finite inline promotion/placement reveal. Secure cosmetic receipts precede motion; old-month/history/duplicate events do not replay it. Demotion is neutral; background/reduced-motion states settle immediately. Existing XP/recovery/terminal-void behavior and live-match exit policy are preserved.
- Verified **38 new Phase 4 cases**, **106 combined affected-screen tests**, and **27 existing Ranked regression cases** (the runs overlap six Phase 1 cases). Flutter analysis and debug APK build pass. Saved **24 actual fixture PNGs** with decoded artwork in Light/Dark and representative 2× text/long-name layouts. The Home compatibility golden passes unchanged. See [Phase 4 handoff](RANKED_LEAGUES_PHASE_4_HANDOFF.md) and [render index](ranked_phase4/README.md) for precise coverage and manual review steps.
- No backend/DB/environment flag, launch month, deployment or UTC timezone change was made in Phase 4. The user's login screen/tests/artwork and unrelated icon/config edits were preserved; `pubspec.yaml` only gained the Ranked asset directory alongside their existing login registration. Real SQL/Lua/query-plan/load/native-device evidence remains uncollected.

## Phase 3 implemented

- Added authenticated, registration-gated `/ranked/me`, `/ranked/leaderboard`, and `/ranked/seasons` endpoints under `/api/v1/pvp`. Own summary includes current/selected-month qualification, lifetime provisional state, effective seed, exact live ordinal, qualified peak, next tier, active/pending match across months, last final season and capabilities. Read previews create no rows. Public boards contain qualified profiles only; finalized results use frozen archive fields.
- Added parameterized bounded keyset SQL with deterministic rating-descending/UUID-ascending order. Live page ordinals count against the whole eligible season in the same snapshot, independently of the cursor's old ordinal. Signed five-minute cursors pin policy/month/live-final mode and reset safely. Query plans/latency are unmeasured because SQL execution is restricted.
- Added bounded five-second owner/top-page caches, fresh bypass, single-flight invalidation and month-boundary expiry that consumes query latency. Added strict query bounds, safe errors and per-owner read/search rate limits. Home/Profile gain an isolated optional `rankedLeague` section while preserving existing fields.
- Extended owner match history with season/disposition/stable Elo event/version data and opt-in `includeVoids=1`. Existing completed-only pagination remains compatible. Reconnect/results expose stable ledger event IDs and state versions. Completed-looking rated records cannot bypass pending settlement through Practice replay.
- Added a versioned atomic Redis queue with server-only standing estimates, process/ticket ownership, mutual windows, duplicate JOIN age preservation and claim/cancel/replacement fencing. Search stays at ±100 throughout the first 60 seconds, then widens by 50 every 15 seconds up to ±600. League edges are not walls; a five-minute recent-opponent preference applies when an alternative exists. No extra Elo bonus or secret repeat-opponent deduction was added.
- Added 45-second queue/120-second claim leases, 15-second refresh/renewal, bounded pruning/candidate scans, expiry checks independent of pruning, caller deadlines and no rated local fallback. Admission rechecks registration/active seats/rating/version/month under ordered DB locks and resolves unknown commit by fixed match UUID. Queue/transport cleanup failure cannot hide a committed match. V1 remains one WebSocket host.
- All read/skill/admission controls default off; launch month remains unselected. Drain pauses new search/admission while persisted recovery/settlement/archive obligations continue. No environment or UTC timezone setting was changed. No Phase 3 DDL or Flutter code was added. The user's login screen, login tests and associated assets/config edits were preserved.
- Added the frontend contract and operational handoff in [RANKED_LEAGUES_PHASE_3_API.md](RANKED_LEAGUES_PHASE_3_API.md). This replaces illustrative route/flag names in the earlier plan where they differ from implemented contracts.

### Phase 3 verification

| Check | Result |
|---|---|
| Full focused PvP suite | **72 passed**, including retained Phases 1–2 and new read, cache, history, capability, Home/Profile, queue/admission and socket-race cases |
| Practice session/replay suite | **9 passed**, including unsettled rated replay protection |
| Existing Home suite | **8 passed** |
| Backend `npm run build` | Passed after final source changes |
| Optional PostgreSQL suite | Parsed and explicitly skipped with `RANKED_ALLOW_DATABASE_TESTS=false`; no DB connection |
| Optional Redis suite | Syntax checked and explicitly skipped with `RANKED_ALLOW_REDIS_TESTS=false`; no Redis connection or Lua execution |
| Changed-source whitespace | Passed |
| Flutter/device checks | Not rerun in Phase 3; no Flutter changes made in this phase, user's login work left intact |

Read fixtures use a deterministic array oracle and inspect parameterized SQL; they do not execute PostgreSQL. Queue adapter/socket tests use inert Redis replies; the pure widening/eligibility/ownership logic is exercised, but actual Lua execution remains unverified. The optional suites cover actual SQL live/final pagination, archived history, independent-client races and real Lua expiry/claim/cancellation behavior when separately authorized. No query-plan, p95, population/load, VPS, native-device or distributed-host evidence is claimed.

## Phase 2 implemented

- Added five Prisma models: immutable versioned policies, monthly seasons, lazy player-season standings, one settlement header per match and immutable per-player rating changes. Added typed UTC `timestamptz(3)` admission/recovery fields, frozen internal question snapshots, state versions, participant disconnect observations and answer-to-participant integrity.
- Prepared additive SQL under `backend/prisma/changes/` without introducing a migration baseline. It includes calendar/nonoverlap constraints, qualification/counter/rating checks, partial indexes, seed/season/content immutability, and deferred terminal/ledger consistency checks. It aborts on legacy answer orphans instead of deleting data. **The SQL has not been executed or validated by PostgreSQL.**
- Pinned the approved v1 defaults: seed 1200; K64 before 20 lifetime games then K32; initial/monthly qualification 10/3 with unfinished initial qualification preserved; Silver/Gold/Platinum/Diamond at 1000/1200/1450/1700; integer half-away rounding; no floor/extra bonuses; carry rating and requalify monthly. Policies are hashed/validated and cannot be silently edited.
- Admission captures database time after ordered user and season lock waits, selects the half-open IST month, freezes ownership/content and initializes standings lazily from the latest prior settled player state. Prior unresolved rated outcomes block new competitive admission, including friendly duels. Reads create no standings. No legacy/friendly/Practice game contributes Elo.
- Outcome, both Elo calculations from original ratings, W/L/D/qualification/peaks, two ledger rows, the settlement snapshot, existing XP awards and terminal match state now commit in one transaction. User/standing/progress locks use consistent ordering; the shared user mutex permits FK key-share checks. Known rollback failures have bounded retries; a lost completion commit acknowledgement is safely resolved by rereading/retrying the immutable match outcome.
- Added monthly calendar catch-up, current-plus-two future seasons, and atomic archival once every assigned match has a terminal disposition. Archives freeze rating, earned qualified peak, league, deterministic qualified ordinal and eligible count. Old-month matches settle in their admission month while new-month admission proceeds for other players. Idle months create no user rows.
- Added startup/periodic bounded due-work recovery, persisted ready/round/transition/hard-expiry handling and socket cache reconstruction. Recovery retains active deadlines, closes missing submissions once, resumes transitions and settles recoverable final evidence. The approved 15-minute system-failure ceiling voids unrecoverable unfinished matches without Elo or XP. Valid final evidence remains settleable after that time; temporary XP/DB failures never become invented losses. Normal inactivity/disconnects retain timed play, and exact equal totals draw.
- Existing GET/reconnect/completion returns a whitelisted own rating block and current absolute XP. Committed results remain retrievable after missed delivery. Frozen Ranked questions also govern completed Practice replays and replay ancestry after catalog edits; replays still award zero rewards.
- Added minimal arena compatibility for `CANCELLED/SYSTEM_VOID`: stop the round, show Match cancelled / no Elo or XP, and use the existing Return to Ranked action. No league UI, badge, leaderboard, Home/Profile/lobby redesign or forfeit feature was introduced. Updated the frontend handbook's previously deferred outage note.
- `RANKED_ADMISSION_ENABLED` defaults off. Enabling requires an explicit `RANKED_LAUNCH_SEASON`. Turning admission off preserves settlement/recovery/archival obligations for existing rated matches. No launch date, environment flag, database timezone or deployment setting was changed.

## Relevant source

- `backend/prisma/schema.prisma`, `backend/prisma/changes/ranked-phase2.sql` and its `README.md` (manual DB review/test/rollout procedure).
- `backend/src/modules/pvp/ranked/`: policy/config, immutable questions, Elo/calendar, season, settlement, transaction and recovery-worker modules.
- Existing PvP match service, DTO/socket and server worker startup/shutdown; shared social user mutex and admission guard; Practice replay source handling.
- Arena controller/screen and the current frontend handbook for the server-confirmed void compatibility path.
- Focused PvP/Practice/Home tests; opt-in `ranked-postgres.integration.cjs` and `ranked-redis.integration.cjs`; existing Phase 2 Flutter tests for terminal void handling. Phase 3 adds query/contracts/cache/eligibility/queue modules in `pvp/ranked/` and `test:pvp:redis`. No dependency or lockfile change.

## Phase 2 verification (previous checkpoint)

| Check | Result |
|---|---|
| Focused PvP tests (foundation, integrity, socket, persistence/recovery) | 44 passed in the final full focused PvP run; deterministic in-memory transaction model, no DB/Redis/app bootstrap |
| Practice session/replay tests | 8 passed, including frozen replay ancestry and prohibited live replays |
| Backend `npm run build` | Passed |
| Prisma schema validation and client generation | Passed; source/client tooling only, no DB connection; existing multiSchema deprecation warning retained |
| Flutter `test/pvp_phase_one_test.dart` | 6 passed, including server-confirmed void, duplicate results, XP/snapshot/ACK recovery and stale-event/account guards |
| Existing Ranked Flutter regressions | 17 passed (normal result/recovery/theme/navigation behavior) |
| Focused Flutter analysis | No issues after the lint correction |
| PostgreSQL integration suite | Skipped by default; no environment authorized or connected |
| Changed-source whitespace | Passed |

The new persistence tests execute real service code with inert dependencies and deterministic rollback/serialization. They cover idempotent settlement, post-XP/ledger failure rollback, lost commit acknowledgement, mixed K and qualification/peak semantics, old/new-month carry, lock-wait boundary resampling, frozen questions, restart deadlines, expiry/voids, calendar catch-up, archive gating and worker bounds/shutdown. These checks do **not** prove actual PostgreSQL locks, constraints, deferred triggers, SQL archival or process/network behavior.

The separately gated PostgreSQL suite uses two real clients for completion/admission races, injects failure after real XP writes, reconstructs a service after a simulated restart, checks SQL constraints and executes archive SQL. It performs no schema setup/migration or cleanup and never falls back to the ordinary `DATABASE_URL`; a separately authorized disposable DB/schema/content fixture is required. See the DB change README. No load/soak test, population simulation or VPS benchmark was run.

## Remaining limits and rollout requirements

- **Database verification is outstanding.** No local DB setup/actions, migration execution, VPS connection or deployment was performed. Apply/review the SQL only after separate authorization; schema drift, legacy audits, real concurrent-connection/deadlock/rollback behavior and deferred trigger execution must be verified before activation. The new backend requires the additive schema even when admission is off.
- V1 supports one PvP WebSocket host. DB lifecycle/settlement writes are idempotent under duplicate workers, but cross-host socket routing and queue ownership are not implemented. Phase 3 implements the approved first-minute narrow search and gradual widening in Redis with process ownership fencing; actual Lua and Redis failure behavior still need the authorized integration run.
- Existing completed history/XP remains untouched and unrated; no retrospective rating, timing certification or historical question version is fabricated. Legacy in-flight matches recover unrated; old records without content snapshots use their existing catalog source.
- New audit FKs restrict deletion. Current auth/user code has no account-deletion endpoint; future erasure/anonymization and retention must be reviewed before broad rollout. No purge or historical XP correction is included.
- Phase 3 read/history APIs and server client-capability gating are implemented. Flutter capability adoption/league presentation is implemented in Phase 4; manual review, real service integration and a production launch date remain outstanding. A client-side outage alone still cannot grant an exit/result; the new terminal return requires the authoritative system-void snapshot. General Forfeit/pending-result exit remains absent.
- No capacity, native-device, distributed-worker or production-readiness claim is made from the local checks. All four source phases stop here for manual review. Environment operations and release remain separately restricted.

## Phase 1 retained foundation

The prior checkpoint repaired premature answer/private-data disclosure, live Practice replay bypasses, client timing exploits, answer/timeout/transition races, socket replacement ownership, completion delivery and duplicate local XP application. Its pure Elo/calendar rules and focused coverage remain in the current suite. Existing score → total-time → exact draw ordering and XP amounts are retained. The Phase 1 checkpoint passed 27 PvP, 7 Practice, 5 arena tests and 17 existing Ranked Flutter regressions; its schema/recovery limitations are addressed in source above, with actual DB verification still outstanding.
