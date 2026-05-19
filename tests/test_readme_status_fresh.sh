# shellcheck shell=bash
# The README Status table is a static snapshot of registry.tsv. This test fails
# if registry.tsv changed without regenerating the README (see Task 16 / gen-status.sh).
_expected="$(bash scripts/gen-status.sh)"
# README's table is the trailing block starting at the header row through EOF.
_actual="$(sed -n '/^| Repo | Language | Mode | Owner |/,$p' README.md)"
assert_eq "$_actual" "$_expected" "README Status table is in sync with gen-status.sh / registry.tsv"
