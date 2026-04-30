#!/usr/bin/env bash
# Fetch Shared Web Server info for a runtime (apiType, default-port URL,
# default-port auth, runtime-wide minAuth floor). Use this for routing decisions
# (basic|intermediate → bare WSS listener; advanced → API Service Component) and
# as supplementary info — NOT as the authoritative description of the listener's
# auth. SharedServerInformation only describes the default port. Multi-port
# runtimes, and ports configured with cert/custom/gateway/external-provider auth,
# are not fully represented here. The user's .env declarations
# (SERVER_AUTH_TYPE, SERVER_BASE_URL, etc.) are the authoritative source.
#
# Usage: bash scripts/boomi-shared-server-info.sh [<atom-id>]
#   Defaults to $BOOMI_TEST_ATOM_ID when <atom-id> is omitted.

source "$(dirname "$0")/boomi-common.sh"
load_env
require_env BOOMI_API_URL BOOMI_USERNAME BOOMI_API_TOKEN BOOMI_ACCOUNT_ID
require_tools curl jq

ATOM_ID="${1:-${BOOMI_TEST_ATOM_ID:-}}"
if [[ -z "$ATOM_ID" ]]; then
  echo "Usage: bash scripts/boomi-shared-server-info.sh [<atom-id>]" >&2
  echo "No atom id provided and BOOMI_TEST_ATOM_ID is unset in .env." >&2
  exit 1
fi

url="$(build_api_url "SharedServerInformation/${ATOM_ID}" false)"
boomi_api -X GET "$url" -H "Accept: application/json"

if [[ "$RESPONSE_CODE" != "200" ]]; then
  echo "ERROR: SharedServerInformation lookup failed (HTTP ${RESPONSE_CODE})" >&2
  echo "$RESPONSE_BODY" >&2
  exit 1
fi

# `auth` is omitted from the response when the default port's auth type falls
# outside the API's `none|basic` enum (i.e. cert, cert-header, custom, external
# provider, or gateway). Surface that explicitly so absence isn't read as
# "couldn't fetch."
auth_display="$(echo "$RESPONSE_BODY" | jq -r '
  if .auth then .auth
  else "(not reported — default port uses cert/custom/gateway/external-provider; ask the user)"
  end')"

echo "$RESPONSE_BODY" | jq -r --arg auth_display "$auth_display" '
  "atomId:  " + (.atomId // "-"),
  "apiType: " + (.apiType // "-"),
  "url:     " + (.url // "-") + "    (default port; other ports may exist with different auth)",
  "auth:    " + $auth_display,
  "minAuth: " + (.minAuth // "-") + "    (floor across all ports)"
'
