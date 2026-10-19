# Phase C — layout revision for manual review

**Historical Phase C revision review record. Approved on 19 October 2026 with “APPROVE PHASE C, proceed with next.” Current D status is recorded in UI_UX_REVAMP_PROGRESS.md.**

The user requested `REVISE PHASE C` after reviewing the initial implementation. Their composition preferences are now saved in `UI_UX_DESIGN_PREFERENCES.md` and linked from root `AGENTS.md` for future authorized phases. The initial C handoff was not approved.

## What is preserved

The approved palettes, font families/sizes, design tokens and semantic colors remain unchanged. No theme, controller, route, validation requirement, API, data definition, timer/scoring, learning content, database or infrastructure change is included in this revision.

Stitch and the old onboarding screenshot informed grouping and interaction. Their colors, fonts, dimensions, decorative effects, placeholder rewards and account data were not copied. Login's sole change is removal of the requested unavailable-links sentence; both legal controls remain disabled until real destinations are supplied.

## Start and review both themes

1. Use your configured device/API and rebuild with `flutter run --debug`. No preview flag is required. A debug APK is also available at `build/app/outputs/flutter-apk/app-debug.apk`.
2. With an existing completed account, Home → avatar/name → Profile. Appearance is now immediately below identity, before progress.
3. Select Light, Dark and System. Repeat the screen checks in Light and Dark. For System, change OS appearance while a migrated screen is open.
4. To inspect Login, use Profile's bottom Sign out action and confirm. The preference persists across logout.
5. To inspect Complete profile, sign in with an existing incomplete-registration account. Completed accounts correctly go Home; manually opening `/signup` does not bypass the existing guard. No account reset/database setup is required or authorized.
6. Also check a normal 360–390 px phone, narrow width, landscape and enlarged system text. Keep the keyboard open during form checks.

Saved mode still covers the migrated entry/Home/Topics/embedded-lesson/Profile surfaces. Other feature bodies/global overlays retain their scheduled dark boundaries; the existing short disclosure remains beneath the selector.

## S02 — Complete profile composition

**Reach**

1. Login → Continue with Google → choose an existing incomplete-registration account.
2. Inspect First name / Last name, Date of birth, Gender, Religion / belief and Country.
3. Select a gender pill. Open the remaining pickers, then scroll to Complete profile.
4. Submit with missing values, fix the inline errors and move between name fields using keyboard Next.

**Changed**

- Related name fields share a row when the labels/input space fit at actual text scale. They become a column only when needed.
- Step and required-field status share a concise header; the two introductory paragraphs are removed.
- Four gender choices use native wrapping selection chips with a checkmark/selected state.
- DOB, belief and country controls have purposeful leading icons. Existing calendar and selection-sheet interactions remain.
- Belief/country share a row on wider layouts when readable; phone layouts retain comfortable full-width selectors.
- Related gaps are tighter using existing spacing values; touch targets and the original 16 px option/input roles are retained.

**Visual checks**

- On a normal phone, names align side by side and gender occupies compact wrapping rows.
- The form requires substantially less vertical scrolling; the final action is easy to find.
- Long names can still be edited; labels/errors do not collide.
- At enlarged text, fields/whole chips wrap without shrinking the approved fonts or losing choices.
- Keyboard focus, disabled state and error contrast remain clear in both themes.

**Functional checks / expected result**

All six required fields, exact option values and India default remain. A selected pill stores the same gender string as before; resizing does not clear it. Missing values produce inline errors and first-invalid focus without submitting. Server failure retains the draft and allows retry; a successful intended registration goes Home. Avoid completing an account solely to obtain a screenshot.

## O01–O03 — DOB, belief and country

**Reach**

1. Complete profile → Date of birth → open the calendar. Cancel, reopen, select a date and use OK.
2. Open Religion / belief; inspect the selected state and scroll to Prefer not to say.
3. Open Country; close without selecting, then reopen and choose an intended value.

**Changed**: entry controls now read as date/belief/country tasks through icons and grouping. Calendar and shared selection-sheet internals retain the existing Phase C implementation.

**Visual checks**: calendar/selection contrast in both themes; long row labels; reachable Close/Cancel/OK at enlarged text and landscape; selected values readable in paired wide-layout fields.

**Functional checks / expected result**: Cancel/back/Close retains the old value; selection updates only that field. DOB bounds remain 1960 through today. Stored strings, error repair and subsequent selections remain unchanged. Actual date-picker keyboard-entry mode still needs device verification.

## S11 — Profile identity and prominent appearance

**Reach**

1. Home → avatar/name → Profile.
2. Inspect avatar, name, email and level badge.
3. Immediately below, use System / Light / Dark.
4. Leave Profile, reopen it, restart the app and check the saved mode.

**Changed**

