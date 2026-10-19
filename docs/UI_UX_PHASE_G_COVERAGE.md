# Phase G — final QA coverage and release limits

Authorization: `APPROVE PHASE F`. This report supplements the preserved original audit/plan; their reference checklists are not rewritten. A–F approvals and the saved composition preferences remain in force. **The user subsequently marked Phase G completed and manually approved, requested no release, and explicitly deferred the unresolved Ranked outage/exit policy.** Fixture evidence and the agent’s native verification limitations remain recorded accurately; completion is no longer awaiting approval.

## Automated envelope

`test/phase_g_app_review_test.dart` mounts every S01–S18 view in Light and Dark at **320×568, 390×844, 430×932, 844×390 and 768×1024**, each at **1.0, 1.3 and 2.0 actual Flutter text scale**: 540 screen/theme/size/scale cases. The fixtures include safe top/bottom padding of 24 px, long identities and supplied question/explanation data; enlarged cases use long content. Each case checks initial layout and scrolls the reading surface with bounded pumps to find later overflow. This is rendered fixture coverage, not a claim of authentic server content or native orientation testing.

Additional G cases cover embedded fullscreen reading with draft/controller/no-submission/Back/Close preservation, Home difficulty/achievement sheets, Topic details and Daily preparation at 320×568 and 568×320/2× in both themes, root saved preference/OS changes with route/controller/draft preservation, persistent storage reload, modal appearance while open, native notices, and unknown-route recovery. One separate test uses the **real production asset manifest**, without the fixture font handler, to load both approved font families at all five bundled weights with runtime fetching disabled.

At 390×844/1×, all 18 views in each theme also run Flutter's native target and label guidelines and pixel text-contrast guideline. Transient enabled-color animations are allowed to finish before measurement. The appearance badge uses the approved 12 px label role. Notice contrast is sampled on the actual snackbar Text with `CustomMinimumContrastGuideline`: underlying controls can be visually occluded by a snackbar and are not a valid background for its contrast sample. No failing visible text is excluded to silence a test.

The A–F suites supply action/state/overlay regressions, real 2× keyboard insets on registration/search/tutor/text input, selected and locked answers, reduced motion, timer/submission guards, lifecycle/route/account ownership, and explicit resolved color-pair checks. B and C were extended to the 568×320/2× envelope for the real Profile/Topics/calendar and Login/signup/picker flows. The retired topic-card tests retain their model checks; available-topic callbacks and unavailable-topic protection are now checked on the **live ConstellationRoadmapView**, alongside existing topic/subtopic tests.

## S01–S18 and shell traceability

All rows receive the G envelope above. The state coverage column identifies additional preserved or extended suites; it does not imply every hypothetical server response was generated.

