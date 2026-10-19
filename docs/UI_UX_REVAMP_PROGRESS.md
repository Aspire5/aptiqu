# UI/UX revamp progress

## Current checkpoint

- **Phase G — Final Quality Assurance and Cleanup: COMPLETED AND MANUALLY APPROVED by the user.**
- The user explicitly requested no release and chose to leave the Ranked outage/exit policy unresolved. That deferred issue does not reopen G or block the separately authorized documentation task. No release was performed.
- **Phase F: APPROVED** by the user with `APPROVE PHASE F`. This authorizes G only; release requires separate final approval.
- **Phase E: APPROVED** by the user with `APPROVE PHASE E`. That checkpoint authorized F; F approval subsequently authorized G.
- **Phase D: APPROVED** by the user with `APPROVE PHASE D`. Later approvals are recorded above.
- **Phase C revision: APPROVED** by the user with “APPROVE PHASE C, proceed with next.” Later approvals are recorded above.
- Phase A approval is explicit in the conversation: “I loved it!” and **`APPROVE PHASE A`**, followed by authorization to proceed with the next phase.
- Additional approved requirement: “let the user configure the mode - System (Default) | Light | Dark … at any time from the profile screen.” This moves the appearance selector into B. The accepted A palette/type/surface direction was retained.
- Phase B approval is explicit in the conversation: **`APPROVE PHASE B`**. This authorized C, not D–G. No individual device-check outcomes were supplied with approval.
- During C the user approved the legal UI with destinations deferred: “yes add the ui, i'll set the links later.” Missing policy URLs no longer require clarification for this implementation checkpoint.
- The initial Phase C handoff was **not approved**. The user requested **`REVISE PHASE C`** with screenshots, Stitch HTML and composition preferences; that revision was subsequently explicitly approved before D started.
- Current G scope is completed and approved. The user’s approval is recorded separately from the agent’s fixture/native verification evidence below. Ranked recovery remains a known deferred limitation; no release is in scope. F remains approved and preserved.
- Completed E scope: Friends/picker, requests, learner profiles, friendly duel rooms, Ranked lobby/arena and scoped confirmations/recovery. Preserve supported social/match operations, timers, IDs, scoring and rewards.
- The existing audit and revamp plan are preserved as reference documents, including their original proposal status.

## Phase G — Final Quality Assurance and Cleanup — 19 October 2026

Explicit authorization: **`APPROVE PHASE F`**. This authorizes final UI QA/cleanup, not release. The saved palette, families, sizes and composition preferences remain in force. G was subsequently manually approved by the user, who requested no release and explicitly deferred the Ranked outage/exit policy. The historical verification limitations below remain factual; they are not a pending G approval gate.

| Surface / work | Implemented result | Preservation / coverage |
|---|---|---|
| AptiquApp / root appearance | Saved System/Light/Dark at MaterialApp.router, both approved themes, live root system-bar annotations and saved/OS startup brightness. Immediate appearance updates match the already migrated surfaces. | Root OS/override/reload test retains route, controller, draft and a single lesson start; UX-01 |
| ProfileScreen / AppearanceSetting | Remove obsolete partial-dark-mode note; current-mode badge uses the existing 12 px label role for readable raster contrast. | Original preference storage, retry and selector behavior; UX-01/02/03 |
| HomeScreen / ChatPlaygroundZone | Compact embedded-lesson header at limited height, full title in a stable reading slot, labelled Fullscreen lesson/Exit fullscreen lesson controls using existing presentation state. Stable keyed Home content preserves draft/controller state. Native Back restores fullscreen shell; Close lesson retains Home behavior. | Both-theme enlarged-landscape draft, controller identity, no submission/request, Back/Close tests; same messages/actions/IDs; UX-06/09/14 |
| TopicDetailsSheet / TopicActionButtons | Measure actual labels before choosing a row; keep Whole topic actions in the reading scroller when sheet height is limited. Close stays fixed. | Fixes reproduced 14 px overflow at 568×320/2×; same topic/subtopic callbacks and progress; UX-04/06/07/21 |
| Practice / Daily / Home notices | Replace remaining fixed dark/red/white overrides with native or approved error foreground/background pairs. Daily defensive notices keep the original text and guards. | Native root notice fixtures in both themes, measured visible snackbar contrast; no request/rule changes; UX-01/02/03 |
| AppRouter fallback / motion | Plain Page unavailable with Return to Home, inherited root appearance; Profile's custom transition honors disableAnimations. | Existing routes, aliases, parameters/extras and auth/onboarding guards retained; UX-09/10/19/24 |
| Font availability | Bundle exact verified Outfit/Plus Jakarta Sans static weights 400/500/600/700/800 with OFL licenses/source hashes, and disable runtime font fetching. | Families/type sizes unchanged; production asset-manifest load test; all ten APK font payloads match verified hashes/bytes; UX-22 |
| Legacy cleanup | Remove unused legacy theme/colors, AptiquDialog, AptiquBadge, CyberAmbientBackground and LearningMapTopicCard; retain only used typography roles. | Six presentation files removed after reference search; registered screens/active loaders retained. Model checks remain, card test intent moved to live map/dock assertions; UX-23 |
| Golden review | Correct substituted-font fixtures and select explicit Dark for old dark comparisons. Individually inspect/accept 11 baseline pairs, including the newly exposed Custom comparison. | Before/after files and hashes preserved; no bulk update. A–F PNG evidence unchanged; UX-22 |

### Validation and actual evidence

- **Final full `flutter test --no-pub --dart-define=CAPTURE_PHASE_G=true`: 820 passed, zero failures.** This includes 550 G cases (540 screen/theme/size/scale cases plus 10 overlay/root/fullscreen cases), the independent production-font asset test, extended B/C short-landscape coverage and all existing state/action regressions. No missed-tap warnings or caught layout exceptions remain. Earlier integration runs also passed 458 and then 818 tests before the final reading-space refinement.
- **`flutter analyze --no-pub`: no issues.** **`flutter build apk --debug --no-pub`: passed.** **`git diff --check`: passed.** APK: `build/app/outputs/flutter-apk/app-debug.apk`.
- Full G screen envelope: S01–S18 in Light/Dark at **320×568, 390×844, 430×932, 844×390, 768×1024**, each at **1.0/1.3/2.0 actual text scale**, including safe insets, long content and scrolling. At 390×844/1×, all 18 views in each theme pass native target/label and pixel text-contrast guidelines. Additional keyboard/selected/locked/reduced-motion/lifecycle cases remain in A–F.
- **76 fresh actual rendered G PNGs** using safe fixture data and exact approved fonts; normal 18-view theme pairs, representative hard landscape, short Home/Topic/preparation, guarded notices and fullscreen draft. Normal pairs, saved hard landscape and supplemental overlays were visually inspected. Not every matrix case was saved or manually inspected. [Evidence index](ui_ux_phase_g/README.md).
- **11 individually reviewed golden pairs** and before/after hashes saved under [goldens](ui_ux_phase_g/goldens/README.md). All legacy golden comparisons now pass. Generated test failure output was removed after preserving review evidence.
- Compared G against `/private/tmp/aptiqu_phase_g_baseline` (approved F working state, because HEAD predates A): **13 existing production Dart files changed, six confirmed-unused presentation files removed, no new production Dart file**. Approved ThemeData build/typography role definitions, lockfile, root AGENTS and the original audit/plan are byte-verified unchanged. Font asset directories are the only pubspec change; no dependency version changed. [Scope/hash record](ui_ux_phase_g/scope_verification.json).
- A–F PNGs remain unchanged: A 13, B 12, C 16, C revision 32, D 60, E 103, F 84. No backend/database/VPS/migration, models, authored content, lesson operations, scoring/reward rules, endpoint/payload, match policy or friendship-version change entered G.
- Final logs: `/private/tmp/aptiqu_phase_g_final_tests.log`, `aptiqu_phase_g_final_analysis.log`, `aptiqu_phase_g_final_apk.log`. Font source/APK hash verification is persisted in the scope record.

