# Event Streams Platform Reference

## Contents
- Overview
- Architecture
- CLI Tool
- Topic REST Produce API
- Topic and Subscription Configuration
- Integration Patterns
- Operation Comparison
- Operation Selection Guide
- Platform Behavior
- Known Constraints
- Dead-Letter Queues
- GraphQL API Reference
- URL Reference

## Overview

Event Streams is Boomi's cloud-based message queuing and streaming service. Topics and subscriptions are configured via the Event Streams GUI or GraphQL API, while Integration processes interact through connector components.

## Architecture

```
Event Streams Setup:
├── Topics (configured in Event Streams GUI)
├── Subscriptions (configured in Event Streams GUI)
└── Integration Components:
    ├── Connection (environmentToken authentication)
    └── Operations:
        ├── Listen (Start step only, continuous)
        ├── Consume (Start or Connector step, pull-based)
        └── Produce (Connector step only, publishing)
```

## CLI Tool

Infrastructure management via `<skill-path>/scripts/event-streams-setup.sh`:

```bash
# Query existing environment tokens
bash <skill-path>/scripts/event-streams-setup.sh query-tokens

# Create environment token (defaults: allowConsume=true, allowProduce=true)
bash <skill-path>/scripts/event-streams-setup.sh create-token "MyToken"
# Create produce-only token
bash <skill-path>/scripts/event-streams-setup.sh create-token "ProduceOnly" false true

# Create topic
bash <skill-path>/scripts/event-streams-setup.sh create-topic "MyTopic"

# List all topics
bash <skill-path>/scripts/event-streams-setup.sh list-topics

# Query topic details (includes REST produce URLs)
bash <skill-path>/scripts/event-streams-setup.sh query-topic "MyTopic"

# Create subscription
bash <skill-path>/scripts/event-streams-setup.sh create-subscription "MyTopic" "MySubscription"

# Provision an ES connection (creates on platform, pulls back encrypted — no credential exposure)
bash <skill-path>/scripts/event-streams-setup.sh provision-connection "MyESConnection" "MyToken" "MyFolder"

# Produce a test message via REST API (uses first produce-enabled token)
bash <skill-path>/scripts/event-streams-setup.sh rest-produce "MyTopic" '{"key":"value"}'
# Produce with a specific token
bash <skill-path>/scripts/event-streams-setup.sh rest-produce "MyTopic" '{"key":"value"}' "MyToken"
```

The tool handles GraphQL authentication and API calls.

## Topic REST Produce API

Topics expose REST endpoints for producing messages without a Boomi process. Use `query-topic` to retrieve the exact URLs for a topic — no manual URL construction needed:

```bash
bash <skill-path>/scripts/event-streams-setup.sh query-topic "MyTopic"
# Response includes restProduceUrl and restProduceSingleMsgUrl
```

Authentication uses the ES environment token (Bearer token with the `data` field from token query).

For full REST API details (URL patterns, payload formats, message properties, size limits), see `references/guides/event_streams_rest_api.md`.

## Topic and Subscription Configuration

Topics and subscriptions are created/configured via Event Streams GUI.

In Boomi components, they are referenced by name:
- Topics: `<field id="topic" type="string" value="[topic_name]"/>`
- Subscriptions: `<field id="subscription" type="string" value="[subscription_name]"/>`

## Integration Patterns

### Basic Pub/Sub
```
Publisher Process:
[Start] → [Build Message] → [Produce to Topic] → [Stop]

Subscriber Process:
[Listen on Topic] → [Process Message] → [Stop]
```

### Request/Reply Pattern
```
Requester:
[Start] → [Produce to Request Topic] → [Consume from Reply Topic] → [Stop]

Responder:
[Listen on Request Topic] → [Process] → [Produce to Reply Topic] → [Stop]
```

### Batch Processing Pattern
```
Batch Process:
[Start on Schedule] → [Consume (maxMessages=100)] → [Process Batch] → [Stop]
```

## Operation Comparison

| Operation | Step Type | Behavior | Key Use Case |
|-----------|-----------|----------|--------------|
| Listen | Start only | Continuous listening | Event-driven processes |
| Consume | Start or Connector | On-demand pull | Batch processing, controlled polling |
| Produce | Connector only | Send messages | Publishing events |

## Operation Selection Guide

