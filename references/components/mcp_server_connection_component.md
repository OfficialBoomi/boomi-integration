# MCP Server Connection Component

> **Technology Preview** (Jan 2026): This connector is NOT production-ready. No SLA coverage, community support only.

Component type: `connector-settings`
SubType: `officialboomi-X3979C-mcp-prod`

## Contents
- Critical Warning
- Overview
- XML Structure
- Configuration Fields
- Authentication Patterns
- Notes

## Critical Warning

**Technology Preview Limitations:**
- NOT recommended for production use
- No SLA coverage
- Subject to breaking changes without notice
- Community forum support only

## Overview

The MCP Server Connection component configures authentication and server identity for exposing Boomi processes as AI-callable tools via the Model Context Protocol. Each connection can serve multiple MCP operations/tools.

## XML Structure

```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<bns:Component
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xmlns:bns="http://api.platform.boomi.com/"
  componentId="{component-guid}"
  version="1"
  name="{Connection_Name}"
  type="connector-settings"
  subType="officialboomi-X3979C-mcp-prod"
  folderId="{folder-id}"
  deleted="false"
  currentVersion="true">
  <bns:encryptedValues/>
  <bns:description>{description}</bns:description>
  <bns:object>
    <GenericConnectionConfig xmlns="">
      <field id="serverName" type="string" value="{Server-Display-Name}"/>
      <field id="auth" type="string" value="API_TOKEN"/>
      <field id="apiTokens" type="customproperties">
        <customProperties>
          <properties key="{token-name}" value="{uuid-token}"/>
        </customProperties>
      </field>
      <field id="conversationStarters" type="customproperties">
        <customProperties>
          <properties key="{capability-key}" value="{capability-description}"/>
        </customProperties>
      </field>
    </GenericConnectionConfig>
  </bns:object>
</bns:Component>
```

## Configuration Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| serverName | string | Yes | Display name for the MCP server (determines URL path) |
| auth | string | Yes | Authentication method: `API_TOKEN` or `NONE` |
| apiTokens | customproperties | Conditional | Required if auth=API_TOKEN. Key-value pairs of token names and UUIDs |
| conversationStarters | customproperties | No | AI discovery hints describing server capabilities |

### Server Name Guidelines

The `serverName` determines the URL path: `http://host:8000/mcp/{serverName}/sse`

| Guideline | Example |
|-----------|---------|
| Use descriptive names | `MCP_Production_OrderProcessing` |
| Follow consistent convention | `[Environment]_[App]_[Function]` |
| Avoid special chars/spaces | `shopify-mcp` (auto URL-encoded if needed) |
| Keep concise (20-30 chars) | `MCP_Invoice_v2` |

### Conversation Starters

| Constraint | Limit |
|------------|-------|
| Name length | <100 characters |
| Value length | <1024 characters |

Write intentional prompts so MCP clients know which tool to use:
- `GetOrders` → "Gets the top 10 recent orders from the Shopify store."
- `SearchInventory` → "Get a list of products with low inventory levels."

## Authentication Patterns

### API Token Authentication (Recommended)

```xml
<field id="auth" type="string" value="API_TOKEN"/>
<field id="apiTokens" type="customproperties">
  <customProperties>
    <properties key="PRODUCTION" value="6dee4392-6021-4362-b2bd-19c08aeed88d"/>
    <properties key="DEVELOPMENT" value="b6a3b83e-dfd1-4092-90d4-2751ba9419b0"/>
  </customProperties>
</field>
```

- Token values must be valid UUIDs
- Keys are client/environment identifiers
- Multiple tokens supported for different clients
- **Client Authentication Headers:** Clients use either:
  - `Authorization: Bearer <token>`
  - `X-API-Key: <token>`
- Keep readable tokens secure - once encrypted on platform, cannot be decrypted

### No Authentication (Testing Only)

```xml
<field id="auth" type="string" value="NONE"/>
```

**WARNING:** Only use `NONE` for local testing. Never deploy without authentication.

### Unsupported Authentication

- OAuth - NOT supported
- Basic Auth - NOT supported

## Notes

1. **Namespace Requirement**: `GenericConnectionConfig` must have `xmlns=""` (empty namespace)
2. **Token Security**: Tokens are stored as plain text in XML; encrypted only after platform push
3. **Connection Sharing**: One connection can serve multiple operations/tools
4. **Conversation Starters**: Optional hints help AI agents discover server capabilities
5. **SSL**: Not supported at connector level; use external SSL termination (gateway/load balancer)
