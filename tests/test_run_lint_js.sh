# shellcheck shell=bash
# run-lint.sh JS arm — shape/dispatch tests only.
# Runtime npm-ci/eslint assertions are deferred to the first js PR's CI —
# analogous to Python's PR #41 first-run validation.

# bad language -> exit 2
bash scripts/run-lint.sh js-bad-lang /tmp >/tmp/rljsbad.out 2>&1; ec=$?
assert_exit "$ec" 2 "run-lint js: unsupported language exits 2"

# js-vanilla: missing package.json -> exit 2
_js_nopkg="$(mktmp)"
bash scripts/run-lint.sh js-vanilla "$_js_nopkg" >/tmp/rljs_nopkg.out 2>&1; ec=$?
assert_exit "$ec" 2 "run-lint js-vanilla: missing package.json exits 2"
assert_contains "$(cat /tmp/rljs_nopkg.out)" "package.json" "run-lint js-vanilla: missing package.json message mentions package.json"

# js-next: missing package.json -> exit 2
_jsn_nopkg="$(mktmp)"
bash scripts/run-lint.sh js-next "$_jsn_nopkg" >/tmp/rljsn_nopkg.out 2>&1; ec=$?
assert_exit "$ec" 2 "run-lint js-next: missing package.json exits 2"

# Both js-vanilla and js-next: missing repo-root -> exit 2 (caught before package.json check)
bash scripts/run-lint.sh js-vanilla fixtures/js-does-not-exist >/tmp/rljs_noroot.out 2>&1; ec=$?
assert_exit "$ec" 2 "run-lint js-vanilla: missing repo-root exits 2"

bash scripts/run-lint.sh js-next fixtures/js-does-not-exist >/tmp/rljsn_noroot.out 2>&1; ec=$?
assert_exit "$ec" 2 "run-lint js-next: missing repo-root exits 2"