| ID / actual view | State/action evidence in addition to G layouts | Manual/native limitation |
|---|---|---|
| Shell / HomeScreen, TopBarZone, BottomNavZone | `home_navigation_test`, `social_test`, A/B/F: five tabs, fullscreen/back, pending dot, active task protection | Native system-back, orientation and OS bars need device acceptance |
| S01 LoginScreen | `auth_account_selection_test`, C: error/cancel/busy, duplicate sign-in, logo/provider action, disabled legal UI | Real Google/native account picker not exercised by agent |
| S02 SignUpScreen | C: prefill, every invalid field, retained values/errors, focus, keyboard, selectors, cancellation/busy/account switch | Native keyboard/date picker and registration require intended test account |
| S03 HomeDashboardContent | `home_dashboard_test`, B/G: empty/populated/cached failure, supplied metrics, resume, difficulty, achievements, calendar/day | Live data/timezone acceptance remains manual |
| S04 ChatPlaygroundZone / QuestionContainerWidget | A/B/G, `home_navigation_test`: answer/input/feedback/tools, selection/callback, close/re-entry; fullscreen draft/controller/Back preservation | Real lesson answer/reward not submitted by agent |
| S05 ConstellationRoadmapView / TopicDetailsSheet | `constellation_roadmap_test`, `topic_details_sheet_test`, `topic_progress_ui_test`, B/G: map/list/zoom, states, live dock updates, callbacks | G fixes short-sheet overflow and measured action-row fit; native dragging remains manual |
| S06 PracticeCatalogView setup | `practice_catalog_test`, D: Random/Custom/settings, partial topic/subject selection, no catalog/error/preparation/duplicate guards | Live generation/friendly picker require service/account data |
| S07 PracticeCatalogView history | D: loading/error/empty/cache/page retry, paging, replay guard, labels | Live history/replay values require account data |
| S08 PracticeSessionScreen | `practice_session_test`, D/E: timed/untimed/replay/friendly, clock failure, selection/submission/error/retry, hints, Book/Alternative/preferred reason, result/abandon | Device timer/background and server reward acceptance outstanding |
| S09 PvpLobbyView | E: idle/queue/cancel/connecting races, history empty/error/populated/retry/replay busy | Live matchmaking/multi-device required |
| S10 PvpArenaScreen | E: waiting, supplied question/lock/round/result, loss/tie/AFK, connection loss/reconnect and recovered completion, invalid entry | **Permanent-outage exit remains unsupported; UX-08 is explicitly deferred by the user** |
| S11 ProfileScreen | B/C/G, `xp_level_system_test`: identity/avatar fallback, missing/cached/error stats, appearance save/failure/retry, version, logout confirm | Real native storage/relaunch, screen reader and logout acceptance outstanding |
| S12 DailyStreakHubScreen | D/G: loading/error/eligible/resume/completed, history/error/paging, preparation/failure/busy | Live daily participation/rewards not generated |
| S13 DailyChallengeQuizScreen | D/F/G: missing session, options/timeout/selected/submitting/feedback, long methods/Next/completion/exit, invitation toolbar, guarded notices | Native lifecycle and live server deadline acceptance outstanding |
| S14 FriendsScreen / picker | `social_test`, E: all relationships, search/no results/error/keyboard, paging/stale requests, picker return | Live presence, two-account activity and native focus outstanding |
| S15 FriendRequestsScreen | `social_test`, E: empty/error/loading/pending, actions/busy/version | Agent did not send or respond to real requests |
| S16 FriendProfileScreen | `social_test`, E: relationship states, unavailable/online/offline, N/A, long counts/names, badge/activity failures/paging | Actual avatars/presence and native traversal need acceptance |
| S17 DuelRoomScreen | E/F: requester/recipient, pending/deadline/expiry/back/cancel/reject/active/own done/complete/tie/abandoned/error, auto-open | Live two-account deadlines/background behavior outstanding |
| S18 LessonFeedScreen / all node renderers | F/G, `lesson_progress_test`: both aliases, all five nodes, unknown fallback, title, errors, retained draft/selection, next/unpublished/complete and scoped route ownership | Published routed content/native entry setup as described in F review; tutor still server stub |

## O01–O22 traceability

Both-theme small-portrait and short-landscape/2× coverage is supplied by B/C/D/E/F plus the G additions. C/B now include the stricter 568×320 size. Test capture files from earlier phases remain unchanged; G has fresh supplemental evidence.

