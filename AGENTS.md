# AptiQu content authoring rules

## Scope and workflow
- Treat the approved topic `subtopics.json` as the authority for subtopic names, order, IDs, learner descriptions, and `script_scope`. Do not silently broaden a script. Use the source book to resolve ambiguity and ask the user only when the scope remains genuinely unclear.
- Follow the current three-checkpoint workflow: (1) identify meaningful subtopics and save their names, descriptions, priorities, IDs, positions, and detailed scopes in `subtopics.json`; (2) create every approved subtopic script; (3) review all scripts for teaching quality, source and scope alignment, correctness, notation, JSON, graph, and answer-reference consistency. Do not extract objective questions from the book or make additional question banks as workflow steps. Complete all three checkpoints for a topic before stopping for user review unless a genuine ambiguity blocks safe work.
- Use the local source book and strong completed AptiQu scripts as references. Do not run local database setup/actions, connect to a VPS, or migrate data unless the user explicitly changes those restrictions.

## Learner and teaching standard
- Write for a learner with little prior knowledge and limited English confidence. Use familiar words, short natural sentences, and one main idea at a time. Introduce necessary exam or mathematical vocabulary with a plain-English explanation.
- Prefer a concrete example before an abstract rule: show what happens with actual people, objects, dates, or numbers; explain the result; then name the rule and show how it generalizes. Do not start by telling the learner to apply a model they have not seen.
- Explain why a method works, not only which operation to perform. Show meaningful intermediate steps, say what each step represents, identify likely mistakes, and check the result in a way that fits the problem.
- Use everyday analogies when they make an idea easier to picture. State how the parts of the story map to the math and where the analogy stops. Do not force a story into every screen or let it suggest a false rule.
- Build a learner-facing sequence: orient the learner; teach one idea; demonstrate it; ask a small prediction or guided question; explain the answer; then increase the challenge and offer a fresh independent application. Place practice soon after the skill it checks. End with a recap of ideas the learner can now explain or do.
- Open as a teacher speaking to a learner about the subject. Use a natural line such as “Let's learn how age problems work” followed by a small, concrete situation. Never open with “Welcome,” process directions, grading mechanics, or language about worked reasoning, retries, remediation, or repairing skills. Those are authoring details, not the lesson.
- Write for a narrow phone chat bubble. Give one useful idea or one worked step per screen, leave blank lines between thoughts, and put important equations or a small comparison on their own lines. A long paragraph that forces the learner to scroll through one message is a presentation defect even when every sentence is correct. Keep the teaching depth by spreading the reasoning across connected screens, not by deleting it.
- Use plain-text visual layouts when they clarify a time shift or relationship. Make labels readable in a proportional font; prefer a vertical, labelled timeline over columns aligned with spaces. Connect the visual to the arithmetic in the next sentence.
- Make each screen lead naturally to the next. Refer to the concrete result just found, then ask what changes when a new condition is added. Avoid a sequence of unrelated mini-lectures or generic instructions about how to use the app.
- Make every content node earn its place by adding a new idea, worked step, useful comparison, check, or practice transition. A new node is not automatically new teaching. Avoid repeated meta-instructions such as “keep the labels visible” when a worked equation can show the learner how.
- A typical script will often fit roughly 30–50 total nodes, but node count is a planning guide, not a quota. Use fewer for a narrow scope and more only when each added node teaches something distinct. Do not split filler into nodes to reach a count or compress a broad scope to stay under it. If a script falls well outside the range, review whether the lesson is over-split or missing development.
- Keep the script’s stated duration credible for its actual teaching, practice, and expected learner work. File length and word count alone do not prove adequate depth or duration.

