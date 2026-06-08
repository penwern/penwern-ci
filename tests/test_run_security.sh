# shellcheck shell=bash
# run-security.sh — orchestration/aggregation tests using STUB scanners on PATH.
# The real scanners (gitleaks/govulncheck/pip-audit/trivy/npm) are not needed: each
# stub ignores its args and exits with a code chosen via an env var, so we can drive
# every clean/findings/infra branch deterministically without installing anything.

# Build a stub bin dir; prepend to PATH so stubs shadow any real tool but coreutils
# (in /usr/bin) stay reachable.
_secbin="$(mktmp)/bin"; mkdir -p "$_secbin"
for _tool in gitleaks govulncheck pip-audit trivy npm; do
  _var="STUB_$(printf '%s' "$_tool" | tr 'a-z-' 'A-Z_')_RC"
  {
    echo '#!/usr/bin/env bash'
    echo "exit \${$_var:-0}"
  } > "$_secbin/$_tool"
  chmod +x "$_secbin/$_tool"
done
_secpath="$_secbin:$PATH"

# roots: go needs only an existing dir; python needs requirements.txt; js needs a lockfile
_sec_go="$(mktmp)/go"; mkdir -p "$_sec_go"
_sec_py="$(mktmp)/py"; mkdir -p "$_sec_py"; : > "$_sec_py/requirements.txt"
_sec_js="$(mktmp)/js"; mkdir -p "$_sec_js"; : > "$_sec_js/package-lock.json"

_rs() { PATH="$_secpath" bash scripts/run-security.sh "$@"; }

# all clean -> 0
( _rs go "$_sec_go" >/tmp/rs1.out 2>&1 ); ec=$?
assert_exit "$ec" 0 "run-security go: all scanners clean -> 0"

# gitleaks finds a leak (rc 1) -> findings -> 1
( STUB_GITLEAKS_RC=1 _rs go "$_sec_go" >/tmp/rs2.out 2>&1 ); ec=$?
assert_exit "$ec" 1 "run-security go: gitleaks leak -> 1"

# govulncheck vulns (rc 3) -> findings -> 1
( STUB_GOVULNCHECK_RC=3 _rs go "$_sec_go" >/tmp/rs3.out 2>&1 ); ec=$?
assert_exit "$ec" 1 "run-security go: govulncheck vulns (rc 3) -> 1"

# govulncheck unexpected exit (rc 99) -> infra -> 2
( STUB_GOVULNCHECK_RC=99 _rs go "$_sec_go" >/tmp/rs4.out 2>&1 ); ec=$?
assert_exit "$ec" 2 "run-security go: govulncheck unexpected rc -> infra 2"

# trivy misconfig (rc 1) -> findings -> 1
( STUB_TRIVY_RC=1 _rs go "$_sec_go" >/tmp/rs5.out 2>&1 ); ec=$?
assert_exit "$ec" 1 "run-security go: trivy misconfig -> 1"

# trivy unexpected exit (rc 2) -> infra -> 2
( STUB_TRIVY_RC=2 _rs go "$_sec_go" >/tmp/rs6.out 2>&1 ); ec=$?
assert_exit "$ec" 2 "run-security go: trivy unexpected rc -> infra 2"

# python: pip-audit vulns (rc 1) -> 1
( STUB_PIP_AUDIT_RC=1 _rs python "$_sec_py" >/tmp/rs7.out 2>&1 ); ec=$?
assert_exit "$ec" 1 "run-security python: pip-audit vulns -> 1"

# js: npm audit vulns (rc 1) -> 1
( STUB_NPM_RC=1 _rs js-vanilla "$_sec_js" >/tmp/rs8.out 2>&1 ); ec=$?
assert_exit "$ec" 1 "run-security js: npm audit vulns -> 1"

# ansible: no dependency scanner, gitleaks + trivy only; all clean -> 0
( _rs ansible "$_sec_go" >/tmp/rs9.out 2>&1 ); ec=$?
assert_exit "$ec" 0 "run-security ansible: gitleaks+trivy only, clean -> 0"

# unsupported language -> infra 2
( _rs cobol "$_sec_go" >/tmp/rs10.out 2>&1 ); ec=$?
assert_exit "$ec" 2 "run-security: unsupported language -> infra 2"

# missing repo-root -> infra 2
( _rs go "$_sec_go/does-not-exist" >/tmp/rs11.out 2>&1 ); ec=$?
assert_exit "$ec" 2 "run-security: missing repo-root -> infra 2"
