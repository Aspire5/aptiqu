# Backend dependency/runtime review — 20 October 2026

A read-only `npm audit --package-lock-only --ignore-scripts --json` check completed with exit 1 because advisories exist. It did not install packages or apply fixes. `npm ls deepmerge-ts uuid --all` confirmed the installed chains. No dependency versions changed; package/lock root metadata only gains the production Node engine requirement.

The registry reports **five affected package entries: three high and two moderate**, arising from **two underlying advisories**:

| Chain | Advisory and scope | Status |
| --- | --- | --- |
| prisma 6.19.3 → @prisma/config 6.19.3 → deepmerge-ts 7.1.5 | [GHSA-ggr8-5vv4-36mx](https://github.com/advisories/GHSA-ggr8-5vv4-36mx): recursive object graphs can exhaust the stack; fixed in deepmerge-ts 8.0.0. These three affected tooling entries inherit the high severity. | Unresolved. Do not force a major transitive override or ORM upgrade without compatibility/schema/client verification. |
| google-auth-library 9.15.1 → gaxios 6.7.1 → uuid 9.0.1 | [GHSA-w5hq-g745-h8pq](https://github.com/advisories/GHSA-w5hq-g745-h8pq): missing buffer bounds checks in UUID v3/v5/v6 buffer-writing paths; fixed in uuid 11.1.1. These two entries are moderate in the audit result. | Unresolved. Review a compatible upstream dependency update and authentication regression checks before release. |

Reachability notes are **inferences from the installed code**, not exploit tests or a clean-bill claim: the deepmerge chain is under Prisma configuration tooling; plain JSON cannot construct the advisory's recursive object graphs. The inspected gaxios implementation calls `uuid.v4()` for multipart boundaries, not the advisory's explicit buffer APIs. Other usages were not comprehensively proven unreachable. The audit lists fixes as available; no automatic broad audit fix was run. Keep both findings tracked as release review gates.

The local backend shell resolves Node **24.5.0**; the workspace root resolves **20.19.5**. Application checks passed on available 24.5.0, with some isolated utility/HTTP checks also run under the root runtime. No Node runtime was installed/upgraded. [Official Node release information](https://nodejs.org/en/blog/release) listed **24.22.0 LTS** and **22.23.3 LTS** at review; [Node's EOL register](https://nodejs.org/en/about/eol) lists Node 20 as EOL. Production bootstrap/package engines now require `^22.23.3 || ^24.22.0`, with `.nvmrc` selecting 24.22.0. Verify fresh security releases before actual deployment. Full verification on that exact target binary remains outstanding.

Installed package engine ranges were inspected for pdf-parse 2.4.5, pdfjs-dist 5.4.296, @google/genai 2.24.0, @prisma/client 6.19.3, BullMQ 6.3.11, Multer 2.4.0 and ws 8.22.0. They permit the selected 22/24 runtime lines. Engine compatibility is not proof of runtime behavior or package security. No actual PDF or provider-scale test, dependency installation or deployment occurred.
