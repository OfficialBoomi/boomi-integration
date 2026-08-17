#!/usr/bin/env bash
# Event Streams setup: topics, subscriptions, and tokens via GraphQL
# Usage: bash scripts/event-streams-setup.sh <command> [args]
#   Commands: query-tokens, create-token <name> [consume] [produce], provision-connection <name> <token-name> <folder-id>,
#             create-topic <name>, create-subscription <topic> <name>, list-topics,
#             query-topic <name>, rest-produce <topic> <payload> [token-name]

source "$(dirname "$0")/boomi-common.sh"
load_env
require_env BOOMI_API_URL BOOMI_USERNAME BOOMI_API_TOKEN BOOMI_ACCOUNT_ID BOOMI_ENVIRONMENT_ID
require_tools curl jq

# --- JWT auth for GraphQL ---
get_jwt() {
  local ssl_flag=""
  [[ "${BOOMI_VERIFY_SSL:-true}" == "false" ]] && ssl_flag="-k"

  curl_cfg user "BOOMI_TOKEN.${BOOMI_USERNAME}:${BOOMI_API_TOKEN}" \
    | curl -s $ssl_flag \
        --max-time 30 \
        -A "$BOOMI_USER_AGENT" \
        -K - \
        "${BOOMI_API_URL}/auth/jwt/generate/${BOOMI_ACCOUNT_ID}"
}

graphql() {
  local query="$1"
  local variables="${2:-null}"
  local jwt
  jwt=$(get_jwt)

  local ssl_flag=""
  [[ "${BOOMI_VERIFY_SSL:-true}" == "false" ]] && ssl_flag="-k"

  local payload
  payload=$(jq -n --arg q "$query" --argjson v "$variables" '{query: $q, variables: $v}')

  curl_cfg header "Authorization: Bearer ${jwt}" \
    | curl -s $ssl_flag \
        --max-time 30 \
        -A "$BOOMI_USER_AGENT" \
        -K - \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "${BOOMI_API_URL}/graphql"
}

# --- Commands ---

query_tokens() {
  graphql '{
    environments {
      id name
      eventStreams {
        region
        tokens { id name allowConsume allowProduce expirationTime createdTime description }
      }
    }
  }' | jq .
}

create_token() {
  local name="$1"
  local consume="${2:-true}"
  local produce="${3:-true}"
  local expiry
  expiry=$(jq -nr 'now + (365*86400) | strftime("%Y-%m-%dT00:00:00.000Z")')
  local vars
  vars=$(jq -n --arg eid "$BOOMI_ENVIRONMENT_ID" --arg name "$name" --arg exp "$expiry" \
    --argjson consume "$consume" --argjson produce "$produce" \
    '{input: {environmentId: $eid, name: $name, allowConsume: $consume, allowProduce: $produce, expirationTime: $exp, description: ""}}')

  graphql 'mutation($input: EventStreamsEnvironmentTokenCreateInput!) {
    eventStreamsTokenCreate(input: $input) {
      id name allowConsume allowProduce expirationTime createdTime
    }
  }' "$vars" | jq .
}

create_topic() {
  local name="$1"
  local vars
  vars=$(jq -n --arg eid "$BOOMI_ENVIRONMENT_ID" --arg name "$name" \
    '{input: {environmentId: $eid, name: $name, description: ""}}')

  graphql 'mutation($input: EventStreamsTopicCreateInput!) {
    eventStreamsTopicCreate(input: $input) {
      name description createdBy createdTime
    }
  }' "$vars" | jq .
}

create_subscription() {
  local topic="$1"
  local name="$2"
  local vars
  vars=$(jq -n --arg eid "$BOOMI_ENVIRONMENT_ID" --arg topic "$topic" --arg name "$name" \
    '{input: {environmentId: $eid, topicName: $topic, name: $name, description: ""}}')

  graphql 'mutation($input: EventStreamsSubscriptionCreateInput!) {
    eventStreamsSubscriptionCreate(input: $input) {
      name type durable createdTime
    }
  }' "$vars" | jq .
}

