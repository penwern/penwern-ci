# shellcheck shell=bash
target="$(mktmp)"

# Go repo: sync drops configs/golangci.yml as .golangci.yml at target root.
bash scripts/sync-config.sh curate-preservation-core "$target" >/tmp/sc1.out 2>&1; ec=$?
assert_exit "$ec" 0 "sync: go sync exits 0"
assert_exit "$([ -f "$target/.golangci.yml" ] && echo 0 || echo 1)" 0 "sync: .golangci.yml written"
assert_eq "$(diff -q configs/golangci.yml "$target/.golangci.yml" >/dev/null; echo $?)" "0" "sync: content matches canonical"

# --check on an in-sync target = exit 0, no write
bash scripts/sync-config.sh curate-preservation-core "$target" --check >/tmp/sc2.out 2>&1; ec=$?
assert_exit "$ec" 0 "sync --check: in-sync exits 0"

# --check on a drifted target = exit 1
echo "# drift" >> "$target/.golangci.yml"
bash scripts/sync-config.sh curate-preservation-core "$target" --check >/tmp/sc3.out 2>&1; ec=$?
assert_exit "$ec" 1 "sync --check: drift detected exits 1"

# cp failure on unwritable target dir must exit 2 (not silent success)
_ro="$(mktmp)"; chmod 500 "$_ro"
bash scripts/sync-config.sh curate-preservation-core "$_ro" >/tmp/sc4.out 2>&1; ec=$?
chmod 700 "$_ro"
assert_exit "$ec" 2 "sync: unwritable target exits 2 (no silent success)"

# unregistered slug exits 3
_t5="$(mktmp)"
bash scripts/sync-config.sh definitely-not-registered "$_t5" >/tmp/sc5.out 2>&1; ec=$?
assert_exit "$ec" 3 "sync: unregistered slug exits 3"

# ---------------------------------------------------------------------------
# Python arm tests — isolated temp registry
# ---------------------------------------------------------------------------
_py_reg="$(mktmp)/py-sync-reg.tsv"
printf '# repo\tlanguage\tmode\towner\n' > "$_py_reg"
printf 'py-sync-greenfield\tpython\tadvisory\tplatform\n' >> "$_py_reg"
printf 'py-sync-merge\tpython\tadvisory\tplatform\n'       >> "$_py_reg"
printf 'py-sync-refuse\tpython\tadvisory\tplatform\n'      >> "$_py_reg"
printf 'py-check-clean\tpython\tadvisory\tplatform\n'      >> "$_py_reg"
printf 'py-check-drift\tpython\tadvisory\tplatform\n'      >> "$_py_reg"
printf 'py-check-absent\tpython\tadvisory\tplatform\n'     >> "$_py_reg"

_pysync() { PENWERN_REGISTRY="$_py_reg" bash scripts/sync-config.sh "$@"; }

# 1. greenfield: no pyproject.toml — sync creates one byte-identical to canonical [tool.ruff*] block
_gf="$(mktmp)"
_pysync py-sync-greenfield "$_gf" >/tmp/py_sc1.out 2>&1; ec=$?
assert_exit "$ec" 0 "py sync: greenfield exits 0"
assert_exit "$([ -f "$_gf/pyproject.toml" ] && echo 0 || echo 1)" 0 "py sync: greenfield creates pyproject.toml"
_gf_ruff="$(awk '/^\[tool\.ruff/{f=1} /^\[/ && !/^\[tool\.ruff/{f=0} f' "$_gf/pyproject.toml")"
_canonical_ruff="$(sed -n '/^\[tool\.ruff/,$p' configs/ruff.pyproject-fragment.toml)"
assert_eq "$_gf_ruff" "$_canonical_ruff" "py sync: greenfield pyproject.toml matches canonical [tool.ruff*] block"

# 2. existing pyproject.toml with no [tool.ruff*]: sync appends; result contains both original section and canonical block
_mg="$(mktmp)"
printf '[project]\nname = "example"\nversion = "0.1.0"\n' > "$_mg/pyproject.toml"
_pysync py-sync-merge "$_mg" >/tmp/py_sc2.out 2>&1; ec=$?
assert_exit "$ec" 0 "py sync: append to existing pyproject.toml exits 0"
assert_contains "$(cat "$_mg/pyproject.toml")" "[project]" "py sync: append preserves original [project] section"
assert_contains "$(cat "$_mg/pyproject.toml")" "[tool.ruff]" "py sync: append adds [tool.ruff] block"

