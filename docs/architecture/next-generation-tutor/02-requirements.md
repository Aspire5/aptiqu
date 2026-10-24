# 02 — Functional and non-functional requirements

Status: proposed acceptance contract, 22 October 2026. P0 = required before the affected capability is exposed; P1 = required during the initial Tutor rollout; P2 = future compatible seam only. Dependencies are requirement IDs. Q = educational gates in document 12; API/data contracts are in 05/06. A checked source file is not an implemented requirement.

## Functional traceability

| ID | Priority | Required behavior and acceptance evidence | Dependencies / design |
|---|---|---|---|
| FR-01 | P0 | Subject→Topic→Subtopic→Skill, ordered placements and stable IDs; publish rejects cycles, orphan skills and redundant fragments | 06; editorial scope review |
| FR-02 | P0 | One versioned topic JSON includes structured `skill_ai_scope`, outcomes, exclusions, prerequisites, misconceptions, sequence and assessment coverage; import/export roundtrip is semantically equal | FR-01; 06/07 |
| FR-03 | P0 | Validated JSON imports to immutable PostgreSQL revisions; atomic release pointer; existing progress survives rename/reorder and explicit split/merge mapping | FR-02; 06/13 |
| FR-04 | P0 | Select/start/continue/restart/next and interrupted resume return correct owned skill, pinned content and confirmed progress, including two-device conflict test | FR-03,21; 05/11 |
| FR-05 | P0 | Generate a structured lesson from approved skill and effective learner preferences; coverage and correctness gate before display; never include identity in a shared artifact | FR-02,18,21,36 |
| FR-06 | P0 | Concrete example precedes new vocabulary; each outcome has demonstration, guided check and independent application; later steps require only prior teaching/prerequisites | FR-05; Q beginner and teacher reviews |
| FR-07 | P0 | Natural short sentences, defined vocabulary, visible reasons/intermediate steps; beginner reviewer can explain the method without prior topic knowledge | FR-06; Q language rubric |
| FR-08 | P1 | Continue, typed doubt, simpler/more detail/example/analogy/language/already-understand controls preserve session context and prevent stale response attachment | FR-04,05; 05/11 |
| FR-09 | P0 | Tutor DTO has no deadline or timeout grading; no countdown UI; optional duration never reduces mastery or blocks progression | FR-04; Flutter/API contract tests |
| FR-10 | P0 | Completion requires independently successful outcome evidence, hints/repeats tracked; mastery and completion are separate; retry failure cannot silently count as mastery | FR-24,36; 08 |
| FR-11 | P1 | Every screen has accessible text and equivalent optional spoken content; mute/off/failure paths teach the full same skill | FR-05,16; 09 |
| FR-12 | P1 | Existing app logo is initial tutor representation; asset can change behind a mascot adapter without session/schema migration | 09/11 |
| FR-13 | P1 | Warm, clear mature male voice shortlist evaluated by listeners in each released language; age/persona is listener judgment, not inferred from gender metadata | FR-30,40; 09 |
| FR-14 | P1 | Persistent narration preference, explicit mute/replay/pause behavior; Continue and answer stop obsolete audio immediately; lifecycle/network tests pass | FR-11; 09 state table |
| FR-15 | P1 | Speaking feedback follows actual player state, reduced motion supported; failed animation never blocks text or input | FR-12,14 |
| FR-16 | P0 for audio | Math AST/text and spoken representation agree on grouping, signs, symbols and precision; native-language reviewer checks Hindi/Tamil/Hinglish before audio release | FR-36; 09/12 |
| FR-17 | P1 | Speech usage/INR metering, reuse and limits included in all applicable operating scenarios; no synthesis for muted/off sessions | FR-21,38; 09/10 |
| FR-18 | P0 | Distinguish mathematical readiness from explanation detail; explicit language/goal/preferences; no unsupported learning-style label; scope never shrinks | FR-01; 08 |
| FR-19 | P1 | Ask language and optional goal, offer skippable diagnostic and readable detail choices; defaults/editability tested without exposing numeric depth sliders | FR-18; 08/11 |
| FR-20 | P1 | Bounded in-session scaffolding adapts; explicit persistent settings win; visible proposals/undo for durable changes; no language/goal override | FR-18,24; 08 |
| FR-21 | P0 | PostgreSQL stores generated immutable artifacts and review lineage; compatible requests reuse by versioned key; private doubts never enter shared cache | FR-03,05; 06 |
| FR-22 | P1 | Bounded cache uses existing Redis for approved shared content; publication/quarantine authorization cannot be bypassed by stale cache | FR-21; 04/05 |
| FR-23 | P1 | One-step lookahead with quotas; next-skill cached/fallback useful content meets target; no speculative per-learner combinatorial generation | FR-21,38; 10 |
| FR-24 | P0 | Append facts for attempts, hints, retries, doubt/help events, progression and preference changes, with source/evidence IDs; no inferred misconception saved as fact | FR-04; 06/08 |
| FR-25 | P1 | Deterministic strengths/coverage/trends plus optional evidence-cited interpretation; no unsupported psychological or speed claim | FR-24; 08 |
| FR-26 | P1 | Cheap aggregates after committed attempts; debounced narrative analysis after meaningful evidence/session completion; no model call in answer transaction | FR-24,38; 08 |
| FR-27 | P1 | Feedback cites actual evidence window and distinguishes few observations from established pattern; unsupported numbers/claims rejected | FR-25; Q analyzer fixtures |
| FR-28 | P0 | Analyzer receives allowlisted snapshots, no SQL or DB credentials; validated service persists versioned interpretations with audit and supersession | FR-24; 05/06/14 |
| FR-29 | P2 | Skill/outcome/evidence IDs exported through a read contract for future targeted practice; no practice question-generation implementation | FR-10,25 |
| FR-30 | P0 | Dated official model, price, limits and modality research; actual account access distinguished; representative synthetic tests or disclosed access failure | 07,09,SOURCES; FR-38 |
| FR-31 | P0 | Route workloads using AptiQu teaching evidence; candidate selection provisional until Q passes; higher model cost justified per failure family | FR-30,32–37 |
| FR-32 | P0 | Personally inspect generated sample successful and wrong paths from beginner view; record skipped steps and terminology with screen references | FR-39; 12 |
| FR-33 | P0 | Separate teacher review verifies scope, reasoning, assessments and profile fit; both review perspectives must pass | FR-32,36 |
| FR-34 | P0 | Each new challenge connects to a demonstrated prior operation; no sudden difficulty jump; independent final application uses changed values | FR-06; Q progression rubric |
| FR-35 | P1 | Prompt changes map to specific observed failures; preserve baseline, fixture and versions; limited retest within budget | FR-37–39; 07/12 |
| FR-36 | P0 | Independently evaluate math, answer IDs, semantic option uniqueness, hints, retry facts and exact notation; unsupported verifier families require teacher release | FR-05; 12 |
| FR-37 | P0 | Standard scorecard with evidence, blocking defects, pass thresholds and voice status; valid JSON alone cannot pass | FR-32–36; 12 |
| FR-38 | P0 | Live tests ≤₹100 and ≤10 paid requests; local tighter plan ≤₹10/6, token ceilings, sequential dispatch, persisted reservations, no uncontrolled retries | evaluation/PLAN.md; 10 |
| FR-39 | P1 investigation | Compare beginner/advanced outputs when account access allows; preserve raw samples, manually review, report actual failures; fixtures remain usable offline | FR-30,32,38 |
| FR-40 | P0 | No unnecessary speech tests; any future paid audio test reserved within the same remaining investigation allowance or newly approved budget | FR-17,38 |
| FR-41 | P0 | Read only named keys when needed; use secret injection/local ignored config, never ask for pasted values; disclose privileged agent file access | 14; evaluation harness |
| FR-42 | P0 | No real secrets in code/docs/logs/screenshots/errors/model prompts; allowlisted provider-error logging and artifact scan | FR-41 |
| FR-43 | P0 | Exact local secret paths ignored/untracked verified; production secrets server-side; checks do not imply history/artifact secrecy | FR-41; 01/14 |
| FR-44 | P0 | Separate dev/prod projects, model permissions, rate limits, INR admission reservations, alerts and provider hard-limit verification; explain lag/soft alerts | FR-38; 10/14 |
| FR-45 | P0 | Confirm only requested credential availability without values; missing access never blocks architecture; no rotation/deletion/modification | FR-41; evaluation/RUN_LOG.md |

