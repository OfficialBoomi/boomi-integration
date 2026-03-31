#!/usr/bin/env bash
# Branch and merge operations for Boomi platform
# Usage: bash scripts/boomi-branch.sh <command> [options]
#
# Commands:
#   list                              List all branches
#   create --name NAME --parent NAME  Create a branch from parent
#   delete --branch NAME_OR_ID        Delete a branch
#   merge --source NAME --dest NAME   Create merge request (default strategy: OVERRIDE, priority: SOURCE)
#   merge-status --id ID              Check merge request status
#   merge-execute --id ID             Execute a merge (action: MERGE)
#   merge-revert --id ID              Revert a completed merge
#   merge-delete --id ID              Cancel a pending merge request

source "$(dirname "$0")/boomi-common.sh"
load_env
require_env BOOMI_API_URL BOOMI_USERNAME BOOMI_API_TOKEN BOOMI_ACCOUNT_ID
require_tools curl jq

COMMAND="${1:-}"
shift 2>/dev/null || true

case "$COMMAND" in

# --- list ---
list)
  url="$(build_api_url "Branch/query")"
  boomi_api -X POST "$url" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -d '{"QueryFilter":{}}'

  if [[ "$RESPONSE_CODE" != "200" ]]; then
    echo "ERROR: Failed to list branches (HTTP ${RESPONSE_CODE}): ${RESPONSE_BODY}" >&2
    exit 1
  fi

  echo "$RESPONSE_BODY" | jq -r '.result[]? | "\(.name)\t\(.id)\t\(.stage)\tparent=\(.parentName // "none")"' | column -t -s $'\t'
  log_activity "branch-list" "success" "$RESPONSE_CODE" '{}'
  ;;

# --- create ---
create)
  BRANCH_NAME=""
  PARENT=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name)   BRANCH_NAME="$2"; shift 2 ;;
      --parent) PARENT="$2"; shift 2 ;;
      *)        echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done

  if [[ -z "$BRANCH_NAME" || -z "$PARENT" ]]; then
    echo "Usage: bash scripts/boomi-branch.sh create --name NAME --parent NAME_OR_ID" >&2
    exit 1
  fi

  parent_id=$(resolve_branch_id "$PARENT") || exit 1

  url="$(build_api_url "Branch")"
  boomi_api -X POST "$url" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -d "{\"parentId\":\"${parent_id}\",\"name\":\"${BRANCH_NAME}\"}"

  if [[ "$RESPONSE_CODE" != "200" && "$RESPONSE_CODE" != "201" ]]; then
    echo "ERROR: Failed to create branch (HTTP ${RESPONSE_CODE}): ${RESPONSE_BODY}" >&2
    exit 1
  fi

  branch_id=$(echo "$RESPONSE_BODY" | jq -r '.id')
  ready=$(echo "$RESPONSE_BODY" | jq -r '.ready')
  echo "Branch '${BRANCH_NAME}' created (ID: ${branch_id}, ready: ${ready})"

  if [[ "$ready" != "true" ]]; then
    echo "Branch is still creating. Poll with: bash scripts/boomi-branch.sh list"
  fi

  log_activity "branch-create" "success" "$RESPONSE_CODE" \
    "$(jq -cn --arg name "$BRANCH_NAME" --arg id "$branch_id" --arg parent "$PARENT" \
       '{branch_name: $name, branch_id: $id, parent: $parent}')"
  ;;

# --- delete ---
delete)
  BRANCH=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --branch) BRANCH="$2"; shift 2 ;;
      *)        echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done

  if [[ -z "$BRANCH" ]]; then
    echo "Usage: bash scripts/boomi-branch.sh delete --branch NAME_OR_ID" >&2
    exit 1
  fi

  branch_id=$(resolve_branch_id "$BRANCH") || exit 1

  url="$(build_api_url "Branch/${branch_id}")"
  boomi_api -X DELETE "$url" -H "Accept: application/json"

  if [[ "$RESPONSE_CODE" != "200" ]]; then
    echo "ERROR: Failed to delete branch (HTTP ${RESPONSE_CODE}): ${RESPONSE_BODY}" >&2
    exit 1
  fi

  echo "Branch '${BRANCH}' deleted"
  log_activity "branch-delete" "success" "$RESPONSE_CODE" \
    "$(jq -cn --arg branch "$BRANCH" --arg id "$branch_id" '{branch: $branch, branch_id: $id}')"
  ;;

