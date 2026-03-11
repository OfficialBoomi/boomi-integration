# Database V2 Connector Operation Component

## Contents
- Component Type
- Operation Types
- XML Structure
- GET Operations
- INSERT Operations
- UPDATE/DELETE Operations
- Response Profile Structure
- Profile Type Attributes

## Component Type
- **Type**: `connector-action`
- **SubType**: `officialboomi-X3979C-dbv2da-prod`

## Operation Types

| Action | customOperationType | operationType |
|--------|-------------------|---------------|
| GET | `GET` | `EXECUTE` |
| INSERT | `CREATE` | `CREATE` |
| UPDATE | `UPDATE` | `UPDATE` |
| DELETE | `DELETE` | `DELETE` |
| UPSERT | `UPSERT` | `UPSERT` |

## XML Structure

```xml
<Component componentId="" name="Operation_Name"
           type="connector-action"
           subType="officialboomi-X3979C-dbv2da-prod"
           folderId="{FOLDER_GUID}">
  <bns:encryptedValues/>
  <bns:object>
    <Operation returnApplicationErrors="true" trackResponse="false">
      <Archiving directory="" enabled="false"/>
      <Configuration>
        <GenericOperationConfig
          customOperationType="GET"
          objectTypeId="tablename"
          operationType="EXECUTE"
          requestProfile="request-profile-guid"
          requestProfileType="json"
          responseProfile="response-profile-guid"
          responseProfileType="json">

          <!-- Operation-specific fields here -->

          <Options>
            <QueryOptions>
              <Fields>
                <ConnectorObject name="tablename">
                  <FieldList>
                    <ConnectorField filterable="true" name="columnname"
                                    selectable="true" selected="true" sortable="true"/>
                  </FieldList>
                </ConnectorObject>
              </Fields>
              <Inputs/>
            </QueryOptions>
          </Options>
        </GenericOperationConfig>
      </Configuration>
      <Tracking><TrackedFields/></Tracking>
      <Caching/>
    </Operation>
  </bns:object>
</Component>
```

## GET Operations

### Dynamic Get
```xml
<field id="GetType" type="string" value="Dynamic Get"/>
<field id="INClause" type="boolean" value="false"/>
<field id="query" type="string" value="select * from tablename"/>
<field id="linkElement" type="string" value=""/>
<field id="maxRows" type="integer"/>
<field id="maxFieldSize" type="integer"/>
<field id="batchCount" type="integer"/>
<field id="fetchSize" type="integer"/>
```

Connector generates SQL at runtime from input document structure.

### Standard Get
```xml
<field id="GetType" type="string" value="Standard Get"/>
<field id="INClause" type="boolean" value="false"/>
<field id="query" type="string" value="select * from tablename where column = ?"/>
<field id="linkElement" type="string" value=""/>
<field id="maxRows" type="integer"/>
<field id="maxFieldSize" type="integer"/>
<field id="batchCount" type="integer"/>
<field id="fetchSize" type="integer"/>
```

User-provided SQL with `?` placeholders or `$paramName` named parameters.

### Standard Get with IN Clause
```xml
<field id="GetType" type="string" value="Standard Get"/>
<field id="INClause" type="boolean" value="true"/>
<field id="query" type="string" value="where customerName in ($customerName)"/>
```

**Input document format:**
```json
{"customerName": ["value1", "value2"]}
```

Named parameters with `$` prefix accept arrays when `INClause="true"`.

### Multi-Table IN Clause
```xml
<GenericOperationConfig objectTypeId="table1,table2" ...>
  <field id="GetType" type="string" value="Standard Get"/>
  <field id="INClause" type="boolean" value="true"/>
  <field id="query" type="string" value="
    select * from table1
    left join table2 on table1.id = table2.fk
    where table1.column in ($table1.column)
    and table2.column in ($table2.column)
  "/>
```

**Input document format:**
```json
{
  "table1.column": ["value1", "value2"],
  "table2.column": ["value3"]
}
```

- `objectTypeId`: Comma-separated table names
- Named parameters: `$tablename.columnname`
- Input keys: `"tablename.columnname"`

## INSERT Operations

### Dynamic Insert
```xml
<field id="InsertionType" type="string" value="Dynamic Insert"/>
<field id="schemaName" type="string" value=""/>
<field id="query" type="string" value=""/>
<field id="joinTransaction" type="boolean" value="false"/>
<field id="CommitOption" type="string" value="Commit By Profile"/>
<field id="batchCount" type="integer"/>
```

Connector generates INSERT SQL from input document.

**Input format:**
```json
{
  "requestBody": {
    "entries": [
      {"column1": "value1", "column2": "value2"}
    ]
  }
}
```

### Standard Insert
```xml
<field id="InsertionType" type="string" value="Standard Insert"/>
<field id="schemaName" type="string" value=""/>
<field id="query" type="string" value="insert into table (col1,col2) values(?,?)"/>
<field id="joinTransaction" type="boolean" value="false"/>
<field id="CommitOption" type="string" value="Commit By Rows"/>
<field id="batchCount" type="integer" value="2"/>
```

User-provided INSERT SQL with `?` placeholders.

### Commit Options
- `"Commit By Profile"`: Commit after all records processed
- `"Commit By Rows"`: Commit in batches (use with `batchCount`)

## UPDATE/DELETE Operations

Similar structure to INSERT with operation-specific type fields:
- UPDATE: `<field id="UpdateType" type="string" value="Dynamic Update|Standard Update"/>`
- DELETE: `<field id="DeleteType" type="string" value="Dynamic Delete|Standard Delete"/>`

Dynamic operations accept WHERE/SET clause structure in input document.

## Response Profile Structure

Standard response fields for all operations:
```xml
<FieldList>
  <ConnectorField name="Query" filterable="true" selectable="true" selected="true" sortable="true"/>
  <ConnectorField name="Rows Effected" filterable="true" selectable="true" selected="true" sortable="true"/>
  <ConnectorField name="Status" filterable="true" selectable="true" selected="true" sortable="true"/>
</FieldList>
```

Returns execution metadata: query executed, rows affected, status.

## Profile Type Attributes

Database V2 operations **require** profile type attributes:
```xml
requestProfileType="json"
responseProfileType="json"
```

Unlike REST connector, these attributes are valid and necessary.
