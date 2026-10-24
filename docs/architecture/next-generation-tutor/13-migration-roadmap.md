# 13 — Migration and phased implementation roadmap

**This is an implementation handoff, not authorization to implement.** No production code, existing scripts, DB, VPS, infrastructure or deployment was changed. Architecture review precedes every implementation commitment. The user must explicitly authorize any future database setup/actions/migrations and release work; a phase description is not that authorization.

Complexity estimates below are relative engineering effort ranges for planning, not delivery promises. Educational authoring/review and native-language work are additional and can dominate. Keep unrelated Practice/PvP/Ranked behavior intact; do not resolve the deferred Ranked outage/exit policy here.

## Phase 0 — Approve contracts and launch scope

**Goal:** agree on a small, coherent launch curriculum and evidence policy before building a generic generator. Complexity M, roughly 3–5 engineer-days plus teacher/product review.

- Review this package, choose a first 3–5 skills from approved source subtopics, preserve names/order/scope, and approve the skill split. Explicitly decide launch locales, teacher staffing, review throughput, narration default and monthly INR allowance.
- Existing references: `books/SubTopics/*/subtopics.json`, strong Age/Number System scripts, current AGENTS rules, `docs/FRONTEND_DESIGN_SYSTEM.md`, runtime/Prisma schema. No existing content edits during this decision phase.
- New deliverables: reviewed topic JSON schema, lesson/public DTO schema, mathematical family specification, fixed teacher-reviewed fixtures and approval record. DB/API/frontend changes: none yet.
- Tests: offline schema roundtrip, source-clause→skill coverage review, exact math fixtures and misuse/ambiguity cases. No DB/provider calls needed.
- Acceptance: no unresolved scope gap; documented “completion vs durable mastery”; model selection remains conditional; privacy/age policy has an owner. Approval boundary: authorize Phase 1 separately.
- Risks/rollback: overfragmented skills or too many variants; revise specifications while legacy runtime remains authoritative.

## Phase 1 — Curriculum revisions and migration preparation

**Goal:** add skills and immutable publication beside legacy curriculum. Complexity L, ~6–10 engineer-days after authorization.

- Existing files: `backend/prisma/schema.prisma`, `backend/src/modules/admin/admin-syllabus.service.ts`, `admin-syllabus.controller.ts`, `backend/src/modules/roadmap/`, `backend/src/runtime/sync-curriculum.ts`, `backend/prisma/changes/README.md`.
- New components: `backend/src/modules/curriculum/` importer/validator/exporter/publisher, versioned schema fixtures, explicit legacy mapping report. Proposed database entities: curriculum_release, topic/subtopic/skill revisions, release placements, prerequisites, outcomes and mapping provenance.
- API: admin dry-run diff/import/export/publish plus published read catalog. UI: dashboard skill/scope view, no learner player switch yet. A dry-run must not write published rows.
- Dependencies: Phase 0 approval; separately approved schema/native-constraint baseline strategy. The repo has no ordinary Prisma migration baseline; review actual target drift later with explicit access, never assume a fresh migrate command is safe.
- Tests: pure import/export and invalid prerequisites/cycles/duplicate positions; then separately authorized disposable-DB uniqueness/publication/rollback tests. Verify identical import no-op and old release reads.
- Acceptance: every original scope clause maps to an approved skill; publish atomic; rename/reorder preserves stable IDs; startup source sync cannot overwrite v2 records; old roadmap/scripts still load.
- Risks: join-table placement semantics and manual SQL drift. Rollback: keep v2 catalog feature flag off and old routes unchanged; retain additive tables, no destructive down migration.

## Phase 2 — Deterministic Tutor session and assessment core

**Goal:** reliable text learning with approved fixture lessons before AI composition. Complexity L, ~8–12 engineer-days.

- Existing files: lesson transaction/session/question/public-node services, `backend/src/modules/xp/`, roadmap progression; inspect their callers before sharing helpers. Do not change legacy semantics accidentally.
- New modules: proposed `tutor/` session/artifact/assessment services and public DTO projections in 05. Database: tutor_session, action receipts, assessment_item, skill_attempt, learner_event, outcome_evidence, skill_state and outbox.
- APIs: start/resume, current session, actions, pause and owned preparation resources. Frontend: repository/transport fixtures only or developer flag; production shell still uses legacy player.
- Dependencies: published skill/outcome IDs and reviewed mathematical family. All math truth and seeded numeric checks are deterministic. No live AI integration is necessary for this phase.
- Tests: unit state machine, public-answer masking, item uniqueness, hints/exposure, no timer fields, insufficient-evidence completion, request identity/hash conflict and safe resume. After separate DB authorization: parallel-device commit, receipt replay after lost acknowledgment, atomic XP/progression, outbox crash replay and quarantine behavior.
- Acceptance: acknowledged attempts never duplicate; no completion without required independent evidence; reading/answering uses no model call; existing XP/progress cannot be double-awarded or reconstructed speculatively.
- Risks: new/legacy transaction lock-order conflict; read-only render drift. Rollback: disable new starts, retain handlers to resume/settle already created v2 sessions; do not abandon durable obligations.

