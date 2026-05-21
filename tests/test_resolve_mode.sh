# shellcheck shell=bash
_rm() { bash scripts/resolve-mode.sh "$1" 2>&1; }

out="$(_rm curate-preservation-core)"; ec=$?
assert_eq "$out" "gate" "resolve: known gate repo"
assert_exit "$ec" 0 "resolve: known repo exits 0"

# Advisory branch — exercised via a temp registry so the test doesn't depend on
# the real registry having an advisory row (all 14 repos are now in gate).
_adv_reg="$(mktmp)/adv-reg.tsv"
printf '# repo\tlanguage\tmode\towner\n' > "$_adv_reg"
printf 'fake-advisory-repo\tgo\tadvisory\tplatform\n' >> "$_adv_reg"
out="$(PENWERN_REGISTRY="$_adv_reg" bash scripts/resolve-mode.sh fake-advisory-repo 2>&1)"; ec=$?
assert_eq "$out" "advisory" "resolve: advisory mode returned for advisory row"
assert_exit "$ec" 0 "resolve: advisory repo exits 0"

out="$(_rm not-a-real-repo)"; ec=$?
assert_exit "$ec" 3 "resolve: unknown repo fails loud (exit 3)"
assert_contains "$out" "not registered" "resolve: unknown repo message"
