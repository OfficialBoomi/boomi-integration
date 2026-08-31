#!/usr/bin/env bash
# Query Boomi execution records and optionally download logs
# Usage:
#   bash scripts/boomi-execution-query.sh [--process-id <ID>] [--status <STATUS>] [--since <ISO8601>] [--limit <N>]
#   bash scripts/boomi-execution-query.sh --execution-id <ID> --logs
# With no filters, returns the 3 most recent executions across the account.

source "$(dirname "$0")/boomi-common.sh"
load_env
require_env BOOMI_API_URL BOOMI_USERNAME BOOMI_API_TOKEN BOOMI_ACCOUNT_ID
require_tools curl jq

# --- Parse args ---
PROCESS_ID=""
EXECUTION_ID=""
STATUS=""
SINCE=""
LIMIT=3
FETCH_LOGS=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --process-id)    PROCESS_ID="$2"; shift 2 ;;
    --execution-id)  EXECUTION_ID="$2"; shift 2 ;;
    --status)        STATUS="$2"; shift 2 ;;
    --since)         SINCE="$2"; shift 2 ;;
    --limit)         LIMIT="$2"; shift 2 ;;
    --logs)          FETCH_LOGS=true; shift ;;
    -*)              echo "Unknown option: $1" >&2; exit 1 ;;
    *)               echo "Unexpected argument: $1" >&2; exit 1 ;;
  esac
done

# --- Validate args ---
if [[ -n "$EXECUTION_ID" && "$FETCH_LOGS" != "true" ]]; then
  echo "ERROR: --execution-id requires --logs flag" >&2
  exit 1
fi

# --- Download logs for a specific execution ---
if [[ -n "$EXECUTION_ID" && "$FETCH_LOGS" == "true" ]]; then
  # Pre-flight: logs arrive as a zip archive.
  if ! command -v unzip &>/dev/null; then
    echo "ERROR: --logs requires 'unzip' to extract the log archive, and it was not found." >&2
    exit 1
  fi

  log_url="$(build_api_url "ProcessLog" false)"
  log_xml="<ProcessLog xmlns=\"http://api.platform.boomi.com/\" executionId=\"${EXECUTION_ID}\" logLevel=\"ALL\"/>"

  echo "Requesting logs for execution: ${EXECUTION_ID}..."

  download_url=""
  for (( j=1; j<=12; j++ )); do
    boomi_api -X POST "$log_url" \
      -H "Accept: application/xml" \
      -H "Content-Type: application/xml" \
      -d "$log_xml" \
      --max-time 120

    if [[ "$RESPONSE_CODE" == "200" || "$RESPONSE_CODE" == "201" || "$RESPONSE_CODE" == "202" ]]; then
      download_url=$(echo "$RESPONSE_BODY" | sed -n 's/.*url="\([^"]*\)".*/\1/p' | head -1)
      [[ -n "$download_url" ]] && break
    elif [[ "$RESPONSE_CODE" == "400" ]] && echo "$RESPONSE_BODY" | grep -q "is invalid"; then
      echo "  ProcessLog not ready, waiting... (${j}/12)"
      sleep 5
    else
      echo "ERROR: ProcessLog request failed (HTTP ${RESPONSE_CODE}): ${RESPONSE_BODY}" >&2
      exit 1
    fi
  done

  if [[ -z "$download_url" ]]; then
    echo "ERROR: Could not obtain log download URL" >&2
    exit 1
  fi

  echo "Downloading log archive..."
  local_zip=$(mktemp)
  log_content=""
  archive_listing=""
  archive_bytes=""
  archive_head=""
  log_file=""
  dl_code=""
  # Distinguishes "extracted a log that happens to be empty" from "never got a log".
  extract_status="not_ready"

  for (( k=1; k<=24; k++ )); do
    boomi_api --out-file "$local_zip" -X GET "$download_url" --max-time 120
    dl_code="$RESPONSE_CODE"

    if [[ "$dl_code" == "200" ]]; then
      if archive_listing=$(unzip -l "$local_zip" 2>/dev/null); then
        log_file=$(printf '%s\n' "$archive_listing" | sed -n 's/.*[[:space:]]\([^ ]*\.log\)$/\1/p' | head -1 || true)
        if [[ -z "$log_file" ]]; then
          extract_status="no_log_in_archive"
        elif log_content=$(unzip -p "$local_zip" "$log_file" 2>/dev/null); then
          extract_status="extracted"
        else
          extract_status="extract_failed"
        fi
      else
        extract_status="unreadable_archive"
        archive_bytes=$(wc -c < "$local_zip" | tr -d ' ')
        archive_head=$(head -c 120 "$local_zip" | tr -dc '[:print:]' || true)
      fi
      break
    elif [[ "$dl_code" == "202" || "$dl_code" == "204" ]]; then
      echo "  Log file not ready, waiting... (${k}/24)"
      sleep 5
    else
      extract_status="download_failed"
      break
    fi
  done

  rm -f "$local_zip"

  if [[ "$extract_status" != "extracted" ]]; then
    case "$extract_status" in
      no_log_in_archive)
        echo "ERROR: Log archive downloaded but contains no .log file — nothing to report." >&2
        echo "  Archive contents:" >&2
        printf '%s\n' "$archive_listing" | sed 's/^/    /' >&2
        ;;
      extract_failed)
        echo "ERROR: Log archive downloaded but its .log entry could not be extracted: ${log_file}" >&2
        ;;
      unreadable_archive)
        echo "ERROR: Log archive downloaded but could not be read as a zip, or held no entries." >&2
        echo "  Received ${archive_bytes} bytes, starting: ${archive_head}" >&2
        ;;
      download_failed)
        echo "ERROR: Log download failed (HTTP ${dl_code})." >&2
        ;;
      *)
        echo "ERROR: Log file still not ready after 24 attempts (last HTTP ${dl_code})." >&2
        ;;
    esac
    echo "No result file written. This is a log-retrieval failure, not an empty execution log." >&2
    exit 1
  fi

  # Save result
  feedback_dir="active-development/feedback/execution-results"
  mkdir -p "$feedback_dir"
  timestamp=$(date +%Y%m%d_%H%M%S)
  result_file="${feedback_dir}/logs_${timestamp}_${EXECUTION_ID}.json"

  escaped_logs=$(echo "${log_content:-}" | jq -Rs '.')
  cat > "$result_file" <<EOF
{
  "execution_id": "${EXECUTION_ID}",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "logs": ${escaped_logs}
}
EOF

  echo "SUCCESS: Logs saved to ${result_file}"
  if [[ -n "$log_content" ]]; then
    echo "$log_content"
  else
    echo "NOTE: Log extracted successfully and is empty — this execution produced no log entries."
  fi
  exit 0
