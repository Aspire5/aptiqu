# AptiQu Admin Dashboard — Release & Update Log

All notable changes, version updates, and UI enhancements for the AptiQu React/Vite admin operations portal.

---

## [1.3.0] — 2026-10-02

### AI Prompts Control Center & Live Zero-Restart Engine
* **New AI Prompts Sidebar Navigation:** Added dedicated `AI Prompts` section in the left navigation sidebar with icon and route.
* **Live Server Prompt Management:** Full dashboard editing for PvP Generation, PvP Integrity Review, Practice Generation, Practice Review, and Daily Challenge system instructions.
* **Draft vs. Live Separation:** Implemented dual-action workflow:
  * `Save Draft`: Persists updates in database without altering live server execution.
  * `Publish to Live`: Hot-swaps the active in-memory prompt cache on the server, taking effect immediately with **zero server restart**.
* **Curriculum Synthesis & OCR Prompt Templates:** Stored textbook OCR and PYQ prompt template in DB under `Manual Reference Prompts` with 1-click clipboard copy for manual ChatGPT/Gemini runs.
* **Daily Challenge Depletion Warning:** Added top-level alert banner on the executive dashboard surfacing critical inventory depletion or low-stock alerts for unused manual PYQs with direct link to bulk import.
* **CRUD Audit & Subtopic Enhancements:** Added missing fields in Syllabus modals: Subtopic `description`, `teachingMinutes`, and `isActive` toggles for Topics and Subtopics.

---

## [1.2.0] — 2026-10-02

### Book Curriculum & PYQ Authoring Tools
* **PYQ & Status Filtering:** Added filter controls for `PYQs Only`, `Non-PYQ`, and review statuses (`PUBLISHED`, `REVIEW`, `DRAFT`) in Question Bank Explorer.
* **Badges & Visual Tags:** Rendered `🏛️ PYQ` badge, `REVIEW REQUIRED` tag, `externalKey`, and `AI Preferred` chips on question rows.
* **Dual Solution & Provenance Inspector:** Expanded question rows show Solution 1 (Book Method) and Solution 2 (Alternative Speed Shortcut) with preference badges and textbook provenance (book, edition, chapter, pages).
* **Comprehensive Question Form Modal:** Added form fields for unique `externalKey`, `pyq`, review status, source type, generation method, full book provenance, and dual solutions with AI preference reason.
* **Enhanced Bulk Importer:** Updated Excel/CSV download template and live preview with curriculum columns: `externalKey`, `subtopicKey`, `pyq`, `sourceBook`, `sourceChapter`, `alternativeExplanation`, `preferredSolution`, `preferredReason`.
* **Strict Script Verification & Import:** Integrated `Strict Import & Verify Refs` action in Lesson Script inspector ensuring all question references exist and match the target subtopic prior to persisting.

---

## [1.1.0] — 2026-10-01

### Curriculum & UX Enhancements
* **Study Order Sequence:** Removed alphabetical sorting from syllabus; topics and subtopics now strictly preserve intended curriculum study order.
* **Interactive Drag-and-Drop Reordering:** Added native HTML5 drag-and-drop handles (`GripVertical`) to reorder topics within subjects and subtopics within topics.
* **Curriculum Reusability & Multi-Link:** Added "Link Topic" and "Link Subtopic" modals allowing existing topics and subtopics to be attached to new subjects/topics without duplicating questions or scripts.
* **Safe Unlink Protocol:** Added safe dissociation actions with confirmation modals ensuring unlinking never deletes the underlying entities.
* **Official Branding:** Integrated official AptiQu logo on the sidebar brand header and authentication login card.

---

## [1.0.0] — 2026-10-01 (Production Release)

### Administrative Features
* **Authentication Portal:** Single-tenant admin credentials gatekeeper with secure session storage.
* **Analytics & Graphs:** Scalable dot-line trend graphs for 24-hour active users, daily registration velocity, and historical daily streak pass rates.
* **Curriculum Management:** Overview and inspector for subjects, topics, and question repositories.
* **User Management:** Searchable tabular roster with progression levels, streak states, and activity timestamps.
