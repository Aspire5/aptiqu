# Phase E rendered evidence

103 actual Flutter widget renders using production font fixtures and safe example data. These are review artifacts, not golden baselines or authenticated device screenshots. See [the manual review guide](../UI_UX_PHASE_E_REVIEW.md) for entry paths, prerequisites, expected behavior and limitations.

Normal captures are 390×844 at 1× text. `large-320` is 320×568 at 2× text; `large-568` is 568×320 at 2× text. Picker captures include a 100 px test keyboard inset. Tall rows, reading regions and dialog bodies deliberately scroll; snapshots show only the visible portion. The requests-error landscape fixture is additionally captured in Dark; normal requests and large requests have both themes.

Production fonts, sizes and semantic colors are retained. Representative normal compositions and both themes, enlarged/landscape confirmations, long metrics, keyboard layouts and error/recovery states were visually inspected. No claim is made that every image was independently inspected or that fixtures establish real-device/server/accessibility outcomes.

| Surface / state | Light | Dark |
|---|---|---|
| duel abandoned | [Light](duel-abandoned-light.png) | [Dark](duel-abandoned-dark.png) |
| duel active | [Light](duel-active-light.png) | [Dark](duel-active-dark.png) |
| duel back large 320 | [Light](duel-back-large-light-320.png) | [Dark](duel-back-large-dark-320.png) |
| duel back large 568 | [Light](duel-back-large-light-568.png) | [Dark](duel-back-large-dark-568.png) |
| duel cancelled | [Light](duel-cancelled-light.png) | [Dark](duel-cancelled-dark.png) |
| duel completed | [Light](duel-completed-light.png) | [Dark](duel-completed-dark.png) |
| duel draw | [Light](duel-draw-light.png) | [Dark](duel-draw-dark.png) |
| duel error | [Light](duel-error-light.png) | [Dark](duel-error-dark.png) |
| duel expired | [Light](duel-expired-light.png) | [Dark](duel-expired-dark.png) |
| duel invitation large 320 | [Light](duel-invitation-large-light-320.png) | [Dark](duel-invitation-large-dark-320.png) |
| duel invitation large 568 | [Light](duel-invitation-large-light-568.png) | [Dark](duel-invitation-large-dark-568.png) |
| duel leave | [Light](duel-leave-light.png) | [Dark](duel-leave-dark.png) |
| duel own finished | [Light](duel-own-finished-light.png) | [Dark](duel-own-finished-dark.png) |
| duel recipient | [Light](duel-recipient-light.png) | [Dark](duel-recipient-dark.png) |
| duel rejected | [Light](duel-rejected-light.png) | [Dark](duel-rejected-dark.png) |
| duel requester | [Light](duel-requester-light.png) | [Dark](duel-requester-dark.png) |
| friend picker large 320 | [Light](friend-picker-large-light-320.png) | [Dark](friend-picker-large-dark-320.png) |
| friend picker large 568 | [Light](friend-picker-large-light-568.png) | [Dark](friend-picker-large-dark-568.png) |
| friend requests | [Light](friend-requests-light.png) | [Dark](friend-requests-dark.png) |
| friends | [Light](friends-light.png) | [Dark](friends-dark.png) |
| friends empty | [Light](friends-empty-light.png) | [Dark](friends-empty-dark.png) |
| friends search | [Light](friends-search-light.png) | [Dark](friends-search-dark.png) |
| learner activity | [Light](learner-activity-light.png) | [Dark](learner-activity-dark.png) |
| learner profile | [Light](learner-profile-light.png) | [Dark](learner-profile-dark.png) |
| profile empty | [Light](profile-empty-light.png) | [Dark](profile-empty-dark.png) |
| profile large 320 | [Light](profile-large-light-320.png) | [Dark](profile-large-dark-320.png) |
| profile large 568 | [Light](profile-large-light-568.png) | [Dark](profile-large-dark-568.png) |
| ranked cancelling | [Light](ranked-cancelling-light.png) | [Dark](ranked-cancelling-dark.png) |
| ranked defeat afk | [Light](ranked-defeat-afk-light.png) | [Dark](ranked-defeat-afk-dark.png) |
| ranked feedback | [Light](ranked-feedback-light.png) | [Dark](ranked-feedback-dark.png) |
| ranked history error | [Light](ranked-history-error-light.png) | [Dark](ranked-history-error-dark.png) |
| ranked interruption | [Light](ranked-interruption-light.png) | [Dark](ranked-interruption-dark.png) |
| ranked lobby | [Light](ranked-lobby-light.png) | [Dark](ranked-lobby-dark.png) |
| ranked locked | [Light](ranked-locked-light.png) | [Dark](ranked-locked-dark.png) |
| ranked pending | [Light](ranked-pending-light.png) | [Dark](ranked-pending-dark.png) |
| ranked player | [Light](ranked-player-light.png) | [Dark](ranked-player-dark.png) |
| ranked player large 320 | [Light](ranked-player-large-light-320.png) | [Dark](ranked-player-large-dark-320.png) |
| ranked player large 568 | [Light](ranked-player-large-light-568.png) | [Dark](ranked-player-large-dark-568.png) |
| ranked policy large 320 | [Light](ranked-policy-large-light-320.png) | [Dark](ranked-policy-large-dark-320.png) |
| ranked policy large 568 | [Light](ranked-policy-large-light-568.png) | [Dark](ranked-policy-large-dark-568.png) |
| ranked queue | [Light](ranked-queue-light.png) | [Dark](ranked-queue-dark.png) |
| ranked recovered result | [Light](ranked-recovered-result-light.png) | [Dark](ranked-recovered-result-dark.png) |
| ranked result | [Light](ranked-result-light.png) | [Dark](ranked-result-dark.png) |
| ranked result large 320 | [Light](ranked-result-large-light-320.png) | [Dark](ranked-result-large-dark-320.png) |
| ranked result large 568 | [Light](ranked-result-large-light-568.png) | [Dark](ranked-result-large-dark-568.png) |
| ranked waiting | [Light](ranked-waiting-light.png) | [Dark](ranked-waiting-dark.png) |
| remove friend | [Light](remove-friend-light.png) | [Dark](remove-friend-dark.png) |
| remove large 320 | [Light](remove-large-light-320.png) | [Dark](remove-large-dark-320.png) |
| remove large 568 | [Light](remove-large-light-568.png) | [Dark](remove-large-dark-568.png) |
| requests error large 568 | — | [Dark](requests-error-large-dark-568.png) |
| requests large 320 | [Light](requests-large-light-320.png) | [Dark](requests-large-dark-320.png) |
| requests large 568 | [Light](requests-large-light-568.png) | [Dark](requests-large-dark-568.png) |

Regenerate only these artifacts with:

```sh
flutter test --no-pub --dart-define=CAPTURE_PHASE_E=true test/phase_e_social_competitive_test.dart
```

The 48 cases cover social actions/versions, picker results, busy/expiry, lifecycle/navigation races, month retry/cache, native target labels/sizes, queue acknowledgement, existing replay/reconnect operations, timer/selection restoration, route fallback and live appearance retention. Existing `test/goldens` and all A–D renders are preserved. Global invitation arbitration and the live Ranked Leave/Forfeit product/server policy remain separate work.
