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
| acknowledgeLater | boolean | false | |
| acknowledgementTimeout | integer | (empty) | Can be left empty |
| subscriptionType | string | "Shared" | |
| maxMessages | integer | 10 | Maximum messages to consume |
| timeout | integer | 5000 | Timeout in milliseconds |
| consumeFromDeadLetter | boolean | false | |

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