fi

# --- Build query filter ---
# Default: last 24 hours
if [[ -z "$SINCE" ]]; then
  if date -v-1d &>/dev/null 2>&1; then
    SINCE=$(date -u -v-1d +%Y-%m-%dT%H:%M:%SZ)  # macOS
  else
    SINCE=$(date -u -d '1 day ago' +%Y-%m-%dT%H:%M:%SZ)  # GNU
  fi
fi

expressions=""

if [[ -n "$PROCESS_ID" ]]; then
  expressions="${expressions}
      <nestedExpression operator=\"EQUALS\" property=\"processId\" xsi:type=\"SimpleExpression\">
        <argument>${PROCESS_ID}</argument>
      </nestedExpression>"
fi

expressions="${expressions}
      <nestedExpression operator=\"GREATER_THAN_OR_EQUAL\" property=\"executionTime\" xsi:type=\"SimpleExpression\">
        <argument>${SINCE}</argument>
      </nestedExpression>"

if [[ -n "$STATUS" ]]; then
  expressions="${expressions}
      <nestedExpression operator=\"EQUALS\" property=\"status\" xsi:type=\"SimpleExpression\">
        <argument>${STATUS}</argument>
      </nestedExpression>"
fi

query_xml="<QueryConfig xmlns=\"http://api.platform.boomi.com/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\">
  <QueryFilter>
    <expression operator=\"and\" xsi:type=\"GroupingExpression\">${expressions}
    </expression>
  </QueryFilter>
  <QuerySort>
    <sortField fieldName=\"executionTime\" sortOrder=\"DESC\"/>
  </QuerySort>
</QueryConfig>"

# --- Execute query ---
query_url="$(build_api_url "ExecutionRecord/query" false)"

echo "Querying execution records..."
boomi_api -X POST "$query_url" \
  -H "Accept: application/json" \
  -H "Content-Type: application/xml" \
  -d "$query_xml" \
  --max-time 120

if [[ "$RESPONSE_CODE" != "200" ]]; then
  echo "ERROR: Query failed (HTTP ${RESPONSE_CODE}): ${RESPONSE_BODY}" >&2
  exit 1
fi

# --- Parse and display results ---
total=$(echo "$RESPONSE_BODY" | jq -r '.numberOfResults // 0')
echo "Found ${total} execution(s)"

# Save raw response
feedback_dir="active-development/feedback/execution-results"
mkdir -p "$feedback_dir"
timestamp=$(date +%Y%m%d_%H%M%S)
result_file="${feedback_dir}/query_${timestamp}.json"
echo "$RESPONSE_BODY" | jq '.' > "$result_file"

# Display summary (limited to --limit)
echo "$RESPONSE_BODY" | jq -r --argjson limit "$LIMIT" '
  .result[:$limit][] |
  "\(.executionTime) | \(.status) | \(.processName // "unknown") | \(.executionId) | type=\(.executionType // "?")"
'

echo ""
echo "Full results saved to ${result_file}"

# Hint for log retrieval
if [[ "$total" != "0" ]]; then
  first_id=$(echo "$RESPONSE_BODY" | jq -r '.result[0].executionId // empty')
  if [[ -n "$first_id" ]]; then
    echo "To download logs for the latest execution:"
    echo "  bash scripts/boomi-execution-query.sh --execution-id ${first_id} --logs"
  fi
fi