| ID | Actual overlay / entry | Coverage |
|---|---|---|
| O01 | SignUpScreen DOB picker | C: range/selection/cancel, validation, both themes and 2× landscape |
| O02 | SignUpScreen belief selector | C: exact values, selected radio, bounded scrolling/Close and dismissal |
| O03 | SignUpScreen country selector | C: exact values, selection and scroll-safe Close/dismissal |
| O04 | Home By difficulty sheet | B/G: supplied definitions/metrics, 320×568 and 568×320/2× Close and scrolling |
| O05 | AchievementBrowser | `home_dashboard_test`/G: loading/error/retry/cache/pagination/dedup; real sheet in both 2× envelopes |
| O06 | ActivityCalendar day details | `home_dashboard_test`, B: day list → exact day, zero/populated/IST; B now includes 568×320/2× |
| O07 | TopicDetailsSheet | Topic suites/B/G: live completion, subtopic and whole-topic callbacks; small/short sheet reading/action positions and Close |
| O08 | Daily history sheet | D: loading/error/empty/populated/paging/retry and both 2× envelopes |
| O09 | Daily preparation region | D/G: local guarded preparation, failure recovery; 2× short-height status remains readable. No destructive action invented |
| O10 | Daily result dialog | D: success/failure, actual streak/reward values, small/short 2× and Return action |
| O11 | Daily exit confirmation | D: Stay/Leave and same state/timing, both 2× envelopes |
| O12 | Practice hints | D: actual available/revealed count/reopen, both 2× envelopes |
| O13 | Preferred-method reason | D: actual reason and unavailable reason, both 2× envelopes |
| O14 | Practice exit confirmation | D: retain/abandon and existing callback/zero completion reward, both 2× envelopes |
| O15 | DoubtSheetWidget / Ask tutor | F: keyboard, busy/error/retry/long reply, dismissal before completion, explicit STUB_RESPONSE, both 2× envelopes |
| O16 | VoiceStubSheet | F: disclosed Coming soon, bounded content/Close/Got it at both 2× envelopes; no voice submission |
| O17 | ImageStubDialog | F: disclosed Coming soon, native scrollable dialog/Got it at both 2× envelopes; no scan submission |
| O18 | Profile signout confirmation | B/C/G: Cancel/confirm/busy/failure, both 2× envelopes; live theme switching while open |
| O19 | Remove-friend confirmation | E: named identity, Cancel/one delete/version, both 2× envelopes |
| O20 | SocialInvitationDialog / SocialOverlay review | E/F: deadline, Back/no response, expiry, busy/error and native response; editing/modal/task/queue deferral, owner change, review entry, background/resume fixtures |
| O21 | LevelUpOverlay | XP/F: actual identity/final level, queued/coalesced awards, 2× portrait/landscape, reachable Continue, reduced motion and one continuation |
| O22 | Daily persistent explanation | D/F: correct/incorrect/timeout, long supplied methods, Next guard/result and invitation-toolbar coexistence at 2× |

## Original findings and measurable acceptance

| Finding / criterion | Implemented/automated evidence | Release acceptance status |
|---|---|---|
| UX-01 appearance | Paired themes/components from A; persisted selector B/C; G root mode + startup/system bars, no static dark aliases; OS/override/reload/route/draft tests | Native OS bars/keyboard/relaunch check outstanding |
| UX-02/03 contrast/readability | Semantic foreground/background pairs; real-font pixel guidelines across all normal 18-view/theme fixtures; active/selected/loading/error pair checks in A–F; G notices/badge | Device rendering and remaining live-content states require acceptance; disabled legal/busy controls are explicitly disabled exceptions |
| UX-04 targets | Project 48 px native minimum controls, calendar day list, measured target/label guidelines on normal G fixtures, A–F explicit bounds at 2× | Native touch/assistive-tech pass outstanding; targets do not expand invisibly over neighbors |
| UX-05 semantics/focus | Native options/actions, selection/locked state, icon labels, keyboard/focus/announcement fixtures; G normal 18-view label/target checks | **TalkBack/VoiceOver completion remains unverified** |
| UX-06/07 layout/modal safety | Complete G size/scale envelope, long content and scroll passes; prior keyboard/mounted-disposal fixtures; new short TopicDetailsSheet regression fixed | Native rotation/keyboard/safe-area session outstanding |
| UX-08 Ranked recovery | E waiting/connection/retry/refresh and honest recovered-result handling; no fabricated rewards | **OPEN P1 / user-deferred:** no supported permanent-outage Leave/Forfeit operation or sufficient recovered result payload. Separate product/server approval needed |
| UX-09 navigation | Auth/onboarding guards, safe extras/invalid route fallbacks, alias IDs, F route ownership and G readable unknown-route Home recovery | Native back/entry acceptance outstanding |
| UX-10 states | Initial failure stops loading; cached/stale content and operation-specific retry; guarded duplicate requests/submissions; suites above | Live network/service acceptance outstanding |
| UX-11/12/13/14/15 | Approved type hierarchy, readable selected/feedback states, session progress, navigation and method presentation implemented A–F; original callbacks/IDs/order/timers preserved | Inspect actual account content as in manual guide |
| UX-16/17/18 | Truthful tutor/voice/scan availability, original required registration/validation, actual avatar/initial/version | Legal destinations explicitly deferred by user; tutor remains stub; no integrations added |
| UX-19 motion | Static reduced-motion loaders/map/celebration; G Profile route honors disableAnimations and root appearance changes are immediate | Native reduced-motion and focus traversal acceptance outstanding |
| UX-20 overlay coordination | F owns invitation/celebration stacking, route/editing/activity guards, monotonic expiry, manual review and account reset | Multi-device/native background deadline acceptance outstanding |
| UX-21 composition/metrics | Approved grouped hierarchy and source-specific/N/A metric meanings preserved; G does not recompute values | Verify actual values, no comparison between unlike denominators |
| UX-22 evidence | Production-font fixture correction, 11 individual golden decisions, dual-theme full size/scale matrix, offline production-asset load test | Device evidence incomplete; widget images are not authentic native screenshots |
| UX-23 cleanup | Six confirmed-unused presentation files removed; only `AptiquTypography.textTheme` retained; obsolete theme aliases removed; catalog stat helper already absent after migration | Registered routed screens and live indicators retained |
| UX-24 copy | Plain existing labels from A–F plus G Page unavailable; no raw framework exception in fallback | No backend/content-authoring changes |
| Regression / scope | Full Flutter suite and analysis; build; baseline-based source comparison, asset hashes and preserved audit/plan. No models/endpoints/payloads/scoring/curriculum/auth changes | No deploy/PR/commit/install performed |

