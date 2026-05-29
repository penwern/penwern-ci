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

# --- test-mode (kind=test, reads column 5) ---
_tm_reg="$(mktmp)/tm-reg.tsv"
printf '# repo\tlanguage\tmode\towner\ttest-mode\n' > "$_tm_reg"
printf 'tm-gate\tpython\tgate\tt\tgate\n'      >> "$_tm_reg"
printf 'tm-adv\tpython\tgate\tt\tadvisory\n'   >> "$_tm_reg"
printf 'tm-none\tpython\tgate\tt\tnone\n'      >> "$_tm_reg"
printf 'tm-bad\tpython\tgate\tt\tgarbage\n'    >> "$_tm_reg"

out="$(PENWERN_REGISTRY="$_tm_reg" bash scripts/resolve-mode.sh tm-gate test 2>&1)"; ec=$?
assert_eq "$out" "gate" "resolve test: gate"
assert_exit "$ec" 0 "resolve test: gate exit 0"

out="$(PENWERN_REGISTRY="$_tm_reg" bash scripts/resolve-mode.sh tm-adv test 2>&1)"
assert_eq "$out" "advisory" "resolve test: advisory"

out="$(PENWERN_REGISTRY="$_tm_reg" bash scripts/resolve-mode.sh tm-none test 2>&1)"; ec=$?
assert_eq "$out" "none" "resolve test: none is valid"
assert_exit "$ec" 0 "resolve test: none exit 0"

out="$(PENWERN_REGISTRY="$_tm_reg" bash scripts/resolve-mode.sh tm-bad test 2>&1)"; ec=$?
assert_exit "$ec" 4 "resolve test: invalid test-mode exit 4"

# lint kind still reads column 3 (explicit kind)
out="$(PENWERN_REGISTRY="$_tm_reg" bash scripts/resolve-mode.sh tm-gate lint 2>&1)"
assert_eq "$out" "gate" "resolve lint: explicit lint kind reads col 3"

# real registry: format-reporting test-mode is gate
out="$(bash scripts/resolve-mode.sh curate-format-reporting test 2>&1)"
assert_eq "$out" "gate" "resolve test: format-reporting gate in real registry"
