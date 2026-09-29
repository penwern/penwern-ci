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

# go.mod tidiness: an untidy go.mod is a finding (exit 1), independent of golangci-lint
bash scripts/run-lint.sh go fixtures/go-untidy >/tmp/rl_untidy.out 2>&1; ec_untidy=$?
assert_exit "$ec_untidy" 1 "run-lint go: untidy go.mod reports findings"
assert_contains "$(cat /tmp/rl_untidy.out)" "not tidy" "run-lint go: untidy go.mod says how to fix it"

# infra: a go.mod that does not parse is exit 2, not a tidiness finding
_broken="$(mktmp)"; printf 'not a go.mod\n' > "$_broken/go.mod"; cp fixtures/go-clean/main.go "$_broken/"
bash scripts/run-lint.sh go "$_broken" >/tmp/rl_brokenmod.out 2>&1; ec_broken=$?
assert_exit "$ec_broken" 2 "run-lint go: unparseable go.mod = infra error (exit 2), not findings"
