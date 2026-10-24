# 11 — Flutter learner experience and administrative dashboard

Status: proposed changes only. The canonical current reference is `docs/FRONTEND_DESIGN_SYSTEM.md`; current Phase G is approved and no release is requested. Keep approved palette, typography/sizes, tokens and navigation. This document does not reopen historical UI phases or authorize implementation.

## Reuse and consolidate

Current Home embeds the lesson through `home_controller.dart`/`chat_playground_zone.dart`; routed lessons use `lesson_feed_controller.dart`/`lesson_feed_screen.dart`. Both use `lesson_repository.dart`. Introduce a shared proposed `TutorSessionCoordinator` for server state, receipt identity, action retry, help attachment and lifecycle. Home and routed surfaces consume the same state; legacy scripts continue through their current adapter. Do not build another divergent player.

Existing reusable UI: `AnswerOption`, `QuestionMetadata`, `AptiquButton`, `AppLoader`, `TutorThinkingBubble`, `SessionNotice`, `showAppSheet`, `TopicDetailsSheet` and measured action-row behavior. Before adding widgets, inspect their actual contracts and callers. `AnswerOption` does not grade; `SessionNotice` does not own retry policy. Narration needs new domain-specific control/player widgets because existing voice UI is a stub.

Potential new files beneath `lib/features/tutor/`: `models/tutor_session.dart`, `models/tutor_block.dart`, `repositories/tutor_repository.dart`, `controllers/tutor_session_coordinator.dart`, `controllers/narration_controller.dart`, `widgets/tutor_block_renderer.dart`, `widgets/tutor_avatar.dart`, `widgets/narration_controls.dart`, `widgets/learning_preferences_sheet.dart`. Names are proposals, not created files.

## Complete learner journeys

| User intent | Existing surface to adapt | Proposed behavior / reason |
|---|---|---|
| New-user setup | Existing auth/signup plus short optional learning sheet | Language first, optional goal/detail; skippable diagnostic; no 1–9 sliders or demographic profiling |
| Pick subject/topic | Home `ConstellationRoadmapView` and topic dock/sheet | Preserve map/list and lock semantics; show approved skill availability/languages and progress |
| Start subtopic | `TopicDetailsSheet` | Concise outcome summary and ordered skill rows; choose first ready/unassessed skill; Start/Continue/Replay stay truthful |
| Start a specific skill | Same sheet/expanded subtopic view | Skill description, prerequisite support and estimated duration range, no separate screen for each metadata item |
| Resume unfinished work | Home next action / topic Continue | Fetch owned pinned session; confirm uncertain action; restore cursor/text; audio waits for explicit play on foreground |
| Read lesson | Shared Home/routed tutor surface | Short text/math blocks; connected chat sequence; 640 px maximum reading region where already used |
| See tutor mascot | Small header/avatar slot | Existing logo, decorative by default; actual playback-driven speaking state |
| Enable/listen/mute | Compact narration row near current teacher header | Clearly labelled speaker toggle, pause/replay; 48 px targets; text remains central |
| Continue | Existing inline action after current step | Stops obsolete audio immediately, submits one receipt-protected action; does not wait for clip end |
| Answer untimed item | Existing native `AnswerOption` group | Tap ID, immediate selected/pending state, server grade and feedback; no countdown or speed score |
| Ask typed doubt | Existing doubt sheet adapted | Current skill/screen context, input ≤500 chars, retained draft/error/retry; no voice-input icon implying support |
| Simpler/more detail/example/analogy | Tutor help menu/sheet | Contextual private response; original lesson stays pinned; no fourth always-visible toolbar row |
| Already understand | Tutor action menu | Optional short check; no mastery from assertion or scrolling |
| Language change | Tutor menu + preferences | Show available approved variants; stop audio; switch next safe boundary or explicit restart; preserve evidence |
| Cold preparation | Existing loading/notice area | Immediate truthful preparation label, approved compatible fallback, no imaginary progress percent; review-required content stays unavailable |
| Complete skill | Existing completion surface | State what independent evidence showed; ask a meaningful explanation/check; distinguish completion from review due |
| View progress | Home/performance and topic rows | Outcome/skill counts and evidence uncertainty, review due; no invented percentage mastery |
| Review preferences | Profile Learning preferences group | Explicit values and optional suggestions/undo; preserve Appearance near identity |
| Read AI progress feedback | Existing progress area, compact expandable section | Dated “Based on recent answers” with evidence link and report/adjust control |

These cover the requested nineteen flows without nineteen screens. Goal/locale changes can alter a roadmap recommendation but cannot silently change an active lesson's required outcomes.

## Tutor composition

```text
Skill title                     Close / Fullscreen

Logo   AptiQu        Narration on/off

One connected teaching step.

Important expression

A short explanation of this step.

Continue                     Ask a doubt
```

This is a semantic composition sketch, not space-aligned implementation. Use real Row/Wrap and content measurement. At narrow width/2× text, controls wrap as complete labelled units. The conversation reading flow owns the full title when the header becomes compact, following current Home behavior. Avoid repeated heavy cards and explanatory prose around each tool.

Use `context.type.bodyLarge` (16 px Plus Jakarta Sans) for teaching, approved title roles, theme foreground/background pairs and token spacing. Do not shrink text to fit a dense model paragraph. Split content at meaningful teaching boundaries; mathematical lines can have accessible alternative speech. A future equation renderer needs a real Flutter package/device evaluation; no math-layout package is currently established by the inspected pubspec.

## State and recovery UX

`TutorViewState` combines server session status and current allowed actions with separate local action/help/audio state. Preserve the current action's identity/payload until acknowledgment; a transport error leaves a visible Retry for that same operation. Switching route/account increments a generation epoch; stale HTTP/help/audio callbacks cannot append to the wrong conversation.

