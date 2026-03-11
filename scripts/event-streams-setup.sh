#!/usr/bin/env bash
# Event Streams setup: topics, subscriptions, and tokens via GraphQL
# Usage: bash scripts/event-streams-setup.sh <command> [args]
#   Commands: query-tokens, create-token <name>, create-topic <name>,
#             create-subscription <topic> <name>, query-topic <name>

source "$(dirname "$0")/boomi-common.sh"
load_env
require_env BOOMI_API_URL BOOMI_USERNAME BOOMI_API_TOKEN BOOMI_ACCOUNT_ID BOOMI_ENVIRONMENT_ID
require_tools curl jq

# --- JWT auth for GraphQL ---
get_jwt() {
  local ssl_flag=""
  [[ "${BOOMI_VERIFY_SSL:-true}" == "false" ]] && ssl_flag="-k"

  local auth_string="BOOMI_TOKEN.${BOOMI_USERNAME}:${BOOMI_API_TOKEN}"
  local auth_b64
  # base64 -w0 (Linux) or plain base64 (macOS) — suppress line wraps
  auth_b64=$(printf '%s' "$auth_string" | base64 | tr -d '\n')

  curl -s $ssl_flag \
    --max-time 30 \
    -H "Authorization: Basic ${auth_b64}" \
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

  curl -s $ssl_flag \
    --max-time 30 \
    -H "Authorization: Bearer ${jwt}" \
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
        tokens { id name data allowConsume allowProduce expirationTime createdTime description }
      }
    }
  }' | jq .
}

create_token() {
  local name="$1"
  local vars
  vars=$(jq -n --arg eid "$BOOMI_ENVIRONMENT_ID" --arg name "$name" \
    '{input: {environmentId: $eid, name: $name, allowConsume: true, allowProduce: true, description: ""}}')

  graphql 'mutation($input: EventStreamsTokenCreateInput!) {
    eventStreamsTokenCreate(input: $input) {
      id name data allowConsume allowProduce expirationTime createdTime
    }
  }' "$vars" | jq .
}

create_topic() {
  local name="$1"
  local vars
  vars=$(jq -n --arg eid "$BOOMI_ENVIRONMENT_ID" --arg name "$name" \
    '{input: {environmentId: $eid, name: $name, description: "", partitions: 1}}')

  graphql 'mutation($input: EventStreamsTopicCreateInput!) {
    eventStreamsTopicCreate(input: $input) {
      name description partitions createdBy createdTime
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

query_topic() {
  local name="$1"
  local vars
  vars=$(jq -n --arg eid "$BOOMI_ENVIRONMENT_ID" --arg name "$name" \
    '{environmentId: $eid, name: $name}')

  graphql 'query($environmentId: ID!, $name: ID!) {
    eventStreamsTopic(environmentId: $environmentId, name: $name) {
      name description partitions
      subscriptions { name type }
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
    [[ -z "${2:-}" ]] && { echo "Usage: create-token <name>" >&2; exit 1; }
    create_token "$2" || rc=$? ;;
  create-topic)
    [[ -z "${2:-}" ]] && { echo "Usage: create-topic <name>" >&2; exit 1; }
    create_topic "$2" || rc=$? ;;
  create-subscription)
    [[ -z "${2:-}" || -z "${3:-}" ]] && { echo "Usage: create-subscription <topic> <name>" >&2; exit 1; }
    create_subscription "$2" "$3" || rc=$? ;;
  query-topic)
    [[ -z "${2:-}" ]] && { echo "Usage: query-topic <name>" >&2; exit 1; }
    query_topic "$2" || rc=$? ;;
  *)
    echo "Usage: bash scripts/event-streams-setup.sh <command> [args]"
    echo "Commands:"
    echo "  query-tokens                        List environment tokens"
    echo "  create-token <name>                  Create new token"
    echo "  create-topic <name>                  Create topic"
    echo "  create-subscription <topic> <name>   Create subscription"
    echo "  query-topic <name>                   Query topic details"
    exit 1 ;;
esac

if [[ "$rc" -ne 0 ]]; then
  log_activity "event-streams-${command}" "fail" "" \
    "$(jq -cn --arg cmd "$command" '{command: $cmd}')"
  exit "$rc"
fi

log_activity "event-streams-${command}" "success" "" \
  "$(jq -cn --arg cmd "$command" '{command: $cmd}')"
