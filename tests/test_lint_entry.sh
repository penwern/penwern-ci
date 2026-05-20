# shellcheck shell=bash
_reg="$(mktmp)/reg.tsv"
printf '# repo\tlanguage\tmode\towner\n' > "$_reg"
printf 'adv-go\tgo\tadvisory\tt\n'  >> "$_reg"
printf 'gate-go\tgo\tgate\tt\n'     >> "$_reg"

_le() { PENWERN_REGISTRY="$_reg" bash scripts/lint-entry.sh "$@"; }

# advisory + dirty -> findings softened, exit 0, banner mentions advisory
_le adv-go go fixtures/go-dirty >/tmp/le1.out 2>&1; ec=$?
assert_exit "$ec" 0 "lint-entry: advisory softens findings to exit 0"
assert_contains "$(cat /tmp/le1.out)" "advisory" "lint-entry: advisory banner shown"

# gate + dirty -> exit 1
_le gate-go go fixtures/go-dirty >/tmp/le2.out 2>&1; ec=$?
assert_exit "$ec" 1 "lint-entry: gate fails on findings"

# advisory + clean -> exit 0
_le adv-go go fixtures/go-clean >/tmp/le3.out 2>&1; ec=$?
assert_exit "$ec" 0 "lint-entry: advisory clean passes"

# gate + clean -> exit 0
_le gate-go go fixtures/go-clean >/tmp/le3b.out 2>&1; ec=$?
assert_exit "$ec" 0 "lint-entry: gate clean passes"

# CROWN-JEWEL §6 test: advisory + INFRA error (missing repo-root) -> exit 2 (fail loud even in advisory)
_le adv-go go fixtures/does-not-exist >/tmp/le4.out 2>&1; ec=$?
assert_exit "$ec" 2 "lint-entry: infra error fails loud even in advisory (spec §6)"

# advisory + broken canonical config -> still exit 2 (run-lint returns 2; advisory must NOT mask it)
_brk="$(mktmp)"; mkdir -p "$_brk/configs"
printf 'version: "2"\nlinters:\n  enable: [definitely_not_a_linter]\n' > "$_brk/configs/golangci.yml"
PENWERN_REGISTRY="$_reg" PENWERN_CI_ROOT="$_brk" bash scripts/lint-entry.sh adv-go go fixtures/go-clean >/tmp/le5.out 2>&1; ec=$?
assert_exit "$ec" 2 "lint-entry: advisory + broken config = infra exit 2 (not softened)"

# repo not in registry -> exit 3 (fail loud, all modes)
_le unknown-slug go fixtures/go-clean >/tmp/le6.out 2>&1; ec=$?
assert_exit "$ec" 3 "lint-entry: unknown repo fails loud (exit 3)"

# invalid mode value in registry -> exit 4 (fail loud, all modes)
_bad_reg="$(mktmp)/bad.tsv"
printf '# repo\tlanguage\tmode\towner\n' > "$_bad_reg"
printf 'bad-mode\tgo\tgarbage\tt\n' >> "$_bad_reg"
PENWERN_REGISTRY="$_bad_reg" bash scripts/lint-entry.sh bad-mode go fixtures/go-clean >/tmp/le7.out 2>&1; ec=$?
assert_exit "$ec" 4 "lint-entry: invalid mode propagates exit 4"

# §6 Python assertions — isolated temp registry (slugs unique from Go slugs above)
_py_reg="$(mktmp)/py-reg.tsv"
printf '# repo\tlanguage\tmode\towner\n'  > "$_py_reg"
printf 'py-clean-adv\tpython\tadvisory\tt\n' >> "$_py_reg"
printf 'py-clean-gate\tpython\tgate\tt\n'    >> "$_py_reg"
printf 'py-dirty-adv\tpython\tadvisory\tt\n' >> "$_py_reg"
printf 'py-dirty-gate\tpython\tgate\tt\n'    >> "$_py_reg"
printf 'py-infra-adv\tpython\tadvisory\tt\n' >> "$_py_reg"

_lepy() { PENWERN_REGISTRY="$_py_reg" bash scripts/lint-entry.sh "$@"; }

# 1. advisory + py-dirty -> findings softened, exit 0
_lepy py-dirty-adv python fixtures/py-dirty >/tmp/le_py1.out 2>&1; ec=$?
assert_exit "$ec" 0 "lint-entry py: advisory softens dirty findings to exit 0"

# 2. gate + py-dirty -> exit 1
_lepy py-dirty-gate python fixtures/py-dirty >/tmp/le_py2.out 2>&1; ec=$?
assert_exit "$ec" 1 "lint-entry py: gate fails on dirty findings"

# 3. advisory + py-clean -> exit 0
_lepy py-clean-adv python fixtures/py-clean >/tmp/le_py3.out 2>&1; ec=$?
assert_exit "$ec" 0 "lint-entry py: advisory clean passes"

# 4. gate + py-clean -> exit 0
_lepy py-clean-gate python fixtures/py-clean >/tmp/le_py4.out 2>&1; ec=$?
assert_exit "$ec" 0 "lint-entry py: gate clean passes"

# 5. §6 invariant: advisory + missing repo-root -> exit 2 (infra fails loud even in advisory)
_lepy py-infra-adv python fixtures/py-does-not-exist >/tmp/le_py5.out 2>&1; ec=$?
assert_exit "$ec" 2 "lint-entry py: missing repo-root exits 2 even in advisory (spec §6)"

# 6. advisory + broken pyproject.toml (unknown rule selector -> ruff config error) -> exit 2
_brk_py="$(mktmp)"
printf 'def x():\n    pass\n' > "$_brk_py/app.py"
printf '[tool.ruff.lint]\nselect = ["NOT_A_REAL_RULE_XYZ"]\n' > "$_brk_py/pyproject.toml"
PENWERN_REGISTRY="$_py_reg" bash scripts/lint-entry.sh py-clean-adv python "$_brk_py" >/tmp/le_py6.out 2>&1; ec=$?
assert_exit "$ec" 2 "lint-entry py: advisory + broken ruff config = infra exit 2 (not softened)"