# 3. existing pyproject.toml that already has [tool.ruff]: sync refuses with exit 2
_rf="$(mktmp)"
printf '[tool.ruff]\nline-length = 88\n' > "$_rf/pyproject.toml"
_pysync py-sync-refuse "$_rf" >/tmp/py_sc3.out 2>&1; ec=$?
assert_exit "$ec" 2 "py sync: refuse when [tool.ruff*] already present exits 2"
assert_contains "$(cat /tmp/py_sc3.out)" "already has" "py sync: refuse message mentions 'already has'"

# 4. --check on in-sync pyproject.toml: exit 0
_ck="$(mktmp)"
sed -n '/^\[tool\.ruff/,$p' configs/ruff.pyproject-fragment.toml > "$_ck/pyproject.toml"
_pysync py-check-clean "$_ck" --check >/tmp/py_sc4.out 2>&1; ec=$?
assert_exit "$ec" 0 "py check: in-sync pyproject.toml exits 0"

# 5. --check on drifted pyproject.toml: exit 1 with diff
_dr="$(mktmp)"
sed -n '/^\[tool\.ruff/,$p' configs/ruff.pyproject-fragment.toml > "$_dr/pyproject.toml"
printf '\n# drift marker\n' >> "$_dr/pyproject.toml"
_pysync py-check-drift "$_dr" --check >/tmp/py_sc5.out 2>&1; ec=$?
assert_exit "$ec" 1 "py check: drifted pyproject.toml exits 1"
assert_contains "$(cat /tmp/py_sc5.out)" "DRIFT" "py check: drift output mentions DRIFT"

# 6. --check on missing pyproject.toml: exit 2
_ab="$(mktmp)"
_pysync py-check-absent "$_ab" --check >/tmp/py_sc6.out 2>&1; ec=$?
assert_exit "$ec" 2 "py check: absent pyproject.toml exits 2"

# ---------------------------------------------------------------------------
# JS arm tests — isolated temp registry, both js-vanilla and js-next flavours
# ---------------------------------------------------------------------------
_jsreg() {
  local f; f="$(mktmp)/js-sync-reg.tsv"
  printf '# repo\tlanguage\tmode\towner\n' > "$f"
  printf 'js-vani-gf\tjs-vanilla\tadvisory\tplatform\n'     >> "$f"
  printf 'js-vani-insync\tjs-vanilla\tadvisory\tplatform\n' >> "$f"
  printf 'js-vani-drift\tjs-vanilla\tadvisory\tplatform\n'  >> "$f"
  printf 'js-vani-chk-ok\tjs-vanilla\tadvisory\tplatform\n' >> "$f"
  printf 'js-vani-chk-dr\tjs-vanilla\tadvisory\tplatform\n' >> "$f"
  printf 'js-vani-chk-ab\tjs-vanilla\tadvisory\tplatform\n' >> "$f"
  printf 'js-next-gf\tjs-next\tadvisory\tplatform\n'        >> "$f"
  printf 'js-next-insync\tjs-next\tadvisory\tplatform\n'    >> "$f"
  printf 'js-next-drift\tjs-next\tadvisory\tplatform\n'     >> "$f"
  printf 'js-next-chk-ok\tjs-next\tadvisory\tplatform\n'   >> "$f"
  printf 'js-next-chk-dr\tjs-next\tadvisory\tplatform\n'   >> "$f"
  printf 'js-next-chk-ab\tjs-next\tadvisory\tplatform\n'   >> "$f"
  echo "$f"
}
_JSREG="$(_jsreg)"
_jssync() { PENWERN_REGISTRY="$_JSREG" bash scripts/sync-config.sh "$@"; }

# --- js-vanilla ---

# 1. greenfield (no eslint.config.mjs / .prettierrc.json): creates both byte-identical to canonical
_js_gf="$(mktmp)"
_jssync js-vani-gf "$_js_gf" >/tmp/js_sc1.out 2>&1; ec=$?
assert_exit "$ec" 0 "js-vanilla sync: greenfield exits 0"
assert_exit "$([ -f "$_js_gf/eslint.config.mjs" ] && echo 0 || echo 1)" 0 "js-vanilla sync: greenfield creates eslint.config.mjs"
assert_exit "$([ -f "$_js_gf/.prettierrc.json" ] && echo 0 || echo 1)" 0 "js-vanilla sync: greenfield creates .prettierrc.json"
assert_eq "$(diff -q "configs/eslint.vanilla.mjs" "$_js_gf/eslint.config.mjs" >/dev/null; echo $?)" "0" "js-vanilla sync: greenfield eslint.config.mjs matches canonical"
assert_eq "$(diff -q "configs/prettierrc.json" "$_js_gf/.prettierrc.json" >/dev/null; echo $?)" "0" "js-vanilla sync: greenfield .prettierrc.json matches canonical"

