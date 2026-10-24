# 03 — Architecture alternatives and decision

**Recommend a modular backend with reusable generated skill lessons, deterministic session/assessment control, and evidence-based asynchronous analysis.** Use an LLM to compose instruction and answer bounded doubts; do not give an agent control over progression, database queries or publication.

## Decision criteria

Educational correctness/completeness and beginner understanding are veto gates. Within candidates passing those gates, compare perceived latency, evidence integrity, reuse/INR cost, reliability, privacy, small-team maintenance and growth. The table is engineering judgment about design properties; it is not a measured model benchmark. “Strong” does not imply a quality gate has passed.

| Approach | Teaching potential | Correctness control | Typical latency shape | Reuse/cost | Reliability/privacy | Team burden |
|---|---|---|---|---|---|---|
| A. Expand hand-authored legacy graphs | Strong when reviewed; expensive coverage | Human review; current stale/retry defects persist | Fast after retrieval | Low inference, high author time | Predictable; progress migration easy | Rising content maintenance |
| B. Generate the next message on every turn | Flexible, but drift/skipped scope risk | Validating partial prose is hard | Provider dependency on every Continue | Poor reuse; many small calls and long context | Outage disrupts lesson; personal context repeated | Moderate software, high QA |
| C. Generate an entire unique lesson per learner | Coherent planning possible | Full pre-display validation possible | Long cold start per learner | Low sharing; parameter explosion | Private isolation easier, more stored variants | Moderate/high operational and review work |
| D. Autonomous tutor/analyzer agents with tools | Flexible exploration, inconsistent instruction | Multiple uncertain decisions and tool privileges | Serial agent loops create variable waits | Extra model rounds; poor spend predictability | Broad data/injection surface | High; little first-release benefit |
| E. Reviewed generated skill variants + private adaptive help | Coherent reusable core plus targeted support | Full artifact gates; deterministic answers and evidence | Cached turns fast; cold misses need fallback | Shared generation/voice amortized; doubts bounded | Durable/pinned sessions, minimal provider data | Fits existing modules/jobs; recommended |
| F. Early microservices + event streaming platform | No intrinsic teaching advantage | Same model/QA problems as E | More hops and consistency boundaries | More fixed infrastructure and operations | Isolation can help at scale | Disproportionate initially |

E does not mean storing manually scripted hundreds-node subtopics again. The authored input is a topic curriculum specification with assessable skills, supported mathematical families and teaching requirements. Generated lesson artifacts are persisted runtime products with provenance. A teacher reviews the scope and release candidates; the system reuses accepted instruction and creates private explanations when needed.

## What is deterministic and what uses AI

| Responsibility | Mechanism | Rationale |
|---|---|---|
| Curriculum order, prerequisites, scope/version | Authored specification and validation | Required mathematics must not depend on an LLM's memory |
| Lesson explanation/example wording | LLM within skill/outcome constraints | Adds meaningful instructional variation |
| Question mathematical truth | Reviewed family generator + exact evaluator; independently verified authored items for unsupported families | A second LLM is not proof of correctness |
| Option ordering/uniqueness and answer IDs | Application validation | Live sample showed prose/answer mismatch despite valid JSON |
| Continue, grading, remediation routing, completion | Session state machine and outcome evidence | Fast, auditable, replayable |
| Doubts/analogies/private simplification | Bounded LLM call using sanitized pinned context | Useful personalized help without regenerating whole lesson |
| Strengths, weak evidence, revision due | Deterministic aggregates/rules | Basic statistics do not need inference |
| Possible misconception pattern or narrative synthesis | Optional asynchronous LLM proposal referencing observations | Helpful interpretation when evidence is richer than a count |
| Preference changes and mastery updates | Validated application policy | Learner choices and facts must remain authoritative |
| Narration | Dedicated TTS over verified speech text | Text-model capability is not speech synthesis |

## Reuse and personalization tradeoff

