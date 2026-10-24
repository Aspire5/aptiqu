# AptiQu next-generation tutor architecture

**Decision package for review — 22 October 2026. No implementation or release approval is implied.**

Repository baseline: `252fa1b`. Investigation is source-only except the isolated, bounded synthetic API evaluation recorded under [evaluation](evaluation/PLAN.md). No application source, existing content, database, deployment, credential or infrastructure configuration is changed by this package.

## Read in this order

Start with [15 — Executive architecture summary](15-executive-summary.md), then [03 — Architecture decision](03-architecture-alternatives.md), [12 — Educational quality and actual evaluation](12-educational-quality-evaluation.md), and [13 — Implementation roadmap](13-migration-roadmap.md).

| Document | Purpose |
|---|---|
| [01 — Existing system](01-existing-system-assessment.md) | Confirmed repository evidence, reusable foundations and limitations |
| [02 — Requirements](02-requirements.md) | All 45 FRs and 12 NFRs, dependencies and acceptance criteria |
| [03 — Alternatives](03-architecture-alternatives.md) | Independent comparison and recommended design |
| [04 — HLD](04-high-level-design.md) | Components, trust boundaries, data flows and deployment shape |
| [05 — LLD](05-low-level-design.md) | Modules, API contracts, transactions, sequences and recovery |
| [06 — Data](06-data-architecture.md) | Topic JSON, immutable revisions, relational entities and consistency |
| [07 — AI](07-ai-models-prompts.md) | Verified capabilities, model routing, prompts and versioning |
| [08 — Personalization](08-personalization-analyzer.md) | Onboarding, mastery evidence, analyzer and learner control |
| [09 — Voice](09-voice-mascot.md) | Voice selection, math speech, playback and replaceable logo mascot |
| [10 — Performance and costs](10-performance-scalability-costs.md) | Workload arithmetic, targets, INR estimates and spending controls |
| [11 — Flutter and dashboard](11-frontend-dashboard.md) | Journeys, existing components, accessibility and admin operations |
| [12 — QA](12-educational-quality-evaluation.md) | Human rubrics, checks, sample observations and release gates |
| [13 — Roadmap](13-migration-roadmap.md) | File-level phased implementation, tests, rollback and approvals |
| [14 — Risks and ADRs](14-risks-adrs.md) | Security/privacy, decisions, uncertainty and ownership |
| [15 — Executive summary](15-executive-summary.md) | Recommendation and first milestone |
| [Sources](SOURCES.md) | Dated official research and evidence limitations |
| [Validation record](VALIDATION.md) | Executed package checks, experiment totals and verification limits |

## Evidence conventions

- **Confirmed** means read in the checked-out source or returned by a recorded live request. Source presence does not prove deployment or production health.
- **Proposed** means a future contract, policy, target or estimate. Tables and diagrams below describe the recommended system unless marked current.
- **Unverified** means it needs a device, provider-account, legal, learner or authorized infrastructure check. No measured percentile or learning outcome is fabricated.
- Monetary estimates are INR only. Planning conversion: ₹95 per provider USD billing unit, checked against the dated FX reference in [Sources](SOURCES.md). Taxes and buffers are explicit in document 10.

## Non-negotiable boundaries

Keep Tutor Mode untimed. Text always works without speech. Curriculum scope is authoritative; personalization cannot remove required outcomes. Persist shared generated lessons in PostgreSQL, keep personal exchanges private, and make completion evidence-based. Preserve legacy sessions, XP receipts and unrelated product behavior. No voice input, final mascot artwork, Practice/PvP generation redesign, database actions, VPS connection, migrations or deployment in this assignment.

Approval is requested for the architecture and a future phase only after this package has been reviewed. No further paid test or production implementation should be inferred from delivery.