### Approval outcome and retained verification limits

- [Exact Phase G manual steps](UI_UX_PHASE_G_REVIEW.md) and [every S01–S18/O01–O22 plus UX-01–UX-24 acceptance status](UI_UX_PHASE_G_COVERAGE.md) are saved. Device discovery found **no authorized devices**. No install, authenticated live answer/social/match/reward event, real Google provider session, native TalkBack/VoiceOver, OS lifecycle/orientation or iOS/release acceptance was performed by the agent.
- **UX-08 remains an open P1 release dependency:** the existing Ranked service has no supported permanent-outage Leave/Forfeit operation, and reconnect does not supply a full winner/reward/answer acknowledgement result. E's honest waiting/refresh/recovered-history UI is preserved. Separate product/server authorization is needed; no unsupported operation/reward was invented.
- Native Android/iOS screen-reader, keyboard, bars, orientation and two-device server/lifecycle acceptance remain required. Tablet is a fixture sanity check; web/desktop shipping scope is not assumed.
- Terms/Privacy destinations remain disabled and explicitly deferred by the user's instruction. Tutor/Voice/Scan remain disclosed unavailable capabilities; no integrations were added.
- **Phase G is completed and manually approved. No deployment/release is requested or performed. The Ranked outage/exit policy is explicitly left unresolved. Any future release or deferred-policy work has its own scope; this is not a pending G approval request.**

## Permanent frontend handbook — documentation follow-up

The user approved G and requested a portable reference and AI guardrails, with no release or further UI implementation. `docs/FRONTEND_DESIGN_SYSTEM.md` documents the actual post-G theme, typography, architecture, components, composition preferences and known limits. Root `AGENTS.md` retains its original contents and gains a scoped handbook pointer; `CLAUDE.md`, `.github/copilot-instructions.md` and `.cursor/rules/flutter-ui.mdc` supply small compatibility pointers. No application, asset, dependency or test implementation changes are part of this follow-up.

## Phase F — Routed Lessons and Global UI — 19 October 2026

Explicit authorization: **`APPROVE PHASE E`**. The approved palettes, type scale, font families and saved composition preferences carry forward. Phase G is now authorized.

| Surface | Implemented changes | Preservation / audit coverage |
|---|---|---|
| S18 LessonFeedScreen / ChatBubbleWidget | Supplied title or Lesson fallback, visible Ask tutor, measured compact chrome, one coherent conversation/input scroller, themed tutor/user bubbles, initial error/retry and persistent submission error. Unknown nodes explain the limitation instead of disappearing. | Both aliases/start IDs/checkpoints/auth guards retained; route-owned tagged controllers and page keys preserve the previous completion and reject stale/disposed updates; UX-05/06/07/09/10/14/15/24 |
| S18 content / choice / question / text | Native complete-label choices with measured row fit, primary content progression, shared question metadata/answer options, immediate-submit disclosure/selected state, labelled text and Send. A stable keyed input sliver preserves draft/selection when an error appears. | Original action types/IDs/order, trim, response-time measurement and existing request guards; no extra submit/reveal/reward action; UX-02/05/06/10/15 |
| S18 completion | Scrollable summary, full next title, guarded next push, plain unavailable/roadmap-complete states and truthful Return to Home label. | Same supplied next step/slug and original Home destination; Back restores previous route/controller; no fabricated progression; UX-05/06/09/14/24 |
| O15 Ask tutor preview | Bounded live-themed keyboard-aware sheet, fixed Close, persistent label/question, busy/error/retry, long response scrolling, mounted-safe completion and the existing server's 500-character question limit. | Same endpoint/payload; read-only presentation of existing `STUB_RESPONSE` flag as Tutor · Coming soon, not an actual explanation; UX-05/06/07/10/16 |
| O16/O17 tools | Live-themed tools sheet, Voice/Scan Coming soon labels before selection, consistent scroll-safe information/dismissal. | No camera/microphone/upload integration or fabricated lesson submission; UX-07/16 |
| O20 global invitation coordination | Automatic dialogs defer during active routes, embedded lessons, modal/editable/keyboard focus, preparation, background matchmaking/replay and app inactivity. A native review entry preserves access; Daily uses a toolbar mail action to retain feedback reading height. Back keeps a timed entry without automatic re-prompt. | Original response workflow, destination, version/busy behavior and deadline; no accept/reject from dismissal/expiry; existing remaining budget never restarts; owner changes clear only owned presentation; UX-05/10/14/20 |
| O21 LevelUpOverlay / XpController | Approved themed native dialog, actual avatar/initial, compact measured identity/final level, scrollable content and reachable Continue. Short internal transition; reduced motion shows the final level immediately. Pending awards coalesce and wait behind critical work/invitations. | Existing XP/auth updates happen immediately; only nonessential presentation waits; no reward calculation/request changes, no lost queued final level, no cross-account celebration; UX-02/05/06/18/19/20 |

### Composition and contract boundaries

Shared AnswerOption, QuestionMetadata, TutorThinkingBubble, native buttons and AppSheet have real routed consumers. No theme/token/font definition changed. A minimal `GlobalOverlayGate` observes existing root popup transitions and named learning routes; the existing SocialOverlay owns the two global presentation flows rather than introducing a general overlay framework. Home marks its embedded flow. Practice/Ranked controllers publish existing busy flags so changing tabs cannot make background preparation or matchmaking appear idle. Those observers call no server operation and do not cancel/pause work.

Invitations retain their existing server budget using a monotonic received deadline. Repeated inbox updates cannot extend it; expired/deferred items cannot create late automatic dialogs. Already-shown but unanswered invitations remain available through Review after Back. Native modal focus is retained through closing transitions. Expiring notices announce availability once instead of narrating every countdown tick. Explicit Review can open the same existing dialog during work without resetting the underlying timer/answer. Friend requests retain their inbox flow; no new automatic friend-request delivery was introduced.

The existing lesson repository now carries the response message plus the already-present tutor-unavailable flag to its sole controller consumer. All HTTP paths/payloads and lesson model/node schemas remain. Read-only local inspection confirmed `StubAiProvider` and `STUB_RESPONSE`; the UI labels it Coming soon and retains the question instead of presenting placeholder text as teaching. Live response/busy/failure states use deterministic fixtures. **No AI integration or backend readiness is claimed.**

Home/Topics still open the embedded player. S18's existing `/lesson/:slug` and `/lesson-step/:stepId` aliases are reviewable with a signed-in development run using `flutter run --route` and real published identifiers. No production debug launcher or external app-link handler was added. The manual guide explains the exact prerequisite and safe fixture alternative.

Scope compared with `/private/tmp/aptiqu_phase_f_baseline`: **22 existing production files plus one new presentation gate**, and one new focused test file. Prior A–E presentation outside these scoped consumers, every existing test, models, theme/token/font files, dependencies/assets, authored content, audit/plan and all previous renders/golden baselines are preserved. No backend, database, migration, VPS, scoring-rule or infrastructure change, live authenticated action or commit was made. The earlier Practice/Ranked view marker experiment was replaced by controller-owned observation; those two view files match the approved E snapshot exactly.

### Verification and evidence

