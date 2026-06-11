# Database (Legacy) Operation Component

## Contents
- Component Type
- Connector Context
- XML Structure
- Get Action
- Send Action
- Commit and Batching
- Profile Reference
- Parameter Binding

## Component Type
- **Type**: `connector-action`
- **SubType**: `database`
- **Root element**: `<Operation>`

## Connector Context
Defines a single action for the **Database (Legacy) connector**, paired with a Database (Legacy) connection (`connector-settings`, subType `database`) and a Database Profile (`profile.db`). The **SQL itself lives in the referenced Database Profile** — the operation only sets the action type (Get/Send), batching, and commit behavior.

This is **not** Database V2. Database V2 operations (`databasev2_connector_operation_component.md`) carry the SQL and a `GenericOperationConfig`; the legacy operation references the SQL indirectly through a `profile.db`.

## XML Structure

```xml
<?xml version="1.0" encoding="UTF-8"?>
<bns:Component xmlns:bns="http://api.platform.boomi.com/"
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               componentId=""
               name="Operation_Name"
               type="connector-action"
               subType="database"
               folderId="{FOLDER_GUID}">
  <bns:encryptedValues/>
  <bns:object>
    <Operation>
      <Archiving directory="" enabled="false"/>
      <Configuration>
        <!-- DatabaseGetAction or DatabaseSendAction -->
      </Configuration>
      <Tracking><TrackedFields/></Tracking>
      <Caching/>
    </Operation>
  </bns:object>
</bns:Component>
```

The action type must match the referenced profile's `executionType`: a Get references a `dbread` profile, a Send references a `dbwrite` profile.

## Get Action
Retrieves data. References a read profile (`executionType="dbread"` — statement type `select` or `spread`).

```xml
<DatabaseGetAction batchCount="0" maxRows="0">
  <ReadProfile profileId="{profile-db-guid}"/>
</DatabaseGetAction>
```

| Attribute | Notes |
|-----------|-------|
| `batchCount` | Number of records per output document. Default `0` = no batching. Use with large result sets (e.g. `5000`) for efficient downstream processing |
| `maxRows` | Maximum rows returned. Default `0` = no maximum |

### Link Element
A Link Element groups adjacent result rows sharing the linked column's value into one output document. It is configured on `<ReadProfile>`:

```xml
<DatabaseGetAction batchCount="1" maxRows="0">
  <ReadProfile linkElementKey="6"
               linkElementName="resultset (Statement/Fields/resultset)"
               profileId="{profile-db-guid}"/>
</DatabaseGetAction>
```

| Attribute | Notes |
|-----------|-------|
| `linkElementKey` | Key of the profile result-set element to group on |
| `linkElementName` | Display name of that element, including its profile path |

Two preconditions, both required:
- **`batchCount` must be > 0.** With `batchCount="0"` the Link Element is inert (the read returns a single document). `batchCount="1"` splits every row, and the Link Element then re-merges rows that share the linked value.
- **The SQL must `ORDER BY` the linked column** so equal values are contiguous. Grouping operates on contiguous runs only — if the linked values are interleaved, matching rows land in separate documents and the output fragments.

## Send Action
Sends data. References a write profile (`executionType="dbwrite"` — `standardinsertupdatedelete`, `dynamicinsert`, `dynamicupdate`, `dynamicdelete`, or `spwrite`).

```xml
<DatabaseSendAction batchCount="10" commitOption="commitrows" enableBatching="true">
  <WriteProfile profileId="{profile-db-guid}"/>
</DatabaseSendAction>
```

| Attribute | Notes |
|-----------|-------|
| `commitOption` | `commitprofile` = Commit by Profile: a single commit after all statements in the profile execute (avoids orphaned rows across parent/child statements). `commitrows` = Commit by Number of Rows: commits in groups sized by `batchCount` |
| `batchCount` | Rows per commit when `commitOption="commitrows"`. Ignored under `commitprofile` (all rows commit once at document end). `0` or `1` commits one row at a time |
| `enableBatching` | Enable JDBC Batching. Set `true` for SQL that does **not** return a result set — standard/dynamic INSERT/UPDATE/DELETE and stored-procedure writes. Set `false` for statements/triggers that return a result set (executed individually). Ignored if the driver does not support batching |

## Commit and Batching
- **Commit by Profile** (`commitOption="commitprofile"`): a single commit after all of a document's statements run; `batchCount` ignored. Keeps a multi-row write atomic.
- **Commit by Number of Rows** (`commitOption="commitrows"`): commits every `batchCount` rows; allows partial progress.

## Profile Reference
The `<ReadProfile>` / `<WriteProfile>` `profileId` points at the `profile.db` component. Inside a process, the connector shape also references the same profile through its `parameter-profile` attribute:
```
parameter-profile="EMBEDDED|databaseparameterchooser|{profileId}|{operationId}"
```

## Parameter Binding
Input values for the profile's parameters/conditions are bound at the **process connector shape**, not in the operation component. The shape carries a `<parameters>` block with one `<parametervalue>` per profile input, e.g. a static value for a stored-procedure argument:
```xml
<parameters>
  <parametervalue elementToSetId="5" elementToSetName="BusinessEntityID" key="0" usesEncryption="false" valueType="static">
    <staticparameter staticproperty="5"/>
  </parametervalue>
</parameters>
```
Configuring parameters makes the query execute per-document (dynamic document property values are retained per document rather than merged).
