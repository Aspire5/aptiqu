# MANUAL UI VERIFICATION — PHASE D

**Historical Phase D review guide — explicitly APPROVED with `APPROVE PHASE D`.** Phase E subsequently implemented the next authorized scope; use its review guide for the current checkpoint. These D instructions and evidence remain preserved.

The approved palettes, fonts, font sizes and tokens remain. This phase improves Practice setup/history/player and Daily hub/quiz, including O08–O14/O22. Question IDs, ordering, option IDs, validation, timers, replay rules, reward calculations and API payloads remain. Small controller changes expose persistent UI errors, prevent duplicate preparation and expose existing paginated history APIs; they do not add server operations.

## Start and inspect both themes

1. From the repository, run `flutter run --debug --no-pub -d 1025631386112547` for the currently connected Infinix X6739 (Android 14), using your normal API configuration. If the device changes, use its current `flutter devices` ID. The debug APK is `build/app/outputs/flutter-apk/app-debug.apk`.
2. Sign in with an existing account whose registration is complete. Home → avatar/name → Profile → Appearance → Light.
3. Return Home and follow the screen checks below. Repeat with Dark. Also select System and change OS appearance while Practice or Daily is open; these destinations should follow it.
4. Check a normal phone, landscape and enlarged system text. A short Practice viewport moves the header/action into its scroll instead of squeezing the settings. No fonts are reduced to force fitting.
5. Use existing history, live questions and intended attempts. No database setup, account reset, seeded rewards or infrastructure access is required or authorized. Empty/error/completed states may depend on your account/server; safe rendered fixtures are available below when a real state cannot be reached.

## PracticeCatalogView — setup (S06)

Source: `lib/features/practice/views/practice_catalog_view.dart`; Home shell boundary: `lib/features/home/presentation/screens/home_screen.dart`.

### Reach

1. Home → **Practice** in the bottom navigation.
2. Inspect **Random**, then **Custom**.
3. In Custom, choose a subject, expand a topic and select individual subtopics. Try **All** and **Clear**.
4. Toggle **Friendly duel**, **Smart AI Picks** and **60-second timer**. Restore your intended settings before starting.

### Changed / visual checks

One compact question summary, consistently aligned setting rows and lighter expandable topic groups replace nested cards/decorative dashes. Subject choices show a readable check/selected state. The primary action is **Start practice** or **Invite a friend**. It stays below the scroller at normal height and joins scrolling when height/text scale requires it.

Check title/selection contrast, 48 px targets, multiline subject/topic labels, balanced spacing and the disabled-action explanation after Clear. Random/Custom reflows into whole native choices when an enlarged segmented layout would not fit.

### Functional checks / expected result

Subject changes, whole-topic/partial-topic/individual checks, All/Clear and preference restoration retain their meanings. Clear disables starting Custom practice and explains why. No catalog disables starting honestly. A failed catalog load offers Retry. Starting/preparing disables configuration/repeated starts. Friendly duel still opens the existing friend picker; that picker and duel-room redesign belong to E. Cancelling the picker returns safely with the existing choices.

## PracticeCatalogView — history & replays (S07)

### Reach

1. Home → Practice → the **History & replays** icon at the upper right.
2. With existing entries, inspect dates, status, score/time, XP and Replay. Scroll to **Load more** when another page exists.
3. Pull to refresh. Use **Back to practice** and Android Back separately.
4. Choose **Replay** on an intended existing entry to open the player.

### Changed / visual checks

History uses grouped metrics and divider-separated rows with full local dates, readable status/reward text and native Replay actions. Cached refresh errors leave entries visible with a compact Retry notice; initial loading/error/empty states are distinct. Shared preparation feedback labels a pending replay and locks repeated launches.

Check long dates/status, metric wrapping, neutral no-reward labels, readable Replay/Load more and both back paths at enlarged text.

### Functional checks / expected result

Both back controls return to setup. Refresh replaces the list; Load more appends the next existing API page. A failed page leaves entries/page position intact so retry does not skip it. A replay preserves its session/question IDs and earns no replay rewards. If your account has no history, inspect the honest empty state and the fixture captures rather than creating artificial records.

## PracticeSessionScreen — player, hints, preferred method, result and exit (S08 / O12–O14)

Source: `lib/features/practice/views/practice_session_screen.dart`.

### Reach