- Final `flutter test --no-pub --dart-define=CAPTURE_PHASE_F=true`: **256 passed, nine failed tests**. All **44 new F cases passed**. The nine failures are the same ten preserved image comparisons: Practice random; Home consistency/populated/day details; Topics completed; Friends search/requests; learner profile normal/large/empty. No non-golden failure remains and no baseline was automatically accepted.
- F cases exercise all five node types, both real aliases/parameter precedence, next/back/controller ownership, actual action payloads, immediate/duplicate submission, fast error retry, draft/selection/theme retention, keyboard Send/blank suppression, long reading/options/next text, help busy/error/late dismissal/keyboard/unavailable, tool truthfulness, native target/label/text-contrast guidelines in both themes, critical modal and Daily feedback priority, live Ranked deferral, queued/deferred/original-budget expiry, Back/re-review, background matchmaking, focus restoration, editing/keyboard completion release without a route change and account changes. Intermediate targeted XP/Home and invitation checks also passed; the final full run supersedes them.
- **84 actual rendered PNGs** in [the evidence index](ui_ux_phase_f/README.md), with exact production font fixtures. Normal Light/Dark; 320×568 and 568×320 at 2×; 100 px keyboard insets; long tutor/question/choice/completion, unavailable tools, timed-work invitation entries and multi-level dialogs. Representative normal and hard cases in both themes were visually inspected; these are safe example data, not authenticated screenshots. Long reply captures are fixtures, not proof of live AI service availability.
- Final `flutter analyze --no-pub`: **no issues**. `git diff --check`: **passed**. `flutter build apk --debug --no-pub`: **passed**. APK: `build/app/outputs/flutter-apk/app-debug.apk`.
- Baseline comparisons confirm every A–E render/evidence index, all golden files, existing tests, original audit/plan, AGENTS.md and dependency manifests remain unchanged. Only E review approval metadata and the progress/preferences checkpoint were updated alongside new F review/evidence.
- Authenticated multi-account/provider/server/native lifecycle, physical keyboard/system bars, TalkBack/VoiceOver, iOS and release acceptance were not performed. The existing Ranked active Leave/Forfeit server-policy gap, legal URLs and current tutor stub remain explicit dependencies. Root legacy-theme retirement, exhaustive cross-app QA, individual golden review and unused-helper cleanup remain Phase G.
- Manual approval: **AWAITING USER**. [Exact review entry paths and expected results](UI_UX_PHASE_F_REVIEW.md). Saved preferences persist; they do not authorize G.

## Phase E — Social and Competitive Experience — 19 October 2026

Explicit authorization: **`APPROVE PHASE D`**. The approved composition preferences, palettes, fonts, font sizes, semantic pairs and design tokens carry forward. At the E handoff, F had not started; the subsequent explicit E approval authorized F as recorded above.

| Surface | Implemented changes | Preservation / audit coverage |
|---|---|---|
| S14 Friends / picker | One embedded heading; persistent labelled search/stable loading region; compact identity and separate relationship targets; long-name reflow; native pagination, distinct empty/error modes; dedicated Invite a friend picker chrome. | Same debounce/cancel/stale-result protection, cursor/presence behavior and returned picker identity; UX-03/05/12/14 |
| S15 requests | Quiet pending count, grouped identity/date and native equal-width or stacked actions; visible press/focus feedback; loading/error/content scroll together, including enlarged landscape. | Invitation versions, busy/respond guards and return refresh retained; UX-11/12/13/21 |
| S16 learner profile / O19 | Grouped identity/streak/coins/performance, lighter achievements, full large metrics, genuine unavailable values and native named removal confirmation. Existing calendar reused. | Same definitions/relationship operations/IST month cache; fixed existing month retry callback returning a Future from `setState`; UX-06/11/12/21 |
| S17 friendly duel | Role-specific pending/countdown, grouped participants/settings/progress, readable terminal outcomes, initial error replacement, cached retry and active Leave confirmation; pending Back states cancel/reject consequence. | Same 60-second invitation budget, resume/auto-open/session IDs, existing leave/respond endpoints and server rewards; status change during confirmation cannot execute a different consequence; UX-10/12/20/24 |
| O20 incoming invitation presentation | Standard themed scrollable native dialog, sender/expiry/settings, disabled Responding state and semantic error text. | Response version/busy/expiry handling unchanged. Global SocialOverlay delivery/seen/priority/queue arbitration unchanged and deferred F; UX-20/24, presentation only |
| S09 Ranked lobby | Action-first compact summary/rules; queue/cancelling/opening state, acknowledgement timeout/retry, cached/empty/error history, full opponent/outcome/actual XP and neutral no-reward Practice replay. | Existing matchmaking/cancel/replay operations and match-found authority preserved; duplicate queue/navigation/replay guards; UX-04/06/10/13/21/24 |
| S10 Ranked arena | Fixed timer/count, adaptive scores, shared native options/metadata/feedback, immediate-submit disclosure, pending/acknowledged lock, scrollable results, explicit live exit policy, Refresh match recovery and invalid-extra fallback. | Existing server question/answer/score/reward authority; reconnect restores remaining time without restarting a minute or resubmitting; no invented Leave/Forfeit; UX-02/05/06/08/15, with UX-08 dependency below |

The Home shell removes its legacy dark wrappers only for Friends and Ranked; their routed E destinations and scoped dialogs now follow the saved appearance live. Global/routed lesson migration remains F. Shared social helpers consume the approved native buttons/colors/type instead of custom decorative borders, fixed foregrounds or duplicate button semantics. No design-token changes.

### Protocol and preservation boundary

Read-only inspection of the local PvP socket/match implementation confirmed existing AUTH_INIT, JOIN_MATCHMAKING, LEAVE_MATCHMAKING, SUBMIT_ANSWER and RECONNECT_MATCH. The reconnect snapshot returns status/index/remaining time/question/scores, **not** winner, rewards, answer acknowledgement or explanation. Recovery therefore preserves a pending same-question selection without automatic resubmission and uses a completed snapshot only to direct the user to recorded history. Normal completion retains the existing XP update calculation and uses server score/reward fields. Recovery timeout/error/unauthenticated waiting are visible.

The client socket exposes local connection/authentication state and a local CONNECTION_LOST notification, shares concurrent connect attempts and ignores stale replaced-channel callbacks. No server command, API contract or automatic reconnect/cancellation was added. Controllers add presentation/recovery state, single-entry/answer guards, existing command acknowledgement handling and UI error exposure. Existing endpoint parameters/session/question/option IDs and scoring/reward rules remain.

**Open product dependency (UX-08):** there is no active Ranked Leave/Forfeit server operation. Live exit stays blocked with explicit policy text and the supported Refresh match recovery. A permanent server/connectivity failure can still prevent normal completion. A leave/forfeit policy requires separate product/server scope and approval; this UI phase does not invent it or claim to close the gap.

Scope compared with `/private/tmp/aptiqu_phase_e_baseline`: **19 existing production files**, one existing test's intended label/title expectations, and one new focused test file, plus progress/preferences/review/evidence documents. The only additional activity-widget fix is the scoped retry callback. An incidental model formatting change was restored. Prior A–D production files outside this scope, their rendered evidence, shared theme/token/font definitions and every golden baseline are preserved. No backend, database, VPS, migration, model, repository, dependency/asset or authored learning-content changes were made. No commits were requested or created.

### Verification and evidence

- Focused `flutter test --no-pub --dart-define=CAPTURE_PHASE_E=true test/phase_e_social_competitive_test.dart`: **48 passed**. Social identity/action/picker, invitation busy/expiry/error/version, friendship removal, presence/cached failure, actual remote-month retry/cache, all friendly terminal states/own finish/auto-open/confirmation race, queue cancellation/connect/match-found races, replay route, recovery/authentication/timeout/remaining time/pending selection/completed snapshot, invalid route and live appearance retention. Native Android target-size/label guidelines also pass on the arena; existing social target checks execute before their preserved golden differences.
- Full `flutter test --no-pub --dart-define=CAPTURE_PHASE_E=true`: **208 passed, nine failed tests**, all ten preserved golden image comparisons: Practice random; Home consistency/populated/day details; Topics completed; Friends search/requests; learner profile normal/large/empty. This run included 44 E cases; four additional lifecycle/accessibility cases then passed in the complete 48-case focused suite. No non-golden failure remains. Intentional E social changes add to prior visual drift; no baseline was automatically accepted.
- **103 rendered PNGs** with production font fixtures in [the E evidence index](ui_ux_phase_e/README.md): normal Light/Dark, empty/error, requests/profile/activity/removal, all friendly lifecycle states, O20 enlarged scrollable dialogs, Ranked queue/player/pending/locked/feedback/win/draw/loss/AFK/connection loss/recovered completion. 320×568 and 568×320 at 2× cover the hardest controls/confirmations/reading regions; picker includes a keyboard inset. Representative normal compositions and both themes, long metrics/names, keyboard, enlarged/landscape dialogs and recovery states were visually inspected. These are safe example fixtures, not authenticated screenshots. A final four-case recapture keeps friendly win/draw evidence distinct.
- Final `flutter analyze --no-pub`: **no issues**. `git diff --check`: **passed**. `flutter build apk --debug --no-pub`: **passed**. APK: `build/app/outputs/flutter-apk/app-debug.apk`.
- No authenticated device/server social action, match, answer or reward was performed. Native lifecycle/process restoration, multi-device server timing, physical keyboard/system bars, TalkBack/VoiceOver, iOS and release checks remain human/device acceptance, not outcomes established by widget fixtures.
- Manual approval: **explicitly granted with `APPROVE PHASE E`**. No individual device-check outcomes were supplied. [The preserved E review guide](UI_UX_PHASE_E_REVIEW.md) remains historical. This approval authorized F only.

