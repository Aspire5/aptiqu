# MANUAL UI VERIFICATION — PHASE G

Phase F was approved with `APPROVE PHASE F`. Phase G implementation and automated review are complete. **Final human acceptance and release approval are still required. No deployment, install, production interaction or release was performed.**

Use the current [debug APK](../build/app/outputs/flutter-apk/app-debug.apk) or run the existing Flutter app from this checkout. Use a test account for answers, friend responses and matches: those existing operations can change real progress/rewards. The agent used local fixtures only. Device discovery found no authorized device; native checks below are outstanding.

[Rendered evidence](ui_ux_phase_g/README.md) · [coverage and unresolved acceptance](UI_UX_PHASE_G_COVERAGE.md) · [individual golden reviews](ui_ux_phase_g/goldens/README.md).

## AptiquApp / ProfileScreen / AppearanceSetting

1. Sign in to a completed account. On **Home**, tap your avatar/name in the top bar to open **Profile**.
2. In **Appearance**, choose **Light**, **Dark**, then **System**. The current-mode badge uses the existing label text style at the same size. The temporary partial-dark-mode note is removed.
3. With **System** selected, change the device appearance while the app is open. Visit **Home**, **Topics**, **Practice**, **Ranked** and **Friends**, then open Profile, Daily challenge and available detail screens. Screen backgrounds, native controls, notices, selection handles and system bars must agree. The app root now follows the preference as well as the individual screens.
4. Set an explicit Light/Dark choice, change the OS appearance and verify the override remains. Close and relaunch the app; the saved choice must remain. Select System again to restore the default behavior.
5. Open **Sign out**, change the OS appearance in System mode, and return to the still-open dialog. Its theme must update. Tap **Cancel**: the account and current route must remain. Also check theme switching does not reset an active practice selection, lesson draft, question or timer.
6. Check text on a first launch with network unavailable, including Login when no session is available. The approved Outfit/Plus Jakarta Sans files are now bundled; text must render without waiting for font downloads. Native auth/network failures remain governed by existing behavior. No cache clearing, account deletion or database setup is needed for this check.

Expected: consistent root and overlay appearance, stable navigation/session state, readable badge and original font families/sizes. The preference remains local to this device. **Login, SignUpScreen and ProfileScreen account behavior is unchanged.**

## HomeScreen / ChatPlaygroundZone — fullscreen reading

1. From Home, use **Continue learning**, or **Topics → available topic → Start/Continue**, to open the existing embedded lesson.
2. In a short viewport or with enlarged text, the fixed header is compact and the full lesson title is in the reading scroller. Tap **Fullscreen lesson** beside **Close lesson**. It uses the existing fullscreen presentation state to free the shell's top/bottom space for reading.
3. Scroll to a question and type an unsubmitted answer if the lesson supplies a text node. Tap **Exit fullscreen lesson**, then enter fullscreen again and use device **Back**. The shell must return with the same lesson, selected answer/draft and scroll controller. None of these presentation actions submits an answer, awards XP or restarts the session.
4. **Close lesson** still returns to Home and restores shell navigation. On Topics, Back from the existing fullscreen map also restores the shell.

Expected: substantially more reading space in large-text landscape, full title available by scrolling, 48 px labelled controls, and unchanged lesson callbacks/state. The G fixture checks draft/controller preservation and absence of lesson requests while toggling.

## TopicDetailsSheet / TopicActionButtons

Prerequisite: an account with an available or completed published topic.

1. From Home, tap **Topics**, select **List** (or use the map), then tap a topic.
2. At normal phone size, inspect the same topic/subtopic progress, **Practice**, and **Start**, **Continue** or **Replay** actions. Actions now share a row whenever their actual labels fit at the current text scale.
3. Increase device text size to about 2× and rotate to landscape. Scroll the sheet. When height is limited, **Whole topic** actions are part of the scrollable content instead of consuming the reading area; **Close topic details** remains visible. On narrow portrait, controls may stack to retain full labels and 48 px targets.
4. Drag the sheet shorter and taller. Read every subtopic, reach the Whole topic actions, then close/reopen it. Choose an action only if you intend to start the existing lesson/practice operation. It must use the same topic/subtopic and preserve Start/Continue/Replay meaning.
5. Open an unpublished topic. Its explanation remains readable, and no unsupported lesson-start action is offered.

Expected: no bottom overflow at 568×320/2×, no clipped button label, no lost lesson callback, and a useful scrolling reading area. Both light/dark captures include the reading and action positions.

## PracticeCatalogView / DailyStreakHubScreen / DailyChallengeQuizScreen notices

1. From **Home → Practice**, allow the catalog to load. On a test device, make the network unavailable, then tap **Start practice** once. If preparation fails, the existing **Session Failed** notice must use readable theme-matched error foreground/background colors. Restore network and retry normally; busy controls must prevent duplicate preparation.
2. From **Home → Daily Challenge**, inspect loading, eligible/completed state and any existing failure/retry feedback in both appearances. Starting/answering/finishing the challenge retains the existing server rules, 60-second timing and reward values.
3. In an active daily question, **Confirm answer** stays disabled until a selection is available. Complete or leave only as intended; final result/exit behavior is unchanged.

The Daily “select an option” and “cannot start another attempt today” notices are defensive controller paths, normally prevented by the visible controls. **There is no reliable ordinary navigation path that forces them.** Their actual native snackbars were checked with local fixtures in both themes. No artificial action or developer launcher was added to expose them. The old coming-soon Home notification also inherits the native snackbar theme; normal topic inspection uses the existing topic sheet.

