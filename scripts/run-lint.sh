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
  *)
    die "unsupported language '$lang'" 2
    ;;
esac
exit 0
