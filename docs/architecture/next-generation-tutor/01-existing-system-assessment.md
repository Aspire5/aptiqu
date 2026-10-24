# 01 — Existing system assessment

Date: 22 October 2026. Baseline `252fa1b`. Findings are source observations, not a production audit. Paths in code spans are repository-relative and name confirmed files unless explicitly labelled proposed.

## Technology and runtime

| Area | Confirmed source | Implication |
|---|---|---|
| Mobile | `pubspec.yaml`: Dart `^3.9.2`, Flutter, Get `^4.7.3`, go_router `^17.2.3`, Dio `^5.11.1`, secure storage `^10.3.4` | Retain current navigation/state ecosystem; no rewrite is justified |
| API | `backend/package.json`, `backend/tsconfig.json`, `backend/src/app.ts`: Express 4, strict TypeScript 5.8/CommonJS/ES2022, Zod | Add modules and validated DTOs within the current backend |
| Persistence | `backend/prisma/schema.prisma`: Prisma 6.4 multi-schema PostgreSQL | Add versioned curriculum/skill tables with deliberate native constraints |
| AI | `backend/src/modules/ai/gemini.provider.ts`, `backend/src/config/runtime-config.ts` | Google GenAI SDK exists; source default is `gemini-3.5-flash-lite`, not the brief's anticipated 2.5 model |
| Jobs/cache | BullMQ 6, ioredis 6, `backend/src/queues/content-generation.queue.ts`, `backend/src/modules/lesson/services/redis.service.ts` | Redis is already infrastructure in the application; reusing it has a different cost than introducing it anew |
| Dashboard | `admin-dashboard/package.json`, `admin-dashboard/src/App.tsx`: React 18, Vite 5, TypeScript, Axios, React Router | Extend existing protected dashboard routes |
| Runtime roles | `backend/src/runtime/lifecycle.ts`, `backend/ops/ecosystem.config.cjs`, `docs/BACKEND_RUNTIME_OPERATIONS.md` | Combined/http/realtime/jobs capabilities and readiness/drain machinery exist; PM2 file is an unactivated example |

Dependency ranges are declarations, not proof of installed versions or advisory resolution. Runtime code pins production Node ranges `^22.23.3 || ^24.22.0`; no upgrade/install was performed. No CI workflow, active server configuration, live process count, target schema or cloud region was verified. Do not turn historical operations documents into evidence that a release occurred.

## Current tutoring execution

`backend/src/modules/lesson/interfaces/script-dsl.interface.ts` defines CONTENT, CHOICE, QUESTION, TEXT_INPUT and COMPLETION nodes with conditional edges. Inline and repository question references coexist. `lesson.routes.ts` mounts authenticated active/start/get/action/interrupt/pause/resume endpoints beneath `/api/v1/lessons`.

`LessonScript` has a publication pointer; `LessonScriptVersion` stores JSONB/checksum/version; `LessonSession` pins a script version and current node with `stateVersion`. `LessonEvent`, `QuestionAttempt`, `LessonActionReceipt`, `ScriptAssignment`, roadmap progress and the XP ledger already give useful recovery foundations.

`backend/src/modules/lesson/services/learning-transaction.ts` scopes transactions through AsyncLocalStorage, locks the learner before the session, hashes operation identity and payload, and persists response receipts. Reusing an action ID with a changed payload is rejected. Preserve this invariant. The proposed tutor must not call a remote model while holding these locks.

`script-cache.service.ts` caches immutable definitions in Redis, coalesces reads and hydrates pinned question snapshots. `public-lesson-node.ts` allowlists visible fields and strips answer keys/branch rules. This is valuable security behavior. New lesson objects must preserve server-side solutions and grading even if a different lesson schema replaces the legacy graph.

`question.service.ts` evaluates selected option IDs deterministically. `mastery.service.ts` records correct/total accuracy for a Concept. That ratio is an observation summary, not a calibrated estimate of durable mastery. Session completion follows reaching a COMPLETION node; it does not prove all required skill outcomes were independently assessed.

The real Tutor AI is **not integrated**: `providers/stub-ai.provider.ts` returns a fixed unavailable message for doubts and a constant score of 1.0 for its open-text evaluation method. `lesson-session.service.ts` imports this stub. The constant score must never become evidence of comprehension in the new system. Its interrupt path currently executes inside the learning transaction because it is a local stub; substituting a paid network call in place would create long transactions and financial retry risk.

## Mobile execution and design constraints

There are two lesson players:

1. Home's embedded conversation: `lib/features/home/presentation/controllers/home_controller.dart`, `widgets/chat_playground_zone.dart`, `widgets/question_container_widget.dart`.
2. Routed lesson: `lib/features/lesson/controllers/lesson_feed_controller.dart`, `views/lesson_feed_screen.dart`, `views/widgets/node_renderer_factory.dart`.

Both use `lib/features/lesson/repositories/lesson_repository.dart` and server session state. The routed controller retains operation IDs for uncertain retries, guards stale responses and stores checkpoints. The new design should share a session coordinator rather than replicate a third independent controller. Existing players remain for legacy content during migration.

`question_node_widget.dart` measures elapsed time with a stopwatch, without a countdown. Preserve untimed Tutor semantics. Both Home and routed controllers include a 500 ms minimum thinking presentation; that artificial wait conflicts with immediate cached Continue/answer feedback and should be revisited in a separately authorized implementation phase.

`DoubtSheetWidget` exposes typed doubts with the current 500-character bound. `voice_stub_sheet.dart` and `image_stub_dialog.dart` are disclosed placeholders, not functioning speech or camera integration. `pubspec.yaml` has no established audio-player dependency. Introduce narration behind an adapter and explicit plugin/device evaluation.

