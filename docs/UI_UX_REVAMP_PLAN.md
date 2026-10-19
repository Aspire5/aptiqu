# AptiQu Flutter UI/UX revamp implementation plan

Plan date: 18 October 2026. Foundation: [UI_UX_AUDIT.md](UI_UX_AUDIT.md).

**Status: proposal only. No implementation is authorized by this document.** Only this report and the audit were created. Future work must stay in Flutter presentation, preserve application behavior, and respect the repository’s prohibition on database actions, VPS access and migrations.

Coverage keys are identical to the audit: **S01–S18** screen/view entries, shared Home shell, **O01–O22** modal/sheet/overlay entries, and **UX-01–UX-24** findings. All receive a migration or preservation action below.

## A. Proposed visual direction

### A focused learning companion

Keep AptiQu’s owl, violet identity, familiar curriculum concepts, and conversational teaching. Express its personality through confident headings, a small amount of violet, useful progress feedback and occasional restrained celebration. Make ordinary study surfaces quiet enough to read for an extended session.

The existing owl asset and `AptiquColors` clearly establish violet/cyan; no new brand hue is necessary. Use deeper existing violet `#6D28D9` for light-mode actions and existing pale violet `#D0BCFF` with a dark foreground for dark-mode actions. This directly addresses measured contrast failures while preserving recognition. Cyan becomes a quieter information accent, not the default for every metric. Amber remains available for streak/coin identity and warnings through distinct semantic roles, not arbitrary orange fills across every action.

Use warm neutral light surfaces and slightly softened blue-violet dark surfaces. Keep most content on the page or in one meaningful surface. Use cards for independently actionable units or clearly grouped data, not every heading, icon, number and explanatory sentence. Remove routine glow, moving grid backgrounds and unnecessary colored borders from reading areas. Retain the map as an optional distinctive view with an accessible ordered-list counterpart.

The target audience is 15–25 with emphasis on young adults. Use plain language such as “Complete profile,” “Daily challenge,” “Find match,” and “Ask tutor.” Avoid cadet/initiation vocabulary and implementation terms. This is presentation copy only: do not rewrite lesson scripts, question prompts, solution meaning, required profile fields, or game rules.

The intended hierarchy is consistent: **where I am → what matters now → what I can do → supporting detail**. Preserve genuine differences: a timed arena needs a visible timer and locked-answer status; a lesson needs readable teaching; a profile needs identity and understandable statistics.

## B. Proposed unified design system

These are starting specifications for implementation and validation, not claims of completed visual QA. Dimensions are Flutter logical pixels. All typography respects system text scaling; “minimum height” never means clip content to a fixed height.

### Semantic palette

| Role | Light | Dark | Intended usage |
|---|---|---|---|
| Page / scaffold | `#F8F7FC` | `#0F111A` | Main screen background |
| Surface | `#FFFFFF` | `#171A25` | Cards, sheets, dialogs, menus |
| Surface container | `#F1EFF7` | `#212532` | Inputs and quiet grouped regions |
| Surface container high | `#EAE7F2` | `#303949` | Hover/selected-neutral supporting layers, not default for every card |
| On surface | `#1C1D29` | `#E8E7F0` | Main text and meaningful icons |
| On surface variant | `#5D6073` | `#B4B6C8` | Supporting text; no extra alpha for readable instructions |
| Primary | `#6D28D9` | `#D0BCFF` | Primary action fill, selected/focus emphasis |
| On primary | `#FFFFFF` | `#24005A` | Text/icons on primary fill; always used as a pair |
| Primary container | `#EDE5FF` | `#35234E` | Soft selected background or small brand region |
| On primary container | `#3D176C` | `#EBDDFF` | Text on soft brand region |
| Secondary / info foreground | `#166A80` | `#83CEDD` | Restrained successor to cyan; links/status where secondary meaning is needed |
| Info container | `#E3F3F6` | `#17353D` | Provenance/supporting info region |
| Success foreground | `#08734F` | `#6DD8A9` | Correct/completed labels and icons |
| Success container | `#E6F5ED` | `#123A2D` | Answer feedback and success messages |
| Warning foreground | `#8C4B09` | `#EBC17B` | Warning text/icons; streak/coin accent can share hue but not meaning |
| Warning container | `#FFF3DD` | `#3D2D16` | Warning or compact streak summary |
| Error foreground | `#B42335` | `#FFB3BB` | Error copy and icons |
| Error container | `#FDECEF` | `#421E28` | Error banner/incorrect answer feedback |
| Destructive action fill / on fill | `#B42335` / white | `#FFB3BB` / `#421E28` | Confirmed destructive action; distinguish from informational error banner |
| Outline for controls | `#7C7F94` | `#85899F` | Meaningful field/control edges and neutral state boundary |
| Quiet divider | `#DDD9E8` | `#363B4D` | Decorative grouping only; never sole interactive-state indicator |
| Disabled content / fill | `#77788A` / `#EAE7F2` | `#8C90A4` / `#252A38` | Explicitly unavailable controls; include reason where important |
| Scrim | black at .40 | black at .60 | Modal background; validate over actual content |

Fill every relevant `ColorScheme` foreground/container partner coherently; do not leave `onSecondary`, `onError`, `onPrimaryContainer`, inverse roles or surface variants to unrelated defaults. Use matching pairs for tertiary/warning-style Material elements. Add a small `ThemeExtension` only for roles ColorScheme does not express clearly: success, warning, lesson answer states, optional social identity accent and chart/activity intensity. Map disabled styling through component states. Do not create a separate token for each screen.

The social rose avatar may remain a decorative identity fallback accent after contrast checking, but use a solid or restrained fill and readable initials, with no glow. The owl JPEG may remain within a dark-backed logo frame in both themes; do not invert it or regenerate assets as part of theme migration.

#### Calculated starting checks

Using the same sRGB formula as the audit, these exact opaque pairs calculate as follows. Ratios are rounded only for display. All other combinations, state overlays and gradients require their own checks.

| Pair | Ratio |
|---|---:|
| Light primary: white on `#6D28D9` | 7.10:1 |
| Dark primary: `#24005A` on `#D0BCFF` | 10.08:1 |
| Light text: `#1C1D29` on page `#F8F7FC` | 15.67:1 |
| Light secondary text: `#5D6073` on white | 6.20:1 |
| Dark text: `#E8E7F0` on `#171A25` | 14.14:1 |
| Dark secondary text: `#B4B6C8` on `#171A25` | 8.64:1 |
| Light / dark success foreground on corresponding container | 5.22 / 7.22:1 |
| Light / dark warning foreground on corresponding container | 6.12 / 7.85:1 |
| Light / dark error foreground on corresponding container | 5.70 / 8.58:1 |
| Light / dark info foreground on corresponding container | 5.41 / 7.34:1 |
| Light / dark control outline against base surface | 3.95 / 5.02:1 |

Use 4.5:1 as the default text acceptance threshold even for most headings; use the 3:1 exception only where text genuinely qualifies as large. Disabled elements and purely decorative boundaries are assessed separately. Follow [WCAG contrast guidance](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html); a passing palette table alone does not validate actual screens.

### Typography

Retain **Outfit for titles**, **Plus Jakarta Sans for body and controls**. Retire Space Grotesk from routine labels and metrics after real-font comparisons; use the body family with tabular figures for stable timers/counters. This reduces three-family switching while preserving the current brand character. Install these styles in `ThemeData.textTheme`; remove embedded dark colors from static styles. Defaults, chips, list tiles and local Text widgets should then share the same family/scale.

| Role | Size / height | Weight | Use |
|---|---|---|---|
| Display | 28 / 1.20 | 700 | Result headline or occasional key statistic; not every page |
| Page title | 22 / 1.25 | 700 | Primary screen heading |
| Section title | 18 / 1.30 | 600 | Performance, subtopics, account sections |
| Item title | 16 / 1.35 | 600 | Topic, learner, history item |
| Reading body | 16 / 1.50 | 400–500 | Lesson, question, solution, long instructions |
| Compact body | 14 / 1.45 | 400–500 | Short summaries, settings and secondary content |
| Action label | 14 / 1.30 | 600 | Buttons, tabs, form labels |
| Metadata | 12 / 1.40 | 400–500 | Dates, provenance, short supporting labels |
| Metric | 24 / 1.20 | 600 | Key counts; 16–18 for compact timer/score |

