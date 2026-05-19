# shellcheck shell=bash
assert_eq "a" "a" "harness: eq matches"
assert_contains "hello world" "lo wo" "harness: contains matches"
assert_exit 0 0 "harness: exit matches"
_harness_tmp="$(mktmp)"; [ -d "$_harness_tmp" ] && assert_eq "dir" "dir" "harness: mktmp made a dir" || _pcfail "mktmp failed"
rm -rf "$_harness_tmp"
unset _harness_tmp
