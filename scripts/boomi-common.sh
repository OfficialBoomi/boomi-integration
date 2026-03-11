#!/usr/bin/env bash
# Shared utilities for Boomi CLI tools
# Sourced by all tool scripts — not executed directly

set -euo pipefail

# --- Environment ---

load_env() {
  local env_file=".env"
  if [[ -f "$env_file" ]]; then
    set -a
    source "$env_file"
    set +a
  else
    echo "ERROR: .env file not found in $(pwd)" >&2
    exit 1
  fi
}

require_env() {
  local missing=()
  for var in "$@"; do
    if [[ -z "${!var:-}" ]]; then
      missing+=("$var")
    fi
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "ERROR: Missing required environment variables: ${missing[*]}" >&2
    echo "Check your .env file." >&2
    exit 1
  fi
}

require_tools() {
  local missing=()
  for tool in "$@"; do
    if ! command -v "$tool" &>/dev/null; then
      missing+=("$tool")
    fi
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "ERROR: Missing required tools: ${missing[*]}" >&2
    exit 1
  fi
}

# --- API helpers ---

build_api_url() {
  local endpoint="$1"
  local verbose="${2:-true}"
  local base="${BOOMI_API_URL}/api/rest/v1"

  if [[ "${PARTNER_OVERRIDE:-}" == "true" && -n "${PARTNER_SUB_ACCOUNT:-}" ]]; then
    base="${BOOMI_API_URL}/partner/api/rest/v1"
  fi

  local url="${base}/${BOOMI_ACCOUNT_ID}/${endpoint}"

  if [[ "${PARTNER_OVERRIDE:-}" == "true" ]]; then
    if [[ -n "${PARTNER_SUB_ACCOUNT:-}" ]]; then
      url="${url}?overrideAccount=${PARTNER_SUB_ACCOUNT}"
      [[ "$verbose" == "true" ]] && echo "  [Partner API] Operating on sub-account: ${PARTNER_SUB_ACCOUNT}" >&2
    else
      echo "  [Warning] PARTNER_OVERRIDE=true but PARTNER_SUB_ACCOUNT is not set" >&2
    fi
  fi

  echo "$url"
}

# curl with Boomi auth and common options (low-level — prefer boomi_api for most calls)
boomi_curl() {
  local ssl_flag=""
  [[ "${BOOMI_VERIFY_SSL:-true}" == "false" ]] && ssl_flag="-k"

  curl -s $ssl_flag \
    --max-time "${BOOMI_TIMEOUT:-60}" \
    -u "BOOMI_TOKEN.${BOOMI_USERNAME}:${BOOMI_API_TOKEN}" \
    "$@"
}

# High-level API call: captures body and http code cleanly via temp file.
# Sets global RESPONSE_BODY and RESPONSE_CODE after each call.
# Usage: boomi_api [curl args...]
RESPONSE_BODY=""
RESPONSE_CODE=""
boomi_api() {
  local tmpfile
  tmpfile=$(mktemp)
  RESPONSE_CODE=$(boomi_curl -o "$tmpfile" -w "%{http_code}" "$@")
  RESPONSE_BODY=$(cat "$tmpfile")
  rm -f "$tmpfile"
}

# --- XML helpers ---

# Extract an attribute value from an XML string or file
# Usage: xml_attr "componentId" < file.xml
#    or: echo "$xml" | xml_attr "componentId"
xml_attr() {
  local attr="$1"
  grep -o "${attr}=\"[^\"]*\"" | head -1 | sed "s/${attr}=\"//;s/\"//"
}

# Portable in-place sed (macOS vs GNU)
sedi() {
  if sed --version 2>/dev/null | grep -q GNU; then
    sed -i "$@"
  else
    sed -i '' "$@"
  fi
}

# --- Sync state ---