Prefer sentence case. Use normal tracking for body/actions and at most .4 for optional short uppercase metadata. Avoid all-caps sentences. Important instructions, answer options and failure explanations never use metadata size. Do not truncate educational content, critical actions or errors. Ellipsis is acceptable for list identity when the full value is available on a detail screen and through semantics. A 32–40 px login wordmark can remain a brand exception if short-height tests pass.

### Spacing, shapes and surfaces

- Spacing tokens: **4, 8, 12, 16, 24, 32**. Use 4 within a label/value pair, 8 for icon/text, 12 between related rows/actions, 16 internal card padding and narrow-phone screen margin, 24 between sections. Allow 20 px page margins at widths ≥390 if consistently applied. Reserve 32 for major transitions, not between every card.
- Content gutters: 16 per side on narrow phones, 20 on wider phones; reading width capped around 640. Wide dashboard/profile layouts may use up to 840 with grouped sections, but retain reading order. Decide columns by actual constraints/content fit, not by phone model name.
- Shapes: 8 for small chips, 12 for controls/ordinary cards, 16 for large grouped panels, 24 for top corners of sheets. Circular avatars and progress rings remain circular. Chat bubbles may use a 4 px directional corner; that is a purposeful exception.
- Page-level cards: default no shadow. Raised overlay: one subtle neutral shadow, roughly offset 0/4, blur 16; validate by brightness. Prefer surface differentiation in dark mode. No colored glow for standard focus, selection or navigation.
- Parallel metric tiles: equal width and aligned baselines at normal scale, with content-driven height. Use a shared minimum height only when all content fits; switch to rows if labels wrap differently. Do not impose equal heights on unrelated lesson messages or history entries.

### Control contracts

| Component | Target specification | States and accessibility |
|---|---|---|
| Primary button | Solid primary/onPrimary, min-height 48, radius 12, horizontal 16/vertical 12, icon 20 with gap 8 | Enabled, pressed, focused, loading, disabled. Preserve readable label during loading; one activation; native keyboard/semantics |
| Secondary button | Outline or neutral tonal surface, readable foreground, same size/radius | Distinguishable from primary; outline passes meaningful contrast when needed |
| Quiet action | TextButton with full 48 px target | Supportive action only; not the only visible primary on a completion screen |
| Destructive action | Quiet entry; filled destructive only in confirmation | Explicit consequence text, Cancel secondary, busy state, avoid accidental double action |
| Icon button | 20–24 icon inside ≥48 × 48 hit region | Tooltip/accessibility label, visible focus, pressed feedback |
| Input | Persistent label, 16 px entry text, min-height 52, grows for helper/error | Focus border, inline validation, autofill/input action when appropriate, readable placeholder |
| Choice/segment/check/switch | Material controls with central theme; min 48 px interactive region | Selected/check state and semantic value, not color alone |
| Answer option | ≥56 px preferred height, flexible multiline text, 12–16 padding, separate letter slot | Selected, unselected, correct, incorrect-selected, locked, disabled; check/cross/text + semantics |
| App bar | 56 min-height, content-aware larger title arrangement at scale | Back/close consistent; move secondary tools to overflow only if they remain discoverable |
| Bottom navigation | Five existing destinations, min 64 height plus safe inset, flexible width | Readable 12 px labels, selected indicator, selected semantics; no fixed 60 px item assumption |
| Sheet | Max width 640, drag/close affordance as appropriate, bounded scrolling, bottom safe inset | Keyboard-aware, focus contained/restored, readable title/actions, no arbitrary .55/.85 height unless content warrants |
| Dialog | Max width about 480; scrollable content and wrapping/stacking actions | Clear title/body/consequence, native dialog semantics; dismissal policy explicitly specified |

For action pairs, align widths where hierarchy is equal or both are expected choices. Use full-width primary actions for setup and player footers, content-width actions in lists, and quiet text links for supporting detail. Do not add floating primary buttons merely for visual prominence. A 48 px minimum is a project touch standard, not an assertion that WCAG universally requires that exact size.

### State presentation and motion

- First load: stable placeholder or compact loader with a task label. Cached refresh: keep content and show local progress. Empty: explain what is missing and a meaningful next action. Error: concise explanation and retry/return, distinct from empty. Success: explain result and next step. Preserve metric definitions and unknown/N/A states.
- Keyboard focus: visible two-pixel outline using a contrasting semantic focus color with separation from fill. Selected radio/option: icon/check and semantics in addition to fill/border. Countdown: expose meaningful time remaining without speaking every second; announce thresholds only when useful. Never announce a result before it exists.
- Use 120–180 ms pressed/state transitions, 180–240 ms navigation/content transitions. No animated grid/ambient blobs during study. Map camera movement only when requested or essential, bounded and bypassed for reduced motion. Level-up can use a short fade/scale; never delay continuation for decorative animation.
- Honor `MediaQuery.disableAnimationsOf(context)` in loaders, map, background, route transition and celebration. Static busy state still indicates work. Preserve AppLoader’s anti-flash intent and stable slot while loading; remove its persistent empty space when an entire section has finished.

## C. Theme architecture and migration

### Files and responsibilities

| Existing / proposed file | Planned responsibility |
|---|---|
| `lib/core/theme/aptiqu_colors.dart` | Keep only centrally defined raw palette values during migration; stop consuming these directly from feature widgets. Do not delete aliases until all consumers move |
| `lib/core/theme/aptiqu_theme.dart` | Build complete light/dark ThemeData, ColorScheme, textTheme and component themes from shared definitions |
| `lib/core/theme/aptiqu_typography.dart` | Context/theme-compatible role definitions with color supplied by the theme, not baked-in dark values |
| Proposed `lib/core/theme/aptiqu_tokens.dart` | Spacing/radius/duration constants plus small semantic ThemeExtension definitions with copyWith/lerp; keep it compact, split only if it becomes hard to maintain |
| Proposed `lib/core/theme/appearance_controller.dart` | System/Light/Dark selection, initial preference and notification through existing GetX conventions; no app-wide state-management replacement |
| `lib/main.dart` | Provide `theme`, `darkTheme`, reactive `themeMode`, default System; coordinate system bars from active theme |
| `lib/features/profile/presentation/screens/profile_screen.dart` | Appearance selector under Account; mode updates immediately without navigation reset |
| Signup picker and all presentation files in audit corpus | Replace local darkness checks/static colors with theme roles; retain necessary const widgets only where values remain truly constant |

