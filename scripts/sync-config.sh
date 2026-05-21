#!/usr/bin/env bash
# Usage: sync-config.sh <repo-slug> <target-dir> [--check|--update]
# Copies the canonical config(s) for the repo's language into <target-dir>.
#   (default)  greenfield-write; refuse if existing config differs from canonical
#   --check    no-write; exit 0 in-sync / 1 drift (with diff) / 2 config-absent
#   --update   force-replace the canonical block(s) in an existing config (used when the
#              canonical evolves — e.g. target-version bump, new ignores, new rules).
set -u
here="$(dirname "$0")"
. "$here/lib.sh"

slug="${1:-}"; [ -n "$slug" ] || die "usage: sync-config.sh <repo-slug> <target-dir> [--check|--update]" 2
target="${2:-}"; [ -n "$target" ] || die "usage: sync-config.sh <repo-slug> <target-dir> [--check|--update]" 2
check=0; update=0
case "${3:-}" in
  --check)  check=1 ;;
  --update) update=1 ;;
  '')       ;;
  *)        die "unknown flag '${3:-}'; supported: --check, --update" 2 ;;
esac
[ -d "$target" ] || die "target-dir '$target' does not exist" 2

reg="${PENWERN_REGISTRY:-$PENWERN_CI_ROOT/registry.tsv}"
[ -f "$reg" ] || die "registry not found at $reg" 2
lang="$(grep -v '^#' "$reg" | awk -F'\t' -v r="$slug" '$1==r {print $2; exit}')"
[ -n "$lang" ] || die "repo '$slug' not registered" 3

