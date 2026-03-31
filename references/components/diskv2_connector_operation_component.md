# Disk V2 Connector Operation Component

## Contents
- Overview
- Operation Types
- Component Structure
- CREATE Operation
- UPSERT Operation
- GET Operation
- QUERY Operation
- LIST Operation
- DELETE Operation
- LISTEN Operation
- Document Properties

## Overview

Disk V2 operation components define file system actions. Operations use `GenericOperationConfig` with operation-specific fields and filter configurations.

**Connector Type**: `disk-sdk`

## Operation Types

| Action | objectTypeId | operationType | customOperationType | Request Profile | Response Profile | Purpose |
|--------|-------------|---------------|--------------------|----|------|---------|
| CREATE | FILE_CREATE_UPSERT | CREATE | — | binary | json | Write files |
| UPSERT | FILE_CREATE_UPSERT | UPSERT | — | binary | json | Write files (create or overwrite/append) |
| GET | FILE | GET | — | xml | binary | Retrieve a file by ID |
| QUERY | FILE | QUERY | QUERY | xml | binary | Search files by filter criteria |
| LIST | DIRECTORY | QUERY | LIST | xml | json | List directory contents with metadata |
| DELETE | FILE | DELETE | — | xml | binary | Remove a file |
| LISTEN | — | LISTEN | — | binary | binary | Watch directory for file events (start shape only) |

## Component Structure

```xml
<?xml version="1.0" encoding="UTF-8"?>
<bns:Component xmlns:bns="http://api.platform.boomi.com/"
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               componentId=""
               name="{operation-name}"
               type="connector-action"
               subType="disk-sdk"
               folderId="{folder-id}">
  <bns:encryptedValues/>
  <bns:object>
    <Operation returnApplicationErrors="false" trackResponse="{see each operation}">
      <Archiving directory="" enabled="false"/>
      <Configuration>
        <GenericOperationConfig objectTypeId="{type}" operationType="{action}"
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

## CREATE Operation

Writes files to the target directory. Input document body becomes file content.

`trackResponse="false"` for CREATE operations.

```xml
<GenericOperationConfig objectTypeId="FILE_CREATE_UPSERT" operationType="CREATE"
    requestProfileType="binary" responseProfileType="json"
    responseProfile="{json-profile-component-id}">
  <field id="createDir" type="boolean" value="true"/>
  <field id="includeAll" type="boolean" value="true"/>
  <field id="actionIfFileExists" type="string" value="APPEND"/>
  <Options>
    <QueryOptions>
      <Fields>
        <ConnectorObject name="File">
          <FieldList>
            <ConnectorField filterable="true" name="createdDate" selectable="true" selected="true" sortable="true"/>
            <ConnectorField filterable="false" name="directory" selectable="true" selected="true" sortable="false"/>
            <ConnectorField filterable="true" name="fileName" selectable="true" selected="true" sortable="true"/>
            <ConnectorField filterable="true" name="fileSize" selectable="true" selected="true" sortable="true"/>
            <ConnectorField filterable="true" name="isDirectory" selectable="true" selected="true" sortable="true"/>
            <ConnectorField filterable="true" name="modifiedDate" selectable="true" selected="true" sortable="true"/>
          </FieldList>
        </ConnectorObject>
      </Fields>
      <Inputs/>
    </QueryOptions>
  </Options>
