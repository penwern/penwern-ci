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