## Phase D — Practice and Daily Learning — 19 October 2026

Explicit authorization: **“APPROVE PHASE C, proceed with next.”** The saved composition preferences and approved visual system carried forward. At the D handoff, E remained unauthorized; the subsequent explicit D approval authorized E as recorded above.

| Surface | Implemented changes | Preservation / audit coverage |
|---|---|---|
| S06 Practice setup | Compact Random/Custom, one question summary, consistently padded settings, native selected subjects/tri-state topic groups, strong Start/Invite, disabled reasons. Short/enlarged viewports scroll the header/action with content. | Existing selection/default/persistence and start/picker operations; UX-01/02/05/06/12/21 |
| S07 Practice history | Grouped metrics, full local dates/readable statuses, lighter rows, neutral replay reward labels, cached-error retry, pending replay label, existing-API pagination and Android Back to setup. | Same history/replay IDs/endpoints; no replay reward changes; UX-06/10/11/12/14/21 |
| S08 player / O12–O14 | Native answer controls, readable body, count/timer/provenance, adaptive friendly metrics, continuous book/alternative methods, safe hint/reason sheets, scrollable results/native exit. Inline submission error/retry preserves selection. Missing Practice route extra recovers to Home. | Answer validation/order/timer/recovery/reveal/abandon/reward calculations unchanged; UX-02/05/06/07/09/10/12/15/19 |
| S12 Daily hub / O08–O09 | Availability first, Start/Resume/finished states, grouped streak/metadata, concise rules/expandable tiers, shared history, honest preparation and inline errors. Back/History disabled during preparation. | Server eligibility/tier/rewards retained; IST deadline copy matches local server source; UX-04/06/10/12/13/20/21/24 |
| S13 Daily quiz / O10–O11/O22 | Native options/shared reading/metadata, stable confirmation, actual-body-constrained persistent feedback, excluded underlying focus/pointer/semantics, guarded Next/result, scrollable actual result, safe empty state and exit copy. | Separate Daily confirmation/timeout flow retained; no hints added, no extra reward claim; UX-02/05/06/07/09/10/12 |

New shared `question_presentation.dart` has real Practice/Daily consumers for options, metadata, feedback, methods, wrapping metrics and compact cached-error notices. Shared themes/tokens/fonts/button/sheet primitives are reused without changing their approved definitions. Practice's old dark-only shell wrapper is removed; Ranked/Friends and all E/F routes/global overlays retain their boundaries. Appearance changes apply live to Practice and Daily.

Scope relative to `/private/tmp/aptiqu_phase_d_baseline`: nine existing production files and one new shared presentation file; one new focused test file. Existing controller changes are limited to UI error exposure, duplicate preparation guarding, existing history pagination/retry, plain loading copy and optional Daily repository injection for deterministic fixtures. The Practice clock/submission/recovery/abandon calculations and Daily timer/answer payload/scoring operations retain their existing behavior. The router change validates only the Practice extra; auth guards and other route builders remain. No models, repositories, dependencies/assets, backend/database/VPS/migration or authored learning content changed. A/B/C source and evidence outside this scope are preserved.

### Verification and evidence

- `flutter test --no-pub --dart-define=CAPTURE_PHASE_D=true test/phase_d_learning_test.dart`: **35 passed**. Covers selection/partial-topic/settings, actual hint counts/reopen, missing reasons, answer retry, cache/page retry, duplicate preparation/submission/Next, real controller expiry/reset, friendly clock recovery, invalid/empty routes, short viewports, semantics and ≥4.5:1 active state/action pairs.
- **60 actual rendered PNGs** in [the Phase D evidence index](ui_ux_phase_d/README.md), using production font fixtures. Representative normal screens in both themes; 320×568 and 568×320 at 2× for the scoped history/hint/exit/result overlays; long Daily feedback and landscape advancing; replay result. Test-only safe example data, not authenticated device screenshots. Representative normal compositions, both theme pairs and hardest overlay states were visually inspected; transient initial font raster captures were recaptured after settling. Previous phase captures/golden files are unchanged.
- Full `flutter test --no-pub`: **164 passed, 9 failed tests**, all the preserved ten Home/Topics/Practice/social golden-image comparisons. Practice now intentionally differs further in D. No non-golden failure remains; no baselines were accepted automatically. The final compact-notice/full-date refinements also passed the focused 35-case capture suite.
- `flutter analyze --no-pub`: **no issues**. `git diff --check`: **passed**. `flutter build apk --debug --no-pub`: **passed**, using the existing Android toolchain.
- Device discovery now sees **Infinix X6739, Android 14 (API 34)**. No install/live authenticated answer/reward action, native assistive-technology/keyboard session, iOS or release verification was performed. APK compilation and fixtures do not substitute for those checks.
- Detailed entry paths, data prerequisites, visual checks, interaction checks and observable expected results: [UI_UX_PHASE_D_REVIEW.md](UI_UX_PHASE_D_REVIEW.md).

## Approved Phase C revision — composition preferences

User preferences are saved in [UI_UX_DESIGN_PREFERENCES.md](UI_UX_DESIGN_PREFERENCES.md), with a durable pointer in root `AGENTS.md` for future authorized UI phases. Preserve the approved palettes, type/font sizes and tokens; improve related rows/groups, task-appropriate controls, visual communication, density and personality. Avoid automatic vertical stacking, repetitive cards and unnecessary explanation. Reference layouts do not authorize copying their styling/data or starting another phase.

| Surface | Revision | Preservation / reference adaptation |
|---|---|---|
| S02 names and introduction | Names share a row when labels/input space fit at actual scale; necessary fallbacks retain a column. Concise step/required status replaces two intro paragraphs. Related gaps use existing 16 px spacing. | Same controllers, required checks, focus/Next/autofill and draft. No font-size reduction to force fitting. |
| S02 gender / O01–O03 entry controls | Native wrapping ChoiceChips replace four vertical radios. DOB/belief/country receive task icons; belief/country can pair on wide readable layouts. | Same strings/defaults, 16 px option/input roles, native selected/disabled states and 48 px targets; suitable calendar/list pickers retained. |
| S11 identity | Avatar beside identity by default when actual name/email/level fit; long/enlarged content determines fallback, replacing the blanket narrow-width/text-scale rule. Level uses a compact native badge/action. | Full identity stays accessible; real image/initial, progress semantics and existing celebration callback retained. |
| S11 appearance | Moved directly after identity; compact segmented System/Light/Dark, selected-mode badge, optional fitting icons. Whole native choices wrap at large text. Repeated mode descriptions removed. | System (Default) semantics, saved preference, immediate switching, error retry and short legacy-dark disclosure retained. Native option type remains 16 px. |
| S11 progress and account | XP/topic progress grouped in one surface, with side-by-side wide layout. Difficulty metrics use lighter rows/columns. Version/signout form a quiet adaptive footer. | Same calculations, percentages, data/recovery behavior and one confirmed logout. Reference header shortcut is not duplicated. |
| S01 Login | Only “These links are not available yet.” removed. | Exact comparison confirms all other Login source unchanged; missing legal controls remain disabled. |

