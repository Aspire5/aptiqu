# AptiQu backend

The database structure is defined in `prisma/schema.prisma`. Apply schema changes manually; this backend has no migration workflow or automatic database setup on install, build or startup.

From this directory, after pulling the current code:

```bash
npm ci
npx prisma db push
npx prisma generate
npm run build
```

Restart the backend using your existing process manager. `db push` reads the configured `DATABASE_URL` from `.env`. No migration baseline or `migrate resolve` command is required.

## Remove previously installed Home objects once

If the old Home rollup SQL was already run on your VPS, removing files from this repository does not remove those PostgreSQL objects. Before applying the new schema, stop the backend and run this once in `psql` connected to `aptiqu_db`:

```sql
BEGIN;
DROP FUNCTION IF EXISTS gamification.sync_home_submission() CASCADE;
DROP FUNCTION IF EXISTS gamification.home_event_delta() CASCADE;
DROP FUNCTION IF EXISTS gamification.award_home_badges() CASCADE;
DROP FUNCTION IF EXISTS gamification.sync_home_ranked() CASCADE;
DROP VIEW IF EXISTS gamification.home_source_events;
DROP TABLE IF EXISTS gamification.home_events,
  gamification.home_totals, gamification.home_days,
  gamification.home_badges, gamification.home_ranked;
DROP INDEX IF EXISTS learning.lesson_home_resume;
DROP TABLE IF EXISTS public."_prisma_migrations";
COMMIT;
```

`CASCADE` on those four functions removes their dependent Home triggers. This removes the old Home machinery and unused migration history; answer/session tables, curriculum, XP and users remain. Afterward, run the manual schema/build commands above. The new API calculates Home metrics directly from the source tables.
