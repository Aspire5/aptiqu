# AptiQu frontend design system

Canonical reference for designing, creating, modifying and reviewing the **Flutter learner frontend**. It records the final, manually approved Phase G implementation and the subsequently authorized Ranked Leagues Phase 4 additions. Phase G is **completed and approved**; the user requested no release. Ranked outage/exit policy was deferred at that checkpoint; see the later Phase 2 policy update in the limitations section. This handbook does not authorize release, backend changes or another redesign.

The running implementation is the authority for what exists. Current user requirements guide the task; this document supplies the established default. It is a living design contract, not an immutable specification. It applies to Flutter UI work, not unrelated backend or educational-content authoring. Follow the applicable root [AGENTS.md](../AGENTS.md) instructions for those domains.

## Start here

1. Read the sections relevant to the requested screen or interaction.
2. Inspect its actual theme, shared widgets, state owner and navigation entry.
3. Confirm the current user's requested outcome and constraints.
4. Reuse suitable roles/components; design around the content and task.
5. Protect behavior, accessibility, text scaling and both appearances.
6. Verify the affected states; explain meaningful departures; update this handbook only when a lasting convention changes.

**Decision hierarchy:** explicit current task requirements take precedence over historical aesthetic preferences. Protect functional behavior, accessibility and technical correctness; explain conflicts and seek clarification when they genuinely cannot be reconciled. Approved conventions are the default for ordinary frontend work. New approaches are welcome when they improve usability, aesthetics, accessibility or maintainability. Explain significant departures; when approved, update the relevant section. An already authorized redesign does not require a second approval merely because it changes this default. Phase-specific approval gates apply when the current task establishes them; the completed revamp is not a permanent approval requirement for every small frontend fix.

## Architecture and source map

| Layer | Actual source / symbols | Responsibility and boundary |
|---|---|---|
| Bootstrap / app root | [main.dart](../lib/main.dart): `main`, `AptiquApp`; [InitialBinding](../lib/core/bindings/initial_binding.dart) | Initialize GetX services, load appearance before auth entry, disable runtime font fetching, build `MaterialApp.router` with both themes and root system-bar annotation. Root theme changes are immediate (`Duration.zero`). |
| Appearance | [AppearanceController](../lib/core/theme/appearance_controller.dart), [AppearanceTheme](../lib/core/theme/appearance_theme.dart) | Device-local preference and live standalone/overlay theme boundary. Never recreate session controllers to change appearance. |
| Design roles | [AptiquTheme](../lib/core/theme/aptiqu_theme.dart), [AptiquTypography](../lib/core/theme/aptiqu_typography.dart), [tokens/extensions](../lib/core/theme/aptiqu_tokens.dart) | Paired Material colors, component themes, reading roles and small spacing/radius vocabulary. |
| Navigation | [AppRouter](../lib/core/routing/app_router.dart), [AppRoutes](../lib/core/routing/app_routes.dart) | `go_router`, auth/onboarding guards, route validation/fallbacks, root navigator and messenger keys. Existing social/profile flows also use native Navigator pushes. |
| Shell | [HomeScreen](../lib/features/home/presentation/screens/home_screen.dart) | Home, Topics, Practice, Ranked, Friends; embedded lesson and map fullscreen state. The keyed `home-content` region protects state when chrome changes. |
| Shared presentation | [lib/shared/widgets](../lib/shared/widgets) | Controls, state regions, question presentation, sheet primitives, loading and text-fit measurement. Prefer these before adding another reusable layer. |
| Feature presentation | [lib/features](../lib/features) | Feature screens, views and local reusable pieces. Some useful components remain in a feature directory; location alone does not make them universal. |
| State / data | Feature `controllers`, `repositories`, `models`; social controller/API | Controllers and local widget state own selection, timing, validation, busy/error and navigation effects. Visual primitives receive values/callbacks; they must not infer correctness, eligibility or rewards. |
| Global presentation | [GlobalOverlayGate](../lib/core/presentation/global_overlay_gate.dart), [SocialOverlay](../lib/features/social/social_overlay.dart), [XpController](../lib/core/progression/controllers/xp_controller.dart) | Coordinate critical work, invitations and celebrations. Presentation deferral never pauses timers or changes server rules. |

There are two lesson presentations: Home's [ChatPlaygroundZone](../lib/features/home/presentation/widgets/chat_playground_zone.dart) / [QuestionContainerWidget](../lib/features/home/presentation/widgets/question_container_widget.dart), and routed [LessonFeedScreen](../lib/features/lesson/views/lesson_feed_screen.dart) / [NodeRendererFactory](../lib/features/lesson/views/widgets/node_renderer_factory.dart). Reuse visual primitives without merging their distinct controllers/contracts. Routed feed controllers are tagged and route-owned; preserve disposal, stale-response checks and page identity.

## A. Design identity and philosophy

AptiQu serves young adults learning aptitude and reasoning. Its personality is modern, polished, mature and slightly lively: educational professionalism with visible progression and reward. Violet carries the main brand/action signal; teal and amber support specific secondary meanings. The curriculum map, clear level progression, friendly tutor identity and earned achievements supply personality without decorating every panel.

Make learning text easy to read and the next meaningful action easy to recognize. Prefer a clear focal action, quiet metadata, aligned metrics and real state changes. Restraint should not turn the app into a sterile corporate form. Equally, engagement does not justify cartoonish decoration, arbitrary rewards, persistent glow or ornamental gradients behind reading content.

Consistency comes from roles and interaction quality, not making every screen the same. A lesson conversation, a competitive question, a profile and a searchable learner list need different compositions. Preserve the distinction between supplied data and presentation: N/A is not zero, a replay is not a new rewarded attempt, and a placeholder is not an operational tool.

## B. Themes and semantic color system

### Runtime appearance

`AptiquTheme.lightTheme` and `AptiquTheme.darkTheme` build Material 3 themes. `AptiquApp` binds `themeMode` to `AppearanceController.mode`. **System** is the default and follows OS appearance without restarting; explicit Light/Dark overrides the OS until changed. [AppearanceSetting](../lib/features/profile/presentation/widgets/appearance_setting.dart), immediately below Profile identity, supplies the segmented choices or wrapping native chips when labels need more room.

The controller persists `ThemeMode.name` under `aptiqu.appearance` with `FlutterSecureStorage`, independently of account/session storage. Missing, corrupt or unreadable storage falls back to System. Changes apply immediately; writes serialize so the last choice persists. Save failure has visible session-only feedback and Retry saving. Do not convert this into an account/server preference without a separate requirement.

