## Component Type
**Type**: `connector-action`  
**SubType**: `invixoconsultinggroupas-OZI90V-boomia-prod`

## Overview
Defines operations against SAP objects exposed through Boomi for SAP Core. Initial object import requires GUI, but filters and field selection can be modified programmatically.

## QUERY Operation Structure
```xml
<Operation returnApplicationErrors="false" trackResponse="true">
  <Configuration>
    <GenericOperationConfig
      objectTypeId="CG_PA0002"
      objectTypeName="CG_PA0002"
      operationType="QUERY"
      requestProfileType="xml"
      responseProfile="profile-guid"
      responseProfileType="json">
      <field id="maxReturnedRows" type="integer" value="1000"/>
      <field id="batchSize" type="integer" value="100"/>
      <Options>
        <QueryOptions>
          <Fields>
            <ConnectorObject name="CG_PA0002">
              <FieldList>
                <ConnectorField filterable="true" name="items/PA0002.PERNR"
                               selectable="true" selected="true" sortable="true"/>
                <!-- Additional fields... -->
              </FieldList>
              <Filter>
                <ConnectorBaseFilter>
                  <ConnectorFilterExpression
                    expressionField="items/PA0002.PERNR"
                    expressionOperator="EQ"
                    key="1"
                    name="PERNR="/>
                </ConnectorBaseFilter>
              </Filter>
              <Sorts/>
            </ConnectorObject>
          </Fields>
          <Inputs>
            <Input key="1" name="PERNR="/>
          </Inputs>
        </QueryOptions>
      </Options>
    </GenericOperationConfig>
  </Configuration>
</Operation>
```

## Key Attributes
- `objectTypeId` / `objectTypeName`: Typically identical values representing the SAP object name exposed through Boomi for SAP Core (e.g., "CG_PA0002")
- `responseProfile`: GUID reference to a JSON profile component that defines the response structure
- `operationType`: Operation type - "QUERY", "CREATE", "UPDATE", "UPSERT", or "DELETE"
- `responseProfileType`: Format of response data - "json" for Boomi for SAP operations

## Filter Configuration
Filters require matching entries in both `<Filter>` and `<Inputs>`:
- `<ConnectorFilterExpression>`: Defines filter field and operator
  - `expressionField`: Field path (e.g., "items/PA0002.PERNR")
  - `expressionOperator`: "EQ", "NE", "GT", "LT", etc.
  - `key`: Numeric identifier matching Input element
  - `name`: Display name for parameter
- `<Input>`: Creates parameter slot for runtime values
  - `key`: Must match filter expression key
  - `name`: Parameter name

## Unfiltered Query Pattern
To retrieve all records without filtering:
```xml
<Filter><ConnectorBaseFilter/></Filter>
<Inputs/>
```
This pattern is commonly used for full data extracts or when filtering is handled by downstream components.

## Performance Configuration
Two fields control query performance and result set size:
- `maxReturnedRows`: Maximum number of records to return (default: 1000)
- `batchSize`: Number of records retrieved per API call batch (default: 100)

These are configured as field elements within `GenericOperationConfig`:
```xml
<field id="maxReturnedRows" type="integer" value="1000"/>
<field id="batchSize" type="integer" value="100"/>
```

## Response Structure
Returns JSON array directly:
```json
[
  {
    "PA0002.PERNR": "00001234",
    "PA0002.NACHN": "Smith"
  },
  {
    "PA0002.PERNR": "00005678",
    "PA0002.NACHN": "Jones"
  }
]
```

## Field Referencing
The `items/` prefix in field names (e.g., `items/PA0002.PERNR`) is the connector's internal notation for referencing array elements, not part of the actual JSON structure.

## Modifiable Elements
- Field selection: `selected="true/false"` on ConnectorField elements
- Filter expressions: Add/modify ConnectorFilterExpression elements
- Input parameters: Must have corresponding Input element for each filter