</GenericOperationConfig>
```

### CREATE Fields

| Field | Type | Description |
|-------|------|-------------|
| `createDir` | boolean | Auto-create directories if they don't exist. |
| `includeAll` | boolean | When `true`, response includes all 6 fields. When `false`, response includes only `fileName` and `directory`. |
| `actionIfFileExists` | string | Behavior when target file already exists. Values are case-sensitive. |

#### actionIfFileExists Values

| Value | Behavior |
|-------|----------|
| `APPEND` | Appends content to existing file. |
| `OVERWRITE` | Replaces file content entirely. |
| `ERROR` | Creates file if it doesn't exist. If file exists, returns error `[2]`. |
| `FORCE_UNIQUE_NAMES` | Appends incrementing integer to basename: `file.txt` → `file1.txt` → `file2.txt`. |

### CREATE Response

Returns a JSON document per file written.

With `includeAll=true`:
```json
{
  "fileName": "example.txt",
  "directory": "work/output",
  "createdDate": "2025-01-15T10:30:00.000Z",
  "modifiedDate": "2025-01-15T10:30:00.000Z",
  "fileSize": 47,
  "isDirectory": false
}
```

With `includeAll=false`:
```json
{
  "fileName": "example.txt",
  "directory": "work/output"
}
```

- Dates use format `yyyy-MM-dd'T'HH:mm:ss.SSS'Z'` (ISO 8601 with milliseconds, UTC).
- `fileSize` is in bytes.

### fileName with Subdirectory Paths

The `connector.disk-sdk.fileName` document property supports forward-slash path separators:

| fileName Value | Resolved Directory | Resolved FileName |
|---|---|---|
| `report.txt` | (connection directory) | `report.txt` |
| `sub1/sub2/deep-file.txt` | `{directory}/sub1/sub2` | `deep-file.txt` |

Nested directories are auto-created when `createDir=true`.

**Path traversal**: On cloud runtimes, `../` in fileName is blocked by the Java SecurityManager:
```
[-1] access denied ("java.io.FilePermission" "work/../temp" "write")
```

## UPSERT Operation

Writes files with create-or-update semantics. Creates the file if it doesn't exist; if it exists, overwrites or appends based on the `append` field. Shares the same `objectTypeId` as CREATE (`FILE_CREATE_UPSERT`).

`trackResponse="false"` for UPSERT operations.

```xml
<GenericOperationConfig objectTypeId="FILE_CREATE_UPSERT" operationType="UPSERT"
    requestProfileType="binary" responseProfileType="json"
    responseProfile="{json-profile-component-id}">
  <field id="createDir" type="boolean" value="true"/>
  <field id="includeAll" type="boolean" value="true"/>
  <field id="append" type="boolean" value="false"/>
  <!-- Same <Options> block as CREATE (File FieldList with 6 response fields) -->
</GenericOperationConfig>
```

### UPSERT Fields

| Field | Type | Description |
|-------|------|-------------|
| `createDir` | boolean | Auto-create directories if they don't exist. |
| `includeAll` | boolean | When `true`, response includes all 6 fields. When `false`, response includes only `fileName` and `directory`. |
| `append` | boolean | When `false`, overwrites existing file content. When `true`, appends to existing file content. |

### UPSERT vs CREATE

UPSERT replaces CREATE's `actionIfFileExists` (4-value string) with a single `append` boolean:

| UPSERT setting | Equivalent CREATE setting |
|----------------|--------------------------|
| `append="false"` | `actionIfFileExists="OVERWRITE"` |
| `append="true"` | `actionIfFileExists="APPEND"` |

UPSERT has no equivalent to CREATE's `ERROR` or `FORCE_UNIQUE_NAMES` modes. UPSERT never errors on an existing file — it always creates or updates.

### UPSERT Response

Same JSON response structure as CREATE. Controlled by `includeAll` the same way.

## GET Operation

Retrieves a single file by ID. The ID is equal to the filename. Returns file content.

`trackResponse="true"` for GET operations.

```xml
<GenericOperationConfig objectTypeId="FILE" operationType="GET"
    requestProfileType="xml" responseProfileType="binary">
  <field id="deleteAfter" type="boolean" value="false"/>
  <field id="failDeleteAfter" type="boolean" value="false"/>
  <Options>
    <QueryOptions>
      <Fields><ConnectorObject name="File"><FieldList/></ConnectorObject></Fields>
      <Inputs><Input key="0" name="ID"/></Inputs>
    </QueryOptions>
  </Options>
</GenericOperationConfig>
```

### GET Fields

| Field | Type | Description |
|-------|------|-------------|
| `deleteAfter` | boolean | Delete file after reading. |
| `failDeleteAfter` | boolean | Fail process if post-read deletion fails. |

The `ID` input parameter is required on the connector step and identifies the target file.

## QUERY Operation

Searches for files matching filter criteria. Returns one document per matching file.

`trackResponse="true"` for QUERY operations.

```xml
<GenericOperationConfig customOperationType="QUERY" objectTypeId="FILE"
    operationType="QUERY" requestProfileType="xml" responseProfileType="binary">
  <field id="count" type="integer" value="-1"/>
  <Options>
    <QueryOptions>
      <Fields>
        <ConnectorObject name="File">
          <FieldList>
            <ConnectorField filterable="true" name="fileName" type="FilePath"/>
            <ConnectorField filterable="true" name="fileSize" type="Comparable"/>
            <ConnectorField filterable="true" name="createdDate" type="Comparable"/>
            <ConnectorField filterable="true" name="modifiedDate" type="Comparable"/>
          </FieldList>
          <Filter>
            <ConnectorBaseFilter>
              <ConnectorFilterLogical logicalOperator="and">
                <ConnectorFilterExpression expressionField="fileName"
                    expressionOperator="WILDCARD" key="0"
                    name="fileName:WILDCARD" type="FilePath"/>
              </ConnectorFilterLogical>
            </ConnectorBaseFilter>
          </Filter>
          <Sorts/>
        </ConnectorObject>
      </Fields>
      <Inputs><Input key="0" name="fileName:WILDCARD"/></Inputs>
    </QueryOptions>
  </Options>
