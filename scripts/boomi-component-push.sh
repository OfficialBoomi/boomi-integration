#!/usr/bin/env bash
# Push a local component XML file to the Boomi platform (update)
# Usage: bash scripts/boomi-component-push.sh <file_path> [--branch NAME_OR_ID] [--force] [--allow-password-token] [--test-connection]

source "$(dirname "$0")/boomi-common.sh"

usage() {
  cat >&2 <<'EOF'
Usage:
  bash scripts/boomi-component-push.sh <file_path> [--branch NAME_OR_ID] [--force] [--allow-password-token]
  bash scripts/boomi-component-push.sh --test-connection

Pushes a local component XML file to the Boomi platform as an update.

Arguments:
  <file_path>            Path to the component XML file to push.

Options:
  --branch <name|id>     Target branch (name or id). Defaults to the XML's
                         branchId, then BOOMI_DEFAULT_BRANCH_ID, then the
                         account default branch.
  --account-default      Send no branch identifier, letting the platform resolve
                         the target to the account default branch. Required to
                         push unqualified once sync state records a branch, so
                         the choice is always deliberate. Drops the branchId from
                         the local file on success, so later plain pushes stay
                         unqualified. Cannot combine with --branch.
  --force                Push even when the content matches the last push
                         (skips the content-hash short-circuit). Not needed to
                         retarget the branch — that is never short-circuited.
  --allow-password-token Push a REST Client connection whose password field
                         looks like a pulled secret token (128 lowercase hex).
  --test-connection      Verify platform credentials and exit.
  -h, --help             Show this help and exit.

Side effects: creates a new component version on the platform; updates local sync state.
EOF
}

# Answer --help before load_env, which needs a workspace .env.
if wants_help "--branch" "$@"; then usage; exit 0; fi

load_env
require_env BOOMI_API_URL BOOMI_USERNAME BOOMI_API_TOKEN BOOMI_ACCOUNT_ID
require_tools curl jq

# --- Parse args ---
FILE_PATH=""
TEST_CONN=false
BRANCH=""
ACCOUNT_DEFAULT=false
FORCE=false
ALLOW_PASSWORD_TOKEN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --test-connection) TEST_CONN=true; shift ;;
    --branch)          BRANCH="$2"; shift 2 ;;
    --account-default) ACCOUNT_DEFAULT=true; shift ;;
    --force)           FORCE=true; shift ;;
    --allow-password-token) ALLOW_PASSWORD_TOKEN=true; shift ;;
    -h|--help)         usage; exit 0 ;;
    -*)                echo "Unknown option: $1" >&2; usage; exit 1 ;;
    *)                 FILE_PATH="$1"; shift ;;
  esac
done

if $TEST_CONN; then
  test_connection
  exit 0
fi

if [[ -z "$FILE_PATH" ]]; then
  echo "ERROR: missing <file_path>." >&2
  usage
  exit 1
fi

if [[ ! -f "$FILE_PATH" ]]; then
  echo "ERROR: File not found: ${FILE_PATH}" >&2
  exit 1
fi

assert_no_password_token "$FILE_PATH" "$ALLOW_PASSWORD_TOKEN"

COMPONENT_NAME="$(basename "$FILE_PATH" .xml)"

# --- Resolve component ID ---
component_id=$(read_component_id "$FILE_PATH" 2>/dev/null || true)

if [[ -z "$component_id" ]]; then
  component_id=$(xml_attr "componentId" < "$FILE_PATH")
  if [[ -n "$component_id" ]]; then
    echo "No sync state — using componentId from XML: ${component_id}"
  else
    echo "ERROR: No component ID found. Create the component first or pull from platform." >&2
    exit 1
  fi
fi

# --- Resolve branch and safety checks ---
# Resolved before the content check, which compares the target branch too.
if $ACCOUNT_DEFAULT && [[ -n "$BRANCH" ]]; then
  echo "ERROR: --account-default and --branch are mutually exclusive." >&2
  exit 1
fi

xml_branch=$(detect_xml_branch "$FILE_PATH")
sync_branch=$(read_sync_branch "$FILE_PATH" 2>/dev/null || true)
if $ACCOUNT_DEFAULT; then
  BRANCH_ID=""
else
  BRANCH_ID=$(resolve_effective_branch "$BRANCH" "$xml_branch")
fi

# Safety: sync state says branch but XML disagrees
if [[ -n "$sync_branch" && -z "$BRANCH" ]] && ! $ACCOUNT_DEFAULT; then
  if [[ -z "$xml_branch" ]]; then
    echo "ERROR: This component was pulled from branch ${sync_branch} but the XML has no branchId." >&2
    echo "Pass --branch to confirm target, --account-default to push unqualified," >&2
    echo "or re-pull from the branch." >&2
    exit 1
  elif [[ "$xml_branch" != "$sync_branch" ]]; then
    echo "ERROR: Sync state says branch ${sync_branch} but XML has branchId ${xml_branch}." >&2
    echo "Pass --branch to confirm target, --account-default to push unqualified," >&2
    echo "or re-pull from the branch." >&2
    exit 1
  fi
