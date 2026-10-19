# AptiQu UI composition preferences

Saved from the user's **REVISE PHASE C** instructions on 19 October 2026. Apply these to the current revision and future **explicitly authorized** UI phases. This document does not authorize another phase or a broad redesign.

## Preserve the approved visual system

Keep the established light/dark palettes, font families, font sizes, semantic foreground/background pairs, spacing and radius tokens. The user is happy with them. Improve composition and interaction choice before proposing changes to the design system.

Stitch HTML/screenshots and previous implementations are references for grouping, alignment, hierarchy and interaction. Their colors, gradients, font choices, dimensions, decorative effects, placeholder rewards and sample account data are not requirements to copy. References do not override the app's business contracts or accessibility requirements.

## Composition and interaction

- **Evaluate rows first for related content.** Name fields can share a row; an avatar can sit beside identity; counts can align with their labels; related statistics can share a grouped region. Do not default to a full-width vertical stack for every item.
- **Choose controls for the task.** A small mutually exclusive set such as gender can use selectable pills. Appearance benefits from a compact System/Light/Dark segmented control. Calendar/date selection and longer belief/country lists can retain suitable native pickers. Do not add arbitrary interaction variety.
- **Make important controls easy to find.** Appearance belongs high on Profile, immediately after identity, rather than buried in a large Account form. Keep one clear sign-out action with its confirmation.
- **Communicate through structure and state.** Prefer concise labels, purposeful icons, visible selection, aligned metrics and progress indicators over repeated explanatory paragraphs. Keep explanations that clarify an actual decision, error or data limitation.
- **Increase density without cramming.** Remove redundant instructions, oversized empty gaps and repeated wrappers. Keep comfortable touch targets (the app's 48 px action standard), readable labels and breathing room. Do not shrink approved fonts to force a layout to fit.
- **Avoid repetitive cardification.** Every section need not repeat a full-width container/title/paragraph hierarchy. Group related progress in one surface, use lighter metric rows or columns where appropriate, and keep account metadata/actions quiet.
- **Preserve personality.** Aim for a polished, modern, confident, slightly lively experience for young adults. Avoid sterile corporate forms, cartoonish decoration, gratuitous gradients and visual noise.

## Responsive decisions

Use actual available width, content and system text scale to decide whether a row remains readable. A narrow-screen breakpoint alone is not a reason to stack a short name beside a perfectly fitting avatar. Conversely, long identity, validation text or enlarged labels may genuinely need extra rows or columns to collapse.

Wrap whole controls and labels where practical. Retain all names, emails, required choices, validation messages and data meanings. Preserve focus order, keyboard activation, native selected/disabled states, reduced-motion behavior and accessible labels. Check normal phone composition as well as the hardest enlarged-text fixture; “no overflow” alone does not establish good composition.

## Current scope and approval

Phase C revision was explicitly approved on 19 October 2026 with `APPROVE PHASE C, proceed with next.` Phase D was explicitly approved with `APPROVE PHASE D`. Phase E was explicitly approved with `APPROVE PHASE E`. Phase F was explicitly approved with `APPROVE PHASE F`. Phase G is completed and manually approved by the user. The user requested no release and explicitly left the Ranked outage/exit policy unresolved. Earlier automated/native evidence limitations remain recorded; they do not reopen the approved phase. Preserve working validation requirements, navigation, appearance persistence, APIs and learning logic.

Login's only requested change in this revision is removal of **“These links are not available yet.”** Everything else on Login stays unchanged; missing Terms/Privacy destinations must not become misleading active links.

At each handoff, show actual light/dark rendered evidence and precise manual-review steps. Record important adaptations from the references and await explicit approval before another phase.

## Canonical reference and future work

`docs/FRONTEND_DESIGN_SYSTEM.md` is the current, implementation-grounded frontend handbook. This document retains the approved revision feedback as provenance. Its palettes/type/composition are the ordinary default, not a prohibition on a legitimate future redesign. Explicit current user requirements take precedence over historical aesthetic preferences; protect accessibility and relevant behavior, explain significant departures, and update the handbook when a lasting convention changes. The completed phase approval gates are not automatic approval requirements for every future frontend task.
