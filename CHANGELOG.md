# AptiQu changelog

One product history across the Flutter app, backend/API, data and infrastructure code, and admin web interface. All entries below are **development milestones**, not public releases or deployment claims. Product milestone numbers are assigned retrospectively from verified Git history; they are not Git tags, package versions, or mobile build numbers.

The older `CHANGELOG_APP.md`, `CHANGELOG_BACKEND.md`, `CHANGELOG_DASHBOARD.md` and `releases/release_manifest.json` are historical service records. Their independent versions and production labels are not the current product release status. This file is the canonical history. The first public release, **v1.0.0**, is reserved; Google Play launch is targeted for **8 November 2026 (Diwali)**. It has not been released.

## [Unreleased] — Development

### Added
- Public product landing page with genuine Flutter preview renders, app theme comparison and a unified development timeline.
- Public root route and isolated protected admin routes under `/dashboard`.

## [0.0.6] — 2026-10-20 · Ranked competition and platform reliability

### Added
- Elo-based Ranked leagues, qualification, monthly seasons, leaderboard and season history across the mobile app and backend.
- Original Unranked, Bronze, Silver, Gold, Platinum and Diamond badge presentation.

### Improved
- Backend request handling, background work, caching and session consistency across learning and competition.

Evidence: `9bdcd64` (Ranked implementation) and `4bf0d31` (backend hardening). Implementation exists; runtime activation and deployment are separate operator decisions.

## [0.0.5] — 2026-10-19 · A consistent learning experience

### Improved
- Shared mobile typography, accessible controls and coordinated Light, Dark and System appearance.
- Learning, Practice, profiles and social screens refined around the existing product behavior.

### Added
- Friends, learner profiles and friendly challenge flows.

Evidence: `7042ec7`, `7f1038c`, `810d02b`, `6cdf838`. Friends work began on 15 October; this date marks the grouped UI milestone.

## [0.0.4] — 2026-10-14 · Progress you can follow

### Added
- Home learning progress, performance information and an initial achievement system.
- Expanded lesson material and subtopic-specific learning paths.

### Improved
- Practice topic selection and script targeting.
- Data migration organization in repository code.

Evidence: `ff62e8f`, `056575b`, `dddae83`, `b69d53c`, `b92ce61`, `f0468a0`. This records code changes, not execution of migrations.

## [0.0.3] — 2026-10-02 · A stronger content foundation

### Added
- Book-based curriculum, previous exam question provenance and alternative worked solutions.
- Curriculum ordering, reusable topics and subtopics, and content import validation.
- Administrative question, curriculum and prompt management with draft and published states.

Evidence: `7bc3d12`, `af0159b`, `31bf990`, with original service notes retained in the historical changelogs.

## [0.0.2] — 2026-09-30 · Practice and play

### Added
- Random and topic-based Practice sessions with answer feedback.
- Initial head-to-head question play and daily learning streaks.
- React admin interface for product operations.

Evidence: `d0700fc`, `2f2e441`, `197b6cf`, `88227cf`, `648c662`. The early head-to-head implementation is distinct from the later completed Elo league system.

## [0.0.1] — 2026-09-25 · The learning foundation

### Added
- Initial Flutter learning app and supporting API/data models.
- Curriculum roadmap and step-based lesson progression.

Evidence: `b451208`, `2621b8a`, `5db1979`. This is the earliest verifiable repository milestone, not the historical mobile build numbered 0.0.1+1.

## [1.0.0] — Reserved public launch

Target: 8 November 2026, Diwali, on Google Play. Not released. Individual roadmap features have no committed release date.

## Maintaining this history

Keep meaningful work under Unreleased until it forms a verified milestone. Then add a descending `## [0.0.x] — YYYY-MM-DD · Short title` section with Added/Improved/Fixed/Changed bullets and supporting commit references. Use dates of verified development, never invented release or deployment dates. Do not renumber published milestones or infer product versions from package files. Keep v1.0.0 reserved until the public release is verified.

The landing page imports this file at build time and displays a short selection of milestone bullets. Rebuild the frontend after updates. There is no second hand-maintained public history, Git hook or release automation.
