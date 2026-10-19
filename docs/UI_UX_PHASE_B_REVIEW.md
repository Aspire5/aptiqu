# Phase B — manual review

Status: **AWAITING MANUAL APPROVAL**. Phase A was explicitly approved by the user. Phase C has not started.

## Run and switch appearance

1. Use the usual configured simulator/device and existing API. Run `flutter run --debug` from the repository root. No preview define is required.
2. Sign in with an existing account that has completed registration. No database or migration work is required or authorized.
3. Home → tap your avatar/name → Profile → scroll to Account → Appearance.
4. Choose **System (Default)**, **Light**, or **Dark**. The choice applies immediately and is saved on this device, independently of the signed-in account.
5. Return Home. Restart the app and verify the choice remains selected. Choose System and change device appearance; then choose an explicit Light/Dark mode and verify OS changes do not override it.

Home chrome, Home, Topics, embedded lessons and Profile follow the choice. Other feature bodies and global overlays retain their legacy dark appearance until their authorized phases. The setting states “Some screens currently use dark mode.” This is a staged migration, not full-app light-mode acceptance. The former debug-only dropdown has been removed.

Repeat the following in **Light and Dark**, on a narrow phone, landscape, and enlarged system text. The account's actual curriculum, achievements, history and lesson nodes determine which states are reachable. The rendered fixtures in `ui_ux_phase_b/` demonstrate representative states without modifying account data.

## S11 — Profile and appearance

**Reach**

1. From Home, tap the avatar/name.
2. Scroll through identity, level/XP, unique topics, difficulty statistics, and Account.
3. Select each Appearance option. Use Back to return Home.
4. Reopen Profile, tap the top **Sign Out** icon or **Sign Out of AptiQu**, then **Cancel**.

**Changed**: native radio controls, local persistence and save-error recovery; theme-aware surfaces and navigation; responsive identity and metric groups; own image or initial fallback; themed sign-out confirmation. Existing authentication, statistics definitions, refresh and logout actions remain.

**Visual check**: all radio labels remain readable, selected state is obvious, long identity text wraps, metric groups fit at large text, and dialog actions remain reachable.

**Functional check / expected**: theme changes immediately, survives restart, and does not lose the active lesson. Cancel keeps the account signed in. If storage is unavailable the inline error truthfully says the choice is session-only and offers **Retry saving**; do not deliberately break device storage to trigger this. Storage errors/races are covered by tests. Actual logout can be checked at the end of the session if desired. The inherited hardcoded version and refresh-error behavior remain Phase C work.

## Shared Home shell

**Reach**

1. Return Home after selecting an appearance.
2. Open **Topics**, **Practice**, **Ranked**, and **Friends**, then return **Home**.
3. During an embedded lesson, visit Profile and change appearance, then return.

**Changed**: persisted appearance now drives the existing approved shell; avatar semantics expose the same Profile action. Legacy bodies for Practice/Ranked/Friends are explicitly bounded to dark.

**Visual check**: profile strip and five tab labels remain readable; selected tab is clear; large text can grow chrome without clipping. A light shell around a legacy dark feature is currently expected.

**Functional check / expected**: tabs retain their existing destinations and state. Changing appearance preserves the controller, conversation, selected answer and progress. Back returns from Profile to the same experience.

## S03 / O04 / O05 — Home and detail sheets

**Reach**

1. Home → inspect Daily Challenge, Continue learning (or Explore topics for a first learner), Your performance, Achievements, Ranked, and consistency.
2. Under Your performance, tap **View difficulty details** → inspect **By difficulty** → **Close**.
3. Under Achievements, tap **View all achievements** → inspect the browser → **Close**.

**Changed**: quieter secondary timing metric, consistent tabular numerals and badge type; common loading/empty/error surfaces; shared bounded sheets with persistent close actions and scrollable content. Achievement pagination and metric definitions remain.

**Visual check**: primary action stands out; average time is secondary; counts and labels wrap cleanly; modal titles and close buttons remain visible in landscape/large text. Check earned/locked and empty achievement states when available.