provision_connection() {
  local conn_name="$1"
  local token_name="$2"
  local folder_id="$3"
  local script_dir
  script_dir="$(dirname "$0")"

  # Fetch token value by name (never printed)
  local result
  result=$(graphql '{
    environments {
      id eventStreams {
        tokens { name data }
      }
    }
  }')

  local token_data
  token_data=$(echo "$result" | jq -r --arg name "$token_name" --arg eid "$BOOMI_ENVIRONMENT_ID" \
    '[.data.environments[] | select(.id == $eid) | .eventStreams.tokens[]? | select(.name == $name) | .data] | first // empty')

  if [[ -z "$token_data" ]]; then
    echo "ERROR: No token found with name '${token_name}'" >&2
    return 1
  fi

  # Build connection XML in temp file
  local tmpfile
  tmpfile=$(mktemp)
  trap 'rm -f "$tmpfile"' RETURN

  cat > "$tmpfile" <<XMLEOF
<?xml version="1.0" encoding="UTF-8"?><bns:Component xmlns:bns="http://api.platform.boomi.com/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" componentId="" name="${conn_name}" type="connector-settings" subType="officialboomi-X3979C-events-prod" folderId="${folder_id}"><bns:encryptedValues><bns:encryptedValue isSet="true" path="//GenericConnectionConfig/field[@type='password']"/></bns:encryptedValues><bns:object><GenericConnectionConfig><field id="connectionType" type="string" value="Yes"/><field id="environmentToken" type="password" value="${token_data}"/></GenericConnectionConfig></bns:object></bns:Component>
XMLEOF

  # Create on platform (encrypts the token server-side)
  echo "Creating connection '${conn_name}' with token '${token_name}'..."
  bash "${script_dir}/boomi-component-create.sh" "$tmpfile"
  local create_rc=$?
  if [[ "$create_rc" -ne 0 ]]; then
    echo "ERROR: Failed to create connection on platform" >&2
    return 1
  fi

  # Extract component ID from the created file
  local component_id
  component_id=$(awk 'match($0, /componentId="[^"]*"/) { print substr($0, RSTART+13, RLENGTH-14); exit }' "$tmpfile")
  if [[ -z "$component_id" ]]; then
    echo "ERROR: Could not extract component ID after create" >&2
    return 1
  fi

  # Pull back the encrypted version into the workspace
  echo "Pulling encrypted connection back to workspace..."
  bash "${script_dir}/boomi-component-pull.sh" --component-id "$component_id"
}

list_topics() {
  graphql 'query($environmentId: ID!) {
    eventStreamsTopics(environmentId: $environmentId) { name description }
  }' "$(jq -n --arg eid "$BOOMI_ENVIRONMENT_ID" '{environmentId: $eid}')" | jq .
}

rest_produce() {
  local topic="$1"
  local payload="$2"
  local token_name="${3:-}"

  local url
  url=$(graphql 'query($eid: ID!, $name: ID!) {
    eventStreamsTopic(environmentId: $eid, name: $name) { restProduceSingleMsgUrl }
  }' "$(jq -n --arg eid "$BOOMI_ENVIRONMENT_ID" --arg name "$topic" \
    '{eid: $eid, name: $name}')" | jq -r '.data.eventStreamsTopic.restProduceSingleMsgUrl // empty')

  [[ -z "$url" ]] && { echo "ERROR: Could not get REST URL for topic '${topic}'" >&2; return 1; }

  local token_data
  if [[ -n "$token_name" ]]; then
    token_data=$(graphql '{
      environments { id eventStreams { tokens { name data } } }
    }' | jq -r --arg eid "$BOOMI_ENVIRONMENT_ID" --arg name "$token_name" \
      '[.data.environments[] | select(.id == $eid) | .eventStreams.tokens[]? | select(.name == $name) | .data] | first // empty')
    [[ -z "$token_data" ]] && { echo "ERROR: No token found with name '${token_name}'" >&2; return 1; }
  else
    token_data=$(graphql '{
      environments { id eventStreams { tokens { data allowProduce } } }
    }' | jq -r --arg eid "$BOOMI_ENVIRONMENT_ID" \
      '[.data.environments[] | select(.id == $eid) | .eventStreams.tokens[]? | select(.allowProduce == true) | .data] | first // empty')
    [[ -z "$token_data" ]] && { echo "ERROR: No produce-enabled token found for this environment" >&2; return 1; }
  fi

  curl_cfg header "Authorization: Bearer ${token_data}" \
    | curl -s --max-time 30 \
        -A "$BOOMI_USER_AGENT" \
        -K - \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$url"
  echo
}

