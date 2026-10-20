# AptiQu backend

The database structure is defined in `prisma/schema.prisma`. Apply schema changes manually; this backend has no migration workflow or automatic database setup on install, build or startup.

From this directory, after pulling the current code:

Schema changes are manual and development-only in this work. Verify the hostname, port and database name before applying them; never assume the ordinary `.env` target is disposable. Generate the client with `npx prisma generate` after reviewing `prisma/schema.prisma`.

**Prisma schema synchronization alone is incomplete.** Ranked also needs native CHECKs, partial indexes and immutable/deferred integrity triggers documented in `prisma/changes/README.md`. The historical `ranked-phase2.sql` contains both Prisma-representable DDL and supplemental SQL; do not blindly run that whole file over a schema already created by Prisma. Preserve those native definitions on an existing database. No migration baseline, automatic reset or production migration program is introduced.

Stage 2 additionally requires the assignment pair unique constraint, generation lease table, BookSource processing controls, prompt draft revision and Practice timing policy. Recreate a verified disposable fixture rather than assuming historical development duplicates are safe to discard. Do not use `--accept-data-loss` or reset an unknown target.

Queue modules are inert on import; the existing combined bootstrap explicitly starts workers. There is no automatic source-book import at server listen. Source-book synchronization remains an explicit operator action. PM2 roles/cluster deployment remain a later task.

`npm test` runs the selected inert security/Practice/PvP regressions. Local hardening integration tests require explicit `STAGE1_ALLOW_LOCAL_TESTS` / `STAGE2_ALLOW_LOCAL_TESTS` flags and dedicated `STAGEn_TEST_DATABASE_URL` / `STAGEn_TEST_REDIS_URL` values; they reject ordinary or remote targets. Do not substitute the regular `DATABASE_URL`. See `../docs/BACKEND_HARDENING_IMPLEMENTATION_PROGRESS.md` for the exact verified fixture names, schema requirements and results.

AI admission uses shared Redis concurrency/request/token reservations and the bounded settings in `.env.example`. These are conservative admission limits, not a monetary guarantee. Provider timeout aborts the client transport; remote computation or billing may continue. Books require an explicit retry after a real failure; legacy queued jobs without a processing epoch must be explicitly re-enqueued.

## Runtime and release preparation

Read [the Stage 3 runtime runbook](../docs/BACKEND_RUNTIME_OPERATIONS.md) before starting this version. Production validates private storage paths, pool budgets, feature configuration and the supported Node version in `.nvmrc`. The real `.env` is never modified by these changes. Custom clients must send the Stage 2 script/prompt/timing preconditions.

`/health` reports process liveness; `/ready` reports recent dependency/worker readiness and becomes 503 during draining. Startup checks required schema columns, assignment uniqueness and native Ranked guard metadata without applying DDL. Metadata checks are not a full SQL drift proof. Keep one realtime owner and one jobs/scheduler owner, with fork mode. The prepared `ops/ecosystem.config.cjs` is an unactivated example and requires separately provisioned private configuration.

`npm run build` compiles the backend. `npm run verify:artifact` checks a dry-run package manifest without publishing; runtime storage, PDFs, real `.env`, tests and authoring scripts are excluded from that artifact. Committed source materials stay in Git. No install/build/start command performs database schema actions.

The previous README's destructive historical Home cleanup is obsolete and must not be used as an upgrade instruction. Any cleanup is a separate reviewed task. Admin destructive deletion still exists and may conflict with Ranked immutable evidence; do not drop native guards to bypass that conflict.
