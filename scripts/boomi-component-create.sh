#!/usr/bin/env bash
# Create a new component on the Boomi platform from a local XML file
# Usage: bash scripts/boomi-component-create.sh <file_path> [--branch NAME_OR_ID] [--test-connection]

source "$(dirname "$0")/boomi-common.sh"
load_env
require_env BOOMI_API_URL BOOMI_USERNAME BOOMI_API_TOKEN BOOMI_ACCOUNT_ID
require_tools curl jq

# --- Parse args ---
FILE_PATH=""
TEST_CONN=false
BRANCH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --test-connection) TEST_CONN=true; shift ;;
    --branch)          BRANCH="$2"; shift 2 ;;
    -*)                echo "Unknown option: $1" >&2; exit 1 ;;
    *)                 FILE_PATH="$1"; shift ;;
  esac
done

if $TEST_CONN; then
  test_connection
  exit 0
fi

if [[ -z "$FILE_PATH" ]]; then
  echo "Usage: bash scripts/boomi-component-create.sh <file_path> [--branch NAME_OR_ID]" >&2
  exit 1
fi

if [[ ! -f "$FILE_PATH" ]]; then
  echo "ERROR: File not found: ${FILE_PATH}" >&2
  exit 1
fi

COMPONENT_NAME="$(basename "$FILE_PATH" .xml)"

# --- Check if already created ---
existing_id=$(read_component_id "$FILE_PATH" 2>/dev/null || true)
if [[ -n "$existing_id" ]]; then
  echo "Component '${COMPONENT_NAME}' already exists with ID: ${existing_id}"
  exit 0
fi

# --- Stamp origin into local file (persists across future pushes) ---
stamp_origin_file "$FILE_PATH"

# --- Resolve branch ---
BRANCH_ID=$(resolve_effective_branch "$BRANCH" "$(detect_xml_branch "$FILE_PATH")")

# --- Prepare XML: blank componentId for CREATE, inject branch if needed ---
prepared_xml=$(sed 's/componentId="[^"]*"/componentId=""/' "$FILE_PATH")
if [[ -n "$BRANCH_ID" ]]; then
  prepared_xml=$(inject_branch_id "$prepared_xml" "$BRANCH_ID")
  echo "Creating component '${COMPONENT_NAME}' on branch ${BRANCH:-$BRANCH_ID}"
else
  echo "Creating component '${COMPONENT_NAME}' on main"
fi

# --- Create on platform ---
url="$(build_api_url "Component")"

boomi_api -X POST "$url" \
  -H "Accept: application/xml" \
  -H "Content-Type: application/xml" \
  -d "$prepared_xml"

if [[ "$RESPONSE_CODE" != "200" && "$RESPONSE_CODE" != "201" ]]; then
  log_activity "component-create" "fail" "$RESPONSE_CODE" \
    "$(jq -cn --arg name "$COMPONENT_NAME" --arg file "$FILE_PATH" \
       --arg err "${RESPONSE_BODY:0:500}" \
       '{component_name: $name, file_path: $file, error: $err}')"
  echo "ERROR: Create failed (HTTP ${RESPONSE_CODE}): ${RESPONSE_BODY}" >&2
  exit 0
fi

# --- Extract component ID from response ---
component_id=$(echo "$RESPONSE_BODY" | xml_attr "componentId")
if [[ -z "$component_id" ]]; then
  echo "ERROR: No componentId in create response" >&2
  exit 0
fi

# --- Update local file with generated ID (only replace the empty-string placeholder) ---
sedi "s/componentId=\"\"/componentId=\"${component_id}\"/" "$FILE_PATH"

# Add version="1" if not present
if ! grep -q 'version="' "$FILE_PATH"; then
  sedi "s/componentId=\"${component_id}\"/componentId=\"${component_id}\" version=\"1\"/" "$FILE_PATH"
fi

# Write branchId back into local XML so push/deploy can detect it
if [[ -n "$BRANCH_ID" ]] && ! grep -q 'branchId="' "$FILE_PATH"; then
  local_xml=$(cat "$FILE_PATH")
  inject_branch_id "$local_xml" "$BRANCH_ID" > "$FILE_PATH"
fi

echo "Updated local file with componentId: ${component_id}"

# --- Write sync state ---
content_hash=$(hash_file "$FILE_PATH")
write_sync_state "$component_id" "$FILE_PATH" "$content_hash" "$BRANCH_ID"

log_activity "component-create" "success" "$RESPONSE_CODE" \
  "$(jq -cn --arg name "$COMPONENT_NAME" --arg id "$component_id" \
     --arg file "$FILE_PATH" --arg branch "${BRANCH_ID:-main}" \
     '{component_name: $name, component_id: $id, file_path: $file, branch: $branch}')"
echo "SUCCESS: Component '${COMPONENT_NAME}' created with ID: ${component_id}"
