#!/usr/bin/env bash
# Usage: test-entry.sh <repo-slug> <language> <repo-root>
# Exit: 0 = clean OR advisory-with-failures OR skipped(test-mode=none);
#       1 = gate-with-failures; 2 = infra error (ANY mode, incl. no-tests-collected);
#       3 = repo not registered; 4 = invalid test-mode.
set -u
here="$(dirname "$0")"
. "$here/lib.sh"

slug="${1:-}"; [ -n "$slug" ] || die "usage: test-entry.sh <repo-slug> <language> <repo-root>" 2
lang="${2:-}"; [ -n "$lang" ] || die "usage: test-entry.sh <repo-slug> <language> <repo-root>" 2
root="${3:-}"; [ -n "$root" ] || die "usage: test-entry.sh <repo-slug> <language> <repo-root>" 2

# Resolve test-mode first; propagate its fail-loud exit codes (2/3/4) unchanged.
mode="$(bash "$here/resolve-mode.sh" "$slug" test)"; rc=$?
[ "$rc" -eq 0 ] || exit "$rc"

if [ "$mode" = "none" ]; then
  log "test-mode=none for $slug — no reusable-test job; skipping."
  exit 0
fi

[ -d "$root" ] || die "repo root not found: $root" 2

run_tests() {
  case "$lang" in
    python) ( cd "$root" && pytest -m "not integration" ) ;;
    go)     ( cd "$root" && go test ./... ) ;;
    js-*|js) ( cd "$root" && npm test ) ;;
    *)      die "unsupported language '$lang' for tests" 2 ;;
  esac
}

run_tests; test_rc=$?

case "$test_rc" in
  0) log "tests clean ($slug, $lang)"; exit 0 ;;
  1) : ;;  # test failures -> handled by mode logic below
  5)
    # pytest exit 5 = no tests collected. test-mode != none but no tests = misconfig.
    log "INFRA: no tests collected for $slug ($lang) — test-mode != none but nothing to run. Failing loud."
    exit 2
    ;;
  *)
    log "unexpected test-runner exit $test_rc for $slug ($lang) — treating as infra (fail loud, all modes)"
    exit 2
    ;;
esac

# Findings path (test_rc == 1).
if [ "$mode" = "advisory" ]; then
  log "advisory: $slug ($lang) has test failures (NON-BLOCKING). Fix before flipping to gate."
  exit 0
fi
log "gate: $slug ($lang) has test failures — FAILING."
exit 1
