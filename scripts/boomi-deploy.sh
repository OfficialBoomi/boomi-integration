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

# --- Detect branch and warn ---
xml_branch=$(detect_xml_branch "$FILE_PATH")
sync_branch=$(read_sync_branch "$FILE_PATH" 2>/dev/null || true)
effective_branch="${xml_branch:-${sync_branch:-}}"

# --- Step 1: Package the component ---
# Uses the two-step pattern: PackagedComponent → DeployedPackage
# This ensures deterministic branch control (branchName on DeployedPackage is silently ignored).
notes="${DEPLOY_NOTES:-Deployment at $(date -u +%Y-%m-%dT%H:%M:%SZ)}"
package_version="deploy-$(date +%s)"

# Resolve branch ID to human-readable name for PackagedComponent (which requires branchName, not branchId)
branch_name=""
if [[ -n "$effective_branch" ]]; then
  branch_name=$(resolve_branch_name "$effective_branch") || {
    echo "ERROR: Could not resolve branch name for '${effective_branch}'" >&2
    exit 1
  }
  if [[ "$branch_name" != "main" ]]; then
    echo "WARNING: This component is from a non-main branch (${branch_name})."
    echo "Deploying will replace any existing deployment of this process in environment ${env_id}. If this is unexpected STOP and consult the user to discuss"
  fi
  echo "Packaging '${COMPONENT_NAME}' (${component_id}) from branch ${branch_name}"
else
  echo "Packaging '${COMPONENT_NAME}' (${component_id}) from main"
fi

# Build PackagedComponent JSON — include branchName only if non-main
pkg_json=$(jq -cn \
  --arg cid "$component_id" \
  --arg ver "$package_version" \
  --arg notes "$notes" \
  --arg branch "$branch_name" \
  'if $branch == "" then
    {componentId: $cid, packageVersion: $ver, notes: $notes}
  else
    {componentId: $cid, packageVersion: $ver, notes: $notes, branchName: $branch}
  end')

pkg_url="$(build_api_url "PackagedComponent")"
boomi_api -X POST "$pkg_url" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -d "$pkg_json"

if [[ "$RESPONSE_CODE" != "200" && "$RESPONSE_CODE" != "201" ]]; then
  log_activity "deploy-package" "fail" "$RESPONSE_CODE" \
    "$(jq -cn --arg name "$COMPONENT_NAME" --arg id "$component_id" \
       --arg err "${RESPONSE_BODY:0:500}" \
       '{component_name: $name, component_id: $id, error: $err}')"
  echo "ERROR: Packaging failed (HTTP ${RESPONSE_CODE}): ${RESPONSE_BODY}" >&2
  exit 0
fi

package_id=$(echo "$RESPONSE_BODY" | jq -r '.packageId // empty')
if [[ -z "$package_id" ]]; then
  echo "ERROR: No packageId in PackagedComponent response" >&2
  exit 0
fi

echo "Packaged as ${package_id}"

# --- Step 2: Deploy the package ---
echo "Deploying to environment ${env_id}"

deploy_url="$(build_api_url "DeployedPackage")"
deploy_json=$(jq -cn \
  --arg pid "$package_id" \
  --arg eid "$env_id" \
  --arg notes "$notes" \
  '{packageId: $pid, environmentId: $eid, notes: $notes}')

boomi_api --max-time "${BOOMI_DEPLOY_TIMEOUT:-120}" \
  -X POST "$deploy_url" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -d "$deploy_json"

# Duplicate = prior attempt succeeded
if [[ "$RESPONSE_CODE" == "400" ]] && echo "$RESPONSE_BODY" | grep -qi "duplicate"; then
  log_activity "deploy" "success" "$RESPONSE_CODE" \
    "$(jq -cn --arg name "$COMPONENT_NAME" --arg id "$component_id" \
       --arg env "$env_id" --arg pkg "$package_id" \
       '{component_name: $name, component_id: $id, environment_id: $env, package_id: $pkg, duplicate: true}')"
  echo "Prior deployment succeeded (duplicate request detected)"
  echo "SUCCESS: Package ${package_id}"
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
     --arg env "$env_id" --arg pkg "$package_id" --arg branch "${branch_name:-main}" \
     '{component_name: $name, component_id: $id, environment_id: $env, package_id: $pkg, branch: $branch}')"
echo "SUCCESS: Deployed '${COMPONENT_NAME}' (package: ${package_id})"
