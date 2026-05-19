# shellcheck shell=bash
good="$(mktmp)"; cp configs/golangci.yml "$good/.golangci.yml"
bash scripts/check-drift.sh curate-preservation-core "$good" >/tmp/cd1.out 2>&1; ec=$?
assert_exit "$ec" 0 "drift: matching config exits 0"

bad="$(mktmp)"; cp configs/golangci.yml "$bad/.golangci.yml"; echo "extra: 1" >> "$bad/.golangci.yml"
bash scripts/check-drift.sh curate-preservation-core "$bad" >/tmp/cd2.out 2>&1; ec=$?
assert_exit "$ec" 1 "drift: divergent config exits 1"
assert_contains "$(cat /tmp/cd2.out)" "DRIFT" "drift: reports DRIFT"

missing="$(mktmp)"
bash scripts/check-drift.sh curate-preservation-core "$missing" >/tmp/cd3.out 2>&1; ec=$?
assert_exit "$ec" 1 "drift: absent config counts as drift"
