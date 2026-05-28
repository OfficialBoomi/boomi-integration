#!/usr/bin/env bash
# Read and write environment extension *values* via the Boomi
# /EnvironmentExtensions API. Safe by construction:
#   - every POST hard-injects "partial": true so omitted keys are preserved
#   - rejects payloads containing "value": "" (use "useDefault": true to remove an override)
#   - backs up the current state to active-development/extension-snapshots/ before every POST
#
# Scope: VALUES only. Extension *declarations* (<bns:processOverrides> in each
# process component) are managed via boomi-component-push.sh.

set -euo pipefail
source "$(dirname "$0")/boomi-common.sh"
load_env
require_env BOOMI_API_URL BOOMI_USERNAME BOOMI_API_TOKEN BOOMI_ACCOUNT_ID BOOMI_ENVIRONMENT_ID
require_tools curl jq

usage() {
  cat <<'EOF'
Read and write environment extension VALUES via /EnvironmentExtensions.

Scope: values only. Extension declarations (<bns:processOverrides> in each
process component) are managed via boomi-component-push.sh.

Commands:
  get
      Fetch current extension state for $BOOMI_ENVIRONMENT_ID. Prints JSON to stdout.

  set --file <path>
  set -                       (read payload from stdin)
      Apply a partial update. Body should contain ONLY the keys you want to
      change — included keys are updated, omitted keys are preserved.

      Before the POST, the current state is snapshotted to:
        active-development/extension-snapshots/extensions_<envId>_<UTC>.json

      The script auto-injects "partial": true. Any "value": "" is rejected
      (the platform stores empty strings literally). "useDefault": true on a
      DPP entry is also rejected (the platform's error for this is opaque).
      To remove a connection/operation-field override, send {"useDefault": true}
      on the field (no "value" key). To remove a DPP override, send the
      property entry with no "value" key (e.g. {"name":"DPP_X"}).

  -h, --help, help
      Print this message.

Examples:
  # Inspect current values
  bash scripts/boomi-extensions.sh get

  # Update one DPP
  echo '{"properties":{"property":[{"name":"DPP_X","value":"new"}]}}' \
    | bash scripts/boomi-extensions.sh set -

  # Revert a connection field override (useDefault is a field attribute)
  echo '{"connections":{"connection":[{"id":"<conn-id>","field":[{"id":"url","useDefault":true}]}]}}' \
    | bash scripts/boomi-extensions.sh set -

  # Revert a DPP override (send the entry with no "value" key)
  echo '{"properties":{"property":[{"name":"DPP_X"}]}}' \
    | bash scripts/boomi-extensions.sh set -

  # Update a connection field from a file
  bash scripts/boomi-extensions.sh set --file changes.json

Notes:
  - Values apply on the next execution of any process already deployed with
    these extension declarations. Redeploy is only required when declarations
    themselves change.
  - GET omits values for encrypted fields (encryptedValueSet=true is preserved).
    POSTing a field block without "value" is interpreted as no-change — so a
    round-trip of GET → edit → POST is safe for encrypted fields.
  - Snapshots accumulate in active-development/extension-snapshots/. Prune
    manually when desired.
EOF
}

env_url() {
  build_api_url "EnvironmentExtensions/${BOOMI_ENVIRONMENT_ID}"
}

cmd_get() {
  local url; url="$(env_url)"
  boomi_api -X GET "$url" -H "Accept: application/json"
  if [[ "$RESPONSE_CODE" != "200" ]]; then
    echo "ERROR: GET failed (HTTP ${RESPONSE_CODE})" >&2
    echo "$RESPONSE_BODY" >&2
    log_activity "extensions-get" "fail" "$RESPONSE_CODE" \
      "$(jq -cn --arg env "$BOOMI_ENVIRONMENT_ID" '{environmentId:$env}')"
    exit 1
  fi
  echo "$RESPONSE_BODY" | jq '.'
  log_activity "extensions-get" "success" "$RESPONSE_CODE" \
    "$(jq -cn --arg env "$BOOMI_ENVIRONMENT_ID" '{environmentId:$env}')"
}

write_snapshot() {
  local dir="active-development/extension-snapshots"
  mkdir -p "$dir"
  local snap="${dir}/extensions_${BOOMI_ENVIRONMENT_ID}_$(date -u +%Y%m%d_%H%M%S).json"

  local url; url="$(env_url)"
  boomi_api -X GET "$url" -H "Accept: application/json"
  if [[ "$RESPONSE_CODE" != "200" ]]; then
    echo "ERROR: snapshot GET failed (HTTP ${RESPONSE_CODE}) — aborting before POST." >&2
    echo "$RESPONSE_BODY" >&2
    exit 1
  fi
  echo "$RESPONSE_BODY" | jq '.' > "$snap"
  echo "Snapshot: $snap" >&2
}

cmd_set() {
  local source="${1:-}"
  local body=""
  case "$source" in
    --file)
      [[ -f "${2:-}" ]] || { echo "ERROR: file not found: ${2:-}" >&2; exit 1; }
      body=$(cat "$2")
      ;;
    -)
      body=$(cat)
      ;;
    "")
      echo "ERROR: 'set' requires --file <path> or '-' for stdin. See --help." >&2
      exit 1
      ;;
    *)
      echo "ERROR: unknown 'set' arg: $source. See --help." >&2
      exit 1
      ;;
  esac

  [[ -n "${body//[[:space:]]/}" ]] \
    || { echo "ERROR: empty payload." >&2; exit 1; }

  echo "$body" | jq empty 2>/dev/null \
    || { echo "ERROR: payload is not valid JSON." >&2; exit 1; }

  if echo "$body" | jq -e '.. | objects | select(has("value")) | select(.value == "")' >/dev/null 2>&1; then
    echo "ERROR: payload contains \"value\": \"\" — refusing to send." >&2
    echo "Empty strings are stored literally by the platform and will break the next execution." >&2
    echo "To remove an override:" >&2
    echo "  - On a connection or operation field, set \"useDefault\": true on the field (omit \"value\")." >&2
    echo "  - On a DPP, send the property entry with no \"value\" key (e.g. {\"name\":\"DPP_X\"})." >&2
    exit 1
  fi

  if echo "$body" | jq -e '.properties.property[]? | select(has("useDefault"))' >/dev/null 2>&1; then
    echo "ERROR: payload sets \"useDefault\" on a DPP entry — the platform rejects this." >&2
    echo "To remove a DPP override, send the property entry with no \"value\" key (e.g. {\"name\":\"DPP_X\"})." >&2
    echo "\"useDefault\" is a connection/operation-field attribute only." >&2
    exit 1
  fi

  body=$(echo "$body" | jq --arg id "$BOOMI_ENVIRONMENT_ID" \
    '. + {"@type":"EnvironmentExtensions","id":$id,"partial":true}')

  write_snapshot

  local url; url="$(env_url)"
  boomi_api -X POST "$url" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -d "$body"

  if [[ "$RESPONSE_CODE" != "200" && "$RESPONSE_CODE" != "201" ]]; then
    echo "ERROR: POST failed (HTTP ${RESPONSE_CODE})" >&2
    echo "$RESPONSE_BODY" >&2
    log_activity "extensions-set" "fail" "$RESPONSE_CODE" \
      "$(jq -cn --arg env "$BOOMI_ENVIRONMENT_ID" '{environmentId:$env}')"
    exit 1
  fi

  echo "$RESPONSE_BODY" | jq '.'
  echo "Updated. Values apply on the next execution of any process already deployed with these extension declarations." >&2

  log_activity "extensions-set" "success" "$RESPONSE_CODE" \
    "$(jq -cn --arg env "$BOOMI_ENVIRONMENT_ID" '{environmentId:$env}')"
}

cmd="${1:-}"
shift || true
case "$cmd" in
  get)               cmd_get ;;
  set)               cmd_set "$@" ;;
  -h|--help|help|"") usage ;;
  *)                 echo "Unknown command: $cmd" >&2; usage >&2; exit 1 ;;
esac
