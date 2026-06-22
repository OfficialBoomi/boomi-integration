#!/usr/bin/env bash
# List component version history via ComponentMetadata/query
# Usage: bash scripts/boomi-version-history.sh --component-id <ID> [--branch NAME] [--current]

source "$(dirname "$0")/boomi-common.sh"
load_env
require_env BOOMI_API_URL BOOMI_USERNAME BOOMI_API_TOKEN BOOMI_ACCOUNT_ID
require_tools curl jq

# --- Parse args ---
COMPONENT_ID=""
BRANCH=""
CURRENT_ONLY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --component-id) COMPONENT_ID="$2"; shift 2 ;;
    --branch)       BRANCH="$2"; shift 2 ;;
    --current)      CURRENT_ONLY=true; shift ;;
    -*)             echo "Unknown option: $1" >&2; exit 1 ;;
    *)              echo "Unexpected argument: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$COMPONENT_ID" ]]; then
  echo "Usage: bash scripts/boomi-version-history.sh --component-id <ID> [--branch NAME] [--current]" >&2
  exit 1
fi

# Strip any tilde suffix if present
COMPONENT_ID="${COMPONENT_ID%%~*}"

# --- Build query filter (JSON) ---
# Base filter: componentId
filter=$(jq -cn --arg cid "$COMPONENT_ID" '{
  operator: "EQUALS",
  property: "componentId",
  argument: [$cid]
}')

# Add optional filters via AND grouping
extra_filters=()

if [[ -n "$BRANCH" ]]; then
  extra_filters+=("$(jq -cn --arg b "$BRANCH" '{
    operator: "EQUALS",
    property: "branchName",
    argument: [$b]
  }')")
fi

if $CURRENT_ONLY; then
  extra_filters+=("$(jq -cn '{
    operator: "EQUALS",
    property: "currentVersion",
    argument: ["true"]
  }')")
fi

# Combine filters
if [[ ${#extra_filters[@]} -gt 0 ]]; then
  nested="[$filter"
  for ef in "${extra_filters[@]}"; do
    nested+=",${ef}"
  done
  nested+="]"
  filter=$(jq -cn --argjson nested "$nested" '{
    operator: "and",
    nestedExpression: $nested
  }')
fi

query_json=$(jq -cn --argjson expr "$filter" '{ QueryFilter: { expression: $expr } }')

# --- Execute query ---
query_url="$(build_api_url "ComponentMetadata/query" false)"

echo "Querying version history for component ${COMPONENT_ID}..."
boomi_api -X POST "$query_url" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -d "$query_json"

if [[ "$RESPONSE_CODE" != "200" ]]; then
  log_activity "version-history" "fail" "$RESPONSE_CODE" \
    "$(jq -cn --arg id "$COMPONENT_ID" --arg err "${RESPONSE_BODY:0:500}" \
       '{component_id: $id, error: $err}')"
  echo "ERROR: Query failed (HTTP ${RESPONSE_CODE}): ${RESPONSE_BODY}" >&2
  exit 1
fi

# Accumulate results across pages
all_results="$RESPONSE_BODY"
total=$(echo "$RESPONSE_BODY" | jq -r '.numberOfResults // 0')
query_token=$(echo "$RESPONSE_BODY" | jq -r '.queryToken // empty')

while [[ -n "$query_token" ]]; do
  more_url="$(build_api_url "ComponentMetadata/queryMore" false)"
  boomi_api -X POST "$more_url" \
    -H "Accept: application/json" \
    -H "Content-Type: text/plain" \
    -d "$query_token"

  if [[ "$RESPONSE_CODE" != "200" ]]; then
    echo "WARNING: Pagination query failed (HTTP ${RESPONSE_CODE}), showing partial results" >&2
    break
  fi

  # Merge result arrays
  page_results="$RESPONSE_BODY"
  all_results=$(jq -cn \
    --argjson a "$(echo "$all_results" | jq '.result')" \
    --argjson b "$(echo "$page_results" | jq '.result')" \
    --argjson total "$total" \
    '{ numberOfResults: $total, result: ($a + $b) }')

  query_token=$(echo "$page_results" | jq -r '.queryToken // empty')
done

# --- Display results ---
result_count=$(echo "$all_results" | jq '.result | length')
echo "Found ${result_count} version(s) (total: ${total})"
echo ""

if [[ "$result_count" == "0" ]]; then
  log_activity "version-history" "success" "$RESPONSE_CODE" \
    "$(jq -cn --arg id "$COMPONENT_ID" '{component_id: $id, versions: 0}')"
  exit 0
fi

# Print component name from first result
comp_name=$(echo "$all_results" | jq -r '.result[0].name // "unknown"')
comp_type=$(echo "$all_results" | jq -r '.result[0].type // "unknown"')
echo "Component: ${comp_name} (${comp_type})"
echo ""

# Table header and rows
printf "%-8s %-20s %-21s %-30s %-8s\n" "VERSION" "BRANCH" "MODIFIED" "MODIFIED_BY" "CURRENT"
printf "%-8s %-20s %-21s %-30s %-8s\n" "-------" "--------------------" "---------------------" "------------------------------" "-------"

echo "$all_results" | jq -r '.result[] | "\(.version)\t\(.branchName // "main")\t\(.modifiedDate)\t\(.modifiedBy)\t\(.currentVersion)"' | \
while IFS=$'\t' read -r ver branch modified modified_by current; do
  printf "%-8s %-20s %-21s %-30s %-8s\n" "$ver" "$branch" "$modified" "$modified_by" "$current"
done

log_activity "version-history" "success" "$RESPONSE_CODE" \
  "$(jq -cn --arg name "$comp_name" --arg id "$COMPONENT_ID" --argjson count "$result_count" \
     '{component_name: $name, component_id: $id, versions: $count}')"