</GenericOperationConfig>
```

### QUERY Fields

| Field | Type | Description |
|-------|------|-------------|
| `count` | integer | `-1` for unlimited. Positive integer limits results. `0` is invalid (error: `Limit must be positive or -1`). |

### QUERY Filter Fields

| Field | Type |
|-------|------|
| `fileName` | FilePath |
| `fileSize` | Comparable |
| `createdDate` | Comparable |
| `modifiedDate` | Comparable |

### Filter Operators by Field Type

**FilePath** fields (`fileName`):

| Operator | XML Value |
|----------|-----------|
| Regex Match | `REGEX` |
| Wildcard Match | `WILDCARD` |
| Equals | `EQUALS` |
| Does not Equal | `NOT_EQUALS` |
| Less Than | `LESS_THAN` |
| Greater Than | `GREATER_THAN` |

**Comparable** fields (`fileSize`, `createdDate`, `modifiedDate`):

| Operator | XML Value |
|----------|-----------|
| Equals | `EQUALS` |
| Does not Equal | `NOT_EQUALS` |
| Less Than | `LESS_THAN` |
| Greater Than | `GREATER_THAN` |

`LESS_THAN` and `GREATER_THAN` are **strict (exclusive)** — the exact value is excluded from results.

Date filter values must use the full millisecond format (`yyyy-MM-dd'T'HH:mm:ss.SSS'Z'`). Omitting milliseconds or using epoch timestamps causes a parse error.

Multiple filters can be combined using `logicalOperator="and"` in the `ConnectorFilterLogical` wrapper.

Filter values are passed as step parameters. The `key` attribute on `ConnectorFilterExpression` maps to the `key` on the corresponding `Input` and `parametervalue`.

## LIST Operation

Lists directory contents with JSON metadata. Returns one JSON document per entry.

`trackResponse="true"` for LIST operations.

```xml
<GenericOperationConfig customOperationType="LIST" objectTypeId="DIRECTORY"
    operationType="QUERY" requestProfileType="xml" responseProfileType="json"
    responseProfile="{json-profile-component-id}">
  <field id="count" type="integer" value="-1"/>
  <Options>
    <QueryOptions>
      <Fields>
        <ConnectorObject name="Directory">
          <FieldList>
            <ConnectorField filterable="true" name="createdDate" type="Comparable"/>
            <ConnectorField filterable="false" name="directory" selectable="true" selected="true"/>
            <ConnectorField filterable="true" name="fileName" type="FilePath"/>
            <ConnectorField filterable="true" name="fileSize" type="Comparable"/>
            <ConnectorField filterable="true" name="isDirectory" type="Boolean"/>
            <ConnectorField filterable="true" name="modifiedDate" type="Comparable"/>
          </FieldList>
          <Filter>
            <ConnectorBaseFilter>
              <ConnectorFilterLogical logicalOperator="or">
                <ConnectorFilterExpression expressionField="isDirectory"
                    expressionOperator="EQUALS" key="0"
                    name="isDirectory:EQUALS" type="Boolean"/>
              </ConnectorFilterLogical>
            </ConnectorBaseFilter>
          </Filter>
          <Sorts/>
        </ConnectorObject>
      </Fields>
      <Inputs><Input key="0" name="isDirectory:EQUALS"/></Inputs>
    </QueryOptions>
  </Options>
