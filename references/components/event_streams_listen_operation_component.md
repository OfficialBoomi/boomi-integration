# Event Streams Listen Operation Component

Component type: `connector-action`
SubType: `officialboomi-X3979C-events-prod`

## Contents
- XML Structure
- Configuration Fields
- Operation Attributes

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
        <GenericOperationConfig customOperationType="LISTEN" 
                                operationType="Listen" 
                                requestProfileType="none" 
                                responseProfileType="binary">
          <field id="topic" type="string" value="[topic_name]"/>
          <field id="subscription" type="string" value="[subscription_name]"/>
          <field id="subscriptionType" type="string" value="Shared"/>
          <field id="transacted" type="boolean" value="false"/>
          <field id="numConsumers" type="integer" value=""/>
          <field id="ackTimeout" type="integer" value="10"/>
          <field id="maxRetries" type="integer" value="10"/>
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
| subscriptionType | string | "Shared" | Must be `Shared` for dead-lettering; Exclusive/Failover retry indefinitely (see DLQ Behavior) |
| transacted | boolean | false | `true` acks only on successful completion; `false` acks on receipt so failures are never redelivered or dead-lettered (see DLQ Behavior) |
| numConsumers | integer | (empty) | Can be left empty |
| ackTimeout | integer | 10 | Timeout in seconds; on no-ack the message is redelivered after this interval |
| maxRetries | integer | 10 | Redelivery ceiling; exceeding it dead-letters the message (see DLQ Behavior) |
| consumeFromDeadLetter | boolean | false | When `true`, reads from the subscription's DLQ instead of its main backlog |

## Operation Attributes

| Attribute | Value | Notes |
|-----------|-------|-------|
| customOperationType | "LISTEN" | |
| operationType | "Listen" | |
| requestProfileType | "none" | No request profile for listen |
| responseProfileType | "binary" | Messages received as binary |
| returnApplicationErrors | false | |
| trackResponse | true | |

## Dead-Letter Queue Behavior

A Listen operation drives dead-lettering only when configured with `subscriptionType="Shared"`, `transacted="true"`, and a `maxRetries` ceiling. With those set, a message whose process fails (error, timeout, or consumer disconnect) is redelivered after `ackTimeout`; once failed redeliveries exceed `maxRetries`, the broker moves it to the subscription's dead-letter queue.

- With `transacted="false"`, the message is acknowledged on receipt — a downstream failure cannot trigger redelivery and nothing reaches the DLQ.
- Exclusive and Failover subscription types retry indefinitely and never dead-letter.

To reprocess dead-lettered messages, use a Consume operation with `consumeFromDeadLetter="true"`. See `platform_entities/event_streams.md` for the full DLQ model — per-subscription scope, the reprocess/quarantine pattern, and the management surface.