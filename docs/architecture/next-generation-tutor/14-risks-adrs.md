# 14 — Risks, security, privacy and architecture decisions

Status: proposed decisions for user review, 22 October 2026. Owners below are roles to assign, not people already appointed. Architecture approval does not imply legal compliance, vendor entitlement, quality certification or production release readiness.

## Risk register

| ID | Risk / evidence | Severity | Mitigation and release gate | Owner |
|---|---|---|---|---|
| R01 | Model returns valid JSON with wrong answer IDs; observed four mismatches across v1 samples | Critical | Application-owned verified assessments, independent math/reference checks, teacher release; zero known blocker | Teaching/AI lead |
| R02 | Prompt revisions improve keys but omit questions; observed eight incomplete v2 prompts | Critical | Single canonical item object drives display/options/grade; contract completeness and learner-path review | Backend/QA |
| R03 | False diagnosis condemns valid equivalent math; observed in all reviewed Luna variants | High | Semantic review, qualified feedback, no assumption of mistake from isCorrect alone | Teacher reviewer |
| R04 | Direct Gemini API terms conflict with likely under-18 audience | Critical rollout constraint | Confirm eligible provider contract/service or do not use that route in school/minor-facing client | Product/legal |
| R05 | Children's data processed without appropriate consent, safeguards/retention | Critical | Age policy, minimization, verifiable consent where required, vendor terms/ZDR review, deletion process | Privacy/product |
| R06 | Repeated paid dispatch after uncertain timeout/crash | High | Durable reservation/dispatch IDs, fenced lease, one retry owner, retain uncertain holds | Backend/operations |
| R07 | Personal text reused across learners | Critical | Shared artifacts identity-free; private help/audio separate owner scope and keys | Backend/security |
| R08 | Cold generation/review creates long waits | High | Prepublished launch catalog, compatible fallback, honest pending state, bounded variants | Content/product |
| R09 | Voice dominates costs on misses | High | Clip reuse, opt-in, bounded prefetch, INR admission and speech quality gates; sensitivity in 10 | Operations/product |
| R10 | Audio changes grouping/signs or leaks answers | Critical for narration | Shared semantic math, speech compiler/lexicon, native transcription checks; disable unsafe clip | Voice/teacher |
| R11 | Legacy completion incorrectly becomes mastery | High | Explicit mapping and provenance; legacy-completed distinct from independently demonstrated | Data/education |
| R12 | Existing singleton roles/DB constraints disturbed by new workers | High | Preserve realtime/jobs ownership, bounded pools, additive reviewed migrations and isolated tests | Backend/operations |
| R13 | Teacher/native review cannot scale | High | Limited launch variants and review staffing; only later gated family-based automation | Content/product |
| R14 | Broad admin access/localStorage token increases exposure | High | Permission matrix, stronger operator auth/session handling, audit, minimized analytics | Security/dashboard |
| R15 | Source licensing or ambiguous extraction copied into generated content | High | Rights review, conceptual reuse over verbatim replication, source-page verification | Content/legal |
| R16 | Model alias or provider terms/prices change | Medium/high | Config/price versions, canary fixtures, dated research, reversible gateway routing | AI/operations |
| R17 | Analyzer overstates sparse evidence | High | Deterministic facts, claim evidence IDs, confidence/uncertainty, review/undo | Learner analytics |
| R18 | Offline UI invents acknowledged progress or stale help/audio attaches | High | Stable operation identities, server revision, local epoch/account scoping, no local mastery guess | Flutter |

## Credential handling and financial protection

The user explicitly asked not to read `.env` until needed. Repository investigation excluded secret files. At live-evaluation time the harness attempted only the requested provider's named key; a name-only diagnostic found the actual OpenAI variable `OPEN_AI_API_KEY` in `backend/.env`. Values were never printed, embedded in prompts, copied into fixtures or changed. The exact ignored paths were checked with Git and were untracked; no full history/artifact scan or account-wide secrecy claim was made.

A local ignored file is a developer convenience, not an absolute boundary against an agent/process with file access. In implementation, prefer an approved OS/cloud secret store or process injection with restricted filesystem/account permissions. Avoid secrets in shell arguments, screenshots, URLs, logs, crash payloads and generated documentation. Never ship a provider key in Flutter assets, binaries or client HTTP requests. No credential rotation/deletion was performed or requested.

Use separate dev/staging/prod projects, least-privilege service credentials, model allowlists, API restrictions/IP/identity controls where supported, and operator access audit. Verify supported restrictions per provider rather than promising generic “key restrictions.” The app gateway owns global/per-user/workload rate, token/audio bounds and INR reservations. Cache/job retries cannot bypass these controls. Never allow model-generated tool calls to retrieve keys or modify budget settings.

