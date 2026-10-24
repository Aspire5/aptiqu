# 08 — Personalization, mastery and learner analysis

**Adapt the assistance to the learner while keeping mathematical objectives explicit.** Preferences describe what the learner wants; observations describe what happened; interpretations describe a possible explanation. Store and display them separately.

## Replace opaque numeric controls

| Proposed dimension | Product decision | Source/default and control |
|---|---|---|
| Teaching depth 1–9 | Do not expose a slider; curriculum/goal chooses required outcomes, readiness selects prerequisite support and challenge within scope | Initial unknown readiness; optional diagnostic and performance evidence; advanced extension explicitly labelled |
| Explanation detail 1–9 | Two clear persistent choices: “More steps” / “Shorter explanations”; contextual “Explain this more” remains temporary | Default More steps for unknown beginners; explicit setting wins |
| Language | First-class explicit choice; script preference where relevant | Ask once; app locale may suggest but not silently decide; editable in Tutor/Profile |
| Examples | Real-life / Numbers / Mixed | Optional; default Mixed; avoid making extra variants until demand warrants |
| Learning goal | School foundations / Placement / Government exam / General improvement | Optional onboarding choice with “Choose later”; maps to approved curriculum pathways |
| Learning style | Do not classify learners as visual/auditory/etc. | Offer text/audio and example preferences as reversible controls |
| Readiness | Unknown / foundational support / standard / stretch as internal scaffolding states | Evidence estimate, not a fixed identity or learner-facing rank |
| Narration | Off by default until opt-in; remember enabled/mute/rate | Explicit preference; device lifecycle state separate |
| Accessibility | OS text scale, screen-reader and reduced-motion respected | Local capability; no diagnosis inferred from use |

