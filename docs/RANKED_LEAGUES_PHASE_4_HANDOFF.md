# Ranked Leagues — Phase 4 frontend handoff

Updated 20 October 2026 (IST). The user authorized Phase 4 with “proceed with the next phase.” Flutter source, focused integration fixtures and local render/build verification are complete. This is ready for manual review; no release, live-data operation or rated activation was performed.

## Implemented experience

| Surface | Behavior |
|---|---|
| Home | Uses the existing Ranked region for league artwork, Elo/global position or placement progress, month and finite next-tier progress. Existing learning/Daily/consistency priority and Ranked-tab callback remain. Older responses without `rankedLeague` keep the existing last-match/start presentation. |
| Own Profile | Appearance remains immediately below identity. Ranked this season follows it, with league, actual Elo/ordinal, W/L/D, qualified peak, Leaderboard and Season history. Optional disabled/unavailable data stays separate from XP/learning. |
| Ranked lobby | Compact standing before Find match; month/end in explicit IST; stats and accurate rules below the main action. Active/previous-month unresolved matches offer Resume match or Check pending result. Server search widening, PAIRING, cancellation, errors and paged recent history remain distinct. |
| Leaderboard | `/ranked/leaderboard`, selected month, qualified rows, actual per-page ordinals, public profile whitelist, finite pages and own-standing strip. Equal-rating order is explained. Cursor resets discard the old chain; movement is deduplicated by learner ID. |
| Season history | `/ranked/seasons`, played months only, frozen final league/rating/position/qualified peak/W/L/D, closing/incomplete states and links to that month's board. More months are reachable through paging. |
| Arena/result | Retains live question/answer/score behavior and authoritative exit restrictions. Committed own results show before → after, signed delta (including zero/negative draw deltas), league change, actual XP and the result's admission month. Recovered committed results use the same presentation. Unrated and server-confirmed system void remain explicit. |

Both routes use the existing router/auth/onboarding guards and preserve underlying navigation state. No public learner-history expansion or unrestricted profile navigation was added.

## Data and ownership

`lib/features/pvp/ranked/` contains typed DTOs, the repository, badge/standing sections, paginated browser and inline result presentation. Home/User/history models parse additive fields without changing their prior contracts. Missing/malformed optional league data does not become zero Elo or a fabricated league.

The repository uses the existing authenticated Dio client, a 15-second read receive timeout, safe typed failures and per-owner `Retry-After` cooldowns. It does not poll. Own summary refreshes use `fresh=1`. Current summary is fetched separately from historical results, so a late old-month result does not overwrite the current month's standing. Existing server flags stay authoritative; a lobby preview does not claim rated admission is open.

Lobby reads coalesce, reject stale owner/version responses, and refresh on return from arena. The server remains the final active-seat/admission authority if a standing read fails. New sockets opt into `rankedCapability: 1`; they do not submit rating, season, policy or nonce. PAIRING cannot be represented as a successful cancellation. Waiting-window expansion follows server state, not the local elapsed label. An independently keyed rules expansion avoids a scroll-state collision during queue-region rebuilds.

Arena events reject older `stateVersion` values. A rated record with pending disposition stays in recovery rather than inventing a terminal result. Existing absolute-XP reconciliation and duplicate-result guards are retained. Account changes clear the lobby's pending presentation and owner-bound data; Home dashboard requests also reject the previous account/generation. Browser responses are fenced by account and selected-request generation. The singleton WebSocket also fences pending token lookup, incoming events and outgoing actions by account/connection generation; an old connect completion cannot clear a newer connection attempt or open with a previous account token.

Dates are parsed as UTC instants. Month/end labels use explicit UTC +05:30 formatting for modern IST, independent of device timezone. There is no host/process/database timezone change.

## Artwork and motion

All six supplied WebP files are explicitly bundled via `assets/images/ranked/`. `RankedLeague` maps the actual enum values to their existing filenames. `RankedBadge` preserves transparency and artwork, uses size/device-ratio-bounded decode dimensions, semantics and an icon fallback. Adjacent text identifies the league even when an image fails. No art replacement, palette/type change, new font or dependency was introduced.

`RankedResultView` presents promotion inline with a finite 900 ms old-to-final badge fade/scale; placement completion uses the same restrained reveal. Demotion is static/neutral. Text and Return to Ranked remain available throughout. It does not sequence intermediate tiers or add rewards.

