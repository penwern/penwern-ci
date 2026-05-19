# shellcheck shell=bash
_rm() { bash scripts/resolve-mode.sh "$1" 2>&1; }

out="$(_rm curate-preservation-core)"; ec=$?
assert_eq "$out" "gate" "resolve: known gate repo"
assert_exit "$ec" 0 "resolve: known repo exits 0"

out="$(_rm curate-event-watcher)"; ec=$?
assert_eq "$out" "advisory" "resolve: known advisory repo"
assert_exit "$ec" 0 "resolve: known advisory repo exits 0"

out="$(_rm not-a-real-repo)"; ec=$?
assert_exit "$ec" 3 "resolve: unknown repo fails loud (exit 3)"
assert_contains "$out" "not registered" "resolve: unknown repo message"