`AppearanceTheme(builder: ...)` observes the same mode and platform brightness, supplies the resolved Theme and `AnnotatedRegion<SystemUiOverlayStyle>`. Existing screens and overlays use this boundary for live updates, including standalone fixtures. Consume the **builder's themed context**, not an outer context captured before the boundary. `AptiquTheme.systemBars` uses a transparent status bar, appropriate icon brightness and the page background for the navigation bar. Platform keyboard/bar rendering still needs native checks.

### Current color values

Hex values are opaque sRGB unless noted. Source: `AptiquTheme._build`; these are documentation, not a second token implementation. New UI consumes the semantic role rather than copying its hex value.

| Role | Light | Dark | Intended use / foreground pairing |
|---|---|---|---|
| `primary` | `#6D28D9` | `#D0BCFF` | Main enabled action; text/icons use onPrimary. |
| `onPrimary` | `#FFFFFF` | `#24005A` | Foreground on primary. |
| `primaryContainer` | `#EDE5FF` | `#35234E` | Selected/subtle brand surface; use onPrimaryContainer. |
| `onPrimaryContainer` | `#3D176C` | `#EBDDFF` | Selected/subtle brand foreground. |
| `secondary` | `#166A80` | `#83CEDD` | Secondary emphasis, informational/progress accent. |
| `onSecondary` | `#FFFFFF` | `#00363F` | Foreground on a solid secondary fill. |
| `secondaryContainer` | `#E3F3F6` | `#17353D` | Secondary supporting surface; use onSecondaryContainer. |
| `onSecondaryContainer` | `#166A80` | `#83CEDD` | Foreground on secondaryContainer. |
| `tertiary` | `#8C4B09` | `#EBC17B` | Amber reward/warning accent; pair by context, never imply a fabricated award. |
| `onTertiary` | `#FFFFFF` | `#3D2D16` | Foreground on solid tertiary. |
| `tertiaryContainer` | `#FFF3DD` | `#3D2D16` | Amber supporting surface; use onTertiaryContainer. |
| `onTertiaryContainer` | `#8C4B09` | `#EBC17B` | Foreground on tertiaryContainer. |
| `error` | `#B42335` | `#FFB3BB` | Error text/icons; a solid destructive action uses onError. |
| `onError` | `#FFFFFF` | `#421E28` | Foreground on solid error. |
| `errorContainer` | `#FDECEF` | `#421E28` | Error/status panel or custom error notice; use onErrorContainer. |
| `onErrorContainer` | `#B42335` | `#FFB3BB` | Foreground on errorContainer. |
| `surface` | `#FFFFFF` | `#171A25` | Reading/card/dialog surface; normal text uses onSurface. |
| `onSurface` | `#1C1D29` | `#E8E7F0` | Main readable text/icons on neutral surfaces. |
| `onSurfaceVariant` | `#5D6073` | `#B4B6C8` | Secondary readable text and supporting icons; not low-alpha body text. |
| `surfaceDim` | `#F8F7FC` | `#0F111A` | Default scaffold/page background. |
| `surfaceBright` | `#FFFFFF` | `#303949` | Brightest neutral surface in this scheme. |
| `surfaceContainerLowest` | `#FFFFFF` | `#0F111A` | Lowest container tier. |
| `surfaceContainerLow` | `#FFFFFF` | `#171A25` | Low container tier. |
| `surfaceContainer` | `#F1EFF7` | `#212532` | Filled input/chip and grouped neutral region. |
| `surfaceContainerHigh` | `#EAE7F2` | `#303949` | Raised neutral region/progress track. |
| `surfaceContainerHighest` | `#EAE7F2` | `#303949` | Highest neutral container tier; currently same values as High. |
| `outline` | `#7C7F94` | `#85899F` | Meaningful control outline. |
| `outlineVariant` | `#DDD9E8` | `#363B4D` | Quiet separators/decorative borders; not a text role. |
| `inverseSurface` | `#212532` | `#E8E7F0` | Contrasting neutral transient surface. |
| `onInverseSurface` | `#E8E7F0` | `#1C1D29` | Foreground on inverseSurface. |
| `inversePrimary` | `#D0BCFF` | `#6D28D9` | Primary accent on inverse surfaces. |
| `status.success` | `#08734F` | `#6DD8A9` | Correct/success foreground on successContainer. |
| `status.successContainer` | `#E6F5ED` | `#123A2D` | Success panel/answer fill; foreground is status.success. |
| `status.disabled` | `#77788A` | `#8C90A4` | Explicit disabled control foreground, not explanatory text. |
| `status.disabledContainer` | `#EAE7F2` | `#252A38` | Explicit disabled control fill. |
| `status.warning` | `#8C4B09` | `#EBC17B` | Alias of tertiary for warnings. |
| `status.warningContainer` | `#FFF3DD` | `#3D2D16` | Alias of tertiaryContainer; foreground is status.warning. |

`shadow` and `scrim` are black; `surfaceTint` is transparent. Modal sheet barrier opacity is 0.4 in Light and 0.6 in Dark. `AptiquStatus` is a `ThemeExtension`; it defines no independent `onSuccess` token. Do not assume white text is correct on a success/primary container. `AnswerOption` demonstrates success-on-successContainer, error-on-errorContainer and onPrimaryContainer-on-primaryContainer.

Access roles with `Theme.of(context).colorScheme`, `Theme.of(context).textTheme`, or import `aptiqu_tokens.dart` for `context.colors`, `context.type`, `context.status`. The status extension has a fallback for non-app theme contexts; use the app theme in production and fixtures rather than treating that fallback as another approved palette.

The theme configures AppBar, Card, Filled/Elevated/Outlined/Text/Icon buttons, input decoration, chips, sheets, dialogs, dividers, progress and text selection. Other native Material widgets inherit their scheme/defaults; there is no custom theme for every control. Input fill is surfaceContainer; focus borders use primary at 2 px; errors use error at 1/2 px. Body/display text defaults to onSurface. Shared buttons let native foreground inheritance reach child text/icons; avoid a child Text color that defeats that pair.

**Color changes:** first look for an existing semantic meaning. Reuse a status/secondary/tertiary role when it actually matches the content. If an enduring feature needs a new semantic accent, explain its meaning and define paired Light/Dark roles centrally (for example in an appropriate ThemeExtension), then verify its actual composited states. Do not scatter screen-local hex constants or recolor unrelated roles to accommodate one panel. Significant palette departures should be intentional, authorized and reflected here. Google's branded sign-in treatment is an existing documented exception, not a new app-wide palette.

## C. Typography

Source: `AptiquTypography.textTheme`. These are the **explicitly configured** roles; do not assume unlisted Material roles have the same custom definition. Sizes are logical Flutter font sizes before system scaling; height is the TextStyle multiplier.

