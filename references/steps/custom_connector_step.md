# Custom Connector Step Reference

## Contents
- Purpose
- Key Concepts
- Configuration Structure
- Required Components
- Reference XML Example
- Workflow Considerations

## Purpose

Custom Connector steps use connectors built with Boomi's Java Connector SDK. They follow the same `connectoraction` shape structure as standard connectors but reference a custom `connectorType` identifier.

## Key Concepts

- **Same Shape Structure**: Uses `shapetype="connectoraction"` identical to REST, Database, and other standard connectors
- **Connector Type Format**: `{connectorGroupID}-{classification}` (e.g., `myconnector-ABC123-prod`)
- **Classification**: Defined in the connector's build configuration (dev, prod, or custom values)
- **Action Types**: Specific to each custom connector, defined by the connector's operations

## Configuration Structure

```xml
<shape image="connectoraction_icon" name="[shapeName]" shapetype="connectoraction" userlabel="[label]" x="[x]" y="[y]">
  <configuration>
    <connectoraction actionType="[connector-specific-action]"
                    allowDynamicCredentials="NONE"
                    connectionId="[connection-component-guid]"
                    connectorType="[connectorGroupID]-[classification]"
                    hideSettings="false"
                    operationId="[operation-component-guid]">
      <parameters/>
      <dynamicProperties/>
    </connectoraction>
  </configuration>
  <dragpoints>
    <dragpoint name="[shapeName].dragpoint1" toShape="[nextShape]" x="[x]" y="[y]"/>
  </dragpoints>
</shape>
```

## Required Components

Before adding a Custom Connector step:
1. **Connection Component**: See `custom_connector_connection_component.md` for full XML structure including `type="connector-settings"`, `subType` format, and `GenericConnectionConfig` field patterns
2. **Operation Component**: Defines the action, request/response profiles (uses same `<Operation><Configuration><GenericOperationConfig>` structure as REST operations - see `rest_connector_operation_component.md`)

## Reference XML Example

```xml
<shape image="connectoraction_icon" name="shape2" shapetype="connectoraction" userlabel="" x="256.0" y="96.0">
  <configuration>
    <connectoraction actionType="Get Current Weather"
                    allowDynamicCredentials="NONE"
                    connectionId="85ab1ba5-fa8e-4c17-8f95-2685525003a6"
                    connectorType="weatherconnector-ABC123-dev"
                    hideSettings="false"
                    operationId="b4744cc9-6ce4-4bb5-b645-268eec335e4d">
      <parameters/>
      <dynamicProperties/>
    </connectoraction>
  </configuration>
  <dragpoints>
    <dragpoint name="shape2.dragpoint1" toShape="shape3" x="384.0" y="104.0"/>
  </dragpoints>
</shape>
```

## Workflow Considerations

- **Connector Development**: Use the `implementing-boomi-connectors` skill to build custom connectors with the Java Connector SDK
- **Connection/Operation Setup**: Two paths:
  - **With implementing-boomi-connectors skill**: Build connection/operation components programmatically (the agent knows the connector's field structure since it built the connector)
  - **Without**: Configure in Boomi platform UI first, then pull locally for use
- **Dynamic Properties**: Custom connectors may support dynamic properties depending on their implementation
