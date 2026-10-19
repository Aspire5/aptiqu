# Ranked Leagues — Phase 3 API and matchmaking handoff

Updated 20 October 2026 (IST). Phase 3 source work is complete. PostgreSQL/Redis execution and query-plan measurements remain pending separate environment authorization. Phase 4 frontend work is now implemented; see `RANKED_LEAGUES_PHASE_4_HANDOFF.md` for client integration and verification.

## Time and authority

The VPS, Node process, database and database sessions remain **UTC**. Calendar ownership uses explicit `Asia/Kolkata` monthly bounds and database admission time. API instants use UTC ISO strings; `timezone: "Asia/Kolkata"` identifies season display/calendar semantics. A season is `[startsAt, endsAt)`; October 2026 ends at `2026-10-31T18:30:00.000Z`.

PostgreSQL owns admitted matches, settlements, XP, Elo, qualification and archives. Redis owns temporary search tickets and claims. Queue estimates never become settlement inputs. Reads create no season/player records. Existing pre-launch history remains unrated.

## HTTP routes

All routes below are under `/api/v1/pvp`, require JWT authentication and completed registration, and use the existing `{ success: true, data }` envelope. Owner identity comes from JWT; an arbitrary `userId` query is rejected. Responses use `Cache-Control: private, no-store`. Ranked reads and history share a per-host, per-owner budget of 60 requests/minute.

| GET route | Accepted query | Result |
|---|---|---|
| `/ranked/me` | Optional `seasonId=YYYY-MM`; `fresh=0\|1` | Own standing, season, active/pending match, runtime capabilities and most recent finalized season |
| `/ranked/leaderboard` | Optional `seasonId`; `limit` default 25, maximum 50; optional signed `cursor` | Qualified public entries, exact ordinal per observation, pagination metadata and next cursor |
| `/ranked/seasons` | `limit` default 12, maximum 24; optional `before=YYYY-MM` | Own played seasons, descending month, plus current-season context and `nextBefore` |
| `/history` | `page` default 1, maximum 1000; `limit` default 10, maximum 50; optional `seasonId`; `includeVoids=0\|1` | Existing match history plus own rating event and settlement metadata |

Numeric queries accept decimal integer strings within bounds. History offset `(page - 1) * limit` cannot exceed 10,000. Duplicate/array queries, unknown keys, malformed months, empty cursors and cursors longer than 2048 characters fail validation. Explicit unknown seasons return 404. The implicit current month can be returned as a `NOT_STARTED` preview if its persisted season does not exist.

`GET /matches/:matchId` remains the participant-authorized recovery snapshot. `POST /replay/:matchId` retains zero-reward Practice behavior; an unsettled rated result cannot be replayed even if a damaged/intermediate record looks completed.

### Own summary and seasonal history

`me` returns `serverNow`, `asOf`, `timezone`, `currentSeasonId`, `season`, `standing`, `activeMatch`, `seedPending`, `capabilities`, and `lastFinalSeason`.

The `season` object contains `id`, UTC `startsAt`/`endsAt`, `timezone`, `policyId`, `status`, `finalizedAt`, and `eligibleCount`. Status is `NOT_STARTED`, `UPCOMING`, `ACTIVE`, `CLOSING`, or `FINALIZED`. Missing archive data stays null.

`standing` separates:

- `league` and `qualified` from lifetime `ratingIsProvisional`. Monthly qualification can be unfinished after the lifetime provisional period ends.
- Numeric `rating`, `placements`, `played`, `wins`, `losses`, `draws`, `peakRating`, `version`, and `hasRecord`.
- Qualified `position` and `positionKind: "ORDINAL"`. Unqualified position is null. `positionAsOf` is the live observation or archive time.
- `nextLeague` with target league/rating, remaining rating and normalized progress. Unranked/Diamond have no next tier; Bronze's unbounded lower interval has null progress.

Without a current row, the summary previews the latest prior rating/career count or the initial 1200. It does not assign a league before qualification or write a standing. `seedPending` warns that an unresolved match can still change the eventual seed. No fabricated zero rating or global position is returned for unavailable data.

`activeMatch` is discovered independently of the requested season and can point into a previous month. It contains `matchId`, `seasonId`, `status`, `stateVersion`, and `recoveryState` (`RESUMABLE` or `RESULT_PENDING`). Phase 4 should offer authoritative recovery before a new search. `lastFinalSeason` contains the latest played archive's rating/league/position/peak.

`capabilities` includes `reads`, `skillMatchmaking`, `admissionPaused`, and `ratedAdmission`. These describe configured availability and season/launch gating; they are not a live Redis health guarantee. Admission still rechecks all requirements.

Season history includes only rows with at least one rated result, excluding idle/void-only rows. Closing months expose `resultsFinalizing`. Finalized rows use frozen rating/league/peak/position; non-final history positions stay null (request `me` for the live exact position). There is no per-row rank query loop.

