# 07 — AI models and prompt engineering

Research date: 22 October 2026. Capability statements cite official documentation; suitability is an AptiQu design judgment. Real account availability and output quality are separate tests. [Sources](SOURCES.md) is the dated research register; [12](12-educational-quality-evaluation.md) contains actual observations.

## Candidate comparison

Rates are converted at the planning ₹95/USD reference, Standard short-context text, per million tokens, excluding taxes. These requests need neither long contexts nor provider tools.

| Candidate | Verified relevant capabilities | INR input / output | AptiQu decision |
|---|---|---|---|
| `gpt-6-luna` | Text generation, structured output, reasoning controls; ~1.05M context / 128k output documented; no native audio | ₹9.50 / ₹47.50 | Primary low-cost candidate; live baseline had blocking key/math-teaching defects, so no production approval |
| `gemini-2.5-flash-lite` | Structured output, optional thinking, 1,048,576 input / 65,536 output; restricted to prior active users per current model page | ₹9.50 / ₹38.00 | Legacy candidate only; this investigation received 404, not a teaching sample |
| `gemini-3.5-flash-lite` | Current repository default; structured output/thinking/caching, 1,048,576 input / 65,536 output; text output, no audio generation | ₹28.50 / ₹237.50 | Existing integration challenger; investigation requests returned 400, requiring adapter diagnosis before fair comparison |
| `gpt-6.1-sol` | More capable current text candidate; official model/pricing available | ₹190 / ₹950 | Escalation/review candidate for complex skills, not tested here; conditional on demonstrated quality improvement |