**Functional check / expected**: Continue resumes the same lesson; Explore opens Topics; existing Daily and Ranked actions retain their destinations. Difficulty totals match Home. Achievement **Load more**, pull-to-refresh and **Retry**, when available, use the same server pages without duplicates. Cached/error/loading states should not hide the profile strip.

## O06 — Consistency calendar, date list and day details

**Reach**

1. Home → scroll to the consistency calendar.
2. Scroll vertically through months. On a narrow display, swipe the calendar horizontally to reveal the remaining weekdays.
3. Tap **View dates as list** for a month.
4. Tap a date in the list → inspect the exact day details → **Close**. Also tap a day directly in the grid.

**Changed**: calendar date targets are at least 48 logical pixels. A native labelled day list offers the same dates and facts. Date sheets share the close/header/reading-width treatment. The list closes before the selected day opens.

**Visual check**: seven weekdays remain aligned; Today and successful Daily Challenge markers are distinct; list rows wrap; dates and counts are readable; content fits in the sheet without horizontal text overflow.

**Functional check / expected**: both entry paths show the same date, submissions, correct count and **Asia/Kolkata · IST** definition. Month position survives refresh/resize; year boundaries remain reachable. Day-list selection does not alter progress.

## S05 / O07 — Topics Map/List and topic details

**Reach**

1. Home → **Topics** (or **Explore topics**).
2. Select an existing subject, then **List**. Tap an available topic.
3. In topic details, scroll through subtopics. Inspect the fixed whole-topic action, subtopic actions and **Practice** where offered. Use **Close topic details**.
4. Switch to **Map**. Use **Focus Active Level**, **Zoom In**, **Zoom Out**, and **Fullscreen Map** / **Exit Fullscreen**. Tap a map node to open the same sheet.

**Changed**: ordered accessible curriculum list, visible state/progress/current-topic descriptions, native keyboard/focus interaction, semantically labelled map nodes, bounded zoom controls, shorter/reduced-motion camera behavior, adaptive HUD and a persistent topic-sheet header. List defaults on displays narrower than 360 px or sufficiently enlarged text; users can still choose Map.

**Visual check**: long names and status text wrap; current topic is identifiable beyond color; locked/coming-soon states remain distinct; HUD does not obscure content; sheet close/whole-topic actions stay reachable at large text.

**Functional check / expected**: list and map preserve subject order, topic/subtopic IDs, completion and launch actions. Start/Continue/Replay launches the selected existing step; Practice uses the same topic. Reopen after progress refresh to check live completion. If data changes while open, the sheet updates or truthfully reports unavailability. Repeated zoom clicks remain within the gesture limits.

## S04 — Embedded lesson, shared thinking, inputs and answers

**Reach**

1. Home → **Continue learning**, or Topics → topic/subtopic → its available Start/Continue/Replay action.
2. Read tutor messages and use **Continue** where the script supplies it.
3. Tap an option, inspect feedback, and use **Hint** where offered.
4. At an actual text-input node, enter text and use **Submit** or keyboard send.
5. Use **Close lesson**, then reopen via Continue learning.

**Changed**: shared themed thinking indicator; native busy/disabled Submit controls; consistent readable field treatment. Existing approved answer-state visuals remain. Unimplemented voice/scan inputs now say **Voice answers · Coming soon** / **Scan notes · Coming soon**, with a disabled action and honest explanation instead of fabricating a submission. Use Close lesson if an existing script requires an unavailable mode; no alternate completion is invented.

**Visual check**: thinking text/arc remains readable; loading retains the action label; prompts, hints, mathematics and long answers fit; correct/incorrect/locked states have text and icons as well as color. With Reduce Motion enabled, busy indicators are static.

**Functional check / expected**: choice taps still submit immediately, once; completed/busy options cannot be resubmitted. Text sends its real value once. Hints and continuation retain order. Appearance changes preserve the conversation/selection. Unavailable tools neither submit an answer nor mark a node complete. Real voice/scan integrations are not supplied by this phase.

## Shared-component regression surfaces — not feature redesigns

These retain legacy dark bodies. They need review because common controls, meaningful input outlines, loaders, calendar or thinking visuals changed. No new server operations or flows were added.

