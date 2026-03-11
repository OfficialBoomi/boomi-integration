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
               componentId="{generate-uuid}"
               name="{connection-name}"
               type="connector-settings"
               subType="{connectorGroupID}-{classification}"
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

The `subType` attribute uses the format: `{connectorGroupID}-{classification}`

**How to find it:**

1. **From the custom connector code**: Look for the `@ConnectorConfig` annotation's `groupId` and the build configuration's classification value

2. **From Boomi platform**:
   - Create a connection in the GUI for your custom connector
   - Pull the component using `boomi-component-pull.sh`
   - Check the `subType` attribute in the pulled XML

3. **From existing components**: If you have a pulled connection or operation for this connector, the `connectorType` attribute contains the same value

**Example identifiers:**
- `weatherconnector-ABC123-dev`
- `mycompanyconnector-XYZ789-prod`
- `bigconnectorsdkresearch-VYO86P-28nov1-dev`

## Field Configuration

Custom connector fields are defined in the connector's Java code. Use `<field>` elements (not `<property>` elements):

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
- Check the custom connector's `@ConnectorConfig` annotation and field definitions
- Pull an existing connection from the platform to see the field structure
- If you built the connector with `implementing-boomi-connectors` skill, you know the field IDs

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

**Pulled/Existing Connections**: Preserve `<bns:encryptedValues>` and encrypted field values exactly as-is. Never modify encrypted values.

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

Custom connector operations follow the same `GenericOperationConfig` pattern. See `rest_connector_operation_component.md` for the structural template - custom connectors use the same `<Operation><Configuration><GenericOperationConfig>` hierarchy.
