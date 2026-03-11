# MFT Connector Step

## Contents
- Purpose
- Step Configuration
- Parameters
- Document Properties
- Examples

## Purpose

MFT connector steps execute file transfer operations against Boomi's Thru-powered Managed File Transfer platform. Use for:
- Picking up files from MFT flows (GET)
- Dropping off files to MFT flows (CREATE)
- Updating file processing outcomes (UPDATE)

## Step Configuration

```xml
<shape image="connectoraction_icon" shapetype="connectoraction" userlabel="{step-label}" x="0" y="0">
  <configuration>
    <connectoraction actionType="{GET|CREATE|UPDATE}"
        connectorType="thru-8SHH0W-thrumf-technology"
        connectionId="{connection-component-id}"
        operationId="{operation-component-id}"
        parameter-profile="EMBEDDED|genericparameterchooser|{operation-component-id}">
      <parameters>
        <!-- Parameter values if required by operation -->
      </parameters>
    </connectoraction>
  </configuration>
  <dragpoints>
    <dragpoint toShape="{next-shape}" x="0" y="0"/>
  </dragpoints>
</shape>
```

## Parameters

For FLOW_PICKUP operations, the ID parameter is **required** and specifies the Storage Repository from the Thru portal:

```xml
<parameters>
  <parametervalue elementToSetId="0" elementToSetName="ID" key="0" valueType="static">
    <staticparameter staticproperty="{storage-repository}"/>
  </parametervalue>
</parameters>
```

The Storage Repository value is found in the Thru portal under Flow Endpoint → Connection tab.

**Note**: DROP_OFF operations do not support the ID parameter. Omit `parameter-profile` and leave `<parameters/>` empty for CREATE steps.

For dynamic values, use `valueType="document"` or `valueType="track"`:

```xml
<parametervalue elementToSetId="0" elementToSetName="ID" key="0" valueType="track">
  <trackparameter propertyId="{property-id}" propertyName="{property-name}"/>
</parametervalue>
```

## Document Properties

### FileName (Required for DROP_OFF)

Set before the CREATE step using Set Properties:

```xml
<documentproperty name="Thru MFT — Partner Connector - FileName"
    propertyId="connector.thru-8SHH0W-thrumf-technology.fileName">
  <sourcevalues>
    <parametervalue valueType="static">
      <staticparameter staticproperty="output.txt"/>
    </parametervalue>
  </sourcevalues>
</documentproperty>
```

### Response Status (After GET)

Check file existence using Application Status Code:

```xml
<decision comparison="equals" name="FileExists?">
  <decisionvalue valueType="track">
    <trackparameter propertyId="meta.base.applicationstatuscode" propertyName="Base - Application Status Code"/>
  </decisionvalue>
  <decisionvalue valueType="static">
    <staticparameter staticproperty="200"/>
  </decisionvalue>
</decision>
```

Status codes:
- `200`: File returned
- `204`: No file available

## Examples

### File Pickup (GET)

```xml
<shape image="connectoraction_icon" shapetype="connectoraction" userlabel="Pickup from MFT" x="240" y="48">
  <configuration>
    <connectoraction actionType="GET" connectorType="thru-8SHH0W-thrumf-technology"
        connectionId="684288ad-ed41-4f47-956a-c8b648d3adc3"
        operationId="ec3080d6-6666-465c-a5cc-6b5ec545a57c"
        parameter-profile="EMBEDDED|genericparameterchooser|ec3080d6-6666-465c-a5cc-6b5ec545a57c">
      <parameters>
        <parametervalue elementToSetId="0" elementToSetName="ID" key="0" valueType="static">
          <staticparameter staticproperty="TRN001"/>
        </parametervalue>
      </parameters>
    </connectoraction>
  </configuration>
  <dragpoints>
    <dragpoint toShape="shape3" x="416" y="56"/>
  </dragpoints>
</shape>
```

### File Drop-off (CREATE)

```xml
<shape image="connectoraction_icon" shapetype="connectoraction" userlabel="Drop to MFT" x="432" y="48">
  <configuration>
    <connectoraction actionType="CREATE" connectorType="thru-8SHH0W-thrumf-technology"
        connectionId="3890198c-c63b-464d-8300-38fe154d7765"
        operationId="02080083-0801-4ed5-b151-d8ef9bacb4cb">
      <parameters/>
    </connectoraction>
  </configuration>
  <dragpoints>
    <dragpoint toShape="shape4" x="608" y="56"/>
  </dragpoints>
</shape>
```

Note: Set FileName document property before this step.

### Continuous Polling Loop (Many-to-Many)

For continuous file processing, CREATE can loop back to GET:

```xml
<!-- After CREATE completes, dragpoint loops back to GET shape -->
<shape shapetype="connectoraction" userlabel="File Drop Off" x="816" y="48">
  <configuration>
    <connectoraction actionType="CREATE" connectorType="thru-8SHH0W-thrumf-technology"
        connectionId="{connection-id}" operationId="{operation-id}">
      <parameters/>
    </connectoraction>
  </configuration>
  <dragpoints>
    <dragpoint toShape="shape-get-pickup" x="176" y="240"/>
  </dragpoints>
</shape>
```

Pattern: GET → Decision (check 200) → Set Properties → CREATE → back to GET
