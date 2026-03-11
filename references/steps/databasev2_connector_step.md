# Database V2 Connector Step

## Contents
- Purpose
- Step Type
- XML Structure
- Required Attributes
- Input Document Patterns
- Parameters and Dynamic Properties
- Common Patterns
- Component Dependencies

## Purpose
Database V2 connector steps execute SQL operations against relational databases. Input document structure drives SQL generation for dynamic queries, or provides parameter values for pre-defined SQL.

**Use when:**
- Querying databases for records (SELECT statements)
- Inserting, updating, or deleting data (DML operations)
- Executing stored procedures
- Building dynamic SQL based on document content

## Step Type
- **shapetype**: `connectoraction`
- **Connector Type**: `officialboomi-X3979C-dbv2da-prod`

## XML Structure

```xml
<shape shapetype="connectoraction" name="shape_name" userlabel="Display Name">
  <configuration>
    <connectoraction
      actionType="GET"
      allowDynamicCredentials="NONE"
      connectionId="connection-component-guid"
      connectorType="officialboomi-X3979C-dbv2da-prod"
      hideSettings="false"
      operationId="operation-component-guid"
      parameter-profile="request-profile-guid">
      <parameters/>
      <dynamicProperties/>
    </connectoraction>
  </configuration>
  <dragpoints>
    <dragpoint name="shape_name.dragpoint1" toShape="next_shape" x="416.0" y="56.0"/>
  </dragpoints>
</shape>
```

## Required Attributes

- `actionType`: Operation action type
  - GET operations: `"GET"`
  - INSERT operations: `"CREATE"`
  - UPDATE operations: `"UPDATE"`
  - DELETE operations: `"DELETE"`
- `connectionId`: GUID of Database V2 connection component
- `operationId`: GUID of Database V2 operation component
- `parameter-profile`: GUID of request profile component
- `connectorType`: Always `"officialboomi-X3979C-dbv2da-prod"`

## Input Document Patterns

### Dynamic Operations
Input structure drives SQL generation:

**Dynamic Insert/Update:**
```json
{
  "SET": [{"column": "city", "value": "boston"}],
  "WHERE": [{"column": "id", "value": "123", "operator": "="}]
}
```

**Dynamic Insert (batch):**
```json
{
  "requestBody": {
    "entries": [
      {"column1": "value1", "column2": "value2"},
      {"column1": "value3", "column2": "value4"}
    ]
  }
}
```

### Standard Operations
Input provides parameter values for SQL query:

**Standard Get with named parameters:**
```json
{"paramName": "value"}
```

**Standard Get with IN clause:**
```json
{"paramName": ["value1", "value2", "value3"]}
```

**Multi-table IN clause:**
```json
{
  "tablename.columnname": ["value1"],
  "othertable.columnname": ["value2", "value3"]
}
```

## Parameters and Dynamic Properties

Database V2 connector steps use **empty parameter/dynamic property sections**:
```xml
<parameters/>
<dynamicProperties/>
```

All input data comes from document content, not step configuration.

## Common Patterns

**Standard workflow:**
1. Message step generates input JSON
2. Data Process step splits input (if batching)
3. Database connector step executes operation
4. Response contains Query/Rows Effected/Status fields

**IN clause workflow:**
1. Message step creates JSON with array values
2. Database connector step with `INClause="true"` operation
3. Connector expands arrays into SQL IN clause

## Response Document

Standard response structure for all operations:
```json
{
  "Query": "executed SQL statement",
  "Rows Effected": 5,
  "Status": "success"}
```
