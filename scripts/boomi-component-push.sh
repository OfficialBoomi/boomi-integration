#!/usr/bin/env bash
# Push a local component XML file to the Boomi platform (update)
# Usage: bash scripts/boomi-component-push.sh <file_path> [--test-connection]

source "$(dirname "$0")/boomi-common.sh"
load_env
require_env BOOMI_API_URL BOOMI_USERNAME BOOMI_API_TOKEN BOOMI_ACCOUNT_ID
require_tools curl jq

# --- Parse args ---
FILE_PATH=""
TEST_CONN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --test-connection) TEST_CONN=true; shift ;;
    -*)                echo "Unknown option: $1" >&2; exit 1 ;;
    *)                 FILE_PATH="$1"; shift ;;
  esac
done

if $TEST_CONN; then
  test_connection
  exit 0
fi

if [[ -z "$FILE_PATH" ]]; then
  echo "Usage: bash scripts/boomi-component-push.sh <file_path>" >&2
  exit 1
fi

if [[ ! -f "$FILE_PATH" ]]; then
  echo "ERROR: File not found: ${FILE_PATH}" >&2
  exit 1
fi

COMPONENT_NAME="$(basename "$FILE_PATH" .xml)"

# --- Resolve component ID ---
component_id=$(read_component_id "$FILE_PATH" 2>/dev/null || true)

if [[ -z "$component_id" ]]; then
  component_id=$(xml_attr "componentId" < "$FILE_PATH")
  if [[ -n "$component_id" ]]; then
    echo "No sync state — using componentId from XML: ${component_id}"
  else
    echo "ERROR: No component ID found. Create the component first or pull from platform." >&2
    exit 1
  fi
fi

# --- Check for changes ---
current_hash=$(hash_file "$FILE_PATH")
sync_dir="$(pwd)/active-development/.sync-state"
state_name="$(_sync_state_name "$FILE_PATH")"

for sf in "${sync_dir}/${state_name}.json" "${sync_dir}/${COMPONENT_NAME}.json"; do
  if [[ -f "$sf" ]]; then
    last_hash=$(jq -r '.content_hash // empty' "$sf" 2>/dev/null)
    if [[ -n "$last_hash" && "$current_hash" == "$last_hash" ]]; then
      echo "Component '${COMPONENT_NAME}' is up to date (no changes detected)"
      exit 0
    fi
    break
  fi
done

# --- Push to platform ---
url="$(build_api_url "Component/${component_id}")"
echo "Pushing component '${COMPONENT_NAME}' (${component_id}) to Boomi platform"

boomi_api -X POST "$url" \
  -H "Accept: application/xml" \
  -H "Content-Type: application/xml" \
  -d "$(cat "$FILE_PATH")"

if [[ "$RESPONSE_CODE" != "200" && "$RESPONSE_CODE" != "201" && "$RESPONSE_CODE" != "204" ]]; then
  log_activity "component-push" "fail" "$RESPONSE_CODE" \
    "$(jq -cn --arg name "$COMPONENT_NAME" --arg id "$component_id" \
       --arg file "$FILE_PATH" --arg err "${RESPONSE_BODY:0:500}" \
       '{component_name: $name, component_id: $id, file_path: $file, error: $err}')"
  echo "ERROR: Push failed (HTTP ${RESPONSE_CODE}): ${RESPONSE_BODY}" >&2
  exit 0
fi

# --- Update sync state ---
write_sync_state "$component_id" "$FILE_PATH" "$current_hash"

log_activity "component-push" "success" "$RESPONSE_CODE" \
  "$(jq -cn --arg name "$COMPONENT_NAME" --arg id "$component_id" \
     --arg file "$FILE_PATH" \
     '{component_name: $name, component_id: $id, file_path: $file}')"
echo "SUCCESS: Pushed component '${COMPONENT_NAME}'"