| Role | Family | Size | Weight | Height | Use |
|---|---|---|---|---|---|
| `displaySmall` | Outfit | 28 | 700 | 1.20 | Occasional result headline/key emphasis, not every label. |
| `headlineSmall` | Outfit | 22 | 700 | 1.25 | Page/result headline where this role is appropriate. |
| `titleLarge` | Outfit | 22 | 700 | 1.25 | AppBar/page heading; AppBar theme selects this role. |
| `titleMedium` | Outfit | 18 | 600 | 1.30 | Section heading and some metrics. |
| `titleSmall` | Outfit | 16 | 600 | 1.35 | Item, question-state and learner-row heading. |
| `bodyLarge` | Plus Jakarta Sans | 16 | 400 | 1.50 | Lesson bubbles, questions, solutions, form entry and primary reading. |
| `bodyMedium` | Plus Jakarta Sans | 14 | 400 | 1.45 | Supporting prose, compact body and input labels. |
| `bodySmall` | Plus Jakarta Sans | 12 | 400 | 1.40 | Metadata and secondary metric labels; not lesson explanations. |
| `labelLarge` | Plus Jakarta Sans | 14 | 600 | 1.30 | Standard button labels. |
| `labelMedium` / `labelSmall` | Plus Jakarta Sans | 12 | 500 | 1.40 | Compact labels/badges. Current appearance badge uses labelMedium. |

The roles are color-free at definition; `AptiquTheme` applies active onSurface colors. Consume `context.type` / `Theme.of(context).textTheme`, not a fresh GoogleFonts style for each Text. Preserve inherited foreground inside colored controls. Use `copyWith` for a necessary, explained emphasis; a local override does not automatically become a global role.

The final implementation contains deliberate local exceptions: Login's Outfit wordmark is 36 px; Home performance metrics use 24 px or 18 px and `FontFeature.tabularFigures()` in `HomeDashboardContent._stat`; TopicDetailsSheet's topic title is 21 px; map/navigation metadata includes explicit 12 px/zero-letter-spacing overrides. **There is no universal metric token, globally enforced tabular-figure setting or custom letter-spacing scale.** Do not promote old Space Grotesk/uppercase styles from the audit into current code. Unspecified letter spacing inherits framework/font behavior.

Outfit and Plus Jakarta Sans static files at weights 400/500/600/700/800 are bundled in [assets/fonts](../assets/fonts), with [source hashes](../assets/fonts/SOURCES.json) and per-family OFL licenses. `main` disables runtime font fetching. The [font asset test](../test/production_font_assets_test.dart) checks production loading. Google's sign-in button alone uses bundled GoogleSans Medium, 14 px, weight 500, height 20/14; its [source/branding record](../assets/fonts/google_sans/SOURCE.md) explains that exception. Do not replace the app's reading fonts with the provider font.

## D. Layout, spacing, shapes and composition

| Current convention | Definition / verified use |
|---|---|
| Spacing tokens | `AptiquSpace.xs=4`, `sm=8`, `md=12`, `lg=16`, `xl=24`, `xxl=32`. `gutter(width)` is 16 below 390 logical px, otherwise 20. |
| Radius tokens | `AptiquRadius.chip=8`, `control=12`, `panel=16`, `sheet=24`. These are defaults, not a mandate to make every asset/control identical. |
| Page/reading bounds | Login uses a 440 px maximum reading region. Signup and embedded lesson content use 640 px bounds. Modal sheets default to max width 640. Other layouts use available content width. |
| Controls | App standard is at least 48×48 hit regions. Shared button height is a **minimum**, growing for content; AnswerOption minimum height is 56. Native control padding/semantics must remain usable at enlarged text. |
| Surfaces / elevation | Neutral surfaces, quiet outlines and selective grouping. AppBar, Card, shared buttons and themed ElevatedButton use zero elevation. Dialogs retain native behavior unless locally configured; there is no universal zero-elevation rule. |
| Sheet framing | Top radius 24, visible title/Close, safe insets and scrolling. `showAppSheet` caps content after keyboard inset at 90% of available window height. |
| Responsive fit | [textFits](../lib/shared/widgets/layout/text_fit.dart) uses TextPainter, actual text style, direction and system text scaler. Content and height matter as well as viewport width. |

Not every spacing/radius literal has been replaced by a token. Do not document a complete automated token-enforcement system that does not exist. Prefer the vocabulary where it fits; review related callers before changing a shared dimension.

### The composition lesson from the approved revision

An earlier version became overly serious and repetitive: heading → paragraph → full-width control → large gap, repeated down the page. Preserve the correction:

- Evaluate rows and meaningful groups for related information: avatar beside identity, name fields together when readable, aligned counts, related progress in one surface. Use grids/columns when the content benefits.
- Choose controls for the task. System/Light/Dark is a compact mutually exclusive set; gender uses selectable chips; native dates and longer radio-list selectors serve different needs. A longer collection may warrant search, but the current country/belief sheets are not a generic searchable-selector component.
- Prefer concise labels, meaningful icons and visible selection over redundant paragraphs. Keep explanations that resolve uncertainty, disclose a limitation or teach a concept.
- Reduce wasted space and unnecessary scrolling without cramming controls or shrinking fonts. Do not repeat a heavy card/title/body wrapper for every metric.
- Keep full names and important values in identity/detail regions. The compact shell currently truncates the name visually while exposing the full identity in its profile-opening semantics; that existing exception is not permission to truncate all detail text.

These principles do **not** force horizontal layouts. Long names, required validation, translated labels, narrow width or 2× text can need wrapping/stacking. Whole controls should wrap where possible. Do not use a screen-width breakpoint as a substitute for measuring whether the actual labels fit.

Useful references: [AppearanceSetting](../lib/features/profile/presentation/widgets/appearance_setting.dart), [SocialIdentityHeader](../lib/features/social/widgets/social_profile_chrome.dart), [TopicActionButtons](../lib/features/home/presentation/widgets/topic_details_sheet.dart), [SessionMetrics](../lib/shared/widgets/questions/question_presentation.dart). Topic actions use a row only when both labels fit; at limited sheet height, Whole topic actions join the reading scroller while Close stays fixed. The embedded lesson has a compact short-height header, a full title in the reading flow and explicit fullscreen reading; normal shell navigation returns on Exit fullscreen/Back.

## E. Reusable component inventory

**Before creating a reusable widget, check this inventory and its source/callers.** Reuse suitable behavior and visual contracts. If the use case differs, keep a small local composition or establish a focused new component; do not stretch an existing widget into a conditional-heavy universal screen. The “used by” examples are current callers, not every possible consumer.

### Shared controls, feedback and questions

