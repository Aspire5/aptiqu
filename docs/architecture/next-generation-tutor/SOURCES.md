# Research and evidence register

Checked 22 October 2026 (Asia/Kolkata). Official pages were searched/opened, not treated as verified from memory. Provider claims establish documented capability/rates, not AptiQu quality, account entitlements or observed performance. Links are direct supporting sources; no credential-bearing URLs are used.

## Models, API contracts and controls

| Source | Supports | Important limitation |
|---|---|---|
| [OpenAI GPT-6 Luna](https://developers.openai.com/api/docs/models/gpt-6-luna) | Model ID, text/no-audio capability, structured output/reasoning, context/output sizes and catalog prices/tiers | Actual account quotas and quality not established by catalog |
| [OpenAI GPT-6.1 Sol](https://developers.openai.com/api/docs/models/gpt-6.1-sol) | More capable comparison candidate | No paid AptiQu test performed |
| [OpenAI pricing](https://developers.openai.com/api/docs/pricing) | Standard/Flex/Batch/Fast distinctions, token rates and regional premiums | Estimates use Standard short context; no promotional saving assumed |
| [OpenAI structured output](https://developers.openai.com/api/docs/guides/structured-outputs) | Typed schema output mechanism | Does not guarantee mathematical/teaching correctness |
| [OpenAI data controls](https://developers.openai.com/api/docs/guides/your-data) | Distinction among training, application state, abuse retention and ZDR eligibility | `store:false` does not imply zero provider retention |
| [OpenAI under-18 guidance](https://developers.openai.com/api/docs/guides/safety-checks/under-18-api-guidance) | Additional safeguards and child-personal-data/ZDR requirements | Requires product/vendor/legal work before child rollout |
| [OpenAI spend limits](https://developers.openai.com/api/docs/guides/spend-limits) | Alerts vs hard limits; enforcement lag | No account setting was inspected/modified |
| [Gemini 2.5 Flash-Lite](https://ai.google.dev/gemini-api/docs/models/gemini-2.5-flash-lite) | Stable model code, capabilities/sizes and current prior-user access restriction | This research request returned 404, exact cause unknown |
| [Gemini 3.5 Flash-Lite](https://ai.google.dev/gemini-api/docs/models/gemini-3.5-flash-lite) | Current candidate code, text output, structured/thinking/caching, stable status | Research requests returned 400; no quality conclusion |
| [Gemini pricing](https://ai.google.dev/gemini-api/docs/pricing) | Free/paid distinction and text/TTS token rates | Free tier not a production privacy/capacity guarantee |
| [Gemini rate limits](https://ai.google.dev/gemini-api/docs/rate-limits) | Project/model/tier quotas, non-guaranteed capacity | Account dashboard not inspected; no fixed free quota asserted |
| [Gemini structured output](https://ai.google.dev/gemini-api/docs/structured-output) | Schema capability/provider-specific translation | Adapter still needs an offline contract test |
| [Gemini thinking](https://ai.google.dev/gemini-api/docs/thinking) | Reasoning controls vary by generation/API | Do not send one universal thinking setting to every model |
| [Gemini API terms](https://ai.google.dev/gemini-api/terms) | Effective March 2026 age/client restrictions and free-service data use | Direct minor-facing eligibility unresolved; paid key is insufficient |
| [Google Cloud spend caps](https://docs.cloud.google.com/billing/docs/how-to/budgets-spend-caps) | Single-project/service caps for selected services, lag/in-flight behavior | TTS coverage not established by eligible-service list |

## Voice

| Source | Supports | Limitation |
|---|---|---|
| [Google Cloud TTS pricing](https://cloud.google.com/text-to-speech/pricing) | Chirp/Neural2/WaveNet character rates, Gemini TTS audio-token conversion and dated previews | Native quality/latency untested; no free credits in baseline |
| [Google voice catalog](https://docs.cloud.google.com/text-to-speech/docs/list-voices-and-types) | English India/Hindi/Tamil male voices and control-family differences | Gender label cannot establish age/warmth or Hinglish quality |
| [OpenAI TTS guide](https://developers.openai.com/api/docs/guides/text-to-speech) | Voice IDs, multilingual support, speech controls/disclosure | Guide still demonstrates legacy model |
| [OpenAI GPT-4o Mini TTS](https://developers.openai.com/api/docs/models/gpt-4o-mini-tts) | Model units and deprecated label at review time | Conflict with guide requires lifecycle clarification before new adoption |
| [Azure Speech language/voice support](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/language-support?tabs=tts) | Third-provider comparison and locale-specific selection | Region/endpoint/voice eligibility needs check |
| [Azure Speech pricing](https://azure.microsoft.com/en-us/pricing/details/speech/) | Service pricing entry point | Dynamic page did not establish a reliable exact regional quote; no invented rate |

## Education, privacy and cost reference

| Source | Supports | Limitation |
|---|---|---|
| [IES organizing instruction practice guide](https://ies.ed.gov/ncee/wwc/PracticeGuide/1) | Worked examples/problem solving, retrieval, concrete/abstract connections | General educational evidence, not validation of AptiQu's policy thresholds |
| [EEF learning styles evidence](https://educationendowmentfoundation.org.uk/education-evidence/teaching-learning-toolkit/learning-styles) | Avoid fixed learning-style categorization | Does not mean learner preferences should be ignored |
| [Official DPDP Rules Gazette](https://www.meity.gov.in/static/uploads/2025/11/53450e6e5dc0bfa85ebd78686cadad39.pdf) | Phased commencement and privacy framework | Confirm applicability/corrigenda/commencement with legal review |
| [Government student-data clarification](https://www.pib.gov.in/PressReleasePage.aspx?PRID=2202901&reg=48&lang=2) | Student/child-data consent and limited institution exceptions | AptiQu qualification for an exception is not established |
| [Dated INR reference](https://indiapay.com/usd-inr-today/) | ₹94.47 shown as of 22 October 2026 03:30 IST; planning rounded to ₹95 | Secondary reference, not a bank or billing settlement rate |
| [DigitalOcean VM pricing](https://www.digitalocean.com/pricing/droplets) | Example VM compute allowances | Not current AptiQu deployment, region quote or load capacity |
| [DigitalOcean managed databases](https://www.digitalocean.com/pricing/managed-databases) | Example PostgreSQL/Valkey compute and disk | Need disk/replica/region/HA sizing before purchase |
| [DigitalOcean object storage](https://www.digitalocean.com/pricing/spaces-object-storage) | Bundle and storage/egress overage | Does not include arbitrary cross-region/other vendor costs |

## Local evidence

Repository baseline `252fa1b`. Principal source files and findings are in 01; paths were read without importing application configuration or opening databases. The UI handbook, design preferences and current top progress checkpoint were read, along with actual theme/widgets and both lesson callers. A source-only inventory counted 20 catalogs/203 entries/236 immediate script JSON files; this is not a DB/publication audit.

Local book: `books/r-s-aggarwal-quantitative-aptitude-for-competitive-examinations-pr_b93f895b533ef87247c379175b251de2.pdf`, 961 pages. Read contents at PDF page 8 and Simplification printed pages 95–98/PDF104–107. Extracted mathematical layout can be scrambled; do not trust complex formula OCR without visual/source verification. No source objective-question bank was created.

Live and offline evidence: [plan](evaluation/PLAN.md), [dispatch log](evaluation/RUN_LOG.md), [independent arithmetic/reference checks](evaluation/OFFLINE_CHECKS.md), raw returned samples and typographic previews. Exact requests are reproducible from the isolated harness, but rerunning paid calls requires a fresh explicit plan; this six-request cap is exhausted. No real learner data, audio generation, DB action, migration, provider account change, VPS access or deployment was performed.

## Research limitations

No provider-wide benchmark ranking, native multilingual assessment, audio audition, production load test, learner learning-gain study, full security/secret-history audit, target database inspection or invoice reconciliation. Some pages are dynamically generated and have inconsistent lifecycle snippets; where facts conflict, the package records uncertainty rather than choosing an unsupported assertion. Rates/terms/availability must be rechecked before implementation spending and release.
