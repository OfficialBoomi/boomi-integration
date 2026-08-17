#!/usr/bin/env bash
# Shared utilities for Boomi CLI tools
# Sourced by all tool scripts — not executed directly

set -euo pipefail

# --- Environment ---

load_env() {
  local env_file=".env"
  if [[ -f "$env_file" ]]; then
    # No set -a: .env values are read in-shell, never handed to child processes.
    source "$env_file"
    _set_user_agent   # .env must not override the header
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

# --- Version ---

_skill_version() {
  cat "$(dirname "${BASH_SOURCE[0]}")/../VERSION" 2>/dev/null || echo "unknown"
}

# --- Constants ---

# Skill name is a literal — standalone installs may rename the directory.
# A function because load_env re-calls it after sourcing .env, so the
# User-Agent cannot be poisoned.
_set_user_agent() {
  BOOMI_USER_AGENT="boomi-companion/boomi-integration/$(_skill_version)"
}
_set_user_agent

# --- API helpers ---

# Emits a curl config file on stdout for `curl -K -`, keeping credentials out of argv.
# Usage: curl_cfg user "u:p" header "Authorization: Bearer t" | curl -K - ...
curl_cfg() {
  (( $# % 2 == 0 )) || { echo "ERROR: curl_cfg needs directive/value pairs" >&2; return 1; }
  local val
  while [[ $# -gt 1 ]]; do
    val="$2"
    val="${val//\\/\\\\}"
    val="${val//\"/\\\"}"
    printf '%s = "%s"\n' "$1" "$val"
    shift 2
  done
}

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

  curl_cfg user "BOOMI_TOKEN.${BOOMI_USERNAME}:${BOOMI_API_TOKEN}" \
    | curl -s $ssl_flag \
        --max-time "${BOOMI_TIMEOUT:-60}" \
        -A "$BOOMI_USER_AGENT" \
        -K - \
        "$@"
}

# High-level API call: captures body and http code cleanly via temp file.
# Sets global RESPONSE_BODY and RESPONSE_CODE after each call.
# Usage: boomi_api [--out-file <path>] [curl args...]
# When --out-file is given, the response is written to <path> (caller owns it)
# and RESPONSE_BODY is left empty.
RESPONSE_BODY=""
RESPONSE_CODE=""
boomi_api() {
  local out_file=""
  if [[ "${1:-}" == "--out-file" ]]; then
    out_file="$2"; shift 2
  fi
  local tmpfile="${out_file:-$(mktemp)}"
  RESPONSE_CODE=$(boomi_curl -o "$tmpfile" -w "%{http_code}" "$@")
  if [[ -z "$out_file" ]]; then
    RESPONSE_BODY=$(cat "$tmpfile")
    rm -f "$tmpfile"
  else
    RESPONSE_BODY=""
  fi
}

# --- Query pagination ---

# Appends `.result` arrays from a `/query` + `/queryMore` loop into pages_file
# (one JSON array per line; consume with `jq --slurpfile` to avoid ARG_MAX).
# Sets TOTAL_COUNT from the first page.
TOTAL_COUNT=0
paginate_query() {
  local endpoint="$1"
  local body="$2"
  local pages_file="$3"

  local url; url="$(build_api_url "${endpoint}/query" false)"
  boomi_api -X POST "$url" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -d "$body"

  if [[ "$RESPONSE_CODE" != "200" ]]; then
    echo "ERROR: ${endpoint}/query failed (HTTP ${RESPONSE_CODE}): ${RESPONSE_BODY}" >&2
    return 1
  fi

  echo "$RESPONSE_BODY" | jq -c '.result // []' >> "$pages_file"
  TOTAL_COUNT=$(echo "$RESPONSE_BODY" | jq -r '.numberOfResults // 0')
  local token; token=$(echo "$RESPONSE_BODY" | jq -r '.queryToken // empty')

  while [[ -n "$token" ]]; do
    local more_url; more_url="$(build_api_url "${endpoint}/queryMore" false)"
    boomi_api -X POST "$more_url" \
      -H "Accept: application/json" \
      -H "Content-Type: text/plain" \
      -d "$token"

    if [[ "$RESPONSE_CODE" != "200" ]]; then
      echo "WARN: ${endpoint}/queryMore failed (HTTP ${RESPONSE_CODE}); returning partial results." >&2
      break
    fi
    echo "$RESPONSE_BODY" | jq -c '.result // []' >> "$pages_file"
    token=$(echo "$RESPONSE_BODY" | jq -r '.queryToken // empty')
  done
}

# --- Folder helpers ---
#
# fullPath is returned by Folder/query but not queryable, so path matching here
# is client-side. Folder queries are unfiltered on deleted by default, so every
# helper pins deleted=false.

FOLDER_ID_BATCH="${FOLDER_ID_BATCH:-200}"    # ids per OR expression; ~20KB request body
# Subtree cap, bound by folder_descendants' string accumulator rather than the
# API: the walk is quadratic in folder count.
FOLDER_SCOPE_MAX="${FOLDER_SCOPE_MAX:-1000}"

# Folder/query with the given expression AND deleted=false.
# Emits `id<TAB>name<TAB>fullPath<TAB>parentId` per line.
folder_query_records() {
  local expr="$1"
  local body pages records
  body=$(jq -cn --argjson e "$expr" '{QueryFilter:{expression:{
    operator:"and",
    nestedExpression:[$e, {operator:"EQUALS",property:"deleted",argument:["false"]}]
  }}}')
  pages=$(mktemp)
  if ! paginate_query "Folder" "$body" "$pages"; then
    rm -f "$pages"; return 1
  fi
  if ! records=$(jq -r '.[] | [.id, .name, .fullPath, (.parentId // "")] | @tsv' "$pages"); then
    rm -f "$pages"; return 1
  fi
  rm -f "$pages"
  [[ -n "$records" ]] && printf '%s\n' "$records"
  return 0
}

# Warn when a pattern/path resolves to more folders than the cap. The non-recursive
# union path has no cap of its own, so this is its only oversized-scope signal.
_folder_match_count_warn() {
  local input="$1" records="$2" count
  count=$(printf '%s\n' "$records" | grep -c . || true)
  if [[ "$count" -gt "$FOLDER_SCOPE_MAX" ]]; then
    echo "WARN: '${input}' matched ${count} folders, over the ${FOLDER_SCOPE_MAX}-folder cap. Narrow the pattern; a recursive walk of this scope will be truncated." >&2
  fi
}

_folder_scope_cap_warn() {
  echo "WARN: folder scope hit the ${FOLDER_SCOPE_MAX}-folder cap; results are truncated. Narrow the folder rather than raising FOLDER_SCOPE_MAX." >&2
}

# '%' LIKE pattern → shell glob (escaping metacharacters that are literal in LIKE).
_folder_pattern_to_glob() {
  local p="$1"
  p="${p//\\/\\\\}"
  p="${p//\*/\\*}"
  p="${p//\?/\\?}"
  p="${p//\[/\\[}"
  printf '%s' "${p//%/*}"
}

# Resolve a folder reference → `id<TAB>name<TAB>fullPath<TAB>parentId` lines.
# Errors on 0 matches. Input forms, in precedence order:
#   '/' in input → path: query the last segment, then match fullPath client-side
#   '%' in input → LIKE on name, all matches
#   otherwise    → EQUALS id, then EQUALS name (>1 name match is ambiguous → error)
resolve_folder_scope() {
  local input="$1"
  local records

  if [[ "$input" == *"/"* ]]; then
    local leaf="${input##*/}"
    local op="EQUALS"
    [[ "$leaf" == *"%"* ]] && op="LIKE"
    if ! records=$(folder_query_records \
        "$(jq -cn --arg o "$op" --arg v "$leaf" '{operator:$o,property:"name",argument:[$v]}')"); then
      return 1
    fi
    local matched="" id name path parent
    if [[ "$input" == *"%"* ]]; then
      local glob; glob="$(_folder_pattern_to_glob "$input")"
      while IFS=$'\t' read -r id name path parent; do
        [[ -z "$id" ]] && continue
        # shellcheck disable=SC2254  # glob is intentionally unquoted
        if [[ "$path" == $glob || "$path" == */$glob ]]; then
          matched+="${id}	${name}	${path}	${parent}"$'\n'
        fi
      done <<< "$records"
    else
      while IFS=$'\t' read -r id name path parent; do
        [[ -z "$id" ]] && continue
        if [[ "$path" == "$input" || "$path" == *"/$input" ]]; then
          matched+="${id}	${name}	${path}	${parent}"$'\n'
        fi
      done <<< "$records"
    fi
    if [[ -z "$matched" ]]; then
      echo "ERROR: No folder path matched '${input}'. Paths are matched against Folder.fullPath (e.g. 'Account/Parent/Child'); a '/'-anchored trailing portion is enough, and % wildcards work in any segment." >&2
      return 1
    fi
    _folder_match_count_warn "$input" "$matched"
    printf '%s' "$matched"
    return 0
  fi

  if [[ "$input" == *"%"* ]]; then
    if ! records=$(folder_query_records \
        "$(jq -cn --arg v "$input" '{operator:"LIKE",property:"name",argument:[$v]}')"); then
      return 1
    fi
    if [[ -z "${records//[[:space:]]/}" ]]; then
      echo "ERROR: No folders matched pattern '${input}'." >&2
      return 1
    fi
    _folder_match_count_warn "$input" "$records"
    printf '%s\n' "$records"
    return 0
  fi

  # Folder ids are base64 "F:<n>", so always Rjo-prefixed (cf. resolve_branch_id).
  if [[ "$input" == Rjo* ]]; then
    records=$(folder_query_records \
      "$(jq -cn --arg v "$input" '{operator:"EQUALS",property:"id",argument:[$v]}')" 2>/dev/null) || records=""
    if [[ -n "${records//[[:space:]]/}" ]]; then
      printf '%s\n' "$records"
      return 0
    fi
  fi

  if ! records=$(folder_query_records \
      "$(jq -cn --arg v "$input" '{operator:"EQUALS",property:"name",argument:[$v]}')"); then
    return 1
  fi
  if [[ -z "${records//[[:space:]]/}" ]]; then
    echo "ERROR: Folder '${input}' not found (by id or exact name). Use % wildcards for LIKE matching, or a path like 'Parent/Child'." >&2
    return 1
  fi
  local count; count=$(printf '%s\n' "$records" | grep -c . || true)
  if [[ "$count" -gt 1 ]]; then
    echo "ERROR: Folder name '${input}' matches ${count} folders:" >&2
    printf '%s\n' "$records" | awk -F'\t' 'NF>0 {print "  " $3 "  (" $1 ")"}' >&2
    echo "Pass a folder id, a path like 'Parent/${input}', or a % wildcard pattern to accept multiple matches." >&2
    return 1
  fi
  printf '%s\n' "$records"
}

# Direct children of the folder ids on stdin (records or bare ids), batched
# FOLDER_ID_BATCH per query. Emits child records on stdout.
folder_children() {
  local ids=() id
  while IFS=$'\t' read -r id _; do
    [[ -z "$id" ]] && continue
    ids+=("$id")
  done
  [[ ${#ids[@]} -eq 0 ]] && return 0

  local i=0
  while [[ $i -lt ${#ids[@]} ]]; do
    local batch=("${ids[@]:i:FOLDER_ID_BATCH}")
    local exprs=()
    for id in "${batch[@]}"; do
      exprs+=("$(jq -cn --arg v "$id" '{operator:"EQUALS",property:"parentId",argument:[$v]}')")
    done
    local expr
    if [[ ${#exprs[@]} -eq 1 ]]; then
      expr="${exprs[0]}"
    else
      expr=$(jq -cn --argjson n "[$(IFS=,; echo "${exprs[*]}")]" '{operator:"or",nestedExpression:$n}')
    fi
    if ! folder_query_records "$expr"; then
      return 1
    fi
    i=$((i + FOLDER_ID_BATCH))
  done
}

# BFS a subtree from the given root records → roots plus every descendant, as
# `id<TAB>name<TAB>fullPath<TAB>parentId` lines. Visits each id once.
# Exit: 0 complete, 1 query failed, 2 truncated at FOLDER_SCOPE_MAX (partial
# records still on stdout). Callers MUST surface 2, or a partial subtree reads
# as a complete one.
folder_descendants() {
  local roots="$1"

  local seen=" " out="" frontier="" id name path parent total=0
  # The roots are capped too: a wide pattern ('%', 'Billing/%') can resolve to
  # more folders than the cap on its own, and if they already cover the tree the
  # child loop below never runs to catch it.
  while IFS=$'\t' read -r id name path parent; do
    [[ -z "$id" ]] && continue
    [[ "$seen" == *" $id "* ]] && continue
    if [[ "$total" -ge "$FOLDER_SCOPE_MAX" ]]; then
      _folder_scope_cap_warn
      printf '%s' "$out"
      return 2
    fi
    seen+="$id "
    out+="${id}	${name}	${path}	${parent}"$'\n'
    frontier+="${id}"$'\n'
    total=$((total + 1))
  done <<< "$roots"

  while [[ -n "${frontier//[[:space:]]/}" ]]; do
    local children
    if ! children=$(printf '%s' "$frontier" | folder_children); then
      return 1
    fi
    frontier=""
    while IFS=$'\t' read -r id name path parent; do
      [[ -z "$id" ]] && continue
      [[ "$seen" == *" $id "* ]] && continue
      if [[ "$total" -ge "$FOLDER_SCOPE_MAX" ]]; then
        _folder_scope_cap_warn
        printf '%s' "$out"
        return 2
      fi
      seen+="$id "
      out+="${id}	${name}	${path}	${parent}"$'\n'
      frontier+="${id}"$'\n'
      total=$((total + 1))
    done <<< "$children"
  done

  printf '%s' "$out"
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
      jq -r '.branch_id // empty' < "$sf" 2>/dev/null
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
  # || true: a no-match must yield empty, not exit 1, under set -euo pipefail
  # head -n1: platform XML is single-line, so -o would emit every match
  { grep -o "${attr}=\"[^\"]*\"" || true; } | head -n1 | sed "s/${attr}=\"//;s/\"//"
}

# Usage: set_root_component_id "<id-or-empty>" < file.xml
set_root_component_id() {
  awk -v id="$1" '
    BEGIN { done = 0; intag = 0 }
    {
      if (!done) {
        start = 1
        if (!intag) {
          ts = match($0, /<bns:Component|<Component/)
          if (ts) { intag = 1; start = ts }
        }
        if (intag) {
          rest = substr($0, start)
          gt = index(rest, ">")
          ci = match(rest, /componentId="[^"]*"/)
          if (ci > 0 && (gt == 0 || ci < gt)) {
            # componentId belongs to the root open tag — replace its value
            abs = start + ci - 1
            $0 = substr($0, 1, abs - 1) "componentId=\"" id "\"" substr($0, abs + RLENGTH)
            done = 1; intag = 0
          } else if (gt > 0) {
            # root open tag closes here with no componentId — insert before the close
            abs = start + gt - 1
            ins = abs
            if (substr($0, abs - 1, 1) == "/") ins = abs - 1
            $0 = substr($0, 1, ins - 1) " componentId=\"" id "\"" substr($0, ins)
            done = 1; intag = 0
          }
        }
      }
      print
    }
  '
}

# Portable in-place sed (macOS vs GNU)
sedi() {
  if sed --version 2>/dev/null | grep -q GNU; then
    sed -i "$@"
  else
    sed -i '' "$@"
  fi
}

# --- Credential guards ---

# Matches REST Client connection AND operation components — they share this subType.
# Operations carry no password fields, so the caller is unaffected.
# Usage: is_rest_connector_component <file>
is_rest_connector_component() {
  grep -qE 'subType="officialboomi-[A-Za-z0-9]+-rest(-[^"]*)?"' "$1" 2>/dev/null
}

# Refuse to write a pulled REST Client secret token back to the platform. Other connectors are
# not checked. Detects the token form only — an emptied or deleted password field destroys the
# credential too, but catching that needs prior platform state, so the error text warns instead.
# Usage: assert_no_password_token <file> [allow:true|false]
assert_no_password_token() {
  local file="$1" allow="${2:-false}"
  [[ "$allow" == "true" ]] && return 0
  is_rest_connector_component "$file" || return 0

  # Token shape: exactly 128 lowercase hex in a type="password" field value.
  local ids="" field_tag field_id
  while IFS= read -r field_tag; do
    [[ "$field_tag" == *'type="password"'* ]] || continue
    printf '%s' "$field_tag" | grep -qE '[^a-zA-Z]value="[0-9a-f]{128}"' || continue
    field_id="?"
    if [[ "$field_tag" == *' id="'* ]]; then
      field_id="${field_tag#* id=\"}"
      field_id="${field_id%%\"*}"
    fi
    ids+=" $field_id"
  done < <(tr '\r\n' '  ' < "$file" | grep -oE '<field[^>]*>' 2>/dev/null || true)
  [[ -n "$ids" ]] || return 0

  echo "ERROR: refusing to write — REST Client password field(s) hold a pulled secret token:${ids}" >&2
  echo "That value references the stored secret; writing it makes the token string the credential. The" >&2
  echo "write and deploy succeed, then auth fails at request time and a later pull still reports" >&2
  echo "isSet=\"true\", so nothing looks wrong." >&2
  echo "Fix: do not write this component. Have the user set the password in the Boomi GUI, or move the" >&2
  echo "secret to an Environment Extension. Do not ask the user for the plaintext to get past this, and" >&2
  echo "do not empty or delete the field — unchecked, but equally destructive." >&2
  echo "See references/components/rest_connection_component.md § Password Encryption." >&2
  echo "If this genuinely is a 128-lowercase-hex credential, re-run with --allow-password-token." >&2
  exit 1
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
      cid=$(jq -r '.component_id // empty' < "$sf" 2>/dev/null)
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

# Opt-in via BOOMI_COMPANION_LOG_ACTIVITY=1 in .env. Default is off.
log_activity() {
  [[ "${BOOMI_COMPANION_LOG_ACTIVITY:-0}" == "1" ]] || return 0

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
      --arg name "boomi-integration" \
      --arg ver "$(_skill_version)" \
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
        skill_name: $name,
        skill_version: $ver,
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
