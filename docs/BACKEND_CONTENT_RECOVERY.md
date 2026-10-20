# Recover repository lessons and refresh the admin origin allowlist

The hardened bootstrap no longer called the existing repository importer. That importer also required an existing RS Aggarwal subject, assumed legacy subtopics already existed, and ignored chapters after 14. On an empty database, roadmap reads could throw an unclassified exception and return 500. The replacement restores the missing subject/topic/subtopic/script hierarchy, retains existing scripts, and reconciles the roadmap once after the batch. Empty catalog reads now return `503 CURRICULUM_NOT_READY`; unknown roadmap IDs return 404.

Automatic recovery runs in the background only on the single combined/jobs owner, with `CURRICULUM_SYNC_ON_STARTUP=true` (default). HTTP-only/realtime-only owners do not import. `CURRICULUM_SOURCE_ROOT` must point at the deployed `books/SubTopics` JSON directories; those files are deliberately outside the backend npm artifact. Approved `subtopics.json` files govern their script selection. The two older chapters without manifests use their existing saved script/subtopic metadata. No PDFs, users, DB-only question-bank rows or generated practice/PvP sets are restored. Inline lesson questions remain part of their saved scripts. Existing/inactive subjects are preserved; no legacy destructive seeding command or reset is involved.

The supplied `CORS_ALLOWED_ORIGINS=https://aptiqu.in,http://15.252.71.142` matches the screenshot's `http://15.252.71.142` origin. A rejection means the running process saw a different allowlist or a different request origin; the supplied logs do not establish which. Process environment values take precedence over dotenv, and PM2 retains process configuration across ordinary restarts. The default dotenv path now resolves relative to the backend module, rather than the supervisor's working directory. Startup logs `cors.configured` with the active origins; rejection logs `http.origin_denied` with the parsed origin and `ORIGIN_DENIED`, without credentials or request bodies. Exact scheme, host and port matching remains enforced.

## Operator steps on EC2 after pushing/pulling this fix

These are manual instructions; no EC2 command was executed during development. Use the existing deployment account and current supported Node runtime. The commands below assume the combined process named `aptiqu-backend` shown in the supplied logs. For split roles, stop the importing jobs owner for the one-shot command and refresh/restart the API-serving owners' CORS environment separately. Keep the current database and native Ranked guards intact.

1. Enter the actual repository `backend/` directory, pull the change, and build. No dependencies changed:

   ```sh
   cd /actual/path/to/aptiqu/backend
   git pull --ff-only
   npm run build
   ```

2. Set the following non-secret values in the current shell. Verify that this is the complete repository checkout, not only a backend npm artifact:

   ```sh
   export CORS_ALLOWED_ORIGINS='https://aptiqu.in,http://15.252.71.142'
   export CURRICULUM_SOURCE_ROOT="$(cd .. && pwd)/books/SubTopics"
   export CURRICULUM_SYNC_ON_STARTUP=true
   export DOTENV_CONFIG_PATH="$PWD/.env"
   test -d "$CURRICULUM_SOURCE_ROOT/SBT-RSA-03-Decimal_Fractions/Scripts"
   ```

   Save the same allowlist, absolute source root and startup flag in the selected environment file for future deployments. If using a private environment file, set `DOTENV_CONFIG_PATH` to that file instead. Do not print or paste the whole environment file. An ecosystem file that explicitly defines these keys must also contain the intended values. Do not add wildcards or unrelated origins. A browser using `www`, HTTPS instead of HTTP, or a non-default port has a different origin.

3. Stop the automatic importing owner, then run the explicit additive recovery once:

   ```sh
   pm2 stop aptiqu-backend
   npm run sync:curriculum
   ```

   Review `curriculum.sync.completed`: `scripts` counts new imports, `skippedScripts` counts retained scripts, and `failedScripts` counts source/import problems. The command returns nonzero for missing source files or failures; successful prior file imports remain committed and are safe to retry. Do not run `seed:curriculum` as a recovery substitute: that historical script contains destructive legacy cleanup. Do not run `db push --force-reset`.

4. Refresh PM2's process environment explicitly from the shell exports above, then restart and persist the updated process configuration:

   ```sh
   pm2 restart aptiqu-backend --update-env
   pm2 save
   pm2 logs aptiqu-backend --lines 80 --nostream
   ```

   Confirm `cors.configured` contains both intended origins and check `runtime.ready`/the importer summary. Automatic startup rechecks missing files; it retains already imported scripts. If the logged allowlist differs, resolve the PM2 ecosystem/private-file override instead of weakening CORS. [PM2 documents environment updates with `--update-env`](https://pm2.keymetrics.io/docs/usage/process-management/).

5. Test CORS on the EC2 instance itself (replace 5001 if the configured API port differs):

   ```sh
   curl -i -X OPTIONS http://127.0.0.1:5001/api/v1/admin/auth/login \
     -H 'Origin: http://15.252.71.142' \
     -H 'Access-Control-Request-Method: POST' \
     -H 'Access-Control-Request-Headers: content-type'
   ```

   Expect 204 with `Access-Control-Allow-Origin: http://15.252.71.142`. This checks the backend directly; if only the public URL still fails, compare the browser's actual Request URL/Origin with proxy routing and the new denial log. Retry admin login. Sign out/in on the mobile app after the reset so deleted user identities and cached roadmap selections are not reused, then reopen Topics after the import summary appears.

## Known saved-source blockers and focused verification

Offline normalization/graph checks inspected 229 saved scripts: 226 passed the existing validator and three older HCF/LCM files failed. They are reported as `curriculum.script_invalid` / `SCRIPT_GRAPH_INVALID` and left unpublished; no validator was weakened and no teaching files were rewritten:

- `hcf_lcm_05_fractions.json`: a transition field is not an array.
- `hcf_lcm_07_number_construction.json`: unreachable nodes and no valid completion path/node.
- `hcf_lcm_09_divisibility_bounds.json`: no valid completion path/node.

Twelve older Number System scripts also reference 36 `ns-q-*` question keys rather than carrying inline questions. These original question rows were erased by the reset. The saved bank files use different `rs-q-*` keys; their numeric suffixes are not evidence of equivalent questions. The importer does not invent or alias replacements. On an empty bank these twelve scripts report `QUESTION_REFERENCE_MISSING` and remain unpublished until their original question data or a reviewed mapping is restored. Missing references now produce an explicit 409 import error instead of an unclassified 500.

Accordingly, a first recovery with these exact source files and an empty question bank is expected to report **15 blocked scripts** (three graph defects plus twelve missing-bank dependencies) and return nonzero while retaining valid imports. The remaining **214 structurally valid, self-contained scripts** are candidates for import; actual database results are recorded by the command's summary. Those source lessons need a separate content correction before they can publish. This does not establish that every other script will import successfully into a particular target database; inspect the summary and per-file error codes.

Validation performed: TypeScript build; four inert recovery/empty-catalog/missing-reference tests (including repeat import and preservation of inactive subjects); one inert loopback HTTP test covering allowed domain/IP origins, a rejected different port, redacted diagnostics and existing readiness/body/drain behavior. No database, Redis, AWS, migrations, load test or performance benchmark was used for this fix.
