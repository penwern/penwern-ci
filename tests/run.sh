#!/usr/bin/env bash
set -u
cd "$(dirname "$0")/.." || { echo "run.sh: cannot cd to repo root" >&2; exit 1; }
TESTS_RUN=0
TESTS_FAILED=0
. tests/helpers.sh
# NOTE: test files are SOURCED — never call `exit` in a test file (it kills the runner); use `return` instead.
for t in tests/test_*.sh; do
  [ -e "$t" ] || continue
  echo "== $t =="
  # shellcheck disable=SC1090
  . "$t"
done
echo "---"
echo "Ran $TESTS_RUN assertions, $TESTS_FAILED failed"
[ "$TESTS_FAILED" -eq 0 ]
