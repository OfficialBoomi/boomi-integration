#!/usr/bin/env bash
# Test a WSS listener endpoint via the shared web server.
#
# Auth selection from .env:
#   SERVER_AUTH_TYPE=basic   → requires SERVER_USERNAME + SERVER_TOKEN
#   SERVER_AUTH_TYPE=bearer  → requires SERVER_BEARER_TOKEN
#   SERVER_AUTH_TYPE=none    → no auth; any creds set in .env are ignored
#   SERVER_AUTH_TYPE unset   → inferred from which creds are populated; ambiguity
#                              (e.g. Basic vars + Bearer both set, or only one of
#                              SERVER_USERNAME/SERVER_TOKEN) is a hard error.
#
# Client Certificate / mTLS and other non-Bearer custom auth schemes are out of
# scope — fall back to manual curl for those cases. See
# references/platform_entities/shared_web_server.md.
#
# Usage: bash scripts/boomi-wss-test.sh --path /ws/simple/createOrder [--method POST] [--data '{"key":"val"}' | --data file.json] [--content-type application/xml]

source "$(dirname "$0")/boomi-common.sh"
load_env
require_tools curl

# --- Parse args ---
WSS_PATH=""
DATA=""
METHOD="POST"
CONTENT_TYPE="application/json"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --path)         WSS_PATH="$2"; shift 2 ;;
    --data)         DATA="$2"; shift 2 ;;
    --method)       METHOD="$2"; shift 2 ;;
    --content-type) CONTENT_TYPE="$2"; shift 2 ;;
    -*)       echo "Unknown option: $1" >&2; exit 1 ;;
    *)        echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$WSS_PATH" ]]; then
  echo "Usage: bash scripts/boomi-wss-test.sh --path /ws/simple/createOrder [--method POST] [--data '{...}'] [--content-type application/xml]" >&2
  exit 1
fi

if [[ -z "${SERVER_BASE_URL:-}" ]]; then
  echo "ERROR: SERVER_BASE_URL must be set in .env" >&2
  exit 1
fi

# --- Resolve auth mode ---
auth_type="${SERVER_AUTH_TYPE:-}"
auth_inferred=false
basic_set=false
bearer_set=false
[[ -n "${SERVER_USERNAME:-}" || -n "${SERVER_TOKEN:-}" ]] && basic_set=true
[[ -n "${SERVER_BEARER_TOKEN:-}" ]] && bearer_set=true

if [[ -z "$auth_type" ]]; then
  # Back-compat inference. Hard-fail on any ambiguity so the user fixes .env.
  if $basic_set && $bearer_set; then
    echo "ERROR: SERVER_USERNAME/SERVER_TOKEN and SERVER_BEARER_TOKEN are both set." >&2
    echo "       Set SERVER_AUTH_TYPE=basic or SERVER_AUTH_TYPE=bearer to disambiguate," >&2
    echo "       or clear the credentials for the scheme you don't want." >&2
    exit 1
  fi
  if $basic_set; then
    if [[ -z "${SERVER_USERNAME:-}" || -z "${SERVER_TOKEN:-}" ]]; then
      echo "ERROR: Incomplete Basic credentials. Set both SERVER_USERNAME and SERVER_TOKEN, or neither." >&2
      exit 1
    fi
    auth_type="basic"
  elif $bearer_set; then
    auth_type="bearer"
  else
    auth_type="none"
  fi
  auth_inferred=true
fi

case "$auth_type" in
  basic)
    if [[ -z "${SERVER_USERNAME:-}" || -z "${SERVER_TOKEN:-}" ]]; then
      echo "ERROR: SERVER_AUTH_TYPE=basic requires SERVER_USERNAME and SERVER_TOKEN in .env" >&2
      exit 1
    fi
    ;;
  bearer)
    if [[ -z "${SERVER_BEARER_TOKEN:-}" ]]; then
      echo "ERROR: SERVER_AUTH_TYPE=bearer requires SERVER_BEARER_TOKEN in .env" >&2
      exit 1
    fi
    ;;
  none)
    ;;
  *)
    echo "ERROR: SERVER_AUTH_TYPE='${auth_type}' is invalid. Expected: basic, bearer, or none." >&2
    exit 1
    ;;
esac

ssl_flag=""
[[ "${SERVER_VERIFY_SSL:-true}" == "false" ]] && ssl_flag="-k"

# --- Build curl args ---
curl_args=($ssl_flag -s -w "\n--- HTTP %{http_code} (%{time_total}s) ---" \
  --max-time 30 -A "$BOOMI_USER_AGENT" -X "$METHOD")

case "$auth_type" in
  basic)  curl_args+=(-u "${SERVER_USERNAME}:${SERVER_TOKEN}") ;;
  bearer) curl_args+=(-H "Authorization: Bearer ${SERVER_BEARER_TOKEN}") ;;
esac

if [[ -n "$DATA" ]]; then
  if [[ -f "$DATA" ]]; then
    curl_args+=(-H "Content-Type: ${CONTENT_TYPE}" -d "@${DATA}")
  else
    curl_args+=(-H "Content-Type: ${CONTENT_TYPE}" -d "$DATA")
  fi
fi

url="${SERVER_BASE_URL}${WSS_PATH}"
banner="auth=${auth_type}"
$auth_inferred && banner="${banner} (inferred — set SERVER_AUTH_TYPE in .env to declare explicitly)"
echo "Testing: ${METHOD} ${url}  (${banner})"
curl "${curl_args[@]}" "$url" 2>/dev/null; true
echo ""
