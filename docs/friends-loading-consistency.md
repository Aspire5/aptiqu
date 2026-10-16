# Friends, shared loading and consistency

The app uses the original violet/cyan orbiting `AptiquLoadingIndicator` through
`AppLoader`. Indeterminate API loaders share a 250 ms appearance delay. Persistent
loading slots retain an already-visible indicator for at least 350 ms, without
delaying API completion or blocking the newly loaded content. If a whole loading
screen is replaced by content, that replacement happens immediately. Timers are
cancelled on disposal. Small button slots constrain the ring to their actual size.
Determinate progress bars and countdown rings still represent progress/time.

Friends is the fifth bottom navigation destination, immediately after Ranked.
The Home shortcut and discovery/friends segmented tabs are removed. Empty search
loads accepted friends in pages of 50. Next/Previous use server cursors; the app
holds one page of people and a small cursor history. Clearing search immediately
resets that history to page 1. The duel friend picker retains friend-only search.

Nonempty discovery search waits 350 ms after typing stops, cancels the preceding
Dio request, and invalidates earlier responses immediately when text changes.
Both cancellation and a request generation check are needed: cancellation alone
does not guarantee an already-completing request cannot overwrite newer results.
The backend ranks case-normalized name/email matches by exact match, prefix, then
substring position, with stable name/ID tie breaks, and returns at most 10 people.
SQL parameters and escaped LIKE metacharacters keep input literal. Email is used
for matching but is not returned in public profiles. Typo correction is not part
of this ranking.

Relations and public profiles load in batches; presence is fetched only for
accepted friends and only those displayed are subscribed through the existing
WebSocket. Online means a live foreground social session with heartbeat expiry,
not merely an unexpired login token. Redis outages show status unavailable.
Friends since uses the accepted friendship's updatedAt: acceptance changes this
timestamp, and accepted friendships have no unrelated timestamp updates today.
Re-acceptance after removal therefore starts a new friendship date.

Request buttons disable while pending. Accepted, outgoing and incoming relations
show Friend, Request sent, and Accept request respectively. Existing transactional
invitation validation, version checks, authorization and rate limits remain in
use. Relationships are reloaded after writes and social change events.

Consistency uses the existing Home aggregate query, changing the daily range to
January 1 through today in IST. The response fills the complete year, including
zero-valued future dates, so it is bounded at 365/366 daily records. No answer
history is downloaded and no month-scroll requests are made. A fixed-height
ListView.builder creates visible month widgets on demand and initially positions
at the current month. Each month shows its first through last date. The window
height accounts for six-week months and larger text. The launch UI has only the
non-interactive 2026 year chip. Calendar and friend date displays use IST.

## Tradeoffs and alternatives

| Decision | Benefit | Cost / alternative |
| --- | --- | --- |
| Delayed shared ring | Fast calls never flash; consistent appearance | A slow call initially has a short blank loading slot. Artificially delaying every response would waste time; skeletons add per-screen layouts and were not requested. |
| Cursor friend pages | Bounded retained people; stable ordering as memberships change | Cannot jump directly to an arbitrary page number. Offset paging offers that, but deep offsets become more expensive and shifting rows can move between pages. |
| Server-ranked search | Searches the whole registered population; returns only 10; no client directory cache | Prefix/substring relevance is less forgiving than typo similarity. Client filtering would miss unloaded people. A separate search service adds synchronization and operations. |
| Existing WebSocket presence | Prompt updates with subscriptions limited to displayed friends | Requires reconnect/heartbeat handling, already implemented. Polling adds recurring requests and delay. |
| One year of daily totals | Predictable small payload; immediate month scrolling; one consistent Home snapshot | A larger initial payload than one month. Month endpoints reduce that payload but add requests, cache invalidation and scroll loading states for only 12 small months. |

Without new indexes, substring/email matching may scan the registered directory.
LIMIT 10 bounds response size, not database work. The existing name prefix index
does not solve arbitrary substring search. At a larger directory size, profile
the real query and add pg_trgm indexes on search_name and lower(email); this also
supports a future typo-tolerant ranking. This is the preferred next scaling step,
rather than adding an external search system. No database was connected, created,
modified or migrated for this task, so live query plans/latency and real-device
frame timing remain unmeasured.

## Validation

Tests cover loader delay/minimum visibility/disposal and small slots; friend
pagination reset, email query, inline request, stale response protection and
presence events; month boundaries, complete months, larger text and day details;
backend bound SQL, search ordering/relation enrichment and year/leap-day totals.
Backend tests stub Prisma/transport calls and use dummy environment values.
The Home golden was regenerated and visually inspected.

Final results: backend TypeScript build passed; 18 Home/social backend tests and
16 focused Flutter tests passed. Full Flutter suite: 39 passed, one Practice
golden mismatch. Replacing PracticeCatalogView temporarily with its HEAD version
reproduced the identical 4.51% mismatch; its baseline was left unchanged. Static
analysis reports only the existing lesson_feed_controller.dart:91 braces style
lint. These checks do not establish production database latency or device FPS.

References: [Flutter ListView.builder](https://api.flutter.dev/flutter/widgets/ListView/ListView.builder.html),
[Prisma cursor/offset pagination](https://docs.prisma.io/docs/orm/v6/prisma-client/queries/pagination),
[PostgreSQL pg_trgm](https://www.postgresql.org/docs/18/pgtrgm.html).