### Examples of the expected writing
- Poor opening: “Welcome. First follow the worked reasoning, then try a fresh question. If you are wrong, use the retry.” Better opening: “Let's learn how ages change with time. Asha is 24 today. What was her age five years ago?” The learner sees the subject and a reason to continue, without seeing the lesson machinery.
- Poor phone message: “A timeline works like a calendar ruler; moving right means later and moving left means earlier. If Asha is 24 today, then in 7 years she is 24+7=31...” Use actual line breaks like this in a short screen:

  ```text
  Put Asha on a simple timeline:

  5 years ago: 19
  Today: 24
  7 years later: 31
  ```

  In the next short screen, show `24 − 5 = 19` and `24 + 7 = 31` on separate lines. Explain how each number was obtained.
- Poor transition: “Now we will cover age differences.” Better: “Both Asha and Dev get five years older. Does the gap between them also grow?” Then show their ages at both dates and let the learner see that the gap stays fixed.
- Avoid abstract wording such as: “In an age problem, ‘now’ is a coordinate, not a vague word.” Prefer: “Write each person’s age today first. Then mark the other date, such as ‘5 years ago’ or ‘3 years from now.’” Explain any new word before relying on it.
- Do not merely state: “Future ages are present age plus elapsed years.” Demonstrate it: “Asha is 24 today. Seven years from now she will be 24 + 7 = 31. Check by moving back: 31 − 7 = 24.” Then state the general rule.
- A useful factor analogy says what each number means: “Share 12 chocolates equally among 3 people. Each person gets 4, with none left over. So 3 divides 12 exactly and is a factor of 12.” Do not leave the learner to guess which story quantity represents the divisor or remainder.
- Avoid unearned feedback such as: “You moved the wrong direction,” when the system only knows that an answer is incorrect. Use “A common mistake is to add the years for an ‘ago’ question. On this question, start at 31 and subtract 6,” unless the selected distractor proves that this was the learner’s mistake.

## Scope, source, and content integrity
- Cover every meaningful skill required by the approved scope with visible teaching, an example or demonstration, and suitable practice. Mentioning a concept in metadata or a recap is not evidence that it was taught.
- Keep examples, questions, hints, options, answers, explanations, and feedback grounded in the source and scope. Preserve useful content; do not shorten for appearance or pad with repeated rules. Record unresolved source limitations.
- Keep examples and practice purposeful. Fresh values should test transfer; an exact repeat is acceptable only when it deliberately supports a just-taught step. Capstones must combine at least two previously taught skills and must not copy earlier questions verbatim.
- Verify every calculation independently. Check the meaning of each option, not just its text or ID: reordered equivalent expressions may create two correct choices. Confirm exactly one defensible answer unless the question explicitly allows more than one.
- Audit all dates, people, symbols, quantities, units, and conditions across the full question path. A hint or remedial node must match the current prompt exactly. Treat each prompt’s facts as the single source of truth; do not reuse numbers, names, or pronouns from a neighboring question.
- Label each question EASY, MEDIUM, or HARD from its actual reasoning load. Do not assign a default label to every item or force a distribution.
- Use exact notation consistently. Distinguish exact equality from approximation and terminating decimals from rounded displays. For example, write 12,486 rounded to three significant figures as `1.25 × 10^4`. Use the same repeating-decimal convention in teaching, questions, options, and feedback.

## Practice, feedback, and learner evidence
- Hints should guide the next useful step without hiding the answer. Explanations should show the reasoning and a relevant check, not just say “correct.”
- Before giving corrective feedback, name a plausible misconception and show how to repair it using the current question’s actual values. When only `isCorrect` is available, describe a common possible slip rather than claiming to know why the learner chose an answer.
- A retry should use fresh but parallel values and test the same skill. If the learner misses the retry, give a short worked correction or another meaningful recovery route; do not send the learner onward as if the idea were mastered.
- Give learners a fair chance to apply the taught skill without copying the worked answer. A successful path must include relevant practice, and the completion message should ask for a meaningful explanation, check, or application rather than only announce completion.
- For eight multiple-choice nodes, distribute correct answers evenly: exactly two each in A, B, C, and D. Vary the pattern between scripts and synchronize displayed options, stored options, and answer IDs. For other counts, balance as evenly as possible and check for revealing patterns.