# 2. already in sync: idempotent, exit 0
_js_ins="$(mktmp)"
cp "configs/eslint.vanilla.mjs" "$_js_ins/eslint.config.mjs"
cp "configs/prettierrc.json"    "$_js_ins/.prettierrc.json"
_jssync js-vani-insync "$_js_ins" >/tmp/js_sc2.out 2>&1; ec=$?
assert_exit "$ec" 0 "js-vanilla sync: already-in-sync exits 0"

# 3. drift (eslint.config.mjs modified): refuses with exit 2
_js_dr="$(mktmp)"
cp "configs/eslint.vanilla.mjs" "$_js_dr/eslint.config.mjs"
cp "configs/prettierrc.json"    "$_js_dr/.prettierrc.json"
printf '\n// drift\n' >> "$_js_dr/eslint.config.mjs"
_jssync js-vani-drift "$_js_dr" >/tmp/js_sc3.out 2>&1; ec=$?
assert_exit "$ec" 2 "js-vanilla sync: drift in eslint.config.mjs refuses with exit 2"

# 4. --check in-sync: exit 0
_js_chkok="$(mktmp)"
cp "configs/eslint.vanilla.mjs" "$_js_chkok/eslint.config.mjs"
cp "configs/prettierrc.json"    "$_js_chkok/.prettierrc.json"
_jssync js-vani-chk-ok "$_js_chkok" --check >/tmp/js_sc4.out 2>&1; ec=$?
assert_exit "$ec" 0 "js-vanilla check: in-sync exits 0"

# 5. --check drift: exit 1 with diff output
_js_chkdr="$(mktmp)"
cp "configs/eslint.vanilla.mjs" "$_js_chkdr/eslint.config.mjs"
cp "configs/prettierrc.json"    "$_js_chkdr/.prettierrc.json"
printf '\n// drift\n' >> "$_js_chkdr/eslint.config.mjs"
_jssync js-vani-chk-dr "$_js_chkdr" --check >/tmp/js_sc5.out 2>&1; ec=$?
assert_exit "$ec" 1 "js-vanilla check: drift exits 1"
assert_contains "$(cat /tmp/js_sc5.out)" "DRIFT" "js-vanilla check: drift output mentions DRIFT"

# 6. --check config-absent: exit 2
_js_chkab="$(mktmp)"
_jssync js-vani-chk-ab "$_js_chkab" --check >/tmp/js_sc6.out 2>&1; ec=$?
assert_exit "$ec" 2 "js-vanilla check: config-absent exits 2"

# --- js-next ---

# 1. greenfield: creates both byte-identical to canonical
_jsn_gf="$(mktmp)"
_jssync js-next-gf "$_jsn_gf" >/tmp/jsn_sc1.out 2>&1; ec=$?
assert_exit "$ec" 0 "js-next sync: greenfield exits 0"
assert_exit "$([ -f "$_jsn_gf/eslint.config.mjs" ] && echo 0 || echo 1)" 0 "js-next sync: greenfield creates eslint.config.mjs"
assert_exit "$([ -f "$_jsn_gf/.prettierrc.json" ] && echo 0 || echo 1)" 0 "js-next sync: greenfield creates .prettierrc.json"
assert_eq "$(diff -q "configs/eslint.next.mjs" "$_jsn_gf/eslint.config.mjs" >/dev/null; echo $?)" "0" "js-next sync: greenfield eslint.config.mjs matches canonical"
assert_eq "$(diff -q "configs/prettierrc.json" "$_jsn_gf/.prettierrc.json" >/dev/null; echo $?)" "0" "js-next sync: greenfield .prettierrc.json matches canonical"

# 2. already in sync: idempotent, exit 0
_jsn_ins="$(mktmp)"
cp "configs/eslint.next.mjs" "$_jsn_ins/eslint.config.mjs"
cp "configs/prettierrc.json" "$_jsn_ins/.prettierrc.json"
_jssync js-next-insync "$_jsn_ins" >/tmp/jsn_sc2.out 2>&1; ec=$?
assert_exit "$ec" 0 "js-next sync: already-in-sync exits 0"