</GenericOperationConfig>
```

### LIST Fields

| Field | Type | Description |
|-------|------|-------------|
| `count` | integer | `-1` for unlimited. Positive integer limits results. `0` is invalid. |

LIST returns the same JSON structure as CREATE responses. 

The `directory` field is not filterable but is selectable in output.

## DELETE Operation

**SAFETY**: NEVER build or execute a DELETE operation unless the user has specifically and unambiguously requested file deletion. Always confirm with the user before implementing or executing DELETE in any process.

Removes a single file. The target file is specified via an XML request profile, not via parameters or document properties.

`trackResponse="false"` for DELETE operations.

```xml
<GenericOperationConfig objectTypeId="FILE" objectTypeName="File" operationType="DELETE"
    requestProfile="{xml-profile-component-id}" requestProfileType="xml"
    responseProfileType="binary">
  <Options>
    <QueryOptions>
      <Fields>
        <ConnectorObject name="File"><FieldList/></ConnectorObject>
      </Fields>
      <Inputs/>
    </QueryOptions>
  </Options>
</GenericOperationConfig>
```

### DELETE Request Profile

DELETE requires an XML request profile containing the target filename:

```xml
<DeleteProfileConfig>
  <id>filename.txt</id>
</DeleteProfileConfig>
```

The directory is determined by `connector.disk-sdk.directory` document property or the connection default. The `<id>` value is a literal filename — wildcard patterns are not supported.

### DELETE Behavior

- Successful deletion produces **zero output documents**. Downstream steps receive no documents. This means subsequent steps in the same path would NOT be reached.
- Deleting a non-existent file returns error `[1]`: `the 'path/file' file does not exist in the directory.`
- Deleting a directory returns error `[4]`: `is a directory and deletion is not supported for directories.`
- No custom operation fields (unlike CREATE).

## LISTEN Operation

Watches a directory for file events. Used as a **start shape only** — not a mid-process step. Primarily designed for local runtimes.

`trackResponse="true"` for LISTEN operations.

```xml
<GenericOperationConfig operationType="LISTEN"
    requestProfileType="binary" responseProfileType="binary">
  <field id="subDirectory" type="string" value=""/>
  <field id="fileNameFilter" type="string" value=""/>
  <field id="fileMatchingType" type="string" value="WILDCARD"/>
  <field id="includeCreate" type="boolean" value="true"/>
  <field id="includeDelete" type="boolean" value="false"/>
  <field id="includeModify" type="boolean" value="false"/>
  <field id="includeInitial" type="boolean" value="false"/>
  <field id="isSingleton" type="boolean" value="false"/>
  <Options/>
</GenericOperationConfig>
```

### LISTEN Fields

| Field | Type | Description |
|-------|------|-------------|
| `subDirectory` | string | Subdirectory relative to connection directory to watch. |
| `fileNameFilter` | string | Filter pattern for file names. |
| `fileMatchingType` | string | `EXACT_MATCH` or `WILDCARD`. |
| `includeCreate` | boolean | Fire on file creation events. |
| `includeDelete` | boolean | Fire on file deletion events. |
| `includeModify` | boolean | Fire on file modification events. |
| `includeInitial` | boolean | Fire events for files already present when listener starts. |
| `isSingleton` | boolean | Run on single node only in multi-node runtimes. |

LISTEN has no `objectTypeId`. The connection's `pollingInterval` field controls how frequently the directory is polled. The watched directory must exist before the listener is deployed.

### LISTEN Start Shape

```xml
<shape image="start" name="shape1" shapetype="start">
  <configuration>
    <connectoraction actionType="LISTEN"
        connectorType="disk-sdk"
        connectionId="{connection-component-id}"
        operationId="{operation-component-id}">
      <parameters/>
      <dynamicProperties/>
    </connectoraction>
  </configuration>
</shape>
```

## Document Properties

Set via Set Properties step before the connector step.

| Property ID | Display Name | Behavior |
|---|---|---|
| `connector.disk-sdk.directory` | Disk v2 - Directory | Per-document override of the connection directory. Falls back to connection `directory` field when not set. |
| `connector.disk-sdk.fileName` | Disk v2 - File Name | Target filename. Supports `/` for nested subdirectory paths. |

When `connector.disk-sdk.directory` is set, all ID parameters and filter values are relative to the overridden directory. Setting the directory to `work/subfolder` and the GET ID to `subfolder/target.txt` results in a concatenated path (`work/subfolder/subfolder/target.txt`) — there is no deduplication.

```xml
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
      <staticparameter staticproperty="result.txt"/>
    </parametervalue>
  </sourcevalues>
</documentproperty>
```

Both properties support dynamic values via `valueType="track"` for sourcing from other properties.