## Review and correction procedure
- Review the generated draft during writing, not only at the end. After each teaching section, ask: What does the learner know now? What exact step can they perform? Is that step demonstrated in accessible language? What misconception might the next question reveal?
- At checkpoint 3, read the successful path in order and inspect representative wrong-answer paths from the learner’s point of view. Check that each screen makes sense using only what the learner has already seen. Do not accept a valid graph or JSON as proof of good teaching.
- Preview the opening and several later screens at phone width. Look for dense bubbles, awkward wrapping, diagrams that depend on spaces lining up, abrupt topic jumps, and any sentence that describes internal lesson flow. Fix the presentation before calling the script complete.
- For a language failure, rewrite the affected passage in ordinary, natural English and read it in context. For a reasoning gap, add the missing concrete step and explain why it works. For a scope gap, map the missing skill to teaching, example, and practice without expanding the approved scope. For stale feedback, correct every dependent hint, retry, option, and explanation using the current prompt’s facts.
- Re-evaluate each correction in the full learner path. Recalculate all affected math; verify the revised explanation, hints, distractors, and retry still agree; then repeat the structural checks. A fix is complete only when the learner-facing path works, not when the text fragment alone looks correct.
- Treat the following as release blockers: a factual or mathematical error; an ambiguous or multiply correct MCQ; a wrong or mismatched hint; a required scope skill that is only named but not taught; confusing or unnatural instructions that obstruct the method; a retry that does not test the diagnosed skill; or a graph/reference/JSON defect.
- Preserve the established schema, IDs, question count, and unrelated material unless a correction requires a change. Explain necessary changes and unresolved concerns.
- Structural checks must include successful JSON parsing, valid node IDs and transition targets, reachable intended nodes, correct question-option references, and consistency between displayed and stored question data. Also scan the full script for encoding, notation, accidental duplication, stale names/numbers, and incomplete descriptions.

## Database and migration restrictions
- Do not perform local database setup/actions, connect to a VPS, or perform migrations unless the user explicitly authorizes a change to these restrictions.

## UI revamp preferences and approval boundaries
- For UI work, read `docs/UI_UX_DESIGN_PREFERENCES.md` and the current checkpoint in `docs/UI_UX_REVAMP_PROGRESS.md`. These record the user's composition preferences and phase approvals.
- Preserve the approved palette, typography, font sizes and design tokens. Prefer purposeful rows, compact groups, task-appropriate controls and visual hierarchy over automatic vertical stacking, repeated cards and explanatory prose.
- Adapt to real content, width and enlarged text while preserving readable controls and 48 px touch targets. Reference designs guide composition, not a replacement visual system.
- Implement only the explicitly authorized phase or revision, then stop for manual approval. Saved preferences do not authorize future phases.

## Permanent frontend design handbook — Flutter UI tasks only
- When designing, creating, modifying or reviewing Flutter frontend UI, read the relevant sections of `docs/FRONTEND_DESIGN_SYSTEM.md`, then inspect the actual theme/widgets and their callers. That handbook is the canonical current frontend reference; the old audit/plan are historical proposals.
- Check suitable existing components before adding a reusable widget. Use the approved theme/type roles and content-driven composition by default, while protecting accessibility and relevant behavior/data contracts.
- Explicit current user requirements take precedence over historical aesthetic preferences. Legitimate improvements and authorized redesigns are welcome; explain significant departures and update the handbook when a lasting convention changes.
- Phase G is completed and manually approved. No release is requested; the Ranked outage/exit policy remains unresolved by explicit user choice. The earlier phase gates govern that phased revamp, not every future frontend fix. Follow any approval boundary established by the current task. Do NOT run historical phase test suites (`phase_a`, `phase_b`, `phase_c`, `phase_d`, `phase_e`, `phase_g`, etc.) for minor changes or everyday frontend tasks; test only the specific feature/widget test file (e.g. `test/home_dashboard_test.dart`) and run `flutter analyze`.
- This frontend reading requirement does not apply to unrelated backend or educational-content tasks. Keep all existing instructions above intact.