The current approved system is in `docs/FRONTEND_DESIGN_SYSTEM.md` and the top checkpoint of `docs/UI_UX_REVAMP_PROGRESS.md`: Phase G is completed and manually approved; no release is requested. Preserve `AptiquTheme`, Outfit headings, Plus Jakarta Sans reading roles (16 px bodyLarge), existing light/dark palette and `AptiquSpace`/`AptiquRadius`. Shared `AnswerOption`, `AptiquButton`, sheets, retained-content notices and loading components are reusable. Standard hit region is at least 48 px. Logo asset: `assets/images/main_logo.webp`, included by the asset declaration. No new mascot artwork is needed.

## Curriculum and educational assets

A source-only inventory counted **20 `subtopics.json` catalogs, 203 subtopic entries and 236 JSON files under immediate `Scripts/` directories**. These are filesystem counts, not published-row counts or a guarantee that every JSON is a valid lesson. Number System has scripts without the same immediate catalog pattern, so do not infer missing content from catalog totals alone.

Reviewed representative assets:

- `books/SubTopics/SBT-RSA-08-Problems-on-Ages/Scripts/age-01-age-statements-timeline-models.json`: 50 nodes, readable labelled dates, small steps, prompt-matched remediation and retries. Useful concrete timeline teaching and original-clue checks.
- `books/SubTopics/SBT-RSA-04-Simplification/subtopics.json` and `Scripts/sim-01-order-of-operations-bodmas.json`: approved detailed scope, 51-node sample, progressive arithmetic and equation patterns. Preserve scope knowledge, but split into assessable skills with editorial review. Opening/next screen repeats the introduction; some mnemonic screens are dense.
- `books/SubTopics/SBT-RSA-01-Number_System/Scripts/` first place-value script: useful position examples, but some screens are long and sample retry edges proceed unconditionally. Historical content is a reference, not a quality certification.

The local R.S. Aggarwal PDF has 961 pages. Contents at PDF page 8 identify Simplification at printed pages 95–179. Read printed pages 95–98 (PDF 104–107): chained division and worked simplification justify the first evaluation skill. The book's mnemonic language lists division before multiplication and bracket shapes in sequence; the next curriculum must explicitly teach equal precedence and innermost grouping, not blindly promote mnemonic wording into a universal parser rule. Extraction scrambles complex fractions and bars; visual/source review is necessary for those expressions. No objective questions were extracted into a question bank.

`backend/src/modules/admin/prompts/book-script-generation.prompt.ts` requests a fixed skeleton, exactly eight MCQs, EASY/MEDIUM only, and unconditional progression after a retry. Some directions encourage attributing a specific misconception to any wrong answer. These conflict with current authoring standards. Preserve useful explanations and source scopes; replace such runtime-generation assumptions with per-skill outcome coverage and supported feedback.

## Existing data and admin capabilities

The schema already has Subject→Topic→Subtopic plus SubjectTopic/TopicSubtopic placement joins. It has no first-class Skill, immutable skill teaching scope or curriculum release entity. Canonical ownership and linked placements must be reconciled when introducing the four-level curriculum; do not flatten joins and lose roadmap semantics.

Profile has optional DOB, gender, religion and country; these must not flow into Tutor personalization merely because they exist. No separate learner pedagogy preference entity was found in the inspected schema. Concept mastery and AiConversation/AiMessage are partial foundations, not the requested learner analyzer.

Dashboard routes/pages cover syllabus/script import, question management, books, prompt drafts/publication, users and aggregate stats. `AiPrompt` supports mutable publication workflows but does not provide the proposed immutable prompt/model/quality lineage by itself. `admin.middleware.ts` uses one configured admin identity/role. `AuthContext.tsx` stores its bearer token in localStorage. Expanded sensitive learner/financial operations require finer permissions, audit trails and stronger operator authentication; no such redesign is claimed complete.

## Security, operations and tests

API JWT middleware, separate admin audience/purpose checks, body limits, CORS allowlists, no-store responses and allowlisted logging exist. Current provider admission controls bound concurrency/RPM/token reservations, but do not constitute an atomic INR billing ledger or a provider invoice reconciliation system. The Gemini provider can retry 429/503; generic queue retries also exist. New paid tasks must have one retry owner and per-attempt reservation.

`.env`, `backend/.env` and dashboard `.env` are ignored by Git; the corresponding exact paths were not tracked. Values were not printed. This does not prove absence from Git history, other artifacts or other filenames. At the point of authorized testing, only requested named provider keys were used. The OpenAI key uses `OPEN_AI_API_KEY` in `backend/.env`; no credential was modified.

Testing exists in Flutter `test/` and backend Node test suites. Default backend tests include inert security/practice/PvP cases; some legacy lesson/roadmap tests require explicit isolated dependencies. No DB setup, DB actions, Redis setup, migration, server startup or historical phase suite was run for this documentation task. Runtime operations documents explicitly distinguish example topology from deployment. Source migration history includes manual native SQL and no established Prisma migration baseline; plan a reviewed baseline rather than assuming `migrate deploy` is immediately safe.

## Migration risk and reuse verdict

Retain authentication, session receipts, server grading, immutable versions, shared mobile controls, curriculum placements, jobs/cache foundations, XP transaction semantics and useful teaching examples. Add skills and outcome evidence beside current records. Isolate generation, personal doubts, analysis and narration behind typed services. The largest risks are unvalidated generated mathematics, incompatible progress mapping, accidental startup synchronization over new curriculum, duplicate paid jobs and expanding admin access to minors' data. Documents 05/06/12/13 specify controls and gates.