## Verification record

- Initial G integration run: **458 tests passed**, including the corrected/reviewed goldens. Two root-notice cases then also passed after adding direct checks of both guarded Daily notices.
- **Final full run: 820 tests passed, zero failures**, including 550 G cases, the independent font-asset case and all earlier regression suites. All five sizes run at each of three text scales. No missed-tap warnings or caught layout exceptions remain. Log: `/private/tmp/aptiqu_phase_g_final_tests.log`.
- **Final `flutter analyze --no-pub`: no issues.** `git diff --check`: passed.
- `flutter build apk --debug --no-pub`: passed. APK contains the bundled approved font assets. Release/iOS builds were not run.
- Device discovery: **no authorized devices detected**; iOS wireless discovery reported Developer Mode/connection prerequisites. No device setting was changed to work around this.
- Actual rendered fixture evidence: [G index](ui_ux_phase_g/README.md), with safe example data and exact production fonts. [Golden decisions](ui_ux_phase_g/goldens/README.md) retain all 11 before/after pairs and hashes.

## Preserved scope

Comparison is against `/private/tmp/aptiqu_phase_g_baseline`, captured after F approval, because Git HEAD predates the revamp. G changes root appearance/startup bars/offline font provisioning, notice/fallback presentation, the Profile badge/note, TopicDetailsSheet composition, and embedded fullscreen reading with a stable keyed Home content area. Six unused presentation files and their obsolete static aliases are retired. No backend/database/VPS/migration, authored content, route parameters/extras, lesson/answer operations, rewards, match policy, friendship version or auth/session storage behavior changed.

Font assets are the same verified static files already used by the approved fixtures, with OFL licenses and source hashes. `pubspec.yaml` gains asset directories; **no dependency/version or lockfile change** is introduced in G. The audit, plan, A–F evidence, palette values and typography sizes remain intact.

## Final gate

Phase G is completed and manually approved. The user requested no release and explicitly left the Ranked recovery policy unresolved. The historical native-verification limitations above remain evidence limits, not a pending G approval gate. Any future release assessment is separately scoped. Terms/Privacy URLs remain deferred by the user's instruction; they are not invented or activated. Tutor/Voice/Scan remain disclosed unavailable capabilities. Wider web/desktop shipping scope is unconfirmed; tablet is a fixture sanity pass, not iPad release certification.
