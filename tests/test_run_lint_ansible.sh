# shellcheck shell=bash
# run-lint.sh ansible arm — shape/dispatch tests only.
# Runtime ansible-lint assertions (clean/dirty fixture runs) are deferred to the
# first ansible PR's CI, analogous to the JS phase deferral in test_run_lint_js.sh.
# ansible-lint is not installed in the local dev environment and is pip-installed
# at pinned version only inside the reusable-lint workflow.

# bad language -> exit 2 (catches the unsupported-language fallback)
bash scripts/run-lint.sh ansible-bad-lang /tmp >/tmp/rlans_bad.out 2>&1; ec=$?
assert_exit "$ec" 2 "run-lint ansible: unsupported language exits 2"

# ansible: missing repo-root -> exit 2 (caught before ansible-lint invocation)
bash scripts/run-lint.sh ansible fixtures/ansible-does-not-exist >/tmp/rlans_noroot.out 2>&1; ec=$?
assert_exit "$ec" 2 "run-lint ansible: missing repo-root exits 2"

# ansible-lint not on PATH -> exit 2
# We simulate absence by constructing a PATH that excludes ansible-lint's real location.
# The run-lint.sh ansible arm guards with: command -v ansible-lint || die "..." 2
# If ansible-lint is not installed locally, this test exercises the guard directly.
# If it is installed, we strip its parent directory from PATH to expose the guard.
_ans_root="$(mktmp)"
cp fixtures/ansible-clean/.ansible-lint "$_ans_root/.ansible-lint"
cp fixtures/ansible-clean/.yamllint     "$_ans_root/.yamllint"
cp fixtures/ansible-clean/playbook.yml  "$_ans_root/playbook.yml"
_ansible_bin_dir="$(dirname "$(command -v ansible-lint 2>/dev/null || echo /nonexistent/ansible-lint)")"
_stripped_path="$(printf '%s' "$PATH" | tr ':' '\n' | grep -v "^${_ansible_bin_dir}$" | tr '\n' ':' | sed 's/:$//')"
PATH="$_stripped_path" bash scripts/run-lint.sh ansible "$_ans_root" >/tmp/rlans_nopath.out 2>&1; ec=$?
assert_exit "$ec" 2 "run-lint ansible: ansible-lint not on PATH exits 2"
assert_contains "$(cat /tmp/rlans_nopath.out)" "ansible-lint" "run-lint ansible: not-on-PATH message mentions ansible-lint"
