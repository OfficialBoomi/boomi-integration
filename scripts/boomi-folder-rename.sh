#!/usr/bin/env bash
# Rename a folder on the Boomi platform. The folder keeps its id, parent, and
# contents; only its name (and so its fullPath) changes.
#
# Usage: bash scripts/boomi-folder-rename.sh --folder <id|name|path> --new-name <name>

source "$(dirname "$0")/boomi-common.sh"
load_env
require_env BOOMI_API_URL BOOMI_USERNAME BOOMI_API_TOKEN BOOMI_ACCOUNT_ID
require_tools curl jq

FOLDER=""
NEW_NAME=""

usage() {
  cat >&2 <<'EOF'
Usage:
  bash scripts/boomi-folder-rename.sh --folder <id|name|path> --new-name <name>

  --folder <id|name|path>  Folder to rename. Accepts an id, an exact name, or a
                           path ('Parent/Child' — a '/'-anchored trailing portion
                           is enough). Must resolve to exactly one folder.
  --new-name <name>        New folder name (the leaf name, not a path). Refused
                           if a sibling folder already has that name.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --folder)    FOLDER="$2"; shift 2 ;;
    --new-name)  NEW_NAME="$2"; shift 2 ;;
    -h|--help)   usage; exit 0 ;;
    -*)          echo "Unknown option: $1" >&2; usage; exit 1 ;;
    *)           echo "Unexpected argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$FOLDER" || -z "$NEW_NAME" ]]; then
  usage; exit 1
fi
if [[ "$NEW_NAME" == */* ]]; then
  echo "ERROR: --new-name is a folder name, not a path. Renaming does not move a folder." >&2
  exit 1
fi

fail() { # $1 = stage, $2 = message
  log_activity "folder-rename" "fail" "${RESPONSE_CODE:-}" \
    "$(jq -cn --arg f "$FOLDER" --arg n "$NEW_NAME" --arg s "$1" --arg e "$2" \
       '{folder:$f, new_name:$n, stage:$s, error:$e}')"
  exit 1
}

# --- Resolve to exactly one folder ---
if ! records=$(resolve_folder_scope "$FOLDER"); then
  fail "resolve-folder" "folder resolution failed"
fi
count=$(printf '%s\n' "$records" | grep -c . || true)
if [[ "$count" -ne 1 ]]; then
  echo "ERROR: '${FOLDER}' matches ${count} folders; rename needs exactly one:" >&2
  printf '%s\n' "$records" | awk -F'\t' 'NF>0 {print "  " $3 "  (" $1 ")"}' >&2
  fail "resolve-folder" "ambiguous folder reference"
fi
IFS=$'\t' read -r folder_id old_name old_path parent_id <<< "$records"

if [[ "$old_name" == "$NEW_NAME" ]]; then
  echo "Folder '${old_path}' is already named '${NEW_NAME}'; nothing to do."
  exit 0
fi

# Refuse duplicate sibling names (platform allows them).
if ! same_name=$(folder_query_records \
    "$(jq -cn --arg v "$NEW_NAME" '{operator:"EQUALS",property:"name",argument:[$v]}')"); then
  fail "sibling-check" "sibling name query failed"
fi
if printf '%s\n' "$same_name" | awk -F'\t' -v p="$parent_id" -v self="$folder_id" 'NF>0 && $4 == p && $1 != self {found=1} END {exit !found}'; then
  echo "ERROR: A sibling folder named '${NEW_NAME}' already exists under '${old_path%/*}'. Pick a different name." >&2
  fail "sibling-check" "sibling name collision"
fi

# --- Read the current folder, change only the name, write it back ---
url="$(build_api_url "Folder/${folder_id}")"
boomi_api -X GET "$url" -H "Accept: application/json"
if [[ "$RESPONSE_CODE" != "200" ]]; then
  echo "ERROR: Folder GET failed (HTTP ${RESPONSE_CODE}): ${RESPONSE_BODY}" >&2
  fail "get-folder" "HTTP ${RESPONSE_CODE}"
fi

body=$(printf '%s' "$RESPONSE_BODY" | jq -c --arg n "$NEW_NAME" \
  '.name = $n | del(.fullPath, .deleted, .parentName)')

boomi_api -X POST "$url" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -d "$body"

if [[ "$RESPONSE_CODE" != "200" ]]; then
  echo "ERROR: Folder rename failed (HTTP ${RESPONSE_CODE}): ${RESPONSE_BODY}" >&2
  fail "update-folder" "${RESPONSE_BODY:0:500}"
fi

new_path=$(printf '%s' "$RESPONSE_BODY" | jq -r '.fullPath // empty')

log_activity "folder-rename" "success" "$RESPONSE_CODE" \
  "$(jq -cn --arg id "$folder_id" --arg old "$old_name" --arg new "$NEW_NAME" \
     --arg path "$new_path" \
     '{folder_id:$id, old_name:$old, new_name:$new, full_path:$path}')"
echo "SUCCESS: Renamed '${old_path}' → '${new_path:-$NEW_NAME}' (ID: ${folder_id})"
