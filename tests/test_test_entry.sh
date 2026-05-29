# shellcheck shell=bash
_treg="$(mktmp)/test-reg.tsv"
printf '# repo\tlanguage\tmode\towner\ttest-mode\n'  > "$_treg"
printf 'py-pass-adv\tpython\tgate\tt\tadvisory\n'    >> "$_treg"
printf 'py-pass-gate\tpython\tgate\tt\tgate\n'       >> "$_treg"
printf 'py-fail-adv\tpython\tgate\tt\tadvisory\n'    >> "$_treg"
printf 'py-fail-gate\tpython\tgate\tt\tgate\n'       >> "$_treg"
printf 'py-none\tpython\tgate\tt\tnone\n'            >> "$_treg"
printf 'py-notests-gate\tpython\tgate\tt\tgate\n'    >> "$_treg"
printf 'py-notests-adv\tpython\tgate\tt\tadvisory\n' >> "$_treg"
printf 'go-pass-gate\tgo\tgate\tt\tgate\n'           >> "$_treg"
printf 'go-fail-gate\tgo\tgate\tt\tgate\n'           >> "$_treg"
printf 'bad-tmode\tpython\tgate\tt\tgarbage\n'       >> "$_treg"

_te() { PENWERN_REGISTRY="$_treg" bash scripts/test-entry.sh "$@"; }

# advisory + failing tests -> softened to exit 0
_te py-fail-adv python fixtures/py-tests-fail >/tmp/te1.out 2>&1; ec=$?
assert_exit "$ec" 0 "test-entry py: advisory softens failures to 0"
assert_contains "$(cat /tmp/te1.out)" "advisory" "test-entry py: advisory banner"

# gate + failing tests -> exit 1
_te py-fail-gate python fixtures/py-tests-fail >/tmp/te2.out 2>&1; ec=$?
assert_exit "$ec" 1 "test-entry py: gate fails on test failures"
assert_contains "$(cat /tmp/te2.out)" "gate" "test-entry py: gate failure banner"

# advisory + passing -> exit 0
_te py-pass-adv python fixtures/py-tests-pass >/tmp/te3.out 2>&1; ec=$?
assert_exit "$ec" 0 "test-entry py: advisory passing -> 0"

# gate + passing (integration test excluded) -> exit 0
_te py-pass-gate python fixtures/py-tests-pass >/tmp/te4.out 2>&1; ec=$?
assert_exit "$ec" 0 "test-entry py: gate passing -> 0 (integration excluded)"

# gate + no tests collected -> infra exit 2
_te py-notests-gate python fixtures/py-clean >/tmp/te5.out 2>&1; ec=$?
assert_exit "$ec" 2 "test-entry py: gate + no tests -> infra 2"

# advisory + no tests -> infra exit 2 (advisory must NOT mask infra)
_te py-notests-adv python fixtures/py-clean >/tmp/te6.out 2>&1; ec=$?
assert_exit "$ec" 2 "test-entry py: advisory + no tests -> infra 2 (not masked)"

# test-mode none -> skip, exit 0, even with failing tests present
_te py-none python fixtures/py-tests-fail >/tmp/te7.out 2>&1; ec=$?
assert_exit "$ec" 0 "test-entry py: test-mode none skips (exit 0)"
assert_contains "$(cat /tmp/te7.out)" "none" "test-entry py: none skip banner"

# unknown repo -> exit 3
_te not-registered python fixtures/py-tests-pass >/tmp/te8.out 2>&1; ec=$?
assert_exit "$ec" 3 "test-entry: unknown repo -> 3"

# invalid test-mode -> exit 4
_te bad-tmode python fixtures/py-tests-pass >/tmp/te9.out 2>&1; ec=$?
assert_exit "$ec" 4 "test-entry: invalid test-mode -> 4"

# missing repo-root + gate -> infra exit 2
_te py-pass-gate python fixtures/py-does-not-exist >/tmp/te10.out 2>&1; ec=$?
assert_exit "$ec" 2 "test-entry py: missing repo-root -> infra 2"

# go gate + passing -> exit 0
_te go-pass-gate go fixtures/go-tests-pass >/tmp/te11.out 2>&1; ec=$?
assert_exit "$ec" 0 "test-entry go: gate passing -> 0"

# go gate + failing -> exit 1
_te go-fail-gate go fixtures/go-tests-fail >/tmp/te12.out 2>&1; ec=$?
assert_exit "$ec" 1 "test-entry go: gate failing -> 1"
