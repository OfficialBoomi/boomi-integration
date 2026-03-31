# MCP Server Platform Reference

> **Technology Preview** (Jan 2026): Not production-ready. No SLA, community support only.

## Overview

The MCP (Model Context Protocol) Server Connector transforms deployed Boomi processes into AI-callable tools. AI agents discover and invoke these tools through the standardized MCP protocol.

**Connector Type:** `officialboomi-X3979C-mcp-prod`

**Use Cases:**
- Expose Boomi integrations to AI assistants (Claude, ChatGPT, etc.)
- Create tool-based interfaces for automated workflows
- Bridge enterprise systems with AI agent frameworks

## Architecture

```
AI Agent (Claude, etc.)
    ↓ MCP Protocol (SSE)
Boomi Runtime (on-premise)
    ↓
MCP Server Process
    ├── Connection Component (auth, server name)
    ├── Operation Component (tool definition, schema)
    └── JSON Profile (response structure)
```

**Component Relationships:**

| Component | Type | References |
|-----------|------|------------|
| Connection | `connector-settings` | - |
| Operation | `connector-action` | JSON Profile (responseProfile) |
| Process | `process` | Connection (connectionId), Operation (operationId) |

## URL Structure

MCP Server URLs follow this pattern:

```
http[s]://{host}:{port}/mcp/{server-name}/sse
```

| Component | Description | Example |
|-----------|-------------|---------|
| `{host}` | Runtime's IP or domain | `localhost`, `mcp.company.com` |
| `{port}` | Default MCP port | `8000` |
| `/mcp` | Protocol path segment | Fixed |
| `{server-name}` | Connection's serverName field | `shopify-mcp` |
| `/sse` | Transport type | Fixed (SSE only) |

**Examples:**
- Local: `http://localhost:8000/mcp/shopify-mcp/sse`
- Production: `https://mcp.company.com/mcp/jira-crud/sse`

**Note:** Port 8000 must be accessible. For internet-facing deployments, use a gateway/load balancer with SSL termination.

## Build Order

Components must be created in this order:

1. **Create JSON Schema** - Define tool input structure
2. **Create JSON Profile** - Import schema at build time
3. **Create Connection** - Configure server name and API tokens (use `encrypted="true"` on token properties — see `components/mcp_server_connection_component.md`)
4. **Create Operation** - Define tool (references profile)
5. **Create Process** - MCP Start Shape (references connection + operation)
6. **Deploy** - Push to on-premise runtime

**Critical:** Profile must exist BEFORE operation references it. Schema changes require reimport.

## Protocol Details

| Aspect | Supported | Not Supported |
|--------|-----------|---------------|
| Transport | SSE (Server-Sent Events) | HTTP Streaming, STDIO |
| Message Format | JSON-RPC 2.0 | - |
| Authentication | API_TOKEN | OAuth, Basic Auth |

**MCP Protocol Versions:** 2024-11-05, 2025-03-26, 2025-06-18

## Supported vs Unsupported Features

### Supported
- Tool operations (callable tools)
- API Token auth (UUID-based)
- SSE transport
- General execution mode
- On-premise runtimes and clusters

### Not Supported
- Resource/Prompt operations
- OAuth/Basic authentication
- HTTP Streaming, STDIO
- SSL at connector (use external termination)
- Output schemas, tool metadata annotations
- Low Latency/Bridge modes
- Pure cloud deployment
- Shared Web Server settings

## Integration Patterns

### Basic Tool Pattern
```
[MCP Start] → [Extract DDPs] → [Decision: route by operation] → [Handle] → [Return Documents]
```

### Multi-Operation Pattern
```
[MCP Start]
    ↓
[Extract DDPs]
    ↓
[Decision: search?] → [Search Logic] ─┐
    ↓ false                           │
[Decision: read?] → [Read Logic] ────┤
    ↓ false                           │
[Decision: create?] → [Create Logic] ┤
    ↓                                 │
[...more operations...]               │
    ↓                                 │
[Return Documents] ←──────────────────┘
```

## Client Configuration

### Claude Desktop

Add to `claude_desktop_config.json` (Settings > Developer > Edit Config):

```json
{
  "mcpServers": {
    "shopify": {
      "command": "npx",
      "args": ["mcp-remote", "http://localhost:8000/mcp/shopify/sse", "--allow-http"]
    }
  }
}
```

### MCP Inspector

Interactive testing tool: https://modelcontextprotocol.io/legacy/tools/inspector

### Amazon Q CLI

1. Install: https://docs.aws.amazon.com/amazonq/latest/qdeveloper-ug/command-line-installing.html
2. Configure MCP: https://docs.aws.amazon.com/amazonq/latest/qdeveloper-ug/command-line-mcp-config-CLI.html
3. Run `qchat`, verify MCP Server loads

### Agentstudio Integration

- Processes MUST be deployed to local runtime
- Runtime MUST be internet-accessible
- All processes for same MCP Server MUST share connection component
- Port 8000 MUST be open

## Known Limitations

1. Technology Preview - no SLA
2. Tool only - Resource/Prompt not implemented
3. SSE only - no HTTP Streaming/STDIO
4. API Token only - no OAuth/Basic Auth
5. No SSL at connector - external termination required
6. Manual profile sync - schema changes require reimport + redeploy
7. On-premise required - pure cloud not supported
8. General mode only - Low Latency/Bridge not available

## Known Issues

### 503 After Valid Authentication
- Valid token accepted, then 503 "Server Shutting Down" during init
- **Workaround:** Fresh redeployment via Platform API

### Profile/Schema Changes Not Reflected
- Updated schema not applied to tool
- **Workaround:** Reimport profile, update operation, redeploy ALL processes

### 30-Minute Session Timeout (API Control Plane)
- Sessions auto-terminate after 30 minutes
- **Workaround:** Implement session renewal in client

## Changelog

**2025-11 (Version 2, Current)**
- Fixed Purge Data Immediately / Missing Data Store issue
- Added Low Latency and Bridge Mode support
- Fixed servlet teardown for proper disposal

**2025-10 (Version 1)**
- Renamed to "MCP Server (Tech Preview)"

**2025-09**
- Initial Technology Preview release
