# Event Streams Consume Operation Component

Component type: `connector-action`
SubType: `officialboomi-X3979C-events-prod`

## Contents
- XML Structure
- Configuration Fields
- Operation Attributes
- Key Differences from Listen Operation

## XML Structure

```xml
<bns:Component componentId=""
               name="[Operation_Name]"
               type="connector-action"
               subType="officialboomi-X3979C-events-prod"
               folderId="[folder_guid]">
  <bns:encryptedValues/>
  <bns:object>
    <Operation returnApplicationErrors="false" trackResponse="true">
      <Archiving directory="" enabled="false"/>
      <Configuration>
        <GenericOperationConfig customOperationType="CONSUME" 
                                operationType="EXECUTE" 
                                requestProfileType="none" 
                                responseProfileType="binary">
          <field id="topic" type="string" value="[topic_name]"/>
          <field id="subscription" type="string" value="[subscription_name]"/>
          <field id="acknowledgeLater" type="boolean" value="false"/>
          <field id="acknowledgementTimeout" type="integer" value=""/>
          <field id="subscriptionType" type="string" value="Shared"/>
          <field id="maxMessages" type="integer" value="10"/>
          <field id="timeout" type="integer" value="5000"/>
          <field id="consumeFromDeadLetter" type="boolean" value="false"/>
          <Options/>
        </GenericOperationConfig>
      </Configuration>
      <Tracking>
        <TrackedFields/>
      </Tracking>
      <Caching/>
    </Operation>
  </bns:object>
</bns:Component>
```

## Configuration Fields

| Field | Type | Example | Notes |
|-------|------|---------|-------|
| topic | string | "my-topic" | Topic name configured in Event Streams |
| subscription | string | "my-subscription" | Subscription name configured in Event Streams |
| acknowledgeLater | boolean | false | When `true`, acknowledgement is deferred until the process succeeds; if it fails or never acks, the message returns to the backlog for later re-consumption. When `false`, the message is acked on receipt — it is removed even if the process then fails. A Consume consumer has **no** `maxRetries` and does **not** dead-letter (dead-lettering is Listen-only — see `platform_entities/event_streams.md`) |
| acknowledgementTimeout | integer | (empty) | Intended as the client-side ack window when `acknowledgeLater` is true, but it does **not** control redelivery for the on-demand Consume pattern: an unacked message is redelivered on a platform-determined interval of ~1–2 minutes regardless of this value. Don't use it to tune retry timing; for prompt, deterministic reprocessing ack explicitly (`acknowledgeLater=false`) or design around the ~1–2 min floor |
| subscriptionType | string | "Shared" | |
| maxMessages | integer | 10 | Maximum messages to consume |
| timeout | integer | 5000 | Timeout in milliseconds |
| consumeFromDeadLetter | boolean | false | When `true`, reads from the subscription's DLQ instead of its main backlog — the basis of the reprocessing pattern |

## Operation Attributes

| Attribute | Value | Notes |
|-----------|-------|-------|
| customOperationType | "CONSUME" | |
| operationType | "EXECUTE" | Standard execute operation |
| requestProfileType | "none" | No request profile |
| responseProfileType | "binary" | Messages received as binary |
| returnApplicationErrors | false | |
| trackResponse | true | |

## Key Differences from Listen Operation

- **Placement**: Can be used as either Start step or mid-process connector step
- **Behavior**: Pulls messages on demand rather than continuous listening
- **Configuration**: Includes `maxMessages` and `timeout` for batch control

## Consuming the Dead-Letter Queue

Setting `consumeFromDeadLetter="true"` makes the Consume operation read from the subscription's dead-letter queue instead of its main backlog. This is the only programmatic way to reprocess dead-lettered messages — there is no separate reprocessing API.

- A dead-lettered message is removed from the DLQ only when it is acknowledged (successfully consumed).
- The DLQ is per-subscription, so the operation's `subscription` field determines which DLQ is consumed.

Typical reprocessing flow: consume from the DLQ → inspect/transform → Produce back to the original topic. Guard against poison-message loops with an application-level attempt cap and a separate quarantine topic. See `platform_entities/event_streams.md` for the full DLQ model and how messages reach the DLQ.