# shellcheck shell=bash
bash scripts/run-lint.sh go fixtures/go-clean >/tmp/rl_clean.out 2>&1; ec_clean=$?
assert_exit "$ec_clean" 0 "run-lint go: clean fixture passes ($(tail -1 /tmp/rl_clean.out))"

bash scripts/run-lint.sh go fixtures/go-dirty >/tmp/rl_dirty.out 2>&1; ec_dirty=$?
assert_exit "$ec_dirty" 1 "run-lint go: dirty fixture reports findings"

bash scripts/run-lint.sh go fixtures/does-not-exist >/tmp/rl_missing.out 2>&1; ec_missing=$?
assert_exit "$ec_missing" 2 "run-lint go: missing repo-root is an infra error (exit 2)"

# infra: a broken canonical config must be exit 2 (spec §6), NOT 1 (findings)
_bad_root="$(mktmp)"; mkdir -p "$_bad_root/configs"
printf 'version: "2"\nlinters:\n  enable: [not_a_real_linter_xyz]\n' > "$_bad_root/configs/golangci.yml"
PENWERN_CI_ROOT="$_bad_root" bash scripts/run-lint.sh go fixtures/go-clean >/tmp/rl_badcfg.out 2>&1; ec_bad=$?
assert_exit "$ec_bad" 2 "run-lint go: broken canonical config = infra error (exit 2), not findings"
assert_contains "$(cat /tmp/rl_badcfg.out)" "ERROR" "run-lint go: broken config emits error"
