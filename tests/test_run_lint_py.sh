# shellcheck shell=bash
bash scripts/run-lint.sh python fixtures/py-clean >/tmp/rlp_clean.out 2>&1; ec_clean=$?
assert_exit "$ec_clean" 0 "run-lint py: clean fixture passes ($(tail -1 /tmp/rlp_clean.out))"

bash scripts/run-lint.sh python fixtures/py-dirty >/tmp/rlp_dirty.out 2>&1; ec_dirty=$?
assert_exit "$ec_dirty" 1 "run-lint py: dirty fixture reports findings"

# infra: a broken ruff config must be exit 2 (spec §6), NOT 1 (findings) — mirrors the go regression test
# Method: unknown rule selector in [tool.ruff.lint].select causes ruff to error (rc=2) on 0.6.9
_bad="$(mktmp)"
printf 'def x():\n    pass\n' > "$_bad/app.py"
# Verified: unknown rule selector -> ruff rc=2 (config parse error) on ruff 0.6.9; re-verify on ruff pin bump.
printf '[tool.ruff.lint]\nselect = ["NOT_A_REAL_RULE_XYZ"]\n' > "$_bad/pyproject.toml"
bash scripts/run-lint.sh python "$_bad" >/tmp/rlp_bad.out 2>&1; ec_bad=$?
assert_exit "$ec_bad" 2 "run-lint py: broken ruff config = infra error (exit 2), not findings"
assert_contains "$(cat /tmp/rlp_bad.out)" "ERROR" "run-lint py: broken ruff config emits error message"
