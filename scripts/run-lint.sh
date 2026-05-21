#!/usr/bin/env bash
# Usage: run-lint.sh <language> <repo-root>
# Exit codes: 0 = clean, 1 = lint/format findings, 2 = infra error (fail loud).
set -u
. "$(dirname "$0")/lib.sh"

[ "${1:-}" ] || die "usage: run-lint.sh <language> <repo-root>" 2
lang="$1"
[ "${2:-}" ] || die "usage: run-lint.sh <language> <repo-root>" 2
root="$2"
[ -d "$root" ] || die "repo-root '$root' does not exist" 2

case "$lang" in
  go)
    command -v golangci-lint >/dev/null 2>&1 || die "golangci-lint not installed" 2
    cfg="$PENWERN_CI_ROOT/configs/golangci.yml"
    [ -f "$cfg" ] || die "canonical config not found: $cfg" 2
    ( cd "$root" && golangci-lint run ./... --config "$cfg" ); gc_rc=$?
    [ "$gc_rc" -eq 0 ] && exit 0
    [ "$gc_rc" -eq 1 ] && exit 1
    die "golangci-lint exited $gc_rc (config/internal error — check '$cfg')" 2
    ;;
  python)
    command -v ruff >/dev/null 2>&1 || die "ruff not installed" 2
    ( cd "$root" && ruff check . ); rc_check=$?
    ( cd "$root" && ruff format --check . ); rc_fmt=$?
    { [ "$rc_check" -gt 1 ] || [ "$rc_fmt" -gt 1 ]; } && die "ruff exited (check=$rc_check fmt=$rc_fmt) — config/internal error" 2
    { [ "$rc_check" -eq 1 ] || [ "$rc_fmt" -eq 1 ]; } && exit 1
    exit 0
    ;;
  js-next|js-vanilla)
    [ -f "$root/package.json" ] || die "missing package.json in $root" 2
    ( cd "$root" && npm ci ) || die "npm ci failed in $root" 2
    rc_eslint=0
    ( cd "$root" && npx --no-install eslint . ) || rc_eslint=$?
    rc_prettier=0
    ( cd "$root" && npx --no-install prettier --check . ) || rc_prettier=$?
    # Map: rc 0 clean / 1 findings / >=2 infra
    [ "$rc_eslint" -ge 2 ] && die "eslint crashed (rc=$rc_eslint)" 2
    [ "$rc_prettier" -ge 2 ] && die "prettier crashed (rc=$rc_prettier)" 2
    if [ "$rc_eslint" -eq 1 ] || [ "$rc_prettier" -eq 1 ]; then exit 1; fi
    exit 0
    ;;
  ansible)
    command -v ansible-lint >/dev/null 2>&1 || die "ansible-lint not on PATH (workflow must pip-install at pinned version)" 2
    # Provide a dummy ANSIBLE_VAULT_PASSWORD_FILE so playbooks that reference vault-encrypted
    # host_vars/group_vars can be syntax-checked. The contents won't actually be decryptable,
    # but ansible only crashes when the password file is missing/empty — non-empty content
    # turns the failed decrypt into a non-fatal warning. Overrides any ansible.cfg setting
    # (env var has higher precedence) so workflow CI doesn't need real vault credentials.
    _vault_pw="$(mktemp)" || die "failed to create dummy vault password file" 2
    printf 'penwern-ci-lint-stub\n' > "$_vault_pw"
    rc=0
    ( cd "$root" && ANSIBLE_VAULT_PASSWORD_FILE="$_vault_pw" ansible-lint . ) || rc=$?
    rm -f "$_vault_pw"
    # ansible-lint exit codes: 0 clean / 2 rule violations / 1 (or other) internal/config error.
    case "$rc" in
      0) exit 0 ;;
      2) exit 1 ;;
      *) die "ansible-lint failed (rc=$rc) — internal/config error" 2 ;;
    esac
    ;;
  *)
    die "unsupported language '$lang'" 2
    ;;
esac
exit 0
