#!/usr/bin/env bash
# Bring up + bootstrap the ephemeral Cells for the e2e job, then emit a
# short-lived PAT and base URL.
#
# Assumes the compose stack is already `up -d` (the workflow does that so the
# image-pull/boot is a visible, cacheable step). This script:
#   1. waits for the `cells` healthcheck to go green,
#   2. mints a short-lived admin PAT in-container,
#   3. creates the target workspace (default `quarantine`) over the default
#      `pydiods1` datasource — no new datasource needed.
#
# Outputs (KEY=VALUE on stdout; also appended to $GITHUB_OUTPUT when set, with
# the token masked):
#   token=<PAT>
#   base_url=<CURATE_BASE_URL>
#
# Env / overrides:
#   COMPOSE_FILE    path to the ephemeral-cells docker-compose.yaml (required)
#   CELLS_SERVICE   compose service name           (default: cells)
#   ADMIN_USER      Cells admin user               (default: admin)
#   TOKEN_EXPIRY    PAT lifetime                    (default: 2h)
#   CURATE_BASE_URL loopback URL                    (default: https://localhost:8080)
#   WORKSPACE_SLUG  workspace to create             (default: quarantine)
#   HEALTH_RETRIES  health poll attempts (×5s)      (default: 60)
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/lib.sh"

compose_file="${COMPOSE_FILE:?COMPOSE_FILE is required}"
service="${CELLS_SERVICE:-cells}"
admin_user="${ADMIN_USER:-admin}"
token_expiry="${TOKEN_EXPIRY:-2h}"
base_url="${CURATE_BASE_URL:-https://localhost:8080}"
workspace="${WORKSPACE_SLUG:-quarantine}"
health_retries="${HEALTH_RETRIES:-60}"

dc() { docker compose -f "$compose_file" "$@"; }

# 1. Wait for health.
log "waiting for '$service' healthcheck (max $((health_retries * 5))s)…"
for _ in $(seq 1 "$health_retries"); do
  if dc ps "$service" --format '{{.Health}}' 2>/dev/null | grep -q healthy; then
    healthy=1; break
  fi
  sleep 5
done
if [ -z "${healthy:-}" ]; then
  log "'$service' never became healthy — dumping logs:"
  dc logs "$service" >&2 || true
  die "ephemeral Cells failed to start" 2
fi
log "'$service' is healthy."

# 2. Mint a short-lived admin PAT in-container (-q = token value only).
token="$(dc exec -T "$service" cells admin user token -u "$admin_user" -e "$token_expiry" -q | tr -d '[:space:]')"
[ -n "$token" ] || die "failed to mint PAT (empty token)" 2
log "minted ${#token}-char PAT for '$admin_user' (expires in $token_expiry)."

# 3. Create the workspace over the default pydiods1 datasource. Idempotent (upsert).
#    Body is the bare idm.Workspace proto (NOT wrapped) with exact protojson casing.
read -r -d '' ws_body <<JSON || true
{"UUID":"$workspace","Slug":"$workspace","Label":"$workspace","Scope":"ADMIN",
 "Attributes":"{\"DEFAULT_RIGHTS\":\"rw\"}",
 "RootNodes":{"DATASOURCE:pydiods1":{"Uuid":"DATASOURCE:pydiods1","Path":"pydiods1/","Type":"COLLECTION","MetaStore":{"name":"\"\""}}}}
JSON
code="$(curl -sk -o /dev/null -w '%{http_code}' -X PUT "$base_url/a/workspace/$workspace" \
  -H "Authorization: Bearer $token" -H "Content-Type: application/json" -d "$ws_body")"
[ "$code" = "200" ] || die "workspace create '$workspace' returned HTTP $code (expected 200)" 2
log "workspace '$workspace' ready (HTTP $code)."

# Emit outputs.
echo "token=$token"
echo "base_url=$base_url"
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "::add-mask::$token"
  {
    echo "token=$token"
    echo "base_url=$base_url"
  } >> "$GITHUB_OUTPUT"
fi
