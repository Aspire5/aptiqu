# MANUAL UI VERIFICATION — PHASE F

**Phase F approved with `APPROVE PHASE F`.** This historical guide records the F implementation. Phase G final QA is authorized; see the separate Phase G review for the current release gate. The approved palettes, typography, font sizes and composition preferences carry forward.

This phase covers the routed lesson player (S18), tutor/tools (O15–O17), global invitation coordination (O20) and level-up presentation (O21). It also wires existing background-work flags into presentation safety and adds Daily's compact invitation entry. No server operations, learning/scoring rules or authored scripts were added.

## Start and inspect both appearances

1. Run the existing app normally with your usual API configuration. Sign in and complete registration with an existing account.
2. Home → avatar/name → Profile → Appearance → **Light**. Repeat the checks in **Dark**. For a live change while a lesson/dialog is open, choose **System (Default)** first and change the device's OS appearance. The active lesson, draft and selection must remain intact.
3. Check normal text, enlarged system text and landscape. The supplied renders include 320×568 and 568×320 at 2× text; keyboard fixtures reserve a 100 px inset.
4. Use intended real learner actions. Existing sessions, published lessons, an eligible friend and another eligible Ranked player are prerequisites where stated. Do not create artificial progress/rewards, seed a database or alter infrastructure to reach a state.
5. [Rendered evidence](ui_ux_phase_f/README.md) is a safe alternative for states absent from your account. These are actual Flutter renders with production font fixtures and safe test data, not authenticated device screenshots.

## Reaching LessonFeedScreen — important route prerequisite

Home/Topics continue to open the **embedded** lesson player. They do not launch S18. The routed player is exposed through the existing route aliases and its own next-lesson action. No new debug launcher or production navigation entry was added.

1. Obtain a **published script slug** or an **existing roadmap step ID** already returned for your account by the app's normal lesson/roadmap requests. A local script filename is not proof that it is published. Flutter DevTools' existing network inspection can show the returned identifiers; no database or VPS access is needed.
2. After signing in normally, stop the development run and launch with a real value replacing the placeholder:

   ```sh
   flutter run --debug --no-pub -d DEVICE_ID --route='/lesson/PUBLISHED_SCRIPT_SLUG'
   ```

3. Separately test the other existing alias:

   ```sh
   flutter run --debug --no-pub -d DEVICE_ID --route='/lesson-step/EXISTING_STEP_ID'
   ```

4. The existing `/lesson/PUBLISHED_SCRIPT_SLUG?stepId=EXISTING_STEP_ID` form retains its step-based start behavior. GoRouter's installed implementation accepts a non-root platform initial route, so `--route` is a development entry path without a code change. Existing auth/registration guards still apply. If redirected to sign-in, sign in first, then rerun the intended route.
5. The Android manifest has no public app-link handler for these paths. Installing the APK alone does not add a Home button for this player. If development route launch or published identifiers are unavailable, use the route tests and previews rather than assuming an unconfigured external URL works.

Debug APK: `build/app/outputs/flutter-apk/app-debug.apk`. Use `flutter devices` for the current device ID and keep your normal API configuration.

## LessonFeedScreen / ChatBubbleWidget — reading, status and navigation (S18)

### Reach

1. Open a valid routed lesson using either development entry above.
2. Read the title and conversation; scroll up to earlier messages and down to the active input.
3. Use Back after an intended check. A route opened without a preceding page returns to Home.
4. Where connectivity genuinely fails, inspect the error and Retry. Separately test an intended response that fails, then retry that action.

### Changed / visual checks

The supplied lesson title replaces an opaque slug/ID heading; absent title data falls back to **Lesson**. Tutor/user bubbles use the approved reading styles and semantic foreground/container pairs. Conversation and active controls share one scroll area, so a long question no longer occupies a permanently oversized footer. **Ask tutor** stays visible in the toolbar; narrow/enlarged layouts adapt the chrome without shrinking fonts. The lesson tools button is labelled **Lesson tools · Coming soon**.

Check full titles, equations and long messages; reachable final controls with the keyboard open; readable loading and inline errors; native focus/press feedback. Unsupported node types show an explanation and retain Back/Ask tutor rather than an invisible gap. Initial failure replaces loading. Submission failure retains the feed, selected answer or typed draft and offers the same action again.

### Functional checks / expected results

