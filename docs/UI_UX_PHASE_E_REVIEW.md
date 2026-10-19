# MANUAL UI VERIFICATION — PHASE E

**Historical Phase E review guide — explicitly APPROVED with `APPROVE PHASE E`.** Phase F subsequently implemented the next authorized scope; use its review guide for the current checkpoint. These E instructions and evidence remain preserved.

This phase covers S09/S10/S14–S17, O19 removal and O20 incoming invitation presentation. It carries forward the approved palettes, typography, font sizes and composition preferences. Shared controls now have real social/Ranked consumers; no design tokens changed.

## Start and repeat in both themes

1. Run `flutter run --debug --no-pub` with your normal API configuration and selected device, or install the debug APK at `build/app/outputs/flutter-apk/app-debug.apk`. Use `flutter devices` if a device ID is needed.
2. Sign in to an existing account with registration complete. Home → avatar/name → Profile → Appearance → **Light**. Return Home and follow the checks below, then repeat in **Dark**.
3. Select **System (Default)** and change OS appearance while an E destination is open. Friends, learner profiles, duel rooms, Ranked and these scoped dialogs should follow it without restarting navigation or the match. Changing appearance must not submit an answer or cancel matchmaking.
4. Repeat at normal text size, enlarged system text and landscape. Long names/numbers must remain available through wrapping/scrolling. Native actions retain 48 px targets; no font is reduced to force a row.
5. Social requests and duels need another existing account. Ranked matchmaking needs another eligible player; matching cannot be guaranteed on demand. Use intentional real attempts because answers/acceptance/leave/removal affect real server state. Do not seed data, reset accounts or create artificial rewards for this review. Fixture renders provide a safe visual alternative for states your account cannot reach.

[Rendered evidence index](ui_ux_phase_e/README.md). These are Flutter widget renders using production font fixtures and safe example data, not authenticated device screenshots. No live invitation, match, answer, reward or friendship operation was performed during implementation.

## FriendsScreen — Friends, discovery and LearnerTile (S14)

### Reach

1. Home → **Friends** bottom tab.
2. Inspect the existing friends list and inbox icon. Enter a known learner's name in **Search learners**.
3. Tap the learner's identity to open **Learner profile**; return to the list. Where your actual relationship permits it, inspect **Add Friend**, **Request sent**, or **Accept / Reject**.
4. Clear the search, pull to refresh, and use the next/previous page arrows when another API page exists.

### Changed / visual checks

One embedded heading replaces competing chrome. A persistent native search label, stable loading strip, compact identity rows and separate relationship controls clarify the task. Full identities, level, textual presence and friendship date remain readable. Avatar failure uses the person's initial. Long names reflow to full width when the avatar row would be cramped. Pagination targets are 48 px.

### Functional checks / expected results

Identity opens that learner; relationship buttons perform only their labelled action. Search retains the existing debounce, stale-request cancellation and cursor paging. Clearing it restores friends mode. No friends and no search matches have different copy. Refresh failure retains existing rows with Retry. Presence changes update the text as well as the dot. Keyboard opening leaves the list scrollable. Screen-reader focus should expose identity and relationship controls separately, without duplicate buttons.

## FriendsScreen — Invite a friend picker (S14)

### Reach

1. Home → **Practice** → enable **Friendly duel** and choose your intended settings.
2. Tap **Invite a friend**. You need an existing friend eligible for invitation.
3. Search using **Search friends**, then tap the intended friend's identity. Separately, try Back before making a selection.

### Changed / visual checks

The same compact list adapts to a dedicated **Invite a friend** app bar and picker wording. Inspect enlarged names with the keyboard open; scroll to the end of a tall row.

### Functional checks / expected results

Selecting returns that friend's existing ID/data to the invitation flow, rather than opening their profile. Back returns to Practice with its choices retained. An active-duel banner remains directly below search when supplied by the server and opens that existing duel.

## FriendRequestsScreen — Friend requests, FriendRequestCard and FriendshipActions (S15)

### Reach

1. Have another existing account send a friend request to this account.
2. Home → Friends → inbox icon (**Friend requests**).
3. Tap a requester's identity → Learner profile → return. On intended requests, test **Accept** and **Reject** separately.
4. Pull to refresh. If the connection fails, restore it and tap **Retry**.

### Changed / visual checks

A quiet pending count, grouped avatar/name/request date and primary Accept/secondary Reject replace decorative layers and repeated help. Action pairs use equal widths when labels fit and stack when enlarged text requires it. Loading/error/count/rows scroll together on short screens.

### Functional checks / expected results

