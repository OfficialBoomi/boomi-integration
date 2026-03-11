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
| subscriptionType | string | "Shared" | |
| transacted | boolean | false | |
| numConsumers | integer | (empty) | Can be left empty |
| ackTimeout | integer | 10 | Timeout in seconds |
| maxRetries | integer | 10 | |
| consumeFromDeadLetter | boolean | false | |

## Operation Attributes

| Attribute | Value | Notes |
|-----------|-------|-------|
| customOperationType | "LISTEN" | |
| operationType | "Listen" | |
| requestProfileType | "none" | No request profile for listen |
| responseProfileType | "binary" | Messages received as binary |
| returnApplicationErrors | false | |
| trackResponse | true | |