Both route aliases preserve their IDs and existing start endpoints. Route-owned controllers do not overwrite a previous lesson when the next one is pushed. Return/back disposes only that route's controller; late responses cannot overwrite a newer lesson. Appearance changes retain the current node and draft. Retry does not clear the existing conversation or silently submit a different answer.

## ContentNodeWidget / ChoiceInputWidget / QuestionNodeWidget / TextInputWidget (S18)

### Reach

1. Use published lessons containing the relevant node types. No single live lesson is guaranteed to contain all types; fixtures cover the full set.
2. On content, use **Continue** or an existing content choice. A content option explicitly requesting tutor help opens the help sheet as before.
3. On a choice, select the intended label. On a question, tap one intended answer.
4. At a text-input step, type a response and use **Send answer** or the keyboard Send action.

### Changed / visual checks

Short paired choices share a row only when their measured labels fit; longer choices keep whole labels in stacked native controls. Content progression has a primary action. Questions use shared provenance/difficulty and native answer controls, with a selected mark and immediate-submit disclosure. Display letters are presentation labels; the original answer IDs are submitted. Text input has a persistent **Your answer** label and a labelled 48 px send control. Voice remains available as truthful information in Lesson tools rather than a misleading composer action.

### Functional checks / expected results

Content/choice IDs and order are unchanged. Question taps submit immediately, once, with the existing option ID and measured response time. Pending submission disables repeats. A failed question submission retains its selection and permits retry. Blank/whitespace-only text cannot send; submitted text retains the existing trim behavior. A failed text submission retains the draft. Scroll through long options to their end; no text should be discarded to fit the viewport.

## CompletionNodeWidget — next lesson and return (S18)

### Reach

1. Complete an intended routed lesson.
2. If the server supplies an available next step, inspect its full title and tap **Continue to next lesson**.
3. Use Back in the next lesson. Inspect the previous completed lesson, then **Return to Home**.
4. Inspect Coming soon or Roadmap complete only where supplied by actual progression data; previews cover unavailable states safely.

### Changed / visual and functional checks

The summary is scrollable, next/coming-soon/roadmap-complete states use plain labels, and **Return to Home** truthfully names its existing destination. Long next titles and buttons wrap. Repeated next taps cannot push duplicates. The next destination keeps its supplied step ID or slug; Back restores the previous completion without replacing its controller. Completion and rewards are not fabricated or recalculated by the widget.

## DoubtSheetWidget — Ask tutor preview (O15)

### Reach