## Phase 3 — AI gateway, spend admission and quality-controlled generation

**Goal:** compose reusable skill lessons safely and measure accepted quality. Complexity XL, ~10–18 engineer-days plus teacher evaluation.

- Existing files: `backend/src/modules/ai/gemini.provider.ts`, `provider-budget.ts`, `config/runtime-config.ts`, `queues/content-generation.queue.ts`, `modules/admin/ai-prompts` files and prompt service. Do not insert a paid provider into the legacy transaction-wrapped stub interrupt method.
- New components: typed provider adapters, model/config registry, versioned prompt builder, exact-math/semantic reference validators, artifact review pipeline, separate Tutor generation queue/worker and outbox relay.
- Database: generation jobs/waiters, artifacts/reviews/outcome maps, provider dispatch/cost reservation, immutable model/prompt/price versions. API: preparation/job status, admin candidate review/publish/quarantine, spend visibility.
- Frontend: truthful preparing/fallback states; approved lessons only. Shared generation contains no personal text; private requests stay separate.
- Dependencies: Phase 2, approved secret injection/provider project limits, approved testing budget. Diagnose Gemini's request contract offline with official schema fixtures before another live profile. Candidate evaluation remains gated; current Luna outputs all failed release.
- Eligibility gate: direct Gemini API terms restrict under-18-accessed clients; resolve an appropriate contract/service before using it in AptiQu's school-facing product. Verify OpenAI's child safeguards/ZDR requirements before processing relevant children's personal data. An adult synthetic test is not deployment permission.
- Tests: fake provider refusal/truncation/invalid output and schema setting translation; stampede and duplicate dispatch; uncertain post-send crash; INR reservation failures; queue×SDK retry multiplication; revision/price changes; answer/prompt/reference mutation. Small authorized paid samples only after these pass; independent teacher and beginner review before publication.
- Acceptance: one logical job per compatible key, per-attempt reservation, no unvalidated learner content, no key leakage, full required coverage, correction lineage and at least the approved launch variants prepublished. Measure acceptance cost, not raw generation success.
- Risks: quality failure/review bottleneck and provider entitlements. Rollback: disable new paid admission, continue approved stored lessons and legacy runtime; preserve uncertain cost holds and job records for reconciliation.

## Phase 4 — Shared Flutter text Tutor and initial personalization

**Goal:** expose the new skill experience in the existing approved composition. Complexity L, ~8–12 engineer-days.

- Existing files: `lib/features/home/presentation/controllers/home_controller.dart`, `widgets/chat_playground_zone.dart`, `widgets/question_container_widget.dart`, `widgets/topic_details_sheet.dart`, routed lesson controller/screen/repository, `lib/core/routing/app_router.dart`, Profile settings and shared question/sheet/button widgets.
- New components: shared TutorSessionCoordinator, typed block models/renderer, Tutor repository, learning preferences sheet and unknown/pending/evidence states. Retain an adapter for legacy sessions and eliminate new duplication between embedded/routed surfaces.
- Database/API: learner_preferences/change audit; published skill reads, typed help preparation and context binding. Learner-facing help may initially use approved static snippets until Phase 5 providers pass.
- Frontend: language/goal optional setup, skippable diagnostic, More steps/Shorter explanations, skill rows, untimed tapping, current text/help controls, preparation fallback, meaningful completion and resume. Remove artificial minimum thinking waits from the new path; preserve existing loader anti-flicker policy where appropriate.
- Dependencies: approved launch artifacts and API contracts; read handbook/theme/widgets/callers. No palette/font-size redesign or unrelated navigation change.
- Tests: `test/tutor_session_test.dart`, `test/tutor_learning_test.dart` and relevant existing feature test such as topic/home only when changed; run `flutter analyze`. Check Light/Dark, 320 px/2× text, short landscape, keyboard, Indic text fallback, stale response/account switches, lost action acknowledgment, direct/routed same state. Do not run historical phase suites by habit.
- Acceptance: all text flows work with narration absent, no countdown, no future answer leak, correct action IDs, original UI tokens and accessible 48 px controls. Show actual Flutter rendered evidence for manual feature approval.
- Risks: two-controller divergence/long math wrapping. Rollback: feature flag new-skill start off; legacy sessions preserved; existing v2 sessions remain resumable in compatible UI/API.

