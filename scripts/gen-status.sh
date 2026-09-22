#!/usr/bin/env bash
# Renders the registry as a Markdown table on stdout.
#
# Every mode column in registry.tsv gets its own column here. A generator that
# renders only some of them reports "this repo is opted out of that gate"
# identically to "this repo passes that gate", so a short row is an error, not
# something to render partially.
set -u
# shellcheck source=scripts/lib.sh
. "$(dirname "$0")/lib.sh"
reg="${PENWERN_REGISTRY:-$PENWERN_CI_ROOT/registry.tsv}"
[ -f "$reg" ] || die "registry not found at $reg" 2

# repo slugs cannot start with '#', so '^#' lines are always comments — safe to strip.
short="$(grep -v '^#' "$reg" | awk -F'\t' 'NF>0 && NF<6 {printf "%s (%d fields)\n",$1,NF}')"
[ -z "$short" ] || die "registry rows missing mode columns (expected 6): $(echo "$short" | tr '\n' ' ')" 2

echo "| Repo | Language | Lint | Tests | Security | Owner |"
echo "| --- | --- | --- | --- | --- | --- |"
grep -v '^#' "$reg" \
  | awk -F'\t' 'NF>=6 {printf "| %s | %s | %s | %s | %s | %s |\n",$1,$2,$3,$5,$6,$4}'
