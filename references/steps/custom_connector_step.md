# Custom Connector Step Reference

## Contents
- Purpose
- Key Concepts
- Configuration Structure
- Parameters: GET and DELETE
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
      <!-- see "Parameters: GET and DELETE" below -- a native GET needs a parametervalue here, a native DELETE must not have one -->
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

## Parameters: GET and DELETE

Applies to native SDK GET and DELETE operations (`request.getObjectId()` or `ObjectIdData` iteration), not the REST or OpenAPI-DSL frameworks.

A native GET takes its object id from the step's own `<parametervalue>`, not from the input document:

```xml
<connectoraction actionType="{customTypeId-or-operationType}" connectionId="{connection-guid}"
                 connectorType="{connector-type}" operationId="{operation-guid}">
  <parameters>
    <parametervalue elementToSetId="0" elementToSetName="ObjectId" key="0" valueType="static">
      <staticparameter staticproperty="{object-id}"/>
    </parametervalue>
  </parameters>
  <dynamicProperties/>
</connectoraction>
```

A single `ObjectId` parameter needs no `parameter-profile` attribute anywhere on the step — the platform does not add one on save or on deploy. With the parameter set, the input document is never read, so its format is irrelevant.

Omit the parameter and the document is dropped: one document in, zero out, green execution, and the connector operation is never entered. An empty `<parameters/>` and no `<parameters>` element at all are indistinguishable at execution time.

**Never reuse this parameter block on a DELETE step.** The same block that GET requires throws at execution time on DELETE — `parameters have been defined but no parameter profile has been configured` — because DELETE routes step parameters through a path that requires a configured parameter profile to interpret them, while GET never calls that path. Push and deploy both succeed either way; only execution reveals the mismatch. A DELETE step with no parameters needs no profile.

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
      <!-- this EXECUTE operation takes no id parameter -- do not copy this bare <parameters/> for a native GET or DELETE, see "Parameters: GET and DELETE" above -->
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