Current [OpenAI spend controls](https://developers.openai.com/api/docs/guides/spend-limits) include distinct hard limits and alerts; hard enforcement has lag. Current [Google spend-cap budgets](https://docs.cloud.google.com/billing/docs/how-to/budgets-spend-caps) cover selected services, while alerts-only budgets do not stop traffic. Verify account permissions/configuration and service coverage; do not claim an exact zero-overshoot fence. No provider control was changed here. An application reservation ceiling protects only traffic passing that gateway, not unrelated usage of the same key/project.

## Provider eligibility and children

[Gemini Developer API terms](https://ai.google.dev/gemini-api/terms), effective 23 March 2026, restrict applications directed at or likely accessed by under-18s. This affects AptiQu's intended school audience, not merely whether the developer is an adult. Paid tier does not by itself resolve eligibility. Do not assume moving to an enterprise/cloud endpoint grants permission: confirm that endpoint's actual terms, geography and contract. Until resolved, direct Gemini is an adult synthetic research/integration candidate, not the default minor-facing provider.

[OpenAI under-18 guidance](https://developers.openai.com/api/docs/guides/safety-checks/under-18-api-guidance) calls for age-appropriate safeguards and zero data retention before processing personal data of under-13s or the applicable digital-consent age. Provider approval/eligibility must be verified; using `store:false` removes application storage where supported but is not identical to zero abuse-monitoring retention. [OpenAI data controls](https://developers.openai.com/api/docs/guides/your-data) distinguish training use, application state and abuse monitoring.

Avoid collecting a complete DOB solely for personalization. A legally reviewed age-band/guardian-consent flow can minimize data while meeting assurance needs. Existing optional profile DOB does not prove lawful child processing or verified parental consent. A child mode needs clear AI disclosure, safe math-only contextual help boundaries, age-appropriate error/support handling and reporting/escalation. Minimize stored free-text and ensure support access is permissioned. No child conversations or real learner data were sent in the research tests.

## India privacy obligations and limits

The [official DPDP Rules 2025 Gazette](https://www.meity.gov.in/static/uploads/2025/11/53450e6e5dc0bfa85ebd78686cadad39.pdf) uses phased commencement: some rules on publication, Rule 4 after one year, and Rules 3/5–16/22/23 after eighteen months. As of 22 October 2026, do not describe all provisions as already fully in force or treat the transition as permission to ignore privacy. Confirm exact applicable commencement/corrigenda and business obligations with legal review before release.

The government [student-data clarification](https://www.pib.gov.in/PressReleasePage.aspx?PRID=2202901&reg=48&lang=2) discusses verifiable parental consent and limited educational-institution exceptions. AptiQu cannot assume it qualifies for an institution exemption simply because it teaches mathematics. Behavioral analysis of children, profiling/targeted ads and cross-border vendor transfers need explicit legal/product treatment. Do not monetize or optimize around sensitive-trait inferences. If expanding abroad, assess COPPA/GDPR and local digital-consent rules separately; this package does not claim worldwide compliance.

Required deliverables before child rollout: concise localized privacy/AI notice, purpose/legal-basis and processor register, age/guardian mechanism where required, consent withdrawal/access/correction/deletion support, incident response and retention schedule. The existing deferred policy-link UI is not a completed privacy notice. Do not activate misleading links or fabricate a compliance badge.

## Threat model and controls

| Boundary | Threat | Proposed protection / test |
|---|---|---|
| Learner API | IDOR, forged answer/user/skill scope, replay | Token-derived user, owner+artifact checks, server grades, stable receipts/request hash and revision conflicts |
| Prompt | Learner/source text asks to ignore scope/reveal answers/run SQL | Treat as data; no external tools; allowlisted context; private output validation; test injection fixtures |
| Generated content | Unsafe markup/links, executable text, enormous blocks | Typed text/math grammar, bounded lengths, no raw HTML/script/eval, strict renderer and parser |
| Shared cache | Stale publication, cross-user data, poisoned keys | Canonical server keys, no private payloads, publication check outside cache, quarantine freshness |
| Queue/worker | Duplicate delivery, stale lease, spending amplification | Durable logical identity, fenced dispatch, global INR hold and one retry owner; no blind post-send replay |
| Audio | Arbitrary TTS abuse, leaked private narration/answer | Owned screen/digest request only, signed short-lived URL, private namespace, no answer narration before attempt |
| Admin | XSS/token theft, excessive learner access, malicious publish | Stronger auth/MFA/session review, server RBAC, audit, content security and diff/review gates |
| Persistence | Cascading erasure loses audit/integrity or backup restores deleted data | Explicit erasure orchestration, legal retention/anonymization, backup erasure manifest and restore drill |
| Observability | Logs expose keys/child prose or high-cardinality identity | Allowlisted codes/metrics, redaction, access/retention, artifact secret scans without printing values |

TLS, encrypted disks/backups, secrets separation, restricted database/network access and dependency patch management are necessary operations controls. They remain future deployment verification, not completed source claims. A provider cannot validate its own explanation's math merely by returning a “confidence” field.

## Architecture decision records

| ADR | Decision / status | Alternatives rejected and reason | Revisit trigger |
|---|---|---|---|
| ADR-001 | Proposed: modular existing backend + workers | New microservice/agent platform adds overhead without teaching benefit | Measured ownership/SLA/scaling boundary |
| ADR-002 | Proposed: structured curriculum JSON authored; immutable DB release runtime | Parse filesystem on every request; mutable rows invalidate sessions | Authoring collaboration requirements change |
| ADR-003 | Proposed: stable Skill/outcome identities and versioned scope | Subtopic-as-unit too broad for evidence; one fact per micro-skill too fragmented | Teacher/learner pilot scope feedback |
| ADR-004 | Proposed: reviewed reusable generated lessons + private help | Per-turn/per-learner full generation drifts, waits and duplicates review | Learning outcome/reuse evidence disproves benefit |
| ADR-005 | Proposed: deterministic assessment truth and progression | Trust generated answer IDs or LLM autonomous completion; observed failures | New verified family capability, not model marketing |
| ADR-006 | Proposed: explicit preferences, bounded scaffolding and visible proposals | Numeric 1–9 controls and fixed learning-style labels not intuitive/supported | Usability/evidence improves parameter model |
| ADR-007 | Proposed: deterministic analyzer core, optional asynchronous narrative | LLM after every answer or unrestricted DB agent costs/risks too much | Proven educational benefit of finer cadence |
| ADR-008 | Proposed: reuse Redis/BullMQ, DB outbox/reservations authoritative | New cache/streaming platform or Redis-only durable progression | Measured availability/throughput requirement |
| ADR-009 | Proposed: whole accepted artifact before learner display | Streaming unvalidated math improves token latency but risks teaching errors | Proven safe validated incremental composition |
| ADR-010 | Provisional candidate: Luna after quality improvements; provider eligibility gate | Current live samples fail, Gemini comparison unavailable, no model gets automatic promotion | Teacher-reviewed multi-skill/locale evidence |
| ADR-011 | Provisional candidate: Chirp 3 HD + speech compiler/cache | Text model as assumed TTS; immediate real-time voice stack unnecessary | Native listening, terms/latency/cost evidence |
| ADR-012 | Proposed: logo adapter, no lip sync required | Final character generation/complex synchronization outside scope | Approved future mascot brief |
| ADR-013 | Proposed: additive legacy coexistence and explicit evidence mapping | In-place session rewrite or automatic mastery backfill corrupts meaning | No live/retention legacy dependencies |
| ADR-014 | Proposed: INR pre-reservation + provider controls + reconciliation | Alerts alone or timeout=free assumption cannot bound spend | Provider financial/usage interfaces change |
| ADR-015 | Proposed: child-product eligibility/consent gates before personalized inference | Treat paid key or `store:false` as blanket compliance | Approved legal/vendor contract and child safeguards |

## Open decisions and recommended defaults

| Decision needed | Recommendation now | Work that can proceed without it |
|---|---|---|
| Launch age range/provider terms | Begin an adult/synthetic development pilot; resolve child route explicitly before school rollout | Curriculum contracts, deterministic fixtures, architecture review |
| First launch skill set/languages | 3–5 coherent skills, English text first; design locales now and release only after native approval | Scope decomposition draft and schemas |
| Human review staffing/allowance | Limit variants to reviewed capacity; budget INR labor in 10 | Reuse/evidence contracts |
| Final mature male voice | Audition Charon/Schedar and alternatives with native listeners; no claimed winner yet | Speech representation and playback adapter |
| Meaning of durable mastery | Transparent outcome evidence + delayed retrieval before calibrated score | Deterministic attempts/independence tracking |
| Existing deployment/DB drift | Inspect only when specifically authorized; preserve source-only assumptions | Offline schema/API design |
| Source rights | Verify permitted use before broad reproduction/publication | New concept explanations with traceable source principles |
| Cold artifact without approved fallback | Truthful pending + available related skill; do not show a draft | Prewarm launch catalog and admin review flow |

None of these required stopping the architecture investigation. They are explicit implementation/rollout gates, not excuses to leave documentation incomplete.
