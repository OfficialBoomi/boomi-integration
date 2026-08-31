# Custom Connector Operation Component

## Contents
- Overview
- Component Structure
- Attribute Contract
- Request and Response Profiles
- QUERY Operations
- Named Custom Actions
- Per-Document Field Overrides
- Not Documented Here

## Overview

Custom Connector Operation components configure an action on a connector built with Boomi's Java Connector SDK. They use the same `<Operation><Configuration><GenericOperationConfig>` hierarchy as other connectors, but what goes inside `GenericOperationConfig` is defined by that connector — its `connector-descriptor.xml` and its `Browser` implementation.

**Do not use `rest_connector_operation_component.md` as the template.** Its `path`, `queryParameters`, `requestHeaders`, and `followRedirects` configuration is REST-specific and has no meaning here.

Author these attributes from the connector descriptor. Copying a working operation from a *different* SDK connector is how mismatches get introduced — that connector's `customOperationType` is backed by its own descriptor, not yours.

## Component Structure

```xml
<?xml version="1.0" encoding="UTF-8"?>
<bns:Component xmlns:bns="http://api.platform.boomi.com/"
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               componentId=""
               name="{operation-name}"
               type="connector-action"
               subType="{classificationType}"
               folderId="{folder-id}">
  <bns:encryptedValues/>
  <bns:object>
    <Operation returnApplicationErrors="false" trackResponse="false">
      <Archiving directory="" enabled="false"/>
      <Configuration>
        <GenericOperationConfig objectTypeId="{object-type-id}"
                                objectTypeName="{object-type-label}"
                                operationType="{operationType}">
          <field id="{field-id}" type="string" value="{value}"/>
          <Options/>
        </GenericOperationConfig>
      </Configuration>
      <Tracking>
        <TrackedFields/>
      </Tracking>
      <Caching/>
    </Operation>
  </bns:object>
</bns:Component>
```

