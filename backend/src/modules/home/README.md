Home uses the authenticated `GET /api/v1/user/home` endpoint. Identity and XP load through the existing `/user/profile?summary=true` endpoint. The Home response contract and Flutter navigation remain unchanged.

All Home statistics are calculated in PostgreSQL from the canonical lesson, practice, Daily Challenge and PvP answer tables. There are no Home projection tables, database triggers, stored functions, views, caches or background aggregation jobs.

The API performs five reads in one repeatable-read snapshot:
- One parameterized SQL query filters each answer source by the authenticated user before joining session/question metadata. `UNION ALL` preserves retries and replays. `GROUPING SETS` computes lifetime difficulty totals and recent daily activity together; it returns at most four difficulty rows, 16 source/difficulty rows and 28 daily rows.
- One latest active/paused lesson lookup uses the user/activity index and selects only the metadata needed to resume.
- One query fetches the first six active database-authored achievement definitions. A paginated achievement browser provides the rest.
- One scalar-facts query returns completed challenge/win counts, the best streak and successful challenge dates for the calendar.
- One user-scoped PvP player/match join returns the latest completed result, with a deterministic tie-break and `LIMIT 1`.

Aggregation stays in PostgreSQL; raw answer collections are never loaded into application memory. Existing indexes support filtering attempts by user, sessions/participations by user, and their answers by parent ID. Lifetime metrics still process that user's retained submissions on each request. Query latency and execution plans should be measured against representative history before claiming performance at large scale.

Definitions:
- Submissions include persisted lesson attempts and explicitly selected practice, Daily Challenge and PvP answers. Retries, replays and answers from unfinished sessions count. Null selections and `TIMEOUT` answers in timed modes do not count.
- Accuracy is correct submissions divided by all submissions. An empty denominator returns null.
- Average correct time includes positive response times on correct regular practice, Daily Challenge and non-late PvP answers. Lesson answers, practice replays, incorrect answers and missing/nonpositive times are excluded.
- Activity uses submission timestamps, interpreted as UTC and converted to Asia/Kolkata. The calendar has 28 chronological IST dates; an empty date contains zero submissions. App opens and session launches do not count.
- Difficulty uses the current linked question, or the published script version's inline difficulty for lesson attempts without a question record. Unrecognized values are UNKNOWN. Editing question difficulty changes the derived breakdown.
- Achievement definitions are stored in `gamification.achievements` and authored exclusively through the admin console. No default definitions are hardcoded or automatically seeded. See `../achievements/README.md` for rules, analytics and lifecycle behavior. Progress and unlocked status are calculated from retained history, so edits or deletions of that history change progress.
- Month/year headings and Monday-first weekday labels distinguish calendar dates. Today is outlined in cyan. A fire marker means the participation on that IST date has status COMPLETED; FAILED and ABANDONED participations have no fire marker. The top Daily Challenge card contains the current streak; the duplicate Home heading and XP section are removed.
- Daily Challenge streak and best streak continue to use the existing streak model. The latest PvP snapshot comes directly from completed matches; the product has no rating model.

Schema changes live in `backend/prisma/schema.prisma` and are applied manually with `npx prisma db push`. See `backend/README.md` for deployment and the one-time removal of previously installed Home database objects. Build/start/install commands do not update the database.

Validation without a database: `npm run test:home`, `npm run build`, and `npx prisma validate`. Tests cover weighted metrics, empty results, IST boundaries, calendar shape, the response contract, derived badge corrections and SQL parameter binding. They do not execute SQL against PostgreSQL; query execution and plans remain unverified until explicitly tested on a database.
