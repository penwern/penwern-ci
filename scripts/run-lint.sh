#!/usr/bin/env bash
# Usage: run-lint.sh <language> <repo-root>
# Exit codes: 0 = clean, 1 = lint/format findings, 2 = infra error (fail loud).
set -u
. "$(dirname "$0")/lib.sh"

[ "${1:-}" ] || die "usage: run-lint.sh <language> <repo-root>" 2
lang="$1"
[ "${2:-}" ] || die "usage: run-lint.sh <language> <repo-root>" 2
root="$2"
[ -d "$root" ] || die "repo-root '$root' does not exist" 2

case "$lang" in
  go)
    command -v golangci-lint >/dev/null 2>&1 || die "golangci-lint not installed" 2
    cfg="$PENWERN_CI_ROOT/configs/golangci.yml"
    [ -f "$cfg" ] || die "canonical config not found: $cfg" 2
    ( cd "$root" && golangci-lint run ./... --config "$cfg" ); gc_rc=$?
    [ "$gc_rc" -eq 0 ] && exit 0
    [ "$gc_rc" -eq 1 ] && exit 1
    die "golangci-lint exited $gc_rc (config/internal error — check '$cfg')" 2
    ;;
  python)
    command -v ruff >/dev/null 2>&1 || die "ruff not installed" 2
    ( cd "$root" && ruff check . ); rc_check=$?
    ( cd "$root" && ruff format --check . ); rc_fmt=$?
    { [ "$rc_check" -gt 1 ] || [ "$rc_fmt" -gt 1 ]; } && die "ruff exited (check=$rc_check fmt=$rc_fmt) — config/internal error" 2
    { [ "$rc_check" -eq 1 ] || [ "$rc_fmt" -eq 1 ]; } && exit 1
    exit 0
    ;;
  js-next|js-vanilla)
    [ -f "$root/package.json" ] || die "missing package.json in $root" 2
    ( cd "$root" && npm ci ) || die "npm ci failed in $root" 2
    rc_eslint=0
    ( cd "$root" && npx --no-install eslint . ) || rc_eslint=$?
    rc_prettier=0
    ( cd "$root" && npx --no-install prettier --check . ) || rc_prettier=$?
    # Map: rc 0 clean / 1 findings / >=2 infra
    [ "$rc_eslint" -ge 2 ] && die "eslint crashed (rc=$rc_eslint)" 2
    [ "$rc_prettier" -ge 2 ] && die "prettier crashed (rc=$rc_prettier)" 2
    if [ "$rc_eslint" -eq 1 ] || [ "$rc_prettier" -eq 1 ]; then exit 1; fi
    exit 0
    ;;
  ansible)
    command -v ansible-lint >/dev/null 2>&1 || die "ansible-lint not on PATH (workflow must pip-install at pinned version)" 2
    command -v yamllint     >/dev/null 2>&1 || die "yamllint not on PATH (workflow must pip-install at pinned version)" 2
    yl_cfg="$PENWERN_CI_ROOT/configs/yamllint.yml"
    [ -f "$yl_cfg" ] || die "canonical config not found: $yl_cfg" 2

    # yamllint (ENFORCED) — YAML hygiene over ALL git-tracked YAML. ansible-lint's own
    # project discovery silently under-reports in repos with a gitignored roles/ (bare
    # `ansible-lint .` can examine as few as a handful of top-level files and miss
    # group_vars/host_vars entirely), so yamllint is what actually enforces
    # newline/whitespace/indent hygiene across the tree. Non-strict: error-level rules gate;
    # warnings (e.g. document-start on encrypted vault.yml) are informational only. We feed
    # git-tracked files explicitly because yamllint does not honor .gitignore.
    rc_yl=0
    ( cd "$root" && git ls-files -z '*.yml' '*.yaml' | xargs -0 -r yamllint -c "$yl_cfg" ) || rc_yl=$?

    # ansible-lint (ENFORCED) — ansible-specific rules. The role-repo backlog has been
    # cleared (low-risk findings fixed; behavior-changing ones documented inline with
    # per-line `# noqa`, so the rules stay enabled for new code). Dummy
    # ANSIBLE_VAULT_PASSWORD_FILE lets it syntax-check vault-referencing vars without real
    # creds: ansible only crashes when the password file is missing/empty, so non-empty
    # content turns the failed decrypt into a non-fatal warning.
    _vault_pw="$(mktemp)" || die "failed to create dummy vault password file" 2
    printf 'penwern-ci-lint-stub\n' > "$_vault_pw"
    rc_al=0
    ( cd "$root" && ANSIBLE_VAULT_PASSWORD_FILE="$_vault_pw" ansible-lint . ) || rc_al=$?
    rm -f "$_vault_pw"
    # ansible-lint: 0 clean / 2 rule violations / anything else = internal/config error.
    [ "$rc_al" -ne 0 ] && [ "$rc_al" -ne 2 ] && die "ansible-lint failed (rc=$rc_al) — internal/config error" 2

    # Gate on both yamllint and ansible-lint. yamllint via xargs: 0 = clean; non-zero =
    # error-level findings (xargs maps yamllint's rc 1 to 123). Binaries + config pre-validated.
    if [ "$rc_yl" -ne 0 ] || [ "$rc_al" -eq 2 ]; then exit 1; fi
    exit 0
    ;;
  terraform)
    command -v terraform >/dev/null 2>&1 || die "terraform not on PATH (workflow must install at pinned version)" 2
    # `terraform fmt -check -recursive` is the ENFORCED gate: deterministic, needs no
    # `init`, no providers, and no cloud credentials, so it is safe and fast in CI.
    # `terraform validate` (needs per-module `init` + provider downloads, flaky across
    # multi-root-module repos) and `tflint` (plugin install) are deliberately DEFERRED —
    # add them as a ratchet once the fmt gate is clean, mirroring how the ansible path
    # started with yamllint enforced and layered ansible-lint in later.
    # fmt -check exit codes: 0 = formatted, 3 = files need formatting (findings),
    # anything else (e.g. 2) = a parse/diagnostic error in a .tf file (infra/fail-loud).
    ( cd "$root" && terraform fmt -check -recursive ); tf_rc=$?
    case "$tf_rc" in
      0) exit 0 ;;
      3) exit 1 ;;
      *) die "terraform fmt errored (rc=$tf_rc) — likely a syntax error in a .tf file" 2 ;;
    esac
    ;;
  *)
    die "unsupported language '$lang'" 2
    ;;
esac
exit 0
