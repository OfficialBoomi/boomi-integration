#!/usr/bin/env bash
# Search Boomi components by folder, name, type, or reference relationship.
# Results are written to active-development/inventories/component_search_<timestamp>.json.
# Default filters include currentVersion=true and deleted=false.
# Folder scoping is flat unless --recursive is passed.
#
# Usage:
#   bash scripts/boomi-component-search.sh --folder <id|name|path> [--recursive]
#   bash scripts/boomi-component-search.sh --name '%Invoice%' [--type process]
#   bash scripts/boomi-component-search.sh --type connector-settings,connector-action
#   bash scripts/boomi-component-search.sh --related-to <componentId>
#
# --type takes the API-level component type, not the Boomi UI label. A Boomi
# "connection" is type=connector-settings with a subType identifying the
# connector (e.g. salesforce); an "operation" is type=connector-action.

source "$(dirname "$0")/boomi-common.sh"
load_env
require_env BOOMI_API_URL BOOMI_USERNAME BOOMI_API_TOKEN BOOMI_ACCOUNT_ID
require_tools curl jq

# --- Parse args ---
FOLDER=""
NAME=""
TYPES=""
RELATED_TO=""
RECURSIVE=false

usage() {
  cat >&2 <<'EOF'
Usage:
  bash scripts/boomi-component-search.sh <filter> [<filter>...]

Filters (at least one required):
  --folder <id|name|path> Components in the given folder (flat unless --recursive).
                          Accepts an id, an exact name, a % LIKE pattern, or a
                          path ('Parent/Child' — a '/'-anchored trailing portion
                          is enough, and % works in any segment). A % pattern or
                          path matching several folders unions them; an exact
                          name matching several is refused as ambiguous.
  --recursive             With --folder: also include every descendant folder.
                          Use for parent folders whose components all live in
                          subfolders.
  --name <pattern>        LIKE match on name (case-insensitive); use % wildcards (e.g. '%Invoice%')
  --type <csv>            Component types (OR). Use the API-level type, not the UI label:
                          process, connector-settings (connections), connector-action (operations),
                          transform.map, profile.xml, profile.json, profile.db,
                          profile.edi, profile.flatfile, script.processing, ...
                          e.g. process,connector-settings,connector-action
  --related-to <id>       Components the given id references OR is referenced-by
                          (each output record carries a "relation" field:
                           "references" or "referenced-by")
                          (cannot combine with other filters)

Output: active-development/inventories/component_search_<timestamp>.json

Environment:
  FOLDER_SCOPE_MAX   Max folders in a --recursive scope (default 1000). Past the
                     cap the scope is truncated and metadata.truncated is true.
  FOLDER_ID_BATCH    Folder ids per query (default 200).
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --folder)      FOLDER="$2"; shift 2 ;;
    --recursive)   RECURSIVE=true; shift ;;
    --name)        NAME="$2"; shift 2 ;;
    --type)        TYPES="$2"; shift 2 ;;
    --related-to)  RELATED_TO="$2"; shift 2 ;;
    -h|--help)     usage; exit 0 ;;
    -*)            echo "Unknown option: $1" >&2; usage; exit 1 ;;
    *)             echo "Unexpected argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$FOLDER" && -z "$NAME" && -z "$TYPES" && -z "$RELATED_TO" ]]; then
  echo "ERROR: at least one filter is required." >&2
  usage
  exit 1
fi

if [[ -n "$RELATED_TO" && ( -n "$FOLDER" || -n "$NAME" || -n "$TYPES" || "$RECURSIVE" == true ) ]]; then
  echo "ERROR: --related-to cannot be combined with other filters." >&2
  exit 1
fi

if [[ "$RECURSIVE" == true && -z "$FOLDER" ]]; then
  echo "ERROR: --recursive requires --folder." >&2
  exit 1
fi

mkdir -p active-development/inventories
timestamp="$(date -u +%Y%m%d_%H%M%S)"
out_file="active-development/inventories/component_search_${timestamp}.json"

# --- Tempfile management (trap-based cleanup on any exit path) ---
TMPFILES=()
cleanup_tmpfiles() {
  local f
  # bash 3.2 reads an empty array as unset under set -u; hence the ${arr[@]+...} guard.
  for f in ${TMPFILES[@]+"${TMPFILES[@]}"}; do
    [[ -n "$f" ]] && rm -f "$f"
  done
}
trap cleanup_tmpfiles EXIT

mktempfile() {
  local f
  f=$(mktemp)
  TMPFILES+=("$f")
  echo "$f"
}

