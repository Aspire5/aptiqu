# Sound, haptics, PvP arena and celebrations — implementation report

Completed for the user's implementation request on 25 October 2026. No deployment, paid AI calls, database operations or migrations were performed. Login, educational content, question generation, scoring, Elo, XP award formulas and server-owned round transitions are unchanged.

## Implemented behavior

- Practice, Ranked/Unranked PvP and Friendly sessions announce their first **rendered, playable** question with the approved start sound and one medium platform haptic. Loading, matchmaking and Luna preparation stay silent. Covered/background routes, duplicate events and reconnects do not restart this cue.
- Timed sessions tick at most once per displayed second while the current user can answer. Final-ten-second ticks replace normal ticks. Local submission/locking immediately stops ticking; answer explanations and PvP opponent-waiting states stay silent. Untimed Practice never ticks. A definitively failed Practice submission restores ticking from the existing clock. Zero stops ticks and waits for the confirmed outcome.
- Correct/wrong cues use confirmed Practice results or the current participant's closed-round PvP result. ACKs and option taps do not reveal or imply correctness. Response recovery and duplicate/out-of-order events are deduplicated. Confirmed unanswered timeouts use one wrong cue, without another timeout sound.
- Completion uses the neutral cue. A confirmed PvP win uses the victory cue in its place and a finite 3.8-second Flutter avatar/emblem/ray animation. Losses/draws have neutral completion; voids/abandoned Friendly duels have no victory. Normal result statistics and exit controls remain available during the animation. Historical/recovered terminal snapshots stay silent; a later fresh win after reconnecting to an active match can celebrate normally.
- Friendly individual completion stays a waiting state. Only the shared server-confirmed duel winner can produce victory. Practice and the duel room use the same duel receipt, so opening the result room cannot replay a celebration.
- Level-up now fills the captured previous level's real XP fraction to its threshold, pulses/settles the existing avatar once, reveals the real final level and fills the final bar to server-confirmed progress over 1.8 seconds. Coalesced multi-level awards show `+N levels` once. Missing trustworthy snapshots use the simpler final-level transition. Continue works throughout. Reduced motion renders the final state immediately. No level-up vibration is added.
- The existing `SocialOverlay`/`GlobalOverlayGate` still defer level-up during active gameplay, modal interactions, editing and backgrounding. Its sound occurs only when the celebration is actually visible and never overlaps the victory effect lane.
- Profile includes compact Sound effects, Haptic feedback and Timer audio controls after Appearance. Defaults: sound On, haptics On, timer Full (normal volume 0.13, urgent 0.28). Timer choice is saved independently of the master mute. Preferences remain device-local, survive logout and save using the existing secure-storage approach. Ordinary buttons/tabs/options have no added click sounds.

## Arena composition and truthful waiting state

The main reading scroller contains a compact two-player versus header with real avatars/names, public current levels, scores, a VS anchor and separate personal/round status. Native perspective device silhouettes provide layered depth on regular phones. Short-height, narrow and enlarged-text layouts remove the decorative devices and keep the controls scrollable/readable. Existing palette, type roles, questions, answer buttons and Ranked exit policy remain intact.

At local submission, the personal clock freezes at the displayed lock moment and changes to Confirming/Submitted. The opponent side continues the **shared round** countdown, labelled Round time. The message is “Answer locked. Waiting for round to finish…”; it does not claim the opponent has not submitted. A reconnect with a confirmed submission but no known local lock moment shows Submitted without fabricating a time. Only a server transition advances the question.

The previous decrementing visual PvP timer is now anchored to the already available `deadline`/`serverNow` or `remainingMs`, using one monotonic presentation clock and its existing timer callback. Sound does not create another countdown. Delayed frames skip missed seconds, and a duplicate active snapshot cannot increase the remaining time. The server's 60-second deadline, scoring and round-close logic are untouched.

## Exact approved production audio

Only these eight existing approved recordings are bundled, byte-for-byte identical to the remaining review candidates. No rejected file was restored and no replacement/generated audio was added.

| Event | Production file in `assets/audio/feedback/` | Duration |
|---|---|---:|
| First playable question | `session_start_option_a.wav` | 0.290 s |
| Normal tick | `timer_tick_normal_option_a.wav` | 0.045 s |
| Final 10 seconds | `timer_tick_final10_option_a.wav` | 0.055 s |
| Confirmed correct | `answer_correct_option_a.wav` | 0.539 s |
| Confirmed incorrect/timeout | `answer_wrong_option_b.wav` | 0.533 s |
| Neutral completion | `session_complete_option_b.wav` | 1.002 s |
| Confirmed PvP/Friendly victory | `pvp_victory_option_a.wav` | 3.785 s |
| Visible level-up | `level_up_option_a.wav` | 1.387 s |

