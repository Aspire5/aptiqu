# Phase F rendered evidence

84 actual Flutter widget renders using production font fixtures and safe example data. These are review artifacts, not golden baselines or authenticated device screenshots. See [the manual review guide](../UI_UX_PHASE_F_REVIEW.md) for exact entry paths, published-data prerequisites, interactions and service limitations.

Normal captures are 390×844 at 1× text. Numeric `320` captures are 320×568 at 2× text; `568` captures are 568×320 at 2× text. Completion `large` captures without a numeric suffix are 320×568 at 2×. Daily feedback invitation `large` captures are 568×320 at 2×. Keyboard captures include a 100 px test inset. Reading regions and sheet bodies deliberately scroll; captures show the visible portion, with close/primary controls retained as appropriate.

Representative normal screens in both themes, long question/options and next titles, keyboard layouts, tools/confirmation surfaces, tutor busy/error/unavailable, timed-work invitation entries and final-level layouts were visually inspected. No claim is made that every image was independently inspected or that these fixtures establish native-device/server/accessibility outcomes.

The local server currently returns `STUB_RESPONSE` for tutor requests. `tutor-unavailable` shows the actual client handling of that flag. `tutor-reply` and long replies are deterministic presentation fixtures, not evidence of a live AI integration. Voice and scan remain Coming soon.

| Surface / state | Light | Dark |
|---|---|---|
| completion complete large | [Light](completion-complete-large-light.png) | [Dark](completion-complete-large-dark.png) |
| completion next large | [Light](completion-next-large-light.png) | [Dark](completion-next-large-dark.png) |
| completion unpublished large | [Light](completion-unpublished-large-light.png) | [Dark](completion-unpublished-large-dark.png) |
| daily feedback invitation large | [Light](daily-feedback-invitation-large-light.png) | [Dark](daily-feedback-invitation-large-dark.png) |
| invitation deferred | [Light](invitation-deferred-light.png) | [Dark](invitation-deferred-dark.png) |
| invitation requested | [Light](invitation-requested-light.png) | [Dark](invitation-requested-dark.png) |
| lesson choice | [Light](lesson-choice-light.png) | [Dark](lesson-choice-dark.png) |
| lesson completion | [Light](lesson-completion-light.png) | [Dark](lesson-completion-dark.png) |
| lesson content | [Light](lesson-content-light.png) | [Dark](lesson-content-dark.png) |
| lesson error | [Light](lesson-error-light.png) | [Dark](lesson-error-dark.png) |
| lesson keyboard 320 | [Light](lesson-keyboard-light-320.png) | [Dark](lesson-keyboard-dark-320.png) |
| lesson keyboard 568 | [Light](lesson-keyboard-light-568.png) | [Dark](lesson-keyboard-dark-568.png) |
| lesson options large 320 | [Light](lesson-options-large-light-320.png) | [Dark](lesson-options-large-dark-320.png) |
| lesson options large 568 | [Light](lesson-options-large-light-568.png) | [Dark](lesson-options-large-dark-568.png) |
| lesson question | [Light](lesson-question-light.png) | [Dark](lesson-question-dark.png) |
| lesson question large 320 | [Light](lesson-question-large-light-320.png) | [Dark](lesson-question-large-dark-320.png) |
| lesson question large 568 | [Light](lesson-question-large-light-568.png) | [Dark](lesson-question-large-dark-568.png) |
| lesson submitting | [Light](lesson-submitting-light.png) | [Dark](lesson-submitting-dark.png) |
| lesson text | [Light](lesson-text-light.png) | [Dark](lesson-text-dark.png) |
| lesson tools large 320 | [Light](lesson-tools-large-light-320.png) | [Dark](lesson-tools-large-dark-320.png) |
| lesson tools large 568 | [Light](lesson-tools-large-light-568.png) | [Dark](lesson-tools-large-dark-568.png) |
| lesson unknown large 320 | [Light](lesson-unknown-large-light-320.png) | [Dark](lesson-unknown-large-dark-320.png) |
| lesson unknown large 568 | [Light](lesson-unknown-large-light-568.png) | [Dark](lesson-unknown-large-dark-568.png) |
| level up large 320 | [Light](level-up-large-light-320.png) | [Dark](level-up-large-dark-320.png) |
| level up large 568 | [Light](level-up-large-light-568.png) | [Dark](level-up-large-dark-568.png) |
| level up safe boundary | [Light](level-up-safe-boundary-light.png) | [Dark](level-up-safe-boundary-dark.png) |
| ranked invitation large 320 | [Light](ranked-invitation-large-light-320.png) | [Dark](ranked-invitation-large-dark-320.png) |
| ranked invitation large 568 | [Light](ranked-invitation-large-light-568.png) | [Dark](ranked-invitation-large-dark-568.png) |
| scan large 320 | [Light](scan-large-light-320.png) | [Dark](scan-large-dark-320.png) |
| scan large 568 | [Light](scan-large-light-568.png) | [Dark](scan-large-dark-568.png) |
| tutor busy | [Light](tutor-busy-light.png) | [Dark](tutor-busy-dark.png) |
| tutor error | [Light](tutor-error-light.png) | [Dark](tutor-error-dark.png) |
| tutor keyboard 320 | [Light](tutor-keyboard-light-320.png) | [Dark](tutor-keyboard-dark-320.png) |
| tutor keyboard 568 | [Light](tutor-keyboard-light-568.png) | [Dark](tutor-keyboard-dark-568.png) |
| tutor keyboard reply 320 | [Light](tutor-keyboard-reply-light-320.png) | [Dark](tutor-keyboard-reply-dark-320.png) |
| tutor keyboard reply 568 | [Light](tutor-keyboard-reply-light-568.png) | [Dark](tutor-keyboard-reply-dark-568.png) |
| tutor large 320 | [Light](tutor-large-light-320.png) | [Dark](tutor-large-dark-320.png) |
| tutor large 568 | [Light](tutor-large-light-568.png) | [Dark](tutor-large-dark-568.png) |
| tutor reply | [Light](tutor-reply-light.png) | [Dark](tutor-reply-dark.png) |
| tutor unavailable | [Light](tutor-unavailable-light.png) | [Dark](tutor-unavailable-dark.png) |
| voice large 320 | [Light](voice-large-light-320.png) | [Dark](voice-large-dark-320.png) |
| voice large 568 | [Light](voice-large-light-568.png) | [Dark](voice-large-dark-568.png) |

Regenerate these artifacts without changing golden baselines:

```sh
flutter test --no-pub --dart-define=CAPTURE_PHASE_F=true test/phase_f_routed_global_test.dart
```

All 44 Phase F cases passed in the final full-suite run, which captured this evidence. Existing A–E renders and `test/goldens` are preserved. Root legacy-theme retirement, exhaustive app-wide accessibility/device review and deliberate golden review remain Phase G work.
