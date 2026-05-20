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
  go)
    src="$PENWERN_CI_ROOT/configs/golangci.yml"
    dst="$target/.golangci.yml"
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
    ;;

  python)
    fragment="$PENWERN_CI_ROOT/configs/ruff.pyproject-fragment.toml"
    [ -f "$fragment" ] || die "canonical config missing: $fragment" 2
    dst="$target/pyproject.toml"

    if [ "$check" -eq 1 ]; then
      if [ ! -f "$dst" ]; then
        log "DRIFT: pyproject.toml absent from $target (config-absent is drift)"
        exit 2
      fi
      # Extract [tool.ruff*] sections from the repo's pyproject.toml
      repo_ruff="$(awk '/^\[tool\.ruff/{f=1} /^\[/ && !/^\[tool\.ruff/{f=0} f' "$dst")"
      # Strip preamble from canonical to get just the [tool.ruff*] block
      canonical_ruff="$(sed -n '/^\[tool\.ruff/,$p' "$fragment")"
      if [ "$repo_ruff" = "$canonical_ruff" ]; then
        log "in sync: $slug"
        exit 0
      fi
      log "DRIFT: [tool.ruff*] sections differ from canonical in $dst"
      diff -u <(printf '%s\n' "$repo_ruff") <(printf '%s\n' "$canonical_ruff") 2>/dev/null || true
      exit 1
    fi

    if [ ! -f "$dst" ]; then
      # Greenfield: create pyproject.toml from canonical fragment
      cp "$fragment" "$dst" || die "failed to write $dst from $fragment" 2
      log "wrote pyproject.toml from canonical (greenfield)"
      exit 0
    fi

    # pyproject.toml exists — check for existing [tool.ruff*] sections
    existing_ruff="$(awk '/^\[tool\.ruff/{f=1} /^\[/ && !/^\[tool\.ruff/{f=0} f' "$dst")"
    if [ -n "$existing_ruff" ]; then
      die "pyproject.toml already has [tool.ruff*] sections; merge canonical fragment by hand (duplicate TOML tables are invalid)" 2
    fi

    # Append canonical fragment
    { echo; cat "$fragment"; } >> "$dst" || die "failed to append to $dst" 2
    log "appended canonical [tool.ruff*] block to pyproject.toml"
    exit 0
    ;;

  *)
    die "sync not implemented for language '$lang' (engine is pluggable; add an arm)" 2
    ;;
esac