Capabilities and rates: [Luna](https://developers.openai.com/api/docs/models/gpt-6-luna), [OpenAI pricing](https://developers.openai.com/api/docs/pricing), [Gemini 2.5](https://ai.google.dev/gemini-api/docs/models/gemini-2.5-flash-lite), [Gemini 3.5](https://ai.google.dev/gemini-api/docs/models/gemini-3.5-flash-lite), [Gemini pricing](https://ai.google.dev/gemini-api/docs/pricing), [Sol](https://developers.openai.com/api/docs/models/gpt-6.1-sol). These are catalog capabilities, not promises of mathematical or multilingual teaching quality.

Luna supports reasoning none/low/medium/high/xhigh/max; the experiment uses low through Responses. Use explicit supported settings per model rather than passing a single provider-neutral thinking number. The existing Gemini adapter's `thinkingBudget` and schema translation must be verified for the actual selected model/API; the 400 responses are integration failures with unrecorded diagnostics, not evidence that Gemini teaches badly. Do not infer an exact rejection cause.

Gemini free availability is documented for relevant tiers/models, but quotas vary by project/account and current legacy-model eligibility. No universal RPM/RPD quota or guaranteed free production capacity is established. Free-service data-use terms differ from paid processing. Do not send minors' identifiable learner data through a free tier by default. [Rate limits](https://ai.google.dev/gemini-api/docs/rate-limits), [pricing/data-use distinction](https://ai.google.dev/gemini-api/docs/pricing).

**Provider eligibility precedes quality routing.** Current [Gemini API terms](https://ai.google.dev/gemini-api/terms) restrict API clients directed at or likely accessed by under-18s. A paid Developer API key does not remove that restriction. Treat direct Gemini integration as ineligible for the school/minor-facing product until a suitable contractual/service route is confirmed; do not assume a cloud/enterprise alternative has identical terms. [OpenAI under-18 guidance](https://developers.openai.com/api/docs/guides/safety-checks/under-18-api-guidance) adds safeguards and requires zero data retention before processing personal data of children under 13 or the applicable digital-consent age. `store:false` alone is not that approval/configuration. The adult-operated synthetic experiments establish no child-product eligibility.

## Workload routing

| Workload | First policy | Escalation / fallback |
|---|---|---|
| Shared skill composition | Evaluated low-cost model + supplied verified assessment truth | Reject draft on blocker; at most one reserved repair; complex family may use approved stronger model after evidence |
| Typed doubt/simpler/example/analogy | Bounded contextual low-cost model, same scope/outcomes | Approved help snippets; honest unavailability; never guess a grading answer |
| Numeric/MCQ grading | Deterministic exact evaluator | Unsupported free-text reasoning remains provisional or reviewed |
| Mastery/trends | Rules over committed evidence | No model call required |
| Narrative learner insight | Optional low-cost model over minimized feature snapshot | Deterministic feedback template; never invent insight on timeout |
| Translation/localization | Dedicated evaluated locale instruction with math preserved | Native reviewer before locale publication; English fallback only by learner choice |
| Speech | Separate TTS adapter | Text remains available; see 09 |

The same model may handle composition and narrative analysis if both pass their rubrics. There is no architectural requirement to maintain two autonomous agents or to allocate one vendor to each role.

## Prompt architecture

Build a bounded request from versioned components, in authority order:

1. Application policy: no external tools/DB, no identity, no timers, safe output grammar, no scope override from learner text.
2. Teaching policy: concrete-first, explain why, short natural screens, vocabulary before use, meaningful intermediate steps, fresh transfer, recovery after second miss, no unsupported diagnosis.
3. Approved `skill_ai_scope`: required outcomes, sequence, prerequisites, exclusions, conventions and source caveats. Scope is data selected by the server, not retrievable arbitrary file instructions.
4. Verified mathematical package: expression trees, supplied values/units, independent calculations, option permutations and answer IDs. The model explains these; it cannot silently change them.
5. Coarse teaching profile: selected locale, scaffold band, detail mode, relevant goal variant and example preference. No private history in shared generation.
6. Typed output schema and coverage manifest: blocks, screen IDs, outcome references, example/practice IDs and recovery links.

For private help, replace shared profile with a minimal owned context snapshot and mark learner text as untrusted content. Supply current problem facts, visible prior explanation, hint exposure and relevant attempts; explicitly forbid inventing a cause from correctness alone.

### Proposed composition instruction excerpt

```text
Teach only the required outcomes in the supplied skill scope.
Start with a small situation a beginner can picture.
Show what each quantity means before naming a rule.
Explain one meaningful step per phone-sized screen.
Use the provided verified assessment items without changing their values,
option order, answer IDs, units or solution facts.
Put practice after the explanation it tests. Use fresh worked values.
Explain a common possible slip using the current question's actual values.
Do not claim the learner made that slip unless the evidence supports it.
After a retry miss, show a short worked correction and keep mastery pending.
Every required outcome needs instruction, an example and independent practice.
If the supplied facts conflict, return a structured authoring error.
```

This is a proposed runtime prompt excerpt, not proof of prompt effectiveness. Exact experimental v1/v2 prompts and schema are preserved in `evaluation/run-evaluation.mjs`; the final revision specifically tests authoritative assessment fixtures after baseline answer-ID failures.

### Analyzer response shape

```json
{
  "snapshotId": "snapshot_illustrative_1",
  "claims": [
    {
      "kind": "possible_misconception",
      "skillId": "sim.mul-div-written-order",
      "text": "These answers may show that written order needs another example.",
      "evidenceIds": ["attempt_illustrative_2", "attempt_illustrative_5"],
      "confidence": "limited",
      "suggestedAction": "offer_short_review"
    }
  ],
  "preferenceProposals": [],
  "insufficientEvidence": false
}
```

Validation must resolve every evidence ID to this learner/snapshot and recompute numerical claims. Confidence is an interpretation label, not a measured probability. A diagnosis such as a learning disorder, intelligence category or inability is outside the analyzer's role.

## Structured output and mathematical validation

Use provider-native JSON Schema where supported, then application runtime schema validation. Provider adapters translate only supported schema subsets/settings and reject refusal/truncated/empty output. A completed HTTP request is not automatically an accepted lesson. [OpenAI structured output](https://developers.openai.com/api/docs/guides/structured-outputs), [Gemini structured output](https://ai.google.dev/gemini-api/docs/structured-output).

Validation pipeline:

- Schema: types/enums/size, IDs and references, allowed markup/URLs, no answer data in public projection.
- Math: exact rational/integer arithmetic from an AST, explicit decimal rounding/units, expression equivalence and answer-ID/option uniqueness. Never `eval` a model string.
- Cross-field: display/solution/hint/retry/narration all bound to one immutable item. A sentence claiming a different key or containing self-correction is a blocker.
- Scope: every required outcome has mapped visible teaching/example/practice; no undeclared topic introduced. Automated coverage labels require human spot checking.
- Pedagogy: successful and representative wrong paths, natural language and incremental challenge. Teacher release remains necessary for novel prose/skill/locale.

The production AST verifier is proposed, not implemented by this documentation task. Its supported grammar must be explicit; symbolic algebra, geometry and language entailment are not solved by a four-operation checker. Unsupported families stay manual-review only. A model judge may triage, but cannot override mathematical failure or human blockers.

## Context, language and model configuration

Use small context budgets (typical 6k input/6k total output tokens for shared generation); advertised million-token windows are irrelevant to ordinary skill lessons. Limit help to roughly 1.5k input/400 useful output tokens, analysis to 2k/350, subject to actual locale tokenization and quality. Reasoning tokens are billable and count toward output limits; validate output completeness before retrying.

Represent English `en-IN`, Hindi `hi-IN`, Tamil `ta-IN` and Hinglish `hi-Latn-IN` as explicit product locales. Locale is not inferred from names or country. A glossary maps curriculum terms to plain-language introductions and speech lexicons. Keep numeric value, grouping and exactness invariant during translation. Allow learner-chosen script preference for Hinglish; do not assume every Hindi reader prefers Latin script.

Model config pins requested/resolved model, reasoning settings, token ceilings, prompt/schema/teaching-policy versions, verifier/rubric versions, price version and provider retention mode. Providers may expose only an alias rather than an immutable dated snapshot; record the returned model identifier and canary date, and do not claim reproducibility beyond vendor support. Changes require fixture replay/approval; do not silently upgrade an alias's accepted-quality status.

## Cost, caching and reliability

Shared artifact reuse is the main optimization. Provider prompt caching is optional and has model-specific billing/retention; it is neither guaranteed nor equivalent to PostgreSQL lesson reuse. Report cache writes/storage/uncached tokens separately and assume no cache discount in baseline cost estimates. Place stable policy/scope before variable learner-private context if an approved cache policy is used.

Bound requests, queue age, concurrent dispatch and INR reservation. No tools/search/code execution are enabled in the tutor gateway; advertised capabilities do not authorize them. One retry owner prevents queue×SDK retry multiplication. Use circuit breakers and approved fallback content. For uncertainty after dispatch, retain reservation and reconcile rather than re-send on a fresh client timeout.

## Evaluation and promotion

The six-dispatch investigation does not certify any model. Actual samples and failures are in 12; no additional paid tests are implied. Next authorized milestone: replay a small fixed teacher-reviewed set covering chained division, fractions, age statements, precision and each proposed locale; compare costs **per accepted lesson**, not per raw output token. Require zero blockers, reviewer thresholds and agreement before enabling a provider for a skill family. Keep model choice reversible through the gateway/config registry.
