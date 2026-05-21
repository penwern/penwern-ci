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
| curate-event-watcher | go | gate | platform |
| curate-pure-integration | python | gate | platform |
| curate-format-reporting | python | gate | platform |
| curate-storage-reporting | python | gate | platform |
| curate-archivesspace-integration | python | gate | platform |
| curate-calm-integration-backend | python | gate | platform |
| curate-email-backend | python | gate | platform |
| sharepoint-python-server | python | gate | platform |
| curate-manager | python | gate | platform |
| curate-dev-js | js-vanilla | advisory | platform |
| penwern-website | js-next | gate | platform |
| curate-ansible-deployment | ansible | advisory | platform |
