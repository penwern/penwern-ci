# shellcheck shell=bash
# Shared helpers. PENWERN_CI_ROOT = repo root of penwern-ci itself.
# Source this via an explicit path (e.g. "$(dirname "$0")/lib.sh") or pre-set PENWERN_CI_ROOT; do not source by bare name.
PENWERN_CI_ROOT="${PENWERN_CI_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
log()  { echo "[penwern-ci] $*" >&2; }
die()  { echo "[penwern-ci] ERROR: $1" >&2; exit "${2:-1}"; }
