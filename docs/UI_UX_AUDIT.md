# AptiQu Flutter UI/UX audit

Audit date: 18 October 2026. Status: audit and planning only. Companion: [UI_UX_REVAMP_PLAN.md](UI_UX_REVAMP_PLAN.md).

## A. Executive summary

AptiQu is a learning app with guided aptitude lessons, a curriculum map, practice, daily challenges, ranked competition, and social learning. The front end already has recognizable violet/cyan branding, reusable loaders, useful recovery states in several flows, and meaningful small-phone tests. It needs a coordinated presentation-system migration, not a replacement of its product workflows.

The principal systemic problems are forced dark appearance, colors embedded in text styles and widgets, inconsistent action styling, insufficient contrast on important actions, small labels, and uneven accessibility support. The routed lesson player and the Home-embedded lesson player differ substantially. Ranked competition has a more urgent interaction risk: the arena blocks back navigation and exposes no visible recovery/exit while waiting for a question. Several sheets and completion views have no scroll strategy for large content.

The newer Home, topic-details, and social interfaces offer a useful starting point. Preserve their honest empty states, wrapping text, explicit progress labels, and responsive social layouts. Reduce repeated borders, glow, colored metrics, and competing calls to action. Keep violet as the primary brand signal; reserve cyan and amber for specific secondary meanings. Introduce a complete light theme and a coordinated dark theme, following system appearance by default.

**Coverage:** 18 learner-facing screen/view entries, backed by 17 distinct screen/view implementations; one additional shared Home shell; 22 modal/sheet/overlay entries, including two parameterizations of the signup selector. All entries are evaluated below. These counts do not turn individual question nodes, ordinary cards, or result states into separate screens. There are 12 declared GoRouter routes; two lesson routes share one implementation. The Home shell itself is not double-counted as a learner destination.

**Finding register:** 24 consolidated findings: **0 P0 critical, 10 P1 high, 12 P2 medium, 2 P3 low**. P1 includes confirmed accessibility failures and high-impact source-supported interaction risks, not a claim that every failure was reproduced on a device.

## B. Scope and methodology

### Inspection boundaries

Inspected `lib/main.dart`, `lib/core/routing/`, `lib/core/theme/`, `lib/shared/widgets/`, all feature `presentation/screens/`, `presentation/widgets/`, and `views/` directories, and the social screens/widgets/overlay. Controller reads were limited to navigation, visible state/error handling, validation messages, and overlay entry points. No backend implementation, database, infrastructure, API internals, or business algorithms were audited. No app code, dependencies, generated code, assets, or test baselines were changed. No services, builds, migrations, or device sessions were launched.

Discovery followed `main → MaterialApp.router → AppRouter → HomeScreen` branches, direct Navigator pushes, parameterized constructors, node rendering, and every dialog/sheet/overlay call site. Searches also covered `Scaffold`, `PopScope`, `showDialog`, `showModalBottomSheet`, `showDatePicker`, `bottomSheet`, named navigation, text scaling, semantics, and animation flags. Tests were inspected as evidence of intended behavior; they were **not executed** in this documentation task.

The visual-system measurement corpus comprises **55 Dart files**: `main.dart`; three theme files; all files under shared widgets, feature views, presentation screens/widgets; social Dart files except `social_api.dart` and `social_controller.dart`. Routing and targeted controller reads are additional to that corpus. Counts are source occurrences after removing comments, not screen pixel counts, runtime usage, or unique effective rendered styles. Unused presentation components remain in the corpus and are identified below.

### Evidence and evaluation language

- **S — source confirmed:** an explicit declaration, control path, or calculation. This does not prove a complete runtime experience.
- **V — rendered reference:** an existing repository golden PNG was actually inspected. These are saved test fixtures, not fresh device screenshots.
- **R — runtime verification required:** a plausible layout, focus, lifecycle, navigation, or interaction risk whose actual manifestation still requires testing.
- Confidence is **high** for direct source evidence or deterministic contrast; **medium** for inferred user impact or runtime-dependent behavior. A source-confirmed omission can have medium confidence in its actual runtime impact.

