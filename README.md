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

**Why ansible runs yamllint separately:** bare `ansible-lint .` discovers files by walking the
Ansible *project structure*, which collapses when `roles/` is gitignored. In
`curate-ansible-deployment` (whose `penwern.*` roles are separate repos) it examined ~9 of 220
tracked files and silently passed. So `yamllint` runs over `git ls-files '*.yml' '*.yaml'` as the
real YAML-hygiene gate (non-strict: errors block, warnings inform); encrypted `vault.yml` files
are ignored and line-length is delegated to yamllint (the `yaml[line-length]` ansible-lint rule is
skipped).

## Onboard a repo

1. Add a row to `registry.tsv` (`repo<TAB>language<TAB>mode<TAB>owner<TAB>test-mode`) and regenerate the Status table (`bash scripts/gen-status.sh` — the table below must match, the test suite checks it).
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

Flip the `mode` column for the repo in `registry.tsv` and commit here. No commit needed in the target repo.

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