Profile return refreshes the request state. Accept/reject sends the existing invitation version once; busy controls cannot repeat the response. The count/list reflects the server update. A concurrent change or failed response refreshes current data instead of claiming success. Cached request rows remain visible on refresh failure. An empty inbox says **You’re all caught up**.

## FriendProfileScreen — Learner profile, performance, activity and Remove friend (S16 / O19)

### Reach

1. Home → Friends → tap a friend, discovery result or requester's identity.
2. Inspect identity/relationship controls, then scroll through **Performance**, **Achievements**, **Latest ranked match** and **Learning activity** where the account has those sections.
3. In Learning activity, scroll to another month. Use **View dates as list**, then an available date/day detail. If a remote month fails, restore connectivity and tap **Could not load this month. Retry**.
4. On an existing friend's profile, tap **Remove friend** → **Cancel**. Confirm **Remove** only if you intend to delete that friendship.

### Changed / visual checks

Identity leads, followed by one grouped streak/coins region, aligned performance figures, lighter achievement rows and the existing calendar. Quiet level/XP/presence replace ornamental framing. Large values wrap whole figures without dropping digits. Accuracy and correct-answer time retain their definitions; unavailable results say N/A rather than zero. Removal uses a themed, scrollable native confirmation naming the learner.

### Functional checks / expected results

Relationship variants use the same existing operations. Cancel leaves the friendship intact; confirmed Remove sends one existing deletion and refreshes the relationship. Unknown, offline and online presence are distinguishable in text. Remote months use their requested IST month, cache visited results and retry failed months. The retry callback now avoids an existing Flutter `setState` error. Calendar/date-detail meanings and learner ID are preserved. A profile refresh failure leaves cached details with Retry.

## DuelRoomScreen — Friendly duel lifecycle and leave/back confirmations (S17)

### Reach

1. Home → Practice → Friendly duel → Invite a friend → choose an eligible existing friend. This account is the requester.
2. On the other account, accept the incoming duel or open its existing duel entry; inspect the recipient room before responding.
3. In the pending room, try Back → **Stay**. Inspect the role-specific **Cancel invitation** or **Reject invitation** consequence before confirming only an intended action.
4. In an active duel, use **Resume duel**. Complete an intended session; return to inspect waiting/completed status. To review leaving, tap **Leave duel (no reward)** → Stay; confirm **Leave duel** only if intended.

### Changed / visual checks

Grouped participants, role-specific heading/countdown, compact settings, readable progress/status/XP and contextual actions clarify each state. Initial error replaces loading and offers Retry. Refresh errors retain the room. Active Leave has an explicit no-reward confirmation. Inspect expired, declined, cancelled, own-finished, completed/draw and abandoned states when naturally available.

### Functional checks / expected results

Requester cancellation and recipient rejection keep their existing operations. Pending Back makes its consequence explicit. Active Back retains the existing room-dismissal behavior; it does not silently call Leave. Confirmed Leave uses the existing endpoint. A live status change while confirmation is open cannot execute a different consequence. Resume and `?play=1` auto-open the same session only once. Completed outcome/scores/XP come from server data; own-finished waits for the friend. Invitation expiry remains the existing 60-second budget.

## SocialInvitationDialog — Friend invitation / Duel invitation (O20 presentation)

### Reach

1. Keep this account signed in. Have another existing account send a friend request or a Friendly duel invitation.
2. When the existing invitation delivery presents the dialog, inspect the sender and, for duels, settings/countdown/reward text.
3. Choose an intended **Accept** or **Reject**. Separately allow a duel invitation to expire without responding.

### Changed / visual checks

Native themed, scrollable dialogs preserve readable sender/details and reachable actions in landscape/enlarged text. Busy state reads **Responding…**; errors use the theme's semantic error color. The duel title is **Duel invitation**.

### Functional checks / expected results

Busy controls prevent duplicate responses and expiry must not interrupt an in-flight response. Ordinary failure keeps the dialog and allows retry; existing stale/expired responses dismiss it. Duel expiry refreshes the inbox. Friend response keeps the original invitation version. Global delivery, prioritization against active learning and queued-overlay arbitration are unchanged and remain Phase F work; this phase does not claim those concerns are resolved.

## PvpLobbyView — Ranked queue, recent matches and Practice replay (S09)

### Reach

1. Home → **Ranked** bottom tab.
2. Inspect the summary and expand **Match rules**. Tap **Find match** when you intend to enter matchmaking.
3. While waiting, inspect elapsed time and tap **Cancel**. Wait for server acknowledgement. A second eligible account is needed to inspect automatic entry to a match.
4. Return to Ranked → **Recent matches**. Refresh; on an existing entry tap **Practice replay**.