# Resolve sync state filename from a component file path
_sync_state_name() {
  local file_path="$1"
  local active_dev
  active_dev="$(pwd)/active-development"
  local abs_path
  abs_path="$(cd "$(dirname "$file_path")" && pwd)/$(basename "$file_path")"

  if [[ "$abs_path" == "$active_dev"/* ]]; then
    local rel="${abs_path#${active_dev}/}"
    echo "${rel%.xml}" | tr '/' '__'
  else
    basename "$file_path" .xml
  fi
}

# Read component_id from sync state. Prints ID or returns 1.
read_component_id() {
  local file_path="$1"
  local sync_dir="$(pwd)/active-development/.sync-state"
  local state_name
  state_name="$(_sync_state_name "$file_path")"
  local component_name
  component_name="$(basename "$file_path" .xml)"

  # Try path-based state first, then legacy stem-only
  for sf in "${sync_dir}/${state_name}.json" "${sync_dir}/${component_name}.json"; do
    if [[ -f "$sf" ]]; then
      local cid
      cid=$(jq -r '.component_id // empty' "$sf" 2>/dev/null)
      if [[ -n "$cid" ]]; then
        echo "$cid"
        return 0
      fi
    fi
  done
  return 1
}

# Write sync state for a component
write_sync_state() {
  local component_id="$1"
  local file_path="$2"
  local content_hash="${3:-}"
  local sync_dir="$(pwd)/active-development/.sync-state"

  mkdir -p "$sync_dir"

  local state_name
  state_name="$(_sync_state_name "$file_path")"
  local state_file="${sync_dir}/${state_name}.json"

  cat > "$state_file" <<EOF
{
  "component_id": "${component_id}",
  "file_path": "${file_path}",
  "content_hash": "${content_hash}",
  "last_sync": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
  echo "Sync state: ${state_file}"
}

# SHA-256 hash of a file
hash_file() {
  shasum -a 256 "$1" | cut -d' ' -f1
}

# --- Activity logging ---

_activity_log_dir() {
  echo "$(pwd)/.activity-log"
}

_plugin_version() {
  local plugin_json
  plugin_json="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../../../ && pwd)/.claude-plugin/plugin.json"
  jq -r '.version // "unknown"' "$plugin_json" 2>/dev/null || echo "unknown"
}

log_activity() {
  local operation="$1"
  local result="$2"
  local http_code="${3:-}"
  local details="${4:-\{\}}"

  {
    local log_dir
    log_dir="$(_activity_log_dir)"
    mkdir -p "$log_dir" 2>/dev/null || return 0

    local log_file="${log_dir}/activity.jsonl"
    local timestamp
    timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    local script_name
    script_name="$(basename "${BASH_SOURCE[1]:-unknown}" .sh)"

    jq -cn \
      --arg ts "$timestamp" \
      --arg ver "$(_plugin_version)" \
      --arg ws "$(basename "$(pwd)")" \
      --arg op "$operation" \
      --arg script "$script_name" \
      --arg user "${USER:-}" \
      --arg boomi_user "${BOOMI_USERNAME:-}" \
      --arg account "${BOOMI_ACCOUNT_ID:-}" \
      --arg env_id "${BOOMI_ENVIRONMENT_ID:-}" \
      --arg result "$result" \
      --arg http "$http_code" \
      --argjson details "$details" \
      '{
        timestamp: $ts,
        plugin_version: $ver,
        workspace: $ws,
        operation: $op,
        script: $script,
        user: $user,
        boomi_user: $boomi_user,
        account_id: $account,
        environment_id: (if $env_id == "" then null else $env_id end),
        result: $result,
        http_code: (if $http == "" then null else ($http | tonumber? // $http) end),
        details: $details
      }' >> "$log_file"
  } 2>/dev/null || true
}

# --- Origin stamp ---

get_origin_tag() {
  local plugin_json
  plugin_json="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../../../ && pwd)/.claude-plugin/plugin.json"
  if [[ -f "$plugin_json" ]]; then
    local name version
    name=$(jq -r '.name // "bc-integration"' "$plugin_json" 2>/dev/null || echo "bc-integration")
    version=$(jq -r '.version // "?"' "$plugin_json" 2>/dev/null || echo "?")
    echo "built with ${name} plugin v${version}"
  else
    echo "built with boomi-integration agent skill"
  fi
}

# Stamp origin tag into <bns:description> element of a local component XML file.
# Modifies the file in-place so the stamp persists across pushes.
# Handles: <bns:description>text</...>, <bns:description/>, <bns:description></...>
# If no description element exists or already stamped, file is unchanged.
stamp_origin_file() {
  local file_path="$1"
  if [[ -z "$file_path" || ! -f "$file_path" ]]; then
    return
  fi

  # Already stamped — skip
  if grep -q "built with" "$file_path"; then
    return
  fi

  local tag
  tag=$(get_origin_tag)

  # <bns:description>existing text</bns:description> → append
  if grep -q '<bns:description>[^<]' "$file_path"; then
    sedi "s#</bns:description># | ${tag}</bns:description>#" "$file_path"
    return
  fi

  # <bns:description/> → replace with filled element
  if grep -q '<bns:description/>' "$file_path"; then
    sedi "s#<bns:description/>#<bns:description>${tag}</bns:description>#" "$file_path"
    return
  fi

  # <bns:description></bns:description> → fill empty element
  if grep -q '<bns:description></bns:description>' "$file_path"; then
    sedi "s#<bns:description></bns:description>#<bns:description>${tag}</bns:description>#" "$file_path"
    return
  fi
}

# --- Connection test ---

test_connection() {
  local url
  url="$(build_api_url "Atom/query" false)"
  echo "Testing connection to Boomi platform..."

  local http_code
  http_code=$(boomi_curl -o /dev/null -w "%{http_code}" \
    -X POST "$url" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -d '{"QueryFilter":{}}')

  if [[ "$http_code" == "200" || "$http_code" == "201" ]]; then
    echo "Connection successful"
    echo "Authenticated as: ${BOOMI_USERNAME}"
  else
    echo "ERROR: Connection failed (HTTP ${http_code})" >&2
    exit 1
  fi
}
