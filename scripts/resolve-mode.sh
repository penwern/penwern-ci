#!/usr/bin/env bash
# Usage: resolve-mode.sh <repo-slug>
# Prints advisory|gate. Exit 3 (fail loud) if repo absent from registry.tsv.
set -u
. "$(dirname "$0")/lib.sh"

repo="${1:?usage: resolve-mode.sh <repo-slug>}"
reg="$PENWERN_CI_ROOT/registry.tsv"
[ -f "$reg" ] || die "registry.tsv not found at $reg" 2

line="$(grep -v '^#' "$reg" | awk -F'\t' -v r="$repo" '$1==r {print; exit}')"
[ -n "$line" ] || die "repo '$repo' not registered in registry.tsv" 3

mode="$(printf '%s' "$line" | awk -F'\t' '{print $3}')"
case "$mode" in
  advisory|gate) echo "$mode" ;;
  *) die "repo '$repo' has invalid mode '$mode' in registry.tsv" 4 ;;
esac
