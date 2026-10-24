# 10 — Performance, scalability and INR cost model

**These are planning estimates and proposed targets, not measured capacity or invoices.** Research checked 22 October 2026. All amounts are INR. Cost depends strongly on accepted-artifact reuse, human review and narration misses, not just registered user count.

## Pricing assumptions and provenance

Use **₹95 per USD billing unit** as a rounded planning conversion. The fetched [dated FX reference](https://indiapay.com/usd-inr-today/) showed ₹94.47, timestamped 22 October 2026 at 03:30 IST. This is a secondary published reference, not a verified bank settlement quote. Provider invoices/card FX may differ. Research experiment admission instead uses ₹100 conversion plus 25% headroom.

| Service / unit | INR rate used | Source and qualification |
|---|---|---|
| GPT-6 Luna, million input/output/cached input tokens | ₹9.50 / ₹47.50 / ₹0.95 | [Official model/pricing](https://developers.openai.com/api/docs/models/gpt-6-luna); baseline assumes no cache discount |
| Gemini 2.5 Flash-Lite, million input/output tokens | ₹9.50 / ₹38 | [Official pricing](https://ai.google.dev/gemini-api/docs/pricing); legacy access restriction, no usable test sample |
| Gemini 3.5 Flash-Lite, million input/output tokens | ₹28.50 / ₹237.50 | Same official price source; adapter test rejected |
| GPT-6.1 Sol, million input/output tokens | ₹190 / ₹950 | [Official pricing](https://developers.openai.com/api/docs/pricing); no AptiQu quality benchmark here |
| Chirp 3 HD, million synthesized characters | ₹2,850 | [Google Cloud TTS](https://cloud.google.com/text-to-speech/pricing); count speech-normalized characters, no free credits assumed |
| WaveNet / Neural2, million characters | ₹380 / ₹1,520 | Same current official table; avoid stale older WaveNet rates |
| Cloud Gemini 2.5 Flash TTS, million text/audio tokens | ₹47.50 / ₹950 | Same source; audio 25 tokens/sec, separate from text generation |
| Basic VM: 4 GiB/2 vCPU; 8 GiB/4 vCPU monthly | ₹2,280; ₹4,560 | [DigitalOcean Droplets](https://www.digitalocean.com/pricing/droplets); reference sizing, no region/account quote |
| PostgreSQL Standard compute: 2/4/16 GiB node monthly | ₹2,892.75 / ₹5,785.50 / ₹23,213.25 | [Managed databases](https://www.digitalocean.com/pricing/managed-databases); add required disk and replicas |
| Managed DB disk, GiB/month | ₹20.425 | Same table; select minimum disk for chosen node, not a zero-disk database |
| Managed Valkey reference: 1/2/4 GiB monthly | ₹1,425 / ₹2,850 / ₹5,700 | Same managed-database source; Redis compatibility/HA and region need confirmation |
| Object storage bundle monthly | ₹475 | [Spaces](https://www.digitalocean.com/pricing/spaces-object-storage): 250 GiB storage + 1 TiB transfer; overage ₹1.90/GiB stored, ₹0.95/GiB transfer |

Provider geographic processing premiums, taxes, withholding/FX charges, promotional expiry, support, backups, multi-AZ HA and cross-region traffic may add cost. OpenAI regional uplift documented at 10% where applicable; no regional mode assumed in baseline. Long-context premiums are irrelevant to the bounded ordinary workloads, but must be guarded at admission. Cache writes/storage are not free. No free tier is relied on for production personal data.

## Unit arithmetic

For text: `cost_inr = input_tokens × input_rate / 1,000,000 + total_output_tokens × output_rate / 1,000,000`. Output includes billed reasoning. A failed/truncated output may still be billed. All examples below are **one generation attempt before acceptance/repair overhead**.

| Work unit | Input / total output assumption | Luna | Gemini 2.5 | Gemini 3.5 | Sol |
|---|---|---|---|---|---|
| Newly composed skill artifact | 6,000 / 6,000 tokens | ₹0.342 | ₹0.285 | ₹1.596 | ₹6.840 |
| Bounded typed doubt | 1,500 / 400 tokens | ₹0.03325 | ₹0.02945 | ₹0.13775 | ₹0.665 |
| Optional narrative learner analysis | 2,000 / 350 tokens | ₹0.035625 | ₹0.03230 | ₹0.140125 | ₹0.71250 |
| Reused published skill | No model call | ₹0 inference | ₹0 inference | ₹0 inference | ₹0 inference |

Reuse still costs database/cache/API delivery, storage and operations; it is not “free learning.” Approximate infrastructure allocation in the monthly scenarios is ₹1.00 / ₹0.36 / ₹0.185 per completed session respectively. That allocation includes idle/peak capacity and is not a measured marginal query price.

**Per narrated lesson:** 8,000 speech characters → Chirp ₹22.80; WaveNet ₹3.04; Neural2 ₹12.16 for first synthesis. A full 10-minute Cloud Gemini 2.5 TTS narration is ~₹14.25 audio output plus input tokens (~₹0.095 for 2,000 input tokens), total ~₹14.345. Token/character rates cannot be compared without actual language-length and pronunciation samples. Replay uses stored bytes with no new synthesis fee.

Teacher review is a major cost. For budgeting, assume ₹600/hour and 20 minutes of combined beginner/teacher review per accepted variant = **₹200/variant**, excluding substantial new-skill authoring or native-language specialist work. This is an explicitly assumed labor rate/time, not a market quote. If a new skill needs an hour, use ₹600, not ₹200. An accepted artifact with 80% candidate acceptance and one attempt each costs expected Luna ₹0.342/0.8 = ₹0.4275 plus review effort on rejected candidates; do not divide only by successful outputs and ignore failures.

## Completed-session assumptions

Reference session: one skill, 15 minutes active learning, ~20 accepted Continue/answer actions (one per 45 seconds), 0.6 typed doubts, and optional narrative analysis for 25% of sessions. Voice enabled in 30% of sessions. Shared clip reuse means **5% of narrated 8,000-character-equivalent sessions require new synthesis**. This is a sensitivity parameter, not a measured cache hit rate. Math/helper narration beyond the shared core is excluded from baseline and separately costed below.

Per-session optional voice cost: `0.30 × 0.05 × ₹22.80 = ₹0.342`.

Text with 2% new shared artifacts: `0.02 × ₹0.342 + 0.6 × ₹0.03325 + 0.25 × ₹0.035625 = ₹0.03569625`. Text+core voice variable cost = **₹0.37769625/session** before infrastructure/review/taxes. A fully reused text skill has no generation charge; two doubts and one analysis still cost ~₹0.102125 in this model.

## Monthly scenarios

Monthly session volume and peak concurrency are separate dimensions. Examples associate 10,000/100,000/1,000,000 monthly completions with possible peaks of 100/1,000/10,000 active learners; these imply bursty use, not uniform occupancy. At 15 minutes each, average concurrent occupancy over 30 days is ~3.5/34.7/347.2. Forecast actual peaks and completion rates from telemetry before provisioning.

| Monthly estimate | Pilot | Growth | Large |
|---|---|---|---|
| Completed sessions | 10,000 | 100,000 | 1,000,000 |
| New accepted artifact fraction | 2% | 1% | 0.5% |
| Distinct newly reviewed artifacts | 200 | 1,000 | 5,000 |
| Text inference | ₹357 | ₹3,228 | ₹30,566 |
| New core narration | ₹3,420 | ₹34,200 | ₹342,000 |
| Infrastructure planning allowance | ₹10,000 | ₹36,000 | ₹185,000 |
| Teacher review at ₹200/new variant | ₹40,000 | ₹200,000 | ₹1,000,000 |
| Subtotal, before buffer/tax | **₹53,777** | **₹273,428** | **₹1,557,566** |
| With 25% operating/uncertainty buffer | **₹67,221** | **₹341,785** | **₹1,946,958** |
| If a uniform illustrative 18% tax also applied | **₹79,321** | **₹403,306** | **₹2,297,410** |

The tax row is sensitivity arithmetic, not tax advice or a claim that every labor/vendor line attracts the same tax. Actual invoice tax/input-credit/FX treatment needs accounting review. Engineering salaries, product support, legal/compliance work, source licensing, app-store fees and acquisition costs are excluded and must be budgeted separately. Abandoned sessions, rejected artifacts and abuse also add costs; the 25% buffer is not a substitute for measuring them.

A steady warm catalog with no new variants removes ongoing per-variant teacher-review cost but still needs incident/spot review staffing. Conversely, 5,000 variants ×20 minutes = 1,667 review hours/month, over ten 160-hour reviewer-months. That conflicts with the small-team requirement. Restrict active launch variants, reuse compatible reviewed content, and permit any future parameterized auto-publication only after the quality gates in 12. Do not solve this conflict by silently dropping human review of arbitrary new prose.

### Infrastructure allowance composition

| Resource | Pilot sketch | Growth sketch | Large sketch |
|---|---|---|---|
| API and worker compute | 4 GiB API + ~2 GiB jobs, ~₹3,420 | Two 8 GiB API + two 4 GiB workers, ~₹13,680 | Eight 8 GiB API + six 8 GiB workers, ~₹63,840 |
| PostgreSQL compute and minimum reference disk | 2 GiB node +30 GiB, ~₹3,506 | Two 4 GiB nodes +60 GiB each, ~₹14,022 | Three 16 GiB nodes +290 GiB each, ~₹87,410 |
| Cache/queue | ~₹1,425 | ~₹2,850 | Two 4 GiB nodes, ~₹11,400 |
| Audio storage/transfer | ~₹475 bundle | ~₹475 bundle | ~₹1,000 allowance including growth |
| Logs, backup, ingress/LB/extra networking | ~₹1,174 allowance | ~₹4,973 allowance | ~₹21,350 allowance |
| Rounded total | **₹10,000** | **₹36,000** | **₹185,000** |

These are reference bills with allowances, not validated hardware capacity, HA architecture quotes or a hosting migration recommendation. Existing deployment cost was not inspected. Single-node pilot DB is a cost option with a failure limitation; production HA/SLO demands may require extra nodes earlier. Valkey versus deployed Redis compatibility must be tested. No machines were provisioned.

At 10-minute audio/32 kbps mono, full playback is ~2.4 MB per narrated session: about 7.2/72/720 GB monthly egress at these volumes, before replays. Large scenario new audio is ~36 GB/month with 5% miss; a year of unretired variants can exceed the 250 GiB bundle. Retention and replay rates affect overage. Database growth must budget events/attempts/indexes, not merely small lesson JSON.

## Sensitivity and cost surprises

- If every voiced session needs unique Chirp synthesis, voice becomes `0.3 × ₹22.8 = ₹6.84/session`, **₹6,840,000** at one million sessions, before text/infra/review. Strong reuse is financially material.
- Reducing core audio miss from 5% to 1% lowers large-scenario voice from ₹342,000 to **₹68,400**. A cheaper voice is acceptable only if native listening and math checks pass.
- If 10% of 0.6 doubts/session get 200-character private narration, add `0.6 ×0.1 ×200 ×₹2850/1M = ₹0.0342/session`, or ₹34,200 per million sessions. If every doubt is 1,000 spoken characters, add ₹1.71/session.
- Routing all text to Gemini 3.5 raises the variable text component at the large scenario to ~₹125,661 versus ₹30,566; selecting a provider requires acceptance rates/teaching evidence, not token-price preference alone.
- 10% of 5,000 new artifacts escalated from Luna to Sol adds `500 ×(₹6.84−₹0.342) = ₹3,249` if it replaces, not duplicates, the low-cost attempt. If both are dispatched, include both charges.
- Long reasoning, malformed outputs, queue/SDK retry multiplication, early prefetch, variant explosion, audio pronunciation re-synthesis, replays/egress and multilingual token inflation can increase spend. Monitor acceptance cost and unused-prefetch ratio, not only tokens.

## Concurrency and rate math

For an apples-to-apples peak-capacity comparison use 2% generation miss across all tiers and the same reference session above. Let N be active learners. Starts=N/900 per second; actions=N/45; generation=starts×0.02; doubts=starts×0.6; narrative analysis=starts×0.25. Shared audio new-equivalent jobs=starts×0.3×0.05.

| Peak load | 100 learners | 1,000 learners | 10,000 learners |
|---|---|---|---|
| Start/resume admissions/sec | 0.111 | 1.111 | 11.111 |
| Accepted lesson actions/sec | 2.22 | 22.22 | 222.22 |
| New shared generations/sec | 0.0022 | 0.0222 | 0.2222 |
| Doubt calls/sec | 0.0667 | 0.6667 | 6.6667 |
| Narrative analysis calls/sec | 0.0278 | 0.2778 | 2.7778 |
| Total text requests/min | 5.8 | 58 | 580 |
| New narrated lesson-equivalents/sec | 0.00167 | 0.01667 | 0.16667 |

At 10,000 learners, expected total text volume is ~1.31M input+output tokens/min under these assumptions. Splitting each new narrated equivalent into 20 clips yields ~3.33 TTS dispatches/sec (200/min), not merely ten speech calls/min. Cached audio serves far more playback requests, via object delivery.

Using planning service times of 20 s shared generation, 5 s help and 6 s analysis yields ~4.4 +33.3 +16.7 ≈54.4 concurrent model calls at that peak by Little's law. These service times are assumptions. The repository's default AI concurrency 2/RPM12 and maximum configured concurrency8 are insufficient for this modeled peak. Provider quotas, worker budgets and user admission must be redesigned/validated deliberately; adding CPU alone cannot fix a rate limit. Luna catalog tiers describe quotas, but this key's project limits were not inspected.

For actions, assume roughly 5–10 indexed DB statements per commit path: 222 actions/sec implies ~1,100–2,200 statements/sec before reads/analytics. This is not a PostgreSQL throughput benchmark. Keep JSON bodies out of list queries, short locks and bounded pools. Profile actual query plans and hot learner/session locks in the authorized data-test phase. Audio transfer must bypass API workers after authorization. Queue concurrency/INR admission remains global across replicas.

## Latency budgets

| Interaction | Proposed p95 target on reference network | Strategy / truthfulness |
|---|---|---|
| Local button pending state | ≤100 ms | Immediate UI state, duplicate protection |
| Cached first useful lesson | ≤600 ms | Published artifact lookup, compact public DTO; remove artificial 500 ms wait |
| Continue/accepted answer | ≤300 ms | Deterministic short DB transaction, no provider call |
| Restore pinned session | ≤800 ms | Indexed owner read, bounded transcript |
| New admitted shared draft | Goal ≤20 s provider+validation, separate human publication wait | Pre-warm reviewed catalog; approved fallback within 1 s; never promise draft is ready to teach |
| Bounded contextual help | First useful validated response goal ≤3 s, full ≤8 s | Short context/output, honest timeout/fallback |
| Cached audio audible start | ≤900 ms | Prefetch current/one next, short-lived URL, buffered player |
| New audio audible start | Goal ≤3 s | Small screen clips; text does not wait |

The observed Luna full mini-lesson times were about 27 seconds, so the 20-second cold draft target is **unmet/unproven**, and help latency has not been tested. A long lesson's first token is not a useful validated screen; measure both separately. Human review may take hours, so it is removed from normal learner flow by preparing launch content before exposure, not hidden inside an SLO.

## Financial enforcement and observability

Before every paid attempt, atomically reserve conservative upper-bound INR against project/day/month and learner/workload allowance, with max input/output/audio duration/characters. Store price+FX version and reserve reason. Settle only from usage/billing evidence; retain uncertain holds. A crashed dispatch is not treated as free. No paid traffic if the shared budget/ownership authority is unavailable.

Current OpenAI docs distinguish **alerts** from explicitly enabled **hard spend limits**; hard-limit responses reject affected traffic but enforcement has lag and can overshoot slightly. Do not repeat the outdated claim that all OpenAI project limits are soft, or claim hard limits provide an exact instantaneous financial fence. Account setting/permission must be verified by the operator. [Official spend controls](https://developers.openai.com/api/docs/guides/spend-limits). Google Cloud billing alerts likewise must not be assumed to stop traffic; apply API quotas and the application ledger, verify provider-specific enforcement before launch.

Separate dev/prod projects and restricted keys/model access. Alerts when proposed 50/80/95% of the budget has been spent or reserved notify operators; stop admission at the reserved ceiling. Per-workload priorities favor active text help over speculative generation/audio. Monitor reserved/settled/uncertain INR, accepted-artifact cost, voice reuse, unused prefetch, help/analysis frequency, queue age and quality rejection reason. Logs contain IDs/usage/coarse codes, never keys or raw learner prompts.

Current Google Cloud also documents **spend-cap budgets for selected services including Gemini API**, distinct from alerts-only budgets. They are scoped to one project/service, block new usage after enforcement, and have reporting lag/in-flight overage. The current eligible list does not establish coverage for Cloud Text-to-Speech; do not assume narration is protected by a Gemini cap. No such setting was inspected or enabled in this account. [Google spend caps](https://docs.cloud.google.com/billing/docs/how-to/budgets-spend-caps). Provider-age eligibility in 14 is a separate prerequisite; the comparison prices do not authorize direct Gemini use for minors.

Investigation: six total dispatched requests, three successful Luna samples and three provider rejections; known estimated successful inference ~₹0.4875, total retained conservative reservation ₹7.4375. No speech or paid load test. These are estimates, not invoice-confirmed charges. The local six-request cap is exhausted; no additional paid test is authorized by this package.

## Performance validation plan

First use fake providers with configurable latency, errors and usage; verify 100/1,000/10,000-client action/queue/budget behavior without external inference billing. Test stampedes on one key, distinct-key bursts, Redis loss, DB commit acknowledgment loss, worker death after dispatch, audio outage and two-device actions. After separate infrastructure authorization, measure p50/p95/p99, error rate, query/lock time, RSS/event-loop lag, queue wait and connection headroom against an isolated prepared DB/Redis. No such setup/load test occurred here.

Only after passing inert/isolated checks should a separately budgeted small canary test provider latency. Never load-test the paid APIs under this investigation's cap. Capacity targets and fixed-cost sketches must be revised with measured evidence before production scaling.