# 3. drift: refuses with exit 2
_jsn_dr="$(mktmp)"
cp "configs/eslint.next.mjs" "$_jsn_dr/eslint.config.mjs"
cp "configs/prettierrc.json" "$_jsn_dr/.prettierrc.json"
printf '\n// drift\n' >> "$_jsn_dr/eslint.config.mjs"
_jssync js-next-drift "$_jsn_dr" >/tmp/jsn_sc3.out 2>&1; ec=$?
assert_exit "$ec" 2 "js-next sync: drift refuses with exit 2"

# 4. --check in-sync: exit 0
_jsn_chkok="$(mktmp)"
cp "configs/eslint.next.mjs" "$_jsn_chkok/eslint.config.mjs"
cp "configs/prettierrc.json" "$_jsn_chkok/.prettierrc.json"
_jssync js-next-chk-ok "$_jsn_chkok" --check >/tmp/jsn_sc4.out 2>&1; ec=$?
assert_exit "$ec" 0 "js-next check: in-sync exits 0"

# 5. --check drift: exit 1 with diff output
_jsn_chkdr="$(mktmp)"
cp "configs/eslint.next.mjs" "$_jsn_chkdr/eslint.config.mjs"
cp "configs/prettierrc.json" "$_jsn_chkdr/.prettierrc.json"
printf '\n// drift\n' >> "$_jsn_chkdr/eslint.config.mjs"
_jssync js-next-chk-dr "$_jsn_chkdr" --check >/tmp/jsn_sc5.out 2>&1; ec=$?
assert_exit "$ec" 1 "js-next check: drift exits 1"
assert_contains "$(cat /tmp/jsn_sc5.out)" "DRIFT" "js-next check: drift output mentions DRIFT"

# 6. --check config-absent: exit 2
_jsn_chkab="$(mktmp)"
_jssync js-next-chk-ab "$_jsn_chkab" --check >/tmp/jsn_sc6.out 2>&1; ec=$?
assert_exit "$ec" 2 "js-next check: config-absent exits 2"

# ---------------------------------------------------------------------------
# Ansible arm tests — isolated temp registry
# ---------------------------------------------------------------------------
_ansreg() {
  local f; f="$(mktmp)/ansible-sync-reg.tsv"
  printf '# repo\tlanguage\tmode\towner\n' > "$f"
  printf 'ansible-sync-greenfield\tansible\tadvisory\tplatform\n' >> "$f"
  printf 'ansible-sync-insync\tansible\tadvisory\tplatform\n'     >> "$f"
  printf 'ansible-sync-drift\tansible\tadvisory\tplatform\n'      >> "$f"
  printf 'ansible-check-clean\tansible\tadvisory\tplatform\n'     >> "$f"
  printf 'ansible-check-drift\tansible\tadvisory\tplatform\n'     >> "$f"
  printf 'ansible-check-absent\tansible\tadvisory\tplatform\n'    >> "$f"
  echo "$f"
}
_ANSREG="$(_ansreg)"
_anssync() { PENWERN_REGISTRY="$_ANSREG" bash scripts/sync-config.sh "$@"; }

# 1. greenfield: no .ansible-lint or .yamllint — sync creates both byte-identical to canonical
_ans_gf="$(mktmp)"
_anssync ansible-sync-greenfield "$_ans_gf" >/tmp/ans_sc1.out 2>&1; ec=$?
assert_exit "$ec" 0 "ansible sync: greenfield exits 0"
assert_exit "$([ -f "$_ans_gf/.ansible-lint" ] && echo 0 || echo 1)" 0 "ansible sync: greenfield creates .ansible-lint"
assert_exit "$([ -f "$_ans_gf/.yamllint" ] && echo 0 || echo 1)" 0 "ansible sync: greenfield creates .yamllint"
assert_eq "$(diff -q configs/ansible-lint.yml "$_ans_gf/.ansible-lint" >/dev/null; echo $?)" "0" "ansible sync: greenfield .ansible-lint matches canonical"
assert_eq "$(diff -q configs/yamllint.yml "$_ans_gf/.yamllint" >/dev/null; echo $?)" "0" "ansible sync: greenfield .yamllint matches canonical"

