# Disk V2 Connector Step

## Contents
- Purpose
- Step Configuration
- Parameters
- Examples

## Purpose

Disk V2 connector steps execute file system operations against local or network directories. Use for:
- Writing files (CREATE or UPSERT)
- Reading files (GET)
- Searching files (QUERY)
- Listing directory contents (LIST)
- Deleting files (DELETE)

## Step Configuration

```xml
<shape image="connectoraction_icon" shapetype="connectoraction"
       userlabel="{step-label}" x="0" y="0">
  <configuration>
    <connectoraction actionType="{CREATE|UPSERT|GET|QUERY|LIST|DELETE}"
        connectorType="disk-sdk"
        connectionId="{connection-component-id}"
        operationId="{operation-component-id}">
      <parameters>
        <!-- Parameter values if required by operation -->
      </parameters>
      <dynamicProperties/>
    </connectoraction>
  </configuration>
  <dragpoints>
    <dragpoint toShape="{next-shape}" x="0" y="0"/>
  </dragpoints>
</shape>
```

For operations with filter inputs (GET, QUERY, LIST), add the `parameter-profile` attribute:

```xml
<connectoraction actionType="{GET|QUERY|LIST}"
    connectorType="disk-sdk"
    connectionId="{connection-component-id}"
    operationId="{operation-component-id}"
    parameter-profile="EMBEDDED|genericparameterchooser|{operation-component-id}">
```

## Parameters

Parameters pass filter values and input IDs to the operation. Each parameter maps to an `Input` defined in the operation's `GenericOperationConfig`.

### Static Value

```xml
<parameters>
  <parametervalue elementToSetId="0" elementToSetName="{input-name}" key="0"
      usesEncryption="false" valueType="static">
    <staticparameter staticproperty="{value}"/>
  </parametervalue>
</parameters>
```

### Dynamic Value (from document property)

```xml
<parameters>
  <parametervalue elementToSetId="0" elementToSetName="{input-name}" key="0"
      usesEncryption="false" valueType="track">
    <trackparameter defaultValue="" propertyId="{property-id}"
        propertyName="{property-display-name}"/>
  </parametervalue>
</parameters>
```

## Examples

### CREATE — Write a File

Set directory and filename via Set Properties before the connector step. The document body becomes the file content.

```xml
<!-- Set Properties step before CREATE -->
<documentproperty name="Disk v2 - Directory"
    propertyId="connector.disk-sdk.directory">
  <sourcevalues>
    <parametervalue valueType="static">
      <staticparameter staticproperty="work/output"/>
    </parametervalue>
  </sourcevalues>
</documentproperty>
<documentproperty name="Disk v2 - File Name"
    propertyId="connector.disk-sdk.fileName">
  <sourcevalues>
    <parametervalue valueType="static">
      <staticparameter staticproperty="report.csv"/>
    </parametervalue>
  </sourcevalues>
</documentproperty>

<!-- CREATE connector step -->
<shape image="connectoraction_icon" shapetype="connectoraction"
       userlabel="Write Report" x="432" y="48">
  <configuration>
    <connectoraction actionType="CREATE" connectorType="disk-sdk"
        connectionId="{connection-id}" operationId="{operation-id}">
      <parameters/>
      <dynamicProperties/>
    </connectoraction>
  </configuration>
  <dragpoints>
    <dragpoint toShape="{next}" x="608" y="56"/>
  </dragpoints>
</shape>
```

### GET — Read a File by Name

The ID parameter specifies the filename to retrieve.

```xml
<shape image="connectoraction_icon" shapetype="connectoraction"
       userlabel="Read Config File" x="432" y="48">
  <configuration>
    <connectoraction actionType="GET" connectorType="disk-sdk"
        connectionId="{connection-id}" operationId="{operation-id}"
        parameter-profile="EMBEDDED|genericparameterchooser|{operation-id}">
      <parameters>
        <parametervalue elementToSetId="0" elementToSetName="ID" key="0"
            usesEncryption="false" valueType="static">
          <staticparameter staticproperty="config.json"/>
        </parametervalue>
      </parameters>
      <dynamicProperties/>
    </connectoraction>
  </configuration>
  <dragpoints>
    <dragpoint toShape="{next}" x="608" y="56"/>
  </dragpoints>
</shape>
```

### QUERY — Search Files by Wildcard

```xml
<shape image="connectoraction_icon" shapetype="connectoraction"
       userlabel="Find CSV Files" x="432" y="48">
  <configuration>
    <connectoraction actionType="QUERY" connectorType="disk-sdk"
        connectionId="{connection-id}" operationId="{operation-id}"
        parameter-profile="EMBEDDED|genericparameterchooser|{operation-id}">
      <parameters>
        <parametervalue elementToSetId="0" elementToSetName="fileName:WILDCARD" key="0"
            usesEncryption="false" valueType="static">
          <staticparameter staticproperty="*.csv"/>
        </parametervalue>
      </parameters>
      <dynamicProperties/>
    </connectoraction>
  </configuration>
  <dragpoints>
    <dragpoint toShape="{next}" x="608" y="56"/>
  </dragpoints>
</shape>
```

### LIST — List Directory Contents

```xml
<shape image="connectoraction_icon" shapetype="connectoraction"
       userlabel="List Output Dir" x="432" y="48">
  <configuration>
    <connectoraction actionType="LIST" connectorType="disk-sdk"
        connectionId="{connection-id}" operationId="{operation-id}"
        parameter-profile="EMBEDDED|genericparameterchooser|{operation-id}">
      <parameters>
        <parametervalue elementToSetId="0" elementToSetName="isDirectory:EQUALS" key="0"
            usesEncryption="false" valueType="static">
          <staticparameter staticproperty="false"/>
        </parametervalue>
      </parameters>
      <dynamicProperties/>
    </connectoraction>
  </configuration>
  <dragpoints>
    <dragpoint toShape="{next}" x="608" y="56"/>
  </dragpoints>
</shape>
```
