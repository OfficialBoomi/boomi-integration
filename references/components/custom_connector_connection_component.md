# Custom Connector Connection Component

## Contents
- Overview
- Component Structure
- Finding the Connector Type Identifier
- Field Configuration
- Password Handling
- Common Patterns
- Relationship with Operation Component

## Overview

Custom Connector Connection components store configuration for connectors built with Boomi's Java Connector SDK. They use the same `GenericConnectionConfig` structure as standard connectors but reference a custom connector type identifier.

## Component Structure

```xml
<?xml version="1.0" encoding="UTF-8"?>
<bns:Component xmlns:bns="http://api.platform.boomi.com/"
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               componentId=""
               name="{connection-name}"
               type="connector-settings"
               subType="{classificationType}"
               folderId="{folder-id}">
  <bns:encryptedValues/>
  <bns:object>
    <GenericConnectionConfig>
      <!-- Field elements defined by the custom connector -->
    </GenericConnectionConfig>
  </bns:object>
</bns:Component>
```

**Critical Attributes:**
- `type="connector-settings"` - NOT `type="connector"`
- `subType` - The custom connector's type identifier (see below)
- `<GenericConnectionConfig>` directly under `<bns:object>` - no `<Connection>` wrapper

## Finding the Connector Type Identifier

The `subType` attribute is the connector's **`classificationType`** — the identifier the Connectors API assigns when the connector group is created. The connector's name is slugified and may be truncated, so **it cannot be reliably hand-constructed. Read it back.**

**How to find it:**

1. **From an existing component**: If you have a pulled connection, operation, or process for this connector, the `subType` (connection and operation components) and `connectorType` (step) attributes all carry the same value

2. **From Boomi platform**:
   - Create a connection in the GUI for your custom connector
   - Pull the component using `boomi-component-pull.sh`
   - Check the `subType` attribute in the pulled XML

3. **From the Connectors API**, which owns the value: the connector group's create response returns it, and fetching an existing group lists the classificationTypes it holds. This is the authoritative source, but it is a separate API from the Platform API these scripts call

The connector's own Java code is **not** a source for this value — the identifier is assigned by the platform at group-create time, not declared in the connector.

## Field Configuration

Custom connector fields are declared in the connector's `connector-descriptor.xml` — the root-level `<field>` elements become the connection's fields, and only ids the descriptor declares are honored. Use `<field>` elements here (not `<property>` elements):

```xml
<GenericConnectionConfig>
  <field id="{field-id}" type="{field-type}" value="{value}"/>
</GenericConnectionConfig>
```

**Field Types:**
- `string` - Text values
- `password` - Sensitive values (auto-encrypted on push)
- `boolean` - true/false values
- `integer` - Numeric values

`customproperties` does not use the `value` attribute. It nests a camelCase container whose entries are plural, one per pair:

```xml
<field id="headers" type="customproperties">
  <customProperties>
    <properties key="X-Trace-Id" value="abc123"/>
    <properties key="X-Environment" value="staging"/>
  </customProperties>
</field>
```

Individual entries can be encrypted, in which case they carry `encrypted="true"` and a matching `<bns:encryptedValue>` path — see `openapi_connection_component.md` and `mcp_server_connection_component.md`, which document that variant. Do not put a secret in a plain `<properties value="…">`.

A descriptor may also declare `privatecertificate`, `publiccertificate`, and `oauth` connection fields. How those serialize is not documented here — configure one in the GUI and pull it rather than guessing.

**Example:**
```xml
<GenericConnectionConfig>
  <field id="baseUrl" type="string" value="https://api.example.com"/>
  <field id="apiKey" type="password" value="your-api-key"/>
  <field id="timeout" type="integer" value="30000"/>
  <field id="enableLogging" type="boolean" value="true"/>
</GenericConnectionConfig>
```

**Finding field IDs:**
- Read the connector's `connector-descriptor.xml` — root-level `<field id="…">` elements are the connection fields
- Pull an existing connection from the platform to see the field structure

If neither the descriptor nor a pulled example is available, ask the user for the descriptor rather than guessing ids — an undeclared id is silently dropped.

## Password Handling

**New Connection Creation**: Pass plaintext for `type="password"` fields. Boomi auto-encrypts on push:
```xml
<bns:encryptedValues/>
<bns:object>
  <GenericConnectionConfig>
    <field id="apiKey" type="password" value="plaintext-secret"/>
  </GenericConnectionConfig>
</bns:object>
```

**Never pull a connection and push it back** — doing so destroys the stored credential. To change an existing connection, have the user edit it in the GUI. `boomi_error_reference.md` Issue #39 documents the mechanics and the outcome of each pushed value.

Two points specific to custom connector connections:

- **The push guard does not cover this.** It rejects a pushed 128-hex token for REST Client connections only — it keys on the REST `subType`, not on the component type, which every connection shares — so a custom connector connection carrying one pushes without complaint.
- **The GUI is the only repair path.** Environment Extensions, the alternative documented for REST connections, is not established for custom connector fields.

`<bns:encryptedValues>` is platform-generated output — emit it empty. Its `path` is type-based (`field[@type='password']`), so one entry covers every password-typed field, and `isSet="true"` means "at least one is set", not which.

## Common Patterns

### API Key Authentication
```xml
<GenericConnectionConfig>
  <field id="baseUrl" type="string" value="https://api.service.com/v1"/>
  <field id="apiKey" type="password" value="{api-key}"/>
</GenericConnectionConfig>
```

### Username/Password Authentication
```xml
<GenericConnectionConfig>
  <field id="serverUrl" type="string" value="https://server.example.com"/>
  <field id="username" type="string" value="{username}"/>
  <field id="password" type="password" value="{password}"/>
</GenericConnectionConfig>
```

### OAuth/Token Authentication
```xml
<GenericConnectionConfig>
  <field id="tokenUrl" type="string" value="https://auth.service.com/token"/>
  <field id="clientId" type="string" value="{client-id}"/>
  <field id="clientSecret" type="password" value="{client-secret}"/>
</GenericConnectionConfig>
```

## Relationship with Operation Component

The connection component provides:
- Base configuration (URLs, credentials)
- Authentication settings
- Connection-level options

The operation component adds:
- Specific action to perform
- Request/response profiles
- Action-specific parameters

See `custom_connector_operation_component.md` for the operation's XML and its attribute contract.
