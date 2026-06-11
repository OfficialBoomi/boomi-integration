# Database (Legacy) Connector Step

## Contents
- Purpose
- Step Type
- XML Structure
- Required Attributes
- Action Types
- Parameter Binding
- Component Dependencies

## Purpose
A Database (Legacy) connector step executes a database action defined by a Database Profile (`profile.db`) against a Database (Legacy) connection. The SQL/stored-procedure and its parameters live in the **profile**; the step wires the profile to a connection and operation and supplies input values.

**Use when:**
- Reading from a database with the Database (Legacy) connector (`select`, stored-procedure read)
- Writing with the Database (Legacy) connector (standard/dynamic insert/update/delete, stored-procedure write)
- Working with existing Database (Legacy) assets

For new database work where no constraint requires the legacy connector, prefer Database V2 (`databasev2_connector_step.md`).

## Step Type
- **shapetype**: `connectoraction`
- **Connector Type**: `database`

## XML Structure

```xml
<shape image="connectoraction_icon" name="shape7" shapetype="connectoraction" userlabel="spread" x="512.0" y="432.0">
  <configuration>
    <connectoraction actionType="Get" allowDynamicCredentials="NONE"
                     connectionId="{connection-guid}"
                     connectorType="database"
                     hideSettings="false"
                     operationId="{operation-guid}"
                     parameter-profile="EMBEDDED|databaseparameterchooser|{profile-guid}|{operation-guid}">
      <parameters/>
      <dynamicProperties/>
    </connectoraction>
  </configuration>
  <dragpoints>
    <dragpoint name="shape7.dragpoint1" toShape="shape13" x="560.0" y="392.0"/>
  </dragpoints>
</shape>
```

## Required Attributes

| Attribute | Notes |
|-----------|-------|
| `actionType` | `Get` (read) or `Send` (write). The specific operation (select/insert/update/delete/stored procedure) is determined by the referenced **profile's** `statementType`, not by `actionType` |
| `connectorType` | Always `database` |
| `connectionId` | GUID of the Database (Legacy) connection component |
| `operationId` | GUID of the Database (Legacy) operation component |
| `parameter-profile` | Composite string `EMBEDDED\|databaseparameterchooser\|{profileId}\|{operationId}` — binds the `profile.db` to this operation |

## Action Types
`actionType` is only `Get` or `Send`:
- **Get** — references an operation whose profile is `executionType="dbread"` (`select`, `spread`)
- **Send** — references an operation whose profile is `executionType="dbwrite"` (`standardinsertupdatedelete`, `dynamicinsert`, `dynamicupdate`, `dynamicdelete`, `spwrite`)

## Parameter Binding
`<parameters>` binds input values to the profile's parameter/condition elements. It is empty when inputs are mapped from the incoming document:
```xml
<parameters/>
```

Bind a value on the step with one `<parametervalue>` per profile input. A **stored-procedure input** takes its value from the **incoming document** (`valueType="current"`) — this is the working binding for `spread`/`spwrite` (an upstream Message/Map emits the value):
```xml
<parameters>
  <parametervalue elementToSetId="9" elementToSetName="@BusinessEntityID" key="0" valueType="current"/>
</parameters>
```
`elementToSetId` is the profile element's `key` (e.g. the `DBParameter` key for a stored-proc input). A **fixed** value uses `valueType="static"` with a `<staticparameter>` child instead:
```xml
<parametervalue elementToSetId="5" elementToSetName="DepartmentID" key="0" usesEncryption="false" valueType="static">
  <staticparameter staticproperty="..."/>
</parametervalue>
```

| Attribute | Notes |
|-----------|-------|
| `elementToSetId` | Key of the target element in the profile (a `DBParameter` / `DBCondition` key) |
| `elementToSetName` | Name of that element (e.g. `@BusinessEntityID`) |
| `key` | Zero-based parameter index on the step |
| `valueType` | `current` = value from the incoming document; `static` = fixed value carried in `<staticparameter staticproperty="...">` |

For a stored procedure, `storedProcedure` in the profile must be the **bare proc name** (no `EXEC`/`?`) for this binding to work — see `database_profile_component.md`.

Configuring parameters makes the query execute per-document (dynamic document property values are retained per document rather than merged). `<dynamicProperties/>` is typically empty.

### Feeding write inputs
A **Send** action executes only when it receives a populated input document carrying the profile's field values; a Send fed an empty document (e.g. straight from a `<noaction/>` Start) passes the document through and runs **no SQL**. Supply write values by **mapping the incoming document into the profile** — a Map whose target profile is the `profile.db`. Reads (`Get`) are triggered by an inbound document but take their inputs from the step parameters / mapped document.

## Component Dependencies
A working Database (Legacy) step requires three components — create them in this order:
1. **Database Profile** (`profile.db`) — the SQL/stored procedure and its fields/parameters/conditions (`database_profile_component.md`)
2. **Connection** (`connector-settings`, subType `database`) — `database_connection_component.md`
3. **Operation** (`connector-action`, subType `database`) — references the profile via `ReadProfile`/`WriteProfile` (`database_connector_operation_component.md`)