Cosmetic receipts are stored separately per account in existing secure storage, bounded to 256 event keys. The `(season,eventId)` receipt is written before motion; duplicate/recreated results cannot replay it. Storage failure leaves the static result. Old-month/stale results show their actual text without promotion motion. Visibility/account/lifecycle checks prevent background/modal presentation, and backgrounding settles to the final badge. Both `disableAnimations` and the SDK's platform `reduceMotion` signal settle immediately. No new global celebration overlay competes with XP/invitations. The production receipt store has deterministic duplicate/account/season tests; widget animation tests inject an inert receipt callback to avoid cross-test platform-channel scheduling.

## Verification evidence

| Check | Result |
|---|---|
| New Phase 4 tests | **38 cases** covering contracts/optional data, UTC→IST, cosmetic receipt ownership, Retry-After, queue/claim/cancel, stale owner/version events, pending settlement, manifest/badges, paging/reset, actual recovered arena results and rendered composition/motion |
| Combined affected-screen suite | **106 passed**: Phase 4 + Phase 1 arena recovery + Home dashboard/navigation + existing account/Profile tests. The user's current Login/Signup checks also passed in this run; their source/tests were not rewritten. |
| Existing Ranked regression run | **27 passed** across the retained Phase 1 and Phase E queue/arena/result/recovery cases; overlaps the combined run's six Phase 1 cases |
| Flutter analysis | No issues after final lint corrections |
| Debug APK | `flutter build apk --debug --no-pub` passed; `build/app/outputs/flutter-apk/app-debug.apk` |
| Whitespace | `git diff --check` passed; new Ranked sources/docs also checked |
| Actual rendering | **24 PNGs** with production-font fixtures and decoded badge images; [index](ranked_phase4/README.md) |

Normal renders use 390×844 in Light/Dark. Focused hard cases use 320×568 at 2× text for lobby, leaderboard and result; existing Profile/arena/account regressions also cover their established narrow/landscape/enlarged envelopes. Long names and six-digit positions are included. Leaderboard composition measures real text/available space before giving long names a full-width row. New controls retain native/shared 48 px targets and semantic labels. Screenshots are safe fixtures, not production account results; some are deliberately scrolled to the relevant section.

The Home compatibility golden passes unchanged; no baseline was accepted merely to suppress a failure. Two existing queue tests now flush the added background read before teardown; their behavioral assertions remain. No full historical Phase G sweep, native screen reader/device exercise, live two-client battle, actual PostgreSQL/Redis test or capacity measurement is claimed.

## Manual review

1. Review the light/dark lobby and Home/Profile images in the index. Confirm the approved type/palette, clear Find match, Appearance placement and distinction between Elo/global position and XP.
2. Review the enlarged-text leaderboard/result images for readable names, safe scrolling and reachable Load more/Return. Review the actual arena result captures for the previous-month label and genuine signed delta/XP.
3. In a separately authorized prepared test environment, exercise new-account placements, monthly requalification, qualified/unqualified/closing/final boards, empty/error/retry/old-client states and more than one page of results/history.
4. Verify reconnect and app restart find active/pending matches; duplicate delivery/reopen does not repeat XP or promotion; a late prior-month result stays in its own month. Check account switching and foreground/background/reduced-motion on actual devices.

## Before activation/release

The standing environment restrictions are unchanged. The additive Phase 2 SQL is still unapplied; real PostgreSQL constraints/locking/archive/query plans and Redis Lua/failure behavior are unverified. Those need separately authorized disposable environments and the gated suites in `backend/prisma/changes/README.md`. The local client fixtures do not replace them.

Before a separately approved activation, verify the schema and real service integration, compatible clients, cursor secret, explicit launch month, runtime flags/drain and one-WebSocket-host routing. Measure the actual query plans/latency and target load only under a separately scoped campaign. Confirm native accessibility/motion/navigation and supplied artwork redistribution records before public release.

All read/skill/admission flags remain off by default, no launch month was selected and nothing was deployed. The VPS/server/database remain UTC. The existing live-match exit restriction remains; no Forfeit or Return-while-reconnecting policy was invented. No future phase or release is implicitly authorized. The user's login screen, login assets/tests, platform icons and unrelated edits were preserved.