The audit applies visibility of system status, consistency, user control, error recovery, recognition, and restrained presentation from [NN/g’s usability heuristics](https://www.nngroup.com/articles/ten-usability-heuristics/), alongside grouping, hierarchy, and platform interaction conventions. Text contrast uses [WCAG 2.2 contrast guidance](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html): 4.5:1 normal text and 3:1 qualifying large text. Meaningful non-text controls target 3:1; decorative borders are not automatically failures. Touch interactions target 48 × 48 logical pixels, consistent with the requested mobile benchmark and [Flutter accessibility guidance](https://docs.flutter.dev/ui/accessibility). This is a practical audit, not a certification of WCAG compliance.

### Rendered references actually inspected

All 11 files in `test/goldens/` were viewed: `home-populated.png`, `home-consistency-phone.png`, `home-day-details.png`, `topics-completed-phone.png`, `practice-random.png`, `practice-custom.png`, `friends-search.png`, `friend-requests.png`, `learner-profile.png`, `learner-profile-large.png`, `learner-profile-empty.png`. Also viewed `assets/images/small_logo.jpeg`: a violet/cyan illuminated owl on a dark background.

The Home and practice goldens display thin type; social goldens display heavier type. Do not attribute that difference entirely to production: fixtures disable runtime font fetching, supply `test/fonts/Outfit.ttf`, and social tests additionally load it as Roboto (`test/social_test.dart:185–245`, `test/home_dashboard_test.dart:73`). Font rendering must be revalidated with production families. The black-looking subject label on a dark selected chip is visible in `practice-custom.png`; the precise runtime inherited color remains to be verified.

The optional UI/UX Pro Max helper search could not run under the available Python interpreter because its own script has an incompatible f-string. Its written guidance was read; no generated palette or template was substituted for repository evidence. External reading was limited to the primary benchmark/theming references cited in these reports.

## C. Complete screen inventory

Paths below are repository-relative; line numbers refer to this audit snapshot. Shared dependencies abbreviated here: **T** = `aptiqu_colors.dart`, `aptiqu_typography.dart`, `aptiqu_theme.dart`; **L** = `AppLoader`; **SC** = social widget family. Every screen inherits the global theme even where it uses default Material styles.

| ID | Screen/view and source | Entry mechanism | Purpose, major sections, dependencies | Important states |
|---|---|---|---|---|
| S01 | Login — `lib/features/auth/presentation/screens/login_screen.dart:13` | `/login`; auth guard | Owl/name, feature strip, Google CTA, error, terms; T, `CyberAmbientBackground`, `AptiquButton` | Idle, signing in, sign-in error, logo failure |
| S02 | Complete profile — `lib/features/onboarding/presentation/screens/signup_screen.dart:14` | `/signup`; incomplete registration guard | Name fields, DOB, gender, religion/belief, country, submit; T, `AptiquTextField`, `AptiquButton` | Prefilled, selected, validation failure, submitting; O01–O03 |
| S03 | Home dashboard — `lib/features/home/presentation/widgets/home_dashboard_view.dart:16` | `/`, Home tab index 0 with `showHomeDashboard` | Daily entry, resume/topics, performance, achievements, Ranked, calendar; T, L, `HomeDashboardContent`, `YearActivityCalendar` | Initial/loading, cached refresh, error, first learner, resume, populated, no metrics |
| S04 | Embedded lesson — `lib/features/home/presentation/widgets/chat_playground_zone.dart:13` | Home tab index 0 after resume/topic/subtopic action | Playing header, tutor/user feed, inline questions/actions; T, `QuestionContainerWidget`, background, thinking bubble | Opening, content, select/text/voice/scan/none input, hint, submitted/feedback, continuation, fullscreen |
| S05 | Topics map — `lib/features/home/presentation/widgets/constellation_roadmap_view.dart:21` | Topics tab index 1; Home topics CTA | Subjects, pan/zoom curriculum, topic states, HUD; T, `TopicDetailsSheet` | First load, cached refresh/error, no subjects, available/in-progress/completed/locked/coming soon; fullscreen |
| S06 | Practice setup — `lib/features/practice/views/practice_catalog_view.dart:8` | Practice tab index 2 | Random/custom switch, session summary, duel/AI/timer controls, subject/topic selection, sticky start; T, L | Loading/error/no catalog, random/custom, empty selection, preparing, duel picker |
| S07 | Practice history & replays — same file `:416` | History action switches `showHistory` within S06 | Header/back, history list, scores/time, replay status/action; T, L | Loading, error, empty, paginated/populated, replay busy |
| S08 | Practice player — `lib/features/practice/views/practice_session_screen.dart:10` | `/practice-session` with `PracticeSessionModel` extra; setup, topic practice, history, ranked replay, friendly duel | Progress, optional timer/duel scores, prompt, options, explanations, bottom action; T, L | Ready, clock error, answering, submitting, feedback, hints, replay, duel ended, completion, exit |
| S09 | Ranked lobby — `lib/features/pvp/views/pvp_lobby_view.dart:8` | Ranked tab index 3; Home Ranked CTA | Rules, matchmaking status/action, match history/replay; T, L | Idle, queued/cancel, history loading/empty/populated, replay busy |
| S10 | Ranked arena — `lib/features/pvp/views/pvp_arena_screen.dart:8` | `/pvp-arena` with match/player/question-count extra | Scoreboard/timer, question, options, lock/wait state, round explanation, result; T, L | Waiting for question, answering, locked, round end, win/loss/tie/opponent AFK |
| S11 | Own profile/account — `lib/features/profile/presentation/screens/profile_screen.dart:14` | `/profile`; Home avatar | Identity, XP, roadmap progress, question difficulty, account version/signout; T, L | Cached/refreshing, profile fallback, stats, logout; no appearance selector |
| S12 | Daily streak hub — `lib/features/daily_challenge/presentation/screens/daily_streak_hub_screen.dart:11` | `/daily-streak`; Home Daily CTA/top streak | Streak hero, daily action/status, rules, history, coins; T, L | Loading/error, eligible/resume/completed status, starting overlay, history |
| S13 | Daily quiz — `lib/features/daily_challenge/presentation/screens/daily_challenge_quiz_screen.dart:10` | `/daily-challenge-quiz`; daily start/resume | Question count/timer, prompt/options, confirmation, persistent explanation sheet; T, L | No session/questions, selection, submitting, answer/timeout, completion/incomplete, exit |
| S14 | Friends / invite picker — `lib/features/social/friends_screen.dart:20` | Friends tab index 4; `/friends`; `Navigator.push(FriendsScreen(picker:true))` from practice | Search, requests inbox, active duel, learner list, pagination; T, L, SC | Friends/discovery/picker, loading/error, no friends/results, friendship relations, presence |
| S15 | Friend requests — `lib/features/social/friend_requests_screen.dart:15` | Direct `MaterialPageRoute` from Friends inbox | Count, request cards, accept/reject, help panel; T, L, `SocialPageAppBar`, `FriendRequestCard`, `FriendshipActions` | Loading/error/empty/populated, action pending, realtime refresh |
| S16 | Learner profile — `lib/features/social/friend_profile_screen.dart:14` | Direct `MaterialPageRoute` from Friends or request card, learner ID | Identity/actions, streak/coins, performance, achievements, Ranked, activity; T, L, `LearnerProfileContent`, `LearnerActivityWindow` | Loading/error/cached, relationship variants, online/offline/unknown, empty metrics/activity |
| S17 | Friendly duel room — `lib/features/social/duel_room_screen.dart:13` | `/friendly-duel/:id`, optional `?play=1`; invite acceptance, active duel, practice summary | Participants, invitation status/countdown, settings/notes, player scores, resume/respond/leave | Loading/error, pending, active, own complete, complete/tie, rejected/cancelled/expired/abandoned |
| S18 | Routed lesson feed — `lib/features/lesson/views/lesson_feed_screen.dart:15` | `/lesson/:slug` with optional `stepId`; `/lesson-step/:stepId`; next lesson from completion | App bar tools, chat feed, fixed lower node input/completion area; T, L, `NodeRendererFactory`, chat/input widgets | Loading/error, content/choice/question/text input, submitting, thinking, completion/next/unpublished/roadmap complete |

### Shared shell and route distinctions

`lib/features/home/presentation/screens/home_screen.dart:20` is the shared shell for S03–S07, S09, and embedded S14. It reserves a 50–62 px top zone and 62–84 px bottom zone, changes its center child by index, and animates chrome away in fullscreen. `top_bar_zone.dart` links profile and daily streak; `bottom_nav_zone.dart` provides **five** destinations, despite a stale four-option comment in HomeScreen. No separate settings, splash, leaderboard, or achievements route was discovered. Signup is the onboarding interface; achievements is a sheet.

The route registry is at `lib/core/routing/app_router.dart:23`. Routes requiring `state.extra` cast it directly (`:126`, `:136`); missing extras have no local fallback. The two lesson routes are aliases of S18, not two players. S14’s picker and search states are variants of the same class. S07 is a distinct navigable subview of the same catalog implementation. S08 also implements friendly sessions and ranked/history replays; these are not duplicate screen classes.

The usual Home/topic path enters S04 (`home_controller.dart:1182`). S18 remains registered and has onward navigation inside its own completion widget. No normal Home launch of S18 was found; retain it as **route-reachable, with limited in-app discovery**, not proven dead code.

### Modal, sheet, overlay and transient inventory

Each row also supplies its individual evaluation and improvement direction; these surfaces are additional coverage, not included in the 18 screen count. IDs match the plan.

| ID | Surface, entry and source | Existing structure/states and evaluation | Priority / direction |
|---|---|---|---|
| O01 | DOB date picker; S02 `signup_screen.dart:195` | Platform picker wrapped in a local forced-dark theme. Selected date and range exist. Theme will disagree with future light mode. | P1 / inherit coordinated picker theme, retain date bounds |
| O02 | Religion/belief selector; S02 `signup_screen.dart:351,506` | Shared 55%-height list sheet, selected checkmark, dense tiles, no explicit safe-area wrapper. | P2 / accessible list rows, title/close, safe scrolling |
| O03 | Country selector; S02 `signup_screen.dart:420,506` | Same implementation, different list. Longer list adds scanning burden; no search. | P2 / same container; local search if list length warrants it |
| O04 | Difficulty details; S03 `home_dashboard_view.dart:312` | Scrollable SafeArea sheet, meaningful definitions and unknown-history handling. No standard close/header pattern. | P2 / preserve definitions, unify header/type |
| O05 | Achievement browser; S03 `home_dashboard_view.dart:146`, `achievement_browser.dart:7` | 85%-height sheet, close, refresh, pagination, error/retry/empty. Useful existing pattern. | P2 / themed sheet and list rows; preserve pagination |
| O06 | Activity day detail; S03/S16 `home_dashboard_view.dart:636` | Scrollable SafeArea, explicit IST and empty submissions. V: readable compact sheet. No close action. | P2 / shared header, larger detail text; retain timezone |
| O07 | Topic details; S05 `constellation_roadmap_view.dart:1106`, `topic_details_sheet.dart:7` | Draggable .40–.94 height, .78 initial, max width 640, safe areas, close, live state, sticky topic actions. V: coherent hierarchy. 44 px shrink-wrapped actions and violet/white contrast fall short. | P1 / preserve structure; repair actions, color and scaled layout |
| O08 | Daily history; S12 `daily_streak_hub_screen.dart:363,681` | Sheet with close, history loading/empty/list states; bespoke header and status tiles. | P2 / shared sheet shell and readable rows |
| O09 | Daily preparation overlay; S12 `daily_streak_hub_screen.dart:102` | Dark body-covering container, 90 px loader, progress text; app bar remains outside overlay. Not a full-screen modal barrier. | P2 / local preparing state, explicit accessible status and safe back behavior |
| O10 | Daily result dialog; S13 `daily_challenge_quiz_screen.dart:609` | Non-barrier-dismissible result; streak/rewards or failure copy, return action. Non-scroll Column, 34 px metric and reward row. | P1 / constrained scrollable result; do not change streak/reward rules |
| O11 | Daily exit confirmation; S13 `daily_challenge_quiz_screen.dart:726` | Stay/Leave; copy says resume before midnight UTC. Custom colors and all-caps labels. | P2 / standard confirmation; preserve actual deadline, explain local equivalent only when reliable |
| O12 | Practice hints; S08 `practice_session_screen.dart:565` | Incremental two-hint reveal in a non-scroll Column; white-on-pale action. | P1 / scrollable sheet, accessible button, preserve hint count/reveal behavior |
| O13 | Preferred-method reason; S08 `practice_session_screen.dart:1083` | Non-scroll Column, unflexed title row, generic fallback explanation, pale action. | P1 / wrap title/content, theme action, preserve actual reason |
| O14 | Practice exit confirmation; S08 `practice_session_screen.dart:781` | Explains abandonment and zero completion XP; busy guard exists. | P2 / standard destructive confirmation; retain callback/leave lifecycle |
| O15 | Ask tutor; S18 `doubt_sheet_widget.dart:7` | Keyboard inset padding, input/reply/loading, but whole Column cannot scroll; post-await setState lacks mounted check at `:48`. | P1 / bounded scroll and safe dismissal lifecycle; retain tutor interaction |
| O16 | Voice placeholder; S18 `voice_stub_sheet.dart:5` | Informational sheet after apparently available toolbar action; no scroll/safe-area wrapper. | P2 / disclose unavailable capability before action and standardize info sheet |
| O17 | Scan placeholder; S18 `image_stub_dialog.dart:5` | Informational AlertDialog; label looks like operational scan. | P2 / mark availability at entry; no camera feature implementation implied |
| O18 | Signout; S11 `profile_screen.dart:764` | Confirmation exists; custom red button, icon tile, radius and title row. | P2 / use standard destructive dialog and shared feedback |
| O19 | Remove friend; S14–S16 `friendship_actions.dart:34` | Named-person confirmation, two TextButtons; same destructive intent as signout but different styling. | P2 / same hierarchy, preserve relationship/version handling |
| O20 | Incoming duel invitation; global `social_overlay.dart:41,66` | Blocking dialog with countdown, accept/reject, busy/error/expiry handling; device back allowed when not busy. Can appear over other flows; no route suppression here. | P2 / protect focus and active work; preserve expiry/response contracts |
| O21 | Level-up; global `xp_controller.dart:118`, `level_up_overlay.dart:10` | 1600 ms animation, fixed 320 px card plus margins, avatar, level, Continue. Embedded text color overrides the intended dark button foreground. | P1 / fix contrast/scrolling; reduce motion, retain final level and one continuation |
| O22 | Daily answer explanation; S13 `daily_challenge_quiz_screen.dart:265,333` | Persistent bottom sheet, max .72 screen height, scrollable solution body, fixed header/action. Header has unflexed status and answer chip; light panels depart from dark surfaces. | P1 / wrap header, safe action area, consistent solution styles |

Snackbars/inline banners are presentation patterns rather than additional screens: curriculum coming-soon (`home_controller.dart:1184`), friendship update failure (`friendship_actions.dart:72`), and controller-driven practice/ranked messages. Their actionability, duration and focus announcement need runtime checks. No additional popup-menu or OverlayEntry screen implementation was found in `lib`.

## D. Existing visual-system inventory

### Theme architecture

`main.dart:42` forces `ThemeMode.dark`; only `darkTheme` is supplied. System bars are also set once to a dark arrangement (`main.dart:15`). `aptiqu_theme.dart:9` centralizes a partial ColorScheme plus app bar, card, input, dialog, divider, elevated and outlined button themes. It does **not** install the custom typography into `ThemeData.textTheme`; it does not coordinate filled/text/icon buttons, chips, navigation, sheets, switches, selection controls or snackbars. `error` is not explicitly mapped to the custom error token. Static typography embeds dark text colors, so even changing ThemeData alone cannot deliver light mode.

This is a real shared foundation with incomplete adoption, not an absence of a design system. Static `AptiquColors` references are shared constants but are **not brightness-aware semantic lookups**. Signup’s local `ThemeData.dark()` adds a second theme boundary. No appearance setting was found.

### Measured colors

The 55-file corpus contains **47 unique explicit hex ARGB values across 172 `Color(0x…)` occurrences**, plus **16 distinct Flutter named color expressions across 188 occurrences**. Resolving named values against the locally installed Flutter `material/colors.dart` gives **63 distinct base ARGB values: 61 opaque, transparent black, and white70**. These are base colors, not all effective colors: opacity, gradients, theme defaults, images, and animation create further combinations that cannot be reduced to this count. No arbitrary “total runtime colors” is claimed.

`AptiquColors` defines **27 Color constants**. Outside `lib/core/theme/`, there are **143 explicit hex occurrences representing 24 values**. Repeated identical literals are duplication even when they match a central token.

| Group | Actual values / frequency evidence | Interpretation |
|---|---|---|
| Surfaces | `#060910`, `#0A0E17`, `#0F131C`, `#131722`, `#1A1F2C`, `#232838`, `#2E3447` | Seven dark levels; independent local `#141824`, `#1E1B2E`, `#2A1608` add near-duplicate or feature-specific surfaces |
| Brand | primary `#D0BCFF`, primaryContainer `#8B5CF6`, primaryDark `#6D28D9`, onPrimary `#24005A` | Violet identity worth preserving; use of “primary” as either pale fill or text creates contrast mistakes |
| Secondary | `#22D3EE`, `#0891B2`, `#00363F` | Cyan used for metrics, outlines, icons, controls and progress, competing with violet |
| Amber | `#FFB95F`, `#D97706`, local `#F59E0B` (26 occurrences), `#FCD34D` (4) | Daily, coins, medium difficulty, hints and warning are visually conflated |
| Text | `#DFE2EF`, `#9BA1B6`, `#5E657C`; `Colors.white` 87 times, `white70` twice | Good main dark-mode pairs, but alpha-muted hints and light-on-light actions fail |
| Status | `#10B981` 50 hex occurrences; `#EF4444` 33; `Colors.redAccent` 23, greenAccent 9, green 7, red 5 | Same success/error meanings have multiple unrelated implementations |
| Boundaries/buttons | outline `#3D445C`, outlineVariant `#252B3D`; button `#1B2030` / `#353C54` | Many low-difference borders; not suitable as the only interactive-state cue |
| Social identity | `#E11D48` → `#FB7185` | Legitimate avatar accent, but highlighted avatars/glow add another strong focal point |
| Source/provenance | `#FEF3C7`, `#FDE68A`, `#92400E`, each 4 occurrences | Same provenance chip duplicated across four question implementations |

Most frequent named palette references: primary 126, onSurfaceVariant 120, outlineVariant 118, secondary 103, onSurface 103, surfaceContainerHigh 65, primaryContainer 57, tertiary 57. These are code occurrences, not which color occupies most of a screen.

Other literal values completing the hex inventory are `#38BDF8`, `#6366F1`, `#34D399`, `#F87171`, `#B91C1C`, `#B45309`, `#ECFDF5`, `#A7F3D0`, `#047857`, `#065F46`, `#818CF8`, `#4285F4`. The 16 named expressions are white, transparent, redAccent, black, greenAccent, green, red, purple, amberAccent, white70, amber, blueAccent, lightBlueAccent, orange, redAccent.shade700, purpleAccent.

### Contrast calculations

Calculated with sRGB linearization and relative luminance: `(lighter + .05) / (darker + .05)`. Alpha is composited against the specified base before calculation. Ratios below are rounded for reporting; threshold decisions use the unrounded value. Small UI labels require 4.5:1; bold alone does not make a 12–15 px label qualifying large text.

| Foreground / background | Ratio | Source/use and result |
|---|---:|---|
| `#DFE2EF` / `#0A0E17` | 14.95 | Main dark text/background: passes |
| `#9BA1B6` / `#1A1F2C` | 6.40 | Normal secondary text on container: passes before additional opacity |
| White / `#D0BCFF` | 1.70 | Daily explanation Next/Finish `daily_challenge_quiz_screen.dart:582`; practice completion/hint actions: fails |
| `#DFE2EF` / `#D0BCFF` | 1.32 | Practice submit text inherits static `labelLarge` at `practice_session_screen.dart:537`; level-up Continue at `level_up_overlay.dart:226`: fails despite intended button foreground |
| White / `#8B5CF6` | 4.23 | Topic primary buttons `topic_details_sheet.dart:285`; bright end of shared button gradient: fails normal text |
| `#DFE2EF` / `#8B5CF6` | 3.28 | Home Continue action `home_dashboard_view.dart:444`; content-node static label on violet: fails normal text |
| White / `#6D28D9` | 7.10 | Dark end of shared primary gradient passes; whole gradient needs worst-region validation |
| White / `#10B981` | 2.54 | Explicit white labels/icons on success fill are unsafe for normal text |
| `#DFE2EF` / `#10B981` | 1.96 | Practice Next action with static label color `practice_session_screen.dart:515–540`: fails |
| White / `#D97706` | 3.19 | Ask Tutor action `doubt_sheet_widget.dart:148`: fails normal text |
| White / `#0891B2` | 3.68 | Map READY/IN PROGRESS badge `constellation_roadmap_view.dart:865`: fails small text |
| `#9BA1B6` at .5 / `#1A1F2C` | 2.63 | Global input hint `aptiqu_theme.dart:44`: fails; input placeholder is not a disabled-control exemption |
| `#5E657C` / `#232838` | 2.53 | Lesson text input hint `text_input_widget.dart:60`: fails |
| `#3D445C` / `#1A1F2C` | 1.71 | Outline cannot alone identify a meaningful control boundary against this fill |
| `#252B3D` / `#232838` | 1.04 | Variant border barely separates from high surface; decorative use is acceptable, sole state cue is not |

Gradient labels, translucent chips, map glows, pressed/focused overlays, selected ChoiceChip label inheritance, image-backed content and system bars need runtime or fully composited state verification. The shared primary gradient’s 4.23 endpoint is evidence of a risk region, not proof that every glyph currently overlaps that endpoint. Disabled controls are not automatically WCAG contrast failures, but should remain recognizable.

### Typography, layout and effects

| Area | Existing measurements / evidence | Evaluation |
|---|---|---|
| Families | Outfit headings, Plus Jakarta Sans body, Space Grotesk metrics/caps; 18 direct GoogleFonts calls | Three families plus default Material typography fragment the visual rhythm. Keep the brand face, simplify roles |
| Scale | Display 28/w800; headings 20/16 w700; body 15/13.5/12 at 1.5/1.45/1.4 height; metrics 18/13/10; caps 10/11 with .8/.9 tracking | Main reading style is smaller than ideal for extended lessons; metadata often much smaller |
| Local sizes | 26 distinct numeric `fontSize` values, 7.5–42; most frequent 11 (35), 12 (21), 10 (21), 13 (16), 9 (15) | Excessive micro-variation; 7.5 map badge, 9.5 nav, 9 profile level are especially weak |
| Margins/gaps | Screen margins 14 chat, 16 social/practice, 20 Home/profile/quiz, 28 login; repeated gaps 6/8/10/12/14/16/18/20/24/28/32/36 | Context-sensitive variation is valid, but no token scale explains it |
| Radius | 15 literal circular-radius values: 2,3,4,5,6,7,8,10,12,14,16,18,20,22,24; 12 occurs 49 times, 14 36 times | Too many near-equivalent control/card shapes; circular avatars and map nodes are legitimate exceptions |
| Effects | 42 BoxShadow constructors, 13 LinearGradient, 2 RadialGradient, 1 BackdropFilter | Includes unused components and helper definitions. Not every effect is excessive; persistent glow in map/chrome/background competes with content |
| Iconography | Material Icons, mixing rounded/outlined/filled, emoji provenance icon; Cupertino package declared but no corresponding UI family found | Use a consistent navigation/icon weight, retain recognizable semantics. No need for a new icon package |
| Cards | Home low-surface cards; practice lowest-surface nested cards; social highlighted gradients with 16–24 radius; quiz prompt cards | Shared roles needed, not one universal card with many switches |
| Responsive patterns | Wrapping social actions/stats, Home metrics Wrap, topic draggable sheet; fixed map canvas positions and input grids elsewhere | Preserve working adaptations and remove layout assumptions in fragile areas |

### Buttons and feedback

`AptiquButton` has primary, secondary, outline and Google variants, default height 48 (Google 52), radius 16, 12.5/13.5 px labels, gradients/shadows, and GestureDetector scale feedback. It does not itself establish button role, keyboard activation, visible focus or distinct disabled fill; social wraps it with explicit semantics and opacity. Global ElevatedButton instead uses dark fill, radius 12, 13.5 px label. Home uses violet FilledButton; practice start uses a dark 54 px FilledButton, player uses a pale 52 px ElevatedButton, Daily uses amber, and Ranked uses a cyan-bordered dark 50 px button. Equivalent primary actions have no stable visual signature.

Topic action pairs share equal widths and a 44 px minimum with `shrinkWrap`; useful alignment, below the requested 48 px target. Embedded lesson close is a true 24 × 24 InkWell (`chat_playground_zone.dart:149`), a confirmed small hit region. Other Material controls may get implicit hit padding: do not equate their painted icon size with target size without measuring. Map small FABs, stripped Ranked refresh constraints and dense signup list rows need that measurement.

The loader has a good 250 ms delay and stable slot; minimum display time is enforced only while the same AppLoader remains mounted. Replacing it conditionally can bypass that behavior. It labels itself “Loading,” but its painter repeats continuously and does not inspect reduced-motion preferences. Bottom navigation has explicit selected semantics; social cards/actions have useful semantics. Most custom question/map controls do not explicitly expose selected, correctness or locked state.

## E. Detailed screen-by-screen evaluation

Each section uses the inventory’s source and dependency mapping and identifies its own priority, hierarchy, constraints and preservation needs. Shared findings are cited rather than re-describing the whole theme in every section.

### S01 — Login

**Structure/style:** centered owl and 40 px wordmark, feature pill, large Spacer regions, bottom Google action and legal text in a non-scroll Column (`login_screen.dart:22–192`). Violet/cyan animated backdrop makes this substantially more decorative than social lists.

**Problems/impact:** short-height or scaled-text layouts can overflow; one feature Row cannot wrap. Legal text is 11 px at .6 alpha and is plain Text, so Terms/Privacy are not accessible destinations. The shared Google icon is a blue letter G in a white circle (`aptiqu_button.dart:213`), not a supplied brand asset. Sign-in has useful loading/error handling, but inherits the custom button’s keyboard/semantic gaps.

**Direction:** identity → short value statement → Google sign-in → readable actionable legal links. Use bounded, scrollable content; reduce empty spacers when space is tight; keep logo recognition without animated wallpaper. Reuse the accessible shared button and feedback row. **P1**, high impact on entry/accessibility; UX-03/05/06/13/16. Rendered login itself not available (S/R).

### S02 — Complete profile

**Structure/style:** top row with back, title, “CADET INITIALIZATION” and step pill; scrollable form; paired name fields; DOB, gender pills, belief and country; “Initialize Aptiqu Journey” action. Validation is a top error banner, not field-linked (`signup_controller.dart:102–133`).

**Problems/impact:** back navigates to Login while the router redirects an authenticated incomplete user back to Signup: the action cannot serve its apparent purpose (S). Header is an unflexed title Column plus spacer/step badge; paired fields become narrow. Small uppercase labels, weak hints and plain external labels impede scanning/assistive navigation. List selectors and date picker use inconsistent modal/theme rules.

**Direction:** retain every required field and validation rule; first/last name stack when needed, persistent field labels and error association, focus first invalid field, descriptive CTA “Complete profile.” Provide a truthful account-switch/cancel route through existing auth behavior; do not silently remove fields or change registration policy. **P1**, UX-01/03/06/09/17/24. Reuse themed inputs/buttons and O01–O03.

### S03 — Home dashboard

**Structure/style:** daily card, resume card, performance, achievements, Ranked, consistency. V confirms coherent grouped content, restrained daily entry, and a visibly strong resume action. Wrap handles performance cells; empty accuracy handling and metric definitions are useful.

**Problems/impact:** resume label contrast fails (3.28:1). The unconditional loader slot remains 32 px high even when hidden, then another 28 px precedes Performance (`home_dashboard_view.dart:112,132`), producing a visible large gap. All four metrics use strong cyan, so secondary time competes with accuracy. Calendar dates are 48 px high but one seventh of the inner width: on a 390 px screen with 40 px screen margins and 40 px card padding, roughly 44 px wide, smaller still at 320. Meaning is available through day detail, but target spacing needs care.

**Direction:** keep Continue/Explore as the primary action; retain Daily as a quiet entry and consistency as the final section. Give accuracy/learning progress precedence; group related metrics in a flexible, aligned block, remove the idle loader gap, use sheet detail for definitions. Calendar should offer an accessible day-list alternative rather than compressing seven 48 px targets into a narrow width. **P1**, UX-02/04/11/21; high daily-use impact. Reuse HomeDashboardContent and O04–O06.

### S04 — Embedded lesson

**Structure/style:** scrolling feed with inline interactive questions, 46 px Playing header, tiny red close, background grid/glow; local question input type switches. Long options already become vertical rows. Short four-option sets use a two-column grid with fixed 2.3 aspect ratio (`question_container_widget.dart:478`).

**Problems/impact:** 24 px close target, truncated lesson name and 42 px continuation action. Short-string length is not a reliable measure of fit under text scaling. Nested prompt/bubble/card borders reduce reading width. Unlike S18, questions sit inside the feed; behavior and styling should not be accidentally unified through a controller rewrite.

**Direction:** readable lesson heading with 48 px close and preserved exit-to-Home behavior; quieter tutor bubble; one clear action immediately following the relevant teaching step. Stack short options when measured text cannot fit. Keep hints, feedback, input modes and answer references intact. Reuse future option/feedback primitives, retaining this player’s workflow. **P1**, UX-04/05/06/13/15; high teaching-flow impact. No rendered reference (S/R).

### S05 — Topics map

**Structure/style:** 2D InteractiveViewer, .35–2.2 gesture scale, 260 px positioned nodes at 160 px vertical spacing, active focus glow, 900 ms camera animation, repeating pulse, four floating controls. Subject header is fixed at 48 px; map labels include 7.5 px statuses.

**Problems/impact:** shrinking the canvas compounds tiny labels and hit regions. Explicit semantic topic ordering/state is missing. Fixed node spacing risks overlapping multi-line/scaled labels; HUD directly multiplies transforms, requiring verification against gesture zoom limits. Fullscreen shell disables safe areas; controls may overlap system insets. This is a source-derived risk, not a visually inspected full map.

**Direction:** preserve ordered curriculum, statuses and sheet callbacks. Add a linear topics-list alternative using the same data; retain the map as a distinctive optional exploration view. Enlarge status typography, remove persistent glow, respect reduced motion and insets; constrain manual zoom consistently. O07 is the existing strong action pattern to build on. **P1**, UX-04/05/06/19/21; high discoverability/accessibility impact.

### S06 — Practice setup

**Structure/style:** random/custom segmented choice, summary card, settings card, optional subject chips and topic accordions, sticky 54 px dark start. V confirms intentionally useful whitespace in Random mode and misaligned first switch-row inset compared with later rows.

**Problems/impact:** selected subject label is nearly black in saved golden; chip styling specifies fill/checkmark but not label (`practice_catalog_view.dart:263`). “Friendly duel” has different default content padding from AI/timer rows. Settings and topic controls accumulate nested borders. Start styling is quieter than social Accept; fixed height risks clipping scaled preparing text.

**Direction:** preserve random/custom, AI, timer and friendly-duel logic. One session summary, consistent setting rows, subject selection then subtopic selection. Remove decorative ten-dash summary if it adds no information. Strong shared primary action with min-height; explain disabled no-selection state. **P1**, UX-01/02/06/12/21. Reuse segmented/chip themes and selection rows; retain catalog controller.

### S07 — Practice history & replays

**Structure/style:** conditional subview with back header, status/date, score/time and replay action. Wrap in card footer is a good adaptation. Replay purple badges, reward chips, and 9/11 px labels are unique to this screen (`practice_catalog_view.dart:570–668`).

**Problems/impact:** replay/no-reward information is small; history error replaces the whole list even when cached data may exist. In-view back is implemented; device-back behavior for a subview is not declared here, so verify it. Card decoration gives metadata similar weight to the replay action.

**Direction:** session identity/date → score/time → reward/replay status → Replay. Use neutral list rows, text+icon status and standard secondary action. Preserve pagination and no-reward semantics. **P2**, UX-10/11/12/14/21; medium recovery/scanning impact. Reuse state panel and history row visuals, not ranked result models.

### S08 — Practice player

**Structure/style:** count/progress header, hints, optional friendly scores/time, scrolling prompt/options/dual explanations, fixed bottom button. It already respects reduced motion on entrance and scales the friendly header.

**Problems/impact:** pale submit and green Next fills have failing static light text. Completion is a centered, non-scroll Column (`:665`); hints/reason sheets are also unbounded. Hint counter and app-bar title compete on small phones. Option selection/correctness is largely custom styling; independent semantics need review. Missing current question becomes an indefinite loader without an escape inside that state, although normal player exit exists.

**Direction:** prompt/options first, supporting mode information compactly above; feedback and Book/Alternative methods after submission; stable primary action role across submit/next. Keep friendly scores, replay/no-XP states and existing timer/abandon transitions. Use shared option tile, source chip and solution block with mode-specific callbacks. **P1**, UX-02/05/06/07/12; high action/readability impact.

### S09 — Ranked lobby

**Structure/style:** rules before matchmaking; large icon/status card; recent duels and replays; amber/violet/cyan/green/red signals. Both heading and footer rows contain unflexed text. Refresh removes padding and minimum constraints (`pvp_lobby_view.dart:241`).

**Problems/impact:** users must scan extensive rules before the main action. History failure is only debug-printed (`pvp_lobby_controller.dart:147`), indistinguishable from “no matches” or stale data. Queue is visible and cancellable, a useful behavior to preserve. “Authoritative Questions” exposes implementation vocabulary.

**Direction:** compact match summary and Find match first, expanded rules on demand, recent matches second. Keep timing/reward disclosures visible before entry. Standard recovery banner and 48 px refresh; wrap replay footer. **P1**, UX-04/06/10/13/21/24; high recovery impact. Preserve matchmaking and replay behavior.

### S10 — Ranked arena

**Structure/style:** custom scoreboard and timer above scrolling question; tap locks answer; round result/explanation then win/loss/tie/AFK result. No normal app bar. `PopScope(canPop:false)` applies even to waiting and result layouts (`pvp_arena_screen.dart:28`).

**Problems/impact:** no visible waiting-state recovery or exit; completion’s explicit button is the only presented exit. Missing-question state is a spinner. The long “Answer locked…” Row is not flexible (`:289–309`); result Column is not scrollable. Light option letters on pale selection fill fail contrast; color alone carries much option-state meaning. Actual disconnect behavior was not exercised.

**Direction:** first make connection/wait state explicit, with recovery and an exit using already-supported leave/forfeit semantics; if no such operation exists, escalate that dependency rather than inventing one. Reflow scoreboard, keep timer legible, announce locked/result states, scroll completion. **P1**, UX-02/05/06/08; high user-control impact. Shared question primitives must preserve immediate-lock behavior.

### S11 — Own profile/account

**Structure/style:** uppercase centered PROFILE bar, logout icon, identity/XP/topic/difficulty/account cards. Uses 20 px margin and custom avatar ring, unlike learner profile’s 16 px margin and shared identity system.

**Problems/impact:** silent refresh catch leaves stale values without a status; missing avatar becomes an unrelated stock portrait (`profile_screen.dart:125`). Account displays `v1.0.0 (Build 1)` (`:720`) while pubspec is `0.0.1+1`. Logout is duplicated in header and account body. Many decorated containers make account information unnecessarily long. No appearance control.

**Direction:** identity → learning progress → account settings, with one clear signout entry and System/Light/Dark selector. Reuse avatar fallback and basic progress visuals from social, without equating different metric definitions. Display actual package version and cached-state notice. **P1**, UX-01/10/18/21; high trust/theme impact. O18 keeps confirmation.

### S12 — Daily streak hub

**Structure/style:** “Daily Streak Arena” title plus History/coins; orange gradient hero, status/action card, long rules. O09 covers the body during preparation. Status loading/error/retry exists; history has empty content.

**Problems/impact:** tiny History target, crowded title/actions, 42 px fire inside 90 px loader and technical preparation copy; app-bar interactions remain outside the claimed blocking overlay. “Arena” overlaps Ranked terminology. Decorative hero competes with start/resume.

**Direction:** “Daily challenge” header, clear ready/resume/completed state and primary action, current streak secondary, essential timing/reward facts followed by expandable rules; accessible History action. Preparation should clearly explain waiting/failure without a decorative obstruction. **P2**, UX-04/06/12/13/20/24. Preserve eligibility, reset, question count and reward rules.

### S13 — Daily quiz

**Structure/style:** count, radial timer, linear progress, difficulty/speed badges, prompt/options and amber confirmation. Source provenance chip is an intentionally light amber patch. Answer feedback is a persistent sheet with dual solutions and a separate completion dialog.

**Problems/impact:** confirmation bar has no explicit SafeArea; sheet header places status, spacer and answer chip in one unflexed Row. Pale next/finish button fails contrast. Empty session says only “No active questions.” with no recovery action. Small metadata and duplicate bordered layers add load during timed work. Timeout and incorrect answer share copy, though the view may lack enough data to distinguish them.

**Direction:** protect timer and question; compact metadata, safe sticky confirmation, source chip in semantic neutral/info colors, readable scrollable answer feedback. Give invalid entry a truthful return-to-hub action. Do not introduce hints or change the 60-second rule. **P1**, UX-02/05/06/07/10/12; high accessibility and completion impact.

### S14 — Friends / picker

**Structure/style:** standard app bar/search/inbox, compact learner tiles, relationship actions and paging. V shows clear hierarchy and low clutter. Search cancellation/debounce and presence updates are already handled at the presentation boundary.

**Problems/impact:** default Material app bar differs from social detail chrome; embedded tab may stack Home identity header and Friends header, requiring runtime appraisal. Hint-only search labeling inherits poor contrast. A loader is inserted above content, moving it when fetching. Picker has no inbox and returns a person rather than navigating: preserve that distinction.

**Direction:** search → active duel if present → results; stable inline status region, persistent accessible label, consistent root versus detail header. Keep one card per learner only if it clarifies separate interaction targets. **P1**, UX-03/05/12/14; high discoverability/accessibility impact. Retain SC and pagination.

### S15 — Friend requests

**Structure/style:** 72 px social bar, pending count pill, highlighted request cards, paired actions, repeated instructional panel. V shows readable hierarchy and equal action widths. Large-text stacking already exists in FriendshipActions.

**Problems/impact:** 11 px count/help copy, glow/gradient Accept inconsistent with other primaries, click ripple intentionally suppressed on request card. Persistent help card repeats information available from the actions. Generic inherited remove/request dialogs differ from other confirmations.

**Direction:** pending count becomes quiet metadata; identity/date grouped, Accept primary and Reject secondary; concise help only where needed. Keep explicit profile semantics and separate action targets. **P2**, UX-11/12/13/21. Shared social patterns should be themed, not replaced wholesale.

### S16 — Learner profile

**Structure/style:** identity/actions, three stat tiles, performance, achievements, Ranked, month activity. V includes standard, large text and empty metrics. Missing values are honestly N/A and “No timed results yet”; presence is also textual.

**Problems/impact:** stats’ equal widths do not ensure equal heights if one label/value wraps (`learner_profile_content.dart:153`). At large text the component already changes to rows; retain that. Performance figures stay two columns, which may fail with large counts even if the existing golden passes. Many framed icon panels and 20–24 px cards add visual weight compared with own profile.

**Direction:** keep relationship action close to identity; neutral secondary metrics, aligned stat tiles only when parallel content fits, otherwise rows. Shared calendar and definition-bearing metrics remain. **P2**, UX-06/11/12/21; medium consistency and data-readability impact.

### S17 — Friendly duel room

**Structure/style:** comparatively plain Material app bar/list, raw state strings and participant scores, inline actions. Has useful errors/retry and explicit expired/rejected/abandoned outcomes. Pending back cancels/rejects via `leave()` (`duel_room_screen.dart:202`).

**Problems/impact:** an invitee sees “Waiting for your friend” even while expected to accept (`:239`); per-player statuses are raw uppercase values. During initial failure both loader and error render because `d == null` remains true (`:227`). Active Leave is immediate while practice uses a confirmation; change only presentation, not consequence semantics. Match result appears much plainer than Ranked result.

**Direction:** participant identity → role-specific invitation/status → settings summary → progress/reward → contextual action. Replace raw statuses with clear labels, stop loading when showing terminal load error, unify destructive action presentation. **P1**, UX-10/12/20/24; high recovery and status clarity impact.

### S18 — Routed lesson feed

**Structure/style:** “Interactive AI Tutor” header with slug/step ID subtitle and camera/mic/help; chat list above an input area containing entire prompts/options/completion. Node renderer handles five types and silently returns empty for unknown (`node_renderer_factory.dart:19–76`).

**Problems/impact:** fixed lower area is an unbounded Column inside the main Column; long questions/options/completion can consume all remaining feed space or overflow. Three toolbar tools compress the title; UUID/slug-derived text is not a friendly title. Voice/scan are placeholders. Submitting errors with an existing feed are not separately rendered by the screen’s initial-error branch (`lesson_feed_screen.dart:108`). Direct question tap submits, unlike S08/S13’s explicit confirmation.

**Direction:** meaningful lesson title, Ask tutor as the available utility, explicit unavailable labels for future features, scrollable lesson/input organization and visible recoverable submission status. Harmonize bubble/type/option visuals with S04 while preserving action IDs, route aliases and direct submission behavior. **P1**, UX-05/06/07/10/15/16; high lesson usability impact.

## F. Cross-screen consistency and suspected generation-pattern analysis

| Equivalent need | Current differences | Required direction |
|---|---|---|
| Primary action | Violet gradient login/social; dark global ElevatedButton; pale practice; amber Daily; cyan-border Ranked | One theme-aware primary role; destructive and secondary are explicit exceptions |
| Back/close | Red 24 px embedded close; iOS chevron own profile/Daily; circular 48 px social back; arena blocks back | Standard 48 px controls and predictable route-aware behavior; preserve modal/session consequences |
| Question options | Home adaptive grid/list, routed tap-submit list, practice select/submit, daily amber-select, ranked lock-on-tap | Share visual state vocabulary; keep intentional interaction differences visible |
| Result/error | Sheet, dialog, full body, snackbar, silent fallback | State pattern chosen by task; all provide status and next step without discarding useful data |
| Identity | Stock fallback own profile/level-up; initial in social/Home; circles and squares | Real image or initials; one identity primitive with justified sizes |
| Progress | Glowing map line, violet bars, cyan metrics, amber streak, custom rings | Explicit labels + restrained semantic roles; no arbitrary color per statistic |
| Sheets | 55%, 85%, draggable, fixed content, body overlay, persistent bottom sheet | Consistent chrome/insets/scrolling; retain appropriate differences in modality |
| Form controls | Shared TextFormField with external labels, custom selectors/pills, raw TextField and ChoiceChip | Central component themes plus labels, focus, validation and selected-state semantics |

The code exhibits several patterns sometimes associated with independent generated screens: repeated literal status colors; custom shadows/glows around controls; many nearly identical radii; one-off dialog styling; nested cards in practice/quiz; rigid rows; technical copy such as “CADET INITIALIZATION,” “Authoritative Questions,” and “INITIALIZING DAILY CHALLENGE.” These are **observed design/code patterns, not evidence of authorship**.

Counter-evidence matters: HomeDashboardContent separates much presentation from callbacks; social layouts respond to text scaling; topic sheet shares action rows; several error states and tests are careful. Oversized buttons are **not** a general problem—most are 44–54 px. Login’s 40 px wordmark and result metrics can be legitimate display exceptions. Empty space in a short Random practice view is not automatically waste; adding cards to fill it would be worse. The goal is to remove redundant decoration and inconsistent roles, not to flatten every screen into the same generic template.

## G. Presentation architecture and reuse

1. **Keep existing feature boundaries and GetX/GoRouter contracts.** This audit provides no reason to replace state management or repositories. Refactoring networking or algorithms is out of scope.
2. **Centralize theme consumption before extracting widgets.** Colors baked into typography and constructors defeat ThemeData inheritance. A shared component with hardcoded dark colors would merely centralize the wrong behavior.
3. **Consolidate controls with real repeated contracts:** primary/secondary/destructive/loading buttons; scroll-safe sheet chrome; confirmation dialogs; empty/error/loading regions; answer-option visuals; provenance chips; solution blocks. Keep selection/submission decisions outside visual primitives.
4. **Retain feature-local components where meaning differs.** Friendly-duel status, Ranked scoreboard, curriculum camera, question timing, and lesson node dispatch are not one universal component. Profile statistics may look similar but count different things; share formatting/layout only with explicit labels.
5. **Reduce widget-tree duplication deliberately.** Practice, daily and ranked each repeat prompt/provenance/option structures. Shared files already include a generic AptiquDialog, yet no external use was found. Do not add another generic dialog without replacing a real repeated pattern.
6. **Candidate unused components:** `LearningMapTopicCard` has tests but no production consumer found; `AptiquDialog` only constructs itself in its helper. Neither is an unreachable screen. `PracticeCatalogView._buildStatItem` has no call site in that file. Verify references again before retiring anything. S18 is registered and must not be deleted as “unused.”
7. **Preserve good existing reuse:** loader timing, TutorThinkingBubble, TopicActionButtons, FriendshipActions, shared social identity and calendar behavior. Improve their semantics/themes rather than forking new versions.

## H. Prioritized findings register

Severity: **P0** proven critical blocker with no viable core path; **P1** high-impact accessibility, core interaction or required-theme gap; **P2** material consistency/recovery/maintainability issue; **P3** localized refinement/cleanup. “S/R” means code evidence is strong but manifestation requires runtime verification.

| ID | Priority | Affected | Problem, evidence and user impact | Resolution | Confidence |
|---|---|---|---|---|---|
| UX-01 | P1 | All; O01 | Forced dark `main.dart:42`; static colored typography `aptiqu_typography.dart:11`; incomplete theme `aptiqu_theme.dart:9`; selected chip ambiguity S06. Blocks system/light appearance and consistent inheritance. | Complete semantic light/dark themes, textTheme and component themes, system bars | High S; chip V/R |
| UX-02 | P1 | S03/S06/S08/S10/S13/S18; O07/O12/O13/O15/O21/O22 | Measured action/selection contrast failures; `practice_session_screen.dart:515`, `daily_challenge_quiz_screen.dart:582`, `home_dashboard_view.dart:444`, `level_up_overlay.dart:226`. Primary actions hard to read. | Pair fills with explicit on-colors; remove child text color overrides; test all states | High S/calculated |
| UX-03 | P1 | S01/S02/S14/S18/O15 | Hint alpha gives 2.63:1 (`aptiqu_theme.dart:44`); disabled-color placeholder 2.53:1 (`text_input_widget.dart:60`). Low-confidence readers lose instruction. | Full-contrast hints, persistent labels, accessible helper text | High S/calculated |
| UX-04 | P1 | Shell/S03/S04/S05/S09/S12/O07 | 24 px close `chat_playground_zone.dart:149`; 44 px shrink-wrap topic actions `topic_details_sheet.dart:258`; narrow calendar days `home_dashboard_view.dart:625`; stripped refresh `pvp_lobby_view.dart:241`. Missed taps. | 48 px touch contracts; calendar alternative; runtime target bounds | High S, medium R for implicit Material targets |
| UX-05 | P1 | S01/S02/S04/S05/S08/S10/S13/S18 | Shared button GestureDetector `aptiqu_button.dart:166`; custom selection `question_node_widget.dart:104`, map GestureDetector `constellation_roadmap_view.dart:626`; send icon lacks label `text_input_widget.dart:92`. State/focus not consistently exposed. | Native focusable controls, semantics roles/selected/status, keyboard and screen-reader tests | High omissions S; medium experience R |
| UX-06 | P1 | Shell/S01/S02/S04/S05/S08/S09/S10/S13/S16/S18 | Non-scroll login `login_screen.dart:28`, fixed short-answer grid `question_container_widget.dart:478`, non-scroll completion `practice_session_screen.dart:678`, feed footer `lesson_feed_screen.dart:166`. Text/insets can hide actions. | Content-driven constraints, scrollable results, reflow headers, preserve safe areas | High S risk; medium R |
| UX-07 | P1 | O10/O12/O13/O15/O21/O22 | Non-scroll/rigid modal content; `doubt_sheet_widget.dart:61,73`, `practice_session_screen.dart:580,1099`; post-await setState in dismissible doubt sheet `:48`. Keyboard/long replies may hide controls or update disposed view. | Shared bounded sheet/dialog structure, safe dismissal, scrolling, wrapped header | High S, medium R |
| UX-08 | P1 | S10 | `pvp_arena_screen.dart:28,160` blocks back and shows loader for missing question without visible exit/recovery. Potential trap during connection failure. | Explicit waiting/error UI and supported recovery/exit; do not invent match operations | High S; medium runtime impact |
| UX-09 | P1 | S02/S08/S10/S18 navigation | Signup back `signup_screen.dart:44` conflicts with guard `app_router.dart:39`; direct extra casts `:126,136` lack fallback. Dead-end navigation or invalid-entry failure. | Truthful account-switch/back action and safe route validation/fallback | High S |
| UX-10 | P1 | S07/S09/S11/S13/S17/S18 | Silent profile/history failures `profile_screen.dart:56`, `pvp_lobby_controller.dart:147`; quiz no-action empty `daily_challenge_quiz_screen.dart:94`; duel loader with error `duel_room_screen.dart:227`; routed feed error only when empty `lesson_feed_screen.dart:108`. Recovery and trust degrade. | Distinguish empty/error/stale/submitting states; preserve cached content and local retry | High S; routed error-path impact medium R |
| UX-11 | P2 | All | Three custom families plus defaults; 26 sizes; 7.5 px map badge `constellation_roadmap_view.dart:873`, 9.5 px nav `bottom_nav_zone.dart:199`. Reading hierarchy inconsistent. | Restrained scale; 16 px learning body, 14 px compact body, 12 px metadata | High S |
| UX-12 | P2 | All actions/dialogs | Equivalent CTAs styled independently: `aptiqu_button.dart:77`, `aptiqu_theme.dart:79`, `practice_catalog_view.dart:359`, `pvp_lobby_view.dart:190`. Harder to recognize next action. | Shared primary/secondary/quiet/destructive contracts and state matrix | High S/V |
| UX-13 | P2 | S01/S02/S04/S05/S09/S12/S15/S16 | Persistent animated background `cyber_ambient_background.dart:27`, map glow/pulse `constellation_roadmap_view.dart:85`, social highlighted surfaces `social_widgets.dart:23`. Competing emphasis for study audience. | Retain owl/violet; remove routine glow, limit accent and celebration | High S, judgment V/R |
| UX-14 | P2 | Shell/S07/S11/S14–S18 | Fixed shell zones `home_screen.dart:39`, five fixed nav widths `bottom_nav_zone.dart:126`, 72 px social app bar vs defaults `social_profile_chrome.dart:19`, mixed navigation paths. Density/back behavior differs. | Consistent root/detail chrome; explicit back behavior; test tab state retention | High S; medium R |
| UX-15 | P2 | S04/S18; question players | Separate lesson renderers and repeated options/provenance/feedback; `chat_playground_zone.dart:22`, `lesson_feed_screen.dart:44`, `node_renderer_factory.dart:19`. Fixes drift across experiences. | Shared visual primitives with adapters; preserve distinct flows/routes | High S |
| UX-16 | P2 | S01/S04/S18 | Legal notice is plain Text `login_screen.dart:184`; camera/voice open stubs `lesson_feed_screen.dart:81`; pseudo Google icon `aptiqu_button.dart:213`. Expectations exceed available actions. | Functional legal destinations when supplied; truthful capability labels and correct provider asset | High S |
| UX-17 | P2 | S02 | Top-only validation `signup_screen.dart:103`; required fields handled in controller `signup_controller.dart:102`; labels separate from field. Hard to locate/fix invalid entry. | Inline errors, focus/scroll first invalid field, keep all current rules | High S |
| UX-18 | P2 | S11/O21 | Unrelated stock avatar `profile_screen.dart:125`, `level_up_overlay.dart:84`; hardcoded version `profile_screen.dart:720` contradicts `pubspec.yaml:22`. Incorrect identity/version undermines trust. | Initial/avatar fallback and actual package version presentation | High S |
| UX-19 | P2 | Shared loader, S01/S02/S04/S05/O21 | Unconditional repeat `aptiqu_loading_indicator.dart:34`, map/background loops, celebration; S08 alone already guards its entrance. Motion inconsistency. | Respect disableAnimations, static busy state, no automatic decorative motion | High S |
| UX-20 | P2 | S12/S17; O09/O20/O21 | Global invite dialog `social_overlay.dart:41` can interrupt; level-up is another global dialog; pending duel back has response side effect `duel_room_screen.dart:202`. Competing focus/control expectations. | Document overlay priority, truthful dismiss/back behavior and supported state-preserving deferral | High S; interaction collisions R |
| UX-21 | P2 | S03/S05/S06/S07/S09/S11/S12/S15/S16 | Idle loader gap `home_dashboard_view.dart:112`; nested cards in practice; rules precede queue; stats widths without equal-height policy `learner_profile_content.dart:182`. Scan effort and hierarchy inconsistency. | One focal action, grouped data, selective cards, adaptive parallel metrics | High S/V; content edge cases R |
| UX-22 | P2 | Entire front end | Existing goldens cover a subset and only dark appearance; font substitution `social_test.dart:185`; no complete runtime accessibility evidence. Regressions could hide behind attractive fixtures. | Dual-theme fixture/state matrix, real-font/device QA, semantics and contrast tests | High S |
| UX-23 | P3 | Unused presentation helpers | No production consumer for `learning_map_topic_card.dart`; no external `AptiquDialog` use; unused `_buildStatItem` in catalog. Extra styling surface to maintain. | Verify references and retire only after migration; retain test intent | High static search, runtime reachability bounded |
| UX-24 | P3 | S02/S09/S12/S13/S17/S18 | Cadet/initialization/authoritative vocabulary; Daily “Arena”; raw duel status; slug/ID subtitle. Recognition and plain-English clarity suffer. | Subject-first, plain labels; map statuses to readable words without altering data meaning | High S |

## I. Coverage, limitations and release interpretation

All S01–S18 entries, shared Home shell, O01–O22, and the 55-file presentation/theme corpus were inspected through source and targeted related reads. Reusable surfaces covered include buttons, inputs, badges, dialogs, loading/thinking, animated background, Home chrome/calendar/achievements/topic actions, social identity/action/performance/activity components, all five lesson node renderers, and unused topic-card/dialog candidates.

This is **not** a fresh running-app audit. No authentication, live session, keyboard, TalkBack, VoiceOver, switch control, physical tap measurement, performance benchmark or real-time disconnect test was performed. Saved goldens verify only what is visible in their fixture images, not all scrolling content or runtime font behavior. No assertion is made that all tests currently pass. Colors derived from dynamic composition remain explicitly unverified.

Metadata supports mobile testing: iOS `Info.plist:31–43` declares portrait and landscape, including iPad orientations. Android/iOS folders and desktop/web scaffolding exist; actual shipping platform policy was not established. Prioritize phone portrait and landscape, then an iPad-size sanity check; do not infer a desktop product requirement from scaffolding.

Before implementation completion, high-priority color/target/semantic defects must be fixed and risky layouts exercised with long content and enlarged text. UX-08 requires clarification of supported recovery behavior from the existing front-end contract; this report does not authorize backend investigation or change. Missing legal destinations require product-provided links, not invented URLs. Preserve authored lesson text, identifiers, scope, math notation and answer references; this redesign does not authorize content reauthoring.

Only the two requested Markdown reports are deliverables. The companion plan is a blueprint for a later explicitly authorized implementation.
