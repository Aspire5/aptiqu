# AptiQu — sound, haptics and level-up animation plan

**Status: review only.** Prepared 24 October 2026. No application code, dependencies, pubspec asset declarations, backend, database or deployment settings have been changed. The deliverables are this single Markdown plan and the requested review audio folder.

**Review folder:** [docs/sound_haptics_review/audio](/Users/shagunkumar/Desktop/aptiqu/docs/sound_haptics_review/audio).

## 1. Requirements from your request

1. Make AptiQu feel more alive at meaningful moments, without filling the app with sounds or repeated vibration.
2. After a long Practice/PvP preparation, attract attention **when the first question is actually playable**: one short sound accompanied by one phone haptic. Merely joining a queue, finding an opponent or receiving a preparation response is too early.
3. If the question timer is on, play quiet clock-like ticks. Emphasize the **last ten seconds**, potentially using a short reverberant/echo character.
4. Play a distinct positive ding for a correct answer and a gentle negative cue for a wrong answer. A timer reaching zero must not cause the client to invent correctness. “Ding” is interpreted as a sound, not a new ten-point/XP award.
5. Indicate session/match completion. A confirmed PvP win should have a short **three-to-four-second celebration**.
6. Replace the current plain level-up dialog appearance with a more celebratory Flutter animation: XP bar fills, identity/avatar expands and settles, and the new level becomes clear. Add a short level-up sound; level-up vibration is optional because you explicitly raised concern about too much vibration.
7. Advise whether button-click sounds or other app events merit feedback. Avoid adding sounds merely because an interaction exists.
8. Find and download reviewable sound choices, using filenames that clearly identify their event. Provide alternatives where useful, source/licence details and an exact mapping in this plan.
9. Keep the future implementation light: no gameplay lag, unnecessary memory retention, background noise or heavy animation machinery.
10. Produce a complete plan for review; **do not implement the feature now**.

## 2. Recommended experience

Use **sound to communicate a change**, and haptics sparingly to attract attention. My recommended first release is Practice, Ranked/unranked PvP, friendly duels and the global level-up celebration. Keep the existing visual feedback available with sound and vibration off.

| Moment | Sound | Haptic | Exact trigger / restriction |
| --- | --- | --- | --- |
| Queue/preparation starts | None | None | No loop or repeated loading beep while Luna works. |
| First playable question of a fresh session | One short start cue | One medium-impact request | Valid current question + active/playable state + first rendered frame; once per session, timed or untimed. |
| Later question begins | None | None | The question transition is already visible. No new vibration for every round. |
| Timer running, more than ten seconds left | Quiet normal tick, once per displayed second | None | Only while this user can still answer and timer/audio preferences permit it. |
| Final ten seconds | Replace normal tick with the urgent tick | None | Keep one tick per second. A brighter/short-tail variant adds emphasis; do not stack both ticks. |
| Answer submitted, outcome still pending | Stop this user's ticks | None | Do not announce correct/wrong based on the selected option or submission ACK. |
| Confirmed correct answer | Positive ding | None by default | Solo Practice: accepted server result. PvP: closed-round result for this participant. |
| Confirmed wrong answer / unanswered timeout | Short gentle negative cue | None by default | One cue for the confirmed outcome, not a timeout sound followed by another wrong sound. |
| Practice completed | Short neutral completion cue | None | Completion/result surface becomes visible after a confirmed completed session. |
| PvP win | Three-to-four-second victory cue | None by default | Server-confirmed winner, valid completed result; replaces the neutral completion cue. |
| PvP loss/draw | Neutral completion cue | None | No mocking defeat horn or punitive vibration. |
| System void, cancellation, failed generation | No celebration | None | Preserve the actual error/cancelled state; do not sound like a completed or won match. |
| Level-up presentation becomes visible | Short level-up cue | Optional light tap; recommend off initially | Use the existing safe presentation gate, not the XP network callback. |
| Ordinary button/navigation tap | None | Existing native behavior only | Do not add a custom click to every button, tab or answer-option selection. |

**Recommended defaults for review:** sound effects on; start haptic on; timer audio **Full** at low volume to match your request; level-up haptic off. Offer a quieter “Last 10 seconds” timer mode. These are proposed defaults, not changes already applied.

### Why I recommend quiet buttons

The important sounds lose meaning if every tap produces another sound. Typing, hints, scrolling, tabs and retries are frequent. Custom clicks also become tiring in a study app and can conflict with native feedback. I downloaded one optional click so you can hear the idea, but recommend leaving it out of the first release.

### Other worthwhile places — suggestions, not automatic scope

- **Daily Challenge:** the same confirmed-answer and completion cues could later give it consistent behavior. No new sound family is needed.
- **Lesson/subtopic genuinely completed:** one short success cue could mark the milestone. Avoid playing it for every chat bubble, hint or tutor message.
- **Achievements:** consider only meaningful new unlocks, queued behind game results and level-ups. Do not stack an achievement jingle, victory jingle and level-up sound together.
- **Friend invitations:** keep current visual notices initially. A new invitation sound while solving a timed question would be distracting. Match-start attention already covers an accepted duel when play actually begins.
- **Loading progress, network failures, wrong password, every XP increment, every option selection:** keep quiet in this release. Error text/semantics remain the reliable channel.

## 3. Audio files you can review now