1. Home → Practice → choose intended options → **Start practice**, or History & replays → Replay.
2. Select an answer → **Submit answer**. Review correctness, correct answer and available methods. Use **Next question** / **Continue to summary**.
3. On a question with hints, tap the top **Hints** lightbulb → **Reveal hint 1**, then the next available hint. Close and reopen.
4. When a method is marked **AI preferred**, tap it to open the reason sheet; use **Got it** or Close.
5. Tap **Exit practice** or Android Back → **Keep practicing**. Confirm **Exit (0 XP)** only when you intend to abandon that real attempt.
6. Finish an intended session/replay to inspect its summary → **Return to practice**. Friendly scores require an existing friendly session launched through the existing flow.

### Changed / visual checks

Question count/progress, optional timer and adaptive friendly metrics sit above a readable prompt. Native answer tiles expose selection and feedback with text/icons as well as color. Prompts, options and explanations use the approved 16 px reading role. Methods read as continuous sections; the primary Submit/Next pair remains consistent. Hints/reasons have shared bounded, scrollable surfaces with visible Close. Missing explanations/reasons are labelled honestly. Completion scrolls and displays actual returned XP.

Check long prompts/options/source labels, selected/correct/incorrect contrast, both method headings, hint count, reachable sheet actions and scrollable completion/exit at 2× text and landscape. Normal question content should be compact and calm, without repeated nested cards.

### Functional checks / expected result

Selecting does not submit. Submit locks repeat requests; a failed submission retains selection and shows **Retry answer**, while the existing recovery/timer behavior remains. Next advances once and resets per-question hints/selection. Opening/reopening a hint sheet never reveals a hint by itself; 0/1/2 available hints stay honest. No Daily hint feature is added. Timed/untimed/replay/friendly sessions retain their existing clock and reward rules. Keep practicing preserves the question; Exit abandons with zero completion XP. Replay completion clearly states no rewards. Friendly summary retains **Duel score & rewards** when its ID is available.

Friendly clock failure still offers Retry; a duel that has ended shows a return action. These failure/data variants are covered by fixtures and need not be manufactured on a real account. An invalid `/practice-session` entry without session data now offers **Return to Home** instead of casting/crashing; normal typed route extras are unchanged.

## DailyStreakHubScreen — availability, history and preparation (S12 / O08–O09)

Source: `lib/features/daily_challenge/presentation/screens/daily_streak_hub_screen.dart`; route `/daily-streak`.

### Reach

1. From Home, tap the top flame/streak control (also available from the Daily Challenge dashboard section).
2. Inspect today’s availability, **Start daily challenge** / **Resume challenge**, streak/best streak/average speed/coins and **Tiers and daily questions**.
3. Tap the upper **Daily history** icon. Inspect entries, Close and Load more when available.
4. Start/resume only an intended daily attempt. Observe preparation and the transition to the quiz.

### Changed / visual checks

The visible title is **Daily challenge**. Availability/action comes first, followed by one grouped streak region and concise essential rules with expandable tiers. A small flame supports the streak; the old gradient/glow hero is removed. Coins are quiet metadata. History uses the shared sheet, readable statuses and wrapping metrics. During preparation, the body labels the task and Back/History are disabled until the existing request resolves; no cancellation operation was invented.

Check normal-phone hierarchy, long tier/large values, both theme pairs, visible History/Close, history at enlarged landscape and preparation readability. Missing average speed is Unavailable, not fabricated zero.

### Functional checks / expected result

Server eligibility still controls starting. An in-progress participation shows Resume; completed/failed/unavailable attempts do not offer a new start. The displayed cycle is **midnight IST (UTC+5:30)**, matching the existing server implementation. Status errors offer Retry; a cached failure retains availability details. Preparation failure exposes an inline error and unlocks retry. History failure is distinct from empty; existing entries survive refresh/load failures and pagination can retry. Returning from the quiz refreshes availability. Live eligibility and midnight rollover require an appropriate account/time and were not simulated by modifying server data.

## DailyChallengeQuizScreen — question, persistent feedback, result and exit (S13 / O10–O11/O22)

Source: `lib/features/daily_challenge/presentation/screens/daily_challenge_quiz_screen.dart`; route `/daily-challenge-quiz`.

### Reach