query_topic() {
  local name="$1"
  local vars
  vars=$(jq -n --arg eid "$BOOMI_ENVIRONMENT_ID" --arg name "$name" \
    '{environmentId: $eid, name: $name}')

  graphql 'query($environmentId: ID!, $name: ID!) {
    eventStreamsTopic(environmentId: $environmentId, name: $name) {
      name description
      restProduceUrl restProduceSingleMsgUrl
      subscriptions { name type durable }
    }
  }' "$vars" | jq .
}

# --- Main ---
command="${1:-}"
rc=0

case "$command" in
  query-tokens)
    query_tokens || rc=$? ;;
  create-token)
    [[ -z "${2:-}" ]] && { echo "Usage: create-token <name> [allowConsume] [allowProduce]" >&2; exit 1; }
    create_token "$2" "${3:-true}" "${4:-true}" || rc=$? ;;
  provision-connection)
    [[ -z "${2:-}" || -z "${3:-}" || -z "${4:-}" ]] && { echo "Usage: provision-connection <connection-name> <token-name> <folder-id>" >&2; exit 1; }
    provision_connection "$2" "$3" "$4" || rc=$? ;;
  create-topic)
    [[ -z "${2:-}" ]] && { echo "Usage: create-topic <name>" >&2; exit 1; }
    create_topic "$2" || rc=$? ;;
  create-subscription)
    [[ -z "${2:-}" || -z "${3:-}" ]] && { echo "Usage: create-subscription <topic> <name>" >&2; exit 1; }
    create_subscription "$2" "$3" || rc=$? ;;
  list-topics)
    list_topics || rc=$? ;;
  query-topic)
    [[ -z "${2:-}" ]] && { echo "Usage: query-topic <name>" >&2; exit 1; }
    query_topic "$2" || rc=$? ;;
  rest-produce)
    [[ -z "${2:-}" || -z "${3:-}" ]] && { echo "Usage: rest-produce <topic> <payload> [token-name]" >&2; exit 1; }
    rest_produce "$2" "$3" "${4:-}" || rc=$? ;;
  *)
    echo "Usage: bash scripts/event-streams-setup.sh <command> [args]"
    echo "Commands:"
    echo "  query-tokens                        List environment tokens"
    echo "  create-token <name> [consume] [produce]  Create token (permissions default true)"
    echo "  provision-connection <name> <token> <folder-id>"
    echo "                                       Create connection on platform and pull back encrypted"
    echo "  create-topic <name>                  Create topic"
    echo "  create-subscription <topic> <name>   Create subscription"
    echo "  list-topics                          List all topics"
    echo "  query-topic <name>                   Query topic details"
    echo "  rest-produce <topic> <payload> [token]  Produce via REST (optional token name)"
    exit 1 ;;
esac

if [[ "$rc" -ne 0 ]]; then
  log_activity "event-streams-${command}" "fail" "" \
    "$(jq -cn --arg cmd "$command" '{command: $cmd}')"
  exit "$rc"
fi

log_activity "event-streams-${command}" "success" "" \
  "$(jq -cn --arg cmd "$command" '{command: $cmd}')"
