# MCP Server Start Step

> **Technology Preview** (Jan 2026): This connector is NOT production-ready. No SLA coverage, community support only.

## Contents
- Purpose
- Key Attributes
- XML Structure
- Process Configuration
- Typical Process Pattern
- Component Dependencies
- Notes

## Purpose

The MCP Server Start Step is the entry point for processes that expose tools to AI agents via the Model Context Protocol. It listens for incoming tool invocations and passes the JSON input to subsequent process shapes for handling.

## Key Attributes

| Attribute | Value | Required | Description |
|-----------|-------|----------|-------------|
| actionType | `Listen` | Yes | Only valid value for MCP listeners |
| connectorType | `officialboomi-X3979C-mcp-prod` | Yes | Identifies MCP Server connector |
| connectionId | `{guid}` | Yes | Reference to MCP Connection component |
| operationId | `{guid}` | Yes | Reference to MCP Operation component |
| allowDynamicCredentials | `NONE` | Yes | Credential override behavior (use NONE for MCP) |
| hideSettings | `false` | No | UI visibility control |

### allowDynamicCredentials Values

| Value | Description |
|-------|-------------|
| `NONE` | No credential override (recommended for MCP) |
| `PASSWORD` | Password can be overridden at runtime |
| `CERTIFICATE` | Certificate can be overridden |
| `OAUTH2_AUTHORIZATION_CODE` | OAuth2 auth code override |
| `OAUTH2_CLIENT_CREDENTIALS` | OAuth2 client credentials override |

## XML Structure

```xml
<shape image="start" name="shape1" shapetype="start" userlabel="" x="48.0" y="46.0">
  <configuration>
    <connectoraction
      actionType="Listen"
      allowDynamicCredentials="NONE"
      connectionId="{connection-guid}"
      connectorType="officialboomi-X3979C-mcp-prod"
      hideSettings="false"
      operationId="{operation-guid}">
      <parameters/>
      <dynamicProperties/>
    </connectoraction>
  </configuration>
  <dragpoints>
    <dragpoint name="shape1.dragpoint1" toShape="shape2" x="240.0" y="56.0"/>
  </dragpoints>
</shape>
```

## Process Configuration

The process component containing an MCP Start Step should have these attributes:

| Attribute | Value | Notes |
|-----------|-------|-------|
| workload | `general` | Only supported value (low_latency and bridge NOT available) |
| allowSimultaneous | `true` | Enable multiple concurrent executions |
| enableUserLog | `true` | Enable logging |

```xml
<Process xmlns=""
  allowSimultaneous="true"
  enableUserLog="true"
  processLogOnErrorOnly="false"
  purgeDataImmediately="false"
  updateRunDates="false"
  workload="general">
  <!-- shapes here -->
</Process>
```

See `components/process_component.md` for the full decision table of recommended process options by start step type.

## Typical Process Pattern

MCP processes typically follow this shape sequence:

```
MCP Start Shape (shape1)
    ↓
Document Properties - Extract Input Fields (shape2)
    ↓
Decision - Route by Operation Type (shape3)
    ↓ (branches for search, read, create, update, delete)
[Operation-specific handling shapes]
    ↓
Return Documents (final shape)
```

### DDP Extraction Pattern

After the start shape, use a Document Properties shape to extract JSON fields into Dynamic Document Properties:

```xml
<documentproperty
  defaultValue=""
  isDynamicCredential="false"
  isTradingPartner="false"
  name="Dynamic Document Property - DDP_OPERATION"
  persist="false"
  propertyId="dynamicdocument.DDP_OPERATION"
  shouldEncrypt="false">
  <sourcevalues>
    <parametervalue key="1" valueType="profile">
      <profileelement
        elementId="3"
        elementName="operation (Root/Object/operation)"
        profileId="{profile-guid}"
        profileType="profile.json"/>
    </parametervalue>
  </sourcevalues>
</documentproperty>
```

### DDP Naming Convention

| JSON Field | DDP Name |
|------------|----------|
| operation | DDP_OPERATION |
| projectKey | DDP_PROJECT_KEY |
| issueKey | DDP_ISSUE_KEY |
| maxResults | DDP_MAX_RESULTS |

Pattern: `DDP_[FIELD_NAME_SNAKE_UPPER]`

### Default Value Strategy

| Field Type | Recommended Default | Rationale |
|------------|---------------------|-----------|
| operation | "search" | Safe fallback, most common |
| maxResults | "50" | Balance performance/completeness |
| issueType | "Task" | Most common type |
| priority | "Medium" | Reasonable middle ground |
| Optional fields | "" | Caller provides values |

## Response Handling

MCP uses JSON-RPC 2.0. All responses go through **Return Documents** shape.

### Success Response
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "status": "success",
    "data": { ... }
  }
}
```

### Error Response (in result, not error field)
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "status": "error",
    "error_type": "validation_error",
    "message": "Missing required field: projectKey"
  }
}
```

**Error Types:** `validation_error`, `not_found`, `already_exists`, `permission_denied`, `concurrent_modification`, `unknown`

### SSE Transport Format
```
HTTP/1.1 200 OK
Content-Type: text/event-stream

data: {"jsonrpc":"2.0","id":1,"result":{...}}

```
Each event ends with double newline.

## Component Dependencies

```
MCP Start Step
  ├── references → Connection Component (by connectionId)
  │                  └── contains → Server name, Auth tokens
  └── references → Operation Component (by operationId)
                     ├── defines → Tool name, description, timeout
                     ├── defines → JSON Schema for input
                     └── references → JSON Profile (responseProfile)
```

**Build Order:**
1. Create JSON Profile (for response structure)
2. Create Connection Component
3. Create Operation Component (references profile)
4. Create Process with Start Step (references connection + operation)

## Notes

1. **Deployment**: MCP processes require on-premise runtime or runtime cluster. Pure cloud deployment NOT supported.

2. **SSL**: Not supported at connector level. Use external SSL termination via gateway or load balancer.

3. **Protocol**: Only SSE (Server-Sent Events) transport is supported. HTTP Streaming and STDIO are NOT supported.

4. **Execution Mode**: Only `general` workload supported. `low_latency` and `bridge` modes were planned but not delivered as of Jan 2026.

5. **All Paths Converge**: Every operation branch (search, read, create, update, delete) must eventually connect to the same Return Documents shape for consistent response handling.