The Stitch/previous screenshots guided composition only. No reference gradients/colors/fonts/dimensions, sample identity/data, or placeholder starter rewards were adopted. Theme files, controllers and routing match the pre-revision snapshot exactly. No backend, database, migration, VPS, dependencies, assets, learning or scoring change was made in this revision. Existing initial C changes remain preserved.

Changed production files relative to the initial C snapshot: Login, signup, Profile, Profile's appearance widget, and one small text-fit layout helper consumed by three real layouts. Existing C tests gained composition checks and a separate capture flag; one XP caption assertion now verifies the same separate roadmap label/percentage. No unrelated application screen was migrated. Comparison snapshot: `/private/tmp/aptiqu_phase_c_revision_baseline`.

## Revision verification — 19 October 2026

- `dart format` on modified Dart files; `flutter analyze --no-pub`: **no issues**; `git diff --check`: **passed**.
- `flutter test --no-pub --dart-define=CAPTURE_PHASE_C_REVISION=true test/phase_c_account_test.dart`: **43 passed** (the prior 35 account cases plus eight composition/resizing/selection cases).
- Final full `flutter test --no-pub`: **129 passed, 9 failed tests**. Remaining failures are the same preserved Home/Topics/Practice/social golden-comparison categories; no non-golden failure remains. No golden baselines replaced.
- `flutter build apk --debug --no-pub`: **passed**, producing `build/app/outputs/flutter-apk/app-debug.apk` with the revised layouts.
- Added normal 360×800 and 390×844 geometry checks in both themes: paired names, native gender selection/48 px targets, avatar beside identity, compact Appearance above progress, segmented target size and footer alignment. Wide 768×1024/1.3× checks cover progress columns. Resizing to 320×568/2× preserves form/controller/choice values; wrapping appearance choices activate and persist. Existing calendar, picker, validation, keyboard-inset, submission/retry, auth guard, switch/logout, cached/unavailable stats, metadata, theme/scroll/lesson retention cases remain passing.
- `docs/ui_ux_phase_c_revision/`: **32 actual rendered PNGs**, inspected using real font/asset fixtures. Includes revised normal phone onboarding/Profile, wide grouping, enlarged controls, sheets, validation/errors and both themes. Initial A/B/C captures remain untouched.
- User-supplied device screenshots and Stitch HTML were reviewed as references. No fresh connected-device/provider/network/autofill/screen-reader session, iOS build or release test was run for this revision. APK compilation and fixtures do not substitute for those checks.
- Manual approval was subsequently received. The preserved [UI_UX_PHASE_C_REVIEW.md](UI_UX_PHASE_C_REVIEW.md) replaces the initial layout instructions with exact revised paths, expected visuals and regression checks. Appearance is no longer under Account; it is directly below identity.

## Current approval gate

Phase E is **APPROVED**. Phase F is complete and **AWAITING MANUAL REVIEW**, not approved. Do not start G without `APPROVE PHASE F`. The active guide is [UI_UX_PHASE_F_REVIEW.md](UI_UX_PHASE_F_REVIEW.md). Missing legal destinations, the current tutor-provider limitation, Ranked Leave/Forfeit policy and remaining root-theme/device/golden/release acceptance retain their explicit boundaries. No Phase G work or release approval is inferred.

## Initial Phase C implementation — historical, revised before approval

The following records the initial C implementation/evidence. Its vertical-control/stacking descriptions are superseded by the current revision above. No approval was inferred from its test/build success.

### Phase C implementation and traceability

| Surface | Changes beyond approved B | Audit coverage within C |
|---|---|---|
| S01 Login | Scroll-safe 440 px reading region, static original owl/wordmark, wrapping value/features, approved palettes/type, real Google mark and bundled provider font, readable adjacent error, retained native busy label/duplicate-signin guard. Legal controls explicitly disabled until supplied URLs. | UX-03/05/06/11/13/16/19; legal destination dependency explicitly deferred by user |
| S02 Complete profile | Vertical labelled name fields, keyboard focus/Next/autofill, clear required-field copy, inline errors after first submit, first-invalid scroll/focus, native gender radio choices, body-sized selector values, same required fields/default/options/payload. Busy edits/submission disabled; retained input on server failure. | UX-01/03/04/05/06/09/11/17/24 |
| O01–O03 | DOB uses active appearance and approved title font; same 1960–today bounds. Belief/country use shared header/Close, native radio selection, bounded scroll and exact original values. Cancel/dismiss preserves selection. | UX-01/04/06/09/11/12 |
| Signup account switch | Explicit top/lower switch action and native system-back confirmation; Keep editing retains draft; confirmed existing logout reaches Login without weakening guards. Form-owned controller disposed on departure. Failure is revealed and retry remains available. | UX-09/14/24; documented back/guard defect |
| S11 Profile / O18 | Identity stacks at narrow/large text; section hierarchy and bounded width; cached refresh error/retry; missing metrics labelled unavailable instead of artificial zeros; real installed version; one Account signout action. Confirmation retains behavior, navigates from live screen context, and recovers after local logout failure. Existing statistics/XP meanings retained. | UX-01/06/10/11/14/18/21 |

Only five production Dart files changed from the B snapshot: login/signup/profile screens and the shared button/field files. Only the Google button variant changes appearance; Login is its sole production consumer. Optional name-field focus/autofill/action/enabled parameters preserve all existing defaults; the two signup name fields are the production consumers. Authentication/signup controller business logic, app router/guards, tokens, APIs/payloads and all learning/score/timer/match operations remain unchanged. No backend/database/VPS/migration work occurred. B-start files and uncommitted user work remain intact; a comparison snapshot is at `/private/tmp/aptiqu_phase_c_baseline`.

One necessary runtime dependency was added: `package_info_plus: 8.3.1` and its platform interface, to replace the false hardcoded profile version with installed build metadata. This version fits existing AGP/Gradle/Kotlin settings; no native toolchain upgrade was made. Pub also corrected five inherited lockfile entries to installed Flutter SDK pins (`characters`, `matcher`, `material_color_utilities`, `meta`, `test_api`) and the resulting Dart SDK bound. No broad package upgrade was requested/run. The previous lock required Dart >=3.10 while the installed SDK is 3.9.2; resolution is now consistent with that environment.

The official Google icon and static Google Sans Medium are bundled for the provider action, including the font license. Source URL/hash/length and branding reference are recorded in `assets/fonts/google_sans/SOURCE.md`. The app's approved Outfit/Plus Jakarta Sans design remains elsewhere. Skill accessibility guidance was used; the installed UI/UX search helper still has its own incompatible Python f-string syntax error. No tool/runtime installation or alternative palette was introduced to work around it.

## Phase C verification — 19 October 2026

- `dart format` on changed source/tests: completed.
- `flutter analyze --no-pub`: **no issues**.
- `git diff --check`: **passed**.
- `flutter test --no-pub --dart-define=CAPTURE_PHASE_C=true test/phase_c_account_test.dart`: **35 passed** after the final responsive identity layout. Real image/manifest access was added to the existing font helper; the Google provider font is loaded once per test isolate for stable rendered evidence.
- Final full `flutter test --no-pub`: **121 passed, 9 failed tests**, including the final responsive Profile header and existing B/XP checks. Failures remain image comparisons against the preserved Home/Topics/Practice/social goldens (ten images across nine tests, same categories as B). No non-golden failure remains. No golden baseline was replaced.
- `flutter build apk --debug --no-pub`: **passed** with the new native metadata plugin. The debug APK is `build/app/outputs/flutter-apk/app-debug.apk`. This is compilation evidence, not device or release acceptance.
- `flutter devices --machine`: **[]**; no available device. No actual OAuth/account picker, authenticated API session, system bars, native autofill, physical keyboard, TalkBack/VoiceOver, iOS build/runtime or release build was exercised. Real date-picker keyboard-entry mode remains a device check; calendar selection/dismissal is widget-tested.
- New tests cover both modes at 390×844/1×, 320×568/2×, 844×390/2×, 768×1024/1.3× for Login and signup/pickers; extra 320×568/2× with 220 px keyboard inset; Profile long identity/large totals at 320×568/2× and 844×390/2×. Checks include all required fields, first-invalid focus, cancel/selected values, busy/exact submitted values, server error/retry/success routing, actual production guard/system-back/account-switch behavior, local failure recovery, Profile refresh retention/retry, absent-vs-zero metrics, installed metadata override, scroll/theme retention, System response and logout-to-Login with preserved appearance. Existing account picker guard/logout tests ran in the full suite.
- `docs/ui_ux_phase_c/` contains **16 rendered PNGs** using real fonts/assets and safe fixture data. Inspected both-theme Login/error, signup, DOB/belief sheets, enlarged errors, cached Profile error and long identity. Fixed typography and full-width stacked identity based on these renders. No authenticated device screenshots are claimed.
- Exact review steps and known limits: [UI_UX_PHASE_C_REVIEW.md](UI_UX_PHASE_C_REVIEW.md). Human manual review is **pending**.

