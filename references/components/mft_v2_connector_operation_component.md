# Boomi Managed File Transfer Connector Operation Component

Component type: `connector-action`
SubType: `officialboomi-X3979C-manage-prod`

## Contents
- Overview
- Operation Types
- Component Structure
- List
- Get
- Create
- Error Behavior
- Tracked Properties

## Overview

Operations for the Boomi Managed File Transfer connector (SDK-based, Content API). Every operation targets one MFT flow endpoint by its numeric **Flow Endpoint ID** (`flowEndpointId`), shown before the endpoint name in Flow Studio. List and Get use a Target flow endpoint; Create uses a Source flow endpoint.

Not the legacy connector (`thru-8SHH0W-thrumf-technology`) — see `mft_connector_operation_component.md` for that one. There is no flowSecret in this connector; authentication lives entirely in the connection.

## Operation Types

| Action | `customOperationType` | `operationType` | `objectTypeId` / `objectTypeName` | Request | Response |
|--------|----------------------|-----------------|-----------------------------------|---------|----------|
| List (metadata) | `List` | `QUERY` | `fileMetadata` / `File Metadata` | xml | json |
| List (with content) | `List` | `QUERY` | `file` / `File (with content)` | xml | binary |
| Get | `Get` | `GET` | `file` / `File` | xml | binary |
| Create | `Create` | `CREATE` | `file` / `File` | binary | json |

The process step's `actionType` is the `customOperationType` value (`List`, `Get`, `Create`).

## Component Structure

```xml
<bns:Component xmlns:bns="http://api.platform.boomi.com/"
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               componentId=""
               name="{operation-name}"
               type="connector-action"
               subType="officialboomi-X3979C-manage-prod"
               folderId="{folder-id}">
  <bns:encryptedValues/>
  <bns:object>
    <Operation returnApplicationErrors="false" trackResponse="true">
      <Archiving directory="" enabled="false"/>
      <Configuration>
        <GenericOperationConfig customOperationType="{List|Get|Create}" operationType="{QUERY|GET|CREATE}"
            objectTypeId="{fileMetadata|file}" objectTypeName="{object-type-name}"
            requestProfileType="{type}" responseProfileType="{type}">
          <!-- fields and Options per action, below -->
        </GenericOperationConfig>
      </Configuration>
      <Tracking><TrackedFields/></Tracking>
      <Caching/>
    </Operation>
  </bns:object>
</bns:Component>
```

## List

Returns files on the flow endpoint.

```xml
<GenericOperationConfig customOperationType="List" objectTypeId="fileMetadata" objectTypeName="File Metadata"
    operationType="QUERY" requestProfileType="xml" responseProfileType="json">
  <field id="flowEndpointId" type="integer" value="{flow-endpoint-id}"/>
  <field id="maxFiles" type="integer" value="100"/>
  <field id="fileStatus" type="string" value="Staged"/>
  <field id="shortReadRetryCount" type="integer" value="3"/>
  <Options>
    <QueryOptions>
      <Fields>
        <ConnectorObject name="File Metadata">
          <FieldList/>
          <Filter><ConnectorBaseFilter/></Filter>
          <Sorts/>
        </ConnectorObject>
      </Fields>
      <Inputs/>
    </QueryOptions>
  </Options>
</GenericOperationConfig>
```

For File (with content): `objectTypeId="file"`, `objectTypeName="File (with content)"`, `responseProfileType="binary"`, and `<ConnectorObject name="File (with content)">`.

| Field | Values | Default |
|-------|--------|---------|
| `flowEndpointId` | numeric Target flow endpoint ID | — |
| `maxFiles` | 1–1000 | 100 |
| `fileStatus` | `Staged`, `Completed`, `Error`, `All statuses` | `Staged` |
| `shortReadRetryCount` | 0–10; applies to File (with content) | 3 |

**Object type determines whether List consumes files:**
- **File Metadata** — one JSON metadata document per file. Files stay Staged.
- **File (with content)** — one document per file whose body is the raw file content. Every listed file moves to **Completed**, so it no longer appears under the default `Staged` filter. The document's `status` tracked property still reads `Staged`.

To list files and then download selected ones with Get, the List must be File Metadata.

File Metadata document body:

```json
{"fileId":"6ab4000000000000000000a1","fileName":"orders.csv","originalName":"orders.csv","fileSize":59,
 "status":"Staged","actionType":"Transfer","flowEndpointType":"Target","createdDate":"2026-01-15T10:00:00.000Z",
 "uploader":{"id":"1234","name":"user@example.com","type":"PortalUser"},"protocol":"BoomiConnector",
 "transferType":"Client","subfolderPath":"/","remoteDirectory":null,"timestamp":null,
 "context":{"flowEndpointId":10001,"flowId":2001,"endpointId":3001,"organizationId":4001,"tenantId":501,"customerId":501}}
```

Flow endpoint tags arrive in this body as `flowEndpointTags` and `sourceFlowEndpointTags`; the keys are omitted when the endpoint has no tags. They are not tracked properties.

### File ID filter