# --- merge ---
merge)
  SOURCE=""
  DEST=""
  STRATEGY="OVERRIDE"
  PRIORITY="SOURCE"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --source)   SOURCE="$2"; shift 2 ;;
      --dest)     DEST="$2"; shift 2 ;;
      --strategy) STRATEGY="$2"; shift 2 ;;
      --priority) PRIORITY="$2"; shift 2 ;;
      *)          echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done

  if [[ -z "$SOURCE" || -z "$DEST" ]]; then
    echo "Usage: bash scripts/boomi-branch.sh merge --source NAME --dest NAME [--strategy OVERRIDE|CONFLICT_RESOLVE] [--priority SOURCE|DESTINATION]" >&2
    exit 1
  fi

  source_id=$(resolve_branch_id "$SOURCE") || exit 1
  dest_id=$(resolve_branch_id "$DEST") || exit 1

  url="$(build_api_url "MergeRequest")"
  boomi_api -X POST "$url" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -d "{\"sourceBranchId\":\"${source_id}\",\"destinationBranchId\":\"${dest_id}\",\"strategy\":\"${STRATEGY}\",\"priorityBranch\":\"${PRIORITY}\"}"

  if [[ "$RESPONSE_CODE" != "200" && "$RESPONSE_CODE" != "201" ]]; then
    echo "ERROR: Failed to create merge request (HTTP ${RESPONSE_CODE}): ${RESPONSE_BODY}" >&2
    exit 1
  fi

  merge_id=$(echo "$RESPONSE_BODY" | jq -r '.id')
  stage=$(echo "$RESPONSE_BODY" | jq -r '.stage')
  echo "Merge request created (ID: ${merge_id}, stage: ${stage})"
  echo "Poll with: bash scripts/boomi-branch.sh merge-status --id ${merge_id}"

  log_activity "merge-create" "success" "$RESPONSE_CODE" \
    "$(jq -cn --arg id "$merge_id" --arg src "$SOURCE" --arg dst "$DEST" --arg strat "$STRATEGY" \
       '{merge_id: $id, source: $src, destination: $dst, strategy: $strat}')"
  ;;

# --- merge-status ---
merge-status)
  MERGE_ID=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --id) MERGE_ID="$2"; shift 2 ;;
      *)    echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done

  if [[ -z "$MERGE_ID" ]]; then
    echo "Usage: bash scripts/boomi-branch.sh merge-status --id MERGE_REQUEST_ID" >&2
    exit 1
  fi

  url="$(build_api_url "MergeRequest/${MERGE_ID}")"
  boomi_api -X GET "$url" -H "Accept: application/json"

  if [[ "$RESPONSE_CODE" != "200" ]]; then
    echo "ERROR: Failed to get merge status (HTTP ${RESPONSE_CODE}): ${RESPONSE_BODY}" >&2
    exit 1
  fi

  stage=$(echo "$RESPONSE_BODY" | jq -r '.stage')
  prev=$(echo "$RESPONSE_BODY" | jq -r '.previousStage')
  src=$(echo "$RESPONSE_BODY" | jq -r '.sourceBranchName')
  dst=$(echo "$RESPONSE_BODY" | jq -r '.destinationBranchName')
  echo "Merge ${MERGE_ID}: ${src} → ${dst} | stage: ${stage} (previous: ${prev})"

  # Show component details if available
  details=$(echo "$RESPONSE_BODY" | jq -r '.MergeRequestDetails.MergeRequestDetail // empty')
  if [[ -n "$details" ]]; then
    echo ""
    echo "Components:"
    echo "$RESPONSE_BODY" | jq -r '.MergeRequestDetails.MergeRequestDetail[]? | "  \(.componentGuid) \(.changeType) conflict=\(.conflict) resolution=\(.resolution // "pending")"'
  fi

  log_activity "merge-status" "success" "$RESPONSE_CODE" \
    "$(jq -cn --arg id "$MERGE_ID" --arg stage "$stage" '{merge_id: $id, stage: $stage}')"
  ;;

