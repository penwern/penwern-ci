#!/usr/bin/env bash
# Usage: check-drift.sh <repo-slug> <repo-root>
# Exit 0 if the repo's committed config equals canonical, else 1 (drift),
# 2 = infra/usage error, 3 = repo not registered. Thin delegate to sync-config --check.
set -u
here="$(dirname "$0")"
. "$here/lib.sh"
slug="${1:-}"; [ -n "$slug" ] || die "usage: check-drift.sh <repo-slug> <repo-root>" 2
root="${2:-}"; [ -n "$root" ] || die "usage: check-drift.sh <repo-slug> <repo-root>" 2
exec bash "$here/sync-config.sh" "$slug" "$root" --check
