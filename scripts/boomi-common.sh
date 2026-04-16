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

# --- Constants ---

BOOMI_USER_AGENT="boomi-companion/$(cat "$(dirname "${BASH_SOURCE[0]}")/../VERSION" 2>/dev/null || echo unknown)"

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
    -A "$BOOMI_USER_AGENT" \
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

# --- Branch helpers ---

# Resolve a branch name or ID to a branch ID.
# If input looks like a base64 branch ID (starts with Qjo), pass through.
# Otherwise, query Branch API by name.
resolve_branch_id() {
  local input="$1"
  [[ "$input" == Qjo* ]] && { echo "$input"; return 0; }

  local url
  url="$(build_api_url "Branch/query" false)"
  boomi_api -X POST "$url" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -d "{\"QueryFilter\":{\"expression\":{\"operator\":\"EQUALS\",\"property\":\"name\",\"argument\":[\"${input}\"]}}}"

  if [[ "$RESPONSE_CODE" != "200" ]]; then
    echo "ERROR: Branch query failed (HTTP ${RESPONSE_CODE})" >&2
    return 1
  fi

  local branch_id
  branch_id=$(echo "$RESPONSE_BODY" | jq -r '.result[0].id // empty')
  if [[ -z "$branch_id" ]]; then
    echo "ERROR: Branch '${input}' not found" >&2
    return 1
  fi
  echo "$branch_id"
}

# Resolve a branch ID to a human-readable branch name.
# If input does NOT look like a base64 branch ID, pass through (already a name).
resolve_branch_name() {
  local input="$1"
  [[ "$input" != Qjo* ]] && { echo "$input"; return 0; }

  local url
  url="$(build_api_url "Branch/query" false)"
  boomi_api -X POST "$url" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -d "{\"QueryFilter\":{\"expression\":{\"operator\":\"EQUALS\",\"property\":\"id\",\"argument\":[\"${input}\"]}}}"

  if [[ "$RESPONSE_CODE" != "200" ]]; then
    echo "ERROR: Branch query failed (HTTP ${RESPONSE_CODE})" >&2
    return 1
  fi

  local branch_name
  branch_name=$(echo "$RESPONSE_BODY" | jq -r '.result[0].name // empty')
  if [[ -z "$branch_name" ]]; then
    echo "ERROR: Branch ID '${input}' not found" >&2
    return 1
  fi
  echo "$branch_name"
}

# Read branchId attribute from a component XML file. Empty if not present.
detect_xml_branch() {
  local file="$1"
  local match
  match=$(grep -o 'branchId="[^"]*"' "$file" 2>/dev/null || true)
  [[ -n "$match" ]] && echo "$match" | head -1 | sed 's/branchId="//;s/"//'
  return 0
}

# Inject or replace branchId attribute in XML string.
# Handles both <Component and <bns:Component (namespaced) element tags.
inject_branch_id() {
  local xml="$1"
  local branch_id="$2"
  if echo "$xml" | grep -q 'branchId="'; then
    echo "$xml" | sed "s/branchId=\"[^\"]*\"/branchId=\"${branch_id}\"/"
  else
    echo "$xml" | sed "s/<\([a-zA-Z]*:\)\{0,1\}Component /<\1Component branchId=\"${branch_id}\" /"
  fi
}

# Determine effective branch: --branch flag > XML branchId > BOOMI_DEFAULT_BRANCH_ID > empty (main)
resolve_effective_branch() {
  local flag_branch="$1"
  local xml_branch="$2"

  if [[ -n "$flag_branch" ]]; then
    resolve_branch_id "$flag_branch"
  elif [[ -n "$xml_branch" ]]; then
    echo "$xml_branch"
  elif [[ -n "${BOOMI_DEFAULT_BRANCH_ID:-}" ]]; then
    echo "$BOOMI_DEFAULT_BRANCH_ID"
  fi
}

# Read branchId from sync state. Empty if not present.
read_sync_branch() {
  local file_path="$1"
  local sync_dir="$(pwd)/active-development/.sync-state"
  local state_name
  state_name="$(_sync_state_name "$file_path")"
  local component_name
  component_name="$(basename "$file_path" .xml)"

  for sf in "${sync_dir}/${state_name}.json" "${sync_dir}/${component_name}.json"; do
    if [[ -f "$sf" ]]; then
      jq -r '.branch_id // empty' "$sf" 2>/dev/null
      return 0
    fi
  done
}

# --- XML helpers ---

# Extract an attribute value from an XML string or file
# Usage: xml_attr "componentId" < file.xml
#    or: echo "$xml" | xml_attr "componentId"
xml_attr() {
  local attr="$1"
  grep -o -m 1 "${attr}=\"[^\"]*\"" | sed "s/${attr}=\"//;s/\"//"
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
  local branch_id="${4:-}"
  local sync_dir="$(pwd)/active-development/.sync-state"

  mkdir -p "$sync_dir"

  local state_name
  state_name="$(_sync_state_name "$file_path")"
  local state_file="${sync_dir}/${state_name}.json"

  local json="{\"component_id\":\"${component_id}\",\"file_path\":\"${file_path}\",\"content_hash\":\"${content_hash}\",\"last_sync\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"
  [[ -n "$branch_id" ]] && json=$(echo "$json" | jq --arg b "$branch_id" '. + {branch_id: $b}')
  echo "$json" | jq '.' > "$state_file"
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
  cat "$(dirname "${BASH_SOURCE[0]}")/../VERSION" 2>/dev/null || echo "unknown"
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
  local v
  v=$(cat "$(dirname "${BASH_SOURCE[0]}")/../VERSION" 2>/dev/null || echo "unknown")
  echo "built with boomi-companion v${v}"
}

# Stamp origin tag into <bns:description> element of a local component XML file.
# Modifies the file in-place so the stamp persists across pushes.
# Handles: <bns:description>text</...>, <bns:description/>, <bns:description></...>
# If no description element exists, injects one before <bns:object>.
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

  # No description element — inject one before <bns:object>
  if grep -q '<bns:object>' "$file_path"; then
    sedi "s#<bns:object>#<bns:description>${tag}</bns:description><bns:object>#" "$file_path"
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
