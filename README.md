# penwern-ci

Single source of truth for standardised linting across Penwern repos.
See the design spec: `docs/superpowers/specs/2026-05-19-standardised-linting-design.md` (in the monorepo workspace).

## What each gate runs

Tool versions are pinned in `configs/tool-versions.env`; shared configs live in `configs/`.

| Language | Tools |
| --- | --- |
| `go` | `golangci-lint run` |
| `python` | `ruff check` + `ruff format --check` |
| `js-vanilla` / `js-next` | `eslint` + `prettier --check` |
| `ansible` | `yamllint` (all git-tracked YAML) + `ansible-lint`, both enforced |
| `terraform` | `terraform fmt -check -recursive` |

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
3. Add the caller workflow `.github/workflows/lint.yml` (see spec §4).
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

| Repo | Language | Mode | Owner |
| --- | --- | --- | --- |
| curate-preservation-core | go | gate | platform |
| curate-preservation-api | go | gate | platform |
| curate-event-watcher | go | gate | platform |
| curate-pure-integration | python | gate | platform |
| curate-format-reporting | python | gate | platform |
| curate-storage-reporting | python | gate | platform |
| curate-archivesspace-integration | python | gate | platform |
| curate-calm-integration-backend | python | gate | platform |
| curate-email-backend | python | gate | platform |
| sharepoint-python-server | python | gate | platform |
| curate-manager | python | gate | platform |
| curate-dev-js | js-vanilla | gate | platform |
| penwern-website | js-next | gate | platform |
| curate-ansible-deployment | ansible | gate | platform |
| ansible-cells | ansible | gate | platform |
| ansible-curate | ansible | gate | platform |
| ansible-mongodb | ansible | gate | platform |
| ansible-nats | ansible | gate | platform |
| ansible-prometheus | ansible | gate | platform |
| ansible-grafana | ansible | gate | platform |
| aws-manager | terraform | gate | platform |