fi

# --- Check for changes ---
# The target branch is part of the comparison, not just the content hash.
current_hash=$(hash_file "$FILE_PATH")
sync_dir="$(pwd)/active-development/.sync-state"
state_name="$(_sync_state_name "$FILE_PATH")"

for sf in "${sync_dir}/${state_name}.json" "${sync_dir}/${COMPONENT_NAME}.json"; do
  if [[ -f "$sf" ]]; then
    last_hash=$(jq -r '.content_hash // empty' < "$sf" 2>/dev/null)
    if [[ -n "$last_hash" && "$current_hash" == "$last_hash" && "$BRANCH_ID" == "$sync_branch" ]]; then
      if $FORCE; then
        echo "Force push — skipping content hash check"
      else
        echo "Component '${COMPONENT_NAME}' matches the last push to ${sync_branch:-the account default branch} — nothing sent to the platform."
        echo "No new version was created. Re-run with --force to push anyway."
        exit 0
      fi
    fi
    break
  fi
done

# Stamp componentId onto the root so the body matches the URL ID (platform rejects a mismatch).
push_body=$(set_root_component_id "$component_id" < "$FILE_PATH")

if [[ -n "$BRANCH_ID" ]]; then
  push_body=$(inject_branch_id "$push_body" "$BRANCH_ID")
  echo "Pushing component '${COMPONENT_NAME}' (${component_id}) to branch ${BRANCH:-$BRANCH_ID}"
else
  push_body=$(strip_branch_id "$push_body")
  echo "Pushing component '${COMPONENT_NAME}' (${component_id}) to the account default branch"
fi

# --- Push to platform ---
url="$(build_api_url "Component/${component_id}")"

# Body via tempfile + --data-binary; inline -d "$body" overflows ARG_MAX (small on MinGW) on large components.
body_file="$(mktemp)"
trap 'rm -f "$body_file"' EXIT
printf '%s' "$push_body" > "$body_file"

boomi_api -X POST "$url" \
  -H "Accept: application/xml" \
  -H "Content-Type: application/xml" \
  --data-binary "@${body_file}"

# Trace off across response handling: a 4xx body can echo back a submitted password.
_xtrace_enabled=0
case $- in *x*) _xtrace_enabled=1 ;; esac
set +x

if [[ "$RESPONSE_CODE" != "200" && "$RESPONSE_CODE" != "201" && "$RESPONSE_CODE" != "204" ]]; then
  log_activity "component-push" "fail" "$RESPONSE_CODE" \
    "$(jq -cn --arg name "$COMPONENT_NAME" --arg id "$component_id" \
       --arg file "$FILE_PATH" --arg err "${RESPONSE_BODY:0:500}" \
       '{component_name: $name, component_id: $id, file_path: $file, error: $err}')"
  echo "ERROR: Push failed (HTTP ${RESPONSE_CODE}): ${RESPONSE_BODY}" >&2
  if is_invalid_component_error "$RESPONSE_BODY"; then
    diagnose_invalid_component "$component_id"
  fi
  exit 1
fi

report_response_branch "$RESPONSE_BODY" "$BRANCH_ID" "Push landed on"

# Keep the file unqualified so later plain pushes stay unqualified.
if $ACCOUNT_DEFAULT && [[ -n "$xml_branch" ]]; then
  local_xml=$(cat "$FILE_PATH")
  strip_branch_id "$local_xml" > "$FILE_PATH"
  current_hash=$(hash_file "$FILE_PATH")
  echo "Removed branchId from ${FILE_PATH} to match the unqualified push."
fi

# --- Update sync state ---
write_sync_state "$component_id" "$FILE_PATH" "$current_hash" "$BRANCH_ID"

# Read the platform-assigned version from the returned Component root element.
# Scope to the root tag so the prolog's version="1.0" isn't matched.
new_version=$(printf '%s' "$RESPONSE_BODY" | tr '\n' ' ' \
  | grep -o '<[a-zA-Z]*:\{0,1\}Component[^>]*>' | head -1 \
  | xml_attr "version" || true)

if (( _xtrace_enabled )); then set -x; fi

log_activity "component-push" "success" "$RESPONSE_CODE" \
  "$(jq -cn --arg name "$COMPONENT_NAME" --arg id "$component_id" \
     --arg file "$FILE_PATH" --arg branch "${BRANCH_ID:-account-default}" --arg ver "$new_version" \
     '{component_name: $name, component_id: $id, file_path: $file, branch: $branch, version: (if $ver == "" then null else $ver end)}')"

if [[ -n "$new_version" ]]; then
  echo "SUCCESS: Pushed component '${COMPONENT_NAME}' — now version ${new_version}"
else
  echo "SUCCESS: Pushed component '${COMPONENT_NAME}'"
fi
