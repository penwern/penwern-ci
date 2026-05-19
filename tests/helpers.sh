# shellcheck shell=bash
# Pure-bash assertion harness. Sourced by tests/run.sh; test files share counters.
# Test files are sourced by run.sh and share TESTS_RUN/TESTS_FAILED — use `return`, never `exit`, inside test files.
set -u
: "${TESTS_RUN:=0}"
: "${TESTS_FAILED:=0}"

# _pcfail records a failure but is not itself a counted assertion (TESTS_RUN is not incremented here);
# callers (assert_*) increment TESTS_RUN before calling _pcfail, so "Ran N" may be less than total checks by design.
_pcfail() { echo "  FAIL: $1"; TESTS_FAILED=$((TESTS_FAILED + 1)); }

assert_eq() {  # actual expected [msg]
  TESTS_RUN=$((TESTS_RUN + 1))
  [ "$1" = "$2" ] || _pcfail "${3:-assert_eq}: expected [$2] got [$1]"
}

assert_contains() {  # haystack needle [msg]
  TESTS_RUN=$((TESTS_RUN + 1))
  case "$1" in
    *"$2"*) : ;;
    *) _pcfail "${3:-assert_contains}: [$1] does not contain [$2]" ;;
  esac
}

assert_exit() {  # actual_code expected_code [msg]
  TESTS_RUN=$((TESTS_RUN + 1))
  [ "$1" = "$2" ] || _pcfail "${3:-assert_exit}: expected exit $2 got $1"
}

mktmp() { mktemp -d 2>/dev/null || mktemp -d -t penwernci; }