# --- merge-execute ---
merge-execute)
  MERGE_ID=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --id) MERGE_ID="$2"; shift 2 ;;
      *)    echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done

  if [[ -z "$MERGE_ID" ]]; then
    echo "Usage: bash scripts/boomi-branch.sh merge-execute --id MERGE_REQUEST_ID" >&2
    exit 1
  fi

  url="$(build_api_url "MergeRequest/execute/${MERGE_ID}")"
  boomi_api -X POST "$url" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -d "{\"id\":\"${MERGE_ID}\",\"mergeRequestAction\":\"MERGE\"}"

  if [[ "$RESPONSE_CODE" != "200" ]]; then
    echo "ERROR: Failed to execute merge (HTTP ${RESPONSE_CODE}): ${RESPONSE_BODY}" >&2
    exit 1
  fi

  stage=$(echo "$RESPONSE_BODY" | jq -r '.stage')
  echo "Merge ${MERGE_ID} executing (stage: ${stage})"

  log_activity "merge-execute" "success" "$RESPONSE_CODE" \
    "$(jq -cn --arg id "$MERGE_ID" --arg stage "$stage" '{merge_id: $id, stage: $stage}')"
  ;;

# --- merge-revert ---
merge-revert)
  MERGE_ID=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --id) MERGE_ID="$2"; shift 2 ;;
      *)    echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done

  if [[ -z "$MERGE_ID" ]]; then
    echo "Usage: bash scripts/boomi-branch.sh merge-revert --id MERGE_REQUEST_ID" >&2
    exit 1
  fi

  echo "WARNING: Merge revert is permanent and cannot be undone."

  url="$(build_api_url "MergeRequest/execute/${MERGE_ID}")"
  boomi_api -X POST "$url" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -d "{\"id\":\"${MERGE_ID}\",\"mergeRequestAction\":\"REVERT\"}"

  if [[ "$RESPONSE_CODE" != "200" ]]; then
    echo "ERROR: Failed to revert merge (HTTP ${RESPONSE_CODE}): ${RESPONSE_BODY}" >&2
    exit 1
  fi

  stage=$(echo "$RESPONSE_BODY" | jq -r '.stage')
  echo "Merge ${MERGE_ID} reverted (stage: ${stage})"

  log_activity "merge-revert" "success" "$RESPONSE_CODE" \
    "$(jq -cn --arg id "$MERGE_ID" --arg stage "$stage" '{merge_id: $id, stage: $stage}')"
  ;;

# --- merge-delete ---
merge-delete)
  MERGE_ID=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --id) MERGE_ID="$2"; shift 2 ;;
      *)    echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done

  if [[ -z "$MERGE_ID" ]]; then
    echo "Usage: bash scripts/boomi-branch.sh merge-delete --id MERGE_REQUEST_ID" >&2
    exit 1
  fi

  url="$(build_api_url "MergeRequest/${MERGE_ID}")"
  boomi_api -X DELETE "$url" -H "Accept: application/json"

  if [[ "$RESPONSE_CODE" != "200" ]]; then
    echo "ERROR: Failed to delete merge request (HTTP ${RESPONSE_CODE}): ${RESPONSE_BODY}" >&2
    exit 1
  fi

  echo "Merge request ${MERGE_ID} deleted"
  log_activity "merge-delete" "success" "$RESPONSE_CODE" \
    "$(jq -cn --arg id "$MERGE_ID" '{merge_id: $id}')"
  ;;

# --- help ---
*)
  cat <<'USAGE'
Usage: bash scripts/boomi-branch.sh <command> [options]

Branch commands:
  list                              List all branches
  create --name NAME --parent NAME  Create branch from parent (name or ID)
  delete --branch NAME_OR_ID        Delete a branch

Merge commands:
  merge --source NAME --dest NAME   Create merge request
        [--strategy OVERRIDE|CONFLICT_RESOLVE]
        [--priority SOURCE|DESTINATION]
  merge-status --id ID              Check merge request status and details
  merge-execute --id ID             Execute a pending merge
  merge-revert --id ID              Revert a completed merge (permanent)
  merge-delete --id ID              Cancel a pending merge request
USAGE
  [[ -z "$COMMAND" ]] && exit 0 || exit 1
  ;;

esac