## Phase C outstanding gates

- Wait for `APPROVE PHASE C` or `REVISE PHASE C: ...`. Do not start D automatically.
- Legal destinations remain deferred by explicit user instruction. Controls remain unavailable; no URL-launcher dependency or fictional policies were added.
- Existing golden comparisons still require deliberate visual-baseline review. Approval of A/B was recorded; baselines were not silently rewritten.
- Remaining unmigrated features and global overlays retain dark boundaries. D covers practice/daily; E social/competitive; F routed/global; G completes app-wide themes/accessibility and release review. No coverage from the original audit/plan was dropped.
- Device/provider/network/native-keyboard/accessibility/iOS/release acceptance remains pending as described above.

## Phase B historical record — explicitly approved

The following records approved B. Its approval gate and proposed next phase are superseded by C's checkpoint above; its evidence and original limits remain historical facts.

### Phase B implementation and traceability

| Surface | B changes beyond the approved A pilot | Audit coverage within scope |
|---|---|---|
| Shared controls | Native Filled/Outlined buttons and text fields; retained labels while busy; 48 px minimum targets; keyboard activation/focus/disabled behavior; shared loader and thinking surface with static reduced-motion state; common error/empty/loading views. Delay/minimum display timing remains unchanged. Legacy meaningful input outlines strengthened. | UX-02/04/05/06/10/11/12/13/19, partial global coverage |
| Home shell / S03 | Saved appearance replaces the temporary preview. Avatar accessibility action; safe dark feature-body boundaries. Secondary timing metric, consistent numeric/badge typography, topic recovery views. Existing tab/controllers/state and metric definitions retained. | UX-01/02/06/11/14/21 |
| O04–O06 | Shared live themed sheet surface, persistent close/header, scroll/reading-width bounds. Difficulty, achievement browser, calendar day-list and day-detail use it. Calendar dates have 48 px targets and a labelled list alternative; month/year/data/paging contracts preserved. | UX-01/04/06/09/11/12 |
| S05 / O07 | Native Map/List selector; ordered curriculum alternative defaults on narrow/enlarged text; readable current/state/progress labels; semantic native map targets; bounded zoom, adaptive HUD, shorter/reduced camera motion; persistent topic header with existing sticky actions/live updates. Same topic/subtopic IDs, order and callbacks. | UX-04/05/06/09/11/13/19 |
| S04 | Shared thinking/input/busy presentation and disabled completed/submitting interactions. Voice/scan stubs now truthfully labelled Coming soon and cannot fabricate answers or progress. Existing option immediate-submit/answer/hint/text/continuation logic preserved. | UX-05/06/12/15/16/19, embedded portion |
| S11 | Production System (Default)/Light/Dark selector with immediate local persistence, serialization, safe startup fallback, inline write-error retry. Profile presentation adapted for both themes/responsive metrics, real avatar/initial fallback, native sign-out dialog and mounted async guard. | UX-01/04/06/11/14/18/21, limited account work |

Key implementation files: `appearance_controller.dart`, `appearance_theme.dart`, `appearance_setting.dart`, `app_sheet.dart`, `app_state_view.dart`, shared button/input/loader/thinking widgets, Home/Topics/calendar/lesson presentation, and Profile. No new dependencies. `InitialBinding` registers the preference permanently and `main.dart` loads it before existing auth initialization. Logout still clears only the existing session keys. Local preference is device-wide, not synced to an account or backend.

The user-requested selector is production UI, not a debug flag. It follows OS appearance by default. Explicit overrides survive restart and ignore OS brightness changes. A late storage read cannot overwrite a user choice; rapid writes serialize; read failure falls back to System; write failure keeps the choice for the session and offers retry. The temporary `PilotTheme`/`APTIQU_DESIGN_PREVIEW` mechanism was removed.

Migration boundary: Home chrome, Home, Topics, embedded lessons, Profile and their migrated sheets follow the saved appearance. Other feature bodies/routes/global overlays retain safe legacy dark themes. The Profile note explicitly discloses this. Full-app light acceptance remains G; the selector itself was pulled forward by the user's explicit request. Shared calendar day sheets on learner profiles also follow the selected appearance. This limitation was communicated during implementation.

No backend, database, migration, VPS, API, authored curriculum, answer IDs/order, scoring/reward, matchmaking, timer or lesson-controller business logic changed. Existing A working-tree content was preserved; a B-start comparison copy lives at `/private/tmp/aptiqu_phase_b_baseline`. No commits or golden replacements were made.

## Phase B verification — 19 October 2026

- `dart format` on changed Dart files: completed; unrelated formatting in the inherited XP test was preserved.
- `flutter analyze --no-pub`: **no issues**.
- `git diff --check`: **passed**.
- `flutter test --no-pub --dart-define=CAPTURE_PHASE_B=true test/phase_b_learning_test.dart`: **17 passed**.
- Final `flutter test --no-pub`: **86 passed, 9 failed tests**. Every remaining failure is an image comparison, covering ten golden images: Home consistency/populated/day details, Topics completed, Practice random, Friends search/requests, and learner profile/default/large/empty. No non-golden failure remains. The shared outline/buttons/calendar deliberately change additional Practice/social renders beyond A's existing drift; do not classify all current social differences as pre-existing. Baselines await review, not automatic replacement.
- New preference tests cover default/corrupt/read failure, restart, unrelated storage preservation, rapid choices, late load, write failure/retry. Real-font widget checks cover both themes at 390×844/1×, 320×568/2×, 844×390/2×, 768×1024/1.3×; Profile dialog cancellation, curriculum list/sheet/launch IDs, calendar targets/list/exact day, active Home lesson/selection retention, live System sheet changes, zoom bounds, native keyboard activation, stable busy labels/reduced motion, and no submissions from unavailable tools. Existing A/navigation/loader/topic/XP cases also ran in the full suite.
- `docs/ui_ux_phase_b/`: twelve PNGs captured from actual Flutter rendering with the exact production static font fixtures. Inspected Home/performance, Topics list, Profile appearance, difficulty/date-list sheets and lesson answer feedback across both themes. Fixture data only; existing A images remain untouched.
- No configured Flutter device was available. No authenticated device session, real server/provider flow, physical system bars, device TalkBack/VoiceOver, platform keyboard or release build was executed. Test keyboard/focus evidence does not substitute for device accessibility review.
- Human manual approval: explicitly granted with **`APPROVE PHASE B`**. Individual device-check outcomes were not reported. Original review instructions remain in [UI_UX_PHASE_B_REVIEW.md](UI_UX_PHASE_B_REVIEW.md).

## Historical B handoff and remaining coverage

