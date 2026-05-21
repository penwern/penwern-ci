# shellcheck shell=bash
out="$(bash scripts/gen-status.sh)"; ec=$?
assert_exit "$ec" 0 "gen-status: exits 0"
assert_contains "$out" "| Repo | Language | Mode | Owner |" "gen-status: table header"
assert_contains "$out" "| curate-preservation-core | go | gate | platform |" "gen-status: core row"
assert_contains "$out" "| curate-ansible-deployment | ansible | advisory | platform |" "gen-status: advisory row"
PENWERN_REGISTRY=/tmp/penwernci_no_such_registry bash scripts/gen-status.sh >/dev/null 2>&1; ec=$?
assert_exit "$ec" 2 "gen-status: missing registry exits 2 (fail loud)"
