#!/usr/bin/env bash
# Compare two versions of a component via ComponentDiffRequest
# Usage: bash scripts/boomi-component-diff.sh --component-id <ID> --source <N> --target <N>

source "$(dirname "$0")/boomi-common.sh"
load_env
require_env BOOMI_API_URL BOOMI_USERNAME BOOMI_API_TOKEN BOOMI_ACCOUNT_ID
require_tools curl jq

# --- Parse args ---
COMPONENT_ID=""
SOURCE_VERSION=""
TARGET_VERSION=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --component-id) COMPONENT_ID="$2"; shift 2 ;;
    --source)       SOURCE_VERSION="$2"; shift 2 ;;
    --target)       TARGET_VERSION="$2"; shift 2 ;;
    -*)             echo "Unknown option: $1" >&2; exit 1 ;;
    *)              echo "Unexpected argument: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$COMPONENT_ID" || -z "$SOURCE_VERSION" || -z "$TARGET_VERSION" ]]; then
  echo "Usage: bash scripts/boomi-component-diff.sh --component-id <ID> --source <N> --target <N>" >&2
  exit 1
fi

# Strip any tilde suffix if present
COMPONENT_ID="${COMPONENT_ID%%~*}"

# --- Build request ---
request_json=$(jq -cn \
  --arg cid "$COMPONENT_ID" \
  --argjson src "$SOURCE_VERSION" \
  --argjson tgt "$TARGET_VERSION" \
  '{componentId: $cid, sourceVersion: $src, targetVersion: $tgt}')

# --- Execute ---
url="$(build_api_url "ComponentDiffRequest" false)"

echo "Comparing component ${COMPONENT_ID} version ${SOURCE_VERSION} → ${TARGET_VERSION}..."
boomi_api -X POST "$url" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -d "$request_json"

if [[ "$RESPONSE_CODE" != "200" ]]; then
  log_activity "component-diff" "fail" "$RESPONSE_CODE" \
    "$(jq -cn --arg id "$COMPONENT_ID" --arg src "$SOURCE_VERSION" --arg tgt "$TARGET_VERSION" --arg err "${RESPONSE_BODY:0:500}" \
       '{component_id: $id, source: $src, target: $tgt, error: $err}')"
  echo "ERROR: Diff request failed (HTTP ${RESPONSE_CODE}): ${RESPONSE_BODY}" >&2
  exit 1
fi

# --- Output raw JSON response ---
echo "$RESPONSE_BODY" | jq .

log_activity "component-diff" "success" "$RESPONSE_CODE" \
  "$(jq -cn --arg id "$COMPONENT_ID" --arg src "$SOURCE_VERSION" --arg tgt "$TARGET_VERSION" \
     '{component_id: $id, source: $src, target: $tgt}')"
