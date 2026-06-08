#!/usr/bin/env bash
# Usage: run-security.sh <language> <repo-root>
# Runs the security scanners and aggregates their results.
# Exit codes: 0 = clean, 1 = findings, 2 = infra error (fail loud, all modes).
#
# Scanners (advisory-first rollout — see security-entry.sh for mode handling):
#   - gitleaks            secret scanning, ALL languages
#   - govulncheck         Go dependency/stdlib vulnerabilities      (language=go)
#   - pip-audit           Python dependency vulnerabilities          (language=python)
#   - npm audit           JS dependency vulnerabilities              (language=js-*)
#   - trivy config        IaC / Dockerfile misconfiguration, ALL languages
#
# CodeQL is intentionally absent: code scanning needs GitHub Advanced Security on
# private repos, which the Free plan does not include (most Penwern repos are private).
#
# Each scanner is classified into clean / findings / infra; the job aggregates:
# any infra -> exit 2 (fail loud); else any findings -> exit 1; else exit 0.
set -u
. "$(dirname "$0")/lib.sh"

[ "${1:-}" ] || die "usage: run-security.sh <language> <repo-root>" 2
lang="$1"
[ "${2:-}" ] || die "usage: run-security.sh <language> <repo-root>" 2
root="$2"
[ -d "$root" ] || die "repo-root '$root' does not exist" 2

# Aggregate state. findings=1 once any scanner reports findings; infra short-circuits to 2.
findings=0

# classify <scanner-name> <rc> <clean-code> <findings-code>
# Records findings, or fails loud (exit 2) on any other (unexpected) exit code.
classify() {
  _name="$1"; _rc="$2"; _clean="$3"; _find="$4"
  if [ "$_rc" -eq "$_clean" ]; then
    log "security: $_name clean"
  elif [ "$_rc" -eq "$_find" ]; then
    log "security: $_name reported findings"
    findings=1
  else
    die "$_name exited $_rc (unexpected — infra/config error)" 2
  fi
}

# --- gitleaks: secret scanning over the working tree (ALL languages) ---
# `detect --no-git` scans the checked-out files (not git history), which is what a
# shallow CI checkout has. Exit: 0 = no leaks, 1 = leaks found, other = error.
command -v gitleaks >/dev/null 2>&1 || die "gitleaks not on PATH (workflow must install at pinned version)" 2
( cd "$root" && gitleaks detect --no-git --no-banner --redact --source . ); gl_rc=$?
classify gitleaks "$gl_rc" 0 1

# --- per-language dependency vulnerability scan ---
case "$lang" in
  go)
    command -v govulncheck >/dev/null 2>&1 || die "govulncheck not on PATH (workflow must install at pinned version)" 2
    # govulncheck: 0 = no vulns, 3 = vulnerabilities found, other = error.
    ( cd "$root" && govulncheck ./... ); gv_rc=$?
    classify govulncheck "$gv_rc" 0 3
    ;;
  python)
    command -v pip-audit >/dev/null 2>&1 || die "pip-audit not on PATH (workflow must install at pinned version)" 2
    # Audit the declared requirements when present, else the project tree.
    # pip-audit: 0 = no vulns, 1 = vulnerabilities found, other = error.
    if [ -f "$root/requirements.txt" ]; then
      ( cd "$root" && pip-audit -r requirements.txt ); pa_rc=$?
    else
      ( cd "$root" && pip-audit . ); pa_rc=$?
    fi
    classify pip-audit "$pa_rc" 0 1
    ;;
  js-next|js-vanilla|js)
    command -v npm >/dev/null 2>&1 || die "npm not on PATH" 2
    [ -f "$root/package-lock.json" ] || die "npm audit needs package-lock.json in $root" 2
    # npm audit: 0 = nothing at/above the level, 1 = vulnerabilities at/above --audit-level.
    ( cd "$root" && npm audit --audit-level=high ); na_rc=$?
    classify "npm audit" "$na_rc" 0 1
    ;;
  ansible|terraform)
    # No language-native dependency scanner; gitleaks + trivy config cover these.
    log "security: no dependency scanner for $lang (gitleaks + trivy config only)"
    ;;
  *)
    die "unsupported language '$lang'" 2
    ;;
esac

# --- trivy: IaC / Dockerfile misconfiguration (ALL languages) ---
# `config` scans Dockerfiles, terraform, k8s, etc. and no-ops (exit 0) when none are
# present, so it is safe to run everywhere. --exit-code 1 makes findings non-zero.
command -v trivy >/dev/null 2>&1 || die "trivy not on PATH (workflow must install at pinned version)" 2
( cd "$root" && trivy config --quiet --exit-code 1 . ); tv_rc=$?
classify trivy "$tv_rc" 0 1

[ "$findings" -eq 1 ] && exit 1
exit 0