# 2. already in sync: idempotent, exit 0
_ans_ins="$(mktmp)"
cp configs/ansible-lint.yml "$_ans_ins/.ansible-lint"
cp configs/yamllint.yml     "$_ans_ins/.yamllint"
_anssync ansible-sync-insync "$_ans_ins" >/tmp/ans_sc2.out 2>&1; ec=$?
assert_exit "$ec" 0 "ansible sync: already-in-sync exits 0"

# 3. drift in .ansible-lint: refuses with exit 2
_ans_dr="$(mktmp)"
cp configs/ansible-lint.yml "$_ans_dr/.ansible-lint"
cp configs/yamllint.yml     "$_ans_dr/.yamllint"
printf '\n# drift\n' >> "$_ans_dr/.ansible-lint"
_anssync ansible-sync-drift "$_ans_dr" >/tmp/ans_sc3.out 2>&1; ec=$?
assert_exit "$ec" 2 "ansible sync: drift in .ansible-lint refuses with exit 2"

# 4. --check in-sync: exit 0
_ans_chkok="$(mktmp)"
cp configs/ansible-lint.yml "$_ans_chkok/.ansible-lint"
cp configs/yamllint.yml     "$_ans_chkok/.yamllint"
_anssync ansible-check-clean "$_ans_chkok" --check >/tmp/ans_sc4.out 2>&1; ec=$?
assert_exit "$ec" 0 "ansible check: in-sync exits 0"

# 5. --check drift: exit 1 with diff output
_ans_chkdr="$(mktmp)"
cp configs/ansible-lint.yml "$_ans_chkdr/.ansible-lint"
cp configs/yamllint.yml     "$_ans_chkdr/.yamllint"
printf '\n# drift\n' >> "$_ans_chkdr/.yamllint"
_anssync ansible-check-drift "$_ans_chkdr" --check >/tmp/ans_sc5.out 2>&1; ec=$?
assert_exit "$ec" 1 "ansible check: drift exits 1"
assert_contains "$(cat /tmp/ans_sc5.out)" "DRIFT" "ansible check: drift output mentions DRIFT"

# 6. --check config-absent: exit 2
_ans_chkab="$(mktmp)"
_anssync ansible-check-absent "$_ans_chkab" --check >/tmp/ans_sc6.out 2>&1; ec=$?
assert_exit "$ec" 2 "ansible check: config-absent exits 2"

# ---------------------------------------------------------------------------
# --update flag — force-replace canonical block when canonical evolves
# ---------------------------------------------------------------------------

# unknown flag exits 2
bash scripts/sync-config.sh curate-preservation-core "$(mktmp)" --bogus >/tmp/uf1.out 2>&1; ec=$?
assert_exit "$ec" 2 "sync: unknown flag exits 2"
assert_contains "$(cat /tmp/uf1.out)" "unknown flag" "sync: unknown flag message"

# --- Go --update ---

# 1. drifted .golangci.yml: default refuses with exit 2
_go_dr="$(mktmp)"
cp configs/golangci.yml "$_go_dr/.golangci.yml"
printf '\n# drift\n' >> "$_go_dr/.golangci.yml"
bash scripts/sync-config.sh curate-preservation-core "$_go_dr" >/tmp/go_up1.out 2>&1; ec=$?
assert_exit "$ec" 2 "go sync (default): drift refuses with exit 2"
assert_contains "$(cat /tmp/go_up1.out)" "rerun with --update" "go sync (default): suggests --update"

# 2. --update: overwrites drift, exits 0, content matches canonical
bash scripts/sync-config.sh curate-preservation-core "$_go_dr" --update >/tmp/go_up2.out 2>&1; ec=$?
assert_exit "$ec" 0 "go sync --update: overwrites drift, exits 0"
assert_eq "$(diff -q configs/golangci.yml "$_go_dr/.golangci.yml" >/dev/null; echo $?)" "0" "go sync --update: result matches canonical"

# --- Python --update ---

# 3. existing [tool.ruff]: default refuses
_py_up="$(mktmp)"
printf '[project]\nname = "x"\nversion = "0.1.0"\n\n[tool.ruff]\nline-length = 88\n[tool.ruff.lint]\nselect = ["E"]\n' > "$_py_up/pyproject.toml"
PENWERN_REGISTRY="$_py_reg" bash scripts/sync-config.sh py-sync-refuse "$_py_up" >/tmp/py_up1.out 2>&1; ec=$?
assert_exit "$ec" 2 "py sync (default): existing [tool.ruff*] refuses with exit 2"
assert_contains "$(cat /tmp/py_up1.out)" "rerun with --update" "py sync (default): suggests --update"