| Screen/component | Exact navigation and prerequisites | Change / visual check | Functional check / expected result |
|---|---|---|---|
| S01 Login | With an already signed-out session, open the app → Login → **Continue with Google**. | Native provider button, stable label/loading/disabled state and focus outline. Existing placeholder G mark remains for C. | Existing sign-in starts once; failures preserve existing recovery. Completing sign-in requires the configured provider. |
| S02 Complete profile | Existing incomplete-registration account → Complete profile. Do not reset an existing account to reach it. | FIRST NAME / SECOND NAME fields use persistent native labels and readable outlines; **Initialize Aptiqu Journey** uses the shared button. | Existing values, required rules and selections remain; keyboard focus/validation and submit loading work. Full form redesign remains C. |
| S06/S07 Practice setup/history | Home → **Practice** → **Random** / **Custom** → **History & replays**; use **Back to practice**. | Native meaningful control borders and shared loading arc. | Subject/topic selection, history paging and replay actions retain behavior; no persistent idle busy arc. |
| S08 Practice player | Practice → existing start action, or a playable history entry. | Shared submitting/loading visuals only. | Answer, hint/solution, timer and replay behavior remain. Do not infer scoring changes from UI changes. |
| S09/S10 Ranked lobby/arena | Home → **Ranked**; enter an existing supported match only when desired. | Shared loading visuals and native legacy control outlines only. | Queue/cancel/history remain available; actual arena verification requires an opponent/match. |
| S12/S13 Daily hub/quiz | Home → **Daily Challenge**, then existing eligible start/resume. | Shared loading arc only. | Existing eligibility, timer, answer and completion rules remain; avoid consuming an attempt solely for visual review. |
| S14/S15 Friends/requests | Home → **Friends** → search; inbox icon → requests. Existing learners/requests required. | Native friendship action buttons, focus/busy states and loading arc. | Search/back/pagination retain behavior. Accept/reject only a request you intend to change; repeat taps cannot duplicate busy operations. |
| S16 Learner profile | Friends → tap an existing learner → scroll to activity → **View dates as list** → date. | Same accessible calendar and day sheets; action buttons/loading use shared components. | Learner identity/facts/month loading remain correct; date-list and grid agree. Back returns to Friends. |
| S17 Friendly duel | Friends → existing active duel entry, or a supported accepted invitation. | Shared loading indicator only. | Existing room/resume state remains. Do not create or accept invitations solely to reach a screenshot. |
| S18 Routed lesson / doubt sheet | Use an existing routed lesson entry, or the existing `/lesson/:slug` / `/lesson-step/:stepId` route with an actual published identifier; app's configured deep-link support is required. Tap **Ask Doubt** where available. | Shared tutor-thinking bubble/loading arc only. | Existing question flow and doubt operations remain. Its Scan Work / Voice Input stubs are deferred to F; the embedded unavailable-tool repair does not claim to migrate this route. |

For shared native actions, inspect keyboard Tab focus and Enter/Space activation when supported, clear disabled states, stable labels during loading, and readable text at enlarged scale. Server loading may be too brief to observe; test fixtures cover delayed visibility and reduced motion.

## Evidence and remaining gaps

`ui_ux_phase_b/` contains actual Flutter widget-test PNGs using real bundled font fixtures: Home/performance, Topics list, Profile appearance, difficulty sheet, date-list sheet, and embedded lesson feedback in both themes. Home captures are scrolled to performance; calendar captures use two representative fixture dates. They are not screenshots from an authenticated device.

Analysis, regression counts and preservation details are recorded in `UI_UX_REVAMP_PROGRESS.md`. Golden baselines have not been accepted or replaced. Hardware system bars, device TalkBack/VoiceOver, real platform keyboard, live network/authentication and a release build still require their appropriate environment. No available device was configured in this session. Human review results are pending.

**Phase B is complete and awaiting your manual review.**

**Please inspect the listed screens in both light and dark mode and test the specified interactions.**

**Reply with `APPROVE PHASE B` to authorize the next phase, or `REVISE PHASE B: ...` to request changes.**

**I will not proceed until you explicitly approve.**
