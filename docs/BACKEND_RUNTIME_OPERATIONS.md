# Backend runtime preparation — Stage 3

This is source preparation and local verification, not a deployment approval or a statement about the VPS. No VPS/remote DB inspection, deployment, load test, backup, source-content removal or admin deletion redesign was performed. The original audit/plan remain historical references; the revised three-stage scope governs this implementation.

## Process responsibilities

| BACKEND_ROLE | HTTP API | WebSockets/recovery | Content/book workers, expiry, cron/recovery/temp cleanup |
| --- | --- | --- | --- |
| combined (default) | yes | yes | yes |
| realtime | yes | yes | no |
| http | yes | no; upgrades rejected | no |
| jobs | health/readiness only | no | yes |

Keep one realtime owner and one jobs/scheduler owner. The smallest isolated topology is one realtime process plus one jobs process; no separate HTTP process is required. `backend/ops/ecosystem.config.cjs` is an **unactivated fork-mode example**, with one instance per role. No PM2 command was executed. Do not run `instances:max`, use cluster mode or overlap/reload singleton owners. Only consider more HTTP workers after separately authorized evidence.

Every role must use the same application database and the same Redis URL/database. Full Redis URL/TLS/ACL/escaped credentials are preserved. Token-owned Redis runtime leases reject overlapping owners; renewal failure/replacement exits that process immediately. This limits scheduling overlap; it is not a substitute for database transactions or proof against arbitrary process pauses/partitions. Accepted operation receipts and book/generation fences remain authoritative. Remote AI computation may continue after a process exits.

All roles initialize a Social Redis producer so jobs can publish expiry notifications. Only realtime initializes the Social subscriber and WebSocket listeners. Critical expiry/settlement is persisted independently of optional notification delivery.

**First transition from Stage 2:** the old combined server has no runtime-owner lease. Stop it before starting this version; a new lease cannot detect an older process that never acquired one. No rolling mixed-version singleton activation is supported.

## Configuration and connection budget

Use `backend/.env.example` as the key register and `src/config/runtime-config.ts` as the executable bounds. The real `.env` was not edited. `DOTENV_CONFIG_PATH` optionally selects a private environment file; tests point it at an empty fixture file. Do not put credentials in PM2 source or command output. Business rules, rewards, IST day semantics and shared prompt/timing policy remain code/DB contracts.

Production requires:

