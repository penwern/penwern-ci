# shellcheck shell=bash
assert_exit "$([ -f configs/golangci.yml ] && echo 0 || echo 1)" 0 "configs: golangci.yml exists"
assert_exit "$([ -f configs/ruff.pyproject-fragment.toml ] && echo 0 || echo 1)" 0 "configs: ruff fragment exists"

# golangci-lint must accept the canonical config as valid
if command -v golangci-lint >/dev/null 2>&1; then
  golangci-lint config verify --config configs/golangci.yml >/tmp/gcv.out 2>&1; ec=$?
  assert_exit "$ec" 0 "configs: golangci config verifies ($(cat /tmp/gcv.out))"
fi

# ruff fragment must be the canonical select set
assert_contains "$(cat configs/ruff.pyproject-fragment.toml)" 'select = ["E", "F", "W", "I", "B", "UP", "S"]' "configs: ruff select set"

# tool versions pinned
. configs/tool-versions.env
assert_eq "$GOLANGCI_VERSION" "v2.15.0" "configs: golangci pin"
assert_eq "$RUFF_VERSION" "0.17.6" "configs: ruff pin"

# gitleaks findings template: only location fields, never Secret, Match or Line.
assert_eq "$(grep -Eo '\.[A-Za-z]+' configs/gitleaks-findings.tmpl | LC_ALL=C sort -u | tr '\n' ' ')" ".File .Fingerprint .RuleID .StartLine " "configs: gitleaks template prints location fields only"
assert_exit "$(grep -Eq 'Secret|Match|index|[^t]Line' configs/gitleaks-findings.tmpl && echo 1 || echo 0)" 0 "configs: gitleaks template never names Secret, Match or Line"
