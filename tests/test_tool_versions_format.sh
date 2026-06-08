# shellcheck shell=bash
# configs/tool-versions.env is `cat`-ed into $GITHUB_ENV by every reusable workflow
# (reusable-lint/test/e2e/security). $GITHUB_ENV only accepts KEY=VALUE lines, so a
# comment or stray line breaks EVERY consumer's CI with "Invalid format" — and the
# bash suite would not catch it (scripts `source` the file, which tolerates comments).
# This test enforces the cat-into-GITHUB_ENV contract: every line must be KEY=VALUE.
_tv="${PENWERN_CI_ROOT:-.}/configs/tool-versions.env"
assert_eq "$([ -f "$_tv" ] && echo y)" "y" "tool-versions.env exists"

_tv_bad=0
while IFS= read -r _line || [ -n "$_line" ]; do
  # Allow genuinely empty lines (GITHUB_ENV ignores them); reject everything that is
  # not a NAME=VALUE assignment (this catches '# comment' lines and stray text).
  [ -z "$_line" ] && continue
  case "$_line" in
    [A-Za-z_]*=*) : ;;
    *) echo "  offending line: [$_line]"; _tv_bad=1 ;;
  esac
done < "$_tv"
assert_eq "$_tv_bad" "0" "tool-versions.env is KEY=VALUE only (no comments — it is cat-ed into \$GITHUB_ENV)"
