# Phase G rendered evidence

76 fresh Flutter widget renders with safe example data and exact production fonts. These are rendered fixtures, not authenticated/native-device screenshots or additional golden baselines. The [manual guide](../UI_UX_PHASE_G_REVIEW.md) and [coverage report](../UI_UX_PHASE_G_COVERAGE.md) state what was exercised and what still requires native acceptance.

The complete G matrix covers all 18 views in both themes at five sizes and three actual text scales. The images below are representative review positions, not a claim that every matrix case was saved or individually inspected. All normal theme pairs, the saved enlarged landscape pairs and supplemental Home/Topic/preparation surfaces were visually inspected. Before/after golden decisions were individually reviewed with the correct font fixtures.

## Normal phone: 390×844, 1× text

| View | Light | Dark |
|---|---|---|
| LoginScreen | [Light](S01-login-light-phone.png) | [Dark](S01-login-dark-phone.png) |
| SignUpScreen | [Light](S02-signup-light-phone.png) | [Dark](S02-signup-dark-phone.png) |
| HomeScreen / dashboard | [Light](S03-home-light-phone.png) | [Dark](S03-home-dark-phone.png) |
| ChatPlaygroundZone | [Light](S04-embedded-light-phone.png) | [Dark](S04-embedded-dark-phone.png) |
| ConstellationRoadmapView | [Light](S05-topics-light-phone.png) | [Dark](S05-topics-dark-phone.png) |
| PracticeCatalogView setup | [Light](S06-setup-light-phone.png) | [Dark](S06-setup-dark-phone.png) |
| PracticeCatalogView history | [Light](S07-history-light-phone.png) | [Dark](S07-history-dark-phone.png) |
| PracticeSessionScreen | [Light](S08-practice-light-phone.png) | [Dark](S08-practice-dark-phone.png) |
| PvpLobbyView | [Light](S09-ranked-light-phone.png) | [Dark](S09-ranked-dark-phone.png) |
| PvpArenaScreen | [Light](S10-arena-light-phone.png) | [Dark](S10-arena-dark-phone.png) |
| ProfileScreen | [Light](S11-profile-light-phone.png) | [Dark](S11-profile-dark-phone.png) |
| DailyStreakHubScreen | [Light](S12-daily-light-phone.png) | [Dark](S12-daily-dark-phone.png) |
| DailyChallengeQuizScreen | [Light](S13-daily-quiz-light-phone.png) | [Dark](S13-daily-quiz-dark-phone.png) |
| FriendsScreen | [Light](S14-friends-light-phone.png) | [Dark](S14-friends-dark-phone.png) |
| FriendRequestsScreen | [Light](S15-requests-light-phone.png) | [Dark](S15-requests-dark-phone.png) |
| FriendProfileScreen | [Light](S16-learner-light-phone.png) | [Dark](S16-learner-dark-phone.png) |
| DuelRoomScreen | [Light](S17-duel-light-phone.png) | [Dark](S17-duel-dark-phone.png) |
| LessonFeedScreen | [Light](S18-routed-light-phone.png) | [Dark](S18-routed-dark-phone.png) |

## Enlarged landscape: 844×390, 2× text

Reading regions scroll. A screenshot of the initial position can show only metadata or the start of long content; the automated matrix also scrolls. Embedded learning now has a compact header and an explicit fullscreen reading view, without changing lesson actions.

| View | Light | Dark |
|---|---|---|
| SignUpScreen | [Light](S02-signup-light-landscape.png) | [Dark](S02-signup-dark-landscape.png) |
| ChatPlaygroundZone | [Light](S04-embedded-light-landscape.png) | [Dark](S04-embedded-dark-landscape.png) |
| PracticeSessionScreen | [Light](S08-practice-light-landscape.png) | [Dark](S08-practice-dark-landscape.png) |
| ProfileScreen | [Light](S11-profile-light-landscape.png) | [Dark](S11-profile-dark-landscape.png) |
| DailyChallengeQuizScreen | [Light](S13-daily-quiz-light-landscape.png) | [Dark](S13-daily-quiz-dark-landscape.png) |
| LessonFeedScreen | [Light](S18-routed-light-landscape.png) | [Dark](S18-routed-dark-landscape.png) |

## Home/Topic/preparation: 2× text

Numeric suffixes identify logical widths: **320×568** and **568×320**, with safe insets. Topic actions are shown separately from the initial reading position so their reachability is reviewable. Existing B/C/D/E/F evidence continues to cover the other 22-overlay states without being overwritten.

| Surface | Light portrait | Dark portrait | Light landscape | Dark landscape |
|---|---|---|---|---|
| By difficulty | [Light](O04-light-320.png) | [Dark](O04-dark-320.png) | [Light](O04-light-568.png) | [Dark](O04-dark-568.png) |
| Achievements | [Light](O05-light-320.png) | [Dark](O05-dark-320.png) | [Light](O05-light-568.png) | [Dark](O05-dark-568.png) |
| Topic reading | [Light](O07-reading-light-320.png) | [Dark](O07-reading-dark-320.png) | [Light](O07-reading-light-568.png) | [Dark](O07-reading-dark-568.png) |
| Whole topic actions | [Light](O07-actions-light-320.png) | [Dark](O07-actions-dark-320.png) | [Light](O07-actions-light-568.png) | [Dark](O07-actions-dark-568.png) |
| Daily preparation | [Light](O09-light-320.png) | [Dark](O09-dark-320.png) | [Light](O09-light-568.png) | [Dark](O09-dark-568.png) |

## Notices

390×844 native root presentation. Daily safeguards are invoked through fixture controllers because normal visible controls prevent these invalid actions. Their presence is not a new public flow. The actual error/standard notice foregrounds were measured against their resolved/composited backgrounds.

| Notice | Light | Dark |
|---|---|---|
| Practice preparation failed | [Light](practice-notice-light.png) | [Dark](practice-notice-dark.png) |
| Daily selection guard | [Light](daily-selection-notice-light.png) | [Dark](daily-selection-notice-dark.png) |
| Daily eligibility guard | [Light](daily-attempt-notice-light.png) | [Dark](daily-attempt-notice-dark.png) |

## Embedded fullscreen lesson

844×390 at 2× text. The same unsubmitted draft is retained when entering/exiting fullscreen and when native Back restores the shell. Close lesson restores Home. The fixture verifies that no lesson request/submission occurs from these presentation controls.

[Light](embedded-fullscreen-light.png) · [Dark](embedded-fullscreen-dark.png)

## Reviewed goldens

[All 11 individual decisions and before/after pairs](goldens/README.md). The original A–F PNG evidence is unchanged. Test-only comparison output was removed after preserving the review pairs and hashes here.
