# penwern-ci

Single source of truth for standardised linting across Penwern repos.

## What each gate runs

Tool versions are pinned in `configs/tool-versions.env`; shared configs live in `configs/`.

| Language | Tools |
| --- | --- |
| `go` | `golangci-lint run` |
| `python` | `ruff check` + `ruff format --check` |
| `js-vanilla` / `js-next` | `eslint` + `prettier --check` |
| `ansible` | `yamllint` (all git-tracked YAML) + `ansible-lint`, both enforced |

**Two ansible profiles:** `lang=ansible` covers two repo shapes. A standalone role (identified by
`meta/main.yml`) is checked against `configs/ansible-lint.role.yml`, which skips galaxy `role-name`;
the deployment repo is checked against `configs/ansible-lint.yml`, which excludes the vendored
`geerlingguy.*` roles. `yamllint` is always invoked with an explicit `-c` pointing at
`configs/yamllint.yml`, so a repo-local `.yamllint` is never read by the gate and is not required.
| `terraform` | `terraform fmt -check -recursive` |

**JS repos lint at the pinned versions, not their own.** `npm ci` still runs, because a repo's
`eslint.config.mjs` imports its own plugins (`globals`, `eslint-config-next`, `@eslint/js`) and
those resolve from `node_modules`. The linters themselves are invoked as
`npx eslint@$ESLINT_VERSION` / `npx prettier@$PRETTIER_VERSION`, so the gate is the same for every
JS repo and a dependency bump cannot move it. Keep each repo's own `eslint`/`prettier` devDependency
in step with the pins, otherwise a developer's local run formats differently from CI.

**Line endings (all languages):** every registered repo carries the canonical `.gitattributes`
block from `configs/gitattributes`, which normalises text to LF in the index and on checkout so
that an editor on Windows cannot re-introduce CRLF through a commit. The config-drift audit
compares only the marker-delimited block, so repo-specific rules below it (`export-ignore`,
`linguist-*`) are free to differ.

**Why terraform is fmt-only (for now):** `terraform fmt -check` is deterministic and needs no
`init`, providers, or cloud credentials, so it is the safe enforced gate. `terraform validate`
(needs per-module `init` + provider downloads, and is flaky across repos with several root modules)
and `tflint` (plugin install) are deliberately deferred — layer them in as a ratchet once the fmt
gate is clean, mirroring how the ansible path started with yamllint enforced and added ansible-lint
later. There is no per-repo terraform config file, so the config-drift audit treats terraform repos
as always in sync.

**Why ansible runs yamllint separately:** bare `ansible-lint .` discovers files by walking the
Ansible *project structure*, which collapses when `roles/` is gitignored. In
`curate-ansible-deployment` (whose `penwern.*` roles are separate repos) it examined ~9 of 220
tracked files and silently passed. So `yamllint` runs over `git ls-files '*.yml' '*.yaml'` as the
real YAML-hygiene gate (non-strict: errors block, warnings inform); encrypted `vault.yml` files
are ignored and line-length is delegated to yamllint (the `yaml[line-length]` ansible-lint rule is
skipped).

## Test tier

`reusable-test.yml` runs the hermetic suite, resolved from `registry.tsv` **column 5**
(`test-mode`: `none` | `advisory` | `gate`, default `none`). A repo opts in with a
`.github/workflows/test.yml` caller (same shape as `lint.yml`, `language:` input).

| Language | Command |
| --- | --- |
| `go` | `go test -race -cover ./...` |
| `python` | `pytest -m "not integration" --cov` |
| `js-vanilla` / `js-next` | `npm test` |

`go vet` is deliberately not repeated here: `govet` is already enabled in the central lint
gate. The race detector is the hardening this tier adds over a plain `go test`.

Python integration tests are excluded by marker so this tier stays fast and hermetic. The
live tier is a separate workflow (below).

**`test-mode=none` is a deliberate verdict, not a backlog entry.** The ansible role repos,
`curate-ansible-deployment` and `aws-manager` are config-management and IaC: their correctness
is a property of a converged host or a plan against real cloud state, neither of which a unit
test reaches. yamllint plus ansible-lint (and `terraform fmt` plus `trivy config`) are the
right instruments for them and are already enforced. Do not read those rows as work outstanding.
The rows that *are* outstanding are the ones with a testable surface and no suite yet:
`curate-dev-js` and `penwern-website`.

## Live-Cells e2e tier

`reusable-e2e.yml` is the counterpart to the hermetic tier: it stands up a throwaway Pydio Cells
plus MySQL inside the job (`ci/ephemeral-cells/`, image digest-pinned), mints a short-lived admin
PAT in-container, runs the caller's `pytest -m integration` suite against `https://localhost:8080`,
and tears the stack down. No external host and no stored URL or PAT secret, which is what made the
live tier viable at all: the previous blocker was that integration suites needed a real Curate
instance that CI could not depend on.

Callers configure it with `workspace-slug`, `create-workspace` (set `false` when the suite uses a
default workspace such as `personal-files`, which must not be clobbered), an optional
`setup-command` run with the Cells env exported, and `test-command` / `test-workdir` overrides.
It is not driven by `registry.tsv`: a repo has an e2e job or it does not.

`bootstrap-cells.sh` waits on the compose healthcheck, then polls `SearchWorkspaces` until it
returns 200 before doing any write. The healthcheck only proves the HTTPS listener is up, and
Cells accepts connections well before the IDM services behind it are ready; writes issued in
that window return 500.

**TLS verification is disabled for this job only** (`CURATE_INSECURE_TLS`, `CEC_SKIP_VERIFY`),
which is acceptable solely because the target is an ephemeral, loopback, single-job container with
no MITM surface. Never set these against a real or remote host. If this pattern ever points at
anything non-loopback, extract the container CA and trust it instead.

