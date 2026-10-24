# Ranked native PostgreSQL guards

## Current tables already exist after Prisma 6 `db push`

Use **[ranked-native-install.sql](ranked-native-install.sql)** for this case. Do **not** replay `ranked-phase2.sql`: it includes historical table/type/column creation and Prisma-managed objects. The supplemental installer adds only these persistent native objects:

| Object | Count | Purpose |
| --- | ---: | --- |
| Trigger functions | 4 | Existing audit, identity, answer and settlement guards |
| Triggers | 10 | Seven immediate guards and three deferred integrity guards |
| Constraints | 14 | Twelve CHECKs, one season exclusion and one opponent foreign key |
| Partial indexes | 2 | Qualified standings order and unique final positions |

The exclusion constraint also creates its required GiST backing index. No extension is needed for its built-in `tstzrange` operator class. The Prisma-managed `pvp_matches_status_hard_expires_at_idx` and `ranked_rating_changes_user_id_created_at_id_idx` are deliberately omitted. The four function bodies and all constraint expressions, index definitions and trigger events are retained from the native section of `ranked-phase2.sql`; no gameplay or policy code changes are involved.

**Review status:** static review and the focused disposable local PostgreSQL verification below passed. No SQL fixes were required. No AWS, existing development database or production database was accessed. Production execution and locking under real application traffic remain untested.

Static checks passed using `pglast 7.21` (PostgreSQL 17 parser, without a database): both SQL files, four installer PL/pgSQL blocks and four trigger-function bodies parse; all 14 constraint definitions, ten trigger definitions and two index definitions match the historical native DDL as parsed syntax trees; function bodies match byte for byte. Installer/verifier manifests cover every startup requirement. The verifier's parsed statement tree contains only a read-only transaction, local search-path setting and SELECTs. Parsing does not resolve database types/catalogs or execute DDL.

### Focused disposable runtime verification — 2026-10-20

All seven checks passed on **PostgreSQL 14.19**, with **Prisma CLI/client 6.19.3** and Node 24.5.0. A newly initialized temporary cluster listened only on `127.0.0.1:49732` and its private Unix socket. Every test connection named that cluster's socket/port or explicit loopback URL; no existing database connection settings were used as a fallback. The cluster's actual data directory and unique cluster name were checked before testing. The CLI used a byte-for-byte temporary copy of the repository schema, outside the ordinary `.env` location, with an explicit disposable `DATABASE_URL` and `db push --skip-generate` (no reset). Schema creation, installation and verification used a separate **non-superuser database owner**. Cluster bootstrap alone used its fresh administrative role.

| Requested check | Result and evidence |
| --- | --- |
| Fresh Prisma-managed schema | PASS — `db push` created all **55 model tables**. Required Prisma indexes/unique keys were present, including the two historical indexes omitted from this installer. |
| Pre-install verifier | PASS — **30 `MISSING` native objects**, with the other **16 requirements `OK_METADATA`**, across exactly 46 rows. |
| First native install | PASS — transaction committed **14 constraints, 2 partial indexes, 4 functions and 10 triggers**. |
| Post-install verifier | PASS — **46/46 `OK_METADATA`**. |
| Second install without replacement | PASS — **30 `Matching` notices**, no `Installed` notices; before/after snapshots retained permanent catalog **OIDs, `xmin` values and definitions** across application schemas. A fixture policy row inserted before installation remained byte-for-byte identical. Reverification stayed **46/46**. |
| Actual startup checker | PASS — imported the actual `src/runtime/schema-contract.ts` through `tsx` and invoked `assertDatabaseContract` using a real `PrismaClient` explicitly targeting the disposable database, with connection budget **20**. This exercised the checker function, not full application startup. |
| Failed installation rollback | PASS — in a second fresh Prisma-created database in the same new cluster, a deliberately incompatible `ranked_deny_audit_mutation()` caused failure **after 14 constraints and 2 indexes had been created inside the transaction**. Fresh-connection catalog snapshots exactly matched the pre-attempt state, including the conflicting function; fixture data was unchanged. The verifier then showed **29 `MISSING`, 1 `INVALID` function and 16 `OK_METADATA`**, confirming no partial installation. |

Local evidence is retained under `/private/tmp/aptiqu-native-runtime-9v5gt0th/`: `results.json`, `fixture.json`, individual command logs, verifier CSV output and catalog snapshots. The temporary harness is `/private/tmp/aptiqu-native-runtime-check.py`. These are local review artifacts, not deployment dependencies. Both test databases belonged exclusively to this newly created cluster; it was stopped after verification and its disposable data directory removed. No application server, load test, performance benchmark or broader integration suite was run. Existing unrelated workspace changes were preserved.

### Installation behavior and prerequisites

- The current `schema.prisma` tables, columns, enums and Prisma-managed keys/indexes must already exist. This is supplemental installation, not schema repair, a Prisma migration baseline or recovery of data removed by an earlier reset.
- Use the table-owning deployment role, with `CREATE` on `learning`, database `TEMP` permission, type/schema usage and permission to create functions/triggers and reference the participant key. No superuser or extension installation is required for an ordinary owner deployment.
- The script uses one transaction. It takes `ACCESS EXCLUSIVE` locks on eight existing Ranked/PvP tables, blocking reads and writes until commit/rollback. Schedule a maintenance window and stop all backend HTTP, PvP and worker processes before installation. Its five-second **lock acquisition** timeout aborts instead of waiting indefinitely; index construction/constraint validation can take longer. Existing connection-level statement timeouts still apply.
- Matching installed definitions are retained. CHECK/exclusion and partial-index comparisons use empty temporary `LIKE` tables so PostgreSQL canonicalizes both sides with the same actual types and collations. The five temporary templates contain no application rows and disappear at commit/session end. The FK is compared by ordered keys, referenced table, actions and deferral; functions by body and attributes; triggers by function, events, timing, row scope, arguments and deferral. Trigger enable modes `O` (ordinary) and `A` (always) are accepted, as in startup.
- Different definitions, disabled triggers, unvalidated constraints, invalid indexes or naming collisions abort the **whole** transaction. Function comparison ignores only surrounding whitespace; internal formatting differences also require review. No existing object is dropped, replaced, re-enabled or silently accepted by name. Repeating the command is intended to retain matching installed objects and create only missing ones.
- Adding CHECK/FK/exclusion/unique guards validates existing rows. Violations abort without altering those rows or leaving a partial installation. A failed statement or lost connection rolls back all new persistent objects. Diagnose the named object/data issue separately; this script performs no cleanup or data correction. Newly installed deferred triggers apply to subsequent writes; they do not retrospectively audit old settlements.

