#!/usr/bin/env bash
# List Boomi folders: a folder's child folders, or a whole subtree.
# Prints "id<TAB>fullPath" per line and writes
# active-development/inventories/folder_list_<timestamp>.json.
# Deleted folders are excluded.
#
# Usage:
#   bash scripts/boomi-folder-list.sh                                  # top-level folders
#   bash scripts/boomi-folder-list.sh --folder <id|name|path>          # direct children
#   bash scripts/boomi-folder-list.sh --folder <id|name|path> --recursive

source "$(dirname "$0")/boomi-common.sh"
load_env
require_env BOOMI_API_URL BOOMI_USERNAME BOOMI_API_TOKEN BOOMI_ACCOUNT_ID
require_tools curl jq

FOLDER=""
RECURSIVE=false

usage() {
  cat >&2 <<'EOF'
Usage:
  bash scripts/boomi-folder-list.sh [--folder <id|name|path>] [--recursive]

  --folder <id|name|path>  Folder to list. Accepts an id, an exact name, a % LIKE
                           pattern, or a path ('Parent/Child' — a '/'-anchored
                           trailing portion is enough, and % works in any
                           segment). Omit to list top-level folders.
  --recursive              List every descendant, not just direct children. The
                           listed folder itself is not included either way.

Output: "id<TAB>fullPath" per line, plus
        active-development/inventories/folder_list_<timestamp>.json

Environment:
  FOLDER_SCOPE_MAX   Max folders listed with --recursive (default 1000). Past the
                     cap the list is truncated and metadata.truncated is true.
  FOLDER_ID_BATCH    Folder ids per query (default 200).
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --folder)      FOLDER="$2"; shift 2 ;;
    --recursive)   RECURSIVE=true; shift ;;
    -h|--help)     usage; exit 0 ;;
    -*)            echo "Unknown option: $1" >&2; usage; exit 1 ;;
    *)             echo "Unexpected argument: $1" >&2; usage; exit 1 ;;
  esac
done

mkdir -p active-development/inventories
timestamp="$(date -u +%Y%m%d_%H%M%S)"
out_file="active-development/inventories/folder_list_${timestamp}.json"

fail() { # $1 = stage, $2 = message
  log_activity "folder-list" "fail" "${RESPONSE_CODE:-}" \
    "$(jq -cn --arg f "$FOLDER" --arg s "$1" --arg e "$2" \
       '{folder:$f, stage:$s, error:$e}')"
  exit 1
}

if [[ -z "$FOLDER" ]]; then
  # The account root is the only folder with no parent.
  if ! roots=$(folder_query_records '{"operator":"IS_NULL","property":"parentId"}'); then
    fail "resolve-root" "account root lookup failed"
  fi
  if [[ -z "${roots//[[:space:]]/}" ]]; then
    fail "resolve-root" "account root folder not found"
  fi
  scope_label="the account root"
else
  if ! roots=$(resolve_folder_scope "$FOLDER"); then
    fail "resolve-folder" "folder resolution failed"
  fi
  scope_label="$FOLDER"
fi

if ! records=$(printf '%s\n' "$roots" | folder_children); then
  fail "folder-children" "child folder query failed"
fi

# Output excludes the folder itself, so the subtree descends from its children.
TRUNCATED=false
if [[ "$RECURSIVE" == true && -n "${records//[[:space:]]/}" ]]; then
  set +e
  records=$(folder_descendants "$records"); rc=$?
  set -e
  case "$rc" in
    0) ;;
    2) TRUNCATED=true ;;
    *) fail "folder-descendants" "subtree walk failed" ;;
  esac
fi

count=$(printf '%s\n' "$records" | grep -c . || true)

out_tmp="${out_file}.tmp"
trap 'rm -f "$out_tmp"' EXIT
printf '%s\n' "$records" | jq -R -s \
  --arg ts "$timestamp" \
  --arg folder "$FOLDER" \
  --argjson recursive "$([[ "$RECURSIVE" == true ]] && echo true || echo false)" \
  --argjson truncated "$TRUNCATED" \
  '{
    metadata: {
      timestamp: $ts,
      query: "folder-list",
      filters: {
        folder: (if $folder == "" then null else $folder end),
        recursive: $recursive
      },
      truncated: $truncated,
      implicitFilters: { deleted: false }
    },
    records: (split("\n") | map(select(length > 0) | split("\t"))
              | map({id:.[0], name:.[1], fullPath:.[2], parentId:.[3]}))
  }' > "$out_tmp"
mv "$out_tmp" "$out_file"
trap - EXIT

printf '%s\n' "$records" | awk -F'\t' 'NF>0 {print $1 "\t" $3}' | sort -t$'\t' -k2,2

log_activity "folder-list" "success" "${RESPONSE_CODE:-}" \
  "$(jq -cn --arg f "$FOLDER" \
     --argjson recursive "$([[ "$RECURSIVE" == true ]] && echo true || echo false)" \
     --argjson truncated "$TRUNCATED" \
     --argjson c "$count" \
     '{folder:$f, recursive:$recursive, truncated:$truncated, records:$c}')"

if [[ "$TRUNCATED" == true ]]; then
  echo "Found ${count} folder(s) under ${scope_label} — TRUNCATED at the ${FOLDER_SCOPE_MAX}-folder cap → ${out_file}"
else
  echo "Found ${count} folder(s) under ${scope_label} → ${out_file}"
fi