Confirmed history is preserved through recoverable errors. A retained-content notice uses existing `SessionNotice`, not an empty full-screen spinner. Offline text already delivered may be read, but grading/progression is not invented locally. Persist only minimized account-scoped checkpoints; server state wins on reconnection. Queueing many offline answers or downloading answer keys is deferred.

A question retry failure shows the actual worked correction and offers review/pause; completion remains pending. No endless mandatory loop, false “mastered” badge or repeated identical solution earns extra evidence. Distinguish retrying a network operation from trying a fresh learning question in labels and internal state.

When a published artifact is quarantined, explain “This example needs a correction” and offer a reviewed replacement. Do not blame the learner or keep narrating known bad content. Reports retain artifact/screen IDs, not screenshots/transcripts by default. Review content under authorized permission.

## Voice/lifecycle behavior

Narration controller is independent of the session coordinator. Continue/answer interrupts current audio; screen epochs prevent an older clip from starting late. App background pauses/stops; foreground does not surprise-autoplay. Audio focus/phone interruptions and headphones use platform behavior. Account sign-out stops speech and purges private clip cache. Reduced motion renders a steady logo; no animation is needed to understand the lesson.

Use account preference plus immediate local mirror for enabled/mute/rate, with pending-setting retry state. Do not enable narration just because a phone has volume, or treat muting as a preference for less teaching. Native screen readers must not compete with automatic narration; offer manual playback. No microphone permission request is appropriate.

## Accessibility acceptance

Validate 320×568, a typical 390 px phone, short landscape, tablet width and text scales 1.0/1.3/2.0 in Light/Dark. Include Hindi/Tamil/Hinglish long labels and fallback font coverage without changing approved Latin font roles. Add appropriate licensed Indic fallback fonts only if actual glyph coverage requires it; test exact assets and sizes, do not assume bundled Latin families contain Indic glyphs.

Requirements: readable wrapping, no equation clipping or whitespace-aligned diagrams, labelled minimum 48 px controls, keyboard/focus order, selected/disabled semantics, live error/feedback announcements, non-color status, safe keyboard/bottom insets, no rapid flashing or forced motion. Screen readers get correct spoken math with grouping; text-only learners receive all content and controls. Test without network, without hearing audio and with all animations disabled.

The investigation's phone-width typographic previews in 12 are **not** Flutter screenshots, real widget tests or device verification. Implementation must produce actual rendered evidence before UI approval. Run only new/specific Tutor feature/widget tests and `flutter analyze`; do not run historical `phase_a`–`phase_g` suites for this feature work by habit.

## Dashboard changes

Adapt `admin-dashboard/src/pages/SyllabusPage.tsx` and `AiPromptsPage.tsx`; keep React/Vite/API plumbing. Add focused proposed pages for generated lessons/review and AI operations if existing pages become too dense. Extend `AdminLayout.tsx`, `App.tsx` and `services/api.ts`; no new dashboard framework is needed.

| Capability | Initial release | Concrete interface / permission |
|---|---|---|
| Curriculum skills/scopes | Required | Subject/topic tree, subtopic ordered skills, source/scope/outcomes/prerequisites editor and dry-run diff; curriculum editor |
| Publish/import/export | Required | Validate report, base revision check, atomic publish with reason/actor; publisher separate from editing |
| Generated lesson review | Required | Read successful path, wrong/retry paths, phone preview and math/coverage checks side by side; teacher reviewer |
| Incorrect-content handling | Required | Search by artifact/screen/report, quarantine, affected-session count and correction lineage; publisher/support policy |
| Model/prompt configuration | Required | Immutable versions, test evidence, price ceilings, canary/rollback; AI configuration permission |
| INR operations | Required | Reserved/estimated/invoiced/uncertain totals separated, per workload, token and voice units, budget stop; finance/operator |
| Failures/health | Required | Queue age, safe provider code, validation failures, outbox/worker/dependency health; operator |
| Learning analytics | Required, minimized | Aggregate outcome evidence and trends with minimum cohort sizes; raw private doubt text restricted and audited |
| Voice usage | Required with narration | Locale/voice/digest quality, cached/new character totals, playback failures, stale-audio quarantine |
| Advanced experimentation | Deferred | Multi-arm learning-outcome trials, automated policy promotion, complex prompt optimizers need separate authorization |

Proposed admin APIs beneath `/api/v1/admin/tutor`: topic dry-run/import/publish, artifact list/detail/review/quarantine, jobs/dispatches, spend summary/config, audio status and report resolution. Mutations require idempotency key, expected revision, permission and audit reason. Paginate by stable cursor; limit raw body access. A review button must not show “Math verified” unless the relevant verifier/version actually ran; human review status remains separate.

Before exposing learner narratives/financial controls beyond the current single-admin model, introduce distinct server-enforced permissions, stronger admin authentication/MFA and session handling. Current localStorage bearer tokens increase XSS impact; evaluate secure HttpOnly same-site sessions with CSRF protection or an equivalent reviewed deployment-specific design. A hidden dashboard button is not access control.

## Implementation/test handoff

New Flutter repository contract fixtures cover 200/201/202, stale versions, duplicate receipts, help errors and public answer redaction. Coordinator tests cover route reuse, two surfaces, account switch and uncertain retry. Widget tests cover phone layout, math semantics, option IDs and untimed questions. Narration adapter tests cover stop-on-answer, stale clips, background, failure/mute and text-only flow. Dashboard tests cover role enforcement, publish conflicts, dry-run, review path preview and quarantine. All are future phase work; no production UI change is delivered here.