### Exact manual commands (operator runs these after review)

From the repository's `backend/` directory, use your normal **libpq/psql** connection profile. Set `PGHOST`, `PGPORT`, `PGDATABASE`, `PGUSER` and the provider-required TLS settings for the reviewed target; provide the password through your normal prompt or password file. A Prisma URL containing `schema`, `connection_limit` or `pool_timeout` is not a libpq URL. Do not paste credentials into SQL or commit them. Set `DATABASE_CONNECTION_BUDGET` to the numeric value actually used by the deployed backend.

These shell guards require the target and budget to be chosen explicitly:

```sh
: "${PGHOST:?Set the reviewed PostgreSQL host}"
: "${PGDATABASE:?Set the reviewed database name}"
: "${PGUSER:?Set the table-owning deployment role}"
: "${DATABASE_CONNECTION_BUDGET:?Set the deployed backend connection budget}"
```

1. Obtain the normal recoverable backup and confirm the target. The identity query and verification are read-only:

   ```sh
   psql -X --set=ON_ERROR_STOP=1 --command='SELECT current_database(), current_user, inet_server_addr(), version();'
   psql -X --set=ON_ERROR_STOP=1 \
     --set=connection_budget="$DATABASE_CONNECTION_BUDGET" \
     --file=prisma/changes/ranked-native-verify.sql
   ```

2. After review and with application processes stopped, install:

   ```sh
   psql -X --set=ON_ERROR_STOP=1 --file=prisma/changes/ranked-native-install.sql
   ```

3. Verify again before restarting the backend:

   ```sh
   psql -X --set=ON_ERROR_STOP=1 \
     --set=connection_budget="$DATABASE_CONNECTION_BUDGET" \
     --file=prisma/changes/ranked-native-verify.sql
   ```

`-X` ignores local psql startup customizations; `ON_ERROR_STOP` stops on SQL errors. Do not add `--single-transaction` or wrap the files in another transaction: both files manage their own transaction. The verification query returns 46 requirement rows, with problems first. Missing native guards are expected before installation. **Every row must report `OK_METADATA`** before restarting. A successful psql exit alone does not mean the report passed: `MISSING`, `INVALID` and `MISSING_OR_INVALID` are report values, not SQL exceptions.

[ranked-native-verify.sql](ranked-native-verify.sql) runs in `BEGIN READ ONLY` and checks all requirements from `src/runtime/schema-contract.ts`: 14 Prisma-managed columns, 10 enabled triggers (including deferred integrity settings), 14 validated constraints, two valid native indexes, the Prisma assignment unique key and the supplied connection budget against available server slots. It also checks function bodies/attributes, trigger structure and native-index keys/order/predicates. It returns actual definitions for review. **`OK_METADATA` is not a full constraint-expression drift proof or a retrospective data audit**; the installer performs the strict expected-definition comparison. Missing Prisma columns/assignment keys or an excessive budget remain separate issues this native-only installer cannot fix.

After a successful install, repeating step 2 is the manual repeatability check; it must report matching objects and commit without replacing them. Re-run step 3 afterward. This passed in the disposable local test above; no AWS execution was performed. Any future Prisma operation that removes native objects requires this reviewed supplemental step again. Do not run a reset to resolve native guard errors. No migration registration or automatic startup installation is added.

PostgreSQL references: [temporary `LIKE` tables](https://www.postgresql.org/docs/14/sql-createtable.html), [catalog definition functions](https://www.postgresql.org/docs/14/functions-info.html), [trigger metadata](https://www.postgresql.org/docs/14/catalog-pg-trigger.html), [index metadata](https://www.postgresql.org/docs/14/catalog-pg-index.html).

## Historical Ranked Phase 2 database change preparation

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

## Luna fresh question preparation

`luna-question-preparation.sql` is an additive, unapplied change for the fresh Luna implementation. It adds the physical `Luna` source enum value (Prisma `LUNA`), a `PREPARING` friendly-duel status, durable preparations, reference lineage and Practice snapshots. No rows are relabeled, content imported, or historical snapshots rewritten. Review and apply this SQL only after explicit database authorization; client generation and offline tests do not apply it. Enum additions must be committed before statements using their new values. Keep the database/session/server timezone UTC.

Deploy the SQL and regenerated Prisma client before the new backend: startup schema checks intentionally reject an older database. Use the jobs runtime/content worker and its existing Redis connection. The new handler has one BullMQ attempt and a four-call durable provider budget; a stalled/ambiguous attempt fails rather than repeating an unknown paid call. Real OpenAI requests, database concurrency checks and VPS deployment were not run as part of source verification.

Luna uses `OPEN_AI_API_KEY`, `LUNA_REASONING_EFFORT=medium` (or `high`), 120-second requests and a 600-second preparation deadline. See the root `luna_pvp_implementation_plan.md` for exact executable prompt/request/schema templates, quotas, key-free verification and rollout limits.