Original source/licence records are retained in the original [review plan](../sound_haptics_implementation_plan.md). [Production licence notices](../assets/audio/feedback/LICENSE.txt) include Kenney's original notices and source/CC0 credits for Fupi's win jingle. The optional button click remains review-only. The debug APK asset inventory was inspected: it contains exactly these eight WAVs plus the licence notice, and no review/demo/optional clips.

**Measured asset payload:** 673,928 bytes (658.1 KiB, approximately 0.643 MiB), excluding the small text licence. All are mono 44.1 kHz PCM16 WAV.

## Implementation files and ownership

| Files | Responsibility |
|---|---|
| `lib/core/feedback/feedback_cue.dart` | Typed eight-event catalogue, asset mapping and volumes. |
| `lib/core/feedback/app_feedback_service.dart` | Foreground/account/session ownership, settings, deduplication, priority and bounded level-up sequencing. Gameplay never awaits it. |
| `lib/core/feedback/feedback_audio_adapter.dart` | Dedicated testable player/haptic boundary, three fixed players, cached files, silent-mode/focus/session handling, interruption/headphone subscriptions and cleanup. |
| `lib/core/feedback/feedback_preferences.dart` | Serialized, race-safe device preference writes and safe storage-error behavior. |
| `lib/core/feedback/feedback_presentation.dart`, root router | Post-frame current-route visibility; covered or exited routes stop feedback. No audio side effects in build. |
| `lib/core/bindings/initial_binding.dart`, `lib/main.dart` | Global registration and preference loading alongside existing Appearance loading. |
| Practice/PvP catalog and lobby controllers | Asynchronous prewarming during preparation. |
| Practice/PvP session controllers and screens | Semantic playable/tick/lock/confirmed-answer/result integration, recovery guards and presentation state. |
| `lib/features/pvp/views/pvp_versus_arena.dart` | Responsive versus header, real identities and separate personal/shared-round status. Timer rebuilds stay within the header/answer-availability regions. |
| `lib/shared/widgets/feedback/victory_celebration.dart` | One finite native Flutter victory controller and a small 16-ray painter. No overlay that traps input. |
| `lib/features/social/duel_room_screen.dart` | Canonical shared Friendly outcome feedback and result celebration, without replay on history/navigation. |
| XP model/controller and `level_up_overlay.dart` | Immutable presentation snapshots, earliest-before/latest-after coalescing, actual XP animation and safe fallbacks. Snapshots are client presentation data and are not serialized as new awards. |
| Profile screen and `feedback_settings.dart` | Local Sound & Haptics controls, native switches and responsive timer choices. |
| `backend/src/modules/pvp/pvp.dto.ts`, `pvp.socket.ts` | Minimal public **level** metadata from the existing XP policy on matchmaking/recovery identities. Private XP balances/answer details remain outside these player DTOs. No schema change. |
| `pubspec.yaml`, lockfile, generated native plugin registrations, iOS Pods integration | Pin `audioplayers 6.5.1` and `audio_session 0.2.2`, compatible with the project's Flutter 3.35.7. Native plugin wiring and CocoaPods lock/build phases are included. No Flutter SDK upgrade. |
| `docs/FRONTEND_DESIGN_SYSTEM.md` | Permanent feedback, arena and celebration conventions. |

The new dev-only platform-interface dependency is used to test the actual playback adapter against a deterministic native platform fake. It adds no separate production audio engine.

## Verification completed

### Flutter

The complete focused regression command passed **86 tests, zero failures**:

```sh
flutter test --no-pub \
  test/app_feedback_service_test.dart \
  test/feedback_audio_adapter_test.dart \
  test/session_feedback_integration_test.dart \
  test/friendly_feedback_test.dart \
  test/celebration_feedback_test.dart \
  test/feedback_ui_test.dart \
  test/practice_session_test.dart \
  test/pvp_phase_one_test.dart \
  test/xp_level_system_test.dart \
  --reporter expanded
```

After the final tick-player overlap guard and result-emblem cleanup, the affected real-adapter tests passed **3/3** and the UI tests passed **18/18**. The UI capture run used `--dart-define=CAPTURE_FEEDBACK=true`. No unrelated historical UI phase suites were run. The old XP widget assertion was updated to the approved missing-snapshot behavior: show the true final level instead of pretending to know prior XP.

