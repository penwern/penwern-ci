# shellcheck shell=bash
out="$(bash scripts/gen-status.sh)"; ec=$?
assert_exit "$ec" 0 "gen-status: exits 0"
assert_contains "$out" "| Repo | Language | Lint | Tests | Security | Owner |" "gen-status: table header"
assert_contains "$out" "| curate-preservation-core | go | gate | gate | gate | platform |" "gen-status: core row"
assert_contains "$out" "| curate-ansible-deployment | ansible | gate | none | gate | platform |" "gen-status: ansible row"

# Every mode column is rendered. A generator that drops one reports "opted out of
# that gate" identically to "passes that gate", so assert each is distinguishable.
assert_contains "$out" "| aws-manager | terraform | gate | none | advisory | platform |" "gen-status: per-gate modes rendered independently"

# Advisory rendering — exercised via a temp registry so the test doesn't depend on
# any real advisory rows in the lint column (all repos are now in lint gate).
_adv_reg="$(mktmp)/adv-reg.tsv"
printf '# repo\tlanguage\tmode\towner\ttest-mode\tsecurity-mode\n' > "$_adv_reg"
printf 'fake-advisory-repo\tgo\tadvisory\tplatform\tadvisory\tnone\n' >> "$_adv_reg"
out_adv="$(PENWERN_REGISTRY="$_adv_reg" bash scripts/gen-status.sh)"
assert_contains "$out_adv" "| fake-advisory-repo | go | advisory | advisory | none | platform |" "gen-status: advisory row rendered"

# A row missing mode columns must fail loud, not render partially. Silently
# projecting away an absent column is what let the board read green while a
# third of the fleet was opted out of test execution.
_short_reg="$(mktmp)/short-reg.tsv"
printf '# repo\tlanguage\tmode\towner\ttest-mode\tsecurity-mode\n' > "$_short_reg"
printf 'legacy-four-col-repo\tgo\tgate\tplatform\n' >> "$_short_reg"
out_short="$(PENWERN_REGISTRY="$_short_reg" bash scripts/gen-status.sh 2>&1)"; ec=$?
assert_exit "$ec" 2 "gen-status: row missing mode columns exits 2 (fail loud)"
assert_contains "$out_short" "legacy-four-col-repo (4 fields)" "gen-status: short row error names the repo and field count"

PENWERN_REGISTRY=/tmp/penwernci_no_such_registry bash scripts/gen-status.sh >/dev/null 2>&1; ec=$?
assert_exit "$ec" 2 "gen-status: missing registry exits 2 (fail loud)"
