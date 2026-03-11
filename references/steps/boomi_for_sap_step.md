## Step Type
`connectoraction` with `connectorType="invixoconsultinggroupas-OZI90V-boomia-prod"`

## Overview
Executes Boomi for SAP operations. Supports runtime parameter binding for filters defined in the operation.

## XML Structure
```xml
<shape shapetype="connectoraction">
  <configuration>
    <connectoraction 
      actionType="QUERY"
      allowDynamicCredentials="NONE"
      connectionId="connection-guid"
      connectorType="invixoconsultinggroupas-OZI90V-boomia-prod"
      hideSettings="false"
      operationId="operation-guid"
      parameter-profile="EMBEDDED|genericparameterchooser|operation-guid">
      <parameters>
        <parametervalue 
          elementToSetId="1" 
          elementToSetName="PERNR=" 
          key="0" 
          usesEncryption="false" 
          valueType="track">
          <trackparameter 
            defaultValue="" 
            propertyId="dynamicdocument.DDP_EMPLOYEE_ID" 
            propertyName="Dynamic Document Property - DDP_EMPLOYEE_ID"/>
        </parametervalue>
      </parameters>
      <dynamicProperties/>
    </connectoraction>
  </configuration>
</shape>
```

## Parameter Binding
Maps runtime values to operation filter inputs:
- `elementToSetId`: Matches Input key in operation
- `elementToSetName`: Matches Input name in operation
- `valueType`: "track" for dynamic properties, "static" for literals
- `propertyId`: Source property (e.g., "dynamicdocument.DDP_VALUE")
- `propertyName`: Display name

For operations without filter inputs (e.g., unfiltered queries), use empty parameter elements:
```xml
<parameters/>
<dynamicProperties/>
```

## Required Attributes
- `actionType`: Must match operation type (QUERY)
- `connectionId`: GUID of SAP connection
- `operationId`: GUID of operation component
- `connectorType`: Always "invixoconsultinggroupas-OZI90V-boomia-prod"
- `parameter-profile`: Format "EMBEDDED|genericparameterchooser|{operation-guid}"

## Usage Pattern
1. Reference existing connection and operation by ID
2. Map filter parameters to runtime properties
3. Process returns JSON array per operation configuration