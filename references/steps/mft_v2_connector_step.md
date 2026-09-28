# Boomi Managed File Transfer Connector Step

## Contents
- Purpose
- Step Configuration
- Start Step Usage
- Get: ID Parameter
- List: File ID Filter
- Create: Per-Document File Name
- Concurrency

## Purpose

Connector steps for the Boomi Managed File Transfer connector (`officialboomi-X3979C-manage-prod`). Use for:
- Listing files on an MFT flow endpoint (List)
- Downloading files from MFT (Get)
- Uploading files to MFT (Create)

For the legacy connector (`thru-8SHH0W-thrumf-technology`), see `mft_connector_step.md`.

## Step Configuration

```xml
<shape image="connectoraction_icon" name="shape3" shapetype="connectoraction" userlabel="{step-label}" x="0" y="0">
  <configuration>
    <connectoraction actionType="Create"
        allowDynamicCredentials="NONE"
        connectionId="{connection-component-id}"
        connectorType="officialboomi-X3979C-manage-prod"
        hideSettings="false"
        operationId="{operation-component-id}">
      <parameters/>
      <dynamicProperties/>
    </connectoraction>
  </configuration>
  <dragpoints>
    <dragpoint name="shape3.dragpoint1" toShape="{next-shape}" x="0" y="0"/>
  </dragpoints>
</shape>
```

`actionType` is `List`, `Get`, or `Create`. List steps carry `parameter-profile="EMBEDDED|genericparameterchooser|{operation-component-id}"`; Create steps do not.

## Start Step Usage

List can be the process Start shape — the same `connectoraction` sits inside `<shape image="start" shapetype="start">`:

```xml
<shape image="start" name="shape1" shapetype="start" userlabel="" x="96.0" y="94.0">
  <configuration>
    <connectoraction actionType="List" allowDynamicCredentials="NONE"
        connectionId="{connection-component-id}"
        connectorType="officialboomi-X3979C-manage-prod" hideSettings="false"
        operationId="{operation-component-id}"
        parameter-profile="EMBEDDED|genericparameterchooser|{operation-component-id}">
      <parameters/>
      <dynamicProperties/>
    </connectoraction>
  </configuration>
  <dragpoints>
    <dragpoint name="shape1.dragpoint1" toShape="shape2" x="304.0" y="104.0"/>
  </dragpoints>
</shape>
```

For List → Get, the List must be File Metadata (see `mft_v2_connector_operation_component.md` § List).

## Get: ID Parameter

Set the ID from the List document's `fileId` tracked property:

```xml
<connectoraction actionType="Get" allowDynamicCredentials="NONE"
    connectionId="{connection-component-id}"
    connectorType="officialboomi-X3979C-manage-prod" hideSettings="false"
    operationId="{operation-component-id}"
    parameter-profile="EMBEDDED|genericparameterchooser|{operation-component-id}">
  <parameters>
    <parametervalue elementToSetId="0" elementToSetName="ID" key="0" usesEncryption="false" valueType="track">
      <trackparameter defaultValue="" propertyId="connector.officialboomi-X3979C-manage-prod.fileId"
          propertyName="officialboomi-X3979C-manage-prod - fileId"/>
    </parametervalue>
  </parameters>
  <dynamicProperties/>
</connectoraction>
```

The ID parameter is required on every Get step (see `mft_v2_connector_operation_component.md` § Get).

## List: File ID Filter

With the File ID filter defined on the operation (see `mft_v2_connector_operation_component.md`):

```xml
<parameters>
  <parametervalue elementToSetId="0" elementToSetName="fileId:EQUALS" key="0" usesEncryption="false" valueType="static">
    <staticparameter staticproperty="{file-id}"/>
  </parametervalue>
</parameters>
```

## Create: Per-Document File Name

Set a Dynamic Document Property upstream (Set Properties step), then bind the `fileName` field override to it. `key` is the operation field id:

```xml
<connectoraction actionType="Create" allowDynamicCredentials="NONE"
    connectionId="{connection-component-id}"
    connectorType="officialboomi-X3979C-manage-prod" hideSettings="false"
    operationId="{operation-component-id}">
  <parameters/>
  <dynamicProperties>
    <propertyvalue childKey="" key="fileName" name="File Name" valueType="track">
      <trackparameter defaultValue="" propertyId="dynamicdocument.DDP_FILENAME"
          propertyName="Dynamic Document Property - DDP_FILENAME"/>
    </propertyvalue>
  </dynamicProperties>
</connectoraction>
```

The override takes priority over the operation's static `fileName`.

## Concurrency

- One Get downloads one file at a time; there is no concurrent-download setting. For parallel downloads, put a Flow Control step (parallel processing, threads) between List and Get so each thread runs its own Get (see `flow_control_step.md`).
- Only one process should read a given flow endpoint. A second process lists the same files and downloads them again. Attach the schedule to a single runtime.
