# MFT Connector Operation Component

## Contents
- Overview
- Operation Types
- Component Structure
- GET Operations
- CREATE Operations
- UPDATE Operations

## Overview

MFT operation components define specific actions for file pickup, drop-off, and status updates. Operations use `GenericOperationConfig` and embedded profile types.

**Connector Type**: `thru-8SHH0W-thrumf-technology`

## Operation Types

| Action | Object Type | Request | Response | Purpose |
|--------|-------------|---------|----------|---------|
| GET | FLOW_PICKUP | xml | binary | Pick up file from MFT |
| GET | FILE_METADATA | - | json | Get file metadata |
| CREATE | DROP_OFF | binary | xml | Drop off file to MFT |
| UPDATE | FLOW_OUTCOME | json | xml | Update file processing status |

## Credential Organization

Each MFT flow has its own flowSecret. For bi-directional integrations:
- **Pickup flow**: Uses flowSecret from pickup flow endpoint
- **Drop-off flow**: Uses different flowSecret from drop-off flow endpoint

**flowSecret must be set in the operation config** (or via Set Properties as a document property). Connection-level flowSecret is ignored by the connector.

## Component Structure

```xml
<?xml version="1.0" encoding="UTF-8"?>
<bns:Component xmlns:bns="http://api.platform.boomi.com/"
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               componentId=""
               name="{operation-name}"
               type="connector-action"
               subType="thru-8SHH0W-thrumf-technology"
               folderId="{folder-id}">
  <bns:encryptedValues/>
  <bns:object>
    <Operation returnApplicationErrors="false" trackResponse="{true|false}">
      <Archiving directory="" enabled="false"/>
      <Configuration>
        <GenericOperationConfig objectTypeId="{object-type}" operationType="{action}"
            requestProfileType="{type}" responseProfileType="{type}">
          <!-- Operation-specific fields and options -->
        </GenericOperationConfig>
      </Configuration>
      <Tracking><TrackedFields/></Tracking>
      <Caching/>
    </Operation>
  </bns:object>
</bns:Component>
```

## GET Operations

### FLOW_PICKUP (File Pickup)

Returns binary file data with tracked FileName and FileCode properties.

```xml
<GenericOperationConfig objectTypeId="FLOW_PICKUP" operationType="GET"
    requestProfileType="xml" responseProfileType="binary">
  <field id="optionDetails" type="string" value="FILE"/>
  <field id="flowSecret" type="string" value="{flow-secret-from-mft-portal}"/>
  <Options>
    <QueryOptions>
      <Fields><ConnectorObject name="FLOW_PICKUP"><FieldList/></ConnectorObject></Fields>
      <Inputs><Input key="0" name="ID"/></Inputs>
    </QueryOptions>
  </Options>
</GenericOperationConfig>
```

**Response handling**: Check `meta.base.applicationstatuscode`:
- `200`: File returned successfully
- `204`: No file available

Set `trackResponse="true"` on Operation element to enable status code tracking.

**flowSecret**: Each operation requires its own flow-specific secret, obtained from the MFT portal Flow Endpoint configuration.

### FILE_METADATA

Returns JSON with file details for a given FileCode.

```xml
<GenericOperationConfig objectTypeId="FILE_METADATA" operationType="GET"
    requestProfileType="xml" responseProfileType="json">
  <Options>
    <QueryOptions>
      <Fields><ConnectorObject name="FILE_METADATA"><FieldList/></ConnectorObject></Fields>
      <Inputs><Input key="0" name="ID"/></Inputs>
    </QueryOptions>
  </Options>
</GenericOperationConfig>
```

**Response fields available** (21 fields): `DateCreated`, `FileCode`, `FileName`, `FileProcessingType`, `FileProcessingTypeDisplay`, `FileSize`, `FileStatus`, `FileStatusDisplay`, `FlowCode`, `FlowName`, `FlowTool`, `FlowToolDisplay`, `ParticipantCode`, `ParticipantEndpointCode`, `ParticipantEndpointName`, `ParticipantExternalCode`, `ParticipantName`, `ParticipantType`, `ParticipantTypeDisplay`, `RelatedFileCode`, `RelatedFileName`

## CREATE Operations

### DROP_OFF (File Drop-off)

Uploads binary file to MFT. Requires FileName document property and flowSecret.

```xml
<GenericOperationConfig objectTypeId="DROP_OFF" objectTypeName="DROP_OFF" operationType="CREATE"
    requestProfileType="binary" responseProfileType="xml">
  <field id="typeId" type="string" value="FILE"/>
  <field id="flowSecret" type="string" value="{flow-secret-from-mft-portal}"/>
  <Options>
    <QueryOptions>
      <Fields><ConnectorObject name="DROP_OFF"/></Fields>
      <Inputs/>
    </QueryOptions>
  </Options>
</GenericOperationConfig>
```

**flowSecret**: Required. Set in operation config with the drop-off flow's secret from MFT portal.

**Required document property** (set via Set Properties step before connector):
- `propertyId="connector.thru-8SHH0W-thrumf-technology.fileName"`
- `name="Thru MFT — Partner Connector - FileName"`

**Note**: DROP_OFF does not support the ID parameter. Do not configure parameters on DROP_OFF steps.

**Troubleshooting**: HTTP 412 on DROP_OFF indicates the flow endpoint isn't configured for uploads in the Thru portal. Verify the flow supports file drop-off operations.

## UPDATE Operations

### FLOW_OUTCOME (Status Update)

Updates file processing status in MFT. Input is JSON payload.

```xml
<GenericOperationConfig objectTypeId="FLOW_OUTCOME" objectTypeName="FLOW_OUTCOME" operationType="UPDATE"
    requestProfileType="json" responseProfileType="xml">
  <Options>
    <QueryOptions>
      <Fields><ConnectorObject name="FLOW_OUTCOME"/></Fields>
      <Inputs/>
    </QueryOptions>
  </Options>
</GenericOperationConfig>
```