## NFR acceptance targets

Targets below are proposed service objectives under admitted load, not current measurements or contractual promises. Region, device and network must be included in later reports.

| ID | Priority | Acceptance criteria | Dependency / evidence |
|---|---|---|---|
| NFR-01 | P0 | Local pending response ≤100 ms; cached lesson first useful screen p95 ≤600 ms; committed Continue/answer p95 ≤300 ms on reference network; cached audio start p95 ≤900 ms; cold generation target ≤20 s after admission but approved fallback within 1 s | 05/10; offline fake-provider + later real-device tests |
| NFR-02 | P0 | Zero known blocker in released artifacts; all required outcomes mapped to visible instruction/practice; both human perspectives pass | 12 |
| NFR-03 | P1 | Capacity plan for 100/1,000/10,000 concurrent learners includes action/AI/voice QPS and quotas; load test mocked providers before any paid performance test | 10; actual capacity unverified |
| NFR-04 | P0 | Every financial output INR; dated conversion, token/audio units, taxes and exclusions explicit | 10/SOURCES |
| NFR-05 | P1 | Generation/reuse/doubt/analysis/narration/session/monthly unit costs and miss-rate sensitivity reproducible | 10 formulas |
| NFR-06 | P0 | No lost acknowledged answer; idempotent replay; safe pinned resume; recoverable outbox/job crash; text usable on audio outage; generation fails closed | 05/13 |
| NFR-07 | P0 | Minimize minors' data, evidence-based consent policy, access scopes, deletion/retention and provider contracts; legal review before child rollout | 06/14 |
| NFR-08 | P0 | Owner-scoped APIs, signed audio access, answer-key redaction, injection containment, admin audit, scoped service credentials, spend abuse limits | 05/14 |
| NFR-09 | P1 | One codebase and shared types/contracts; existing infrastructure reused; extracting a service requires measured bottleneck | 03/13 |
| NFR-10 | P1 | Correlated request/job/artifact IDs, latency, queue age, usage, INR reservations/actuals, cache/quality/audio/progression counters; no raw learner prose in normal logs | 04/10 |
| NFR-11 | P0 | One meaningful step per bubble; 320 px width and 2× text; no aligned-space diagrams; controls reachable with keyboard and bottom insets | 11/12 |
| NFR-12 | P0 | Text-only complete flow, readable math semantics, labelled 48 px controls, screen reader/keyboard focus, reduced motion, no color-only state | 09/11 |

## Cross-cutting policy and assumptions

The first release serves a reviewed subset of skills and languages. English is the initial text-quality pilot; Hindi, Tamil and Hinglish are designed and fixture-planned, but each needs native-language validation before exposure. This is a rollout boundary, not removal of multilingual requirements. Narration remains optional and separate from text release.

The 1–9 personalization proposal is evaluated rather than adopted literally. Mathematical target scope belongs to the curriculum/goal; readiness controls prerequisites and scaffolding. Preference detail changes wording and examples, not required outcomes. A learner saying “I already know” may take an untimed diagnostic but cannot self-award mastery.

One topic JSON is the reviewed authoring artifact; published DB revisions are the runtime authority. Legacy individual scripts remain backup/reference and the compatible legacy runtime during transition, not the new primary authoring mechanism. No step in this plan extracts objective questions or creates a standalone question bank.

Assumptions requiring future confirmation: account quotas/model entitlements; actual deployment/DB native constraints; licensed rights to reuse source prose; target age policy and jurisdictions; regional hosting requirements; suitable voice by listening; observed learning gains. Dependencies do not authorize database operations or deployment now.
