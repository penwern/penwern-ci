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

out="$(PENWERN_REGISTRY="$_tm_reg" bash scripts/resolve-mode.sh tm-adv test 2>&1)"; ec=$?
assert_eq "$out" "advisory" "resolve test: advisory"
assert_exit "$ec" 0 "resolve test: advisory exit 0"

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

# --- security-mode (kind=security, reads column 6) ---
_sm_reg="$(mktmp)/sm-reg.tsv"
printf '# repo\tlanguage\tmode\towner\ttest-mode\tsecurity-mode\n' > "$_sm_reg"
printf 'sm-gate\tpython\tgate\tt\tnone\tgate\n'      >> "$_sm_reg"
printf 'sm-adv\tpython\tgate\tt\tnone\tadvisory\n'   >> "$_sm_reg"
printf 'sm-none\tpython\tgate\tt\tnone\tnone\n'      >> "$_sm_reg"
printf 'sm-bad\tpython\tgate\tt\tnone\tgarbage\n'    >> "$_sm_reg"

out="$(PENWERN_REGISTRY="$_sm_reg" bash scripts/resolve-mode.sh sm-gate security 2>&1)"; ec=$?
assert_eq "$out" "gate" "resolve security: gate"
assert_exit "$ec" 0 "resolve security: gate exit 0"

out="$(PENWERN_REGISTRY="$_sm_reg" bash scripts/resolve-mode.sh sm-adv security 2>&1)"
assert_eq "$out" "advisory" "resolve security: advisory"

out="$(PENWERN_REGISTRY="$_sm_reg" bash scripts/resolve-mode.sh sm-none security 2>&1)"
assert_eq "$out" "none" "resolve security: none is valid"

out="$(PENWERN_REGISTRY="$_sm_reg" bash scripts/resolve-mode.sh sm-bad security 2>&1)"; ec=$?
assert_exit "$ec" 4 "resolve security: invalid security-mode exit 4"

# security kind does not bleed into test/lint columns: sm-gate has test-mode=none, lint mode=gate
out="$(PENWERN_REGISTRY="$_sm_reg" bash scripts/resolve-mode.sh sm-gate test 2>&1)"
assert_eq "$out" "none" "resolve security: kind=test still reads col 5 (none)"

# real registry: security pilots are advisory; un-onboarded repos default to none
out="$(bash scripts/resolve-mode.sh curate-preservation-core security 2>&1)"
assert_eq "$out" "advisory" "resolve security: preservation-core pilot is advisory"
out="$(bash scripts/resolve-mode.sh curate-preservation-api security 2>&1)"
assert_eq "$out" "none" "resolve security: un-onboarded repo defaults to none"

# invalid kind argument -> exit 2 (usage/infra)
out="$(bash scripts/resolve-mode.sh curate-format-reporting bad-kind 2>&1)"; ec=$?
assert_exit "$ec" 2 "resolve: invalid kind exits 2"
assert_contains "$out" "invalid kind" "resolve: invalid kind message"
