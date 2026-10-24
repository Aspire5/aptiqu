# 09 — Optional narration and replaceable mascot

**Recommend Google Cloud Chirp 3 HD as the initial speech-service candidate**, pending listening and math-faithfulness tests. Use the existing `assets/images/main_logo.webp` as the temporary tutor representation. Text and touch interaction remain complete without audio. No microphone, speech recognition, final character artwork or lip sync is part of this phase.

## Voice options and current evidence

| Service / voice candidate | Language/persona evidence | INR price / tradeoff |
|---|---|---|
| Google Cloud Chirp 3 HD, locale-specific `...-Charon` or `...-Schedar` | Official catalog lists male voices for English India, Hindi and Tamil; shortlist for warm mature teacher, not a verified age/persona match | ₹2,850/M characters; naturalness candidate, paid bytes can be shared across compatible lessons |
| Google Cloud WaveNet, e.g. `ta-IN-Wavenet-B`, locale-matched male voice | Broad locale catalog; more deterministic SSML-based pronunciation options | Current published rate ₹380/M characters; choose only if listening passes quality, not solely because cheaper |
| Google Cloud Neural2 male locale where available | SSML-capable alternative; check voice availability separately per language | ₹1,520/M characters; does not imply the same voice exists in every locale |
| Google Cloud Gemini 2.5 Flash TTS | Prompt-directed speech alternative; separate TTS model, not text Flash-Lite | ₹47.50/M input text tokens + ₹950/M output audio tokens; at 25 audio tokens/sec, ~₹1.425/min plus input text |
| OpenAI Speech (`gpt-4o-mini-tts`, `cedar`/`onyx` audition candidates) | Guide supports Hindi/Tamil and English-optimized voices, but model page marks it deprecated while guide still demonstrates it | Published model units ₹57/M text input and ₹1,140/M audio output tokens; no verified duration conversion here; do not commit a new production dependency until lifecycle/pricing clarified |
| Azure Speech neural voices | Official catalog includes locale-specific male candidates; regional/voice eligibility must be checked | Pricing page is dynamic/region-dependent; no reliable fetched INR quote established, so excluded from numeric baseline pending exact quote |

