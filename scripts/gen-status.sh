#!/usr/bin/env bash
# Renders the registry as a Markdown table on stdout.
set -u
# shellcheck source=scripts/lib.sh
. "$(dirname "$0")/lib.sh"
reg="${PENWERN_REGISTRY:-$PENWERN_CI_ROOT/registry.tsv}"
[ -f "$reg" ] || die "registry not found at $reg" 2
echo "| Repo | Language | Mode | Owner |"
echo "| --- | --- | --- | --- |"
# repo slugs cannot start with '#', so '^#' lines are always comments — safe to strip.
grep -v '^#' "$reg" \
  | awk -F'\t' 'NF>=4 {printf "| %s | %s | %s | %s |\n",$1,$2,$3,$4}'