### Leaderboard semantics, cursors and caches

Only qualified players appear publicly. Entries whitelist `userId`, display `name`, `avatarUrl`, `rating`, `league`, and `position`; no email, auth, raw user object or opponent ledger is exposed.

Ordering is **rating descending, UUID ascending**. Positions are unique ordinals 1, 2, 3, including equal ratings. The same tie rule governs live own position and frozen final positions. A league is a rating band, not a leaderboard position.

A bounded SQL page selection and correlated indexed counts compute each returned live ordinal against the complete eligible season within one Repeatable Read observation. The cursor's old position is never used to invent a current rank. Final boards use frozen final rating/position. This query shape is implemented but has **not** had PostgreSQL EXPLAIN or latency measurements; index usefulness and production cost remain rollout checks.

Cursors are HMAC-SHA256 signed, versioned, canonical base64url, and expire after five minutes. They pin season, policy and LIVE/FINAL mode. Altered/expired cursors, current-month rollover, and a LIVE-to-FINAL transition return `400 CURSOR_RESET`; the client should discard that pagination chain and fetch the first page. Cursors are public-board tokens, not private owner credentials.

Each response carries `asOf`. `pagination: "LIVE_MAY_MOVE"` means subsequent pages may miss/repeat entries after rating movement; each returned ordinal is exact for its own observation. Deduplicate by user ID and allow refresh. `FINALIZED_STABLE` means archived ordering is frozen; signed cursor expiry still applies.

Own summaries and shared identity-independent first board pages use bounded, single-flight in-process caches, at most five seconds. Query latency consumes that TTL. Active-month expiry is truncated at rollover. Admission/settlement/void invalidates affected owners and board caches, including uncertain commit outcomes. Cursor pages and seasonal/match history bypass these caches; `fresh=1` bypasses the own-summary cache. Clients should fresh-read after results/reconnect and respect versions/as-of times.

### Existing Home/Profile and result contracts

Home/Profile gain an optional `rankedLeague` section. It returns `{ status: "AVAILABLE", ...me }`, `{ status: "DISABLED", retryable: false }`, or `{ status: "UNAVAILABLE", retryable: true }`. Existing Home `ranked` match data, Profile identity, XP and learning fields remain intact. A temporary Ranked read failure does not fail the rest of those responses.

History preserves its existing `history` and `pagination` fields. Added fields include `seasonId`, `disposition`, `outcomeReason`, `settledAt` and own `rating` (stable `eventId`, `before`, `delta`, `after`, league change, `changeKind`, `seasonVersionAfter`). No opponent Elo delta is returned. History remains completed-only by default for existing clients; `includeVoids=1` also includes cancelled `SYSTEM_VOID` records. Unrated/void rows have null rating data, not invented `+0 Elo`.

Participant result/reconnect snapshots carry stable rating event/version data, terminal `settlementId`, `settledAt` and disposition. `stateVersion` is included in answer acknowledgements, round feedback and question-start events. Phase 4 must deduplicate rewards/animations by authoritative event ID/version and preserve absolute-XP reconciliation. Old clients keep their existing fields.

### Errors

Failures use `{ success: false, code, message }` with safe public messages. Typical cases are `INVALID_QUERY`/`CURSOR_RESET` (400), `UNAUTHORIZED` (401), `REGISTRATION_REQUIRED` (403), `SEASON_NOT_FOUND` (404), incompatible client or pending/stale match (409), request budget (429), and disabled/unavailable authority or queue (503). HTTP 429/503 include `Retry-After`. Internal SQL/Redis errors are not serialized.

## WebSocket search and admission

Authenticate using the existing channel. A Phase 4 client opts into rated contracts with:

```json
{"type":"JOIN_MATCHMAKING","payload":{"rankedCapability":1}}
```

An old empty JOIN remains valid while rated admission is off. Once rated admission is active, clients without capability 1 receive `RANKED_CLIENT_UPDATE_REQUIRED`. Client-provided ratings, league, season, policy, queue nonce or admission time are rejected. Server eligibility reads the effective current standing and blocks incomplete registration, friendly seats and active/unresolved competitive matches.

`LEAVE_MATCHMAKING` retains an empty payload. `QUEUE_STATUS` includes `WAITING_FOR_OPPONENT`, `PAIRING`, or `LEFT_QUEUE`, with own `waitedMs`, `searchExpanded`, `ratingWindow`, and Redis-derived `serverNow` where available. A claim that wins before cancellation returns `PAIRING`, and the client must wait/resume the admitted match. A late JOIN awaiting eligibility is fenced by a later leave; an outdated socket close cannot cancel a replacement's ticket. Repeated JOIN preserves the original waiting age.

`MATCH_FOUND` adds `seasonId`, `policyId`, immutable `ratingMode`, `admittedAt` and public player league to the existing match/player data. Continue the persisted ready/question lifecycle; never start a fresh local round clock from a reconnect event. On initialization/network uncertainty, refresh `me` and recover any match before searching again. A committed match remains recoverable even when Redis cleanup or delivery fails.

