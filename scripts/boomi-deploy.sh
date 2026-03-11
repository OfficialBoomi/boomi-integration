#!/usr/bin/env bash
# Deploy a Boomi process to a runtime environment
# Usage: bash scripts/boomi-deploy.sh <file_path> [--deployment-notes NOTES] [--list-environments]

source "$(dirname "$0")/boomi-common.sh"
load_env
require_env BOOMI_API_URL BOOMI_USERNAME BOOMI_API_TOKEN BOOMI_ACCOUNT_ID
require_tools curl jq

# --- Parse args ---
FILE_PATH=""
DEPLOY_NOTES=""
LIST_ENVS=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --deployment-notes)  DEPLOY_NOTES="$2"; shift 2 ;;
    --list-environments) LIST_ENVS=true; shift ;;
    -*)                  echo "Unknown option: $1" >&2; exit 1 ;;
    *)                   FILE_PATH="$1"; shift ;;
  esac
done

# --- List environments ---
if $LIST_ENVS; then
  url="$(build_api_url "Environment")"
  echo "Listing environments..."

  boomi_api -X GET "$url" -H "Accept: application/json"

  if [[ "$RESPONSE_CODE" != "200" ]]; then
    echo "ERROR: Failed to list environments (HTTP ${RESPONSE_CODE})" >&2
    exit 0
  fi

  echo "$RESPONSE_BODY" | jq -r '.result[]? | "Environment: \(.name) (ID: \(.id))"'
  exit 0
fi

if [[ -z "$FILE_PATH" ]]; then
  echo "Usage: bash scripts/boomi-deploy.sh <file_path> [--deployment-notes NOTES]" >&2
  exit 1
fi

if [[ ! -f "$FILE_PATH" ]]; then
  echo "ERROR: File not found: ${FILE_PATH}" >&2
  exit 1
fi

COMPONENT_NAME="$(basename "$FILE_PATH" .xml)"

# --- Resolve component ID ---
component_id=$(read_component_id "$FILE_PATH" 2>/dev/null || true)

if [[ -z "$component_id" ]]; then
  component_id=$(xml_attr "componentId" < "$FILE_PATH")
  if [[ -n "$component_id" ]]; then
    echo "No sync state — using componentId from XML: ${component_id}"
  else
    echo "ERROR: No component ID found. Create or pull the component first." >&2
    exit 1
  fi
fi

# --- Resolve environment ID ---
env_id="${BOOMI_ENVIRONMENT_ID:-${BOOMI_DEPLOYMENT_ENVIRONMENT_ID:-}}"
if [[ -z "$env_id" ]]; then
  echo "ERROR: No environment configured. Set BOOMI_ENVIRONMENT_ID in .env" >&2
  exit 1
fi

# --- Deploy ---
url="$(build_api_url "DeployedPackage")"
package_name="Deploy_$(date +%s)"
notes="${DEPLOY_NOTES:-Deployment at $(date -u +%Y-%m-%dT%H:%M:%SZ)}"

deploy_xml="<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<ns0:DeployedPackage xmlns:ns0=\"http://api.platform.boomi.com/\">
    <packageName>${package_name}</packageName>
    <environmentId>${env_id}</environmentId>
    <componentId>${component_id}</componentId>
    <notes>${notes}</notes>
</ns0:DeployedPackage>"

echo "Deploying '${COMPONENT_NAME}' (${component_id}) to environment ${env_id}"

boomi_api --max-time "${BOOMI_DEPLOY_TIMEOUT:-120}" \
  -X POST "$url" \
  -H "Accept: application/xml" \
  -H "Content-Type: application/xml" \
  -d "$deploy_xml"

# Duplicate = prior attempt succeeded
if [[ "$RESPONSE_CODE" == "400" ]] && echo "$RESPONSE_BODY" | grep -qi "duplicate"; then
  log_activity "deploy" "success" "$RESPONSE_CODE" \
    "$(jq -cn --arg name "$COMPONENT_NAME" --arg id "$component_id" \
       --arg env "$env_id" --arg pkg "$package_name" \
       '{component_name: $name, component_id: $id, environment_id: $env, package_name: $pkg, duplicate: true}')"
  echo "Prior deployment succeeded (duplicate request detected)"
  echo "SUCCESS: Package ${package_name}"
  exit 0
fi

if [[ "$RESPONSE_CODE" != "200" && "$RESPONSE_CODE" != "201" ]]; then
  log_activity "deploy" "fail" "$RESPONSE_CODE" \
    "$(jq -cn --arg name "$COMPONENT_NAME" --arg id "$component_id" \
       --arg env "$env_id" --arg err "${RESPONSE_BODY:0:500}" \
       '{component_name: $name, component_id: $id, environment_id: $env, error: $err}')"
  echo "ERROR: Deployment failed (HTTP ${RESPONSE_CODE}): ${RESPONSE_BODY}" >&2
  exit 0
fi

log_activity "deploy" "success" "$RESPONSE_CODE" \
  "$(jq -cn --arg name "$COMPONENT_NAME" --arg id "$component_id" \
     --arg env "$env_id" --arg pkg "$package_name" \
     '{component_name: $name, component_id: $id, environment_id: $env, package_name: $pkg}')"
echo "SUCCESS: Deployed '${COMPONENT_NAME}' as package ${package_name}"
