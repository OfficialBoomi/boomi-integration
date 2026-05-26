# Mail (IMAP) Connector Step

## Contents
- Purpose
- Step Configuration
- Parameters
- Receive as Start Step
- Examples

## Purpose

Mail (IMAP) connector steps invoke a Mail (IMAP) operation against a configured connection. Three actions:
- **Receive** — retrieve email + attachments via IMAP
- **Send** — deliver email via SMTP
- **Move** — relocate messages between mailbox folders

See `components/mail_imap_connection_component.md` and `components/mail_imap_connector_operation_component.md` for connection and operation construction. This doc covers the step (canvas shape) XML only.

## Step Configuration

```xml
<shape image="connectoraction_icon" name="{shape-name}" shapetype="connectoraction"
       userlabel="{step-label}" x="0" y="0">
  <configuration>
    <connectoraction actionType="{RECEIVE|SEND|MOVE}"
                     connectorType="mailsdk"
                     connectionId="{connection-component-id}"
                     operationId="{operation-component-id}"
                     hideSettings="false"
                     parameter-profile="{see below}">
      <parameters>
        <!-- See Parameters section -->
      </parameters>
    </connectoraction>
  </configuration>
  <dragpoints>
    <dragpoint toShape="{next-shape}" x="0" y="0"/>
  </dragpoints>
</shape>
```

### parameter-profile by Action

| Action | parameter-profile |
|--------|-------------------|
| RECEIVE (with filters) | `EMBEDDED|genericparameterchooser|{operationId}` |
| RECEIVE (no filters) | omit attribute |
| SEND | omit attribute (Send takes no step parameters) |
| MOVE | `{xml-request-profile-id}` (the GUID of the MOVE request profile referenced by the operation's `requestProfile=`) |

## Parameters

Parameters bind values to operation Inputs (RECEIVE) or to elements in the request profile (MOVE).

### RECEIVE — bind filter value (static)

```xml
<parameters>
  <parametervalue elementToSetId="1" elementToSetName="fromFolder" key="0"
                  valueType="static">
    <staticparameter staticproperty="INBOX/Reports"/>
  </parametervalue>
</parameters>
```

### RECEIVE — bind filter value (from document property)

```xml
<parameters>
  <parametervalue elementToSetId="2" elementToSetName="subject" key="1"
                  valueType="track">
    <trackparameter defaultValue=""
                    propertyId="dynamicdocument.SubjectFilter"
                    propertyName="Dynamic Document Property - SubjectFilter"/>
  </parametervalue>
</parameters>
```

`elementToSetId` and `key` come from the operation's `<Input key="N">` and the corresponding `<ConnectorFilterExpression key="N">`. `elementToSetName` is the filter field name.

The platform also accepts `name="<filterName>"` in place of `key="N"` on `parametervalue`. Both deploy and execute identically — the authoritative binding is `elementToSetId`/`elementToSetName`. Pick one form and stay consistent within a process.

### MOVE — bind Message ID into the request profile

```xml
<parameters>
  <parametervalue elementToSetId="6" elementToSetName="id (DeleteProfileConfig/id)" key="0"
                  valueType="track">
    <trackparameter defaultValue=""
                    propertyId="connector.mailsdk.messageId"
                    propertyName="Mail (IMAP) - Message ID"/>
  </parametervalue>
</parameters>
```

`elementToSetId` references the XML element key inside the request profile (the `<XMLElement key="N">` value for the `id` element). This value is **profile-specific** — whatever key the platform assigned to the `id` element when the XML profile was created. Open the XML profile XML and read the `key="..."` attribute on the `id` `<XMLElement>` to find the correct value. `elementToSetName` is the human-readable element path.

## Receive as Start Step

A Receive can drive a process as a listener / scheduled poller — the `connectoraction` element is embedded directly in the start shape's `<configuration>` instead of a separate connector shape. Use a descriptive `userlabel` so the shape's purpose is visible on the canvas (the start shape renders with the standard Start icon regardless of the embedded connector).

```xml
<shape image="start" name="shape1" shapetype="start" userlabel="Poll incoming mail" x="48" y="48">
  <configuration>
    <connectoraction actionType="RECEIVE"
                     connectorType="mailsdk"
                     connectionId="{connection-id}"
                     operationId="{receive-operation-id}"
                     hideSettings="false"
                     parameter-profile="EMBEDDED|genericparameterchooser|{operation-id}">
      <parameters>
        <parametervalue elementToSetId="1" elementToSetName="fromFolder" name="fromFolder"
                        valueType="static">
          <staticparameter staticproperty="New Incidents"/>
        </parametervalue>
      </parameters>
    </connectoraction>
  </configuration>
  <dragpoints>
    <dragpoint toShape="{next}" x="0" y="0"/>
  </dragpoints>
</shape>
```

## Examples

### RECEIVE — pull unread email and process attachments

```xml
<shape image="connectoraction_icon" name="shape2" shapetype="connectoraction"
       userlabel="Receive email" x="160" y="48">
  <configuration>
    <connectoraction actionType="RECEIVE" connectorType="mailsdk"
                     connectionId="{conn-id}" operationId="{recv-op-id}"
                     hideSettings="false"
                     parameter-profile="EMBEDDED|genericparameterchooser|{recv-op-id}">
      <parameters>
        <parametervalue elementToSetId="1" elementToSetName="fromFolder" key="0"
                        valueType="static">
          <staticparameter staticproperty="INBOX"/>
        </parametervalue>
      </parameters>
    </connectoraction>
  </configuration>
  <dragpoints>
    <dragpoint toShape="{cache-retrieve-shape}" x="0" y="0"/>
  </dragpoints>
</shape>
```

### SEND — single email with body

```xml
<shape image="connectoraction_icon" name="shape6" shapetype="connectoraction"
       userlabel="Send notification" x="816" y="160">
  <configuration>
    <connectoraction actionType="SEND" connectorType="mailsdk"
                     connectionId="{conn-id}" operationId="{send-op-id}"
                     hideSettings="false">
      <parameters/>
    </connectoraction>
  </configuration>
  <dragpoints>
    <dragpoint toShape="{stop-shape}" x="0" y="0"/>
  </dragpoints>
</shape>
```

### MOVE — archive after processing

```xml
<shape image="connectoraction_icon" name="shape3" shapetype="connectoraction"
       userlabel="Archive message" x="832" y="208">
  <configuration>
    <connectoraction actionType="MOVE" connectorType="mailsdk"
                     connectionId="{conn-id}" operationId="{move-op-id}"
                     hideSettings="false"
                     parameter-profile="{move-request-profile-id}">
      <parameters>
        <parametervalue elementToSetId="6" elementToSetName="id (DeleteProfileConfig/id)" key="0"
                        valueType="track">
          <trackparameter defaultValue=""
                          propertyId="connector.mailsdk.messageId"
                          propertyName="Mail (IMAP) - Message ID"/>
        </parametervalue>
      </parameters>
    </connectoraction>
  </configuration>
  <dragpoints>
    <dragpoint toShape="{stop-shape}" x="0" y="0"/>
  </dragpoints>
</shape>
```
