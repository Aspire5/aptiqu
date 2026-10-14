# Database-authored achievements

`gamification.achievements` is the sole catalog. There is no code catalog, default seed, migration, trigger or automatic setup. Update the schema manually with `npx prisma db push`, regenerate Prisma Client and build the backend. Open the admin Achievements tab to create the desired definitions; until then the app shows an empty state.

Each definition has a title, description, target, display order, active flag, rule, soft-delete timestamp and edit version. Supported rule primitives are attempted answers, correct answers, successfully completed Daily Challenges, PvP wins and best recorded Daily Challenge streak. Attempted/correct rules can filter source and difficulty. Other rules reject those filters rather than silently ignoring them. The primitives are API capabilities, not hardcoded achievement definitions.

Sources use the same canonical SQL as Home. Timeouts/null selections are excluded; retries and replays count separately. Unfinished sessions' submitted answers count. PvP wins require a completed, non-tied match and the player's winner flag. Challenge completions require COMPLETED, excluding failed/abandoned attempts. Best streak uses the existing recorded highest streak. Definitions apply retroactively to retained history and have no synthetic award date or permanent award ledger. Editing targets/rules or correcting/deleting history recalculates completion.

Admin routes are behind the existing admin JWT middleware:
- `GET /admin/achievements/options` returns supported rule options.
- `GET /admin/achievements` supports page/limit, title/description search and ALL/ACTIVE/ARCHIVED filters. Maximum page size is 50.
- `POST /admin/achievements` creates a validated definition.
- `PUT /admin/achievements/:id` updates a nondeleted definition with its current version.
- `DELETE /admin/achievements/:id` soft deletes by default; `?hard=true` permanently removes the definition. Both require the current version in the body.
- `POST /admin/achievements/:id/restore` restores a soft-deleted definition as inactive. Review and activate it explicitly.

Soft deletion keeps definitions and their current derived analytics available in the admin. Inactive/soft-deleted definitions are excluded from learner endpoints. Hard deletion removes the catalog row; no learner/session data is deleted. Concurrent edits/deletes produce a 409 conflict instead of overwriting another admin's change. The admin editor traps focus through a native dialog, disables controls during save, validates input and confirms deletion.

Home shows six definitions in stable display-order/ID order. The authenticated `GET /user/achievements` endpoint supplies 20 definitions per page by default (maximum 50), with current progress and a hasMore flag. The app supports refresh, retry and deduplication by database ID. When definitions change during pagination, refresh to rebuild the current list.

Analytics include registration-complete auth users. Completed means progress >= target; in progress means 0 < progress < target; not started means zero progress. Each row partitions all eligible learners into those three groups. Overall totals follow the selected definition filters and count learner-achievement pairs, not distinct people. No per-achievement query or users x achievements Cartesian product is used: PostgreSQL aggregates canonical source rows into per-user rule metrics, groups equal progress values into distributions, then joins definitions to those distributions. It returns only aggregate counts and the requested definition page. No user lists are loaded into Node or the browser.

Lifetime analytics must read retained history; cost still grows with history. User/source indexes, one shared aggregation per request and bounded output avoid N+1 and application-memory scans, but SQL execution, EXPLAIN plans and load performance have not been measured against a live database in this workspace. Local database actions remain restricted by AGENTS.md. Backend tests use isolated mocks and pure rule calculations, not a database.

Validation: `npm run test:home`, `npm run test:achievements`, `npm run build`, `npx prisma validate`, admin build, Flutter Home/navigation/browser tests and targeted Flutter analysis.