| Component / source | Purpose / current callers | Reuse, states and limits |
|---|---|---|
| [`AptiquButton`, `AptiquButtonVariant`](../lib/shared/widgets/buttons/aptiqu_button.dart) | Native Material action; Login, lesson content/completion, practice, social wrapper. | Primary, secondary-container, outline and Google variants; `.outline`/`.google` constructors; icon, busy, disabled, wrapping label, min height and focus outline. Busy retains label and disables callback. Google branding is provider-specific. Caller owns operation/duplicate guard. |
| [`AptiquTextField`](../lib/shared/widgets/inputs/aptiqu_text_field.dart) | Labelled TextFormField; signup first/last name. | Persistent floating label, controller/focus, validator, prefix/suffix, readOnly, obscureText, keyboard/action/autofill, enabled and maxLines. It does not validate a whole form, select the first invalid field or implement search/pickers. Native TextField remains appropriate in existing search/lesson inputs. |
| [`AppLoader`](../lib/shared/widgets/indicators/app_loader.dart) | Stable async slot; AppStateView, buttons, Home and social loading. | Default 32; `loading` flag, configurable size, 250 ms reveal delay and 350 ms minimum visible time once shown. Does not indicate progress percentage or own requests. |
| [`AptiquLoadingIndicator`](../lib/shared/widgets/indicators/aptiqu_loading_indicator.dart) | Themed spinner used by AppLoader. | Optional message/semantics, default 48; static 0.7 arc with reduced motion. That arc is a busy indicator, not 70% completion. |
| [`TutorThinkingBubble`](../lib/shared/widgets/tutor_thinking_bubble.dart) | Tutor busy region in embedded and routed lesson conversations. | Themed bubble, labelled Thinking state and AppLoader; optional avatar/padding treatment. Use for tutor context, not every loading region. |
| [`AppStateView`](../lib/shared/widgets/feedback/app_state_view.dart) | Initial loading/empty/error region; Home, Daily, routed entry fallback, achievement browser. | Title, optional message, loading and optional action label/callback. Caller chooses the state and operation. It supplies a Column, **not** its own scrolling; constrain/wrap it safely. |
| [`AnswerOption`](../lib/shared/widgets/questions/question_presentation.dart) | Complete-label native option in Practice, Daily, Ranked and routed question nodes. | Selected/correct/incorrect, visible state icon, disabled callback/locked presentation, 56 px minimum and wrapping body. ID/label/order/correctness come from the caller. It does not submit, time or score. |
| [`QuestionMetadata`](../lib/shared/widgets/questions/question_presentation.dart) | Wrapping difficulty/mode/source labels in the question players. | Actual supplied metadata; quiet semantic foregrounds. Do not invent provenance or difficulty to fill a chip. |
| [`AnswerFeedback`](../lib/shared/widgets/questions/question_presentation.dart) | Practice/Daily/Ranked answer result. | Correct/incorrect or possible timeout, actual correct answer, live-region semantics. A wrong answer alone is not evidence of a particular misconception. |
| [`QuestionSolutions`](../lib/shared/widgets/questions/question_presentation.dart) | Practice/Daily Book and Alternative methods. | Actual explanation/method, optional alternative and preferred reason/callback; explicit unavailable explanation fallback. No generated tutor/reason content or grading logic. |
| [`SessionMetrics`](../lib/shared/widgets/questions/question_presentation.dart) | Wrapping whole label/value groups; Daily hub/result, friendly duel and learner performance. | Explicit `(label, value)` records; preserves meaning while reflowing. Caller formats numbers/units and N/A. Not a chart or a generic stats fetcher. |
| [`SessionNotice`](../lib/shared/widgets/questions/question_presentation.dart) | Retained-content failure notice; Daily and social lists/profiles. | Live message + Retry with wrapping layout. Retry calls the supplied failed operation; it does not replace useful cached content. |

### Sheets, surfaces, identity and social pieces

| Component / source | Purpose / current callers | Reuse, states and limits |
|---|---|---|
| [`showAppSheet<T>`](../lib/shared/widgets/sheets/app_sheet.dart) | Common short/medium detail sheet; difficulty, dates, hints, tutor, selectors and tool information. | Live theme, keyboard padding, safe area, max width/height, fixed header and scroll body. Return typed values via Navigator.pop. It already owns vertical scrolling: do not place an unbounded Expanded/ListView in its builder. A long paginated/draggable flow may need its own bounded body. |
| [`AppSheetSurface`, `AppSheetHeader`](../lib/shared/widgets/sheets/app_sheet.dart) | Same framing for custom sheets; roadmap dock and achievement browser. | Surface theme/radius plus labelled Close/header semantics. These primitives do not provide their own list controller, paging, modal-opening logic or busy dismissal policy. |
| Native `AlertDialog` + `AppearanceTheme` | Signup account switch, Profile signout, practice/daily exit, friend removal, scan information. | Existing convention is a native, scrollable dialog with truthful Cancel/confirm actions, explicit destructive color pairing and caller-owned busy/mounted checks. **No universal AptiquDialog remains.** Do not resurrect the removed helper. |
| [`SocialSurface`](../lib/features/social/widgets/social_widgets.dart) | Quiet grouped social surface; duel, requests, learner profile/performance. | Material surface, padding (default 16), radius (default 16). `highlighted` is accepted but currently does not alter its rendering; do not assume it adds glow/border. It is not a mandatory wrapper for every section. |
| [`LearnerAvatar`](../lib/features/social/widgets/social_widgets.dart) | Actual avatar or initial; Ranked history, social identity and level-up. | Person map `name`/`avatarUrl`, radius, optional squared shape and explicit known presence. Failed/missing image falls back to an initial; unknown presence has no status dot. `highlighted` currently has no visual effect. No stock-person fallback. |
| [`SocialButton`](../lib/features/social/widgets/social_widgets.dart) | Thin AptiquButton wrapper; Friends and friendship actions. | Primary/secondary outline, loading, optional icon, optional expanded width. Reuse for this domain; the underlying shared button is enough elsewhere. |
| [`LearnerTile`](../lib/features/social/widgets/social_widgets.dart) | Friend/search/picker row in FriendsScreen. | Separate identity and relationship activation targets, detail/actions/picker behavior. Does not decide relationship rules or fetch identity. |
| [`SocialEmptyState`](../lib/features/social/widgets/social_widgets.dart) | Friends/request empty regions. | Icon/title/message; no generic retry/fetch policy. Use AppStateView when its recovery contract is needed. |
| [`SocialPageAppBar`](../lib/features/social/widgets/social_profile_chrome.dart) | Friends, requests and learner-profile chrome. | Native back, title/trailing/centering and measured toolbar height helper. Not the Home tab bar. |
| [`SocialIdentityHeader`, `SocialLevelBadge`](../lib/features/social/widgets/social_profile_chrome.dart) | Request and learner-profile identity, level and optional XP/presence/detail. | Measured avatar/name composition and whole-label wrapping. SocialLevelBadge is a textual level label; **not** a reusable ranked-tier artwork widget. |
| [`FriendRequestCard`](../lib/features/social/widgets/friend_request_card.dart) | Request identity/date/actions in FriendRequestsScreen. | Supplied request and action content; preserves response/busy behavior. Do not use as a generic card for unrelated lists. |
| [`FriendshipActions`](../lib/features/social/widgets/friendship_actions.dart) | Shared relationship controls across Friends, requests and profiles. | Existing relationship/version/busy and remove-confirm workflow. Reuse the actual supported actions; a visual change must not invent a social operation. |
| [`LearnerProfileContent`](../lib/features/social/widgets/learner_profile_content.dart), [`LearnerPerformanceCard`](../lib/features/social/widgets/learner_performance_card.dart) | FriendProfileScreen identity, metrics, performance, badges and supplied summaries. | Preserve unknown/N/A, difficulty data and metric denominators. Own Profile has different data semantics; do not plug it in merely because the layout looks similar. |
| [`LearnerActivityWindow`](../lib/features/social/widgets/learner_activity_window.dart) | FriendProfileScreen paged activity section. | Loading/cache/error/paging and actual activity/date display. It is not a stateless general-purpose calendar. |

