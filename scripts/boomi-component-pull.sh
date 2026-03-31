#!/usr/bin/env bash
# Pull a component from the Boomi platform to local workspace
# Usage: bash scripts/boomi-component-pull.sh --component-id <ID> [--branch NAME_OR_ID] [--target-path PATH]

source "$(dirname "$0")/boomi-common.sh"
load_env
require_env BOOMI_API_URL BOOMI_USERNAME BOOMI_API_TOKEN BOOMI_ACCOUNT_ID
require_tools curl jq

# --- Parse args ---
COMPONENT_ID=""
TARGET_PATH=""
BRANCH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --component-id) COMPONENT_ID="$2"; shift 2 ;;
    --target-path)  TARGET_PATH="$2"; shift 2 ;;
    --branch)       BRANCH="$2"; shift 2 ;;
    -*)             echo "Unknown option: $1" >&2; exit 1 ;;
    *)              echo "Unexpected argument: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$COMPONENT_ID" ]]; then
  echo "Usage: bash scripts/boomi-component-pull.sh --component-id <ID> [--branch NAME_OR_ID] [--target-path PATH]" >&2
  exit 1
fi

# --- Resolve branch ---
BRANCH_ID=""
if [[ -n "$BRANCH" ]]; then
  BRANCH_ID=$(resolve_branch_id "$BRANCH") || exit 1
elif [[ -n "${BOOMI_DEFAULT_BRANCH_ID:-}" ]]; then
  BRANCH_ID="$BOOMI_DEFAULT_BRANCH_ID"
fi

# --- Fetch component (tilde syntax for branch) ---
if [[ -n "$BRANCH_ID" ]]; then
  url="$(build_api_url "Component/${COMPONENT_ID}~${BRANCH_ID}")"
  echo "Fetching component ${COMPONENT_ID} from branch ${BRANCH:-$BRANCH_ID}"
else
  url="$(build_api_url "Component/${COMPONENT_ID}")"
  echo "Fetching component ${COMPONENT_ID} from main"
fi

tmpfile=$(mktemp)
trap 'rm -f "$tmpfile"' EXIT
RESPONSE_CODE=$(boomi_curl -o "$tmpfile" -w "%{http_code}" -X GET "$url" -H "Accept: application/xml")

if [[ "$RESPONSE_CODE" != "200" ]]; then
  log_activity "component-pull" "fail" "$RESPONSE_CODE" \
    "$(jq -cn --arg id "$COMPONENT_ID" --arg err "$(head -c 500 "$tmpfile")" \
       '{component_id: $id, error: $err}')"
  echo "ERROR: Failed to get component (HTTP ${RESPONSE_CODE}): $(head -c 500 "$tmpfile")" >&2
  exit 0
fi

# --- Extract name and type from file (-m 1 avoids SIGPIPE on large payloads) ---
component_name=$(grep -o 'name="[^"]*"' "$tmpfile" | head -1 | sed 's/name="//;s/"//')
component_type=$(grep -o 'type="[^"]*"' "$tmpfile" | head -1 | sed 's/type="//;s/"//')
[[ -z "$component_name" ]] && component_name="unknown"
[[ -z "$component_type" ]] && component_type="unknown"

echo "Retrieved: '${component_name}' (type: ${component_type})"

# --- Determine target path ---
if [[ -n "$TARGET_PATH" ]]; then
  if [[ -d "$TARGET_PATH" ]]; then
    # Target is a directory — auto-generate filename inside it
    safe_name=$(echo "$component_name" | tr '<>:"/\\|?*' '_' | sed 's/^[. ]*//;s/[. ]*$//')
    [[ -z "$safe_name" ]] && safe_name="unnamed_component"
    file_path="${TARGET_PATH%/}/${safe_name}.xml"
  else
    file_path="$TARGET_PATH"
  fi
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

# --- Write file (temp file → final path) ---
mkdir -p "$(dirname "$file_path")"
mv "$tmpfile" "$file_path"

# Align branchId in local file with the requested branch.
# Inherited components (not yet modified on branch) return main's branchId from the API.
# Without this, a push without --branch would silently target main instead of the branch.
if [[ -n "$BRANCH_ID" ]]; then
  local_xml=$(cat "$file_path")
  inject_branch_id "$local_xml" "$BRANCH_ID" > "$file_path"
fi

echo "Saved '${component_name}' to ${file_path}"

# --- Update sync state ---
content_hash=$(hash_file "$file_path")
write_sync_state "$COMPONENT_ID" "$file_path" "$content_hash" "$BRANCH_ID"

log_activity "component-pull" "success" "$RESPONSE_CODE" \
  "$(jq -cn --arg name "$component_name" --arg id "$COMPONENT_ID" \
     --arg file "$file_path" --arg type "$component_type" --arg branch "${BRANCH_ID:-main}" \
     '{component_name: $name, component_id: $id, file_path: $file, component_type: $type, branch: $branch}')"
echo "SUCCESS: Component saved to ${file_path}"
