#!/usr/bin/env bash
# Remove Boomi deployments from a runtime environment
# Usage: bash scripts/boomi-undeploy.sh <deploymentId>
#        bash scripts/boomi-undeploy.sh --by-component <file_path>

source "$(dirname "$0")/boomi-common.sh"
load_env
require_env BOOMI_API_URL BOOMI_USERNAME BOOMI_API_TOKEN BOOMI_ACCOUNT_ID
require_tools curl jq

# --- Parse args ---
DEPLOYMENT_ID=""
BY_COMPONENT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --by-component)  BY_COMPONENT="$2"; shift 2 ;;
    -*)              echo "Unknown option: $1" >&2; exit 1 ;;
    *)               DEPLOYMENT_ID="$1"; shift ;;
  esac
done

# --- Resolve environment ID ---
env_id="${BOOMI_ENVIRONMENT_ID:-${BOOMI_DEPLOYMENT_ENVIRONMENT_ID:-}}"
if [[ -z "$env_id" ]]; then
  echo "ERROR: No environment configured. Set BOOMI_ENVIRONMENT_ID in .env" >&2
  exit 1
fi

# --- Undeploy by component file ---
if [[ -n "$BY_COMPONENT" ]]; then
  if [[ ! -f "$BY_COMPONENT" ]]; then
    echo "ERROR: File not found: ${BY_COMPONENT}" >&2
    exit 1
  fi

  component_id=$(read_component_id "$BY_COMPONENT" 2>/dev/null || true)
  if [[ -z "$component_id" ]]; then
    component_id=$(xml_attr "componentId" < "$BY_COMPONENT")
    if [[ -n "$component_id" ]]; then
      echo "No sync state — using componentId from XML: ${component_id}"
    else
      echo "ERROR: No component ID found. Create or pull the component first." >&2
      exit 1
    fi
  fi

  component_name="$(basename "$BY_COMPONENT" .xml)"
  echo "Looking up active deployment for '${component_name}' (${component_id})..."

  query_body=$(jq -n \
    --arg envId "$env_id" \
    --arg compId "$component_id" \
    '{QueryFilter:{expression:{operator:"and",nestedExpression:[
      {property:"environmentId",operator:"EQUALS",argument:[$envId]},
      {property:"active",operator:"EQUALS",argument:["true"]},
      {property:"componentId",operator:"EQUALS",argument:[$compId]}
    ]}}}')

  url="$(build_api_url "DeployedPackage/query")"

  boomi_api -X POST "$url" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -d "$query_body"

  if [[ "$RESPONSE_CODE" != "200" ]]; then
    echo "ERROR: Query failed (HTTP ${RESPONSE_CODE}): ${RESPONSE_BODY}" >&2
    exit 1
  fi

  count=$(echo "$RESPONSE_BODY" | jq '.numberOfResults // 0')

  if [[ "$count" -eq 0 ]]; then
    echo "ERROR: No active deployment found for '${component_name}' in this environment" >&2
    exit 1
  fi

  DEPLOYMENT_ID=$(echo "$RESPONSE_BODY" | jq -r '.result[0].deploymentId')
  echo "Found deployment: ${DEPLOYMENT_ID}"
fi

# --- Undeploy by deployment ID ---
if [[ -z "$DEPLOYMENT_ID" ]]; then
  echo "Usage:" >&2
  echo "  bash scripts/boomi-undeploy.sh <deploymentId>" >&2
  echo "  bash scripts/boomi-undeploy.sh --by-component <file_path>" >&2
  exit 1
fi

url="$(build_api_url "DeployedPackage/${DEPLOYMENT_ID}")"
echo "Undeploying ${DEPLOYMENT_ID} from environment ${env_id}..."

boomi_api -X DELETE "$url" -H "Accept: application/json"

if [[ "$RESPONSE_CODE" != "200" ]]; then
  log_activity "undeploy" "fail" "$RESPONSE_CODE" \
    "$(jq -cn --arg dep "$DEPLOYMENT_ID" --arg env "$env_id" \
       --arg err "${RESPONSE_BODY:0:500}" \
       '{deployment_id: $dep, environment_id: $env, error: $err}')"
  echo "ERROR: Undeploy failed (HTTP ${RESPONSE_CODE}): ${RESPONSE_BODY}" >&2
  exit 1
fi

log_activity "undeploy" "success" "$RESPONSE_CODE" \
  "$(jq -cn --arg dep "$DEPLOYMENT_ID" --arg env "$env_id" \
     '{deployment_id: $dep, environment_id: $env}')"
echo "SUCCESS: Deployment ${DEPLOYMENT_ID} removed from environment ${env_id}"