- Phase B received explicit approval before C began. Golden baselines remain preserved for deliberate review.
- All screens must ultimately migrate to and validate the saved preference. Global findings remain open where later phases own the affected screen; B does not close application-wide UX-01 or claim full routed-player migration.
- B handed off authentication/account work to C. C subsequently implemented it as recorded above; legal destinations are deferred by explicit user instruction. The saved appearance preference and essential both-theme Profile changes originated in B.
- D–G retain original coverage: practice/daily, social/competitive, routed/global, and final app-wide accessibility/theme/release approval. Product dependencies and hardware checks remain outstanding.

## Phase A historical record — approved, superseded controls

The following preserves the initial pilot's implementation/evidence. Its debug-preview/manual-launch instructions and original deferred work are historical; use the Phase B guide above for the current build. The user explicitly approved A before B began.

### Scope and baseline

Initial working tree: only `docs/UI_UX_AUDIT.md` and `docs/UI_UX_REVAMP_PLAN.md` were untracked. No pre-existing application edits were overwritten.

Read the complete audit/plan and inspected the presentation files and relevant fixtures. Flutter 3.35.7 / Dart 3.9.2 were already installed; SDK-cache writes required sandbox escalation. No packages were installed, no dependencies changed, and no database, VPS, migration, backend, API, authored curriculum, scoring or controller changes were made.

The initial selected baseline passed **20 tests**:

```sh
flutter test --no-pub test/home_navigation_test.dart test/home_dashboard_test.dart test/topic_details_sheet_test.dart test/topic_progress_ui_test.dart test/constellation_roadmap_test.dart
```

## Implemented foundation

- `lib/core/theme/aptiqu_theme.dart`: the plan's coordinated light/dark semantic palette, explicit foreground/container pairs, typography, button/input/chip/surface/sheet themes and active system-bar styles.
- `lib/core/theme/aptiqu_tokens.dart`: compact spacing/radius roles and success/warning/disabled ThemeExtension with copyWith/lerp.
- `lib/core/theme/aptiqu_typography.dart`: color-free theme roles; Outfit titles and Plus Jakarta Sans body/controls. Old static styles remain migration aliases for untouched screens.
- `lib/core/theme/aptiqu_legacy_theme.dart`: preserves the previous theme for unmigrated destinations. `main.dart` uses this legacy theme globally; the new themes are bounded to the pilot.
- At A: `lib/core/theme/pilot_theme.dart` supplied the debug-only `APTIQU_DESIGN_PREVIEW` control. This temporary mechanism has since been replaced by B's production preference.

This is the beginning of UX-01/02/03/11/12 coverage, not a claim that those application-wide findings are closed.

## Pilot surfaces and traceability

| Surface | Implemented | Findings addressed within pilot |
|---|---|---|
| Shared Home shell | Theme inheritance for Home/Topics, quiet profile/progression strip, neutral navigation with selected pill, 12 px sentence-case labels, content-sized chrome. At enlarged text, five destinations use two rows when necessary to keep labels readable. Existing destinations/callbacks remain. | UX-01/04/06/11/14 |
| S03 Home dashboard | Paired Continue/Explore action, neutral metrics, consistent gutters/panels/section gaps, removes idle loader slot, shows two achievement previews plus existing View all. Existing values/definitions retained. | UX-02/11/12/21 |
| O04/O05/O06 | Theme-aware difficulty, achievement and date-detail presentation; existing data, paging, dismissal and IST meanings retained. | UX-01/02/11/12, limited coverage |
| S05 Topics | Themed native subject chips, readable status text, quieter node/path treatment, no decorative pulse/stars/glow, 48+ map controls, larger text-aware node spacing, current-topic framing nearer the upper third, reduced-motion camera fallback. Existing canvas and callbacks retained. | UX-01/04/06/11/13/19, partial |
| O07 Topic details | Themed reading and subtopic surfaces, paired primary/secondary actions, minimum 48 px targets, stacked action pairs at large text, same sticky whole-topic footer, same drag/live-update behavior and IDs. | UX-02/04/06/11/12 |
| S04 Embedded lesson | Quiet reading surface and bubbles, 16 px body, full lesson title, 48 px Close lesson action, native Continue, full-width flexible answer rows with selection/correct/incorrect/locked text and icons, native hints and text Submit. Preserves immediate option submission, IDs, ordering and conversation keys. | UX-02/04/05/06/11/12/13/15, partial |

No map/list curriculum alternative, full navigation/routing refactor, routed-player migration, account appearance preference, or other future feature phase was implemented.

The shell also appears on Practice, practice history, Ranked and embedded Friends (S06/S07/S09/S14); these destinations retain legacy theme bodies. The shared ActivityCalendar/date detail is also consumed by S16 Learner profile. Those are regression surfaces, not redesigns or approved light-mode destinations. Global invitations/level-up and other screens remain outside the pilot migration.

## Rendered evidence

`docs/ui_ux_phase_a/` contains fresh Flutter widget-test PNGs using fixture data, not a connected account. Both real production font families and their exact static weight files are used. Font source hashes/lengths and licenses are recorded under `test/fonts/phase_a/`. Existing font fixtures and all golden baselines are unchanged.

Representative evidence:

- `home-light.png`, `home-dark.png`
- `topics-light.png`, `topics-dark.png`
- `topic-sheet-light.png`, `topic-sheet-dark.png` (actual modal route)
- `lesson-light.png`, `lesson-dark.png`
- `answer-light.png`, `answer-dark.png`
- `lesson-small-2x.png`
- `topic-light.png`, `topic-dark.png` (component fixtures)

Reviewed the rendered hierarchy, colors, primary labels, option feedback and enlarged-text navigation. Source inspection alone was not treated as visual verification. These fixtures do not establish production network/font availability, platform keyboard behavior or device accessibility.

## Tests and remaining verification gaps

Final verification completed on 19 October 2026. Commands/results are recorded below. Tests use existing front-end fakes; no local data services were started.