## Phase 5 — Private help and evidence-based learner analyzer

**Goal:** contextual teaching assistance and grounded progress without latency in grading. Complexity L, ~7–12 engineer-days.

- Existing files: AI gateway interfaces/stub boundary, lesson doubt sheet, `mastery.service.ts`, current Concept/AiConversation models, Home progress controllers/views. Do not reinterpret legacy accuracy as calibrated mastery.
- New components: private help context/validator, deterministic feature builder, snapshot/analysis worker, proposal/consent policy, grounded feedback templates. Database: help requests/responses, analysis snapshots/results and feedback, no LLM SQL access.
- APIs: contextual help kinds/results, preferences/proposals/undo, progress/evidence summary. Frontend: simpler/detail/example/analogy, language boundary behavior, dated supported feedback and “This doesn't seem right” reporting.
- Dependencies: Phase 3 gateway/spend safety and Phase 4 text state; child-data/retention approval before sending personal evidence.
- Tests: foreign evidence rejection, fake metrics, explicit preference precedence, repeated item exposure, delayed/superseded help, insufficient data, debounced snapshot identity, second-miss recovery, quarantined-item projection repair and account deletion workflow. Narrative outage falls back to factual templates.
- Acceptance: AI never writes facts/mastery/XP/preferences directly; every insight has evidence/provenance and uncertainty; automatic scaffolding bounded, durable changes transparent/reversible.
- Risks: over-inference and hidden scope reduction. Rollback: disable narrative/help inference while deterministic progress, explicit preferences and approved text remain functional.

## Phase 6 — Optional narration and logo mascot

**Goal:** faithful multilingual-capable speech without obstructing reading. Complexity L, ~8–14 engineer-days plus native listening/device work.

- Existing files: `assets/images/main_logo.webp`, existing voice stub/doubt widgets, approved theme/tokens, app lifecycle/overlay gates and pubspec. Inspect suitable audio packages/license/platform behavior before choosing a dependency.
- New components: narration compiler/lexicon/provider adapter, audio worker/metadata/object authorization, NarrationController, playback controls and TutorAvatar adapter. No microphone permission or final mascot asset.
- Database/API: audio_asset and dispatch costs, screen/digest-based authorized request/status/URL, account narration settings. No raw arbitrary text-to-speech public endpoint.
- Frontend: opt-in/mute/pause/replay, stop-on-Continue/answer, no surprise foreground audio, reduced motion, accessible synthetic-voice disclosure, locale switch/failure fallback.
- Dependencies: semantic math representation, object storage/security and approved voice shortlist; a separate explicitly bounded speech evaluation budget if needed. No free-tier assumption or promotional preview dependency.
- Tests: pure speech math snapshots per locale; native listener transcription of fixtures; signed URL ownership, no answer leak/private cache crossover, mute prevents new jobs, stale epoch, interruptions/background/headphones, network failure, cache reuse and price limits. Real Android/iOS screen reader/audio focus tests required.
- Acceptance: zero math/speech mismatch in launch corpus, user-approved mature male persona, complete text-only flow, optional mascot animation never blocks. Native UI evidence/manual feature approval before enabling.
- Risks: code-switch pronunciation, TTS hallucination/SSML mismatch, voice miss costs. Rollback: narration flag off, stop player and pending admission; retain text and server progress; preserve billed dispatch evidence.

## Phase 7 — Dashboard operations, security and privacy readiness

**Goal:** accountable publishing and support with minimal access to learner data. Complexity M/L, ~6–10 engineer-days; must precede broad pilot even if built alongside earlier phases.