Flutter’s [`MaterialApp.themeMode`](https://api.flutter.dev/flutter/material/MaterialApp/themeMode.html) supports system-selected light/dark behavior when both themes are supplied. Changing appearance must rebuild styles without recreating feature controllers or resetting an active lesson. Use `Theme.of(context).colorScheme` and `textTheme`; use the extension for non-Material status/chart roles. Custom painters receive resolved tokens and repaint when they change.

Store only the three-way appearance preference using an existing local persistence facility if appropriate; the project already declares local secure storage, so no new dependency is inherently required. Keep that implementation behind the appearance controller. If no saved preference exists, use System. Corrupt/unavailable preference falls back to System. Do not change account/session storage, add network persistence, or delay lesson restoration for theme selection.

### Incremental procedure

1. Define and check paired colors and typography first. Create future component tests before mass migration. Include currently failing buttons, selected chip, calendar day and text input as fixtures.
2. Add both themes and component themes while retaining old color aliases for unmigrated views. During this phase, keep partially migrated light mode behind a development-only preview; do not expose a broken light experience to users.
3. Migrate shared controls and one vertical slice (Home → topic sheet → embedded lesson) in both themes. Repair explicit child Text colors that override button foregrounds.
4. Migrate each remaining screen and modal in the order below. Search all 55 corpus files for `Colors.white`, local `Color(0x…)`, `.withValues(alpha:)` on text, `ThemeData.dark`, and static typography colors. Each remaining literal needs a documented asset/brand/data exception.
5. Migrate painters, overlays, dialog barriers, tooltip/snackbar text and system status/navigation bars. Do not rely solely on `SystemChrome` set once at boot. Test platform-specific icon brightness conventions on Android and iOS.
6. Expose System/Light/Dark only when every destination and transient surface passes both themes. Switching while a sheet/player is open must preserve route, focus where possible, answers, timers and scroll position.
7. Remove unused aliases/helpers only after reference searches and tests pass. Record intentionally retained raw colors centrally.

No screen-local `if (brightness == …)` palette should be added. Theme-dependent values belong in the theme; screens choose semantic meaning. No routing-library migration or controller consolidation is required.

## D. Shared component strategy

| Component family | Current usage / disposition | Proposed consumers and limits |
|---|---|---|
| `AptiquButton` | Login/signup; SocialButton wraps it. Redesign internals around native Material button behavior and explicit variants | All primary/secondary buttons through theme or a thin wrapper. Keep label/icon/loading API; avoid arbitrary height/color knobs as normal usage |
| `SocialButton` | Friends/requests/profile; adds useful semantics | Retain as feature adapter until base button has equivalent semantics; then remove only redundant wrappers, not friendship logic |
| `AptiquTextField` | Signup; duplicates theme decoration | Reuse persistent labels/validation; Friends and tutor inputs may use themed TextField directly if multiline/search contracts differ |
| `AppLoader` / `AptiquLoadingIndicator` | Widespread; useful delayed visibility | Retain timing/stable-slot behavior, replace or simplify visual painter, add reduced motion and task-specific label support |
| `TutorThinkingBubble` | Embedded/routed lesson | Retain, use shared chat spacing/type, flexible content and static reduced-motion busy state |
| `AptiquDialog` | No external production call found | Retire after verification; implement a thin standard confirmation helper only where O11/O14/O18/O19 share title/body/actions. Native AlertDialog handles semantics/layout |
| Proposed `shared/widgets/feedback/app_state_view.dart` | Existing ad hoc loading/empty/error blocks | S03/S05/S06/S07/S09/S11/S13–S18. Support title, message, optional action and compact mode; controller owns state selection |
| Proposed `shared/widgets/sheets/app_sheet.dart` | Repeated sheet headers/containers | O02–O08/O12/O13/O15/O16. Own title/close/insets/scroll limits; caller owns content and dismissal. O22 persistent feedback keeps a feature adapter |
| Proposed `shared/widgets/questions/answer_option_tile.dart` | Home, feed, practice, daily, ranked repeat state rendering | Visual option state and accessibility only; no answer submission, timer, scoring, or ID inference |
| Proposed `shared/widgets/questions/solution_content.dart` | Practice/daily repeat Book/Alternative/preference blocks; four provenance chips | Small solution and provenance widgets in one family. Keep actual text/source/reason intact; no AI preference invention |
| `TopicActionButtons` | Topic/subtopic sheet | Retain equal-action structure, 48 px min targets, responsive stacking, centralized action styles |
| `SocialSurface`, `LearnerAvatar`, social chrome | Friends, requests, learner profile | Theme and simplify. Reuse avatar for own profile/level-up. Extract general header only after root/detail needs are confirmed |
| `FriendshipActions` | Search, requests, learner profile | Preserve relationship logic and large-text stacking; consume redesigned buttons and confirmation helper |
| `LearnerPerformanceCard`, `LearnerProfileContent` | Learner profile | Retain feature-local composition; share metric formatting/layout only if definitions remain explicit |
| `ActivityCalendar`, `YearActivityCalendar` | Home and learner profile | Move to a shared activity file only if it removes the current cross-feature import cleanly; retain month loading, IST labels and day details. Add narrow/large-text list presentation |
| `LearningMapTopicCard` | No production caller; tests exist | Candidate visual basis for the new list only after simplification; otherwise retire. Do not retain obsolete glow merely to reuse code |
| `CyberAmbientBackground` | Login/signup/embedded lesson | Remove from normal reading UI; retain only if a static, low-emphasis login treatment is justified. No continuous decorative animation |
| `AptiquBadge`, `LevelUpOverlay` | Top bar / global progression | Retain meanings, theme styling, readable labels; simplify celebration and avatar fallback |

Do not extract every Row, label or metric into a global widget. Do not build a generic “screen engine,” universal card with many booleans, or unified controller for all players. A component is worthwhile when at least two actual consumers share its visual/accessibility contract and the API remains smaller than the duplicated behavior.

## E. Screen-by-screen implementation specifications

Dependency notation: **D1** = semantic themes/type/tokens; **D2** = controls/state/sheet primitives; **D3** = shared shell/navigation behavior; **D4** = question/solution primitives. Acceptance for every entry also includes the full QA matrix in section G.

### Shared Home shell

**Issues:** UX-01/04/06/14/19. **Files:** `home_screen.dart`, `top_bar_zone.dart`, `bottom_nav_zone.dart`, `app_router.dart` only where route fallback/transition behavior is involved.

Retain the five tab destinations and existing Home-versus-lesson state. Replace percentage-derived fixed chrome with min-height, content-aware top/navigation regions. At narrow width, show the useful learner identity and compact progression without crowding coins/streak; provide full values through accessible labels and existing destinations. Use 12 px navigation labels, even flexible item widths, one selected indicator and neutral unselected icons. Remove glow and arbitrary drop shadows. Keep safe-area handling around fullscreen map controls and lesson exit even when other chrome is hidden.

**Dependencies:** D1/D2. **Risk:** rebuilding the shell can accidentally reset controllers or discard a live conversation; do not replace state switching with a different routing architecture without separate need. **Acceptance:** all five tabs and profile/streak actions work; Home returns to dashboard without clearing the conversation; Topics retap retains intended focus behavior; fullscreen controls clear insets; keyboard/large text does not clip navigation; existing `home_navigation_test.dart` and selected semantics remain valid. Device back for S07 and embedded Friends is explicitly tested.

### S01 — Login

**Issues:** UX-03/05/06/13/16. **Files:** `lib/features/auth/presentation/screens/login_screen.dart`, shared button/background, theme. **Dependencies:** D1/D2.

Use a centered max-width 440 content region with scroll fallback and 16–24 px gutters. Keep owl and wordmark, one compact value statement, and readable sign-in action. Replace the feature Row with wrapping text or three short labels. Space expands on tall screens but collapses naturally on short screens. Use primary body/secondary roles; Google action should use the provider’s appropriate branding treatment rather than a hand-drawn G. Provide actual Terms/Privacy destinations only when supplied by the product; leave this as a blocked content dependency rather than invent URLs.

Keep sign-in errors adjacent to the CTA with text and icon; action label remains identifiable while busy. Legal text uses at least 12 px full-contrast secondary color and independently focusable links.

**Expected improvement:** clear, accessible first action without excessive spectacle. **Risk:** changing button activation could bypass the existing duplicate-signin guard; retain it. **Acceptance:** 320 × 568 at 2× text can reach sign-in/legal controls by scrolling; keyboard/screen-reader activation works; error and image failure render coherently; only one account picker opens for repeated taps. Verify against `auth_account_selection_test.dart`.

### S02 — Complete profile

**Issues:** UX-01/03/06/09/17/24; O01–O03. **Files:** `signup_screen.dart`, `aptiqu_text_field.dart`, minimal `signup_controller.dart` presentation-error exposure, `app_router.dart` if required for a truthful return path. **Dependencies:** D1/D2.

Order: concise “Complete profile” title and step, names, DOB, gender, belief, country, complete action. Keep current required fields. Use vertical name fields below roughly 400 px or when either label/error cannot fit; paired fields remain optional where fit is proven. Persistent 14 px labels, 16 px input, 8 px label/input gap, 16 px between fields, 24 px before CTA. Replace “Initialize…” with “Complete profile.” Error summary may remain, but invalid fields also get local messages and first-invalid focus/scroll.

Resolve back behavior without weakening auth guards: offer an explicit account-switch/signout action using existing auth behavior when ordinary back cannot reach Login. Explain consequences before discarding entered values if relevant. Date picker inherits the active theme. Selection sheets show title, close, selected state and safe scroll; country can gain local filtering without changing stored values.

**Expected improvement:** fewer failed attempts and less scanning. **Risk:** label changes must not change submitted keys or validation rules. **Acceptance:** every current required-field error is attached to its control; picker selections persist; back has an observable truthful result; keyboard and 2× text keep action reachable; both themes include picker calendar and selected dates.

### S03 — Home dashboard

**Issues:** UX-02/04/11/21; O04–O06. **Files:** `home_dashboard_view.dart`, `achievement_browser.dart`, shared activity/state primitives. **Dependencies:** D1/D2/D3.

Preserve Daily entry → Continue/Explore → Performance → Achievements → Ranked → Consistency. Make Continue/Explore the only filled primary in the main dashboard; Daily remains a compact quiet entry. Remove the idle 32 px loader slot and use an inline refresh indicator only while active. Use 24 px section spacing, 12–16 px card internals and stable content gutters.

Group accuracy and correct/submitted counts; present average correct time as secondary and preserve metric definitions. Prefer neutral numbers with one purposeful accent. Show a short achievement preview and existing View all action; do not add invented achievements. Calendar keeps month/year and IST. When seven 48 px targets cannot fit, use an accessible day-list presentation or an explicitly scrollable minimum-width calendar, with an easy list option; no overlapping hit regions.

**Expected improvement:** a clear next learning action and easier progress reading. **Risk:** metrics count different events; do not alter calculations, date semantics or recap copy. **Acceptance:** 0/N/A/loading/error/cached states remain truthful; resume contrast ≥4.5; no idle loader gap; calendar day detail reachable with TalkBack/VoiceOver; existing Home goldens and tests intentionally updated only after review.

### S04 — Embedded lesson

**Issues:** UX-04/05/06/13/15/16; shared learning controls. **Files:** `chat_playground_zone.dart`, `question_container_widget.dart`, `tutor_thinking_bubble.dart`; Home controller only for presentation signals. **Dependencies:** D1/D2/D3/D4.

Use a content-aware header with lesson title and 48 px close; replace “PLAYING”/divider chrome with a quiet lesson label where useful. Keep a single scrollable conversation; flatten redundant prompt/bubble containers and retain paragraph breaks/math notation. Reading body 16/1.5, bubble padding 12–16, message gap 12, max content width 640. Content continuation uses the shared primary style and grows beyond 48 px when needed.

Keep current select/text/voice/scan/none behavior. For four short options, allow two columns only after available width and scaled text fit; otherwise use vertical answer rows. Hints, selected/correct/incorrect labels and locked states must be semantic and visible independently of color. Show unavailable voice/scan capabilities honestly; do not implement them in this revamp.

**Expected improvement:** sustained reading and reliable answer interaction. **Risk:** changing node layout can disrupt auto-scroll and keyed state. **Acceptance:** long equations/options never ellipsize; 2× text falls back to rows; typing remains visible above keyboard; exit preserves existing conversation semantics; submitted answers cannot be activated again; answer IDs and ordering are unchanged.

### S05 — Topics map

**Issues:** UX-04/05/06/13/19/21; O07. **Files:** `constellation_roadmap_view.dart`, `topic_details_sheet.dart`, possibly simplified `learning_map_topic_card.dart`, Home topics branch. **Dependencies:** D1/D2/D3.

Use one subject selector with readable selected labels and quiet completion count. Introduce Map/List presentation over the same ordered topics. Default the accessible list when enlarged text or narrow constraints make the map impractical; retain user choice within the view. List entries show topic name, explicit state, completion count and one details action. Avoid showing teaching-depth implementation metadata as a prominent learner signal.

On the map, remove repeated glow, increase meaningful label sizes to 12+, allow node label height to influence spacing, and supply ordered semantic topic actions independent of painter decoration. Give HUD controls 48 px targets and safe insets. Respect consistent zoom bounds for gestures and buttons; disable automatic camera animation under reduced motion. Sheet retains draggable behavior, live updates, max 640 width and whole-topic/subtopic distinction.

**Expected improvement:** curriculum remains distinctive and becomes usable without precision pan/zoom. **Risk:** list must preserve lock/availability/replay rules and subtopic selection. **Acceptance:** every topic is reachable without a gesture canvas; state announced correctly; no overlap at 2×; all sheet callbacks return the same IDs and dismiss before navigation; subject change invalidates stale sheet actions as today.

### S06 — Practice setup

**Issues:** UX-01/02/06/12/21. **Files:** `practice_catalog_view.dart`, theme component definitions. **Dependencies:** D1/D2/D3.

Keep Random/Custom tabs, one compact “10 questions” summary, consistent setting rows for duel/AI/timer, then subject/subtopics in Custom. Apply identical content padding to all settings; remove the decorative ten-dash graphic. Use a central chip theme with explicit selected foreground, fill and checkmark. Topic expansion rows need spacing/dividers rather than deeply nested cards.

Use a strong primary sticky action with min-height 48 and safe inset, “Start practice” or “Invite a friend” according to existing mode. Preserve preparing label, prevent repeated starts, and explain why no-selection/no-catalog actions are unavailable. Use 16 px compact bodies for options where space allows, 14 px supporting text, 24 px section gaps.

**Expected improvement:** readable configuration with a recognizable next step. **Risk:** combining selection widgets can change tri-state topic behavior; preserve it. **Acceptance:** Random, Custom, all/clear, subject changes, AI/timer/duel combinations and no-content state retain behavior; selected subject text passes 4.5:1; no overflow with long subject names and 2× text; existing catalog tests remain meaningful.

### S07 — Practice history & replays

**Issues:** UX-10/11/12/14/21. **Files:** history section in `practice_catalog_view.dart`, minimal catalog controller error-state exposure if needed. **Dependencies:** D1/D2/D3.

Use the same subview header with Back to practice; title 22 or compact app-bar title. List rows group date/session identity, score/time, replay/reward status and secondary Replay. Use 12 px metadata, 14 px compact body and no bright purple no-reward badge. Footer actions wrap or stack; no fixed equal card height for differing history text. Preserve paginated list and scroll state during retries where possible.

Cached refresh failures show a banner above retained entries; initial errors show retry; empty history explains that completed practice appears here. Replay pending feedback belongs to the activated row or a clearly labelled shared status, while existing concurrency guards remain.

**Expected improvement:** easier review without mistaking replays for reward sessions. **Risk:** device back can leave the shell instead of the subview; define/test return to setup before changing navigation. **Acceptance:** back control and platform back are predictable; replay still launches S08 with no-reward behavior; long dates and status labels wrap; loading, empty, error, pagination and busy states have fixtures.

### S08 — Practice player

**Issues:** UX-02/05/06/07/12/15; O12–O14. **Files:** `practice_session_screen.dart`, D4 shared widgets. **Dependencies:** D1/D2/D4.

Keep count/progress and optional timer at top, hints reachable but secondary, friendly scores as a compact adaptive strip. Main scroll: mode/difficulty, prompt/provenance, options, feedback/solutions. Use shared 16 px reading body and answer tiles; inline metadata wraps. Bottom Submit/Next uses the same primary pair, not pale/green fills with light labels. Correctness is communicated in the feedback region.

Make completion a scrollable result layout with score, actual XP/replay/duel explanation and return. O12/O13 use scroll-safe sheets and readable action colors. Exit keeps its abandonment consequence and busy lifecycle. Preserve ready/clock-error/duel-ended states and existing reduced-motion support.

**Expected improvement:** reliable answering and readable feedback across all session types. **Risk:** answer selection, timeout, hint reveal and Next have different controller timing; visual consolidation must not merge them. **Acceptance:** no duplicate submission; correct IDs/options unchanged; hints reveal same sequence; timed/untimed/replay/friendly variants pass; 320 landscape and long explanations remain navigable; CTA contrast meets 4.5 in every enabled state.

### S09 — Ranked lobby

**Issues:** UX-04/06/10/13/21/24. **Files:** `pvp_lobby_view.dart`, targeted visible error-state changes in `pvp_lobby_controller.dart`. **Dependencies:** D1/D2/D3.

Place compact match summary and Find match action above detailed rules. Summary keeps the existing question count, timer and reward facts; expandable rules preserve full wording meaning. While queued, replace the action region with explicit queue status, elapsed time and Cancel. No oversized glowing loading card. Recent matches use concise participant/score/outcome rows with a secondary replay action and readable zero-reward disclosure.

Use text+icon for victory/loss/tie; color reinforces it. All headers/footers wrap; refresh target stays 48 px. Add a visible history failure state distinct from no matches, with retained cached data when available.

**Expected improvement:** quicker entry and trustworthy queue/history feedback. **Risk:** queue cancellation/navigation races must retain current handling. **Acceptance:** starting, queued, cancelling, failure, matched and history/replay busy states remain distinct; long opponent name and replay labels fit; no silent failure appears as empty history; replay still opens practice, not a live arena.

### S10 — Ranked arena

**Issues:** UX-02/05/06/08/15. **Files:** `pvp_arena_screen.dart`, minimal arena controller presentation-state exposure only; route fallback. **Dependencies:** D1/D2/D4; supported recovery/leave contract must be established before changing exit behavior.

Use an adaptive scoreboard with two clear participants/scores and a stable timer/count. Reserve 12–16 px gaps; stack identities at large text rather than compressing them. Prompt and options follow shared reading/option styles. Preserve immediate selection/lock behavior and explain it before the first answer. Selected option uses on-container colors plus a mark; lock/result text is announced once. Wrap waiting text. Result is scrollable with win/loss/tie/AFK text, scores, actual rewards and return.

Waiting for a question needs a visible status and a recovery/exit route supported by current product behavior. If leaving cannot be safely represented by the existing interface, document the gap for separate approval; do not invent a server action or silently declare a forfeit. Do not automatically cancel matches during theme changes.

**Expected improvement:** accessible timed interaction without an unexplained trapped state. **Risk:** highest workflow sensitivity; preserve timing, opponent events and score authority. **Acceptance:** test no question, delayed next round, connection interruption and completion; back policy is explicit and testable; result button exits once; all result variants and long waiting text fit; no color-only answer state.

### S11 — Own profile/account

**Issues:** UX-01/10/18/21. **Files:** `profile_screen.dart`, shared avatar and theme appearance controller. **Dependencies:** D1/D2/D3.

Use identity header with real avatar/initial fallback and quiet level, then XP/progress, topic/question statistics and Account. Reduce repeated framed icons and keep 24 px between sections. Use the common title scale instead of tracked uppercase PROFILE. Preserve definitions of own-profile statistics; do not substitute learner-profile aggregates just for visual symmetry.

Account contains Appearance (System/Light/Dark), actual app version and one signout action. Keep O18 confirmation. Show refresh failure above retained values, distinguishing unavailable metrics from actual zero. Appearance changes apply immediately and persist locally without an application restart.

**Expected improvement:** accurate identity/account information and useful appearance control. **Risk:** appearance rebuild must not reset authentication/progression state. Version data must come from existing generated/platform metadata or a separately justified minimal mechanism, not a new hardcoded string. **Acceptance:** no unrelated stock portrait; correct version; single clear logout entry; cached/error/empty states; live theme switch preserves profile scroll and active routes; signout behavior unchanged.

### S12 — Daily challenge hub

**Issues:** UX-04/06/12/13/20/24; O08/O09. **Files:** `daily_streak_hub_screen.dart`. **Dependencies:** D1/D2/D3.

Rename visible section to “Daily challenge” while preserving route names. Header has an accessible History action; coins are quiet secondary information. Order current availability/start/resume, streak summary, essential rules, expandable detail. Use one primary action with the shared brand role; amber supports streak meaning rather than filling the whole action region. Replace gradient/fire spectacle with a small meaningful icon and readable number.

During preparation, display task-specific progress within a controlled state region. Ensure other controls do not imply safe actions they cannot perform; coordinate back/History behavior with existing start lifecycle. Do not pretend the current body-only overlay is a full modal. Show actionable failure instead of endless initialization.

**Expected improvement:** clear readiness and less distraction before timed work. **Risk:** changing copy must preserve tier, deadline, all-correct and reward semantics. **Acceptance:** new/resume/completed/unavailable/loading/error/preparing states; narrow title row; History and coins labels readable; preparation and returning from quiz refresh correctly; existing eligibility stays intact.

### S13 — Daily quiz

**Issues:** UX-02/05/06/07/10/12; O10/O11/O22. **Files:** `daily_challenge_quiz_screen.dart`, shared question/solution/state primitives. **Dependencies:** D1/D2/D4.

Keep timer and question progress clear. Use compact wrapped metadata; put provenance in the common chip without emoji. Prompt/options use 16 px reading text; confirmation is a safe-area footer with stable primary action. Empty/invalid session gives Return to daily challenge instead of an isolated sentence.

O22 retains its post-answer function and both methods, but uses shared solution layout, a wrapping correctness/answer header and a safe Next/Finish action. It must fit the usable viewport, not just a fraction of total screen height. Result dialog scrolls and clearly distinguishes actual complete/incomplete information. Do not infer timeout versus incorrect when the supplied state does not distinguish them. Keep exit/resume deadline meaning accurate.

**Expected improvement:** better question focus and reliable completion on small phones. **Risk:** sheet/dialog layering may trigger duplicate next/completion actions; retain guards and test dismissal. **Acceptance:** no hint feature added; timer and confirmation behavior unchanged; all result/solution variants fit at 2×; no content under system navigation inset; action contrast ≥4.5; invalid route has safe recovery.

### S14 — Friends / invite picker

**Issues:** UX-03/05/12/14. **Files:** `friends_screen.dart`, `social_widgets.dart`, `friendship_actions.dart`, root/detail header adapter. **Dependencies:** D1/D2/D3.

Preserve Friends, discovery search and picker modes in one implementation. Root Friends uses title/search/inbox without redundant competing shell headings; picker uses a clear back action and “Invite a friend.” Search has a persistent accessible label and readable hint. Keep active duel banner directly below search. Maintain compact identity rows with separate relationship/action targets and 48 px pagination controls.

Use a stable loading/status region so search results do not jump when a loader appears. No-results copy distinguishes no friends from no search match. Existing debounce, stale-result protection, pagination and presence updates remain untouched.

**Expected improvement:** predictable search and selection in both contexts. **Risk:** picker tap must still return a person rather than open a profile; preserve nested Navigator behavior. **Acceptance:** picker/discovery/friends fixtures, all relationship states, long names, keyboard, pending request count and paging; no duplicate profile/action semantics; refresh errors do not impersonate an empty list.

### S15 — Friend requests

**Issues:** UX-11/12/13/21; O19 where applicable. **Files:** `friend_requests_screen.dart`, `friend_request_card.dart`, social chrome/actions. **Dependencies:** D1/D2/D3.

Use a common detail header with quiet pending count. Group avatar/name/request date, then Accept primary and Reject secondary. Retain equal-width pairs where they fit; stack at enlarged text. Use 16 px item title, 12–14 px date/supporting text, 16 px card padding and 12–16 px row spacing. Remove glow and repetitive help-card decoration; offer a short inline explanation only where it adds useful context.

Keep distinct profile and action semantics. Press feedback must be visible on tappable identity, not suppressed without replacement. Busy state remains local to the request and cannot send duplicate responses.

**Expected improvement:** clear social decisions consistent with the rest of the app. **Risk:** realtime invitation changes and relationship version must stay authoritative. **Acceptance:** accept/reject/profile, empty/cached error/loading and concurrent update fixtures; large-text action stack; count updates correctly; return from profile refreshes existing state without replaying an action.

### S16 — Learner profile

**Issues:** UX-06/11/12/21; O06/O19. **Files:** `friend_profile_screen.dart`, `learner_profile_content.dart`, `learner_performance_card.dart`, `learner_activity_window.dart`, social identity. **Dependencies:** D1/D2/D3.

Keep identity/relationship action first, secondary streak/coins, performance, achievements, Ranked, then activity. Reduce highlighted surface and framed-icon repetition. Parallel stats use aligned minimum-height tiles only when content fits; retain existing row fallback and extend it for long numbers. Performance can stack figures at narrow width/large text. Use actual N/A and time definitions; do not replace missing metrics with zero.

Use 24 px section gaps and 16 px card padding; body labels 14 and metadata 12. Shared day-detail presentation preserves IST and remote month loading/error handling.

**Expected improvement:** balanced profile that remains readable with real data. **Risk:** arbitrary large values and unknown presence state; never discard or cap data merely to fit. **Acceptance:** existing standard/large/empty goldens covered in both themes; all friendship variants; long identity and five-digit counts; activity paging/error/retry; text independently communicates presence; no mismatched stat heights in standard fixture.

### S17 — Friendly duel room

**Issues:** UX-10/12/20/24. **Files:** `duel_room_screen.dart`, shared state/buttons/confirmation. **Dependencies:** D1/D2/D3.

Use participant header, role-specific status and countdown, compact question/timer settings, progress rows and contextual action. Requester sees waiting/cancel; recipient sees invitation/accept/reject. Map raw session statuses to readable labels without altering values. Errors replace initial loading, while stale data remains visible on refresh failure. Completed summary presents actual outcome/reward with the same visual vocabulary as other results.

Active Leave gets clear consequence presentation consistent with practice, using the existing leave operation. Pending back/cancel behavior must remain explicit; do not turn dismissing an invitation into acceptance or change expiry. Use 16 px body, wrapped names and 48 px actions with 12 px spacing.

**Expected improvement:** understandable duel lifecycle and recovery. **Risk:** `?play=1` auto-opens a session; visual changes must not launch it twice. **Acceptance:** requester/recipient pending, expiry/reject/cancel, active, own finished, both finished/tie/abandoned, failure/retry; no spinner coexists with terminal initial error; back and leave consequences tested; resume/auto-open remain single-shot.

### S18 — Routed lesson feed

**Issues:** UX-05/06/07/10/15/16/24; O15–O17. **Files:** `lesson_feed_screen.dart`, `node_renderer_factory.dart`, `chat_bubble_widget.dart`, `content_node_widget.dart`, `choice_input_widget.dart`, `question_node_widget.dart`, `text_input_widget.dart`, `completion_node_widget.dart`. **Dependencies:** D1/D2/D4.

Use a meaningful lesson title from available presentation data, with “Lesson” fallback rather than exposing an opaque ID. Put Ask tutor in the visible toolbar; mark scan/voice Coming soon before they are activated, using existing informational affordances if retained. Shared bubbles/type match S04. Reorganize the input region so long prompt/options/completion scroll safely within available space; prefer one coherent scroll model over a permanently oversized footer. Keep text input composer above keyboard with labelled Send.

All five node types and next/unpublished/roadmap-complete states remain supported. Unknown node type should show a safe explanatory state and return/retry only if the existing contract supports it, not an invisible gap. Submission failure with an existing conversation needs inline feedback without wiping the feed. Preserve direct answer submission on option tap.

**Expected improvement:** usable deep-linked lesson flow consistent with embedded teaching. **Risk:** repeated route pushes/GetX registration can affect controller lifecycle; verify behavior before changing ownership. **Acceptance:** both route aliases, all five nodes, long question/options/completion, text input/keyboard, submitting error, next lesson and coming-soon cases; no hidden input actions; IDs and action payloads unchanged.

### Modal and overlay implementation contracts

All below depend on D1/D2; question-related entries also depend on D4. Use the existing source locations in the audit inventory. Each row is an acceptance checklist item in addition to its parent screen specification.

| IDs | Required changes / preservation | Acceptance and main risk |
|---|---|---|
| O01 | Themed date picker; retain DOB bounds and selection | Both calendar themes, long month/year and large text; dismiss retains previous value |
| O02/O03 | Shared selector title/close, selected state, 48 px rows, safe scrolling; optional local country search | Selection returns exactly current stored value; back/dismiss does not select; long labels fit |
| O04 | Common sheet header, 16 px explanatory body, readable breakdown | All difficulty/unknown data and definitions preserved; scroll to final note at 2× |
| O05 | Common shell around existing browser, stable loading and load-more | Pagination/refresh/retry retains items and no duplicate achievements; close reachable |
| O06 | Common compact detail header/close and clear IST data | Zero submissions, populated date, completed daily flag; long date/2× content scrolls |
| O07 | Preserve draggable/live sheet; 48 px action pairs, semantic roles, wrap/stack when needed | Topic and subtopic actions never cross; locked/unpublished updates honored before navigation |
| O08 | Shared history sheet shell and neutral readable status rows | Initial loading/empty/error/populated and long history fit; close returns to hub |
| O09 | Labelled preparation state with controlled interactions and recoverable failure | Back/History/start races tested; no false full-screen modal assumption; no new cancellation semantics |
| O10 | Scrollable result dialog with score/streak/reward facts and one return | Complete/incomplete at narrow landscape and 2×; one dismissal/return, no repeated reward action |
| O11/O14 | Shared confirmation visual hierarchy; preserve distinct resume versus abandonment consequences | Cancel resumes exact current flow; confirm invokes existing action once; error recoverable |
| O12 | Safe scroll, distinct hint count and reveal action; readable button | 0/1/2 hints, long hint, unavailable hints, dismissal; no extra hint reveal from rebuild |
| O13 | Wrapped method title, scrollable reason, neutral info treatment | Real reason retained; missing reason labelled honestly; Got it visible at 2× |
| O15 | Bounded keyboard-aware sheet, loading/error/reply states, mounted-safe completion | Dismiss during request without disposed update; long reply and keyboard fit; focus restored |
| O16/O17 | Truthful Coming soon entry; consistent small informational surface | Neither implies active camera/microphone work; close accessible; no integration work added |
| O18/O19 | Shared destructive confirmation, named consequence and consistent Cancel | Signout/removal calls and stored state semantics preserved; long person name fits |
| O20 | Standard accessible dialog, role/expiry text, busy state; coordinate with active work | Expiry while open/busy, accept/reject failures, back, queued invites; no lost existing answer or duplicate response |
| O21 | Theme-safe avatar/initial, final level, shorter optional animation, scrollable content, fixed contrast | Multi-level awards display final state; reduced motion instant; Continue once; no overlap with higher-priority task dialogs |
| O22 | Wrapped feedback header, scrollable methods, semantic state, safe footer | Correct/incorrect-or-timeout, long answer/source/preference, next/finish; underlying controls not misleadingly active |

Overlay priority: current user confirmation or answer feedback should retain focus; invitations and celebrations must not silently steal input. Prefer deferring the **presentation** of nonessential celebration until a safe boundary, preserving the event. Invitation timing cannot be extended; if an invitation cannot be shown immediately, use an accessible non-blocking entry to the same existing response workflow where supported. Any change to invitation delivery/expiry rules requires separate product authorization. Validate focus restoration and single-overlay behavior rather than inventing a global overlay framework by default.

## F. Phased implementation roadmap

Complexity is relative (**S/M/L**), not an unvalidated calendar estimate. Each phase should be a reviewable change set with screenshots and relevant tests. Do not enable partially migrated light mode in a release.

| Phase | Scope / findings | Dependencies | Complexity and risk | Exit gate |
|---|---|---|---|---|
| 0 — Baselines and contracts | Capture current phone states with actual fonts; verify S10 leave/recovery, legal destinations, platform scope; UX-08/09/16/22 | Implementation authorization | M; missing product/interface facts | Screen/overlay state fixtures and preserved behavior checklist agreed; no backend expansion |
| 1 — Foundations | Tokens, type, light/dark schemes, component themes, appearance state; UX-01/02/03/11/19 | Phase 0 | M; static text colors/default Material roles | Theme/color tests; representative primary/input/chip/option states pass both modes |
| 2 — Shared interactions | Buttons, inputs, state view, sheet/confirmation shell, loader, option/solution primitives; UX-04/05/07/12/15 | Phase 1 | L; accidental callback/semantic duplication | 48 px/focus/semantics/loading/long-content tests; no domain logic in visual widgets |
| 3 — Learning vertical slice | Home shell, S03–S05, O04–O07, map/list, calendar; UX-02/04/06/13/14/19/21 | Phases 1–2 | L; fullscreen/scroll/topic action regressions | Home→topic→lesson→Home works; existing navigation/topic/calendar tests pass; both themes |
| 4 — Entry and account | S01/S02/S11, O01–O03/O18; UX-03/09/16/17/18/24 | Phases 1–2 | M; auth guards/legal dependency | Account picker/registration/signout preserved; validation and theme switch work |
| 5 — Practice and daily | S06–S08/S12/S13, O08–O14/O22; UX-02/06/07/10/12/21 | D4 and Phase 3 shell | L; timers/submission/completion | Random/custom/replay/friendly and daily lifecycle tests; readable solutions/results |
| 6 — Social and competition | S09/S10/S14–S17, O19/O20; UX-04/08/10/14/20/24 | Phase 5 player; recovery contract resolved | L/highest behavior risk | Invite/expiry/match/replay/back/disconnect matrix verified; all errors recoverable |
| 7 — Routed lessons and global surfaces | S18, O15–O17/O21; harmonize global overlays/system bars; UX-05/06/07/15/19/20 | Shared controls and player primitives | M–L; lifecycle/focus | Both lesson routes and all node/result types pass; overlays coordinate; no static dark leftovers |
| 8 — Coverage, release, cleanup | Expose System default and selector; real-device QA, all states; retire confirmed unused helpers; UX-01/22/23 and remaining issues | All phases | M; missing states/font substitutions | Entire section G passes; all P1 closed or explicitly blocked from release; exactly scoped cleanup |

Develop both themes throughout every phase. Phase 8 is a coverage gate, not the first time light mode is considered. If a component regression appears, fix the shared contract and affected consumers together. Do not broaden into backend work to make a UI fixture pass.

## G. Quality assurance and validation

### Common test envelope

Every screen/view S01–S18 and shell must be checked in **Light and Dark**, plus a System-mode switch scenario. Use **320 × 568**, **390 × 844**, **430 × 932**, and **844 × 390 landscape** as logical-size fixtures. Add a **768 × 1024** sanity pass because iPad orientations are declared; wider web/desktop acceptance is conditional on confirmed shipping scope. Test text scales **1.0, 1.3, 2.0** and platform accessibility scaling, not only a screenshot resized afterward. Exercise safe top/bottom insets and keyboard on every text-input flow.

Run the full state set at typical phone size in both modes; run the hardest long-content/state case at every size/scale. This avoids an unnecessarily huge Cartesian suite while covering critical combinations. Record exactly which combinations ran. For O01–O22, test both themes at 320 portrait and narrow-height landscape with 2× text, keyboard for O15, and visible close/primary controls. Non-applicable empty or success states should be marked N/A with reason rather than invented.

| Coverage | Required content/state variants | Existing tests / future additions |
|---|---|---|
| Shell | Five tabs, root/detail back, fullscreen, pending request dot, long learner name/large counts | `home_navigation_test.dart`, `social_test.dart`; add platform-back and safe-inset cases |
| S01 | Idle, busy, error, cancelled auth, failed logo, long error, short height | `auth_account_selection_test.dart`; add visual/semantics login tests |
| S02 | Prefill, every invalid field, selected DOB/gender/belief/country, busy, keyboard, back/account switch | Add signup widget and picker-state tests |
| S03 | First learner, resume, cached refresh/failure, no data, long titles, metric N/A, badges, calendar day/month | `home_dashboard_test.dart` and three Home goldens |
| S04 | Content/choice/question/text/voice/scan/none, hint, correct/incorrect, long math, busy, exit/re-enter | `home_navigation_test.dart`; add embedded player scale/semantics fixtures |
| S05 | Loading/error/cached, empty subjects, available/locked/coming soon/in-progress/completed, map/list, zoom/fullscreen | `constellation_roadmap_test.dart`, `learning_map_test.dart`, `topic_details_sheet_test.dart`, `topic_progress_ui_test.dart` |
| S06 | Random/custom, all switches, selected/empty subject/subtopics, partial topic checkbox, preparing/no catalog/error | `practice_catalog_test.dart`; expand goldens for chip states and keyboard picker |
| S07 | Loading/error/empty/populated, long history labels, replay busy, pagination, back | Extend catalog tests; separate history fixtures |
| S08 | Ready, clock failure, timed/untimed, hints, selection/submit/feedback, Book/Alternative, replay, friendly scores, completion/abandon | `practice_session_test.dart`; add player visual, contrast, semantics and large-text tests |
| S09 | Idle/queue/cancel, failed queue/history, empty/populated history, replay busy, long opponent names | Add lobby widget fixtures with existing front-end fakes |
| S10 | Waiting, live question, locked, round result, connection loss/delay, win/loss/tie/AFK, back/result return | Add arena presentation and navigation tests; real-device lifecycle verification |
| S11 | Real/missing/failed avatar, no stats/cached/error, long name/email, appearance modes, version, logout | `xp_level_system_test.dart`; add own-profile visual/state cases |
| S12 | Loading/error/eligible/resume/completed, preparation/failure, history, large streak/coin values | Add daily hub state/golden tests |
| S13 | Invalid session, all option/result states, timeout, long provenance/solutions, next/completion, exit | Add daily quiz/overlay/navigation tests |
| S14 | Friends/search/picker, no friends/no results, pending requests, paging, all relationship states, stale load, keyboard | `social_test.dart`, `friends-search.png`; add picker/embedded header goldens |
| S15 | Loading/error/empty, pending counts incl. >99 where applicable, long names, action busy/update | `social_test.dart`, `friend-requests.png` |
| S16 | Relationship variants, presence unknown/offline/online, N/A/long metrics, badge/activity errors, long names | `social_test.dart`, three learner-profile goldens |
| S17 | Requester/recipient, pending/expired/rejected/cancelled/active/own done/complete/tie/abandoned, errors, auto-open | Extend social/practice tests; dedicated duel-room lifecycle fixtures |
| S18 | Both aliases, all five nodes, unknown node fallback, existing-feed error, text input/keyboard, next/unpublished/complete | Add routed-feed widget/navigation/semantics tests; preserve lesson-progress coverage |
| O01–O03 | Every selector state, dismissal and large list/date | Signup overlay tests |
| O04–O08 | Long/empty/failed data, pagination, live topic update and dismissal | Existing Home/topic/social tests plus daily history cases |
| O09–O14/O22 | Preparation, hints, preferred reason, all result/exit states and double-tap guards | Practice/daily overlay tests |
| O15–O17 | Keyboard, long reply, busy dismissal, unavailable-tool explanation | Routed lesson overlay tests |
| O18–O21 | Cancel/confirm/busy/error, invite expiry, back, competing overlays, multi-level progression | Social/XP tests plus integration/focus checks |

### Measurable acceptance criteria

1. **Contrast:** all enabled normal text ≥4.5:1 against actual resolved/composited background; qualifying large text and meaningful non-text UI ≥3:1. Verify foreground inherited by child Text, not just button style declarations. Check selected/focused/pressed/error states and chart/calendar labels. Disabled exceptions documented, no unreadable instructions disguised as disabled.
2. **Targets:** primary interactive controls meet project 48 × 48 hit-region standard. Automated target checks plus manual inspection for custom InkWell/GestureDetector and calendar cells. Targets must not overlap or cover other controls.
3. **Layout:** no RenderFlex overflow, clipped question/action text, inaccessible bottom controls or unintended horizontal page scrolling in the test envelope. Intentional map panning is allowed; reading and forms must not require precision panning. Long identifiers, six-line options, 2,000-character explanation, lengthy names and large numeric values included.
4. **Semantics/focus:** every interactive icon has a meaningful label; options announce selection and lock/result; headers have sensible traversal order. No duplicate spoken button labels from wrapper/base semantics. TalkBack and VoiceOver can complete login entry, topic selection, one lesson question, practice, request response and modal dismissal. Keyboard traversal follows visual order and activation works.
5. **States:** loading is visibly distinct from empty/error; initial failure stops loading; stale content is identified; retry targets the failed operation; busy actions cannot fire twice. Completion and reward presentation use actual supplied values.
6. **Appearance:** System mode responds to OS changes without restart; explicit override remains until changed; preference survives relaunch; overlays, text selection, keyboards where platform-supported, system bars, painters and error states remain legible. Active session/navigation state survives switching.
7. **Motion:** reduced-motion preference disables decorative repeating/camera/celebration animation while maintaining status and interaction. No test depends on waiting indefinitely for a repeating animation to settle; pump bounded frames when testing a loader.
8. **Regression:** preserve route parameters/extras, callbacks, action IDs, option order, timer behavior, replay reward treatment, friendship version and invite expiry. Use existing tests plus fixtures that verify observable behavior, not tests merely mirroring token constants.
9. **Visual review:** compare actual rendered results at common widths in both modes, with real production fonts. Golden changes are individually reviewed; do not bulk-update baselines to silence failures. Fix the substituted-font fixture problem before interpreting font weight/line break regressions.

During later implementation, run targeted Flutter tests for each changed slice, then the full Flutter test suite and analyzer for final integration. Avoid rebuilding unrelated platforms or installing packages without need. New tests here are warranted for changed accessibility/interaction contracts; they are not required for this documentation-only task and were not run now. Screenshots/goldens created in future implementation are additional artifacts outside this task’s current two-file limit.

## H. Risks and preservation requirements

| Risk | Preservation rule / mitigation |
|---|---|
| Theme migration changes text/foreground precedence | Remove explicit incompatible child colors deliberately; test button child text and icon separately. Keep theme roles centralized |
| Increased type expands layouts | Replace fixed height with min-height/scroll before increasing text; use content-driven breakpoint fallbacks |
| Two lesson players have different behavior | Share visual primitives, not controllers; keep both route aliases and embedded callbacks; no removal of S18 based on limited entry discovery |
| Timers/answer locking tied to widget lifecycle | Avoid recreating controllers when theme/layout changes; preserve answer IDs, selected state and timestamp behavior; verify transitions |
| Match exit/reconnect contract is unclear | Investigate only existing Flutter interface necessary for UI behavior. Treat unsupported recovery as a separate approved dependency, not permission to modify backend |
| Modals overlap active timed work | Test focus/stacking and event order. Do not extend deadlines, suppress mandatory outcomes or lose invitations to simplify visuals |
| Auth guard/back behavior | Keep protection intact; make visible account switching truthful using existing auth operations |
| Profile/metrics look similar but differ | Preserve denominators, N/A, time exclusions, date zones, streak semantics and source values. Share presentation with explicit labels only |
| Calendar target requirements conflict with narrow width | Switch to day list or intentional minimum-width calendar; no overlapping expanded targets or tiny labels |
| Placeholder features/legal links | Disclose unavailable scan/voice; do not add integrations or invent policy destinations. Product-provided URLs remain a prerequisite |
| Version and avatars | Derive real version; fallback to initials, never another person’s photograph. No account data changes |
| Font fixtures mask real typography | Use real families/weights in verification; maintain licensing and offline-asset strategy before changing font provisioning |
| Cleanup removes live behavior | Search production and test references after migration; delete only verified unused helper code, not registered screens |
| Scope expands through a “redesign” | No database, VPS, migration, API/backend, lesson-content, scoring or curriculum edits. Any necessary behavior-policy change requires separate authorization |

## I. Recommended implementation order and traceability checklist

Use this dependency-aware checklist when implementation is explicitly approved. Check an item only after its acceptance criteria and both themes pass. The audit remains the source for evidence; this plan supplies the target.

- [ ] Establish real-font baselines and all S/O fixtures; confirm shipping form factors, legal links and existing Ranked recovery contract. **UX-08/16/22**.
- [ ] Define paired palette/type/spacing/motion tokens and complete component themes. **UX-01/02/03/11/19**.
- [ ] Add System-default appearance state and platform-bar strategy; keep release light mode gated until coverage is complete. **UX-01**.
- [ ] Repair shared button contrast, native semantics/focus, disabled/loading states and 48 px controls. **UX-02/04/05/12**.
- [ ] Standardize labelled fields, state regions, scroll-safe sheets and confirmation visuals. **UX-03/07/10/17**; O01–O03/O11/O14/O18/O19.
- [ ] Build small answer-option/provenance/solution primitives without changing submission semantics. **UX-05/12/15**.
- [ ] Migrate Home shell/top/bottom navigation, S03 Home, calendar and O04–O06. **UX-02/04/06/14/21**.
- [ ] Migrate S05 Topics map/list and O07, preserving lock/replay/subtopic behavior. **UX-04/05/06/13/19/21**.
- [ ] Migrate S04 embedded lesson and all input/feedback modes. **UX-04/05/06/13/15/16**.
- [ ] Migrate S01 login and S02 signup with truthful back and field validation. **UX-03/05/06/09/16/17/24**; O01–O03.
- [ ] Migrate S11 own profile; accurate identity/version, appearance control and O18. **UX-01/10/18/21**.
- [ ] Migrate S06 practice setup, S07 history and S08 player, including replays/friendly variants and O12–O14. **UX-02/05/06/07/10/12/14/21**.
- [ ] Migrate S12 daily hub and S13 quiz with O08–O11/O22 and unchanged timing/streak rules. **UX-02/04/06/07/10/12/13/20/24**.
- [ ] Migrate S14 Friends/picker, S15 requests, S16 learner profile and O19; retain existing adaptive social behavior. **UX-03/05/06/11/12/14/21**.
- [ ] Migrate S17 friendly duel lifecycle and global O20 invitation presentation. **UX-10/12/20/24**.
- [ ] Migrate S09 Ranked lobby and S10 arena after recovery contract is resolved; test waiting/disconnect/result/replay. **UX-02/04/05/06/08/10/13/21/24**.
- [ ] Migrate S18 routed feed, all five node types, both route aliases and O15–O17. **UX-05/06/07/09/10/15/16/24**.
- [ ] Harmonize O21 level-up, overlay ordering, reduced motion, custom painters and system bars. **UX-01/02/06/07/18/19/20**.
- [ ] Validate route extras/fallbacks, subview/platform back, focus restoration and all shared states. **UX-05/09/10/14/20**.
- [ ] Complete the section G matrix, measured contrast/target checks, real-device screen-reader and orientation tests; review every updated golden. **UX-02/03/04/05/06/07/22**.
- [ ] Remove verified unused dialog/topic/stat helpers and obsolete styling aliases only after consumer migration. **UX-23**.
- [ ] Confirm every S01–S18 and O01–O22 entry is covered, all P1 findings are resolved, and no unrelated behavior/content/backend change entered the diff. Enable complete System/Light/Dark experience and seek release review. **UX-01–UX-24**.

This checklist ends at a reviewed redesign implementation in a future task. For the present task, the audit and this plan are the completed deliverables; application changes require explicit approval.