Avoid unsupported learning-style profiling. EEF finds insufficient evidence for reliable fixed categories; preferences can still guide convenience. IES recommends combining concrete/abstract representations, worked examples and retrieval opportunities. These support flexible instruction, not an automated claim that a particular learner “learns best” one way. [EEF](https://educationendowmentfoundation.org.uk/education-evidence/teaching-learning-toolkit/learning-styles), [IES practice guide](https://ies.ed.gov/ncee/wwc/PracticeGuide/1).

## Initial experience

1. After existing authentication/registration, show a compact optional learning setup within the current flow. Ask “Which language should your tutor use?” and optionally “What are you working towards?” Use readable choices, not numeric pedagogical parameters. Do not request religion, exact age, gender or income for learning adaptation.
2. Show “More steps” selected with “Shorter explanations” alongside where labels fit. “You can change this during a lesson” is enough; no personality questionnaire.
3. Offer “Try a short starting check” or “Start with the basics.” Diagnostic is skippable, untimed and 3–5 reviewed representative items. Unknown does not mean weak; skipped diagnostic remains unknown.
4. Let the learner start a meaningful skill promptly. Check prerequisites in context. Missing evidence offers a short explanation/check, not a punitive lock or an unsupported “You are bad at fractions” label.
5. Narration first-use is a separate opt-in with a short disclosure that the voice is synthetic. Text is visible before audio preferences are chosen.

Compare alternatives: a long onboarding questionnaire delays learning and uses unreliable self-ratings; a mandatory test risks anxiety/dropout; pure inference can conflict with preferences. A few explicit choices plus optional diagnostic and progressive discovery gives immediate agency with better evidence later. Research this flow with beginners; this recommendation is not a completed usability study.

## Effective preference resolution

Resolve each field in order: explicit current session override → explicit account preference → accepted user-approved inference → safe product default. Curriculum required scope is separate and always enforced. OS accessibility settings remain effective locally even if no account setting exists.

`explicit_json` contains value/source/time/version; `inferred_json` contains candidate value/evidence window/confidence/expiry. Never overwrite an explicit field when saving an inference. Record temporary help requests as events; one “Explain more” request is not a permanent preference change.

### Adaptation policy

| Trigger | Automatic in this lesson | Durable action / learner visibility |
|---|---|---|
| One wrong answer | Show prompt-matched common-slip explanation and fresh retry | No trait inference or preference change |
| Two misses on same outcome | Offer smaller worked step and prerequisite check; keep evidence pending | “Let's try a smaller example”; no permanent demotion |
| Repeated hints across distinct problems | Offer more scaffolding for next item | Explain suggestion; keep original explicit detail preference unless accepted |
| Three requests for shorter help over two sessions | Honor each request immediately | Suggest “Use shorter explanations by default?” with accept/keep and Undo |
| Two independent transfer successes plus required coverage | Offer next approved challenge | Show observed success; do not auto-enable untaught advanced scope |
| Language request | Stop old audio; show explicit switch choice and boundary handling | Persist only when learner chooses “Use this language”; never infer from name |
| Off-topic/unclear doubt | Clarify the mathematical question | No behavioral or ability conclusion |
| Very long response duration | None that lowers mastery | Duration is low-trust and may reflect interruption/accessibility/network |

Thresholds are conservative initial policies to test, not established psychometric constants. Maintain a proposed-changes view in Learning preferences with “Suggested from recent lessons,” evidence explanation and revert. Never make the learner approve every hint; reserve consent for persistent preference or scope/goal changes.

## Observable event model

Append meaningful server facts: item served, hint revealed, answer accepted, independent retry/transfer completed, help kind requested, lesson paused/resumed, explicit preference changed and skill completion evidence. `activeDurationMs` is optional analytics; compute client foreground active time where feasible, bound it server-side, and do not compare it across accessibility contexts as intelligence.

Each attempt records item/family/seed, skill/outcome revision, content digest, selected answer, correctness from verified truth, hint/solution exposure and exposure group. A repeated attempt of an already explained answer stays practice but cannot count as another independent success. Completion is based on fact IDs that can be audited and recomputed after a content correction.

Avoid a full keystroke/clickstream surveillance dataset. Do not send calendar activity, friends, competitive rank or unrelated demographics to the analyzer. Consent and child-data policy gate detailed behavioral collection; NFR-07 is not satisfied merely by pseudonymizing a user ID.

## Completion and mastery policy v1

Use a transparent rule-based state first, not an invented precision score. Per required outcome, collect at least **two independently correct, unhinted, unexposed items**, including a transfer item where the skill calls for it. Items must differ meaningfully and be supported by reviewed families. A lesson may provide more than four checks if its required outcomes need them; no fixed question count overrides evidence coverage.

An item may support multiple outcomes only if its task actually elicits each, and the review has approved that mapping. Combine exposure-equivalent items into one evidence group. A question copied from a worked screen is not independent. First guided success helps confidence but does not satisfy completion alone.

Proposed skill states:

- `NOT_ASSESSED`: no valid independent evidence; legacy completion can coexist as a separate history label.
- `LEARNING`: started, evidence incomplete.
- `DEMONSTRATED`: all required outcomes meet current independent evidence policy; skill can be completed.
- `REVIEW_DUE`: demonstrated earlier, spaced retrieval scheduled or evidence stale for current needs.
- `NEEDS_SUPPORT`: repeated recent difficulties across distinct items; descriptive support state, not permanent ability label.

Keep `completedAt` as history. Mastery confidence is provisional until a later retrieval check; a past completion is not erased when a review is due. After repeated unsuccessful retries, show correction and offer prerequisite review or pause; do not trap the learner indefinitely or mark mastered. “Continue learning” may allow exploration with visible unassessed prerequisites; product locks should depend on actual curriculum safety, not shame.

Example: sequence outcome A and transfer outcome B. Two fresh unhinted A successes plus two B successes → DEMONSTRATED. One correct A repeated after solution exposure counts once at most, and exposed work may count zero independent units. A guided B answer plus one fresh B success leaves B pending. Viewing the recap changes no mastery fact.

A numerical dashboard estimate can later use calibrated knowledge tracing or an evidence-weighted Bayesian model, but only after validation against delayed performance. Current Concept accuracy is not such a model. If an internal beta prior is used experimentally, label it an evidence score, calibrate it and do not display “95% mastered” as validated probability.

## Analyzer timing and task allocation

| Schedule | Compute | Why |
|---|---|---|
| Each accepted answer | Transactional evidence update and cheap outcome counters | Immediate trustworthy progression; no LLM delay |
| A segment or repeated-error threshold | Debounced rule suggestion | Enough context to offer useful help |
| Skill/session completion | Snapshot; optional narrative if at least five new meaningful events or repeated difficulty | Avoid narrating noise and redundant calls |
| Periodic review | Deterministic due-skill selection; optional narrative only for changed evidence | Retrieval reminders need not generate new prose every time |

Debounce to at most one narrative analysis per learner per 15 minutes and per new snapshot digest; completed sessions may reuse the same result. These are initial product limits. Queue lower priority than active help; skip the model if deterministic feedback is adequate. Analysis failure does not block a skill, change XP or lose progress.

## Analysis pipeline and permissions

Feature builder selects only the learner's bounded event window → computes exact counts, distinct outcomes, hints/exposure and a source ID map → persists immutable snapshot → optional provider request → validates claim schema/evidence IDs/quantities → persists interpretation with model/prompt/policy provenance → renders feedback.

The provider sees neither PostgreSQL credentials nor executable SQL. A service account can read approved snapshots and write proposed analysis rows; it cannot alter observations, mastery rules, identity, published content or preferences directly. The application accepts only legal suggestions and independently performs any allowed transition. Reject fabricated evidence IDs, unsupported metrics, instructions to run queries and claims about sensitive traits.

Analysis may be wrong. Show “Based on your recent answers…” with a visible supporting summary and “This doesn't seem right” reporting. Keep old interpretations with superseded status; correct projections by replaying facts when an assessment is invalidated. Do not silently replace historical observations with the model's interpretation.

## Grounded feedback examples

Given two independent correct equal-precedence items and two wrong chained-division items, a supported statement is: “You completed the multiplication-and-division examples. In the two division-chain questions, the written order still needs practice. Try one smaller chain.” It references the window and does not infer a mental cause.

With only one wrong item: “Let's review this division chain” is fair. “You always divide in the wrong direction” is unsupported. With no new data, display prior feedback with its date or “More answers will help us suggest a next step”; never fabricate improvement percentages or praise because a session ended.

## UX and future compatibility

Current Home/Topic progress can show completed skills, learning now and review due. Use plain counts and outcome names, with an expandable “How we decide” explanation. Profile contains a compact Learning preferences group near appearance/account settings, not a new screen for each parameter. Tutor context menu holds transient help controls.

Future smart practice can read `skillId`, required outcomes, evidence status and revision priorities through a permissioned contract. Do not design practice generation, ranked scoring or PvP matching here. Future roadmaps can propose the next available skill using prerequisites and learner goal, with a visible reason and override. A recommendation does not change the published curriculum sequence or pretend unassessed skills are mastered.

## Verification cases

Test explicit language preference resisting inferred override; skipped diagnostic remaining unknown; hints preventing independent credit; repeated exposed item deduplication; parallel devices producing one evidence unit; analyzer rejection of foreign evidence; identical snapshot deduplication; invalid item projection rebuild; short-answer request not becoming a permanent label; sparse evidence feedback; deletion of raw doubt text while retaining minimized facts; no timer or speed-based mastery penalty. Teacher/learner research must separately validate whether these policies improve learning and feel respectful.