- Avatar stays beside identity when the actual name/email/level fit, including normal narrow phones. Exceptional long/enlarged content uses a full-width fallback.
- Level remains a compact native badge/action and preserves the existing celebration callback when available.
- Appearance is a prominent compact segmented control, outside the large Account card. Its selected-mode badge shows System (Default), Light or Dark.
- Icons appear when space permits. Enlarged text uses wrapping native choices instead of truncation or a long explanatory radio list.
- Repeated mode descriptions are removed; persistence/error retry and the existing migration disclosure remain.

**Visual checks**

- At normal phone scale, avatar/name/email/level compose one compact identity group.
- Appearance is visible high on the page, with an unmistakable selected state.
- In both themes, selected foreground/background pairs remain readable.
- At 2× text, full labels/identity and 48 px controls remain reachable; no forced shrinking or ellipsis hides data.

**Functional checks / expected result**

Selection applies immediately and persists across restart/logout. System follows OS appearance; explicit modes override it. Profile scroll, active lesson, authentication and progression state remain intact. Retry saving remains available after a simulated storage failure; do not damage real storage to force this state.

## S11 — Progress grouping, questions and account footer

**Reach**

1. On Profile, scroll below Appearance to progress and Questions solved.
2. Inspect the lower App version / Sign out footer.
3. Tap Sign out → Cancel. Confirm only when ready to leave the account.
4. Pull to refresh; after a genuine network failure, inspect retained details and Retry refresh.

**Changed**

- XP and unique-topic progress share one coherent surface, with aligned metrics/targets and rounded existing-token progress tracks.
- Wider readable layouts place the progress blocks beside each other. Phone layouts group them vertically inside the same surface.
- Difficulty rows are lighter and align counts with their labels; wide layouts show three comparable columns.
- Version and the single confirmed signout action form a quiet footer instead of another large form/card.

**Visual checks**: unchanged count meanings; aligned targets/percentages; balanced row/column layouts; readable zero/unavailable/cached-error states; footer actions fit normal and enlarged text.

**Functional checks / expected result**: the same XP, remaining-XP, unique-topic and difficulty calculations are displayed. Genuine zeros stay zeros; missing statistics remain unavailable. Version comes from the installed package. Cancel stays signed in; confirmed logout reaches Login and preserves appearance. Cached refresh and local logout failures retain the existing visible recovery behavior.

## S01 — Login sentence removal only

**Reach**

1. Profile footer → Sign out → confirm, or launch an already signed-out session.
2. Inspect Terms of Service and Privacy Policy.
3. Try Continue with Google, cancel once, then retry when appropriate.

**Changed**: only “These links are not available yet.” was removed. Owl/wordmark, copy, feature labels, fonts, colors, Google button, error handling and link availability remain unchanged. Content naturally recenters after removal.

**Visual checks**: the sentence is absent in both modes; legal labels remain readable.

**Functional checks / expected result**: missing legal destinations remain disabled; no misleading links or fabricated URLs were added. Existing sign-in cancellation, duplicate guard and completed/incomplete-account routing remain.

## Account-switch confirmation and shared consumers

On Complete profile, Switch account / Use a different account / Android system Back retain the same confirmation. Keep editing preserves every field; confirming signs out and clears the form-owned draft. Error recovery stays retryable. Test cancellation after editing the newly paired fields and choosing a gender pill.

This revision's shared appearance widget is consumed only by Profile. The text-fit helper has real consumers in Profile, Appearance and signup; it selects composition using existing text styles and actual system scale. Unrelated shared widgets and other screen designs are untouched.

## Why these arrangements differ from the references

- Existing approved palettes/type replace the reference's custom indigo/teal styling.
- Related XP/topic progress is grouped into one surface; difficulty metrics and account metadata use lighter structures to reduce repeated cardification.
- Belief/country retain suitable list pickers for their eight/ten options; a compact four-choice chip group suits gender.
- Signout remains one confirmed footer action. The reference's header shortcut is not duplicated.
- Long/enlarged content can change the composition. Compactness does not override accessibility or hide account information.

## Evidence and approval

`ui_ux_phase_c_revision/` contains 32 actual widget-test renders using real fonts/assets and fixture data, including normal 360/390 px composition, wide progress, enlarged controls, validation, sheets and errors in both modes. Initial A/B/C images are preserved separately. These are not authenticated device screenshots.

Final test/build results and scope checks are recorded in `UI_UX_REVAMP_PROGRESS.md`. Golden baselines remain unchanged. Native provider/network/accessibility, date-picker text entry, iOS and release validation still need their appropriate environment.

**Phase C is complete and awaiting your manual review.**

**Please inspect the listed screens in both light and dark mode and test the specified interactions.**

**Reply with `APPROVE PHASE C` to authorize the next phase, or `REVISE PHASE C: ...` to request changes.**

**I will not proceed until you explicitly approve.**
