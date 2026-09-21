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

# The canonical pins must be present: the JS arm installs eslint/prettier at the
# pinned versions rather than using the repo's own copies, so an unset variable is
# an infra error (exit 2), never a silent fall-back to whatever the repo shipped.
_js_pkg="$(mktmp)"; printf '{"name":"t","version":"1.0.0"}\n' > "$_js_pkg/package.json"

( unset ESLINT_VERSION; PRETTIER_VERSION=3.9.8 bash scripts/run-lint.sh js-vanilla "$_js_pkg" ) >/tmp/rljs_noesl.out 2>&1; ec=$?
assert_exit "$ec" 2 "run-lint js: unset ESLINT_VERSION exits 2"
assert_contains "$(cat /tmp/rljs_noesl.out)" "ESLINT_VERSION" "run-lint js: unset ESLINT_VERSION names the variable"

( unset PRETTIER_VERSION; ESLINT_VERSION=9.39.4 bash scripts/run-lint.sh js-vanilla "$_js_pkg" ) >/tmp/rljs_nopret.out 2>&1; ec=$?
assert_exit "$ec" 2 "run-lint js: unset PRETTIER_VERSION exits 2"
assert_contains "$(cat /tmp/rljs_nopret.out)" "PRETTIER_VERSION" "run-lint js: unset PRETTIER_VERSION names the variable"

# The js arm must not reach for the repo's own linters any more. Strip comments
# first: the code comment explaining WHY the flag was dropped names it too.
assert_eq "$(sed 's/#.*//' scripts/run-lint.sh | grep -c -- '--no-install')" "0" \
  "run-lint js: no --no-install on an executable line (pins would be bypassed)"

# ...and it must invoke the pinned versions, not bare tool names. The single quotes
# are deliberate: these are literal grep patterns, not expansions.
# shellcheck disable=SC2016
assert_eq "$(sed 's/#.*//' scripts/run-lint.sh | grep -c -- 'eslint@\$ESLINT_VERSION')" "1" \
  "run-lint js: eslint invoked at the pinned version"
# shellcheck disable=SC2016
assert_eq "$(sed 's/#.*//' scripts/run-lint.sh | grep -c -- 'prettier@\$PRETTIER_VERSION')" "1" \
  "run-lint js: prettier invoked at the pinned version"