`SocialIconPanel` is also defined in `social_profile_chrome.dart`, but has no current construction caller. Its existence is not evidence that every icon needs a panel. Inspect suitability before using it; do not invent a larger “icon-card system” around it.

### Learning, navigation and global presentation

| Component / source | Purpose / current callers | Reuse, states and limits |
|---|---|---|
| [`TopBarZone`](../lib/features/home/presentation/widgets/top_bar_zone.dart), [`BottomNavZone`](../lib/features/home/presentation/widgets/bottom_nav_zone.dart) | Home shell identity/progression and five destinations. | Full identity in semantics; native selected controls, pending social indication and measured nav height/reflow. Keep the existing destination order and fullscreen restoration. Not generic nested-page navigation. |
| [`HomeDashboardContent`](../lib/features/home/presentation/widgets/home_dashboard_view.dart) | Home populated/empty/loading/cached/error and next action. | Supplied metrics and callbacks; sub-sections remain local compositions rather than a universal dashboard schema. |
| [`ActivityCalendar`, `YearActivityCalendar`](../lib/features/home/presentation/widgets/home_dashboard_view.dart) | Home consistency; activity calendar also used by social activity. | Actual days, month/year views, accessible dates-as-list/day detail and timezone. Intentional map/calendar exploration differs from forcing prose into horizontal scrolling. Preserve each calendar's actual inputs. |
| [`AchievementBrowser`](../lib/features/home/presentation/widgets/achievement_browser.dart) | Home achievement sheet. | Caller-provided fetchPage/badgeBuilder, paging/refresh/dedup/cache/error. Uses server-authored achievement definitions; do not make a local achievement rules catalog. |
| [`ConstellationRoadmapView`](../lib/features/home/presentation/widgets/constellation_roadmap_view.dart) | Topics map/list, subject choice, zoom/fullscreen and dock. | Existing curriculum order, lock/current/completion semantics and reduced-motion camera. It is a domain view, not a generic graph/layout widget. |
| [`TopicDetailsSheet`, `TopicActionButtons`](../lib/features/home/presentation/widgets/topic_details_sheet.dart) | Topic/subtopic progress and Practice/Start/Continue/Replay. | Draggable-sheet scroll controller and caller-owned callbacks; measured action rows, compact-height scrolling footer, fixed Close. Inspect actual availability before exposing a play action. |
| [`NodeRendererFactory` and node widgets](../lib/features/lesson/views/widgets/node_renderer_factory.dart) | Routed CONTENT/CHOICE/QUESTION/TEXT_INPUT/COMPLETION input dispatch. | Preserve action IDs, next-step contract, submission/retry/doubt callbacks and unknown-node explanation. This is not the embedded player's controller abstraction. |
| [`DoubtSheetWidget`](../lib/features/lesson/views/widgets/doubt_sheet_widget.dart), [`VoiceStubSheet`](../lib/features/lesson/views/widgets/voice_stub_sheet.dart), [`ImageStubDialog`](../lib/features/lesson/views/widgets/image_stub_dialog.dart) | Routed tutor/tools. | Tutor preview has a 500-character question limit, busy/error/retry/mounted safety; current stub is disclosed. Voice/Scan are Coming soon. Do not represent these as operational voice/camera integrations. |
| [`GlobalOverlayGate`, `GlobalOverlayTask`, `GlobalInvitationAction`](../lib/core/presentation/global_overlay_gate.dart) | Root navigator observer, task-owner registration and Daily invitation toolbar entry. | Guards presentation during critical work/modal transitions. Register/release task ownership correctly. Does not pause a clock, extend an invite or decide server outcome. |
| [`SocialOverlay`, `SocialInvitationDialog`](../lib/features/social/social_overlay.dart) | Global invitation review/presentation coordination. | Automatic deferral for modal/editing/keyboard/task/background work, monotonic deadline, manual review and account ownership. Back from review does not implicitly reject; do not bypass with another independent global dialog. |
| [`LevelUpOverlay`](../lib/features/home/presentation/widgets/level_up_overlay.dart) + [`XpController`](../lib/core/progression/controllers/xp_controller.dart) | Actual identity/final-level celebration and queued/coalesced display. | Native bounded dialog, reachable one-time Continue and reduced motion; actual XP updates occur independently of nonessential presentation. Do not create local reward calculations. |

## F. Interaction and UX patterns

### Navigation and state ownership

Home's five tabs remain **Home → Topics → Practice → Ranked → Friends**. `AppRouter` guards signed-out and incomplete accounts and validates route extras for session/match entry. Main routes include `/login`, `/signup`, `/`, `/profile`, `/daily-streak`, `/daily-challenge-quiz`, `/practice-session`, `/pvp-arena`, `/ranked/leaderboard`, `/ranked/seasons`, plus `/lesson/:slug` and `/lesson-step/:stepId`; social routing adds `/friends` and `/friendly-duel/:id`. Preserve query parameters such as lesson `stepId` and duel `play=1` and the existing typed extras. These are route contracts, **not proof of public native app-link configuration**.

