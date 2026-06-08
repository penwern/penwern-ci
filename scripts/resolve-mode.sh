#!/usr/bin/env bash
# Usage: resolve-mode.sh <repo-slug> [kind]
#   kind=lint (default) -> column 3, valid values: advisory|gate
#   kind=test           -> column 5, valid values: none|advisory|gate
#   kind=security       -> column 6, valid values: none|advisory|gate
# Prints the resolved mode. Exit 2 usage/infra, 3 repo absent, 4 invalid mode value.
set -u
. "$(dirname "$0")/lib.sh"

repo="${1:?usage: resolve-mode.sh <repo-slug> [kind]}"
kind="${2:-lint}"
# PENWERN_REGISTRY lets tests point at an alternate registry without disturbing config resolution.
reg="${PENWERN_REGISTRY:-$PENWERN_CI_ROOT/registry.tsv}"
[ -f "$reg" ] || die "registry.tsv not found at $reg" 2

case "$kind" in
  lint)     col=3 ;;
  test)     col=5 ;;
  security) col=6 ;;
  *)        die "invalid kind '$kind' (expected lint|test|security)" 2 ;;
esac

line="$(grep -v '^#' "$reg" | awk -F'\t' -v r="$repo" '$1==r {print; exit}')"
[ -n "$line" ] || die "repo '$repo' not registered in registry.tsv" 3

mode="$(printf '%s' "$line" | awk -F'\t' -v c="$col" '{print $c}')"

case "$kind" in
  lint)
    case "$mode" in
      advisory|gate) echo "$mode" ;;
      *) die "repo '$repo' has invalid mode '$mode' in registry.tsv" 4 ;;
    esac
    ;;
  test)
    case "$mode" in
      none|advisory|gate) echo "$mode" ;;
      *) die "repo '$repo' has invalid test-mode '$mode' in registry.tsv" 4 ;;
    esac
    ;;
  security)
    case "$mode" in
      none|advisory|gate) echo "$mode" ;;
      *) die "repo '$repo' has invalid security-mode '$mode' in registry.tsv" 4 ;;
    esac
    ;;
esac
