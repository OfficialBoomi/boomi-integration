# MCP Server Operation Component

> **Technology Preview** (Jan 2026): This connector is NOT production-ready. No SLA coverage, community support only.

Component type: `connector-action`
SubType: `officialboomi-X3979C-mcp-prod`

## Contents
- Critical Requirements
- Overview
- XML Structure
- Operation Configuration
- Tool Definition Fields
- JSON Schema Requirements
- Special Structures
- Dependencies
- Notes

## Critical Requirements

**Only `tool` object type is supported:**
- `objectTypeId="tool"` - SUPPORTED
- `objectTypeId="resource"` - NOT SUPPORTED
- `objectTypeId="prompt"` - NOT SUPPORTED (prompts with arguments explicitly unsupported)

**Operation type must be Listen:**
- `customOperationType="Listen"`
- `operationType="Listen"`

## Overview

The MCP Server Operation component defines a tool that AI agents can discover and invoke. It specifies the tool name, description, input schema, and response profile. The JSON Schema defines what parameters the tool accepts.

## XML Structure

```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<bns:Component
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xmlns:bns="http://api.platform.boomi.com/"
  componentId="{component-guid}"
  version="1"
  name="{Operation_Name}"
  type="connector-action"
  subType="officialboomi-X3979C-mcp-prod"
  folderId="{folder-id}"
  deleted="false"
  currentVersion="true">
  <bns:encryptedValues/>
  <bns:description>{description}</bns:description>
  <bns:object>
    <Operation xmlns="" returnApplicationErrors="false" trackResponse="true">
      <Archiving directory="" enabled="false"/>
      <Configuration>
        <GenericOperationConfig
          customOperationType="Listen"
          objectTypeId="tool"
          objectTypeName="Tool"
          operationType="Listen"
          requestProfileType="xml"
          responseProfile="{response-profile-guid}"
          responseProfileType="json">
          <field id="toolName" type="string" value="{TOOL-NAME}"/>
          <field id="toolDescription" type="string" value="{Tool description for AI agents}"/>
          <field id="processTimeout" type="integer" value="30"/>
          <field id="toolSchema" type="string" value="{HTML-ENCODED-JSON-SCHEMA}"/>
          <dynamicOperationField displayType="textarea" id="toolSchema"
            label="JSON Input Schema" overrideable="false" type="string">
            <helpText>Saving a new schema updates MCP tool definition</helpText>
            <defaultValue>{PLAIN-JSON-SCHEMA}</defaultValue>
          </dynamicOperationField>
          <cookie role="OUTPUT">
            <value>{PLAIN-JSON-SCHEMA}</value>
          </cookie>
          <Options>
            <QueryOptions>
              <Fields>
                <ConnectorObject name="Tool">
                  <FieldList>
                    <ConnectorField filterable="true" name="{field-name}"
                      selectable="true" selected="true" sortable="true"/>
                    <!-- One ConnectorField per schema property -->
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
</bns:Component>
```

## Operation Configuration

| Attribute | Value | Notes |
|-----------|-------|-------|
| customOperationType | `Listen` | Only supported value |
| objectTypeId | `tool` | Only supported value (not resource, not prompt) |
| objectTypeName | `Tool` | Human-readable |
| operationType | `Listen` | Boomi operation classification |
| requestProfileType | `xml` | Internal processing (input is actually JSON) |
| responseProfile | `{guid}` | Reference to JSON Profile component |
| responseProfileType | `json` | Output format |

## Tool Definition Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| toolName | string | Yes | MCP tool identifier exposed to AI agents (1-128 chars, unique per server) |
| toolDescription | string | Yes | Human-readable description for AI agent discovery |
| processTimeout | integer | No | Execution timeout in seconds (default: 30) |
| toolSchema | string | Yes | HTML-encoded JSON Schema (Draft 2020-12) defining tool input |

## JSON Schema Requirements

The `toolSchema` field must contain a valid JSON Schema with HTML entity encoding:

### Encoding Rules

| Character | Encoding |
|-----------|----------|
| `"` | `&quot;` |
| `<` | `&lt;` |
| `>` | `&gt;` |
| `&` | `&amp;` |
| newline | `&#xA;` |

### Schema Structure

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "unique-schema-id",
  "title": "Tool Title",
  "description": "What this tool does",
  "type": "object",
  "properties": {
    "fieldName": {
      "type": "string",
      "description": "Field description"
    }
  },
  "required": ["fieldName"]
}
```

### Example: Encoded vs Plain

**Plain (for defaultValue and cookie):**
```json
{"$schema":"https://json-schema.org/draft/2020-12/schema","type":"object"}
```

**HTML-Encoded (for toolSchema field value):**
```
{&quot;$schema&quot;:&quot;https://json-schema.org/draft/2020-12/schema&quot;,&quot;type&quot;:&quot;object&quot;}
```

## Special Structures

### dynamicOperationField

UI metadata for the schema editor. Contains the **plain** (unencoded) JSON Schema.

```xml
<dynamicOperationField displayType="textarea" id="toolSchema"
  label="JSON Input Schema" overrideable="false" type="string">
  <helpText>Saving a new schema updates MCP tool definition</helpText>
  <defaultValue>{PLAIN-JSON-SCHEMA}</defaultValue>
</dynamicOperationField>
```

### cookie

Cached schema for UI display. Must match `defaultValue` content.

```xml
<cookie role="OUTPUT">
  <value>{PLAIN-JSON-SCHEMA}</value>
</cookie>
```

### Options/QueryOptions

Auto-generated field metadata from schema properties. One `ConnectorField` per schema property.

```xml
<Options>
  <QueryOptions>
    <Fields>
      <ConnectorObject name="Tool">
        <FieldList>
          <ConnectorField filterable="true" name="operation"
            selectable="true" selected="true" sortable="true"/>
          <ConnectorField filterable="true" name="projectKey"
            selectable="true" selected="true" sortable="true"/>
        </FieldList>
      </ConnectorObject>
    </Fields>
    <Inputs/>
  </QueryOptions>
</Options>
```

## Dependencies

- **JSON Profile**: Must exist before operation references it via `responseProfile`
- **Connection**: Operation is paired with connection at start shape level

## Notes

1. **Namespace Requirements**:
   - `Operation` element must have `xmlns=""`
   - `GenericOperationConfig` inherits empty namespace

2. **Schema Sync Critical**: The `toolSchema` field, `defaultValue`, and `cookie/value` must all contain the same schema (encoded vs plain). Mismatches cause validation issues.

3. **Profile Sync Manual**: Changing `toolSchema` does NOT automatically update the JSON Profile. You must reimport the profile and redeploy.

4. **Output Schemas**: NOT supported. Define response structure in process logic.

5. **Tool Metadata Annotations**: NOT supported.