- A patched supported Node version matching `backend/.nvmrc` / package engines. The target recorded on 20 October 2026 is Node **24.22.0**, with **22.23.3+ on the 22 line** also accepted. Check [official Node releases](https://nodejs.org/en/blog/release) and [EOL status](https://nodejs.org/en/about/eol) before an actual release. Local checks used available Node 24.5.0; the workspace root also resolves Node 20.19.5. No runtime was installed/upgraded. Those older versions are rejected by production bootstrap.
- Distinct access/admin signing keys of at least 32 bytes; valid token lifetimes; configured Google audiences when Google login is enabled. AI generation is explicitly disableable; enabling it requires a Gemini key. Ranked reads require a separate 32+ byte cursor key; the old access-key fallback is removed. Ranked flags remain off by default and no launch season is chosen.
- Explicit `REDIS_URL`, `DATABASE_URL` pool options `connection_limit` and `pool_timeout`, plus `DATABASE_CONNECTION_BUDGET` and `DATABASE_PROCESS_COUNT`. `connect_timeout` defaults to three seconds. Values are bounded and duplicate pool options reject.
- Absolute `BOOK_STORAGE_ROOT` and `BOOK_TEMP_ROOT`, distinct/non-nested, outside the release checkout. Their resolved paths must also be outside it, and production directory permissions must deny group/other access. Provision private persistent directories under the application owner. Existing source files and DB storage paths are not moved; review those paths before enabling ingestion against older development records.
- Browser `CORS_ALLOWED_ORIGINS`, with exact scheme/host/port origins and no wildcard. Empty permits no cross-origin browser access. Bearer-authenticated native clients without Origin keep working. `HOST` defaults to loopback; explicitly configure a development LAN bind if needed. Do not expose the jobs health listener publicly.

Pool inequality: `connection_limit × DATABASE_PROCESS_COUNT <= DATABASE_CONNECTION_BUDGET`. Count all steady processes **and the planned HTTP reload overlap**. Example only: two owners plus one extra HTTP overlap, each with limit 5, need 15 connections within an operator-assigned budget of 20. This is not a capacity measurement. Startup also checks the declared budget against PostgreSQL max_connections minus superuser/reserved connection slots. Leave additional headroom for operator tools and other applications; actual process counts and shared-server allocations remain operator responsibilities. There is one shared Prisma client/pool per process and no PgBouncer installation.

Operational keys added/wired in Stage 3:

| Area | Keys |
| --- | --- |
| Role/network/lifecycle | BACKEND_ROLE, HOST, PORT, READINESS_TIMEOUT_MS, SHUTDOWN_TIMEOUT_MS, HTTP_REQUEST_TIMEOUT_MS |
| Pool declaration | DATABASE_URL options, DATABASE_CONNECTION_BUDGET, DATABASE_PROCESS_COUNT |
| API/browser | CORS_ALLOWED_ORIGINS, AUTH_JSON_LIMIT_BYTES, MOBILE_JSON_LIMIT_BYTES, ADMIN_JSON_LIMIT_BYTES, GOOGLE_AUTH_ENABLED |
| Jobs/storage | CONTENT_WORKER_CONCURRENCY, SOCIAL_WORKER_CONCURRENCY, QUEUE_FAILED_RETENTION_COUNT, QUEUE_FAILED_RETENTION_SECONDS, BOOK_STORAGE_ROOT, BOOK_TEMP_ROOT, BOOK_UPLOAD_MAX_BYTES, BOOK_MAX_PAGES, BOOK_MAX_EXTRACTED_TEXT_BYTES, BOOK_TEMP_RETENTION_HOURS, CURRICULUM_SOURCE_ROOT, CURRICULUM_SYNC_ON_STARTUP |
| Cache/diagnostics | LOCAL_CACHE_MAX_ENTRIES, LOCAL_CACHE_MAX_BYTES, LOG_LEVEL |
| Feature consolidation | AI_GENERATION_ENABLED and the existing Ranked activation/runtime/queue/cursor settings |

Book concurrency stays one per jobs owner; automatic billable book retries remain disabled. Existing shared AI admission bounds still apply to each provider attempt. Central abuse policies stay reviewed code constants rather than dozens of independent ENV switches. `CURRICULUM_SOURCE_ROOT` supplies repository lesson JSON to the single combined/jobs owner when `CURRICULUM_SYNC_ON_STARTUP=true` (default); it runs in the background and retains existing scripts. Source book PDFs are never auto-imported. See [content recovery](BACKEND_CONTENT_RECOVERY.md) for the additive one-shot command, file prerequisites and PM2 environment refresh.

## Startup, readiness and shutdown

Startup validates config and the supported production runtime, connects dependencies with time limits, checks required Stage 1/2 columns and assignment uniqueness, and checks native Ranked trigger/constraint/index metadata. It checks trigger enablement, deferred flags, constraint validation and index validity, **not complete function/check-expression drift**. It applies no DDL or migrations. Native guards are required even with admission off, since existing rated evidence/recovery must remain valid.

Workers expose readiness only after BullMQ connects. The listener starts after dependency checks, and PM2 receives `ready` after listen succeeds. `/health` is process liveness only; `/ready` reports cached dependency/worker readiness (two-second probes with bounded timeouts) and returns 503 during drain/dependency failure. It reveals no URLs, credentials, schema details or queue payloads. There is a short probe interval, not an instantaneous availability guarantee.

SIGINT/SIGTERM enter one shared bounded shutdown:

1. Mark draining; stop new HTTP requests/upgrades and new matchmaking; pause new worker pulls; close the HTTP listener/idle connections; stop schedules/recovery sweeps.
2. Wait for accepted HTTP handlers, including asynchronous work after a client disconnects. Clients may retry uncertain acknowledgments using existing durable operation identities.
3. Keep existing game answers/recovery running within the remaining shutdown budget. Close sockets and stop Ranked recovery after games finish.
4. Wait for worker closes, then close producers, Social transport, runtime leases, shared Redis and Prisma.

The overall timeout defaults to 30 seconds. Exhaustion forces exit 1; a broken shutdown also fails rather than claiming successful drain. A dependency/ownership loss can interrupt work earlier. Existing DB transactions roll back on connection loss; committed receipts/settlements remain recoverable. Failed book stages still require explicit retry. Provider requests cannot be guaranteed cancelled remotely.

A ten-minute match cannot be promised an uninterrupted restart with a 30-second drain. Route `/ws/pvp` and `/ws/social` to the single realtime owner; WebSockets cannot transfer to another process on reload. Plan an admission pause and allow matches to finish before an owner restart where possible. `RANKED_ADMISSION_DRAIN=true` at startup stops new matchmaking while keeping admitted recovery; changing process ENV still requires operator-controlled restart, so it is not a live maintenance API. On an unavoidable stop, clients reconnect and authoritative clocks continue; hard-expiry/void and settlement rules are unchanged. There is no zero-downtime or HA claim. Keep the supervisor kill timeout above the application drain timeout (example: 35 seconds vs 30).

## Internal cache and content contract

Only immutable stored script definitions are cached under `script:def:v2:<version>`. Authorization/publication checks and sensitive response DTO masking remain outside cache lookup. Reviewed question snapshots embedded in that version are used for teaching/answer evaluation; editing a repository question does not silently replace the question mid-session. Re-author/publish a new script version to incorporate corrections. Book publication persists its hydrated snapshot and checksum. Legacy versions without snapshots still resolve missing references from the repository and do not gain a fabricated historical snapshot.

Cache misses coalesce per process with a bounded in-flight map; this is read optimization, not a distributed lock. Callers receive independent objects. Old cache namespaces are not trusted as v2 data. Local fallback has an entry/byte ceiling, per-entry size cap and at most five-minute lifetime with sweeping/eviction. Lock helpers fail closed and use token-checked release; they never use local cache as ownership. No new Home/profile/leaderboard response caches or materialized rollups were introduced.

## Storage, logs and artifacts

PDF ingestion retains the existing maximum 150 MB capability, now bounded by config. It preflights the page count and extracts at most 25 pages per batch, checking cancellation/text-byte limits before persistence. Large file read/copy/page writes are async; four-byte magic checks and small directory helpers remain synchronous. Parser internals can allocate before a batch limit is checked: this is not an OS memory sandbox, and malicious/expensive PDF behavior was not stress tested. Keep ingestion in the jobs process and review actual memory budgets separately.

Only new `upload-<UUID>.pdf` temporary files older than the configured retention are eligible for bounded hourly cleanup. Source PDFs, book directories, old unmatched filenames and symlinks are preserved. No committed content was deleted, relocated or hidden from Git. Failed/abandoned files may remain until cleanup. Runtime storage must not be served as a static directory.

Logs use structured events with allowlisted fields and coarse error codes, without tokens, payloads, raw provider/Prisma messages, SQL parameters, user identity, raw URLs or query strings. HTTP logs use server-generated request IDs and route templates. A one-minute resource event records RSS/heap/event-loop delay/active requests at debug level only (`LOG_LEVEL=debug`); normal `info` production logs omit these healthy snapshots; readiness records dependency/worker failure. This is lightweight diagnostics, not a monitoring platform. Configure external log rotation/retention with the existing supervisor before release; nothing was installed remotely. Explicitly excluded destructive admin deletion retains its old error/log behavior, so broader all-route privacy hardening is not claimed complete.

Luna preparation failures emit `luna.preparation_failed` with a preparation ID, mode, stage, call count and a fixed error code. Provider failures also include a safe HTTP status and allowlisted provider code when available; raw response messages, prompts and API keys are never logged. The matching Practice frontend line is `[Practice Preparation] id=… state=… code=…`. These are diagnostic records, not files or new API routes. Save the failure line from the API/jobs process and frontend to correlate the same preparation. Existing historical `QUALITY_OR_PROVIDER_FAILURE` records cannot recover an original exception that was previously discarded.

Common codes: `LUNA_AUTH_FAILED` (provider authentication/access), `LUNA_QUOTA_EXCEEDED` (provider quota), `LUNA_RATE_LIMITED`, `LUNA_REQUEST_TIMEOUT`, `LUNA_OUTPUT_LIMIT`, `QUALITY_REVIEW_FAILED`, `PREPARATION_EXPIRED`, `WORKER_INTERRUPTED`, `QUEUE_UNAVAILABLE`, and `DATABASE_FAILURE` with a safe Prisma cause code. Check the reported stage before changing configuration. No automatic paid retry or relaxed quality gate is added. Deploy with the normal backend build/restart; no new environment variable or migration is required. A new mobile build adds the frontend support reference and clearer notices; backend logging works independently.

The npm artifact allowlist contains built runtime code, schema/native SQL references, README, `.env.example` and `.nvmrc`. `npm run verify:artifact` checks the dry-run file list; it never publishes. Storage, original PDFs/page JSON, real `.env`, tests and authoring scripts are excluded from this package. Their source copies remain intentionally public in Git. This is not a CI/CD pipeline or an automatic release script.

## Verification and release boundaries

The progress report records exact checks and fixture targets. Default `npm test` is inert with respect to DB/Redis. HTTP checks bind loopback only. Integration tests require separate allow flags and dedicated loopback URLs. Legacy roadmap/XP/book/lesson test scripts now reject execution before app config unless explicitly supplied dedicated `LEGACY_TEST_*` database/Redis/private storage targets; they remain excluded from the default suite and were not executed against data.

Read [the dependency review](BACKEND_DEPENDENCY_REVIEW.md). The lockfile advisory check has unresolved entries and the locally available runtime is behind the production pin. No dependency or runtime upgrade was performed. Before an actual release, prepare the intended development schema/native SQL, provision private config/storage, resolve dependency/runtime gates, verify the real proxy/permissions/pool allocation, and separately authorize deployment. Do not downgrade past the Stage 1 timing/receipt or Ranked settlement contracts. Disabling admission does not remove obligations to recover/settle admitted matches. Admin deletion conflicts, social discoverability policy, new response caching, query-plan/index tuning, backups and load/soak tests remain separate work.
