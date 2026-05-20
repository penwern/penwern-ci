# penwern-ci

Single source of truth for standardised linting across Penwern repos.
See the design spec: `docs/superpowers/specs/2026-05-19-standardised-linting-design.md` (in the monorepo workspace).

## Onboard a repo

1. Add a row to `registry.tsv` (`repo<TAB>language<TAB>mode<TAB>owner`).
2. `bash scripts/sync-config.sh <repo-slug> <path-to-repo>` to drop the canonical config.
3. Add the caller workflow `.github/workflows/lint.yml` (see spec §4).
4. Commit in the target repo (config + caller + format sweep as separate commits).

## Advisory → gate

Flip the `mode` column for the repo in `registry.tsv` and commit here. No commit needed in the target repo.

## Status

| Repo | Language | Mode | Owner |
| --- | --- | --- | --- |
| curate-preservation-core | go | gate | platform |
| curate-preservation-api | go | gate | platform |
| curate-event-watcher | go | advisory | platform |
| curate-pure-integration | python | advisory | platform |
| curate-format-reporting | python | advisory | platform |
| curate-storage-reporting | python | advisory | platform |
| curate-archivesspace-integration | python | advisory | platform |
| curate-calm-integration-backend | python | advisory | platform |
| curate-email-backend | python | advisory | platform |
| sharepoint-python-server | python | advisory | platform |
| curate-manager | python | advisory | platform |
| curate-dev-js | js-vanilla | advisory | platform |
| penwern-website | js-next | advisory | platform |
| curate-ansible-deployment | ansible | advisory | platform |