Expected: readable notices with unchanged messages, requests and retry/eligibility behavior. [Notice previews](ui_ux_phase_g/README.md#notices) include those guarded paths.

## AppRouter — Page unavailable

There is no public native app-link configuration for arbitrary URLs in this checkout. Do not invent a menu entry.

1. For a safe debug check, stop the running debug app and launch with an unknown initial route using an attached device ID:

   ```sh
   flutter run --debug --no-pub -d DEVICE_ID --route='/missing-review-route'
   ```

2. A valid completed session may be required because the existing auth/onboarding guards remain. If you are redirected to Login/Complete profile instead, finish the normal entry flow and use the local fixture test as the safe alternative: `flutter test --no-pub test/phase_g_app_review_test.dart --name 'unmatched route'`.
3. Expect **Page unavailable**, a short explanation and **Return to Home**, with the chosen appearance and no framework exception/stack text. **Return to Home** must follow normal auth guards and restore the real Home destination.

## Final app-wide acceptance route

Repeat this pass in Light, Dark and System. Use portrait and landscape, normal and enlarged device text, keyboard and system back. The full automated mapping is in the coverage report; these are native acceptance steps, not claims of completed device verification.

1. **LoginScreen / SignUpScreen:** on a signed-out or incomplete test account, inspect **Continue with Google**, cancellation/error/busy, prefill, required-field messages, DOB/belief/country pickers and **Use a different account** cancellation. Terms/Privacy remain disabled until the user supplies URLs, as explicitly agreed. [Phase C steps](UI_UX_PHASE_C_REVIEW.md).
2. **HomeScreen / HomeDashboardContent / ChatPlaygroundZone:** inspect all five tab labels, a long identity, resume/Explore topics, performance definitions, achievements, dates-as-list/day details and IST. Resume an available embedded lesson; inspect content, answer/feedback and Close lesson. Back returns to the same shell. [Phase B steps](UI_UX_PHASE_B_REVIEW.md).
3. **ConstellationRoadmapView / TopicDetailsSheet:** inspect Map/List, subject choice, zoom/fullscreen, available/locked/coming-soon/completed topics and subtopic actions. Use the detailed Phase G sheet checks above.
4. **PracticeCatalogView / PracticeSessionScreen:** inspect Random/Custom, topic selection and settings; **History & replays**, paging and replay; one existing practice answer, hint count, Book/Alternative solution and preferred reason; cancellation/abandon confirmation and result. Preserve replay reward treatment. [Phase D steps](UI_UX_PHASE_D_REVIEW.md).
5. **DailyStreakHubScreen / DailyChallengeQuizScreen:** inspect History, preparation/failure, resume or completed status, active clock, confirm/feedback, long explanation, Next, exit confirmation and result. Do not create another daily attempt to test a layout. [Phase D steps](UI_UX_PHASE_D_REVIEW.md).
6. **FriendsScreen / FriendRequestsScreen / FriendProfileScreen / DuelRoomScreen:** inspect search/keyboard, no-results, paging, request inbox and a learner profile. Use existing data for confirmations and invitation lifecycle. On two test accounts, verify pending/expired/cancelled/accepted states, active friendly play and result; respond only when intended. [Phase E steps](UI_UX_PHASE_E_REVIEW.md).
7. **PvpLobbyView / PvpArenaScreen:** inspect rules/history/replay and queue/cancel. Live match checks require two test accounts and a functioning server. Verify question selection/lock, round/result and reconnect. **A permanent live-match outage still has no supported Leave/Forfeit operation; this is a release-blocking server/product dependency. Do not treat a passing fixture or this phase approval as resolution.** [Phase E recovery limits](UI_UX_PHASE_E_REVIEW.md).
8. **LessonFeedScreen / DoubtSheetWidget / tools:** use a real published routed slug/step from the existing account if available. Both aliases, all five node types, draft/error retention, next/unpublished completion, Ask tutor preview and Voice/Scan Coming soon must agree with the approved behavior. These routes lack a guaranteed public native entry; use the exact debug entry/prerequisites in [Phase F steps](UI_UX_PHASE_F_REVIEW.md). The server tutor is still a stub, explicitly labelled Coming soon.
9. **SocialOverlay / LevelUpOverlay:** with existing test invitations/awards, verify deferred presentation during questions/editing/other dialogs, countdown not restarting, manual invitation review, Back preserving review access, account ownership, queued final level and one Continue. Check OS background/resume on both participating devices. These live/native events were not generated by the agent. [Phase F steps](UI_UX_PHASE_F_REVIEW.md).
10. **Native accessibility:** with TalkBack on Android and VoiceOver on iOS, complete login entry, topic selection, one lesson question, practice, request response and modal dismissal. Verify selected/locked answers, error announcements, meaningful icon labels, traversal order, focus return, keyboard activation, safe areas and reduced motion. Rotate while editing, inside sheets, during a timed question and during pending invitation review. Check status/navigation bars and platform keyboard appearance where supported.

## Approval gate

Record device/OS, theme, text size and any failure with its exact entry path. Resolve the Ranked outage/exit policy through separately authorized server/product work and complete native Android/iOS acceptance before approving a release. Missing legal destinations remain the explicitly deferred user-owned configuration item; no URLs were fabricated.

**Stop here for final manual verification and explicit release approval. Phase F approval authorized this QA/cleanup work only. No release is inferred from phase approval, passing tests, screenshot acceptance or APK compilation.**
