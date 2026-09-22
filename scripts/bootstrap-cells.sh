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
#   CREATE_WORKSPACE create the workspace?          (default: true; false when the
#                    suite uses a default workspace like personal-files)
#   HEALTH_RETRIES  health poll attempts (×5s)      (default: 60)
#   API_RETRIES     IDM readiness/PUT attempts (×3s) (default: 40)
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/lib.sh"

compose_file="${COMPOSE_FILE:?COMPOSE_FILE is required}"
service="${CELLS_SERVICE:-cells}"
admin_user="${ADMIN_USER:-admin}"
token_expiry="${TOKEN_EXPIRY:-2h}"
base_url="${CURATE_BASE_URL:-https://localhost:8080}"
workspace="${WORKSPACE_SLUG:-quarantine}"
create_workspace="${CREATE_WORKSPACE:-true}"
health_retries="${HEALTH_RETRIES:-60}"
api_retries="${API_RETRIES:-40}"

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
#    Retried: the container is "healthy" as soon as it serves HTTPS, which is
#    earlier than the IDM services the token subcommand talks to are ready.
token=""
for _ in $(seq 1 "$api_retries"); do
  token="$(dc exec -T "$service" cells admin user token -u "$admin_user" -e "$token_expiry" -q 2>/dev/null | tr -d '[:space:]')" || true
  [ -n "$token" ] && break
  sleep 3
done
[ -n "$token" ] || die "failed to mint PAT after $api_retries attempts (empty token)" 2
log "minted ${#token}-char PAT for '$admin_user' (expires in $token_expiry)."

# 3. Wait for the IDM workspace service to actually serve.
#    The compose healthcheck only proves the HTTPS listener is up. Cells accepts
#    connections well before idm/workspace is ready, and in that window writes
#    return 500. That is how this job intermittently failed at workspace
#    creation. SearchWorkspaces (POST /a/workspace, empty body) is the read-only
#    probe on exactly the service that was failing, so a 200 here is the
#    readiness signal that matters. Needed in BOTH modes: when
#    CREATE_WORKSPACE=false there is no later write to absorb the race, and the
#    suite would hit the cold service itself.
log "waiting for the IDM workspace service to serve (max $((api_retries * 3))s)…"
for _ in $(seq 1 "$api_retries"); do
  probe="$(curl -sk -o /dev/null -w '%{http_code}' -X POST "$base_url/a/workspace" \
    -H "Authorization: Bearer $token" -H "Content-Type: application/json" -d '{}' || true)"
  if [ "$probe" = "200" ]; then idm_ready=1; break; fi
  sleep 3
done
[ -n "${idm_ready:-}" ] || die "IDM workspace service never returned 200 (last HTTP ${probe:-none}) after $api_retries attempts" 2
log "IDM workspace service is serving."

# 4. Create the workspace over the default pydiods1 datasource. Idempotent (upsert).
#    Body is the bare idm.Workspace proto (NOT wrapped) with exact protojson casing.
#    Skipped when CREATE_WORKSPACE=false (suite uses a default workspace such as
#    personal-files, which must not be clobbered).
if [ "$create_workspace" = "true" ]; then
  read -r -d '' ws_body <<JSON || true
{"UUID":"$workspace","Slug":"$workspace","Label":"$workspace","Scope":"ADMIN",
 "Attributes":"{\"DEFAULT_RIGHTS\":\"rw\"}",
 "RootNodes":{"DATASOURCE:pydiods1":{"Uuid":"DATASOURCE:pydiods1","Path":"pydiods1/","Type":"COLLECTION","MetaStore":{"name":"\"\""}}}}
JSON
  # Retried on 5xx as well: the readiness probe above is a read, and the
  # datasource this workspace roots on can still be settling behind it.
  for _ in $(seq 1 "$api_retries"); do
    code="$(curl -sk -o /dev/null -w '%{http_code}' -X PUT "$base_url/a/workspace/$workspace" \
      -H "Authorization: Bearer $token" -H "Content-Type: application/json" -d "$ws_body" || true)"
    [ "$code" = "200" ] && break
    case "$code" in 5*|000) sleep 3 ;; *) break ;; esac
  done
  [ "$code" = "200" ] || die "workspace create '$workspace' returned HTTP $code (expected 200)" 2
  log "workspace '$workspace' ready (HTTP $code)."
else
  log "CREATE_WORKSPACE=false — skipping workspace creation."
fi

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
