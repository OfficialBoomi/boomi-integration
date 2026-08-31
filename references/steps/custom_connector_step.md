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
- **Connector Type**: The `classificationType` the platform assigns the connector — read it from an existing component or a GUI-created connection, do not construct it (see `custom_connector_connection_component.md` § Finding the Connector Type Identifier)
- **`actionType`**: Mirror the Operation component — the `operationType` it declares, or its `customOperationType` where it has one. It is an identifier, not a label; the human-readable name belongs in the shape's `userlabel`. This is what the GUI uses to bind a newly created operation to an action, so it must be right when authoring. It is **not** a runtime contract, though: `actionType` does not drive routing, and a wrong value on an existing step pushes, deploys, and executes without changing which operation runs. What actually selects the operation is the Operation component's `customOperationType`.

## Configuration Structure

```xml
<shape image="connectoraction_icon" name="[shapeName]" shapetype="connectoraction" userlabel="[label]" x="[x]" y="[y]">
  <configuration>
    <connectoraction actionType="[operationType-or-customTypeId]"
                    allowDynamicCredentials="NONE"
                    connectionId="[connection-component-guid]"
                    connectorType="[classificationType]"
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

`connectorType` should match the Operation component's `subType`, which is what actually selects the connector build that runs — see `boomi_error_reference.md` Issue #38.

Per-document overrides of an operation field go in this shape's `<dynamicProperties>`; see `custom_connector_operation_component.md`.

## Required Components

Before adding a Custom Connector step:
1. **Connection Component**: See `custom_connector_connection_component.md` for full XML structure including `type="connector-settings"`, `subType` format, and `GenericConnectionConfig` field patterns
2. **Operation Component**: See `custom_connector_operation_component.md` for the `GenericOperationConfig` attribute contract and how `subType` selects the connector build

## Reference XML Example

Where the connector descriptor declares `<operation types="EXECUTE">` with no `customTypeId`, `actionType` carries the bare operation type and the display name sits in `userlabel`:

```xml
<shape image="connectoraction_icon" name="shape2" shapetype="connectoraction"
       userlabel="Get Current Weather" x="272.0" y="48.0">
  <configuration>
    <connectoraction actionType="EXECUTE"
                    allowDynamicCredentials="NONE"
                    connectionId="{connection-component-guid}"
                    connectorType="{classificationType}"
                    hideSettings="false"
                    operationId="{operation-component-guid}">
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

- **Connector Development is out of scope.** This skill configures and uses a connector that already exists — building or publishing one with the Java Connector SDK is separate work. Do not start it on your own initiative; if a process needs a connector that has not been built, say so and let the user decide.
- **Connection/Operation Setup**: Two paths, decided by whether the connector's `connector-descriptor.xml` is at hand:
  - **Descriptor available**: Build connection/operation components programmatically — it declares the connection field ids, operation types, custom type ids, and operation field ids the components must name
  - **Descriptor unavailable**: Configure in the Boomi platform UI first, then pull locally for use. Do not infer the ids from another connector's pulled component
- **Dynamic Properties**: Custom connectors may support dynamic properties depending on their implementation