```xml
<ConnectorObject name="File Metadata">
  <FieldList/>
  <Filter>
    <ConnectorBaseFilter>
      <ConnectorFilterLogical logicalOperator="and">
        <ConnectorFilterExpression expressionField="fileId" expressionOperator="EQUALS" key="0" name="fileId:EQUALS"/>
      </ConnectorFilterLogical>
    </ConnectorBaseFilter>
  </Filter>
  <Sorts/>
</ConnectorObject>
...
<Inputs><Input key="0" name="fileId:EQUALS"/></Inputs>
```

The step supplies the value as a parameter with `elementToSetName="fileId:EQUALS"` (see `mft_v2_connector_step.md`).

## Get

Downloads the file whose file ID is supplied as the step's **ID** parameter.

```xml
<GenericOperationConfig customOperationType="Get" objectTypeId="file" objectTypeName="File"
    operationType="GET" requestProfileType="xml" responseProfileType="binary">
  <field id="flowEndpointId" type="integer" value="{flow-endpoint-id}"/>
  <field id="shortReadRetryCount" type="integer" value="3"/>
  <Options>
    <QueryOptions>
      <Fields><ConnectorObject name="File"><FieldList/></ConnectorObject></Fields>
      <Inputs><Input key="0" name="ID"/></Inputs>
    </QueryOptions>
  </Options>
</GenericOperationConfig>
```

| Field | Values | Default |
|-------|--------|---------|
| `flowEndpointId` | numeric Target flow endpoint ID | — |
| `shortReadRetryCount` | 0–10 (0 fails an interrupted download immediately) | 3 |

Set the ID parameter on every Get step:
- Mid-process with no ID parameter, the step fails the execution: `ConnectorException: Object IDs are required. To provide the ID, set ID parameters or use input documents.`
- As a Start step with no ID parameter, Get returns 0 documents and downloads nothing, even when files are Staged.

When a download finishes, the file's status changes to Completed and it drops out of `Staged` List results. If the process fails afterward, scheduled runs do not pick the file up again; re-download it by replaying the document in Process Reporting. Completed files are eligible for purge.

Get output documents do not carry the `fileName` tracked property. To use the file name downstream, carry it forward from the List document (e.g. in a Dynamic Document Property set before Get).

## Create

Uploads each document as a file to the Source flow endpoint.

```xml
<GenericOperationConfig customOperationType="Create" objectTypeId="file" objectTypeName="File"
    operationType="CREATE" requestProfileType="binary" responseProfileType="json">
  <field id="flowEndpointId" type="integer" value="{flow-endpoint-id}"/>
  <field id="subfolderPath" type="string" value=""/>
  <field id="fileName" type="string" value="{file-name}"/>
  <Options>
    <QueryOptions>
      <Fields>
        <ConnectorObject name="File">
          <FieldList>
            <ConnectorField filterable="true" name="chunksUploaded" selectable="true" selected="true" sortable="true"/>
            <ConnectorField filterable="true" name="fileId" selectable="true" selected="true" sortable="true"/>
            <ConnectorField filterable="true" name="fileName" selectable="true" selected="true" sortable="true"/>
            <ConnectorField filterable="true" name="fileSize" selectable="true" selected="true" sortable="true"/>
          </FieldList>
        </ConnectorObject>
      </Fields>
      <Inputs/>
    </QueryOptions>
  </Options>
</GenericOperationConfig>
```

GUI-created Create operations also carry `responseProfile="{profile-id}"`, a JSON profile of the response body.

| Field | Notes |
|-------|-------|
| `flowEndpointId` | numeric Source flow endpoint ID |
| `subfolderPath` | Subfolder under the flow endpoint root; blank uploads to the root. Overridable per document |
| `fileName` | Required. Overridable per document |

With a blank `fileName` and no override, the document fails: `[VALIDATION] fileName is required`. The connector does not generate names. Uploading the same name twice creates two files with distinct `fileId`s.

For per-document names, bind the field's override on the connector step to a Dynamic Document Property (see `mft_v2_connector_step.md`). The override takes priority over the operation's static `fileName`.

Response body: `{"fileName":"orders.csv","fileId":"6ab4000000000000000000b2","fileSize":1024,"chunksUploaded":1}`

## Error Behavior

With `returnApplicationErrors="true"`, a failed file in a batch produces its own document carrying its file ID and the other files are still delivered. With it `false`, one failed file stops the whole batch.

## Tracked Properties

Property IDs follow `connector.officialboomi-X3979C-manage-prod.{name}`. Each action sets a different subset:

| Action | Properties set | `meta.base.applicationstatuscode` |
|--------|----------------|-----------------------------------|
| List | `fileId`, `fileName`, `fileSize`, `createdDate`, `subfolderPath`, `protocol`, `transferType`, `flowEndpointId`, `flowId`, `endpointId`, `organizationId`, `tenantId`, `customerId`, `originalName`, `status`, `actionType`, `flowEndpointType`, `uploaderId`, `uploaderName`, `uploaderType` | 200 |
| Get | `fileId`, `fileSize`, `remoteDirectory`, `flowEndpointId` | 200 |
| Create | `fileId`, `fileName`, `fileSize`, `subfolderPath`, `flowEndpointId`, `chunksUploaded` | 201 |

`actionType` is the MFT transfer action (e.g. `Transfer`), not the connector action.