Use the existing tab/controller callback for a shell destination and the appropriate router/nearest Navigator for a detail or modal. Preserve history and state; do not replace a push with go/pop solely to simplify a screenshot. Device Back exits Home fullscreen presentation before leaving the shell. Practice/Daily/friendly/ranked exit behavior is feature-specific, not one interchangeable “Leave” callback. Unknown routes use Page unavailable / Return to Home. Signup's account switch is an explicit existing auth action with cancellation, not an invented unguarded Back route.

### Actions, choices and forms

Give the current task one clear primary action. Outline/text actions are useful for secondary/cancel/detail intent. A destructive FilledButton uses error/onError deliberately. A busy action retains a stable label and prevents duplicate work; a disabled callback alone does not replace the controller's async guard. Dismissal during an await must remain mounted-safe.

Use segmented controls for short exclusive sets, wrapping chips when actual labels need space, checkbox selection for multiple items, a date picker for dates and radio/list selection for longer exclusive sets. Search can improve genuinely long lists when supported by the task; do not add arbitrary control variety. Current signup uses required name/DOB/gender/belief/country fields, with “Prefer not to say” choices where supported. Keep those values, validation policy, first-invalid focus and autofill/keyboard handling intact. The shared field does not own that policy.

Question selection is deliberately different by player: Practice/Daily have a selected option and explicit submit/confirm; Ranked and the routed question widget disclose immediate submission. Preserve each timing, lock, option order, real ID and retry behavior. Visual letters A/B/C/D must not replace server answer IDs.

### States, confirmations and sheets

- Initial loading, empty, error, cached refresh failure, submission and completion are distinct. An initial failure must stop loading and offer the failed operation's recovery. Retain usable cached content with a notice when appropriate.
- Use labelled errors near the task, live-region announcements for relevant updates, and actual supplied completion/reward values. Do not convert unknown/no data into invented zeroes, a fabricated progress percentage or generic success.
- Confirm meaningful destructive/exit actions using the existing feature contract. Use truthful consequences, a clear cancel path, readable destructive pair and guarded busy state. Do not add confirmations to every reversible UI choice.
- Common detail sheets use showAppSheet; custom paginated/draggable bodies use the surface/header pieces. Keep Close reachable, keyboard/safe insets accounted for, long content scrollable, and actions reachable at short height. Native AlertDialog uses `scrollable: true` where content can grow.
- Root SocialOverlay coordinates invitations/level-up. Timed work and user editing take priority over automatic celebration/dialog appearance; manual invitation review stays available. Do not restart a deadline to make UI convenient or let dismiss/back send a response accidentally.

### Accessibility, responsiveness and motion

Use the app's 48 px hit-region standard without overlapping expanded targets. Reading text must wrap/scroll naturally at real text scale; never shrink the approved type to make a layout pass. Icon-only controls need meaningful tooltips/semantics. Selection, correctness/lock and busy state need explicit non-color cues. Prefer native focus/keyboard activation and sensible traversal; preserve focus after modal review and avoid duplicate wrapper/button announcements.

Verify normal text at least 4.5:1 against the actual resolved/composited background, with 3:1 reserved for qualifying large text/meaningful non-text controls. Disabled controls have a documented exception, but an instruction must not be made unreadable by styling it as disabled. Theme declarations alone cannot prove effective button child contrast.

`MediaQuery.textScalerOf(context)`, available width/height and `textFits` guide reflow. `MediaQuery.disableAnimationsOf(context)` disables decorative loader rotation, roadmap camera motion and celebration transitions; Profile's custom route transition also honors it. Keep visible busy state when motion is reduced. Avoid unlimited `pumpAndSettle` on an intentional repeating loader; use bounded frames.

For substantial shared/visual work, inspect actual Flutter renders in Light/Dark at normal phone size and the hardest long-content/enlarged/keyboard state. The established G envelope is 320×568, 390×844, 430×932, 844×390 and 768×1024 at 1.0/1.3/2.0 text scales, with additional 568×320/2× sheets. Scale the verification to the change; not every copy edit needs the entire historical matrix. “No overflow” alone does not establish good hierarchy or useful reading space.

## G. Icons, images, ranked badges and achievements

Current Flutter controls primarily use **Material `Icons`** (rounded/outlined choices selected for their task); `uses-material-design: true` bundles Material icons. No separate custom icon font/family is used. Ranked Leagues Phase 4 adds the focused `RankedBadge` artwork component under `lib/features/pvp/ranked/ranked_widgets.dart`. Native icon tools use labelled targets, while decorative icons inside a labelled control can be excluded from semantics.

| Existing asset / source | Current status and use |
|---|---|
| [google_g.png](../assets/images/google_g.png) | Actual Google mark used by AptiquButton.google; provider-specific white surface/dark foreground, not an app reward icon. See [provider source record](../assets/fonts/google_sans/SOURCE.md). |
| [ranked artwork](../assets/images/ranked) | `rank_unranked.webp`, `rank_bronze.webp`, `rank_silver.webp`, `rank_gold.webp`, `rank_platinum.webp`, `rank_diamond.webp` exist. Ranked Leagues Phase 4 explicitly bundles `assets/images/ranked/` and maps all six through `RankedLeague`/`RankedBadge`. Actual server league/qualification controls the selection; the image filename does not determine eligibility. Alpha/artwork is preserved, decoded size follows logical bounds/device ratio, and adjacent text/semantics plus an icon fallback keep the meaning accessible. |
| [topic artwork](../assets/images/topics) | `01_current_topic_play.webp`, `02_topic.webp`, `03_subtopic.webp` exist but are not referenced by current Flutter code or explicitly bundled as a subdirectory. Current map nodes use Material icons/painter presentation. |
| [login artwork](../assets/images/login) | Bundled via `assets/images/login/` in `pubspec.yaml`. Three onboarding banners (`aptiqu_onboarding_learn.webp`, `aptiqu_onboarding_practice.webp`, `aptiqu_onboarding_compete.webp`) used by the active automatic Login carousel in order (Learn -> Practice -> Compete) with 1-liner captions, light/dark mode support, without indicator dots. Previous `small_logo.jpeg` is deleted. |
| Native launcher assets | Android [res](../android/app/src/main/res) supplies `ic_launcher` / `ic_launcher_round`, selected by [AndroidManifest](../android/app/src/main/AndroidManifest.xml). iOS uses [AppIcon.appiconset](../ios/Runner/Assets.xcassets/AppIcon.appiconset). Artwork/export folders such as `assets/images/new app icon/` and `assets/images/app_icon_set/` are separate from those platform outputs; do not overwrite existing exports or platform changes without a task requiring it. |