There are **18 WAV files**, approximately **2.46 MiB total**, including the 15-second demonstration. A complete A-choice production set of eight event sounds is **587,180 bytes, approximately 0.56 MiB** before packaging. Alternatives and the demo are for review, not automatically shipped assets.

All review files are mono, 44.1 kHz, 16-bit PCM WAV for straightforward desktop/mobile playback. Original sources were downloaded first, then converted locally. Peaks were lowered/normalized for headroom: ordinary cues/jingles to −9 dBFS, wrong/urgent ticks to −12 dBFS, normal ticks/optional click to −15 dBFS. This is peak normalization, not a claim of equal perceived loudness. Future app volume gains are separate.

**Screening limitation:** licences/source listings, decoding, duration, format and signal levels were checked. I have not performed a listening audition on a physical phone or claimed that one timbre is objectively better. The A set is a practical starting shortlist based on event family and duration; your listening review determines the final choices.

Play the files using their links or Finder/your audio player. The filename is the event mapping. No extra sound uploads are required from you unless you dislike these choices or want a custom brand sound.

| Event | Review file | Length | Size | Original source item / treatment |
| --- | --- | ---: | ---: | --- |
| Session start | [session_start_option_a.wav](/Users/shagunkumar/Desktop/aptiqu/docs/sound_haptics_review/audio/session_start_option_a.wav) | 0.290 s | 25.0 KiB | Kenney Interface Sounds: `Audio/confirmation_001.ogg` |
| Session start | [session_start_option_b.wav](/Users/shagunkumar/Desktop/aptiqu/docs/sound_haptics_review/audio/session_start_option_b.wav) | 0.322 s | 27.8 KiB | Kenney Interface Sounds: `Audio/confirmation_003.ogg` |
| Normal timer tick | [timer_tick_normal_option_a.wav](/Users/shagunkumar/Desktop/aptiqu/docs/sound_haptics_review/audio/timer_tick_normal_option_a.wav) | 0.045 s | 3.9 KiB | Kenney Interface Sounds: `Audio/tick_001.ogg` |
| Normal timer tick | [timer_tick_normal_option_b.wav](/Users/shagunkumar/Desktop/aptiqu/docs/sound_haptics_review/audio/timer_tick_normal_option_b.wav) | 0.020 s | 1.8 KiB | Kenney Interface Sounds: `Audio/tick_002.ogg` |
| Final-ten-seconds tick | [timer_tick_final10_option_a.wav](/Users/shagunkumar/Desktop/aptiqu/docs/sound_haptics_review/audio/timer_tick_final10_option_a.wav) | 0.055 s | 4.8 KiB | Kenney Interface Sounds: `Audio/tick_004.ogg` |
| Final-ten-seconds tick | [timer_tick_final10_option_b_short_echo.wav](/Users/shagunkumar/Desktop/aptiqu/docs/sound_haptics_review/audio/timer_tick_final10_option_b_short_echo.wav) | 0.080 s | 7.0 KiB | Kenney Interface Sounds: `Audio/tick_002.ogg`; short 60 ms echo added |
| Correct answer | [answer_correct_option_a.wav](/Users/shagunkumar/Desktop/aptiqu/docs/sound_haptics_review/audio/answer_correct_option_a.wav) | 0.539 s | 46.5 KiB | Kenney Interface Sounds: `Audio/confirmation_002.ogg` |
| Correct answer | [answer_correct_option_b.wav](/Users/shagunkumar/Desktop/aptiqu/docs/sound_haptics_review/audio/answer_correct_option_b.wav) | 0.490 s | 42.3 KiB | Kenney Interface Sounds: `Audio/confirmation_004.ogg` |
| Wrong answer / confirmed timeout | [answer_wrong_option_a.wav](/Users/shagunkumar/Desktop/aptiqu/docs/sound_haptics_review/audio/answer_wrong_option_a.wav) | 0.162 s | 14.0 KiB | Kenney Interface Sounds: `Audio/error_001.ogg` |
| Wrong answer / confirmed timeout | [answer_wrong_option_b.wav](/Users/shagunkumar/Desktop/aptiqu/docs/sound_haptics_review/audio/answer_wrong_option_b.wav) | 0.533 s | 46.0 KiB | Kenney Interface Sounds: `Audio/error_003.ogg` |
| Session complete / neutral PvP result | [session_complete_option_a.wav](/Users/shagunkumar/Desktop/aptiqu/docs/sound_haptics_review/audio/session_complete_option_a.wav) | 0.391 s | 33.7 KiB | Kenney Music Jingles: `Audio/Sax jingles/jingles_SAX00.ogg` |
| Session complete / neutral PvP result | [session_complete_option_b.wav](/Users/shagunkumar/Desktop/aptiqu/docs/sound_haptics_review/audio/session_complete_option_b.wav) | 1.002 s | 86.4 KiB | Kenney Music Jingles: `Audio/Pizzicato jingles/jingles_PIZZI01.ogg` |
| PvP victory | [pvp_victory_option_a.wav](/Users/shagunkumar/Desktop/aptiqu/docs/sound_haptics_review/audio/pvp_victory_option_a.wav) | 3.785 s | 326.0 KiB | Fupi / OpenGameArt: `winfretless_0.ogg` |
| PvP victory | [pvp_victory_option_b_tempo_adapted.wav](/Users/shagunkumar/Desktop/aptiqu/docs/sound_haptics_review/audio/pvp_victory_option_b_tempo_adapted.wav) | 3.781 s | 325.7 KiB | celestialghost8 / OpenGameArt: `Victory.wav`; tempo adapted from 4.88 s, pitch-preserving |
| Level up | [level_up_option_a.wav](/Users/shagunkumar/Desktop/aptiqu/docs/sound_haptics_review/audio/level_up_option_a.wav) | 1.387 s | 119.5 KiB | Kenney Music Jingles: `Audio/Steel jingles/jingles_STEEL02.ogg` |
| Level up | [level_up_option_b.wav](/Users/shagunkumar/Desktop/aptiqu/docs/sound_haptics_review/audio/level_up_option_b.wav) | 1.324 s | 114.1 KiB | Kenney Music Jingles: `Audio/Pizzicato jingles/jingles_PIZZI07.ogg` |
| Optional button click, not proposed by default | [button_click_optional_not_recommended.wav](/Users/shagunkumar/Desktop/aptiqu/docs/sound_haptics_review/audio/button_click_optional_not_recommended.wav) | 0.053 s | 4.6 KiB | Kenney UI Audio: `Audio/click2.ogg` |
| Review-only timer demo | [preview_timer_5s_normal_then_10s_final.wav](/Users/shagunkumar/Desktop/aptiqu/docs/sound_haptics_review/audio/preview_timer_5s_normal_then_10s_final.wav) | 15.000 s | 1292.0 KiB | Review demonstration: `normal A + final10 A at one tick per second`; demo only, not an app asset |

