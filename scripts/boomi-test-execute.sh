#!/usr/bin/env bash
# Execute a Boomi process test and poll for results
# Usage: bash scripts/boomi-test-execute.sh --process-id <ID> [--test-data FILE] [--no-wait]

source "$(dirname "$0")/boomi-common.sh"
load_env
require_env BOOMI_API_URL BOOMI_USERNAME BOOMI_API_TOKEN BOOMI_ACCOUNT_ID
require_tools curl jq

# --- Parse args ---
PROCESS_ID=""
TEST_DATA=""
NO_WAIT=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --process-id) PROCESS_ID="$2"; shift 2 ;;
    --test-data)  TEST_DATA="$2"; shift 2 ;;
    --no-wait)    NO_WAIT=true; shift ;;
    -*)           echo "Unknown option: $1" >&2; exit 1 ;;
    *)            echo "Unexpected argument: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$PROCESS_ID" ]]; then
  echo "Usage: bash scripts/boomi-test-execute.sh --process-id <ID> [--test-data FILE] [--no-wait]" >&2
  exit 1
fi

# --- Resolve atom ID ---
atom_id="${BOOMI_TEST_ATOM_ID:-}"
if [[ -z "$atom_id" ]]; then
  echo "ERROR: No atom ID configured. Set BOOMI_TEST_ATOM_ID in .env" >&2
  exit 1
fi

# --- Prepare test data ---
encoded_content=""
content_type=""
if [[ -n "$TEST_DATA" ]]; then
  if [[ ! -f "$TEST_DATA" ]]; then
    echo "ERROR: Test data file not found: ${TEST_DATA}" >&2
    exit 1
  fi

  encoded_content=$(base64 < "$TEST_DATA")

  case "${TEST_DATA##*.}" in
    json) content_type="application/json" ;;
    xml)  content_type="application/xml" ;;
    csv)  content_type="text/csv" ;;
    *)    content_type="text/plain" ;;
  esac
fi

# --- Execute process ---
url="$(build_api_url "ExecutionRequest")"

if [[ -n "$encoded_content" ]]; then
  exec_xml="<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<ExecutionRequest processId=\"${PROCESS_ID}\" atomId=\"${atom_id}\" xmlns=\"http://api.platform.boomi.com/\">
    <ProcessProperties>
        <ProcessProperty componentId=\"${PROCESS_ID}\">
            <ProcessPropertyValue key=\"testData\" value=\"${encoded_content}\"/>
            <ProcessPropertyValue key=\"contentType\" value=\"${content_type}\"/>
        </ProcessProperty>
    </ProcessProperties>
</ExecutionRequest>"
else
  exec_xml="<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<ExecutionRequest processId=\"${PROCESS_ID}\" atomId=\"${atom_id}\" xmlns=\"http://api.platform.boomi.com/\"/>"
fi

echo "Executing test for process ${PROCESS_ID} on atom ${atom_id}"

boomi_api -X POST "$url" \
  -H "Accept: application/xml" \
  -H "Content-Type: application/xml" \
  -d "$exec_xml"

if [[ "$RESPONSE_CODE" != "200" && "$RESPONSE_CODE" != "201" ]]; then
  log_activity "test-execute" "fail" "$RESPONSE_CODE" \
    "$(jq -cn --arg pid "$PROCESS_ID" --arg atom "$atom_id" \
       --arg err "${RESPONSE_BODY:0:500}" \
       '{process_id: $pid, atom_id: $atom, error: $err}')"
  echo "ERROR: Execution failed (HTTP ${RESPONSE_CODE}): ${RESPONSE_BODY}" >&2
  exit 0
fi

request_id=$(echo "$RESPONSE_BODY" | xml_attr "requestId")
if [[ -z "$request_id" ]]; then
  echo "ERROR: No requestId in response" >&2
  exit 0
fi

echo "Execution started: requestId=${request_id}"

if $NO_WAIT; then
  log_activity "test-execute" "success" "$RESPONSE_CODE" \
    "$(jq -cn --arg pid "$PROCESS_ID" --arg atom "$atom_id" \
       --arg rid "$request_id" \
       '{process_id: $pid, atom_id: $atom, request_id: $rid, waited: false}')"
  echo "SUCCESS: Test submitted (requestId: ${request_id})"
  exit 0
fi

# --- Poll for completion ---
poll_url="$(build_api_url "ExecutionRecord/async/${request_id}" false)"
max_attempts=120
poll_interval=5

echo "Polling for results..."

execution_xml=""
for (( i=1; i<=max_attempts; i++ )); do
  boomi_api -X GET "$poll_url" -H "Accept: application/xml" --max-time 120

  if [[ "$RESPONSE_CODE" == "200" ]]; then
    poll_status=$(echo "$RESPONSE_BODY" | sed -n 's/.*<bns:status>\([^<]*\)<\/bns:status>.*/\1/p' | head -1)
    if [[ "$poll_status" == "INPROCESS" || "$poll_status" == "STARTED" ]]; then
      echo "  Execution in progress... (${i}/${max_attempts})"
      sleep "$poll_interval"
    else
      execution_xml="$RESPONSE_BODY"
      break
    fi
  elif [[ "$RESPONSE_CODE" == "202" ]]; then
    echo "  Still processing... (${i}/${max_attempts})"
    sleep "$poll_interval"
  else
    echo "ERROR: Polling failed (HTTP ${RESPONSE_CODE}): ${RESPONSE_BODY}" >&2
    exit 0
  fi
done

if [[ -z "$execution_xml" ]]; then
  echo "ERROR: Polling timed out after ${max_attempts} attempts" >&2
  exit 0
fi

# --- Parse execution record (sed — no grep -P, works on macOS) ---
execution_id=$(echo "$execution_xml" | sed -n 's/.*<bns:executionId>\([^<]*\)<\/bns:executionId>.*/\1/p' | head -1)
status=$(echo "$execution_xml" | sed -n 's/.*<bns:status>\([^<]*\)<\/bns:status>.*/\1/p' | head -1)
[[ -z "$execution_id" ]] && execution_id="unknown"
[[ -z "$status" ]] && status="unknown"

echo "Execution completed: status=${status}, executionId=${execution_id}"

# --- Save result ---
feedback_dir="active-development/feedback/execution-results"
mkdir -p "$feedback_dir"

timestamp=$(date +%Y%m%d_%H%M%S)
result_file="${feedback_dir}/execution_${timestamp}_${request_id}.json"

escaped_xml=$(echo "$execution_xml" | jq -Rs '.')

cat > "$result_file" <<EOF
{
  "request_id": "${request_id}",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "execution_record": {
    "execution_id": "${execution_id}",
    "status": "${status}",
    "raw_xml": ${escaped_xml}
  }
}
EOF

log_activity "test-execute" "success" "200" \
  "$(jq -cn --arg pid "$PROCESS_ID" --arg atom "$atom_id" \
     --arg rid "$request_id" --arg eid "$execution_id" --arg st "$status" \
     '{process_id: $pid, atom_id: $atom, request_id: $rid, execution_id: $eid, status: $st, waited: true}')"

echo ""
echo "Test execution completed:"
echo "- Status: ${status}"
echo "- Execution ID: ${execution_id}"
echo "- Result saved to: ${result_file}"
echo ""
echo "Retrieve logs:"
echo "  bash scripts/boomi-execution-query.sh --execution-id ${execution_id} --logs"
