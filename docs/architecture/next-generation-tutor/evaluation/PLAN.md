# Controlled teaching-quality investigation

Date: 22 October 2026. This is an isolated architecture experiment, not a runtime module.

## Authorization and ceilings

The assignment authorizes small live tests when credentials are available, within ₹100 and ten paid requests. The user confirmed that the OpenAI key is in `.env` and instructed that it be read only when actually needed.

This experiment imposes tighter ceilings: **six dispatched requests and ₹10 reserved estimated expenditure**, sequential only, no automatic retry, no speech calls, no provider tools, no learner data. Four initial requests compare the same narrow skill across beginner and advanced profiles with GPT-6 Luna and Gemini 2.5 Flash-Lite. Two slots remain only for an evidence-based revision or an access failure investigation; they are not a spending target. Each failed dispatch counts. An uncertain/failed request retains its full reservation.

Rates verified against official documentation on 22 October 2026: Luna ₹9.50 input / ₹47.50 output per million tokens; Flash-Lite ₹9.50 / ₹38.00. The reference conversion is a **planning assumption of ₹95 per foreign billing unit**, not a bank quote. A larger ₹100 conversion and a 1.25 multiplier are used for pre-dispatch reservations. All provider output tokens, including reasoning, are budgeted at output rates. No cache discount or free-tier credit is assumed.

The entire serialized request is bounded at 24,000 UTF-8 bytes. A conservative 25,000 input-token reservation includes framing overhead; output is capped at 5,000 tokens. This reserves ₹0.625 per Luna request and ₹0.5625 per Gemini request. Six worst-case Luna calls reserve ₹3.75, comfortably below both ceilings. Provider billing, taxes, tokenization and account settings must still be reconciled; this is a bounded local estimate, not a provider invoice or an account-wide cap. No credentials/billing settings will be changed.

## Fixture

Approved source: Simplification subtopic `sim-01-order-of-operations-bodmas`. Extract only the skill **evaluate multiplication and division from left to right**, including a later addition/subtraction step. Prerequisites: positive-integer arithmetic. Exclude fractions, brackets, exponents, missing-number equations, negative results and ambiguous implicit multiplication. This evaluation skill is a proposed subdivision, not an edit to the approved subtopic.

The local source book's printed page 95 (PDF page 104) demonstrates chained division. Its verbal order-of-operations mnemonic must not be interpreted as division always preceding multiplication. The experiment tests equal precedence explicitly, without copying the book's objective questions.

Profiles:

- Beginner: limited English confidence; explain meaning and why; concrete opening; short phone screens; guided prediction followed by fresh application.
- Advanced: competent arithmetic; concise explanations; preserve the justification and a genuine transfer question; do not expand the skill.

Four MCQs per sample, one correct answer in each position, purposeful wrong answers, fresh parallel retry with a worked correction. Display text remains sufficient without narration. No countdown.

## Procedure

1. Run `node run-evaluation.mjs --dry-run` without reading secrets or making requests.
2. Dispatch one case explicitly: `node run-evaluation.mjs --run openai beginner` (or `gemini advanced`). The harness reads only the requested provider's named key, immediately before dispatch. It does not import application config or connect to Redis/PostgreSQL.
3. The harness writes a reservation before sending, caps duration at 55 seconds, stores only allowlisted usage/status fields and model output, and never prints provider error bodies or credentials. A dispatch cannot be retried automatically. A local exclusive lock prevents overlapping invocations.
4. Personally read all successful screens and wrong-answer corrections. Independently recalculate every visible expression and option. Record beginner and teacher findings separately in the final QA document. Structural output alone is not a teaching-quality pass.
5. Revise once only if a recurring, specific flaw warrants it, preserving baseline outputs. Otherwise spend no further calls.

## Limits of evidence

Two profiles of one small English skill cannot validate a production model, multilingual teaching, learning outcomes, latency percentiles or voice. Full phone rendering and learner research remain implementation gates. Raw elapsed time is one network observation per request, not a benchmark. Missing/failed model access is reported rather than hidden by silently substituting a different model.

Sources: [Luna model](https://developers.openai.com/api/docs/models/gpt-6-luna), [Gemini pricing](https://ai.google.dev/gemini-api/docs/pricing), [Gemini availability](https://ai.google.dev/gemini-api/docs/models/gemini-2.5-flash-lite).

## Evidence-driven access adjustment

The existing OpenAI variable is named `OPEN_AI_API_KEY` in `backend/.env`; the initial conventional-name preflight made no network call. The harness now uses that actual name. No value was printed and no configuration was modified.

Gemini 2.5 Flash-Lite returned HTTP 404 on the first dispatch. The body was deliberately not logged, so the exact provider reason is unknown. Do not retry that model automatically or describe its teaching quality as measured. Repository configuration actually defaults to `gemini-3.5-flash-lite`, and its official model page/pricing were verified. Substitute two explicitly identified Gemini 3.5 cases for the unavailable 2.5 cases, preserving the failed record. This is a disclosed candidate change, not an equivalent model result.

Gemini 3.5 rates: ₹28.50 input / ₹237.50 output per million tokens. Its conservative reservation is ₹2.50/call. The revised initial plan is one failed 2.5 call + two Luna calls + two 3.5 calls, total **five dispatches and ₹6.8125 reserved**, leaving one optional revision within ₹10. The original assignment ceilings remain ₹100/ten; neither is expanded. [Gemini 3.5 model](https://ai.google.dev/gemini-api/docs/models/gemini-3.5-flash-lite).

## Final revision authorization within the existing plan

Both Luna baselines have stored answer IDs contradicting their own correct arithmetic. Beginner check s8 repeats s7 verbatim; the multiplication-before-division feedback also condemns a regrouping that gives the same result. Both Gemini 3.5 requests were rejected with HTTP 400; the safe log intentionally lacks the provider diagnostic, so no model quality inference is possible. Stop Gemini testing in this investigation.

Use the sixth/final slot for **Luna beginner v2**, supplying eight independently calculated items (four checks and four retries), fixed option order/keys, explicit two-division teaching, fresh examples, separated prediction/answer and mathematically qualified misconception language. This tests whether providing verified assessment truth improves reliability, rather than merely repeating “be correct.” `node run-evaluation.mjs --run openai beginner v2`. Reserved total after dispatch is ₹7.4375; no further dispatch is allowed by this experiment even though the assignment ceiling is higher. No unbounded adapter debugging or extra speech test is justified.
