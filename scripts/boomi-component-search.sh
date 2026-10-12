#!/usr/bin/env bash
# Search Boomi components by folder, name, type, or reference relationship.
# Results are written to active-development/inventories/component_search_<timestamp>.json.
# Default filters include currentVersion=true and deleted=false. currentVersion
# tracks the account default branch, so results are scoped to that branch
# (main unless the account sets another).
# Folder scoping is flat unless --recursive is passed.
#
# Usage:
#   bash scripts/boomi-component-search.sh --folder <id|name|path> [--recursive]
#   bash scripts/boomi-component-search.sh --name '%Invoice%' [--type process]
#   bash scripts/boomi-component-search.sh --type connector-settings,connector-action
#   bash scripts/boomi-component-search.sh --related-to <componentId> [--branch <name|id>]
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
BRANCH=""
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
                          (each record's "relation" field says which; cannot
                          combine with the filters above)
  --branch <name|id>      With --related-to: resolve versions and consumers on
                          this branch. Defaults to BOOMI_DEFAULT_BRANCH_ID; with
                          neither set, referenced-by is not branch-filtered.

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
    --branch)      BRANCH="$2"; shift 2 ;;
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

if [[ -z "$RELATED_TO" && -n "$BRANCH" ]]; then
  echo "ERROR: --branch requires --related-to." >&2
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
TMPDIR_RUN=$(mktemp -d)
cleanup_tmpfiles() {
  local f
  # bash 3.2 reads an empty array as unset under set -u; hence the ${arr[@]+...} guard.
  for f in ${TMPFILES[@]+"${TMPFILES[@]}"}; do
    [[ -n "$f" ]] && rm -f "$f"
  done
  rm -rf "$TMPDIR_RUN"
}
trap cleanup_tmpfiles EXIT