### Search defaults

| Parameter | Implemented default / rule |
|---|---|
| First 60,000 ms | Similar rating within ±100, for the entire minute |
| At 60,000 ms | First expansion to ±150 |
| Thereafter | Expand by 50 every 15,000 ms, capped at ±600 |
| Pair compatibility | Gap must fit **both** players' waiting windows; same season, policy and rating mode |
| League boundaries | No hard boundary; provisional status creates no separate queue wall |
| Recent opponent | Soft preference for another candidate when an alternative exists in the bounded shortlist; five-minute recent-opponent observation |
| Elo | Ordinary approved Elo; no upset bonus or queue-based adjustment |

Configurable numeric controls are `RANKED_QUEUE_NARROW_WINDOW` (1–400), `RANKED_QUEUE_EXPAND_INTERVAL_MS` (5000–60000), `RANKED_QUEUE_EXPAND_BY` (1–200), and `RANKED_QUEUE_MAXIMUM_WINDOW` (100–1600, at least narrow window). The first minute remains fixed. Invalid configuration pauses search through the safe error path.

### Redis ownership and bounded work

The four versioned keys share the `{ranked-v1}` hash tag. One atomic Lua operation handles joins, cancellation, touches, claims, renewal or cleanup using Redis TIME. A claim removes both users from waiting/rating indexes and records a fixed server match/claim UUID and per-ticket ownership tokens. Old cancellation/cleanup cannot remove a replacement ticket.

Queued leases last 45 seconds and refresh every 15 seconds. Claimed leases last 120 seconds and renew every 15 seconds. Expired leases cannot be revived even when bounded pruning leaves expired records behind. Operations have a 2.5-second caller deadline; uncertain late completion is not treated as success. Each operation prunes at most 128 expired records. Pair selection rotates through at most 32 waiting seeds and examines up to 32 rating candidates on each side per seed, preferring nonrepeat opponent, smaller gap, older wait, then UUID. The one-second matcher admits at most four pairs per tick without overlapping itself. Search/leave actions share a six-actions-per-ten-seconds owner budget.

Each queue adapter has a process owner ID. It only claims that process's tickets; a replacement process cannot steal old process tickets. A newly authenticated JOIN can adopt a still-queued ticket with fresh ownership, preserving waiting age; otherwise the lease expires. Claims use both nonce and ticket tokens, and the DB admission revalidates eligibility/rating/version after ordered user locks, resamples authoritative season assignment, and verifies the live lease witness before writing. Lost admission commit acknowledgement rereads the fixed match ID.

**V1 requires one PvP WebSocket host.** Ownership fencing does not provide distributed socket routing. There is no rated local-memory fallback when Redis is unavailable. Legacy FIFO remains only behind skill matchmaking off/rated admission off. Draining prevents new search/admission while existing match recovery, settlement and archival continue. No capacity or throughput guarantee follows from the bounded-work settings.

## Activation and verification boundary

All new controls default off. No environment file, launch month, server/database timezone, live schema or deployment was changed.

| Control | Purpose |
|---|---|
| `RANKED_LEAGUES_READ_ENABLED` | Dedicated read APIs and optional Home/Profile league sections |
| `RANKED_SKILL_MATCHMAKING_ENABLED` | Redis skill queue |
| `RANKED_ADMISSION_ENABLED` + `RANKED_LAUNCH_SEASON=YYYY-MM` | Rated admission after the approved launch instant, with reads/skill queue and compatible clients required |
| `RANKED_ADMISSION_DRAIN` | Pause new competitive admission/search; retain existing obligations |
| `RANKED_CURSOR_SECRET` | Cursor signing secret, at least 32 characters; falls back to `JWT_ACCESS_SECRET` if absent; a separate secret is preferred |

The additive Phase 2 schema is still required before this backend runs, including with admission disabled. See `backend/prisma/changes/README.md`. No Phase 3 DDL was added.

Deterministic tests run service/transport logic with inert dependencies. Board fixtures use an array oracle and inspect parameterized SQL; they do not execute SQL. Default test runs do not execute Redis Lua. The opt-in PostgreSQL suite additionally prepares completion/admission races, rollback/unknown commit/restart checks, actual live/final SQL pagination and frozen history. The separate Redis suite prepares real Lua ownership/cancellation/widening/expiry/race checks. Both are intentionally skipped until their dedicated environments and operations are separately authorized. No EXPLAIN, live query latency, load test, VPS or native-device check was performed.

Phase 4 has implemented the Flutter models/repository/controllers, league badges and Home/lobby/Profile/result/leaderboard/history presentation against these contracts. See `RANKED_LEAGUES_PHASE_4_HANDOFF.md` for coverage, rendered evidence and remaining live/native integration checks. The user's login-screen changes were preserved. No release or live-data operation is authorized by the completed source phases.
