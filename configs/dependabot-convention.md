# Penwern Dependabot convention

Canonical Dependabot setup for Penwern repos. This is **reference documentation** — Dependabot configs are per-repo (`.github/dependabot.yml`) and are **not** auto-synced by `sync-config.sh` (unlike the lint configs), so apply this by hand when adding/auditing a repo.

## The standard

| Attribute | Value |
|---|---|
| Schedule | `weekly`, `day: monday`, `time: "06:00"`, `timezone: "Europe/London"` |
| Primary ecosystem (`pip` / `gomod` / `npm`) — `open-pull-requests-limit` | **10** |
| `github-actions` ecosystem — `open-pull-requests-limit` | **5** |
| Grouping | one group per ecosystem, `patterns: ["*"]`, `update-types: ["minor", "patch"]` (majors stay individual for review) |
| `commit-message.prefix` | `"deps"` (and `"deps(actions)"` for the github-actions ecosystem) |

### Rationale
- **10 for the primary ecosystem** (vs Dependabot's default of 5): app/library deps churn more; 10 avoids silently dropping bumps.
- **5 for github-actions**: actions update rarely; 5 is plenty.
- **Grouped minor/patch**: one batched PR per week instead of N; majors remain individual so breaking changes get reviewed.

### Deliberate exceptions
- **`penwern-a3m`** — `pip` with `open-pull-requests-limit: 0` (security advisories only, no version-bump PRs). Intentional; leave as-is.
- **`proton`** — no Dependabot yet (separate multi-component round).

## Canonical snippet (pip primary + github-actions)

```yaml
version: 2
updates:
  - package-ecosystem: "pip"            # or "gomod" / "npm"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
      time: "06:00"
      timezone: "Europe/London"
    open-pull-requests-limit: 10
    commit-message:
      prefix: "deps"
    groups:
      minor-and-patch:
        patterns: ["*"]
        update-types: ["minor", "patch"]

  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
      time: "06:00"
      timezone: "Europe/London"
    open-pull-requests-limit: 5
    commit-message:
      prefix: "deps(actions)"
    groups:
      actions:
        patterns: ["*"]
        update-types: ["minor", "patch"]
```

## Gotchas (learned the hard way)
- **Unpinned / `>=`-floored requirements break grouping.** Dependabot diffs semver against a *pinned* current version; bare or `>=` deps file one PR each and bypass the group. Pin with `==`. (Hit `curate-storage-reporting` and `curate-calm-integration-backend` — both fixed 2026-05-30.)
- **UTF-16 `requirements.txt` is unparseable** → 0 PRs ever (and breaks `pip install -r`). Keep files UTF-8. (Hit `sharepoint-python-server`, from PowerShell `pip freeze >`; fixed 2026-05-30.)

## Status (2026-05-30)
Conventions are consistent across the fleet except two limit outliers being aligned: `curate-preservation-api` (github-actions was 10 → 5) and `curate-manager` (second `pip` block was 5 → 10).