Reject a cache keyed by every numeric depth/detail value and full learner history. Initially use three readiness/scaffolding bands and two explanation-detail modes; selected language and curriculum goal/outcome revision remain explicit. Example style participates in the key only when it changes generated content. Coarse cohorts permit sharing, while local branch selection, hints and private doubts accommodate differences. No cross-user free-text, age, name or inferred personal traits enter shared artifacts.

For 1,000 skills, three bands × two details × four languages already permits 24,000 variants before examples or goal forks. Do not pre-generate the entire Cartesian product. Warm common entry variants; cap per-skill active variants and use reviewed compatible defaults with the learner's language preserved. Document 10 quantifies generation and audio miss sensitivity.

## Quality versus latency conflict

Streaming unvalidated generated math would make the first token fast while exposing errors. Do not do that. Publish an immutable complete validated lesson, then deliver its visible screens immediately as the learner advances. For a cold miss, return an owned generation resource and show a preapproved short bridge or compatible published lesson. If no approved content exists, say preparation is pending and offer a related available skill; never manufacture a misleading percentage or claim “ready” before validation.

A new private doubt may stream only after a bounded response chunk passes its applicable safety/math checks; first release can use a short validated full response instead. No universal subsecond cold-generation promise is credible. Measured live elapsed requests in document 12 are small-sample observations and inform a conservative fallback requirement.

## Review scalability decision

Initially every released skill/locale/core variant requires teacher approval and deterministic checks. On-demand drafts persist in PostgreSQL but are not automatically shown merely because a learner asked. Pre-warm the launch curriculum to avoid a human review queue on the normal learner path. This deliberately limits launch coverage while preserving quality.

Later auto-publication may be authorized only for tightly parameterized, already reviewed mathematical families with verified equations/solutions and no new explanatory assertions; ambiguous prose or novel scope stays in review. This is a gated extension, not a claim that arbitrary language can be proven correct automatically. At large scale, a review backlog must reduce eligible variants or fall back to reviewed material, not bypass release gates.

## Infrastructure and boundaries

Keep Express/TypeScript/Prisma/PostgreSQL. Reuse Redis/BullMQ for coalesced generation, audio and analysis jobs; PostgreSQL/outbox is the durable source of pending work. Retain existing realtime ownership separately; new HTTP tutor replicas must not multiply existing singleton jobs/WebSocket owners. Use distinct queues and quota classes so book/PvP jobs cannot exhaust Tutor capacity, without redesigning those features.

Separate worker processes are justified for slow provider calls/PDF isolation. Separate independently deployed services, Kafka, a vector database, agent framework, live speech recognition and lip sync are not justified for v1. Skill-ID retrieval from structured curriculum is enough; add semantic search only after a measured retrieval need.

## Initial model strategy

GPT-6 Luna is the low-cost candidate for shared lesson composition and bounded help, subject to revised-prompt evaluation; it is **not approved by the small test**. Gemini 3.5 Flash-Lite is the existing-code integration candidate and challenger. Gemini 2.5 Flash-Lite is researched but returned an access failure in this account test; no teaching result exists for it. A more capable model such as GPT-6.1 Sol can be reserved for difficult drafts after per-family evidence justifies its extra spend, not invoked for every answer or as an automatic correctness oracle. Deterministic analysis is the default; narrative analysis uses whichever evaluated low-cost provider meets its grounded-output rubric.

Use Google Cloud Chirp 3 HD as the production narration candidate with male voices in English India, Hindi and Tamil; final persona selection requires listening. Current OpenAI speech documentation contains a legacy-model/deprecation inconsistency, so it is a comparator rather than a committed new dependency. See 07/09 and dated [Sources](SOURCES.md).

## Decision exit conditions

Revisit E if controlled learner studies show adaptive private help cannot support outcome learning; if teacher release throughput makes the curriculum commercially impractical; if p95 cached latency fails after profiling; or if isolation/SLA demands exceed modular deployment. Extract a service only when its ownership, scaling or failure boundary becomes measurable. Architecture approval does not waive model-quality, legal, migration or deployment gates.
