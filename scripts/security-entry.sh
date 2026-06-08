#!/usr/bin/env bash
# Usage: security-entry.sh <repo-slug> <language> <repo-root>
# Exit: 0 = clean OR advisory-with-findings OR skipped (security-mode=none);
#       1 = gate-with-findings; 2 = infra error (ANY mode);
#       3 = repo not registered; 4 = invalid security-mode.
#
# Mirrors lint-entry.sh / test-entry.sh: resolve the mode from registry.tsv
# (column 6), run the scanners, and let advisory soften findings to 0 while never
# masking infra errors. The security tier rolls out advisory-first.
set -u
here="$(dirname "$0")"
. "$here/lib.sh"

slug="${1:-}"; [ -n "$slug" ] || die "usage: security-entry.sh <repo-slug> <language> <repo-root>" 2
lang="${2:-}"; [ -n "$lang" ] || die "usage: security-entry.sh <repo-slug> <language> <repo-root>" 2
root="${3:-}"; [ -n "$root" ] || die "usage: security-entry.sh <repo-slug> <language> <repo-root>" 2

# Resolve security-mode first; propagate its fail-loud exit codes (2/3/4) unchanged.
mode="$(bash "$here/resolve-mode.sh" "$slug" security)"; rc=$?
[ "$rc" -eq 0 ] || exit "$rc"

if [ "$mode" = "none" ]; then
  log "security-mode=none for $slug — no scanners run; skipping."
  exit 0
fi

[ -d "$root" ] || die "repo root not found: $root" 2

bash "$here/run-security.sh" "$lang" "$root"; sec_rc=$?
case "$sec_rc" in
  0) log "security clean ($slug, $lang)"; exit 0 ;;
  2) log "INFRA ERROR for $slug ($lang) — failing loud regardless of mode (advisory does not mask infra)"; exit 2 ;;
  1)
    if [ "$mode" = "advisory" ]; then
      log "advisory: $slug ($lang) has security findings (NON-BLOCKING). Clear the backlog before flipping to gate."
      exit 0
    fi
    log "gate: $slug ($lang) has security findings — FAILING."
    exit 1
    ;;
  *) log "unexpected run-security exit $sec_rc for $slug ($lang) — treating as infra (fail loud, all modes)"; exit 2 ;;
esac