Coverage includes answerable-only ticks; immediate locking silence; normal/urgent replacement; untimed Practice; definitive rejection and lost-response recovery; zero waiting for confirmation; shared question/options; duplicate/out-of-order messages; fresh versus historical reconnects; resumed live wins; truthful recovered submitted status; win/loss/draw/void outcomes; background/mute/route/account ownership; Friendly finalization/navigation deduplication; immutable/coalesced XP; safe overlay deferral; reduced motion; settings persistence; asynchronous failures and player cleanup.

UI coverage renders both themes at 390×844/1×, 320×568/1.3×, 390×844/2× and 568×320/2×. All layouts passed without Flutter layout exceptions. Actual production-font renders were saved and inspected; name wrapping and header height were refined during that review.

### Backend and compilation

- `node --import tsx --test src/modules/pvp/tests/pvp-integrity.test.cjs src/modules/pvp/tests/pvp-socket.test.cjs` — **24 passed**, zero failures. Includes public level/private-balance checks and identical question content for both participants.
- Backend `npm run build` — passed.
- `flutter analyze --no-pub lib` — production code clean.
- Full `flutter analyze --no-pub` was run. It reports one existing unused import at `test/public_showcase_capture_test.dart:20`; that unrelated file is unchanged. No diagnostic introduced by this implementation remains.
- `flutter build apk --debug --no-pub` — passed; not a release/signing/publication action.
- `flutter build ios --simulator --debug --no-codesign --no-pub` — passed; no provisioning or distribution.
- `git diff --check` — passed. Full changes reviewed for scope; login, content, database and generation paths are untouched.

## Resource/performance evidence and limits

**Verified structurally and with tests:** exactly three native players are allocated for the adapter lifetime, not per question/session; 100 simulated rounds retain three event streams and release all three handles at disposal. Normal/urgent ticks stop the opposite source before playback. Effects preempt ticks; ticks are suppressed while an effect is playing. There is one effect lane, so victory and level-up cannot play simultaneously. Position polling is disabled. Audio preparation is asynchronous and failures cannot block gameplay. The service has at most 256 semantic receipts, no persistent tick history and one optional pending level-up timer. Repeated sessions do not add player allocations. Finite victory animation schedules no repeating frames after completion.

**Not measured on physical hardware:** native/process heap delta, real speaker/Bluetooth onset latency, battery cost and sustained frame-time/jank distributions. Widget tests and successful native compilation do not establish these hardware measurements. No claim of a measured FPS or memory ceiling is made.

## Compatibility and remaining manual checks

All requested features are implemented. No release or VPS action was requested or performed. There are no new backend environment variables or migrations for this feature. A normal frontend dependency install/build is needed when distributing the updated app, and the small public-level backend update needs the usual backend build/restart when deployed by the user.

Feedback is intentionally foreground-only. App background/lock/pause stops playback and missed cues/ticks are not replayed. No background audio service, notification permission or microphone permission was added. iOS uses ambient audio to respect the silent switch and mix with other audio. Android uses sonification/ringtone attributes and transient session focus; ringer/DND/headphone behavior remains subject to OS and device policy. Native plugin registration exists for the repository's other generated desktop targets, but desktop/web behavior was not separately built or auditioned.

Before distribution, audition on real Android/iOS hardware: normal speaker; media/ringer volume zero; silent switch/DND; haptics disabled at OS and app level; wired/Bluetooth disconnect/reconnect; incoming call/focus interruption; background/lock/unlock; submit at 12 seconds and wait silently; reduced motion; multi-level award; and rapid route/logout/account switches. These are hardware verification limits, not missing app implementation.

## Actual Flutter screenshots

- [Active arena — Dark](evidence/feedback/arena-active-dark.png) · [Light](evidence/feedback/arena-active-light.png)
- [Submitted/waiting — Dark](evidence/feedback/arena-waiting-dark.png) · [Light](evidence/feedback/arena-waiting-light.png)
- [Victory/results — Dark](evidence/feedback/arena-victory-dark.png) · [Light](evidence/feedback/arena-victory-light.png)
- [Level-up final state — Dark](evidence/feedback/level-up-dark.png) · [Light](evidence/feedback/level-up-light.png)

These are actual Flutter test renders with fixture identities and confirmed fixture result data. The static images show composition and the final state, not the complete timed animation or real device audio/haptics.
