#!/usr/bin/env bash
# Usage: lint-entry.sh <repo-slug> <language> <repo-root>
# Exit: 0 = clean OR advisory-with-findings; 1 = gate-with-findings;
#       2 = infra error (ANY mode); 3 = repo not registered; 4 = invalid mode.
set -u
here="$(dirname "$0")"
. "$here/lib.sh"

slug="${1:-}"; [ -n "$slug" ] || die "usage: lint-entry.sh <repo-slug> <language> <repo-root>" 2
lang="${2:-}"; [ -n "$lang" ] || die "usage: lint-entry.sh <repo-slug> <language> <repo-root>" 2
root="${3:-}"; [ -n "$root" ] || die "usage: lint-entry.sh <repo-slug> <language> <repo-root>" 2

# Resolve mode first; propagate its fail-loud exit codes (2/3/4) unchanged.
mode="$(bash "$here/resolve-mode.sh" "$slug")"; rc=$?
[ "$rc" -eq 0 ] || exit "$rc"

bash "$here/run-lint.sh" "$lang" "$root"; lint_rc=$?
case "$lint_rc" in
  0) log "lint clean ($slug, $lang)"; exit 0 ;;
  2) log "INFRA ERROR for $slug ($lang) — failing loud regardless of mode (advisory does not mask infra)"; exit 2 ;;
  1)
    if [ "$mode" = "advisory" ]; then
      log "advisory: $slug ($lang) has lint findings (NON-BLOCKING). Clear the backlog before flipping to gate."
      exit 0
    fi
    log "gate: $slug ($lang) has lint findings — FAILING."
    exit 1
    ;;
  *) log "unexpected run-lint exit $lint_rc for $slug ($lang) — treating as infra (fail loud, all modes)"; exit 2 ;;
esac