**When to Use Listen:**
- Process should launch automatically when messages arrive
- Event-driven architecture (react to events as they occur)
- Real-time message processing requirements
- Most common pattern for Event Streams integrations

**When to Use Consume:**
- Process runs on schedule or manual trigger, then pulls messages
- Need to retrieve messages mid-process after other operations complete
- Batch processing with controlled message retrieval (maxMessages parameter)
- On-demand message consumption rather than continuous listening

**General Pattern:** Listen is preferred for typical Event Streams pub/sub patterns. Use Consume when process flow requires performing operations before retrieving Event Streams messages.

## Platform Behavior

- Producing to a non-existent topic auto-creates it (no description or subscriptions)
- Consuming with a non-existent subscription auto-creates it (type set by the operation's `subscriptionType` field). New subscriptions start with zero backlog.
- Topic name can be overridden at runtime via `dynamicProperties` on the Produce step (key `topic`)

## Known Constraints

- All operations use binary profile types (requestProfileType/responseProfileType)
- Connection uses environment-specific encrypted token

## Dead-Letter Queues

A dead-letter queue (DLQ) holds messages a subscription's consumer repeatedly failed to process. Each subscription has its **own** DLQ — two subscriptions on the same topic dead-letter independently.

### How a message reaches the DLQ

Dead-lettering is driven entirely by the consuming **Listen** operation; there is no setting that "enables" a DLQ, and only a Listen consumer can dead-letter. (A Consume operation never dead-letters — it has no `maxRetries`, and an unacknowledged message just returns to the backlog. See `references/components/event_streams_consume_operation_component.md`.) A Listen message is dead-lettered only when **all three** hold:

- `subscriptionType="Shared"` — Exclusive and Failover retry indefinitely and never dead-letter.
- `transacted="true"` — the message is acked only on success. With `transacted="false"` it is acked on receipt, so a failure never redelivers or dead-letters.
- `maxRetries` — the redelivery ceiling.

The broker redelivers a failed/unacked message after the ack timeout; once redeliveries exceed `maxRetries` it moves the message to the DLQ. A message lands there because the **consumer kept failing**.

### Reprocessing

A message leaves the DLQ only when a consumer acks it. To reprocess, run a Consume operation with `consumeFromDeadLetter="true"` (see `references/components/event_streams_consume_operation_component.md`), which reads the DLQ instead of the main backlog. Typical pattern: consume from the DLQ → inspect/transform → Produce back to the original topic.

The DLQ records only that the consumer failed, not *why* — a message that failed because a downstream system was briefly unavailable looks identical to one that failed because its data can never be processed. So an unprocessable message will loop DLQ → reprocess → fail → DLQ forever. Cap it with an **application-level attempt counter in the payload** (separate from the broker's `maxRetries`, which the broker doesn't expose here) and route exhausted messages to a quarantine topic.

### Management surface

There is **no enable/configure/reprocess surface**: `EventStreamsSubscriptionCreateInput` (used for create and update) has no DLQ-policy fields, and no mutation reprocesses a DLQ. (`eventStreamsSubscriptionClearBacklog` clears the *main* backlog; `eventStreamsRoute*` is general topic routing.) The only reprocess path is a `consumeFromDeadLetter="true"` Consume.

**The GraphQL DLQ read surface is unreliable — don't depend on it.** `deadLetterBacklogCount`, `retryBacklogCount`, and `eventStreamsDeadLetterQueueMessages` exist but return `0`/empty even when the DLQ holds messages (the equivalent *main-queue* fields are accurate — the gap is DLQ-specific). **To inspect or count a DLQ, drain it with a `consumeFromDeadLetter="true"` Consume.** The `eventStreamsDeadLetterQueueMessageDelete` mutation exists but is not practical — it needs message IDs that only the blind list query provides.

## GraphQL API Reference

For advanced usage or automation beyond the CLI tool. Requires JWT token authentication (`GET /auth/jwt/generate/{account_id}` with Basic auth, then `POST /graphql` with Bearer token).

**Standard workflow:** Use `<skill-path>/scripts/event-streams-setup.sh` instead of manual GraphQL calls.

### Topic Operations

**Create Topic**
```graphql
mutation {
  eventStreamsTopicCreate(input: {
    environmentId: "{environment_id}"
    name: "{topic_name}"
    description: "{description}"
  }) {
    name
    createdBy
    createdTime
  }
}
```

**Delete Topic**
```graphql
mutation {
  eventStreamsTopicDelete(
    topic: {
      environmentId: "{environment_id}"
      name: "{topic_name}"
    }
  )
}
```

**Query Topic**
```graphql
{
  eventStreamsTopic(environmentId: "{environment_id}", name: "{topic_name}") {
    name
    description
    restProduceUrl
    restProduceSingleMsgUrl
    subscriptions {
      name
      type
      durable
    }
  }
}
```

Optional diagnostic fields (include only when troubleshooting): `producerCount`, `subscriptionCount`, `backlogCount`, `backlogSize`, `messageRateIn`, `messageRateOut`. Subscriptions also support `backlogCount` and `activeConsumerCount`. (A `deadLetterBacklogCount` field also exists but is unreliable — see Dead-Letter Queues → Management surface; use a `consumeFromDeadLetter="true"` Consume to inspect a DLQ instead.)

### Subscription Operations

**Create Subscription**
```graphql
mutation {
  eventStreamsSubscriptionCreate(input: {
    environmentId: "{environment_id}"
    topicName: "{topic_name}"
    name: "{subscription_name}"
    description: "{description}"
  }) {
    name
    type
    durable
  }
}
```

**Delete Subscription**
```graphql
mutation {
  eventStreamsSubscriptionDelete(
    subscription: {
      topic: {
        environmentId: "{environment_id}"
        name: "{topic_name}"
      }
      name: "{subscription_name}"
    }
  )
}
```

**Clear Subscription Backlog**
```graphql
mutation {
  eventStreamsSubscriptionClearBacklog(
    subscription: {
      topic: {
        environmentId: "{environment_id}"
        name: "{topic_name}"
      }
      name: "{subscription_name}"
    }
  )
}
```

### Environment Token Management

Environment tokens authenticate Event Streams connector operations (365-day expiration by default).

**Query Existing Tokens:**
```graphql
{
  environments {
    id
    name
    eventStreams {
      region
      tokens {
        id
        name
        data
        allowConsume
        allowProduce
        expirationTime
        createdTime
        description
      }
    }
  }
}
```

The `data` field contains the JWT token value used in Event Streams connection components.

**Create Token:**
```graphql
mutation {
  eventStreamsTokenCreate(input: {
    environmentId: "{environment_id}"
    name: "{unique_token_name}"
    allowConsume: true
    allowProduce: true
    expirationTime: "{ISO_datetime}"  # Optional, defaults to 365 days from creation
    description: "{optional_description}"
  }) {
    id
    name
    data
    allowConsume
    allowProduce
    expirationTime
  }
}
```

**Update Token:**
```graphql
mutation {
  eventStreamsTokenUpdate(input: {
    id: "{token_id}"
    name: "{updated_name}"
    allowConsume: true
    allowProduce: false
    expirationTime: "{new_expiration}"
    description: "{updated_description}"
  }) {
    id
    data
  }
}
```

**Delete Token:**
```graphql
mutation {
  eventStreamsTokenDelete(id: "{token_id}")
}
```

**Token Management Notes:**
- Token `name` must be unique within environment
- `allowConsume`/`allowProduce` control operation permissions
- `expirationEditable` indicates if expiration can be extended without recreation
- Extract `data` field value and use in connection component's `environmentToken` field
- Default token auto-created for environment has name "default"

### GraphQL Field Types

**Topic Fields**
- `environmentId`: ID (required)
- `name`: ID (required)
- `description`: String (optional)

**Subscription Fields**
- `environmentId`: ID (required)
- `topicName`: ID (required)
- `name`: ID (required)
- `description`: String (optional)

**Token Fields**
- `environmentId`: ID (required for create)
- `id`: ID (required for update/delete)
- `name`: String (required, unique within environment)
- `allowConsume`: Boolean (optional, default false)
- `allowProduce`: Boolean (optional, default false)
- `expirationTime`: DateTime (optional, defaults to 365 days)
- `description`: String (optional)

## URL Reference

REST produce URLs are per-topic and available via `query-topic` (`restProduceUrl`, `restProduceSingleMsgUrl`). See `references/guides/event_streams_rest_api.md` for URL format details and manual construction if needed.