## Security tier (advisory-first)

`reusable-security.yml` is a parallel tier to lint/test, resolved from `registry.tsv`
**column 6** (`security-mode`: `none` | `advisory` | `gate`, default `none`). It rolls out
advisory-first: findings are reported but never block until a repo is deliberately flipped to
`gate`, mirroring the lint advisory→gate ratchet. A repo opts in with a `.github/workflows/security.yml`
caller (same shape as `lint.yml`, `language:` input) and a `security-mode` other than `none`.

| Scanner | Scope |
| --- | --- |
| `gitleaks` | committed secrets — all languages |
| `govulncheck` | Go dependency/stdlib vulnerabilities (`language: go`) |
| `pip-audit` | Python dependency vulnerabilities (`language: python`) |
| `npm audit` | JS dependency vulnerabilities (`language: js-*`) |
| `trivy config` | IaC / Dockerfile misconfiguration — all languages |

**No CodeQL.** GitHub code scanning needs Advanced Security on private repos, which the Free
plan does not include and most Penwern repos are private — the API returns `403 Advanced Security
must be enabled`. Revisit if the plan changes or for the public repos (`penwern-ci`, `curate-dev-js`).

Each scanner's exit code is classified clean / findings / infra; the job aggregates: any infra →
fail loud (all modes), else any findings → `gate` fails / `advisory` reports, else clean.

## Onboard a repo

1. Add a row to `registry.tsv` (`repo<TAB>language<TAB>mode<TAB>owner<TAB>test-mode<TAB>security-mode`) and regenerate the Status table (`bash scripts/gen-status.sh` — the table below must match, the test suite checks it).
2. `bash scripts/sync-config.sh <repo-slug> <path-to-repo>` to drop the canonical config.
3. Add the caller workflow `.github/workflows/lint.yml` in the target repo:

   ```yaml
   name: lint
   on:
     push: { branches: [main] }
     pull_request: { branches: [main] }
   jobs:
     lint:
       uses: penwern/penwern-ci/.github/workflows/reusable-lint.yml@v1
       with:
         # go | python | js-vanilla | js-next | ansible | terraform
         language: go
       secrets:
         PENWERN_CI_APP_CLIENT_ID: ${{ secrets.PENWERN_CI_APP_CLIENT_ID }}
         PENWERN_CI_APP_PRIVATE_KEY: ${{ secrets.PENWERN_CI_APP_PRIVATE_KEY }}
   ```

4. Commit in the target repo (config + caller + format sweep as separate commits).

### Ansible role repos

The `penwern.*` roles are separate gated repos. Each needs a per-repo `.ansible-lint` skipping
`role-name` (internal roles consumed via git `src`, not published to Galaxy) and `yaml[line-length]`
(owned by yamllint). Clear `ansible-lint` before the first gated run: fix what's safe, and document
deferred findings inline with `# noqa: <rule>` so the rule stays enabled for new code (ratchet)
rather than disabling it repo-wide.

## Advisory → gate

Flip the relevant mode column in `registry.tsv` and commit here, then **re-tag `v1`** (see below).
No commit is needed in the target repo. Columns: `mode` (lint), `test-mode`, `security-mode`.

## Releasing — the `v1` tag

Callers pin `penwern/penwern-ci/.github/workflows/*@v1`. `v1` is a **moving major tag**: it always
points at the latest released `main`. Engine changes (including registry flips) only reach consumers
once `v1` is re-pointed:

```bash
git checkout main && git pull --ff-only
git tag -f v1 && git push -f origin v1
```

Every consumer picks the new engine up on its **next** workflow run — there is no per-commit pin, so
land breaking engine changes carefully (the self-test gates `main`, but consumers feel `v1` instantly).

## Dependabot convention

`.github/dependabot.yml` in each repo tracks its **application** dependencies (gomod / pip / npm /
terraform). The `github-actions` ecosystem is included **only** in repos that have bespoke workflows
referencing pinned third-party actions (e.g. `actions/checkout@v6`). Pure-caller repos — whose
workflows only `uses: …@v1` — **omit** `github-actions`, because Dependabot cannot bump a moving
major tag. penwern-ci itself carries the `github-actions` updater for the shared workflows.

## Status

| Repo | Language | Lint | Tests | Security | Owner |
| --- | --- | --- | --- | --- | --- |
| curate-preservation-core | go | gate | gate | gate | platform |
| curate-preservation-api | go | gate | gate | gate | platform |
| curate-event-watcher | go | gate | gate | gate | platform |
| curate-pure-integration | python | gate | gate | gate | platform |
| curate-format-reporting | python | gate | gate | gate | platform |
| curate-storage-reporting | python | gate | gate | gate | platform |
| curate-archivesspace-integration | python | gate | gate | gate | platform |
| curate-calm-integration-backend | python | gate | gate | gate | platform |
| curate-email-backend | python | gate | gate | gate | platform |
| sharepoint-python-server | python | gate | gate | gate | platform |
| curate-manager | python | gate | gate | gate | platform |
| curate-dev-js | js-vanilla | gate | none | gate | platform |
| penwern-website | js-next | gate | none | gate | platform |
| curate-ansible-deployment | ansible | gate | none | gate | platform |
| ansible-cells | ansible | gate | none | gate | platform |
| ansible-curate | ansible | gate | none | gate | platform |
| ansible-mongodb | ansible | gate | none | gate | platform |
| ansible-nats | ansible | gate | none | gate | platform |
| ansible-prometheus | ansible | gate | none | gate | platform |
| ansible-grafana | ansible | gate | none | gate | platform |
| aws-manager | terraform | gate | none | advisory | platform |