**Critical attributes and structure:**
- `type="connector-action"`
- `subType` — **this attribute selects which connector build executes.** Set it to the same `classificationType` as the connection component. A mismatch between the two is accepted on push, deploy, and execution, and silently runs the classification named here (with the connection's credentials) — see `boomi_error_reference.md` Issue #38.
- `<Archiving>`, `<Tracking><TrackedFields/></Tracking>`, `<Caching/>`, and `<Options/>` are **optional**. The GUI writes all four, which is why every GUI-created component carries them, but omitting any of them pushes, deploys, executes, and renders in the GUI unchanged, and the platform does not re-insert them.
- `<field>` children come **before** `<Options/>` inside `GenericOperationConfig`

For a descriptor declaring `<operation types="EXECUTE" supportsBrowse="true">` with one operation field `city` and no `customTypeId`:

```xml
<GenericOperationConfig objectTypeId="CurrentWeather"
                        objectTypeName="Current Weather"
                        operationType="EXECUTE">
  <field id="city" type="string" value="Austin,US"/>
  <Options/>
</GenericOperationConfig>
```

## Attribute Contract

Every value here comes from the connector, and **the platform does not reject a wrong one.** Get them from the descriptor and the connector's `Browser`; no push, deploy, or execution checkpoint will catch a mismatch.

| Attribute | Source | If it doesn't match |
|---|---|---|
| `operationType` | An `OperationType` the descriptor's `<operation types="…">` declares | — |
| `customOperationType` | A `customTypeId` declared on a descriptor `<operation>`. **Omit entirely when the descriptor declares none.** | Passed to the connector verbatim; the GUI operation form loses its object type and every declared field — Issue #36 |
| `objectTypeId` | An id from `Browser.getObjectTypes()`, or an `<object id="…">` under the descriptor's `<browseConfiguration><objectTypes>` | Nothing at runtime — executes and returns correct data |
| `objectTypeName` | The object type's label | — |
| `<field id="…">` | A `<field>` declared **inside** that `<operation>` element | The value never reaches the connector under the id it expects, and no default replaces it — Issue #37 |

Root-level descriptor `<field>` elements belong to the Connection component instead. `<dynamicProperty>` and `<trackedProperty>` appear in neither component — the connector reads and writes those at runtime.

`EXECUTE` is a current, valid operation type; the platform's "Supported operations (actions)" list omits it because that list enumerates user-facing action semantics, not legal descriptor values — its absence is not a deprecation. A bare `types="EXECUTE"` reaches users as an action named literally "EXECUTE", so a well-built connector usually names its EXECUTE operations — expect a `customOperationType` and check the descriptor rather than assuming the bare form.

The descriptor is the only source for these values. If it is not available, ask the user for it, or have them create the operation in the GUI and pull it — every alternative is a guess the platform will accept.

## Request and Response Profiles

SDK connector operations accept profile GUIDs with matching type attributes:

```xml
<GenericOperationConfig objectTypeId="prices" objectTypeName="prices" operationType="UPDATE"
                        requestProfile="{profile-guid}" requestProfileType="json"
                        responseProfile="{profile-guid}" responseProfileType="xml">
```

`requestProfileType` / `responseProfileType` are `json` or `xml`. The GUI Import Wizard populates these from the connector's `Browser.getObjectDefinitions()` output. Omit the profile attributes an operation does not use — a component may carry a `*ProfileType` without its matching GUID, and an operation that uses no profiles carries none of the four.

## QUERY Operations

A QUERY operation's field selection lives in `<Options><QueryOptions>`. `ConnectorObject`'s `name` is the object type's **label** (`objectTypeName`), not its `objectTypeId`:

```xml
<Options>
  <QueryOptions>
    <Fields>
      <ConnectorObject name="{object-type-label}">
        <FieldList>
          <ConnectorField filterable="true" name="id" selectable="true" selected="true" sortable="true"/>
          <ConnectorField filterable="true" name="address/city" selectable="true" selected="true" sortable="true"/>
        </FieldList>
        <Filter><ConnectorBaseFilter/></Filter>
        <Sorts/>
      </ConnectorObject>
    </Fields>
    <Inputs/>
  </QueryOptions>
</Options>
```

A bare `<ConnectorObject name="…"/>` with no `<FieldList>` selects nothing — `getSelectedFields()` comes back empty. Nested fields use path names (`address/city`).

An empty `<Options/>` on a QUERY operation is also accepted and executes normally; what differs between the two is whether field selection is configured, not whether the operation runs. Prefer importing a QUERY operation through the GUI wizard and pulling it — the wizard enumerates the connector's fields, which is tedious to reproduce by hand.

Filter values for a connector QUERY come from the **process step**, not from this component; the step-level filter shape is not documented here.

## Named Custom Actions

Where the descriptor declares `<operation types="EXECUTE" customTypeId="GET_FORECAST" customTypeLabel="Get 5-Day Forecast">`, `customOperationType` carries the **`customTypeId`**, not the label:

```xml
<GenericOperationConfig customOperationType="GET_FORECAST" objectTypeId="Forecast"
                        objectTypeName="Forecast" operationType="EXECUTE">
```

`customTypeLabel` is display-only — it is what the GUI shows as the action name, falling back to the `customTypeId` when absent. `customOperationType` is the sole driver of which operation the connector receives; the step's `actionType` does not affect runtime routing.

A pulled component from another connector may carry a title-cased `customOperationType` such as `Update`, which looks like a label but is that connector's `customTypeId`. Read the descriptor rather than inferring the convention from an example.

## Per-Document Field Overrides

A descriptor field marked `overrideable="true"` can be driven per document from the process step, keyed by **the descriptor's own field id**:

```xml
<dynamicProperties>
  <propertyvalue childKey="" key="latitude" name="Latitude" valueType="static">
    <staticparameter staticproperty="{value}"/>
  </propertyvalue>
</dynamicProperties>
```

`key` carries the field id; `name` is the display label; `childKey` is present but unused. The REST connector's `queryParameters`-style `childKey`/`key` pairing does **not** transfer here.

The step-level value wins over the operation component's static field. Note the connector sees the two through different APIs — the static operation property map still reports the component's value while the override is in force, so a connector reading the static map ignores step overrides entirely.

## Not Documented Here

Configure these in the GUI and pull the component rather than hand-authoring:

- **LISTEN operations** — nothing in the `GenericOperationConfig` and `<Options/>` shape above is established for listener operations.
- **Non-string operation field types** in `GenericOperationConfig`.