Sources: [Google pricing](https://cloud.google.com/text-to-speech/pricing), [Google voice catalog](https://docs.cloud.google.com/text-to-speech/docs/list-voices-and-types), [OpenAI speech guide](https://developers.openai.com/api/docs/guides/text-to-speech), [OpenAI model lifecycle/rates](https://developers.openai.com/api/docs/models/gpt-4o-mini-tts), [Azure languages](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/language-support?tabs=tts), [Azure pricing](https://azure.microsoft.com/en-us/pricing/details/speech/). Conversion and taxes follow document 10. No free-tier discount is assumed.

Male metadata does not establish approximate age, warmth, patience, Indian pronunciation or suitability for beginners. Final selection needs native-language listeners and user preference review. No synthesis/listening was performed in this assignment. Do not describe any shortlist voice as already validated.

Google's preview 3.8 TTS pricing has a dated change after 31 December 2026. Avoid basing a sustainable launch forecast on a temporary promotional preview rate. Character-based Chirp pricing is the baseline; Gemini TTS is a separately measured alternative. Do not mix text-token rates with audio-token units or price a narrated lesson as ordinary LLM output.

## Content and math speech contract

One canonical semantic content object drives display and narration. Each math block includes AST/verified formula, exact displayed notation and approved speech text. The compiler normalizes expressions, locale terminology and grouping. The LLM may propose natural prose but cannot change numeric value, variable identity or operation grouping when producing narration.

| Visible math | English speech target | Required check |
|---|---|---|
| `3/4 × 16 = 12` | “Three quarters multiplied by sixteen equals twelve.” | Fraction bound before multiplication; no “three divided by four times…” ambiguity |
| `0.05` | “Zero point zero five.” | Preserve leading fractional zero |
| `2^3 = 8` | “Two cubed equals eight.” | Exponent is not multiplication by three |
| `(6 + 2) × 3` | “Open bracket, six plus two, close bracket, multiplied by three.” | For beginner, optionally explain “add first”; no missing bracket |
| `24 ÷ (3 × 2)` | “Twenty-four divided by the result of three times two.” | Must differ from “twenty-four divided by three, then times two” |
| `x − 5 = 7` | “x minus five equals seven.” | `x` letter differs from multiplication sign |
| `1.25 × 10^4` | “One point two five times ten to the fourth power.” | Significant-figure display not replaced by an unqualified exact integer |
| `0.(3)` if this approved convention is selected | “Zero point three recurring.” | Same repeating convention in text, options, feedback and audio |

For long expressions, split at meaningful transformations: read original → explain one operation → read changed line. Do not force a ten-term formula into one unbroken audio clip. Narrate every essential mathematical statement but omit decorative timestamps, buttons and option IDs unless reading the question/options is useful. Audio must not reveal the answer to the current unattempted question.

Language lexicon examples for native review: Hindi “तीन चौथाई”, “गुणा”, “बराबर”; Tamil “நான்கில் மூன்று”, “பெருக்கல்”, “சமம்”; Hinglish “teen chauthai” / “three quarters” according to explicit script/terminology preference. These are proposed glossary entries, not validated recordings. Native reviewers verify inflection, decimal reading, variable names and whether code-switching sounds natural. A Hinglish product locale maps to a reviewed provider voice/language strategy, not a claim that every provider has a dedicated Hinglish locale.

SSML capabilities differ by provider/voice family. Use an adapter capability map; never assume Chirp supports the same SSML tags/prosody controls as WaveNet/Neural2. The catalog lists different control support. Plain speech-text normalization is the safe common path. Unknown symbols, malformed AST, unsupported lexicon or speech/display mismatch block narration for that screen while text remains usable.

## Narration pipeline and reuse

Approved lesson screen → deterministic speech compiler/lexicon → semantic math validation → cache lookup by speech digest+locale+voice version+codec → reserved TTS job if enabled → private object storage → metadata/manifest in PostgreSQL → authorized playback URL. Shared approved lessons can share identity-free audio; private doubt narration never enters the shared bucket/key namespace.

Queue only current and one likely-next screen when narration is enabled. Do not synthesize every branch, every language and every preference combination. Shared approved launch lessons may be narrated before release within an explicitly approved operational budget. Turned-off narration creates no new speech job. If prefetch has already dispatched when muted, suppress playback and retain actual billing evidence; cancellation is not assumed to reverse a charge.

Object URLs are short-lived (proposed five minutes), scoped to owned session/approved artifact and refreshed without regeneration. Store speech/display digest, provider/model/voice version, duration, byte size, codec, quality status and cost. Text corrections invalidate old audio by digest. Use lifecycle rules for orphaned/retired/private audio and clean only owned objects; no arbitrary URL fetch from model content.

## Playback state machine

States: OFF, IDLE, LOADING, PLAYING, PAUSED, ENDED, FAILED. `muted` is an explicit separate setting; actual audible playback follows OS/audio focus too. Session progression state is independent of playback state.

| Event | Audio behavior | Lesson / settings behavior |
|---|---|---|
| New visible step, narration enabled | Cancel obsolete local playback; fetch approved current clip and play when ready | Text and controls available immediately; retain playback epoch to reject stale callbacks |
| Continue during speech | Stop current clip immediately; cancel obsolete prefetch where possible | Submit Continue once; new audio follows only server-confirmed next step |
| Tap answer | Stop question audio before request; lock duplicate tap | Grade server-side; narrate accepted feedback once if enabled |
| Pause/replay | Pause current clip or restart current approved clip | No question attempt, progression or synthesis if cached |
| Mute / narration off | Stop or silence immediately; do not dispatch new synthesis | Remember explicit account preference, plus local immediate state |
| App background / interruption | Pause/stop playback; no automatic background narration in v1 | Save confirmed cursor; do not infer completion from audio ending |
| Foreground | Re-fetch/preserve owned state; wait for explicit resume/play | Avoid surprise speech and duplicate Continue |
| Failed/slow audio | Show compact “Audio unavailable” and optional Retry | Continue reading remains active; no blocking modal or automatic paid loop |
| Unreliable network | Finish already buffered clip; avoid overlap; expose replay when available | Confirmed text retained; action retry uses same identity |
| Language change | Stop old clip and increment epoch | Switch to approved language variant at boundary or explicit restart; no mixed-language stale audio |
| Screen reader active | Avoid competing automatic voices; offer manual narration | Text semantics remain available and preferred |

Persist narration enabled, explicit mute and preferred rate on account with a local mirror for immediate use/offline startup. Ephemeral player position, OS focus and “background paused” are device/session state, not global preferences. Account switches stop playback, purge private cached clips and re-read preferences.

## Mascot adapter

Proposed Flutter `TutorAvatar` receives `idle`, `preparing`, `speaking`, `paused`, `error` and reduced-motion state. Initially render the existing logo with a small speaking ring/pulse; use the approved semantic palette. Speaking follows actual player PLAYING, not provider request start or the presence of a text bubble. Loading uses the existing AppLoader/TutorThinkingBubble contract, not a fake speaking animation.

Future character provider implements the same presentation interface, with optional viseme/timing metadata attached to audio manifests. Missing animation/visemes fall back to logo/text and never delay input. No microphone imagery should imply voice input is active. Mascot can be decorative to a screen reader; playback controls carry useful accessible labels.

## Cost and quality gates

At 8,000 spoken characters, first Chirp synthesis is **₹22.80**, versus **₹3.04** for WaveNet or **₹12.16** for Neural2 before taxes. Replaying stored audio adds no synthesis fee; storage/bandwidth still apply. This is why shared clip reuse matters more financially than making already cheap text inference slightly cheaper. Private personalized narration can dominate costs; begin with core narrated lessons and explicit private-help playback, measured separately.

Future listening fixture: 12 short utterances per released locale covering fraction/grouping, decimal, exponent, equation, variables, options, negative/approximate notation and code-switching. Ask listeners to transcribe the math and rate clarity/warmth/pacing. Require 100% semantic math agreement, no answer leak, and acceptable naturalness in each locale. Budget every audio dispatch and price by actual billable units; no paid voice tests occurred here. Provider latency and synthesis quality remain unmeasured. See 10 for targets and 12 for rubrics.
