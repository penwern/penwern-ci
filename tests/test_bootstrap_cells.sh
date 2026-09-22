# shellcheck shell=bash
# The bootstrap talks to the ephemeral Cells with `curl -k` and carries a minted
# admin PAT on every request. That is safe only against a throwaway loopback
# container, so the script enforces the loopback boundary instead of documenting
# it. These cover the guard, which runs before any docker or network call and so
# needs no ephemeral stack.
_bc_compose="$(mktmp)/compose.yaml"
: > "$_bc_compose"
_bc() { COMPOSE_FILE="$_bc_compose" CURATE_BASE_URL="$1" HEALTH_RETRIES=1 \
          bash scripts/bootstrap-cells.sh 2>&1; }

out="$(_bc https://cells.example.com)"; ec=$?
assert_exit "$ec" 2 "bootstrap: remote host refused (exit 2)"
assert_contains "$out" "refusing to bootstrap against" "bootstrap: refusal names the rejected target"

# A host that merely starts with the loopback name must not pass: the guard has to
# anchor on the authority ending, not on a prefix.
out="$(_bc https://localhost.example.com:8080)"; ec=$?
assert_exit "$ec" 2 "bootstrap: loopback-lookalike host refused (exit 2)"

out="$(_bc http://localhost:8080)"; ec=$?
assert_exit "$ec" 2 "bootstrap: plaintext loopback refused (exit 2)"

# Accepted forms get past the guard and fail later, at the health wait, which is
# what proves the guard let them through rather than short-circuiting.
for _u in https://localhost:8080 https://127.0.0.1:8080 "https://[::1]:8080"; do
  out="$(_bc "$_u")"
  assert_contains "$out" "waiting for 'cells' healthcheck" "bootstrap: loopback form '$_u' accepted by the guard"
done
