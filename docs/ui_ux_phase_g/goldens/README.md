# Individually reviewed golden changes — Phase G

The legacy suites mapped every Google Fonts request to the same Outfit file and also substituted that file for Roboto. G uses the exact approved Outfit/Plus Jakarta Sans weights and native Material icons, then explicitly selects Dark in these legacy dark fixtures so overlays do not accidentally use the test platform's Light default.

Each old/current rendered pair below was viewed and accepted **individually** after that correction. These changes reflect the approved A–F implementations and G's corrected fixture/theme setup. No bulk `--update-goldens` run was used. The next comparison (`practice-custom`) became visible after the preceding Random assertion passed and received its own review.

Dark goldens remain a small regression subset. The G rendered matrix and saved Light/Dark images provide broader coverage; they are not mislabeled as new goldens.

| Baseline | Before | After | Decision / reason |
|---|---|---|---|
| `home-consistency-phone.png` | [Before](before/home-consistency-phone.png) | [After](after/home-consistency-phone.png) | Accept: Approved B palette/type and accessible calendar targets/date-list controls; populated totals and IST unchanged. |
| `home-populated.png` | [Before](before/home-populated.png) | [After](after/home-populated.png) | Accept: Approved reading/metric hierarchy and inherited button foreground; supplied accuracy, attempts and resume destination retained. |
| `home-day-details.png` | [Before](before/home-day-details.png) | [After](after/home-day-details.png) | Accept: Shared themed sheet, visible Close and readable full date; same empty-state message and timezone. |
| `topics-completed-phone.png` | [Before](before/topics-completed-phone.png) | [After](after/topics-completed-phone.png) | Accept: Approved theme/type, readable native Practice/Replay pairs and same completion counts/subtopics. Short-height footer changes are separately covered by G. |
| `friends-search.png` | [Before](before/friends-search.png) | [After](after/friends-search.png) | Accept: Approved E concise search/identity layout and active native Add Friend control; query/relationship operation retained. |
| `friend-requests.png` | [Before](before/friend-requests.png) | [After](after/friend-requests.png) | Accept: Approved E grouped request presentation, actual initial fallback and readable response controls; same pending identity/version actions. |
| `learner-profile.png` | [Before](before/learner-profile.png) | [After](after/learner-profile.png) | Accept: Approved E identity/metric/performance grouping with real initial; source-specific data and response actions unchanged. |
| `learner-profile-large.png` | [Before](before/learner-profile-large.png) | [After](after/learner-profile-large.png) | Accept: Approved E large-text identity and metric wrapping, full content in a scrolling view; no invented avatar or numeric values. |
| `learner-profile-empty.png` | [Before](before/learner-profile-empty.png) | [After](after/learner-profile-empty.png) | Accept: Approved E concise N/A/empty states and quiet grouped metrics; unavailable values remain unavailable. |
| `practice-random.png` | [Before](before/practice-random.png) | [After](after/practice-random.png) | Accept: Approved D compact setup/settings and native selected/busy/action pairs; session/timer/friendly settings unchanged. |
| `practice-custom.png` | [Before](before/practice-custom.png) | [After](after/practice-custom.png) | Accept: Approved D Custom selection and topic list, actual readable selected subject and same selected IDs; original baseline also showed stale Random visual selection. |

[SHA-256 before/after record](reviewed_hashes.json). Source test assertions for IDs, calculations, callbacks and states remain active. Test-only failure images were removed after the review pairs were preserved.
