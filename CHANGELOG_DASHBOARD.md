# AptiQu Admin Dashboard — Release & Update Log

All notable changes, version updates, and UI enhancements for the AptiQu React/Vite admin operations portal.

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
