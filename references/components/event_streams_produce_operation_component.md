# Event Streams Produce Operation Component

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
    <Operation returnApplicationErrors="false" trackResponse="false">
      <Archiving directory="" enabled="false"/>
      <Configuration>
        <GenericOperationConfig customOperationType="PRODUCE" 
                                operationType="EXECUTE" 
                                requestProfileType="binary" 
                                responseProfileType="none">
          <field id="topic" type="string" value="[topic_name]"/>
          <field id="producerAccessMode" type="string" value="Exclusive"/>
          <field id="compressionType" type="string" value="NONE"/>
          <field id="messageProperties" type="customproperties">
            <customProperties/>
          </field>
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
| producerAccessMode | string | "Exclusive" | |
| compressionType | string | "NONE" | |
| messageProperties | customproperties | (empty) | Usage TBD - leave `<customProperties/>` empty for standard use cases |

## Operation Attributes

| Attribute | Value | Notes |
|-----------|-------|-------|
| customOperationType | "PRODUCE" | |
| operationType | "EXECUTE" | |
| requestProfileType | "binary" | Document sent as binary |
| responseProfileType | "none" | No response from produce |
| returnApplicationErrors | false | |
| trackResponse | false | |