case "$lang" in
  go)
    src="$PENWERN_CI_ROOT/configs/golangci.yml"
    dst="$target/.golangci.yml"
    [ -f "$src" ] || die "canonical config missing: $src" 2

    if [ "$check" -eq 1 ]; then
      if [ -f "$dst" ] && diff -q "$src" "$dst" >/dev/null 2>&1; then
        log "in sync: $slug"
        exit 0
      fi
      log "DRIFT: $dst differs from canonical $src"
      if [ ! -f "$dst" ]; then
        log "(dst does not exist — config is absent from the repo)"
      else
        # diff direction: current (repo) -> target (canonical); reads as "what to apply"
        diff -u "$dst" "$src" 2>/dev/null || true
      fi
      exit 1
    fi

    if [ "$update" -eq 1 ] && [ -f "$dst" ]; then
      cp "$src" "$dst" || die "failed to update $dst from $src" 2
      log "updated $dst from canonical"
      exit 0
    fi

    if [ -f "$dst" ] && ! diff -q "$src" "$dst" >/dev/null 2>&1; then
      die ".golangci.yml already exists and differs from canonical; rerun with --update to overwrite" 2
    fi

    cp "$src" "$dst" || die "failed to write $dst from $src" 2
    log "wrote $dst from canonical"
    exit 0
    ;;

  python)
    fragment="$PENWERN_CI_ROOT/configs/ruff.pyproject-fragment.toml"
    [ -f "$fragment" ] || die "canonical config missing: $fragment" 2
    dst="$target/pyproject.toml"

    if [ "$check" -eq 1 ]; then
      if [ ! -f "$dst" ]; then
        log "DRIFT: pyproject.toml absent from $target (config-absent is drift)"
        exit 2
      fi
      # Extract [tool.ruff*] sections from the repo's pyproject.toml
      repo_ruff="$(awk '/^\[tool\.ruff/{f=1} /^\[/ && !/^\[tool\.ruff/{f=0} f' "$dst")"
      # Strip preamble from canonical to get just the [tool.ruff*] block
      canonical_ruff="$(sed -n '/^\[tool\.ruff/,$p' "$fragment")"
      if [ "$repo_ruff" = "$canonical_ruff" ]; then
        log "in sync: $slug"
        exit 0
      fi
      log "DRIFT: [tool.ruff*] sections differ from canonical in $dst"
      diff -u <(printf '%s\n' "$repo_ruff") <(printf '%s\n' "$canonical_ruff") 2>/dev/null || true
      exit 1
    fi

    if [ ! -f "$dst" ]; then
      # Greenfield: create pyproject.toml from canonical fragment
      cp "$fragment" "$dst" || die "failed to write $dst from $fragment" 2
      log "wrote pyproject.toml from canonical (greenfield)"
      exit 0
    fi

    # pyproject.toml exists — check for existing [tool.ruff*] sections
    existing_ruff="$(awk '/^\[tool\.ruff/{f=1} /^\[/ && !/^\[tool\.ruff/{f=0} f' "$dst")"

    if [ "$update" -eq 1 ] && [ -n "$existing_ruff" ]; then
      # Strip existing [tool.ruff*] sections (everything from the first [tool.ruff*] header
      # through any contiguous [tool.ruff*] sections; stop at the next non-ruff [section] header)
      tmp="$(mktemp)" || die "failed to create tempfile for $dst rewrite" 2
      awk '
        /^\[tool\.ruff/ { in_ruff=1; next }
        /^\[/ && !/^\[tool\.ruff/ { in_ruff=0 }
        !in_ruff { print }
      ' "$dst" > "$tmp" || { rm -f "$tmp"; die "failed to strip existing [tool.ruff*] from $dst" 2; }
      # Trim trailing blank lines from stripped pyproject before re-appending canonical
      awk 'NF{p=NR} {l[NR]=$0} END{for(i=1;i<=p;i++) print l[i]}' "$tmp" > "$dst" || { rm -f "$tmp"; die "failed to rewrite $dst" 2; }
      rm -f "$tmp"
      # Append canonical fragment (strip preamble — start from first [tool.ruff*])
      { echo; sed -n '/^\[tool\.ruff/,$p' "$fragment"; } >> "$dst" || die "failed to append canonical to $dst" 2
      log "updated [tool.ruff*] block in pyproject.toml from canonical"
      exit 0
    fi

    if [ -n "$existing_ruff" ]; then
      die "pyproject.toml already has [tool.ruff*] sections; rerun with --update to overwrite, or merge by hand (duplicate TOML tables are invalid)" 2
    fi

    # Append canonical fragment
    { echo; cat "$fragment"; } >> "$dst" || die "failed to append to $dst" 2
    log "appended canonical [tool.ruff*] block to pyproject.toml"
    exit 0
    ;;

  js-vanilla|js-next)
    if [ "$lang" = "js-vanilla" ]; then
      src_eslint="$PENWERN_CI_ROOT/configs/eslint.vanilla.mjs"
    else
      src_eslint="$PENWERN_CI_ROOT/configs/eslint.next.mjs"
    fi
    src_prettier="$PENWERN_CI_ROOT/configs/prettierrc.json"
    [ -f "$src_eslint" ]   || die "canonical config missing: $src_eslint" 2
    [ -f "$src_prettier" ] || die "canonical config missing: $src_prettier" 2
    dst_eslint="$target/eslint.config.mjs"
    dst_prettier="$target/.prettierrc.json"

    if [ "$check" -eq 1 ]; then
      # --check: absent config = exit 2; differ = exit 1; both in sync = exit 0
      if [ ! -f "$dst_eslint" ] || [ ! -f "$dst_prettier" ]; then
        log "DRIFT: one or both JS config files absent from $target (config-absent is drift)"
        exit 2
      fi
      drift=0
      if ! diff -q "$src_eslint" "$dst_eslint" >/dev/null 2>&1; then
        log "DRIFT: $dst_eslint differs from canonical $src_eslint"
        diff -u "$dst_eslint" "$src_eslint" 2>/dev/null || true
        drift=1
      fi
      if ! diff -q "$src_prettier" "$dst_prettier" >/dev/null 2>&1; then
        log "DRIFT: $dst_prettier differs from canonical $src_prettier"
        diff -u "$dst_prettier" "$src_prettier" 2>/dev/null || true
        drift=1
      fi
      if [ "$drift" -eq 0 ]; then
        log "in sync: $slug"
        exit 0
      fi
      exit 1
    fi

    # Write mode
    eslint_present=0; prettier_present=0
    [ -f "$dst_eslint" ]   && eslint_present=1
    [ -f "$dst_prettier" ] && prettier_present=1

    if [ "$update" -eq 1 ] && { [ "$eslint_present" -eq 1 ] || [ "$prettier_present" -eq 1 ]; }; then
      cp "$src_eslint"   "$dst_eslint"   || die "failed to update $dst_eslint from $src_eslint" 2
      cp "$src_prettier" "$dst_prettier" || die "failed to update $dst_prettier from $src_prettier" 2
      log "updated eslint.config.mjs + .prettierrc.json from canonical"
      exit 0
    fi

    if [ "$eslint_present" -eq 0 ] && [ "$prettier_present" -eq 0 ]; then
      # Greenfield: write both
      cp "$src_eslint"   "$dst_eslint"   || die "failed to write $dst_eslint from $src_eslint" 2
      cp "$src_prettier" "$dst_prettier" || die "failed to write $dst_prettier from $src_prettier" 2
      log "wrote eslint.config.mjs + .prettierrc.json from canonical (greenfield)"
      exit 0
    fi

    # One or both exist — check for drift and refuse if differs
    eslint_ok=1; prettier_ok=1
    [ "$eslint_present" -eq 1 ] && ! diff -q "$src_eslint" "$dst_eslint" >/dev/null 2>&1 && eslint_ok=0
    [ "$prettier_present" -eq 1 ] && ! diff -q "$src_prettier" "$dst_prettier" >/dev/null 2>&1 && prettier_ok=0

    if [ "$eslint_ok" -eq 0 ]; then
      die "eslint.config.mjs already exists and differs from canonical; rerun with --update to overwrite (canonical at configs/eslint.${lang#js-}.mjs)" 2
    fi
    if [ "$prettier_ok" -eq 0 ]; then
      die ".prettierrc.json already exists and differs from canonical; rerun with --update to overwrite (canonical at configs/prettierrc.json)" 2
    fi

    # Both in sync (or one absent but no drift on the existing one — handle missing half)
    if [ "$eslint_present" -eq 0 ]; then
      cp "$src_eslint" "$dst_eslint" || die "failed to write $dst_eslint from $src_eslint" 2
      log "wrote eslint.config.mjs from canonical (was missing)"
    fi
    if [ "$prettier_present" -eq 0 ]; then
      cp "$src_prettier" "$dst_prettier" || die "failed to write $dst_prettier from $src_prettier" 2
      log "wrote .prettierrc.json from canonical (was missing)"
    fi
    if [ "$eslint_present" -eq 1 ] && [ "$prettier_present" -eq 1 ]; then
      log "already in sync: $slug"
    fi
    exit 0
    ;;

  ansible)
    src_ansible_lint="$PENWERN_CI_ROOT/configs/ansible-lint.yml"
    src_yamllint="$PENWERN_CI_ROOT/configs/yamllint.yml"
    [ -f "$src_ansible_lint" ] || die "canonical config missing: $src_ansible_lint" 2
    [ -f "$src_yamllint" ]     || die "canonical config missing: $src_yamllint" 2
    dst_ansible_lint="$target/.ansible-lint"
    dst_yamllint="$target/.yamllint"

    if [ "$check" -eq 1 ]; then
      # --check: absent → exit 2; differ → exit 1 with diff; both in-sync → exit 0
      if [ ! -f "$dst_ansible_lint" ] || [ ! -f "$dst_yamllint" ]; then
        log "DRIFT: one or both ansible config files absent from $target (config-absent is drift)"
        exit 2
      fi
      drift=0
      if ! diff -q "$src_ansible_lint" "$dst_ansible_lint" >/dev/null 2>&1; then
        log "DRIFT: $dst_ansible_lint differs from canonical $src_ansible_lint"
        diff -u "$dst_ansible_lint" "$src_ansible_lint" 2>/dev/null || true
        drift=1
      fi
      if ! diff -q "$src_yamllint" "$dst_yamllint" >/dev/null 2>&1; then
        log "DRIFT: $dst_yamllint differs from canonical $src_yamllint"
        diff -u "$dst_yamllint" "$src_yamllint" 2>/dev/null || true
        drift=1
      fi
      if [ "$drift" -eq 0 ]; then
        log "in sync: $slug"
        exit 0
      fi
      exit 1
    fi

    # Write mode
    ansible_lint_present=0; yamllint_present=0
    [ -f "$dst_ansible_lint" ] && ansible_lint_present=1
    [ -f "$dst_yamllint" ]     && yamllint_present=1

    if [ "$update" -eq 1 ] && { [ "$ansible_lint_present" -eq 1 ] || [ "$yamllint_present" -eq 1 ]; }; then
      cp "$src_ansible_lint" "$dst_ansible_lint" || die "failed to update $dst_ansible_lint from $src_ansible_lint" 2
      cp "$src_yamllint"     "$dst_yamllint"     || die "failed to update $dst_yamllint from $src_yamllint" 2
      log "updated .ansible-lint + .yamllint from canonical"
      exit 0
    fi

    if [ "$ansible_lint_present" -eq 0 ] && [ "$yamllint_present" -eq 0 ]; then
      # Greenfield: write both
      cp "$src_ansible_lint" "$dst_ansible_lint" || die "failed to write $dst_ansible_lint from $src_ansible_lint" 2
      cp "$src_yamllint"     "$dst_yamllint"     || die "failed to write $dst_yamllint from $src_yamllint" 2
      log "wrote .ansible-lint + .yamllint from canonical (greenfield)"
      exit 0
    fi

    # One or both exist — check for drift and refuse if differs
    ansible_lint_ok=1; yamllint_ok=1
    [ "$ansible_lint_present" -eq 1 ] && ! diff -q "$src_ansible_lint" "$dst_ansible_lint" >/dev/null 2>&1 && ansible_lint_ok=0
    [ "$yamllint_present" -eq 1 ]     && ! diff -q "$src_yamllint" "$dst_yamllint" >/dev/null 2>&1         && yamllint_ok=0

    if [ "$ansible_lint_ok" -eq 0 ]; then
      die ".ansible-lint already exists and differs from canonical; rerun with --update to overwrite (canonical at configs/ansible-lint.yml)" 2
    fi
    if [ "$yamllint_ok" -eq 0 ]; then
      die ".yamllint already exists and differs from canonical; rerun with --update to overwrite (canonical at configs/yamllint.yml)" 2
    fi

    # Both in sync (or one absent but no drift on the existing one — handle missing half)
    if [ "$ansible_lint_present" -eq 0 ]; then
      cp "$src_ansible_lint" "$dst_ansible_lint" || die "failed to write $dst_ansible_lint from $src_ansible_lint" 2
      log "wrote .ansible-lint from canonical (was missing)"
    fi
    if [ "$yamllint_present" -eq 0 ]; then
      cp "$src_yamllint" "$dst_yamllint" || die "failed to write $dst_yamllint from $src_yamllint" 2
      log "wrote .yamllint from canonical (was missing)"
    fi
    if [ "$ansible_lint_present" -eq 1 ] && [ "$yamllint_present" -eq 1 ]; then
      log "already in sync: $slug"
    fi
    exit 0
    ;;

  *)
    die "sync not implemented for language '$lang' (engine is pluggable; add an arm)" 2
    ;;
esac