1. Routed lesson → **Ask tutor**.
2. Enter an intended question (up to the existing server's 500-character limit) → **Ask tutor**.
3. Inspect Asking tutor, then the actual response/error. Ordinary failure keeps the question and offers **Try again**.
4. Separately close the sheet while an intended request is pending. Return to the lesson; the late reply must not reopen it or update a disposed view.

### Changed / visual checks

A bounded, keyboard-aware shared sheet keeps Close available. The labelled question, busy action, error and long reply scroll without covering controls. The question is retained across failure; loading cannot send duplicates. Native modal focus returns to the prior input when dismissed. Check the final action and final lines of long content at enlarged text/landscape.

### Current service limitation / expected result

**The local backend currently uses a stub tutor provider and returns `STUB_RESPONSE`.** For that explicit status, expect **Tutor · Coming soon** and a clear unavailable message, with the original question retained read-only. It must not be presented as a personal tutor explanation. Voice/scan and live tutoring were not integrated in this phase.

The client now reads that already-returned status alongside the message; the endpoint and request payload are unchanged. The existing request path remains available as **Tutor preview**. Actual reply and error states are covered using deterministic fixture responses; those previews do not prove a deployed AI service exists.

## Lesson tools / VoiceStubSheet / ImageStubDialog (O16–O17)

### Reach

1. Routed lesson → more icon (**Lesson tools · Coming soon**).
2. Select **Voice · Coming soon**. Read the informational sheet → Got it or Close.
3. Reopen Lesson tools → **Scan work · Coming soon** → Got it.

### Changed / checks / expected results

The tools sheet uses the shared live-themed, scrollable shell. Labels disclose availability before selection. The informational surfaces explain the limitation with reachable dismissal at enlarged text and short heights. Neither action requests microphone/camera access, uploads work, submits a lesson answer or changes progress. The lesson/draft remains intact on return.

## SocialOverlay / SocialInvitationDialog / Daily invitation action (O20)

Automatic presentation continues to concern **duel invitations**. Friend requests retain their existing Friends inbox flow; this phase does not introduce automatic friend-request dialogs.

### Reach

1. On another existing friend account: Home → Practice → Friendly duel → Invite a friend → choose this account, using an intended invitation.
2. With the receiving account idle on Home/Friends, inspect the automatic **Duel invitation** dialog.
3. Repeat while receiving account is in an embedded/routed lesson, Practice, Daily, Ranked, preparation/matchmaking, or while a confirmation/help/feedback surface has focus.
4. During active work, use the visible **Review duel invitation** mail action. It is in a non-blocking banner on most surfaces; **Daily uses a badged toolbar mail action** so its answer-feedback reading height is preserved.
5. Try Android Back before responding, then reopen through Review. Respond intentionally with Accept/Reject; separately allow an invitation to expire.
6. During matchmaking, change tabs while waiting. Automatic invitations/celebrations must remain deferred until the existing queue operation resolves. Cancel remains acknowledgement-based.

### Changed / visual checks

Automatic invitations and celebrations cannot stack over a current modal or active work. The review entry is native, labelled and does not take input focus. Banner text exposes the remaining budget visually; its accessibility announcement is stable rather than repeating every second. Daily's compact mail entry keeps feedback and Next readable. Short-header measurement allows the Daily title and action to fit at enlarged text.

### Functional checks / expected results

Review is a deliberate user action and opens the same existing response dialog. Session/question state and timers continue as before. Busy response prevents duplicates; ordinary failure permits retry. Back sends no accept/reject and leaves a timed review entry, without automatically reopening the same dialog. Expiry hides the entry and does not send a response. Deferred/queued invitations keep their original budget across inbox updates; no late popup or extension is created. Explicit accept retains the existing friendly-duel destination and auto-play flow. Account changes clear queued presentation; current-user confirmations retain priority. Background/resume must not revive expired invitations.

## LevelUpOverlay / XpController — global celebration (O21)

### Reach

1. Use an account close to a level boundary, visible in Profile. Complete an intended learning activity that actually earns the required XP.
2. During the active lesson/player/result/confirmation, confirm that a celebration does not steal focus.
3. Return to an idle Home/Friends/Profile boundary, or resolve pending invitations, then inspect the celebration → **Continue**.
4. Repeat with System appearance changes and reduced motion where practical. If no suitable real award is available, use the supplied normal/multi-level/large-text previews; no debug award control or fake reward was added.

### Changed / visual and functional checks

The native dialog uses the real user avatar or initial, approved color/type pairs and a compact measured identity/level layout. The final level is readable near the top, including narrow landscape. Continue stays reachable while long content scrolls. Internal decorative motion is reduced to a short optional level transition; reduced motion shows the final state immediately.

XP/auth progress updates immediately through the existing logic; only celebration presentation waits. Deferred awards retain the final target level instead of being dropped when another event is pending. Invitations take priority when both are waiting. Continue dismisses once and never awards XP again; cancelling/dismissing also leaves recorded progress unchanged. A pending celebration must not appear for a different account. Finishing editing (for example, keyboard Done) and closing the keyboard releases a queued celebration without a route change. Editable focus also protects hardware-keyboard input; the search/draft is preserved.

## Verification and remaining limits

**Final validation:** 44 Phase F cases passed within the full suite; full suite 256 passed / nine preserved golden-comparison failures across ten images. Static analysis and Android debug build passed; `git diff --check` passed. See progress for exact scope. Automated evidence covers route/ID payloads, stale/disposed lifecycle, error/draft/selection retention, both-theme native target labels/sizes/text contrast, keyboard focus, timed-player deferral, queue/background races, Back/expiry and service-unavailable presentation. All authored scripts, models, theme definitions, dependencies/assets and golden baselines remain preserved.

No authenticated device action, invitation, answer, reward, provider integration or native screen-reader session was performed. Multi-device server timing, Android/iOS lifecycle/process restoration, platform keyboards/system bars and TalkBack/VoiceOver still need real-device acceptance. The existing Ranked Leave/Forfeit server-policy gap and deferred legal URLs remain unchanged. Root legacy-theme retirement, exhaustive app-wide checks, deliberate golden review and cleanup remain gated Phase G work.

Phase F is complete and awaiting your manual review.
Please inspect the listed screens in both light and dark mode and test the specified interactions.
Reply with `APPROVE PHASE F` to authorize the next phase, or `REVISE PHASE F: ...` to request changes.
I will not proceed until you explicitly approve.