Check [pubspec.yaml](../pubspec.yaml) before using a stored image: its `assets/images/` entry does not establish that each nested reference folder is bundled. See [Ranked Phase 4 handoff](RANKED_LEAGUES_PHASE_4_HANDOFF.md) for the focused badge/standing/result contracts and [render index](ranked_phase4/README.md) for actual themed evidence. Font/provider source records above remain their respective technical references.

Ranked Leagues presentation uses the existing semantic palette/type roles. `RankedStandingView`/`RankedSectionView` group actual Elo, qualification and ordinal separately from XP. Home retains the legacy last-match presentation when an older API omits the optional section; Profile retains Appearance immediately under identity. The paginated browser measures actual name/position text before choosing a full-width long-name composition. A one-time inline `RankedResultView` uses committed event IDs and secure cosmetic receipts; text/actions remain available during its finite transition. Reduced motion/backgrounding shows the final badge immediately, and demotion stays neutral/static. This adds no global promotion modal or rating logic. Active/pending matches can be discovered/resumed from the lobby; unfinished-match exit restrictions remain as recorded below.

Achievements currently use server-authored titles/descriptions/progress/earned state, native achievement icons and the achievement browser. SocialLevelBadge displays supplied learner level; level-up presents the actual supplied level. Do not infer a ranking threshold, additional reward or achievement rule from an image filename.

For subsequent authorized badge/artwork work, keep a mature, legible silhouette at its real display size, controlled detail and consistent visual weight. Preserve the violet/teal/amber identity and neutral reading surfaces; use tier variation purposefully without making adjacent UI a competing glow/gradient palette. State must also be communicated by text/shape/semantics. Inspect available artwork, licensing, theme contrast and asset registration first; establish a focused component only when an actual supported use case needs it. This handbook creates no artwork or new badge contract.

## H. Patterns to avoid — and why

| Avoid | Design reason / better default |
|---|---|
| Repeating heading → explanation → full-width field → large gap for every item | Makes a task slow and overly formal. Group related content; choose appropriate rows, chips, lists and concise state. |
| Forced horizontal density | Long content/large text needs room. Measure fit and wrap whole controls; readability outranks saving a row. |
| Excessive glow, gradients, blur and random accent colors | Competes with learning and weakens state meanings. Use quiet surfaces and purposeful brand/status emphasis. |
| Tiny metadata or shrinking type to silence overflow | Prevents reading and weakens accessibility. Reflow, scroll or simplify hierarchy instead. |
| White text on any colored button, or explicit child colors overriding native foreground | Correct pairs vary between appearances. Use the matching on-color and verify the rendered state. |
| Unnecessary nested cards and boxed icons everywhere | Adds noise without adding meaning. Use selective groups, separators and lighter rows. |
| Oversized empty controls or sub-48 px targets | Wastes space or makes input unreliable. Use content-driven minimums and real hit regions. |
| A new generic widget that duplicates the button/sheet/answer/state system | Creates drifting fixes and inconsistent states. Inspect existing APIs/callers first; create a focused abstraction only for a distinct repeating need. |
| Hardcoded dark colors, static colored text styles and recreated legacy aliases | Breaks Light/System and overlay inheritance. Consume active roles. Removed `AptiquColors`, legacy dark theme, `AptiquDialog`, `AptiquBadge`, `CyberAmbientBackground` and `LearningMapTopicCard` are not current building blocks. |
| Fabricated avatars, numbers, completion rewards, presence or tool availability | Undermines trust and changes product meaning. Show actual data, N/A, a real initial or an honest unavailable state. |
| Generic AI dashboard decoration unrelated to the task | AptiQu has lessons, curriculum, practice and competition with distinct needs. Let the task and content determine composition. |

## I. Practical recipes

These are small illustrative compositions using current APIs, **not new exported components or features**. Follow the existing screen's imports/state owner, and do not duplicate a domain component that already solves the use case.

### Theme, typography and a paired surface

```dart
import 'package:aptiqu/core/theme/aptiqu_tokens.dart';

Widget supportingMessage(BuildContext context, String message) => Material(
  color: context.colors.secondaryContainer,
  borderRadius: BorderRadius.circular(AptiquRadius.panel),
  child: Padding(
    padding: const EdgeInsets.all(AptiquSpace.lg),
    child: Text(message, style: context.type.bodyLarge!.copyWith(
      color: context.colors.onSecondaryContainer,
    )),
  ),
);
```

The foreground and fill resolve together in both themes. For a normal reading surface use surface/onSurface. For a standalone live-themed modal, use the themed context supplied by AppearanceTheme or showAppSheet.

### Existing field and busy action

```dart
import 'package:aptiqu/shared/widgets/inputs/aptiqu_text_field.dart';
import 'package:aptiqu/shared/widgets/buttons/aptiqu_button.dart';

// Inside the caller's Form. Controller owns validation and save effects.
Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
  AptiquTextField(
    controller: nameController,
    label: 'First name',
    enabled: !busy,
    textInputAction: TextInputAction.next,
    validator: validateFirstName,
  ),
  const SizedBox(height: 16),
  AptiquButton(label: 'Save', isLoading: busy,
    onPressed: busy ? null : save),
]);
```

Keep the label while busy and use an operation guard in the caller. This does not replace SignUpScreen's established required fields/validation. Use AnswerOption for an actual question option instead of repurposing a text field or button recipe.

### Detail sheet and native confirmation

```dart
import 'package:aptiqu/shared/widgets/sheets/app_sheet.dart';

await showAppSheet<void>(context: context, title: 'Details',
  builder: (sheetContext) => Text(message,
    style: Theme.of(sheetContext).textTheme.bodyLarge),
);
```

For a confirmation, follow the existing Profile/friend-removal pattern rather than looking for the removed AptiquDialog:

```dart
import 'package:aptiqu/core/theme/appearance_theme.dart';

final confirmed = await showDialog<bool>(context: context,
  builder: (dialogContext) => AppearanceTheme(builder: (context) => AlertDialog(
    scrollable: true,
    title: const Text('Remove item?'),
    content: const Text('Explain the actual consequence here.'),
    actions: [
      TextButton(onPressed: () => Navigator.of(dialogContext).pop(false),
        child: const Text('Cancel')),
      FilledButton(style: FilledButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.error,
        foregroundColor: Theme.of(context).colorScheme.onError),
        onPressed: () => Navigator.of(dialogContext).pop(true),
        child: const Text('Remove')),
    ],
  )),
);
// Check confirmed == true and caller lifetime/busy state before the real action.
```

This example supplies no delete operation. For existing friend/account/session workflows reuse their actual confirmation and consequences, not the generic example text.

### Content-driven action layout

Inspect TopicActionButtons before writing a new equivalent. For a different domain that needs two related actions, the existing fit pattern is:

```dart
import 'package:aptiqu/shared/widgets/layout/text_fit.dart';

LayoutBuilder(builder: (context, box) {
  final labelWidth = (box.maxWidth - 12) / 2 - 32; // gap + button padding
  final fits = [secondaryLabel, primaryLabel].every((label) =>
    textFits(context, label, Theme.of(context).textTheme.labelLarge!, labelWidth));
  final secondary = OutlinedButton(onPressed: cancel, child: Text(secondaryLabel));
  final primary = FilledButton(onPressed: proceed, child: Text(primaryLabel));
  return fits
    ? Row(children: [Expanded(child: secondary), const SizedBox(width: 12),
        Expanded(child: primary)])
    : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        secondary, const SizedBox(height: 12), primary]);
});
```

Use the actual label style/padding of the real control. A matching width alone is insufficient if the resulting fixed header/footer leaves no useful reading height. Test the caller with real long text and enlarged scale.

### Establishing a new component

Search the inventory/source and compare behavior, not just appearance. If a real repeating use case is missing, start with a small feature-local widget with explicit data/callbacks; use active roles and native controls. Keep network/state policy out of a visual primitive. Review normal and hardest relevant states in both themes. Promote it to a shared location only when its contract is meaningfully reusable; then update the inventory row and relevant recipe rather than adding overlapping “universal” variants.

## J. Maintaining this handbook and using it with AI tools

Update the relevant section when a reusable component becomes established, a theme/type role intentionally changes, an important interaction is approved, a new icon/asset convention becomes standard, or the current guidance becomes inaccurate. Remove obsolete statements instead of accumulating contradictory appendices. Minor local implementation details and temporary experiments belong in their task notes, not a growing list of permanent rules.

For substantial redesigns, recommend actual Flutter renders and manual review before applying the direction widely. For normal fixes, use appropriate targeted widget/interaction tests and analysis; broaden when shared contracts change. Existing verification references are [phase G coverage](UI_UX_PHASE_G_COVERAGE.md), [rendered evidence](ui_ux_phase_g/README.md), [golden decisions](ui_ux_phase_g/goldens/README.md), [production font support](../test/support/presentation_fonts.dart) and [the G regression suite](../test/phase_g_app_review_test.dart). The approved G checkpoint recorded 820 passing tests; future counts can change. Real fonts are essential before accepting a typography/golden difference. Do not bulk-update goldens to hide drift.

### Portable discovery

The handbook uses repository-relative paths and does not require this chat, a particular model/IDE/OS or local plugin. The small entry files point here rather than copying the design system. They are instructions/context, not automated enforcement.

| Tool / entry file | How this repository routes frontend work | Discovery limitation / verification |
|---|---|---|
| Codex / AGENTS-compatible agents: [AGENTS.md](../AGENTS.md) | Original instructions are preserved; a scoped Flutter UI section points here. | Codex discovers its applicable instruction chain at run/session start, with override/size limits. Other tools' AGENTS support differs. Check active instructions after opening the repository. [Official Codex guidance](https://developers.openai.com/codex/guides/agents-md). |
| Claude Code: [CLAUDE.md](../CLAUDE.md) | Imports root AGENTS.md so adding CLAUDE.md does not shadow the existing rules; its frontend pointer is conditional on UI work. | Loading/import behavior is tool/version/configuration dependent. Check the tool's memory/instruction view; a link is not proof the handbook was read. [Official Claude memory guidance](https://code.claude.com/docs/en/memory). |
| GitHub Copilot: [.github/copilot-instructions.md](../.github/copilot-instructions.md) | Short repository instruction conditionally directs Flutter UI tasks here. | Feature/IDE support and enabled repository instructions vary; some review contexts limit instruction size. Check referenced instructions. [Official repository instructions](https://docs.github.com/en/copilot/how-tos/configure-custom-instructions/add-repository-instructions). |
| Cursor: [.cursor/rules/flutter-ui.mdc](../.cursor/rules/flutter-ui.mdc) | File-scoped rule for `lib/**/*.dart` and `test/**/*.dart`, with a frontend description and canonical pointer. | File globs require matching files in context; a planning-only prompt may not attach the rule. Mention it or provide the handbook explicitly. [Official Cursor rules](https://cursor.com/docs/context/rules). |

A model without repository access cannot discover these files by itself. Include the handbook or attach the relevant sections in that environment. Even supported tools can have instruction discovery disabled, overridden, truncated or simply fail to follow a pointer. Ask the agent to name the files/components it actually inspected; there is no new hook, lint package or CI enforcement here.

Example portable prompt:

> Read `AGENTS.md` and the relevant sections of `docs/FRONTEND_DESIGN_SYSTEM.md`, then inspect the actual theme and reusable widgets for this task. Implement [specific frontend change], using suitable existing components and both-theme/accessibility patterns. Preserve relevant behavior; explain any intentional design-system departure. Verify the affected interaction and enlarged-text states. Treat this request as the task scope, not permission for an unrelated redesign.

### Provenance, approval and known limits

This handbook was researched against the post-G Flutter implementation and approved composition revisions. [UI_UX_AUDIT.md](UI_UX_AUDIT.md) and [UI_UX_REVAMP_PLAN.md](UI_UX_REVAMP_PLAN.md) are historical diagnosis/proposals, not proof that every proposed token, search picker or abstraction shipped. [UI_UX_REVAMP_PROGRESS.md](UI_UX_REVAMP_PROGRESS.md) records phase outcomes and the user's completion/approval of G; [UI_UX_DESIGN_PREFERENCES.md](UI_UX_DESIGN_PREFERENCES.md) preserves the composition feedback. This handbook is the current frontend convention reference.

The earlier revamp left the Ranked permanent-outage policy unresolved. In Ranked Leagues Phase 2 the user approved system-failure voids without Elo/XP, while ordinary disconnects continue timed play. A server-confirmed `CANCELLED` / `SYSTEM_VOID` snapshot now shows Match cancelled and enables the existing Return to Ranked action; it does not infer a win/draw or award XP. Other unfinished matches retain Refresh match and the existing exit restriction. Do not invent Leave/Forfeit, winner/reward values or an acknowledgement that the existing contract does not supply. Terms/Privacy destinations remain explicitly deferred/disabled. Tutor/Voice/Scan availability must remain truthful. These limitations do not reopen the approved G phase or authorize work outside a future task.

The recorded G evidence consists of fixture renders/tests, analysis and a debug APK; the agent did not establish native TalkBack/VoiceOver, live multi-device or release verification. User manual approval and agent-collected evidence are different facts. No release is requested or performed by this documentation task. A future release decision and any deferred policy/integration work need their own scope.