- Existing files: `admin-dashboard/src/pages/SyllabusPage.tsx`, `AiPromptsPage.tsx`, `DashboardPage.tsx`, `context/AuthContext.tsx`, `components/layout/AdminLayout.tsx`, `services/api.ts`; backend admin routes/middleware/controllers, runtime telemetry/logging.
- New components: artifact review/path preview, reports/quarantine/correction, curriculum publication history, AI/voice jobs and INR operations, server-enforced permission checks and audit viewer. Database: permission assignments/audit and erasure requests as approved.
- APIs: dry-run/publish/review/quarantine, safe dispatch/INR dashboards, aggregate analytics and controlled sensitive-case access. Frontend: compact purpose-built tables/filters, raw prompt access restricted; draft/published/math-reviewed statuses distinct.
- Dependencies: immutable review lineage, finance/privacy policy owners, provider retention/child consent review. Evaluate stronger admin auth/MFA and safer session storage; UI hiding alone is insufficient.
- Tests: role matrix/IDOR, unauthorized raw doubt/audio/finance access, stale publish race, budget exhaustion, key/error artifact leakage, deletion/backup erasure manifest, incident audit and model rollback. No real learner data in fixtures.
- Acceptance: wrong content can be quarantined promptly; support can trace affected artifacts without unrestricted learner prose; model/price changes controlled; production secret/config audit performed only with authorization.
- Risks: single-admin assumptions and legal treatment of child analytics. Rollback: restrict risky admin operations while keeping read/rollback access; never remove audit evidence to hide mistakes.

## Phase 8 — Verification, pilot and staged deployment

**Goal:** prove safe operations and learning usefulness before broad enablement. Complexity L, ~8–15 engineer-days plus a time-boxed learner pilot; not performed now.

- Existing files: backend runtime roles/readiness/shutdown/telemetry, artifact verification, deployment example and source-sync contract; specific Flutter/API tests. New components: rollout flags, dashboards/alerts, backup/restore and incident runbooks, reproducible mocked-load harness.
- DB changes: additive schema/native constraints only after separately approved target/drift/backup review. Prepare migration baseline and rehearsals against an explicitly authorized disposable environment; no destructive reset or blind `db push`. Preserve existing competitive/XP integrity guards even though feature work is outside scope.
- APIs/frontend: capability gates by app/schema version, mutually compatible old/new routes, limited release cohorts. Pre-warm/review complete launch catalog and audio before offering ready skills.
- Tests: offline/fake-provider load at 100/1,000/10,000 concurrent modeled learners; then separately authorized isolated DB/Redis concurrency/failure/restore tests. Real provider latency only in a new small budget, no paid load benchmark. Verify actual proxy/TLS/region/pools/ownership and provider quotas before deploy.
- Acceptance: zero blockers; correct evidence after lost responses/crashes; budget fail-closed; latency targets measured honestly; restore/erasure and quarantine drills; native-language/voice approval where enabled; consented beginner usability and transfer checks; architecture/product/release approval recorded.
- Deployment: expand schema first, deploy backward-compatible backend/workers, then compatible clients, then flags for a small cohort. Current single realtime/scheduler ownership remains protected. Increase traffic only after error/quality/spend/latency review. No production command is included as an action to run now.
- Rollback: disable new generation/voice/starts independently; retain active-session read/action/settlement and durable receipts; fall back to compatible approved/legacy lessons. Roll back release pointers for new admissions, not pinned historical bodies. Preserve additive data and old binaries/flags; emergency content quarantine takes precedence over cosmetic continuity.

## Cross-phase migration sequence

1. Inventory/validate legacy catalogs and publication snapshots without rewriting them; rights/scope review.
2. Build explicit subtopic→skill mappings, including source clause coverage and ambiguous notation caveats. User review approves new skill boundaries.
3. Publish additive v2 curriculum, leaving existing source sync/roadmap script assignment semantics intact. Prevent startup jobs from re-importing legacy data over new release records.
4. Keep legacy sessions pinned and resumable. New Tutor sessions use immutable v2 artifacts. Do not convert an in-flight graph node into an unrelated skill cursor.
5. Backfill only safe identity/history mappings under explicit DB authorization. Legacy completion is history, not automatically independent mastery; offer short untimed checks for missing evidence.
6. Compare read-only projected progress counts/source IDs before any rollout; investigate differences rather than invent reconciled totals.
7. Migrate new admissions by capability/feature flag, monitor incident/budget/quality evidence, preserve rollback. Deleting legacy assets/schema is deferred until no live/retention dependency and separate approval.

## First recommended milestone

Authorize only **Phase 0 contract review followed by Phase 1 preparation**, or a smaller agreed vertical slice. A useful implementation slice is one approved skill with deterministic verified items, a persisted approved artifact, resumable untimed actions and the existing Flutter look—before general AI help, narrative analysis or speech. This exposes contract/learning risks early without making unvalidated generation the default teaching experience.
