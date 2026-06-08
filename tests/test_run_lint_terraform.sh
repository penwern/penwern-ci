# shellcheck shell=bash
# run-lint.sh terraform arm — shape/dispatch tests plus runtime smoke tests
# against fixtures when terraform is locally installed.

# terraform: missing repo-root -> exit 2 (caught before terraform invocation)
bash scripts/run-lint.sh terraform fixtures/terraform-does-not-exist >/tmp/rltf_noroot.out 2>&1; ec=$?
assert_exit "$ec" 2 "run-lint terraform: missing repo-root exits 2"

# terraform not on PATH -> exit 2. terraform often lives in /usr/bin alongside the
# coreutils run-lint.sh needs (dirname, pwd), so we can't just strip a PATH dir. Instead
# build a sandbox bin dir holding only those coreutils (no terraform) and run with that
# PATH, invoking bash by absolute path so the env-prefixed lookup can still find it.
_tf_sbox="$(mktmp)/bin"; mkdir -p "$_tf_sbox"
for _t in dirname pwd; do ln -sf "$(command -v "$_t")" "$_tf_sbox/$_t"; done
PATH="$_tf_sbox" "$(command -v bash)" scripts/run-lint.sh terraform fixtures/terraform-clean >/tmp/rltf_nopath.out 2>&1; ec=$?
assert_exit "$ec" 2 "run-lint terraform: terraform not on PATH exits 2"
assert_contains "$(cat /tmp/rltf_nopath.out)" "terraform" "run-lint terraform: not-on-PATH message mentions terraform"

# Runtime smoke tests — only when terraform is locally installed (skip otherwise).
if command -v terraform >/dev/null 2>&1; then
  # Clean fixture: well-formatted -> fmt rc 0 -> exit 0.
  bash scripts/run-lint.sh terraform fixtures/terraform-clean >/tmp/rltf_clean.out 2>&1; ec=$?
  assert_exit "$ec" 0 "run-lint terraform: clean fixture passes"

  # Dirty fixture: needs formatting -> fmt rc 3 -> findings -> exit 1.
  bash scripts/run-lint.sh terraform fixtures/terraform-dirty >/tmp/rltf_dirty.out 2>&1; ec=$?
  assert_exit "$ec" 1 "run-lint terraform: fmt findings fail the gate (exit 1)"
fi
