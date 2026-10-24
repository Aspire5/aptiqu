# 15 — Executive architecture summary

**Build a skill-based tutor inside the existing stack, with reusable generated lessons, deterministic assessment and private adaptive help.** Keep Flutter, Express/TypeScript, Prisma/PostgreSQL, Redis/BullMQ and the React dashboard. Additional autonomous agents, microservices and a vector database are not justified for the initial product.

## Recommended product and architecture

Author one topic JSON containing approved subtopics and individually assessable skills. Each skill defines outcomes, prerequisites, teaching sequence, examples, misconceptions, notation and exclusions. Publish immutable revisions into PostgreSQL. Store generated lesson artifacts there, reuse accepted variants across compatible learner requests, and pin each session to the exact content and scope it started with.

The LLM composes explanations and answers bounded contextual doubts. The application owns mathematical assessment truth, option/answer references, session transitions, evidence-based completion, permissions and cost admission. Deterministic statistics provide basic learner analysis; optional asynchronous model interpretation must cite actual evidence and cannot directly edit facts or learner preferences.

Personalization asks language and optional goal, with understandable More steps/Shorter explanations and skippable diagnostics. Use a few scaffold cohorts rather than a 1–9 parameter explosion or unsupported fixed learning styles. Explicit learner settings remain authoritative. Private help is never shared with other learners.

Tutor Mode stays untimed. Adapt existing Home/routed lesson surfaces through a shared coordinator, preserve the approved palette/type/tokens, and show short connected text/math screens. Narration is optional, with the existing app logo behind a replaceable mascot adapter. Continue/answer stops obsolete audio immediately; text never waits for speech or animation.

## Model and voice decisions

**GPT-6 Luna is a low-cost candidate, not a validated production selection.** Gemini 3.5 Flash-Lite is the repository's actual default/challenger; anticipated Gemini 2.5 has current access restrictions. Six controlled dispatches produced three Luna samples and three provider rejections. Every returned sample failed release checks. Two baseline samples had four stored answer-ID/value mismatches; a fixture-based prompt revision fixed keys but omitted all eight question expressions and retained teaching flaws. This directly supports application-owned assessment objects and human pedagogical review. [Actual QA evidence](12-educational-quality-evaluation.md).

Use stronger models selectively only when they demonstrably improve accepted teaching quality. Do not use a second LLM as a mathematical proof or assign Tutor/Analyzer to separate vendors by assumption. Direct Gemini API terms restrict applications likely accessed by under-18s; school rollout needs an eligible contract/service. OpenAI also has specific child-data/retention safeguards. These are rollout gates, not resolved by a paid key. [Provider eligibility](14-risks-adrs.md).

Google Cloud Chirp 3 HD is the narration candidate, with English India/Hindi/Tamil male voice shortlists; final mature, reassuring teacher persona requires listening. No audio test or final mascot generation occurred. Current OpenAI legacy speech documentation has a deprecation inconsistency and is not a committed new dependency. [Voice design](09-voice-mascot.md).

## Responsiveness and quality

Proposed targets: cached first useful lesson p95 ≤600 ms, committed Continue/answer ≤300 ms, restore ≤800 ms and cached audio start ≤900 ms on a defined reference network. Existing accepted lessons need no model call per Continue. Cold drafts target ≤20 seconds after admission but the tiny live samples took ~27 seconds; this target is unproven. Prepublish launch content and offer approved fallback/pending states rather than exposing unvalidated streamed math.

Quality gates combine exact math/reference checks, scope coverage, successful/wrong-path review, phone previews and separate beginner/teacher rubrics. Initial novel skill/locale/variant publication needs accountable teacher approval. No current sample or model is educationally certified; multilingual, native voice, device, load and learning-outcome tests remain future gates.

## INR outlook

Planning conversion ₹95/USD, checked 22 October 2026; baseline excludes free credits. Luna skill composition at 6k input/6k output is ~₹0.342 per attempt; a bounded doubt ~₹0.03325; narrative analysis ~₹0.035625. First Chirp synthesis for 8,000 characters is ~₹22.80, with no repeat synthesis fee for stored audio. Review labor and audio reuse dominate text-token savings.

With the explicit assumptions in [10 — Cost model](10-performance-scalability-costs.md), 10,000/100,000/1,000,000 monthly completed sessions cost approximately **₹67,221 / ₹341,785 / ₹1,946,958** including a 25% uncertainty buffer and assumed per-new-variant review labor, before tax and excluded engineering/support/legal/acquisition costs. These are scenarios, not measured bills. A warm steady catalog reduces review costs; unique narration can increase them sharply. High review demand conflicts with a small team, so bound launch variants and measure reuse.

Investigation estimates: ~₹0.49 known successful inference and ₹7.44 conservative reservations across six dispatches, including failed requests; no invoice verification. No speech or load-test spending. The chosen six-request experiment is closed.

## Migration and first milestone

Retain legacy scripts as teaching/reference assets and the current compatible runtime during migration. Preserve pinned sessions, progress/XP receipts and roadmap placements. Legacy completion does not automatically prove mastery of newly split skills. Add curriculum/session/artifact entities with explicit mappings; protect the repository's existing native DB constraints and singleton runtime ownership.

Recommended first milestone: approve 3–5 skill definitions, topic/lesson/API schemas, verified assessment families and evidence policy; then implement one approved skill as a deterministic persisted, resumable text Tutor in the existing Flutter composition. Add generation, private help/analyzer, voice and dashboard operations in the separately reviewed phases of [13 — Roadmap](13-migration-roadmap.md).

This delivery changes documentation and isolated evaluation artifacts only. It performs no production implementation, data modification, migration, VPS connection, infrastructure provisioning or release. Credentials were read only when needed for authorized tests, never displayed or changed. Review the architecture before authorizing an implementation phase.