### Changed / visual checks

The Find match action and compact rules precede history. Queue, cancelling and opening states are distinct. Lighter history rows retain full opponent identities, score/outcome/time/actual XP and a neutral **Replay · No rewards** disclosure. Empty history differs from a failed load; cached matches remain visible on failure.

### Functional checks / expected results

Repeated Find/Cancel/replay cannot launch duplicate actions. Cancel waits for `LEFT_QUEUE`; an unconfirmed cancellation exposes an error and permits retry. A match-found event that wins the cancellation race opens once. History refreshes on return from the arena. Practice replay uses the existing replay API and opens solo Practice, not a new Ranked match, with no replay rewards. Network failure offers a visible retry instead of impersonating empty history.

## PvpArenaScreen — Ranked match, answers, recovery, policy and results (S10)

### Reach

1. Home → Ranked → Find match; wait for the existing server to pair an eligible opponent.
2. Inspect the waiting state, then question/countdown/scoreboard. Tap one intended answer. Wait for server acknowledgement, round feedback and the next question.
3. Tap the information icon or Android Back while live → inspect **Ranked match in progress** → **Got it**.
4. If updates stop or the connection is interrupted, restore connectivity and tap **Refresh match**. For a controlled lifecycle check, background/resume the app during an intended test match and compare with the other account.
5. Finish the match and inspect its actual victory/defeat/draw/AFK result. Tap **Return to Ranked** once. Check Recent matches.

### Changed / visual checks

Full participant names/scores, fixed question count/timer/progress and a scrolling question/options region replace compressed controls. Options share the approved readable native answer presentation. Copy explains that tapping submits immediately. Pending confirmation differs from acknowledged lock. Feedback uses text and marks as well as color; actual explanation remains. Results scroll at large text and show actual XP. Recovery/waiting/error states offer a visible Refresh match action.

### Functional checks / expected results

One tap sends one existing answer payload; repeated taps while pending/locked cannot submit another option. Match timing/scoring remains server-controlled. Appearance changes retain the same controller, question and selection. Recovery waits for authentication, requests the existing `RECONNECT_MATCH`, restores scores and remaining time without resetting a minute, and preserves a pending same-question choice without resubmitting. A timeout permits retry. A completed reconnect snapshot lacks winner/reward fields, so it says **Match finished** and directs you to recorded history without inventing XP. A normal completion uses supplied result/reward fields and returns once.

**Known product dependency:** the current server interface has no active Ranked Leave/Forfeit command. The live exit remains blocked, with explicit policy text and supported refresh recovery. A permanent disconnect/server failure can still prevent completion; this is a separately scoped product/server leave-policy gap (UX-08), not a new forfeit invented in this UI phase.

## Ranked route fallback

### Reach / expected result

1. A normal match enters through Ranked matchmaking; use that path for the arena checks above.
2. A restored or external `/pvp-arena` route without its required match extra cannot create a live match. The safe screen says **No active Ranked match** and offers **Return to Home**.
3. This invalid-extra state is covered by a deterministic router fixture; ordinary application navigation cannot reliably produce it. No debug entry or fake production match was added.

## Verification record and limits

- Phase E focused suite: **48 passed**; final win/draw evidence separation: four related cases passed again.
- Full regression run: **208 passed, nine failed tests**, all preserved golden comparisons across ten images. This full run included the first 44 E cases; four additional lifecycle/accessibility cases then passed in the 48-case focused run. No golden baselines were rewritten. See progress for exact categories.
- `flutter analyze --no-pub`: no issues. `git diff --check`: passed. `flutter build apk --debug --no-pub`: passed.
- Actual rendered evidence uses production font fixtures. Representative normal screens, both theme pairs, long metrics, keyboard/large text, landscape errors and confirmations were visually inspected.
- Authenticated multi-device/server lifecycle, background/process restoration, physical keyboard/system bars, TalkBack/VoiceOver and iOS/release acceptance still require human/device review. Widget fixture evidence does not establish those outcomes.
- No backend, database, VPS, migration, dependency/asset, progression/scoring-rule, model or authored learning-content changes. The existing protocol/endpoints are retained. Global overlay ordering and routed lessons remain Phase F.

Phase E is complete and awaiting your manual review.
Please inspect the listed screens in both light and dark mode and test the specified interactions.
Reply with `APPROVE PHASE E` to authorize the next phase, or `REVISE PHASE E: ...` to request changes.
I will not proceed until you explicitly approve.
