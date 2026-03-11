#!/usr/bin/env bash
# Pull a component from the Boomi platform to local workspace
# Usage: bash scripts/boomi-component-pull.sh --component-id <ID> [--target-path PATH]

source "$(dirname "$0")/boomi-common.sh"
load_env
require_env BOOMI_API_URL BOOMI_USERNAME BOOMI_API_TOKEN BOOMI_ACCOUNT_ID
require_tools curl jq

# --- Parse args ---
COMPONENT_ID=""
TARGET_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --component-id) COMPONENT_ID="$2"; shift 2 ;;
    --target-path)  TARGET_PATH="$2"; shift 2 ;;
    -*)             echo "Unknown option: $1" >&2; exit 1 ;;
    *)              echo "Unexpected argument: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$COMPONENT_ID" ]]; then
  echo "Usage: bash scripts/boomi-component-pull.sh --component-id <ID> [--target-path PATH]" >&2
  exit 1
fi

# --- Fetch component ---
url="$(build_api_url "Component/${COMPONENT_ID}")"
echo "Fetching component ${COMPONENT_ID}"

boomi_api -X GET "$url" -H "Accept: application/xml"

if [[ "$RESPONSE_CODE" != "200" ]]; then
  log_activity "component-pull" "fail" "$RESPONSE_CODE" \
    "$(jq -cn --arg id "$COMPONENT_ID" --arg err "${RESPONSE_BODY:0:500}" \
       '{component_id: $id, error: $err}')"
  echo "ERROR: Failed to get component (HTTP ${RESPONSE_CODE}): ${RESPONSE_BODY}" >&2
  exit 0
fi

xml_content="$RESPONSE_BODY"

# --- Extract name and type ---
component_name=$(echo "$xml_content" | xml_attr "name")
component_type=$(echo "$xml_content" | xml_attr "type")
[[ -z "$component_name" ]] && component_name="unknown"
[[ -z "$component_type" ]] && component_type="unknown"

echo "Retrieved: '${component_name}' (type: ${component_type})"

# --- Determine target path ---
if [[ -n "$TARGET_PATH" ]]; then
  file_path="$TARGET_PATH"
else
  # Map component type to directory
  local_dir="active-development"
  type_lower=$(echo "$component_type" | tr '[:upper:]' '[:lower:]')
  case "$type_lower" in
    process)            local_dir+="/processes" ;;
    transform.map)      local_dir+="/maps" ;;
    profile.*)          local_dir+="/profiles" ;;
    connector-settings) local_dir+="/connections" ;;
    connector-action)   local_dir+="/operations" ;;
    documentcache)      local_dir+="/document-caches" ;;
    script)             local_dir+="/scripts" ;;
    *)                  local_dir+="/${type_lower}" ;;
  esac

  mkdir -p "$local_dir"

  # Sanitize filename
  safe_name=$(echo "$component_name" | tr '<>:"/\\|?*' '_' | sed 's/^[. ]*//;s/[. ]*$//')
  [[ -z "$safe_name" ]] && safe_name="unnamed_component"
  file_path="${local_dir}/${safe_name}.xml"
fi

# --- Write file ---
mkdir -p "$(dirname "$file_path")"
echo "$xml_content" > "$file_path"
echo "Saved '${component_name}' to ${file_path}"

# --- Update sync state ---
content_hash=$(hash_file "$file_path")
write_sync_state "$COMPONENT_ID" "$file_path" "$content_hash"

log_activity "component-pull" "success" "$RESPONSE_CODE" \
  "$(jq -cn --arg name "$component_name" --arg id "$COMPONENT_ID" \
     --arg file "$file_path" --arg type "$component_type" \
     '{component_name: $name, component_id: $id, file_path: $file, component_type: $type}')"
echo "SUCCESS: Component saved to ${file_path}"