# --- Build ComponentMetadata/query expression ---
# Always adds currentVersion=true and deleted=false.
build_component_expr() {
  # $1: newline-separated list of folderIds (empty = no folder filter)
  local folder_ids_nl="$1"
  local name="$2"
  local types_csv="$3"

  local exprs=()
  exprs+=("$(jq -cn '{operator:"EQUALS",property:"currentVersion",argument:["true"]}')")
  exprs+=("$(jq -cn '{operator:"EQUALS",property:"deleted",argument:["false"]}')")

  if [[ -n "$folder_ids_nl" ]]; then
    local folder_exprs=() fid
    while IFS= read -r fid; do
      [[ -z "$fid" ]] && continue
      folder_exprs+=("$(jq -cn --arg v "$fid" '{operator:"EQUALS",property:"folderId",argument:[$v]}')")
    done <<< "$folder_ids_nl"
    if [[ ${#folder_exprs[@]} -eq 1 ]]; then
      exprs+=("${folder_exprs[0]}")
    elif [[ ${#folder_exprs[@]} -gt 1 ]]; then
      local nested="[$(IFS=,; echo "${folder_exprs[*]}")]"
      exprs+=("$(jq -cn --argjson n "$nested" '{operator:"or",nestedExpression:$n}')")
    fi
  fi

  if [[ -n "$name" ]]; then
    exprs+=("$(jq -cn --arg v "$name" '{operator:"LIKE",property:"name",argument:[$v]}')")
  fi

  if [[ -n "$types_csv" ]]; then
    local type_exprs=()
    IFS=',' read -ra parts <<< "$types_csv"
    for t in "${parts[@]}"; do
      t="${t// /}"
      [[ -z "$t" ]] && continue
      type_exprs+=("$(jq -cn --arg v "$t" '{operator:"EQUALS",property:"type",argument:[$v]}')")
    done
    if [[ ${#type_exprs[@]} -eq 1 ]]; then
      exprs+=("${type_exprs[0]}")
    elif [[ ${#type_exprs[@]} -gt 1 ]]; then
      local nested="[$(IFS=,; echo "${type_exprs[*]}")]"
      exprs+=("$(jq -cn --argjson n "$nested" '{operator:"or",nestedExpression:$n}')")
    fi
  fi

  local nested="[$(IFS=,; echo "${exprs[*]}")]"
  jq -cn --argjson n "$nested" '{operator:"and",nestedExpression:$n}'
}

# --- Reference-relationship query path ---
# ComponentReference/query rejects any filter that pins parentComponentId without
# a companion parentVersion — so resolve the target's current version first.
# Writes final output atomically via .tmp + mv so a mid-write failure can't
# leave a 0-byte file in active-development/inventories/.
run_related_to() {
  local related_to="$1"

  echo "Resolving current version of ${related_to}..."
  local meta_expr meta_body meta_url current_version
  meta_expr=$(jq -cn --arg v "$related_to" '{
    operator:"and",
    nestedExpression:[
      {operator:"EQUALS",property:"componentId",argument:[$v]},
      {operator:"EQUALS",property:"currentVersion",argument:["true"]}
    ]
  }')
  meta_body=$(jq -cn --argjson e "$meta_expr" '{QueryFilter:{expression:$e}}')
  meta_url="$(build_api_url "ComponentMetadata/query" false)"
  boomi_api -X POST "$meta_url" \
    -H "Accept: application/json" -H "Content-Type: application/json" \
    -d "$meta_body"
  if [[ "$RESPONSE_CODE" != "200" ]]; then
    log_activity "component-search" "fail" "$RESPONSE_CODE" \
      "$(jq -cn --arg id "$related_to" --arg err "${RESPONSE_BODY:0:500}" \
         '{mode:"related-to", related_to:$id, stage:"resolve-version", error:$err}')"
    echo "ERROR: could not resolve ${related_to} (HTTP ${RESPONSE_CODE}): ${RESPONSE_BODY}" >&2
    return 1
  fi
  current_version=$(echo "$RESPONSE_BODY" | jq -r '.result[0].version // empty')
  if [[ -z "$current_version" ]]; then
    log_activity "component-search" "fail" "no-current-version" \
      "$(jq -cn --arg id "$related_to" \
         '{mode:"related-to", related_to:$id, stage:"resolve-version", error:"component not found or has no current version"}')"
    echo "ERROR: component ${related_to} not found or has no current version." >&2
    return 1
  fi

  echo "Querying references for ${related_to} (current version ${current_version})..."

  # "references" direction: rows where the target (as parent) references something else.
  # parentComponentId=target AND parentVersion=target-current-version
  local expr_ref body_ref refs_pages refs_total
  expr_ref=$(jq -cn --arg v "$related_to" --arg ver "$current_version" '{
    operator:"and",
    nestedExpression:[
      {operator:"EQUALS",property:"parentComponentId",argument:[$v]},
      {operator:"EQUALS",property:"parentVersion",argument:[$ver]}
    ]
  }')
  body_ref=$(jq -cn --argjson e "$expr_ref" '{QueryFilter:{expression:$e}}')
  refs_pages=$(mktempfile)
  if ! paginate_query "ComponentReference" "$body_ref" "$refs_pages"; then
    log_activity "component-search" "fail" "$RESPONSE_CODE" \
      "$(jq -cn --arg id "$related_to" --arg err "${RESPONSE_BODY:0:500}" \
         '{mode:"related-to", related_to:$id, stage:"references-query", error:$err}')"
    return 1
  fi
  refs_total=$TOTAL_COUNT

  # "referenced-by" direction: rows where something else references the target.
  # componentId=target (no version constraint — match all referrers regardless of their version)
  local expr_by body_by by_pages by_total
  expr_by=$(jq -cn --arg v "$related_to" '{operator:"EQUALS",property:"componentId",argument:[$v]}')
  body_by=$(jq -cn --argjson e "$expr_by" '{QueryFilter:{expression:$e}}')
  by_pages=$(mktempfile)
  if ! paginate_query "ComponentReference" "$body_by" "$by_pages"; then
    log_activity "component-search" "fail" "$RESPONSE_CODE" \
      "$(jq -cn --arg id "$related_to" --arg err "${RESPONSE_BODY:0:500}" \
         '{mode:"related-to", related_to:$id, stage:"referenced-by-query", error:$err}')"
    return 1
  fi
  by_total=$TOTAL_COUNT

  local out_tmp="${out_file}.tmp"
  TMPFILES+=("$out_tmp")
  jq -n \
    --arg ts "$timestamp" \
    --arg related_to "$related_to" \
    --arg ver "$current_version" \
    --slurpfile refs "$refs_pages" \
    --slurpfile by "$by_pages" \
    '{
      metadata: {
        timestamp: $ts,
        query: "related-to",
        filters: { relatedTo: $related_to, resolvedVersion: ($ver | tonumber) }
      },
      records: (
        ((($refs | add) // []) | map(. + {relation:"references"})) +
        ((($by | add) // []) | map(. + {relation:"referenced-by"}))
      )
    }' > "$out_tmp"
  mv "$out_tmp" "$out_file"

  local count
  count=$(jq '.records | length' "$out_file")

  log_activity "component-search" "success" "$RESPONSE_CODE" \
    "$(jq -cn --arg id "$related_to" --arg ver "$current_version" --argjson c "$count" \
       '{mode:"related-to", related_to:$id, resolved_version:($ver | tonumber), records:$c}')"

  echo "Found ${count} reference(s) (references: ${refs_total}, referenced-by: ${by_total}) → ${out_file}"
}

# --- Dispatch ---

if [[ -n "$RELATED_TO" ]]; then
  run_related_to "$RELATED_TO"
  exit $?
fi

# --- Component-metadata path ---
folder_ids_nl=""
folder_scope_json="null"
folder_count=0
TRUNCATED=false
if [[ -n "$FOLDER" ]]; then
  if ! folder_records=$(resolve_folder_scope "$FOLDER"); then
    log_activity "component-search" "fail" "folder-resolve" \
      "$(jq -cn --arg f "$FOLDER" --argjson r "$([[ "$RECURSIVE" == true ]] && echo true || echo false)" \
         '{mode:"component-metadata", folder:$f, recursive:$r, stage:"resolve-folder", error:"folder resolution failed"}')"
    exit 1
  fi
  root_count=$(printf '%s\n' "$folder_records" | grep -c . || true)

  if [[ "$RECURSIVE" == true ]]; then
    set +e
    folder_records=$(folder_descendants "$folder_records"); rc=$?
    set -e
    case "$rc" in
      0) ;;
      2) TRUNCATED=true ;;
      *) log_activity "component-search" "fail" "folder-descendants" \
           "$(jq -cn --arg f "$FOLDER" \
              '{mode:"component-metadata", folder:$f, recursive:true, stage:"folder-descendants", error:"subtree walk failed"}')"
         exit 1 ;;
    esac
  fi

  folder_ids_nl=$(printf '%s\n' "$folder_records" | awk -F'\t' 'NF>0 {print $1}')
  folder_count=$(printf '%s\n' "$folder_ids_nl" | grep -c . || true)
  folder_scope_json=$(printf '%s\n' "$folder_records" \
    | jq -R -s -c 'split("\n") | map(select(length>0) | split("\t"))
                   | map({id:.[0], name:.[1], fullPath:.[2]})')

  if [[ "$RECURSIVE" == true ]]; then
    echo "Resolved folder '${FOLDER}' → ${root_count} root(s), ${folder_count} folders in scope (recursive)$([[ "$TRUNCATED" == true ]] && echo " — TRUNCATED at the ${FOLDER_SCOPE_MAX}-folder cap")"
  elif [[ "$folder_count" -eq 1 ]]; then
    echo "Resolved folder '${FOLDER}' → $(printf '%s\n' "$folder_records" | awk -F'\t' 'NF>0 {print $1 " (" $3 ")"; exit}')"
  else
    echo "Resolved folder '${FOLDER}' → ${folder_count} folders (union)"
  fi
fi

pages=$(mktempfile)
echo "Searching components..."

# Chunk folder ids so a wide subtree can't build an unbounded request body.
# TOTAL_COUNT is per-query, so sum the reported totals across batches.
total_reported=0
run_batch() {
  local ids_nl="$1"
  local expr body
  expr=$(build_component_expr "$ids_nl" "$NAME" "$TYPES")
  body=$(jq -cn --argjson e "$expr" '{QueryFilter:{expression:$e}}')
  if ! paginate_query "ComponentMetadata" "$body" "$pages"; then
    log_activity "component-search" "fail" "$RESPONSE_CODE" \
      "$(jq -cn --arg folder "$FOLDER" --arg name "$NAME" --arg types "$TYPES" \
         --arg err "${RESPONSE_BODY:0:500}" \
         '{mode:"component-metadata", folder:$folder, name:$name, types:$types, stage:"query", error:$err}')"
    return 1
  fi
  total_reported=$((total_reported + TOTAL_COUNT))
}

if [[ "$folder_count" -gt "$FOLDER_ID_BATCH" ]]; then
  batch=""
  batch_n=0
  while IFS= read -r fid; do
    [[ -z "$fid" ]] && continue
    batch+="${fid}"$'\n'
    batch_n=$((batch_n + 1))
    if [[ "$batch_n" -ge "$FOLDER_ID_BATCH" ]]; then
      run_batch "$batch" || exit 1
      batch=""; batch_n=0
    fi
  done <<< "$folder_ids_nl"
  [[ -n "$batch" ]] && { run_batch "$batch" || exit 1; }
else
  run_batch "$folder_ids_nl" || exit 1
fi
TOTAL_COUNT=$total_reported

out_tmp="${out_file}.tmp"
TMPFILES+=("$out_tmp")
jq -n \
  --arg ts "$timestamp" \
  --arg folder "$FOLDER" \
  --arg folder_ids "$folder_ids_nl" \
  --argjson folder_scope "$folder_scope_json" \
  --argjson recursive "$([[ "$RECURSIVE" == true ]] && echo true || echo false)" \
  --argjson truncated "$TRUNCATED" \
  --arg name "$NAME" \
  --arg types "$TYPES" \
  --slurpfile pages "$pages" \
  '{
    metadata: {
      timestamp: $ts,
      query: "component-metadata",
      filters: {
        folder: (if $folder == "" then null else $folder end),
        recursive: $recursive,
        resolvedFolders: (if $folder_ids == "" then null else ($folder_ids | split("\n") | map(select(length > 0))) end),
        folderScope: $folder_scope,
        name: (if $name == "" then null else $name end),
        type: (if $types == "" then null else ($types | split(",") | map(gsub("^\\s+|\\s+$"; ""))) end)
      },
      truncated: $truncated,
      implicitFilters: { currentVersion: true, deleted: false }
    },
    records: (($pages | add) // [])
  }' > "$out_tmp"
mv "$out_tmp" "$out_file"

count=$(jq '.records | length' "$out_file")

log_activity "component-search" "success" "$RESPONSE_CODE" \
  "$(jq -cn --arg folder "$FOLDER" --arg name "$NAME" --arg types "$TYPES" \
     --argjson recursive "$([[ "$RECURSIVE" == true ]] && echo true || echo false)" \
     --argjson truncated "$TRUNCATED" \
     --argjson folders "$folder_count" \
     --argjson c "$count" --argjson total "$TOTAL_COUNT" \
     '{mode:"component-metadata", folder:$folder, recursive:$recursive, truncated:$truncated, folder_count:$folders, name:$name, types:$types, records:$c, total:$total}')"

echo "Found ${count} component(s) (total reported: ${TOTAL_COUNT}) → ${out_file}"
if [[ "$TRUNCATED" == true ]]; then
  echo "WARN: folder scope was truncated at the ${FOLDER_SCOPE_MAX}-folder cap — these results are partial." >&2
fi
