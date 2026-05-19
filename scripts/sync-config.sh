#!/usr/bin/env bash
# Usage: sync-config.sh <repo-slug> <target-dir> [--check]
# Copies the canonical config(s) for the repo's language into <target-dir>.
# --check: no write; exit 1 if target differs from canonical.
set -u
here="$(dirname "$0")"
. "$here/lib.sh"

slug="${1:-}"; [ -n "$slug" ] || die "usage: sync-config.sh <repo-slug> <target-dir> [--check]" 2
target="${2:-}"; [ -n "$target" ] || die "usage: sync-config.sh <repo-slug> <target-dir> [--check]" 2
check=0
[ "${3:-}" = "--check" ] && check=1
[ -d "$target" ] || die "target-dir '$target' does not exist" 2

reg="${PENWERN_REGISTRY:-$PENWERN_CI_ROOT/registry.tsv}"
[ -f "$reg" ] || die "registry not found at $reg" 2
lang="$(grep -v '^#' "$reg" | awk -F'\t' -v r="$slug" '$1==r {print $2; exit}')"
[ -n "$lang" ] || die "repo '$slug' not registered" 3

case "$lang" in
  go)  src="$PENWERN_CI_ROOT/configs/golangci.yml"; dst="$target/.golangci.yml" ;;
  *)   die "sync not implemented for language '$lang' (engine is pluggable; add an arm)" 2 ;;
esac
[ -f "$src" ] || die "canonical config missing: $src" 2

if [ "$check" -eq 1 ]; then
  if [ -f "$dst" ] && diff -q "$src" "$dst" >/dev/null 2>&1; then
    log "in sync: $slug"
    exit 0
  fi
  log "DRIFT: $dst differs from canonical $src"
  if [ ! -f "$dst" ]; then
    log "(dst does not exist — config is absent from the repo)"
  else
    # diff direction: current (repo) -> target (canonical); reads as "what to apply"
    diff -u "$dst" "$src" 2>/dev/null || true
  fi
  exit 1
fi

cp "$src" "$dst" || die "failed to write $dst from $src" 2
log "wrote $dst from canonical"
exit 0
