# shellcheck shell=bash
# security-entry.sh — mode handling (none/advisory/gate) over run-security, using a
# temp registry (column 6 = security-mode) and STUB scanners on PATH so findings/infra
# are deterministic without installing the real tools.

_se_reg="$(mktmp)/se-reg.tsv"
printf '# repo\tlanguage\tmode\towner\ttest-mode\tsecurity-mode\n' > "$_se_reg"
printf 'sec-none\tgo\tgate\tt\tnone\tnone\n'      >> "$_se_reg"
printf 'sec-adv\tgo\tgate\tt\tnone\tadvisory\n'   >> "$_se_reg"
printf 'sec-gate\tgo\tgate\tt\tnone\tgate\n'      >> "$_se_reg"
printf 'sec-bad\tgo\tgate\tt\tnone\tgarbage\n'    >> "$_se_reg"

# stub scanners (exit code per env var); prepend to PATH so coreutils stay reachable
_sebin="$(mktmp)/bin"; mkdir -p "$_sebin"
for _tool in gitleaks govulncheck pip-audit trivy npm; do
  _var="STUB_$(printf '%s' "$_tool" | tr 'a-z-' 'A-Z_')_RC"
  { echo '#!/usr/bin/env bash'; echo "exit \${$_var:-0}"; } > "$_sebin/$_tool"
  chmod +x "$_sebin/$_tool"
done
_se_root="$(mktmp)/repo"; mkdir -p "$_se_root"

_se() { PENWERN_REGISTRY="$_se_reg" PATH="$_sebin:$PATH" bash scripts/security-entry.sh "$@"; }

# security-mode=none -> skip, exit 0 even with a leak present
( STUB_GITLEAKS_RC=1 _se sec-none go "$_se_root" >/tmp/se1.out 2>&1 ); ec=$?
assert_exit "$ec" 0 "security-entry: mode none skips (exit 0)"
assert_contains "$(cat /tmp/se1.out)" "none" "security-entry: none skip banner"

# advisory + clean -> 0
( _se sec-adv go "$_se_root" >/tmp/se2.out 2>&1 ); ec=$?
assert_exit "$ec" 0 "security-entry: advisory clean -> 0"

# advisory + findings -> softened to 0, advisory banner
( STUB_GITLEAKS_RC=1 _se sec-adv go "$_se_root" >/tmp/se3.out 2>&1 ); ec=$?
assert_exit "$ec" 0 "security-entry: advisory softens findings to 0"
assert_contains "$(cat /tmp/se3.out)" "advisory" "security-entry: advisory banner"

# gate + findings -> 1, gate banner
( STUB_GITLEAKS_RC=1 _se sec-gate go "$_se_root" >/tmp/se4.out 2>&1 ); ec=$?
assert_exit "$ec" 1 "security-entry: gate fails on findings"
assert_contains "$(cat /tmp/se4.out)" "gate" "security-entry: gate failure banner"

# advisory + infra -> 2 (advisory must NOT mask infra)
( STUB_GOVULNCHECK_RC=99 _se sec-adv go "$_se_root" >/tmp/se5.out 2>&1 ); ec=$?
assert_exit "$ec" 2 "security-entry: advisory + infra -> 2 (not masked)"

# gate + clean -> 0
( _se sec-gate go "$_se_root" >/tmp/se6.out 2>&1 ); ec=$?
assert_exit "$ec" 0 "security-entry: gate clean -> 0"

# unknown repo -> 3
( _se not-registered go "$_se_root" >/tmp/se7.out 2>&1 ); ec=$?
assert_exit "$ec" 3 "security-entry: unknown repo -> 3"

# invalid security-mode -> 4
( _se sec-bad go "$_se_root" >/tmp/se8.out 2>&1 ); ec=$?
assert_exit "$ec" 4 "security-entry: invalid security-mode -> 4"