# 4. --update: strips old [tool.ruff*], appends canonical, preserves [project]
PENWERN_REGISTRY="$_py_reg" bash scripts/sync-config.sh py-sync-refuse "$_py_up" --update >/tmp/py_up2.out 2>&1; ec=$?
assert_exit "$ec" 0 "py sync --update: rewrites [tool.ruff*] block, exits 0"
assert_contains "$(cat "$_py_up/pyproject.toml")" "[project]" "py sync --update: preserves original [project] section"
# Canonical [tool.ruff*] block must match byte-for-byte after rewrite
_after_ruff="$(awk '/^\[tool\.ruff/{f=1} /^\[/ && !/^\[tool\.ruff/{f=0} f' "$_py_up/pyproject.toml")"
_canonical_ruff="$(sed -n '/^\[tool\.ruff/,$p' configs/ruff.pyproject-fragment.toml)"
assert_eq "$_after_ruff" "$_canonical_ruff" "py sync --update: rewritten [tool.ruff*] matches canonical"
# Old drift marker must be gone
case "$(cat "$_py_up/pyproject.toml")" in
  *"line-length = 88"*) _pcfail "py sync --update: did not strip old [tool.ruff] line-length=88"; TESTS_RUN=$((TESTS_RUN + 1)) ;;
  *) TESTS_RUN=$((TESTS_RUN + 1)) ;;
esac

# --- JS --update ---

# 5. drifted eslint.config.mjs: default refuses
_js_up="$(mktmp)"
cp configs/eslint.vanilla.mjs "$_js_up/eslint.config.mjs"
cp configs/prettierrc.json    "$_js_up/.prettierrc.json"
printf '\n// drift\n' >> "$_js_up/eslint.config.mjs"
PENWERN_REGISTRY="$_JSREG" bash scripts/sync-config.sh js-vani-drift "$_js_up" >/tmp/js_up1.out 2>&1; ec=$?
assert_exit "$ec" 2 "js-vanilla sync (default): drift refuses with exit 2"
assert_contains "$(cat /tmp/js_up1.out)" "rerun with --update" "js-vanilla sync (default): suggests --update"

# 6. --update: overwrites drift, both files match canonical
PENWERN_REGISTRY="$_JSREG" bash scripts/sync-config.sh js-vani-drift "$_js_up" --update >/tmp/js_up2.out 2>&1; ec=$?
assert_exit "$ec" 0 "js-vanilla sync --update: overwrites drift, exits 0"
assert_eq "$(diff -q configs/eslint.vanilla.mjs "$_js_up/eslint.config.mjs" >/dev/null; echo $?)" "0" "js-vanilla --update: eslint.config.mjs matches canonical"
assert_eq "$(diff -q configs/prettierrc.json    "$_js_up/.prettierrc.json"  >/dev/null; echo $?)" "0" "js-vanilla --update: .prettierrc.json matches canonical"

# --- Ansible --update ---

# 7. drifted .ansible-lint: default refuses
_ans_up="$(mktmp)"
cp configs/ansible-lint.yml "$_ans_up/.ansible-lint"
cp configs/yamllint.yml     "$_ans_up/.yamllint"
printf '\n# drift\n' >> "$_ans_up/.ansible-lint"
PENWERN_REGISTRY="$_ANSREG" bash scripts/sync-config.sh ansible-sync-drift "$_ans_up" >/tmp/ans_up1.out 2>&1; ec=$?
assert_exit "$ec" 2 "ansible sync (default): drift refuses with exit 2"
assert_contains "$(cat /tmp/ans_up1.out)" "rerun with --update" "ansible sync (default): suggests --update"

# 8. --update: overwrites drift, both files match canonical
PENWERN_REGISTRY="$_ANSREG" bash scripts/sync-config.sh ansible-sync-drift "$_ans_up" --update >/tmp/ans_up2.out 2>&1; ec=$?
assert_exit "$ec" 0 "ansible sync --update: overwrites drift, exits 0"
assert_eq "$(diff -q configs/ansible-lint.yml "$_ans_up/.ansible-lint" >/dev/null; echo $?)" "0" "ansible --update: .ansible-lint matches canonical"
assert_eq "$(diff -q configs/yamllint.yml     "$_ans_up/.yamllint"     >/dev/null; echo $?)" "0" "ansible --update: .yamllint matches canonical"