1. Home → streak/flame → Start daily challenge or Resume challenge, when eligible.
2. Select one answer → **Confirm answer**. Read the persistent explanation sheet; scroll through both available methods and any preference reason.
3. Use **Next question**; on the final answer use **View result** → **Return to daily challenge**.
4. During an unfinished question, tap **Leave daily challenge** or Android Back → **Stay**. Choose Leave only when intended.

### Changed / visual checks

Progress, seconds remaining and wrapping metadata replace the compressed timer/header treatment. Options share the native Practice presentation while preserving Daily’s separate confirmation behavior. Persistent feedback uses the actual remaining body height, with scrolling header/methods and a safe fixed Next/View result action. The underlying question’s pointer/focus/semantics are excluded during feedback. Results scroll, group actual score/streak/XP/coins and avoid implying a second reward claim. Invalid/empty sessions offer **Return to daily challenge**.

Check option selection, timer visibility, long provenance/explanation/preference, correctness/answer labels and reachable footer/result/Stay/Leave at 2× text and landscape. If the supplied result cannot distinguish incorrect from timeout, it says **Incorrect or timed out**.

### Functional checks / expected result

Selection alone does not submit. Confirmation/submitting locks selection and repeat requests. Timeout keeps the existing submission behavior; Next advances once and resets the existing 60-second timer. Answer errors retain selection and expose Retry answer. Correct and unsuccessful results display the returned values, not invented rewards/streak facts. View result only displays the already-recorded result. Leaving retains the existing open-attempt/timer behavior: the current timer continues and remaining questions must be resumed before midnight IST. Stay does not change the current question. No hints are introduced.

## Shared presentation and migration boundaries

`lib/shared/widgets/questions/question_presentation.dart` has real Practice/Daily consumers: AnswerOption, QuestionMetadata, AnswerFeedback, QuestionSolutions, SessionMetrics and compact SessionNotice. They own presentation only. Existing button/loading/sheet/theme primitives are reused. Check keyboard Tab/Enter and screen-reader selection/correctness/disabled labels on the device; fixture semantics checks do not substitute for a real assistive-technology session.

Profile → Appearance now applies to Practice and Daily as well as the previously migrated surfaces. Ranked, Friends/friend picker/duel rooms, routed lessons and global overlays retain their scheduled boundaries. No theme tokens, dependencies, auth flow, data models, repositories/endpoints, authored content, backend, database, migration or VPS changes were made in D.

## Evidence and validation

- `test/phase_d_learning_test.dart`: **35 passed**, including both-theme layouts, selection/tri-state settings, hint counts, method reasons, failure/retry, cache/pagination, duplicate preparation/submission/Next, countdown expiry/reset, friendly clock recovery, safe invalid routes, semantics and semantic-pair contrast ≥4.5:1.
- [ui_ux_phase_d/README.md](ui_ux_phase_d/README.md): **60 actual rendered PNGs** with production font fixtures. Normal 390×844 light/dark setup/custom/history/player/hints/reason/feedback, Daily hub/resume/completed/history/preparation/player/feedback/result/status-error; 320×568 at 2× for long Daily feedback; 568×320 at 2× for Daily next/question and replay summary; both sizes/themes at 2× for hint/exit/history/result overlays. Additional functional fixtures cover 320×568/2× Practice setup, missing data, submission/start failure and short 150 px Practice viewports.
- PNGs are fixture renders, not authenticated device screenshots. Safe learner/question fixtures do not represent real account performance. Prior phase captures and all golden baselines remain untouched.
- `flutter analyze --no-pub`: **no issues**. `git diff --check`: **passed**.
- Full `flutter test --no-pub`: **164 passed, 9 failed tests**, all old golden comparisons across ten Home/Topics/Practice/social images. The Practice screenshot also intentionally changes in D. Baselines were not overwritten. No non-golden failure remains.
- `flutter build apk --debug --no-pub`: **passed** on the existing Android toolchain. Device discovery found the Infinix X6739; no install, authenticated live quiz/reward run, native screen-reader/keyboard session, iOS build or release test was performed for D.

Start with the normal compositions, then inspect enlarged-state captures for reachability. Full-height scrolling at 2× landscape is deliberate; a no-overflow check alone does not prove the design is pleasing.

**Phase D is complete and awaiting your manual review.**

**Please inspect the listed screens in both light and dark mode and test the specified interactions.**

**Reply with `APPROVE PHASE D` to authorize the next phase, or `REVISE PHASE D: ...` to request changes.**

**I will not proceed until you explicitly approve.**
