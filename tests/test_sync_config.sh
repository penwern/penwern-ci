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