- `dart format` on changed/new Dart files: completed (the pre-existing XP test's formatting was preserved; only its changed caption assertion was updated).
- `flutter analyze --no-pub`: no issues.
- `git diff --check`: passed.
- `flutter test --no-pub`: **70 passed, 8 failed tests**. The failures consist only of golden comparisons: four changed Home/Topics images, plus the five pre-existing social image differences across four tests. No golden baseline was updated.
- `flutter test --no-pub --dart-define=CAPTURE_PHASE_A=true --dart-define=APTIQU_DESIGN_PREVIEW=true test/phase_a_pilot_test.dart`: **14 passed**.
- Affected interaction run including pilot, Home navigation, topic sheet and XP tests: **31 passed**.
- Dual-theme cases: 390×844 at 1×, 320×568 at 2×, 430×932 at 1.3×, 844×390 at 2×, 768×1024 at 1×. Covers Home, difficulty sheet opening, long topic content, map-to-sheet opening, answer callbacks/IDs/hints/feedback/locking. Additional checks cover text submission, active conversation/selected answer retention across preview changes, system brightness response and small-screen shell layout.
- Contrast checks: primary/onPrimary, selected container, primary/secondary surface text, success, warning, error, info and control outlines pass the test thresholds (4.5:1 text, 3:1 meaningful edges). This is not a certification of all composited or untouched app states.
- `flutter devices --machine`: returned no available devices. No emulator/device app session, authenticated server flow, physical system bars, TalkBack/VoiceOver, focus traversal or platform keyboard verification was executed.

Expected review gates: new Home and Topics appearance differs from four preserved golden images. Separately, five social golden image comparisons already differ on the original code. An isolated original-source copy at `/private/tmp/aptiqu_phase_a_original` reproduced the same social image deltas (friends search 0.71%; requests 2.02%; learner profile 3.31%; large profile 7.34%; empty profile 3.71%). Its command was `flutter test --no-pub test/social_test.dart`: 6 passed, 4 failed tests covering five images. These failures predate Phase A and were not silently baselined away. Generated comparison files remain in `test/failures/` for review.

## MANUAL UI VERIFICATION — PHASE A

### Start and switch appearance

1. Connect an existing configured device or start your usual simulator. This environment currently has no Flutter device available.
2. From the repository root, run:

   ```sh
   flutter run --debug --dart-define=APTIQU_DESIGN_PREVIEW=true
   ```

3. Sign in with an existing completed account and use the existing configured API/data. No database setup is required or authorized by this phase.
4. On Home or Topics, use the **Design preview** dropdown at the top: choose **light**, **dark**, or **system**. Inspect each surface in light and dark. For system, change the device appearance while Home is open.
5. Close a sheet before switching the dropdown, then reopen it. Modal routes capture their launching theme; live restyling of an already-open sheet is not part of this preview contract.

The control exists only in a debug build with the define. It disappears outside Home/Topics; other destinations remain in their legacy dark appearance. Restart resets the preview choice. A release build ignores the flag. The production System/Light/Dark account setting remains deferred.

### Shared Home shell (also regression-check the other three tabs)

**How to reach**
1. Finish sign-in and open Home.
2. Tap Topics, Practice, Ranked and Friends; return to Home.
3. Tap the learner avatar/name to open Profile, then return. Tap the streak action to open Daily Streak Arena, then return.

**What changed**: quieter progression/identity strip, readable labels, one selected navigation pill, themed chrome. Very large text on narrow phones uses two navigation rows.

**Visually check**: all five destinations are readable/tappable, the selected destination is clear, profile/streak/coins align, and enlarged text has no clipped labels. Light preview applies to Home/Topics only.

**Functional checks**: all five tabs retain their destinations, Topics retap still refocuses, profile/streak open their existing routes, and returning Home preserves the lesson conversation.

**Expected result**: navigation changes presentation without losing account, lesson or tab state. Practice/Ranked/Friends bodies keep their previous theme.

### S03 — Home dashboard

**How to reach**
1. Tap Home.
2. Inspect Daily Challenge and Continue learning. Without a resumable lesson, the action is Explore topics.
3. Scroll through Your performance, Achievements, Ranked and Your consistency.

**What changed**: readable violet primary pair, calmer metrics/cards, consistent spacing, no idle loading gap, two achievement previews plus View all.

**Visually check**: light has white panels on a warm page; dark has softened dark panels and pale-violet actions with dark labels. Long lesson titles wrap, values remain legible and only the learning action has strong primary emphasis.

**Functional checks**: use Continue learning/Explore topics, Daily Challenge, Open Ranked, Try practice when present, pull-to-refresh and View all achievements. Return after each destination.

**Expected result**: the same destinations/data are shown, with clear hierarchy and no blank loader slot after refresh finishes.

### O04 — Difficulty details

**How to reach**
1. Home → Your performance.
2. With recorded submissions, tap View difficulty details.
3. Scroll to the final explanatory note; dismiss with system Back or the modal scrim/swipe.

**What changed**: themed surface/text and consistent hierarchy.

**Visually check**: title, counts, accuracy, time definitions and final note remain readable in both appearances, at large text and in landscape.

**Functional checks**: data matches Home's existing definitions, the sheet scrolls, dismissal returns to the same Home position.

**Expected result**: complete, readable difficulty information without altered metric meanings. A new account with no submissions has Try practice instead, so this sheet requires existing activity.

### O05 — Achievement browser

**How to reach**
1. Home → Achievements → View all achievements (requires available achievement definitions).
2. Scroll the list; use Load more if supplied; close with the Close icon.

**What changed**: themed error text and inherited controls, with badge rows matching Home's pilot styling.

**Visually check**: earned/locked labels and progress remain readable, long descriptions wrap, Close and Retry are visible.

**Functional checks**: pull to refresh, Load more and Retry when applicable; verify items are retained and not duplicated.

**Expected result**: the existing server-authored catalog and pagination work in a surface consistent with Home.

### O06 — Activity calendar/date detail

**How to reach**
1. Home → scroll to Your consistency.
2. Scroll months, then tap a date.
3. Read the date, submissions/correct counts, Daily Challenge completion if present, and IST label; dismiss.

**What changed**: theme-aware calendar, paired date colors, readable detail typography and theme-aware sheet surface. Activity intensity still distinguishes submission ranges.

**Visually check**: date numbers, today outline and challenge marker remain visible; counts/timezone wrap in both modes.

**Functional checks**: month scrolling/refresh preserves position, date detail matches the chosen date, dismissal returns correctly.

**Expected result**: the same date/activity facts are legible. The accessible day-list/calendar-target redesign remains future work; tiny date targets at narrow widths are not claimed fixed.

### S05 — Topics and O07 — Topic details sheet

**How to reach**
1. Tap Topics (or Home → Explore topics).
2. Choose a subject in the horizontal selector.
3. Tap a topic circle/title to open its details.
4. Scroll its subtopics. Inspect Practice, Start/Continue/Replay, Soon, and the separate Whole topic footer where present.
5. Close; try Fullscreen Map/Exit Fullscreen, Focus Active Level, Zoom In and Zoom Out.

**What changed**: selected subject foreground/checkmark, quieter map/path, larger status labels, themed scrolling sheet, 48 px actions, stacked pairs at large text.

**Visually check**: selected subject is readable; current/completed/coming-soon states are clear; sheet titles/descriptions wrap; whole-topic controls remain separate from each subtopic; light/dark actions use the correct foreground; enlarged text keeps actions reachable.

**Functional checks**: changing subject retains the current curriculum behavior. Close/drag/dismiss works. Starting a subtopic opens that subtopic, Whole topic targets the topic, Replay retains replay behavior, Practice opens existing practice, and Soon remains unavailable. Use only existing available data; no curriculum was seeded.

**Expected result**: the same ordered curriculum and launch IDs are preserved, with a coherent sheet and clear action hierarchy. The map remains a pan/zoom canvas; the future Map/List alternative has not been implemented.

### S04 — Embedded lesson and question/text states

**How to reach**
1. Home → Continue learning, or Topics → topic details → an available Start/Continue/Replay action.
2. Read tutor messages and tap Continue where that lesson supplies it.
3. At a choice/question, tap an answer. Embedded options submit immediately; there is no extra MCQ Submit step.
4. Reveal Hint when supplied. At a text-answer node, enter text and use Submit or the keyboard send action.
5. Use Close lesson to return Home; reopen via Continue learning.

**What changed**: quiet background/bubbles, 16 px reading type, wrapping title, accessible Close lesson, consistent Continue, flexible answer rows, visible selection/result/locked labels and icons, and themed text input.

**Visually check**: paragraphs/math remain intact, long options wrap, correct and incorrect results are readable independently of color, hints are readable, and scrolling keeps each action reachable. Check 320 px width, landscape and enlarged text.

**Functional checks**: IDs/order/answers are unchanged; repeated taps do not resubmit a completed answer; hints retain their sequence; text submits its actual value; continuation still advances the same lesson; Close/Home returns retain the conversation. Inspect correct/incorrect states on fresh questions when the lesson supplies evaluation.

**Expected result**: the same teaching and answer behavior remains, with a consistent reading/interaction style. Question availability depends on the existing script; rendered test fixtures safely demonstrate states if local account data cannot reach them. Voice/scan legacy behavior and the separate routed lesson player were not completed or validated by this pilot; no real voice/scan integration is claimed.

### S16 — Learner profile activity (shared-component regression only)

**How to reach**
1. Home shell → Friends.
2. Tap an existing learner to open their profile.
3. Scroll to learning activity, visit a month and tap a date.

**What changed**: the shared calendar/date detail now reads theme roles. This profile itself is not redesigned and remains legacy dark.

**Visually check**: activity dates/markers/detail labels remain readable and consistent with that legacy screen.

**Functional checks**: friend identity/actions are unchanged; month loading and date detail retain their existing facts; Back returns to Friends.

**Expected result**: no regression from sharing the calendar. An existing visible learner is required. Light preview is intentionally unavailable here until its migration phase.

## Historical A handoff

A was handed off for review and then explicitly approved in the conversation. Its calendar/list/shared-component follow-ups and requested appearance selector were implemented in B as recorded above. Remaining product dependencies and later-phase coverage remain scheduled; approval of A did not authorize C–G.