### Source and licence record

Downloaded on 24 October 2026 from the original asset pages:

| Source / author | Declaration checked | Download used |
| --- | --- | --- |
| [Interface Sounds — Kenney](https://kenney.nl/assets/interface-sounds) | CC0 on the pack page and in the downloaded `License.txt` | [Official ZIP](https://kenney.nl/media/pages/assets/interface-sounds/fa43c1dd4d-1677589452/kenney_interface-sounds.zip) |
| [Music Jingles — Kenney](https://kenney.nl/assets/music-jingles) | CC0 on the pack page and in the downloaded `License.txt` | [Official ZIP](https://kenney.nl/media/pages/assets/music-jingles/f37e530b9e-1677590399/kenney_music-jingles.zip) |
| [UI Audio — Kenney](https://kenney.nl/assets/ui-audio) | CC0 on the pack page and in the downloaded `License.txt` | [Official ZIP](https://kenney.nl/media/pages/assets/ui-audio/490d233f68-1677590494/kenney_ui-audio.zip) |
| [Win Jingle — Fupi](https://opengameart.org/content/win-jingle) | CC0 on the individual submission | [Original OGG](https://opengameart.org/sites/default/files/winfretless_0.ogg) |
| [Victory — celestialghost8](https://opengameart.org/content/victory) | CC0 on the individual submission | [Original WAV](https://opengameart.org/sites/default/files/Victory.wav) |

Kenney's downloaded licences expressly allow personal/commercial use and make credit optional. Retain this source record; optional release credits can name Kenney, Fupi and celestialghost8. The OpenGameArt licence check was per submission, not an assumption about every sound on that website. No paid packs, login-only sources, extracted commercial-game sounds or AI audio generation were used.

**Local edits are explicit:** all files were converted/downmixed and peak-normalized; urgent option B adds a short echo; victory option B speeds the original 4.88-second cue to approximately 3.78 seconds without intentional pitch shifting. Victory A retains the original musical duration. The 15-second timer preview was assembled from the A ticks, at one tick per second; it is a listening demonstration, not a timer implementation. It contains no timeout/result cue because that outcome is separate.

Choose one option per main event; all A choices form the starting shortlist. You can mix A/B selections. Keep the optional button file and timer preview out of a production bundle unless explicitly chosen for a deliberate purpose.

## 4. What the current app actually does

The repository was inspected before writing this plan:

- `pubspec.yaml` currently has **no audio playback dependency** and no declared audio asset directory. The source scan found no existing app feedback service or custom haptic/audio calls to reuse.
- Practice's `PracticeSessionController.begin()` has a short readiness transition. `_startQuestionClock()` starts its stopwatch; friendly sessions first obtain their server-owned remaining time. `_runCountdown()` checks every 250 ms but changes the visible whole-second value only when it changes.
- Practice locks/submits the answer, stops its clock, then receives `lastResult`. A lost acknowledgement can restore an already-answered question through `getSession()`. Those two paths must produce the same single feedback event.
- Practice's `finishSession()` controls the completed presentation and applies the existing XP result. Its animation/audio must not award XP again.
- PvP's `PvpArenaController` handles `QUESTION_STARTED`, `ANSWER_ACCEPTED`, `QUESTION_ENDED`, `MATCH_COMPLETED` and recovered snapshots. A socket ACK confirms submission, not correctness. Closed-round `scores` entries identify this participant's `isCorrect` result.
- PvP start messages already contain `deadline` and `serverNow`. The current fresh-event handler uses a local one-second display countdown; recovery restores `remainingMs`. New sound timing must not create a second, competing game clock or reset the existing deadline.
- A friendly duel is not finally complete merely because this player finished their ten questions. Its shared server state must confirm both players/results before a match-end or victory cue.
- `LevelUpOverlay` is currently a bounded native dialog with a 300 ms animation controller. It changes the displayed level but does not animate an XP fill or avatar pulse. Your description of the missing richer celebration matches the current implementation gap.
- `XpController` already owns actual progression, suppresses repeated level celebrations and coalesces pending level-ups. `SocialOverlay` and `GlobalOverlayGate` defer celebrations while a task, modal or editing interaction is active and while the app is not foregrounded.
- Profile currently places Appearance immediately below identity. Feedback settings should follow that area as a compact group, preserving existing composition, palette, fonts, sizes and 48 px controls.

## 5. Exact trigger rules and collision policy

### 5.1 Session-start attention

A session being **ready on the server** and a question being **playable on this screen** are different events.

1. While the existing preparation UI is visible, asynchronously warm the selected local start/timer/answer assets. Do not delay the network request or require audio to load before gameplay proceeds.
2. Wait for a valid current question, active/playable state and the first frame showing it. Use the actual Practice/friendly clock-ready boundary or PvP `QUESTION_STARTED`/active snapshot; not queue, MATCH_FOUND, navigation push, `202` or PREPARATION_READY alone.
3. Send one semantic `sessionStarted` feedback event with owner/session/first-question identity. Dispatch the short sound and one `HapticFeedback.mediumImpact()` request together, on a best-effort basis. Do not invent a fixed vibration length or guarantee identical hardware intensity. Flutter's API delegates to platform behavior. [Flutter haptic API](https://api.flutter.dev/flutter/services/HapticFeedback-class.html)
4. If the session is untimed, still emit the start attention cue, then remain clock-silent.
5. Do not repeat this attention cue at each of the next nine questions, on widget rebuild, duplicate socket message, reconnect or restoring a session whose start was already consumed.
6. If the very first question arrives through recovery while the user is still attached to this **fresh pending preparation**, a missing start receipt may allow that first attention cue. Opening old history or resuming an already-started match is not a new start.
7. If audio is unavailable or too late, skip it rather than playing “start” over an answer/result. Haptic and visual state remain independent; audio failure never postpones the real clock.

Speaker/Bluetooth audio and physical haptics cannot be guaranteed sample-synchronous. The goal is one coherent attention moment, not a promise of zero latency.

### 5.2 Timer sound

- Bind sound to the **existing current question's remaining whole seconds and answerability**. Never run an independent 60-second audio countdown or play a looping 60-second recording.
- Emit the first normal tick at the next meaningful whole-second transition, not another beep at the same instant as the start cue.
- Normal tick for remaining seconds **59 through 11**; urgent tick for **10 through 1**. At zero: stop ticking. A shorter restored budget starts from its actual value.
- A 250 ms Practice timer callback must not generate four sounds per second. Track question identity and the last handled second. At most one tick per second per question; no backlog of skipped ticks after a frame stall or foreground resume.
- Keep urgent cadence at one per second initially. Emphasis comes from timbre, a modest level difference and optionally the supplied 60 ms echo variant. Do not add an alarm, accelerate to a frantic beat, run live reverb DSP or vibrate for every tick.
- Stop ticks immediately on answer submission/lock, transition, zero, completion, route exit, mute, lost question ownership or inactive/background state. In PvP this user's ticks stop after submission even while the opponent is still answering; do not alter the game's visible/server countdown to achieve that.
- A failed Practice submission that is confirmed **not committed** can resume ticks at the actual remaining budget. A recovered committed answer stays quiet until/through its single confirmed-result cue.
- On reconnect, derive remaining time from the existing authoritative snapshot/deadline. Skip missed seconds and suppress any repeated seconds caused by a correction. Do not restart a 60-second interval or sound a fresh “ten seconds” alarm after resuming at seven.

If implementation discovers drift between fresh PvP display timing and its already-supplied server deadline, resolve it within the existing clock contract and verify scoring is unchanged. The feedback service itself never owns deadlines, response time, timeout submission or match transitions.

### 5.3 Correct, wrong and timeout

**Solo Practice:** play the cue when the accepted `PracticeAnswerResultModel` is reflected in feedback, including its acknowledgement-recovery path. Clicking an option is not evidence of correctness.

**PvP:** play only after `QUESTION_ENDED` or equivalent newly accepted closed-round state. Use the current participant's result, never an opponent's score change or the submission ACK. Avoid revealing correctness early while another player can still answer.

**Timeout:** reaching visual zero stops ticks. Wait for the actual accepted timeout/closed-round outcome. A confirmed unanswered timeout can use the same gentle wrong cue and the existing “Time's up” visual explanation. Do not play both timeout and wrong noises. A delayed correct response that the server accepted still gets the correct cue, even if the local display reached zero before its response arrived.

No extra score/XP, client answer evaluation, new grading rules or louder punishment for a wrong answer is proposed.

### 5.4 Completion, victory and level-up sequencing

- At a confirmed completed result, play **one** terminal cue: victory if the current player won, otherwise neutral completion. Victory replaces the neutral completion sound.
- A void/cancelled/abandoned result is not a win, draw or ordinary completed match. No celebratory cue is played for it.
- The final answer cue can finish before the terminal cue. Use a bounded quiet gap (roughly 150–250 ms if both events arrive together), not an unbounded audio queue. Existing result UI need not wait for that gap.
- A level-up can be earned during completion, but its **sound follows its visible celebration**, after task/overlay safety and any result cue. Never play it invisibly when XP arrives during a timed question.
- A user who immediately starts another task preempts or drops cosmetic audio. Do not delay gameplay to complete a fanfare.
- A friendly duel uses server-confirmed shared completion/winner, not only this player's Practice completion flag. Its canonical feedback identity is the **friendlyDuelId**, shared by both Practice sessions; do not key its terminal cue independently by each session ID. Early individual finish remains a waiting/results state.
- Opening an old completed match, static history or already-completed Practice screen remains silent. Interactive replay can use normal answer/timer feedback when explicitly played; it never earns or fabricates a level-up/victory reward. A special waiting-for-generation start alert is unnecessary for ordinary history replay.

Priority: **current playable session/clock validity → confirmed answer → terminal result → visible level-up → optional previews/cosmetics**. Ordinary button sounds are absent. Stop/preempt lower-priority work rather than layering multiple jingles.

## 6. Richer level-up presentation

Keep the existing root overlay ownership and safe scheduling. Replace the plain dialog **appearance** with a branded celebration surface: actual learner avatar, approved accent ring, large new-level identity, an animated XP bar and a clear Continue action. Keeping a `DialogRoute` internally is useful for focus/navigation; it does not require retaining today's simple native dialog composition.

### Proposed finite sequence, approximately 1.6–1.9 seconds

| Phase | Visual behavior | Sound / data rule |
| --- | --- | --- |
| Entry, about 0–200 ms | Small fade/settle of the celebration surface; identity is readable immediately. | Start the selected short level-up cue when the surface is visible, once. |
| Earned progress, about 200–850 ms | Fill the old-level bar from the **captured pre-award fraction** to its completed boundary. | Keep old-level labeling with that bar; do not rewind the actual global XP state. |
| Level transition, about 850–1150 ms | Avatar/ring expands to around 1.06–1.08 scale and settles once; update the displayed level. | Optional single light haptic at the transition only if explicitly chosen. No repeating “heartbeat.” |
| New progress, about 1150–1750 ms | Reset the presentation bar for the new level, then fill to the **server-confirmed new fraction**. | Show the real final level/progress; no locally invented XP. |
| Rest | Stable final identity and Continue. | No looping pulse, music or automatic replay. Continue remains usable throughout. |

`LevelUpModel` currently has from/to/count but no previous XP fraction. Capture an immutable **presentation snapshot** in `XpController.handleXpUpdate()` before replacing progression, and pass it through the pending celebration. Keep backend progression models/formulas unchanged. If trustworthy previous progress is absent, use an honest simpler new-level reveal and final-progress animation; do not invent an old fill.

If several levels are gained together, preserve current coalescing: one presentation to the actual final level, with “+N levels” where useful. Do not manufacture intermediate thresholds or queue one modal/sound per level.

Implementation uses one finite Flutter `AnimationController`, bounded tweens, localized `AnimatedBuilder`/`ScaleTransition`, a small progress painter/indicator and an avatar `RepaintBoundary`. Reuse the existing avatar image/provider; do not reload it during the pulse. Avoid a new Lottie/Rive/video dependency, live particles across the whole screen, animated blur and per-frame root rebuilds. Flutter recommends keeping animation rebuilds localized and avoiding unnecessary expensive layers. [Flutter performance guidance](https://docs.flutter.dev/perf/best-practices)

Reduced motion shows the final state immediately (or a minimal approved fade), without the fill/pulse. Audio and haptics remain independently controlled; reduced motion is not treated as consent to change sound preferences. Screen readers announce the level change once, not every progress frame. Use actual width/text scale with a scrollable body and reachable 48 px Continue; preserve existing palette/type roles and small-screen accessibility.

The current safe gate normally waits until the session/result route has been left. Preserve that boundary initially. Showing a level-up on top of a still-open result screen would need a deliberate “result is safe” presentation contract; do not simply bypass `GlobalOverlayGate`.

## 7. Lightweight frontend implementation approach

### One shared feedback service, not sounds scattered across widgets

Propose `AppFeedbackService` with a small typed cue catalogue, device preferences, a native audio adapter and lifecycle/route ownership. Feature controllers send semantic events with identities/origin; the service decides whether to play, skip, preempt or deduplicate. Widgets never start playback from `build()`.

An event carries only what is needed: owner/account, session/match ID, question identity/index when relevant, event type, current presentation scope and whether it is a fresh event/recovery/history. No new backend requests, answer payloads, server-side sound generation, database settings or migrations are required.

### Playback dependency and platform policy

Propose a compatible locked release of **audioplayers** (the listing checked for this plan is 6.8.1). It supports the app's mobile platforms and local assets. No dependency is added in this task. Validate the chosen version against the repository's actual Flutter/Dart/Android/iOS build targets before locking it. [Package source/documentation](https://pub.dev/packages/audioplayers)

Use preloaded `AudioPool` instances for repeated short assets and a bounded catalogue/adapter for the longer cues. Its API prepares players with an asset; do not assume a pool's `maxPlayers` alone imposes the app's global concurrency limit. Enforce that limit in our service. [AudioPool API](https://pub.dev/documentation/audioplayers/latest/audioplayers/AudioPool-class.html), [start/cleanup implementation](https://pub.dev/documentation/audioplayers/latest/audioplayers/AudioPool/start.html)

**Default mode: prepared `PlayerMode.mediaPlayer`**, with silence-respecting context. Do not blindly select Android low-latency mode: the maintainer's parity table lists silence-respect limitations there, and low-latency is not available on every platform. Only consider it after device validation and an explicit platform policy; do not trade away silent-mode behavior to shave a few milliseconds. [Maintainer feature table](https://github.com/bluefireteam/audioplayers/blob/main/feature_parity_table.md)

Explicitly configure the equivalent of `AudioContextConfig(respectSilence: true, focus: mixWithOthers, stayAwake: false, route: system)`, rather than taking the library's gain/playback defaults. Keep system output routing, media volume, headphones and other apps' audio under user control. Do not use alarm/notification audio streams, force a speaker route, change system volume, or repeatedly duck someone's music for clock ticks. Platform behavior is verified on devices, not assumed from a generic flag. [Audio context API](https://pub.dev/documentation/audioplayers/latest/audioplayers/AudioContextConfig-class.html), [focus options](https://pub.dev/documentation/audioplayers/latest/audioplayers/AudioContextConfigFocus.html)

Handle platform interruptions and app lifecycle centrally. If the selected player version does not expose an interruption/noisy-output hook needed for reliable phone-call/headphone behavior, add a small `audio_session` adapter after checking its compatibility during implementation; do not silently ship that gap or introduce a heavy audio engine. The optional adapter has documented interruption and unplugged-headphone streams; configure the shared iOS session consistently after player initialization. No microphone, background-audio or notification permission is needed for the foreground feature proposed here. [Audio-session documentation](https://pub.dev/packages/audio_session)

### Explicit resource limits

- Bundle only the final **eight** chosen cues. The optional click, all rejected alternatives and the 15-second review demo stay in `docs`, outside pubspec.
- Start with the selected mono PCM files: the A set is only 0.56 MiB and avoids an unnecessary conversion decision now. Compressed files save bundle bytes but expand when decoded; measure the actual tradeoff rather than assuming small downloads mean small runtime memory.
- Load small preference data once through existing local storage. If preferences have not finished restoring, suppress feedback until known; do not briefly ignore a saved mute setting.
- Create the service once; warm resources lazily when the user starts a session/preparation, not as a blocking app-launch task. Never decode/read a sound for every timer tick.
- **Hard playback budget:** at most one tick voice plus one event voice; a higher-priority event stops or ducks the tick, and two victory/level-up jingles never overlap. Guard the service before asking a pool for another player.
- **Hard resident-player budget:** at most six prepared players, one per resident asset. Prepare start/tick/answer cues while waiting; release the start player after its one use; prepare terminal cues near the final question. Load level-up only when its safe presentation is imminent. Evict inactive assets by a small bounded LRU when needed.
- Cache only the selected finite catalogue; no pool/player per widget, every question or every network event. Dispose stop handles/subscriptions/players on eviction, logout/scope reset and memory pressure.
- Completion callbacks release active voices. Keep a short duration-based watchdog to clean up a missing native callback; if low-latency mode is ever enabled, its explicit stop/dispose obligation must be implemented. No endlessly retained “current player” per tick.
- Use the existing timer signal; **zero additional timer polling loops** for audio. Only brief bounded cue cleanup/sequence timers are allowed. Every queued callback carries a generation token and is discarded if its question/route/preferences are stale.
- Playback/preload exceptions are caught and cosmetic work is skipped. Never await sound playback, preloading or animation completion in answer submission, timer start, match admission, scoring or XP updates.
- No live reverb, synthesis, 60-second background track, sound streaming or extra API/AI calls. The urgent echo is already rendered into one tiny review clip.

### Profiling targets — proposed budgets, not measured claims

| Measure | Initial acceptance target |
| --- | --- |
| Selected audio bytes | Under 1 MiB for the A set; measured 0.56 MiB before packaging. |
| Additional prepared audio/player memory | Aim below 15 MiB on representative mobile devices; measure native/process memory too, not only Dart heap. Reduce residency if exceeded. |
| Steady-state memory | No upward player/subscription growth after 20 sessions or 100 repeated round transitions. |
| Warm speaker cue dispatch | Aim for audible onset within about 100 ms of the eligible event; Bluetooth transport is reported separately. |
| Frames | No new sustained jank or material p95 build/raster regression in profile-mode comparison on a lower-end device. Respect the device's refresh-frame budget. |
| Gameplay correctness | No change to server deadlines, score, XP, answer locking, submission order or results when sound is disabled/fails. |

Zero latency or zero memory cost would be an unrealistic promise. The design removes feedback work from the gameplay critical path and makes overhead bounded and measurable.

## 8. Preferences, lifecycle and event receipts

### Profile settings

Add a compact **Sound & haptics** group after Appearance:

- Sound effects: on/off.
- Haptic feedback: on/off, independent of the sound switch.
- Timer audio: Off / Last 10 seconds / Full. Disable its control when sound is off, but retain the chosen value.
- Optional explicit “Preview start cue” action; no autoplay on opening Profile or toggling a control.

Persist locally per device; cross-device sync is outside scope and needs no database work. Use existing approved controls/type roles and 48 px targets. System silence and accessibility behavior remain authoritative. All visual/timing/result cues remain functional when feedback is muted or hardware is unsupported.

### Foreground-only first release

The service plays only when the app is resumed and the relevant session/celebration is visible. Inactive/hidden/paused/detached, route exit, account switch, loss of session ownership, mute or interruption stops audio and invalidates pending callbacks. Resume uses current state; no burst of missed ticks, old result fanfare or replayed start vibration.

This intentionally does **not** promise an alert when the phone is locked or the user has switched to another app. Reliable background-ready notification would require a separate notification/delivery design, permissions and possibly backend support. It must not be approximated with a perpetual background audio service or by changing Ranked's timed-disconnect rules.

### Deduplication and ordering

- Start key: owner + session ID + start.
- Answer key: owner + session ID + question ID/index, consumed only after a confirmed answer outcome. Correctness chooses the clip; it is not another key component. Fresh response and recovered acknowledgement share this identity.
- Completion key: owner + match/session ID + terminal result/settlement identity, where supplied. A later XP refresh or `stateVersion` bump is not another completion.
- Level-up key: owner + actual final level, tied to the visible coalesced presentation. Refreshing the profile or reconstructing widgets is not a new earned event.
- Tick tracking is transient and bounded to the active question's handled seconds. Never persist every tick.
- Maintain a small in-memory semantic receipt cache and a bounded local terminal/start receipt record (for example, last 64 identities per owner). Reset active scopes on account change; do not let old callbacks vibrate for the next account.
- Mark an event consumed before dispatch; persist cosmetic receipts best-effort without blocking the game. Suppress stale/history origins even if a stored receipt is unavailable. Do not claim physically exact-once delivery across a process crash; prefer dropping a stale cosmetic cue over repeating a result celebration.
- A level-up earned during a match keeps current pending/coalescing behavior. Play its cue only when `SocialOverlay` actually presents it and a result jingle no longer owns the event channel. Continue never waits for audio.

## 9. Proposed files and changes during implementation

All paths are under `/Users/shagunkumar/Desktop/aptiqu`. Existing files are links; new files are proposals only.

| File / area | Future change |
| --- | --- |
| `lib/core/feedback/app_feedback_service.dart` — new | Central semantic feedback, ownership, priority, receipts, lifecycle, preload/cleanup and bounded voice scheduling. |
| `lib/core/feedback/feedback_audio_backend.dart` — new | Testable adapter around the selected local audio plugin; resource accounting, context, stop handles and failure isolation. |
| `lib/core/feedback/feedback_cues.dart` — new | Typed cue catalogue, chosen production paths, measured durations, relative gain/priority and preload groups. |
| `lib/core/feedback/feedback_preferences_controller.dart` — new | Local device settings and loading/mute state; no backend profile fields. |
| [initial_binding.dart](/Users/shagunkumar/Desktop/aptiqu/lib/core/bindings/initial_binding.dart) | Register one feedback/preferences owner. Keep initialization asynchronous and off the gameplay critical path. |
| [main.dart](/Users/shagunkumar/Desktop/aptiqu/lib/main.dart) and routing observer integration | Minimal lifecycle/visible-scope wiring if not wholly contained in the service. No new app wrapper that rebuilds on each tick. |
| [practice_catalog_controller.dart](/Users/shagunkumar/Desktop/aptiqu/lib/features/practice/controllers/practice_catalog_controller.dart) | Start preload in parallel with preparation; cancellation invalidates only cosmetic work. No loading beeps. |
| [practice_session_controller.dart](/Users/shagunkumar/Desktop/aptiqu/lib/features/practice/controllers/practice_session_controller.dart) | Emit real readiness, unique second, locked/submitted, confirmed answer, completed and leave events. Share fresh/recovered-answer identity. |
| [practice_session_screen.dart](/Users/shagunkumar/Desktop/aptiqu/lib/features/practice/views/practice_session_screen.dart) | First-frame visibility acknowledgement, not playback in `build`; keep existing answer/clock semantics. |
| [pvp_lobby_controller.dart](/Users/shagunkumar/Desktop/aptiqu/lib/features/pvp/controllers/pvp_lobby_controller.dart) | Preload while waiting and retain fresh-preparation identity across match opening/reconnect; never sound merely at MATCH_FOUND. |
| [pvp_arena_controller.dart](/Users/shagunkumar/Desktop/aptiqu/lib/features/pvp/controllers/pvp_arena_controller.dart) | Route confirmed question/round/result events to feedback; use this participant's correctness; suppress duplicates, history, voids and stale snapshots. |
| [pvp_arena_screen.dart](/Users/shagunkumar/Desktop/aptiqu/lib/features/pvp/views/pvp_arena_screen.dart) | Supply actual question/result visibility and current presentation scope. |
| [duel_room_screen.dart](/Users/shagunkumar/Desktop/aptiqu/lib/features/social/duel_room_screen.dart) / friendly-session integration | Silent preparation; coordinate only final shared duel outcome with Practice route to avoid two completion sounds. |
| [xp_controller.dart](/Users/shagunkumar/Desktop/aptiqu/lib/core/progression/controllers/xp_controller.dart) | Capture before/after presentation data, preserve actual progression and coalescing, provide a stable visible-celebration identity. |
| [social_overlay.dart](/Users/shagunkumar/Desktop/aptiqu/lib/features/social/social_overlay.dart) | Keep existing foreground/task/editing/modal gate; sequence the visible level-up cue after result audio without blocking progression. |
| [level_up_overlay.dart](/Users/shagunkumar/Desktop/aptiqu/lib/features/home/presentation/widgets/level_up_overlay.dart) | Replace plain dialog body with the finite XP-fill/avatar-pulse/new-level celebration, with reduced-motion and responsive final state. |
| [profile_screen.dart](/Users/shagunkumar/Desktop/aptiqu/lib/features/profile/presentation/screens/profile_screen.dart) + proposed small feedback-settings widget | Compact settings after Appearance; approved palette/type/controls retained. |
| [pubspec.yaml](/Users/shagunkumar/Desktop/aptiqu/pubspec.yaml), lockfile, future `assets/audio/feedback/` | Add only approved dependency/version and eight chosen production assets after review. Do not bundle this entire review folder. |
| Focused new feedback tests; existing Practice and XP tests | Fake audio/haptic backend, deterministic clock/lifecycle/receipt tests, and level-up widget/semantic checks. No physical audio assertion from an emulator alone. |
| [FRONTEND_DESIGN_SYSTEM.md](/Users/shagunkumar/Desktop/aptiqu/docs/FRONTEND_DESIGN_SYSTEM.md) | After approval/implementation, document the lasting feedback and richer-level-up conventions. No handbook changes in this planning task. |

No planned backend/DB/migration, scoring/Elo/XP formula, Luna generation, login screen, manual question, lesson-content, palette or typography changes. No sound is added globally to the shared button widget.

## 10. Implementation and acceptance sequence

1. **Review this plan and listen to assets.** Choose A/B files and settle the decisions below. Asset research is complete enough to proceed; custom audio is optional.
2. Implement a testable service/preferences/audio adapter and production asset manifest. Verify mute, cleanup and player limits before wiring game events.
3. Wire Practice readiness, ticks, confirmed answers and completion. Test timed/untimed, fresh session, replay, early submit, timeout, failed submit and lost acknowledgement.
4. Wire Ranked/unranked and friendly states using the same service. Test duplicate/out-of-order socket events, reconnect at seven seconds, two player identities, shared completion, actual winner, draw, void and cancelled preparation.
5. Replace level-up presentation while preserving XP truth and existing safe gate; test one/multiple levels, absent prior fraction, queued awards, Continue during animation, reduced motion and account switching.
6. Add compact Profile controls. Verify settings persist, mute stops immediately, system silence/output routing are respected and a preview is explicit.
7. Profile and audition on real Android and iOS devices. Check normal phone speaker/headphones/Bluetooth, volume zero, silent mode, vibration disabled, incoming call, other media, app switch, lock/unlock, route change and memory pressure.
8. Render the new level-up surface in the app's Light/Dark themes, normal and enlarged text, narrow/short layouts; inspect actual visuals and semantics. No historical phase test suites or bulk golden updates.
9. Run feature-specific tests and `flutter analyze`; compare frame time, player/memory counts and selected-asset/package size against the baseline. A bounded player count is an assertion, not a comment.
10. Manual acceptance: after a genuine long wait, the start cue is noticeable once; clocks sound only while answerable; final-ten ticks are distinct but tolerable; result sound follows truth; victory and level-up do not stack; no game waits for feedback.

No performance or real-device audio test has been run for this future implementation. The only media work performed now is download, local audio preparation/technical verification and this plan.

## 11. Choices for your review

| Decision | Recommendation | Alternative / implication |
| --- | --- | --- |
| Exact sound choices | Begin with A for the eight core events; swap individual B files after listening. | You can supply a brand-specific set later. The mapping stays semantic, so replacing a clip need not change gameplay code. |
| Timer default | Full, quietly, to match your stated request; allow Last 10 seconds and Off. | Default Last 10 seconds is quieter and less cognitively demanding, but changes the initial experience you described. |
| Urgent character | A for a short dry tick; audition B's very short echo if you want a reverberant emphasis. | Longer reverb or accelerating ticks may obscure the clock and feel stressful; not recommended. |
| Level-up haptic | Sound plus animation, no haptic initially. | One optional light tap at the visual level transition; never a repeating pulse or per-level vibration chain. |
| Button sounds | Leave off; optional sample is only for comparison. | If later chosen, limit to explicit important commit actions, not every button/tab/option. |
| Background attention | Foreground-only in this feature. | If attention is needed while locked/in another app, approve a separate background-ready notification design. This cannot be promised by a foreground audio service. |
| Level-up timing | Existing safe gate, usually after leaving the session/result route. | An inline after-result celebration needs a deliberate safe-result contract, not a blanket gate bypass. |
| Other app areas | Keep first release to sessions and level-up; consider Daily/lesson milestones later with the same assets. | Expanding everywhere immediately increases overlap and fatigue and makes the first implementation harder to evaluate. |

Your approval can name filenames directly, for example: “start B, tick normal A, final10 B, correct A, wrong A, complete B, victory A, level-up B; no button sounds.” No implementation is performed by selecting or listening to the current review files.

### Checks completed for this planning deliverable

All 18 files decode as non-silent mono 44.1 kHz PCM16 WAV, with no clipped samples in the prepared files. Durations and sizes above were measured from the review files. All local links resolve. Git shows only this new plan and the new review folder; tracked application files remain unchanged. No app code, dependency installation, app tests/build, DB/VPS operations or paid AI calls were performed. Phone audition and runtime performance measurements belong to the future approved implementation.
