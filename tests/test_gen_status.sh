# shellcheck shell=bash
out="$(bash scripts/gen-status.sh)"; ec=$?
assert_exit "$ec" 0 "gen-status: exits 0"
assert_contains "$out" "| Repo | Language | Mode | Owner |" "gen-status: table header"
assert_contains "$out" "| curate-preservation-core | go | gate | platform |" "gen-status: core row"
assert_contains "$out" "| curate-ansible-deployment | ansible | gate | platform |" "gen-status: ansible row"

# Advisory rendering — exercised via a temp registry so the test doesn't depend on
# any real advisory rows (all 14 repos are now in gate).
_adv_reg="$(mktmp)/adv-reg.tsv"
printf '# repo\tlanguage\tmode\towner\n' > "$_adv_reg"
printf 'fake-advisory-repo\tgo\tadvisory\tplatform\n' >> "$_adv_reg"
out_adv="$(PENWERN_REGISTRY="$_adv_reg" bash scripts/gen-status.sh)"
assert_contains "$out_adv" "| fake-advisory-repo | go | advisory | platform |" "gen-status: advisory row rendered"

PENWERN_REGISTRY=/tmp/penwernci_no_such_registry bash scripts/gen-status.sh >/dev/null 2>&1; ec=$?
assert_exit "$ec" 2 "gen-status: missing registry exits 2 (fail loud)"