mktempfile() {
  mktemp "${TMPDIR_RUN}/tmp.XXXXXX"
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
# Queries ComponentReference in each direction and joins component metadata.
# Max ids per ComponentMetadata OR query.
REF_ID_BATCH=100

related_fail() {
  local stage="$1" err="$2"
  log_activity "component-search" "fail" "$RESPONSE_CODE" \
    "$(jq -cn --arg id "$RELATED_TO" --arg stage "$stage" --arg err "${err:0:500}" \
       '{mode:"related-to", related_to:$id, stage:$stage, error:$err}')"
}

# Appends one metadata line to $2 per id in the newline list $1.
lookup_metadata() {
  local ids_nl="$1" out="$2" strict="${3:-}"
  local ids=() id
  while IFS= read -r id; do [[ -n "$id" ]] && ids+=("$id"); done <<< "$ids_nl"
  [[ ${#ids[@]} -eq 0 ]] && return 0

  if [[ -n "$BRANCH_ID" ]]; then
    local xml_file root skipped=0 last_code=""
    xml_file=$(mktempfile)
    for id in "${ids[@]}"; do
      boomi_api --out-file "$xml_file" -X GET "$(build_api_url "Component/${id}~${BRANCH_ID}" false)" \
        -H "Accept: application/xml"
      case "$RESPONSE_CODE" in 401|429|5*) return 1 ;; esac
      root=""
      [[ "$RESPONSE_CODE" == "200" ]] && root=$({ grep -o '<bns:Component [^>]*>' "$xml_file" || true; } | head -n1)
      if [[ -z "$root" ]]; then
        [[ "$strict" == strict ]] && return 1
        skipped=$((skipped + 1)); last_code="$RESPONSE_CODE"; continue
      fi
      jq -cn --arg id "$id" \
        --arg name "$(tag_attr name "$root")" --arg type "$(tag_attr type "$root")" \
        --arg folder "$(tag_attr folderName "$root")" --arg ver "$(tag_attr version "$root")" \
        --arg del "$(tag_attr deleted "$root")" \
        '{componentId:$id, name:$name, type:$type, folderName:$folder,
          version:($ver | tonumber? // null), deleted:($del == "true")}' >> "$out"
    done
    if [[ "$skipped" -gt 0 ]]; then
      echo "WARN: ${skipped} component(s) unreadable on branch ${BRANCH} (last HTTP ${last_code}); names omitted." >&2
    fi
    return 0
  fi

  local pages i expr body
  pages=$(mktempfile)
  for ((i = 0; i < ${#ids[@]}; i += REF_ID_BATCH)); do
    expr=$(printf '%s\n' "${ids[@]:i:REF_ID_BATCH}" | jq -R -s -c '
      split("\n") | map(select(length > 0) | {operator:"EQUALS", property:"componentId", argument:[.]})
      | {operator:"and", nestedExpression:[
          (if length == 1 then .[0] else {operator:"or", nestedExpression:.} end),
          {operator:"EQUALS", property:"currentVersion", argument:["true"]}]}')
    body=$(jq -cn --argjson e "$expr" '{QueryFilter:{expression:$e}}')
    paginate_query "ComponentMetadata" "$body" "$pages" || return 1
  done
  jq -c '.[] | {componentId, name, type, folderName, version, deleted}' "$pages" >> "$out"
}

# Value of attr in a single start-tag string.
tag_attr() {
  { printf '%s' "$2" | grep -o " $1=\"[^\"]*\"" || true; } | head -n1 \
    | sed "s/^ $1=\"//;s/\"\$//;s/&lt;/</g;s/&gt;/>/g;s/&quot;/\"/g;s/&apos;/'/g;s/&amp;/\\&/g"
}

# Appends one ComponentReference query's rows, one per line, to $EDGES.
query_refs() {
  local relation="$1" expr="$2" pages body
  pages=$(mktempfile)
  body=$(jq -cn --argjson e "$expr" '{QueryFilter:{expression:$e}}')
  if ! paginate_query "ComponentReference" "$body" "$pages"; then
    related_fail "${relation}-query" "$RESPONSE_BODY"; return 1
  fi
  jq -c --arg rel "$relation" --arg target "$RELATED_TO" \
    '.[] | .references[]?
     | select($rel == "references" or .componentId == $target)
     | {relation:$rel, parentComponentId, parentVersion, componentId, type}' "$pages" >> "$EDGES"
}

run_related_to() {
  BRANCH_ID=""
  BRANCH="${BRANCH:-${BOOMI_DEFAULT_BRANCH_ID:-}}"
  if [[ -n "$BRANCH" ]]; then
    BRANCH_ID=$(resolve_branch_id "$BRANCH") || { related_fail "resolve-branch" "branch ${BRANCH} not found"; return 1; }
    local branch_name
    branch_name=$(resolve_branch_name "$BRANCH_ID" 2>/dev/null) && BRANCH="$branch_name"
  fi
  EDGES=$(mktempfile)
  META=$(mktempfile)

  echo "Resolving ${RELATED_TO}${BRANCH:+ on branch ${BRANCH}}..."
  if ! lookup_metadata "$RELATED_TO" "$META" strict; then
    related_fail "resolve-version" "${RESPONSE_BODY:-HTTP ${RESPONSE_CODE}}"
    echo "ERROR: could not resolve ${RELATED_TO}${BRANCH:+ on branch ${BRANCH}} (HTTP ${RESPONSE_CODE})${RESPONSE_BODY:+: ${RESPONSE_BODY:0:500}}" >&2
    return 1
  fi
  local target current_version
  target=$(jq -c --arg id "$RELATED_TO" 'select(.componentId == $id)' "$META" | head -n1)
  current_version=$(printf '%s' "$target" | jq -r '.version // empty')
  if [[ -z "$current_version" ]]; then
    related_fail "resolve-version" "component not found or has no current version"
    echo "ERROR: component ${RELATED_TO} not found or has no current version${BRANCH:+ on branch ${BRANCH}}." >&2
    return 1
  fi
  if [[ "$(printf '%s' "$target" | jq -r '.deleted')" == "true" ]]; then
    echo "WARN: ${RELATED_TO} is deleted; its current version (${current_version}) references nothing." >&2
  fi

  echo "Querying references for ${RELATED_TO} (version ${current_version})..."
  query_refs references "$(jq -cn --arg v "$RELATED_TO" --arg ver "$current_version" '
    {operator:"and", nestedExpression:[
      {operator:"EQUALS", property:"parentComponentId", argument:[$v]},
      {operator:"EQUALS", property:"parentVersion", argument:[$ver]}]}')" || return 1
  query_refs referenced-by "$(jq -cn --arg v "$RELATED_TO" --arg b "$BRANCH_ID" '
    {operator:"EQUALS", property:"componentId", argument:[$v]} as $c
    | if $b == "" then $c
      else {operator:"and", nestedExpression:[$c, {operator:"EQUALS", property:"branchId", argument:[$b]}]} end')" || return 1

  if ! lookup_metadata "$(jq -r 'if .relation == "references" then .componentId else .parentComponentId end' "$EDGES" | sort -u)" "$META"; then
    echo "WARN: component metadata lookup stopped (HTTP ${RESPONSE_CODE}); remaining names omitted." >&2
  fi

  local out_tmp="${out_file}.tmp"
  TMPFILES+=("$out_tmp")
  jq -n \
    --arg ts "$timestamp" \
    --arg related_to "$RELATED_TO" \
    --arg ver "$current_version" \
    --arg branch "$BRANCH" \
    --arg branch_id "$BRANCH_ID" \
    --slurpfile edges "$EDGES" \
    --slurpfile meta "$META" \
    '(reduce $meta[] as $m ({}; .[$m.componentId] //= ($m | del(.componentId)))) as $by_id
    | {
      metadata: {
        timestamp: $ts,
        query: "related-to",
        filters: {
          relatedTo: $related_to,
          resolvedVersion: ($ver | tonumber),
          branch: (if $branch == "" then null else {name: $branch, id: $branch_id} end)
        },
        target: $by_id[$related_to]
      },
      records: (
        $edges
        | sort_by(.relation != "references")
        | map(. + {related: $by_id[if .relation == "references" then .componentId else .parentComponentId end]})
      )
    }' > "$out_tmp"
  mv "$out_tmp" "$out_file"

  local count refs_n by_n
  count=$(jq '.records | length' "$out_file")
  refs_n=$(jq '[.records[] | select(.relation == "references")] | length' "$out_file")
  by_n=$(jq '[.records[] | select(.relation == "referenced-by")] | length' "$out_file")

  log_activity "component-search" "success" "$RESPONSE_CODE" \
    "$(jq -cn --arg id "$RELATED_TO" --arg ver "$current_version" --arg branch "$BRANCH" --argjson c "$count" \
       '{mode:"related-to", related_to:$id, resolved_version:($ver | tonumber), branch:$branch, records:$c}')"

  echo "Found ${count} reference(s) (references: ${refs_n}, referenced-by: ${by_n}) → ${out_file}"
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
