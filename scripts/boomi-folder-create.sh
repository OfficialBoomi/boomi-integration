#!/usr/bin/env bash
# Create a folder on the Boomi platform
# Usage: bash scripts/boomi-folder-create.sh <folder_name> [--parent-folder-id ID] [--test-connection]

source "$(dirname "$0")/boomi-common.sh"
load_env
require_env BOOMI_API_URL BOOMI_USERNAME BOOMI_API_TOKEN BOOMI_ACCOUNT_ID
require_tools curl jq

# --- Parse args ---
FOLDER_NAME=""
PARENT_ID=""
TEST_CONN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --parent-folder-id) PARENT_ID="$2"; shift 2 ;;
    --test-connection)  TEST_CONN=true; shift ;;
    -*)                 echo "Unknown option: $1" >&2; exit 1 ;;
    *)                  FOLDER_NAME="$1"; shift ;;
  esac
done

if $TEST_CONN; then
  test_connection
  exit 0
fi

if [[ -z "$FOLDER_NAME" ]]; then
  echo "Usage: bash scripts/boomi-folder-create.sh <folder_name> [--parent-folder-id ID]" >&2
  exit 1
fi

# Default parent from env
[[ -z "$PARENT_ID" ]] && PARENT_ID="${BOOMI_TARGET_FOLDER:-}"
[[ -n "$PARENT_ID" ]] && echo "Using parent folder: ${PARENT_ID}"

# --- Create folder ---
url="$(build_api_url "Folder")"

body=$(jq -n \
  --arg name "$FOLDER_NAME" \
  --arg parent "$PARENT_ID" \
  '{name: $name, parentId: $parent}')

boomi_api -X POST "$url" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -d "$body"

if [[ "$RESPONSE_CODE" != "200" && "$RESPONSE_CODE" != "201" ]]; then
  log_activity "folder-create" "fail" "$RESPONSE_CODE" \
    "$(jq -cn --arg name "$FOLDER_NAME" --arg parent "$PARENT_ID" \
       --arg err "${RESPONSE_BODY:0:500}" \
       '{folder_name: $name, parent_id: $parent, error: $err}')"
  echo "ERROR: Folder creation failed (HTTP ${RESPONSE_CODE}): ${RESPONSE_BODY}" >&2
  exit 0
fi

folder_id=$(echo "$RESPONSE_BODY" | jq -r '.id // empty')
if [[ -z "$folder_id" ]]; then
  echo "ERROR: No folder ID in response" >&2
  exit 0
fi

log_activity "folder-create" "success" "$RESPONSE_CODE" \
  "$(jq -cn --arg name "$FOLDER_NAME" --arg id "$folder_id" \
     --arg parent "$PARENT_ID" \
     '{folder_name: $name, folder_id: $id, parent_id: $parent}')"
echo "SUCCESS: Created folder '${FOLDER_NAME}' with ID: ${folder_id}"
