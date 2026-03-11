# Boomi Flow Platform Reference

## Contents
- Overview
- Terminology
- Architecture
- Flow Development
- Multi-Platform Development Workflow
- Integration Components
- Deployment Workflow
- Integration Patterns
- Known Constraints

## Overview

Boomi Flow is a workflow and application builder that creates user interfaces and business processes. Integration processes can be exposed to Flow through **Flow Services Server (FSS)**, allowing Flow applications to invoke Integration capabilities.

This document covers the Integration side of Flow connectivity. Flow application development is done separately — either manually in the Boomi Flow UI, or with the help of a Flow-specific skill or MCP server if available in your environment.

## Terminology

**FSS (Flow Services Server)** is the commonly used acronym for the connector and pattern that enables Flow-to-Integration connectivity. You'll see "FSS" used throughout Boomi documentation, community discussions, and this skill to refer to:
- The connector type (`connectorType="fss"`)
- FSS operations (`subType="fss"`)
- FSS start steps (listener processes for Flow)
- The overall Flow-Integration bridge pattern

## Architecture

```
Boomi Flow Application
    │
    ▼
Flow Services Connector (installed in Flow)
    │
    ▼
Flow Service Component (deployed to environment)
    │
    ▼
Integration Process (with FSS start step)
    │
    ▼
FSS Operation (defines request/response structure)
    │
    ▼
Profiles (JSON/XML data contracts)
```

### Component Relationship
```
Integration Development:
├── Profiles (optional - data contracts)
├── FSS Operation (connector-action, subType="fss")
├── Process (with FSS start step referencing operation)
└── Flow Service (references process, exposes to Flow)

Flow Development (manual or via separate Flow tooling):
├── Flow Connector (discovers Flow Services)
├── Service (binds to deployed Flow Service)
├── Types (generated from Integration profiles)
└── Flow Application (uses service actions)
```

## Flow Development

The Flow side of the solution is built separately from Integration. If you have access to a Flow-specific skill, MCP server, or other tooling, use that for Flow development. Otherwise, the user will need to build Flow components manually in the Boomi Flow UI. Boomi may release a Flow MCP server and/or skill in the future but as of mid 2026 they are not yet available.

The shared web server credentials (`SERVER_BASE_URL`, `SERVER_USERNAME`, `SERVER_TOKEN`) are relevant to Flow connectivity — Flow discovers and invokes FSS endpoints through the same shared web server used for WSS testing.

## Multi-Platform Development Workflow

When building solutions that span both Integration and Flow, follow this sequence:

### Build Order: Integration First, Then Flow

**Critical**: Always complete Integration development and deployment before building Flow components. This enables the Flow builder to discover deployed services and generate proper type bindings.

```
Phase 1: Integration Development
├── 1. Create profiles (request/response structures)
├── 2. Create FSS operation (references profiles)
├── 3. Create process with FSS start step
├── 4. Create Flow Service component
├── 5. Deploy process to environment
└── 6. Deploy Flow Service to environment

Phase 2: Flow Development (after Integration deployed)
├── 7. Discover deployed Flow Services (via Flow UI or other agentic Flow tooling (if available))
├── 8. Install Boomi Integration connector in Flow
├── 9. Create service binding to Flow Service
├── 10. Build Flow application using service actions
└── 11. Deploy/activate Flow
```

### Why This Order Matters

Flow tooling (or manual discovery in the Flow UI) queries deployed Flow Services to:
- Discover available actions
- Generate type definitions from Integration profiles
- Create proper input/output bindings

If Integration isn't deployed first, Flow development proceeds blind — no services to discover, no types to bind.

### Parallel Development

When building both Integration and Flow components:
1. Use the **boomi-integration skill** for all Integration work
2. Use Flow-specific tooling (skill, MCP server, or manual Flow UI) for Flow development
3. Always plan Integration-first, Flow-second
4. Ensure Integration deployment completes before starting Flow build

## Integration Components

### FSS Operation Component
Defines the request/response contract for Flow interactions.

```xml
<Operation>
  <Configuration>
    <FSSListenAction operationType="action"
                     requestProfile="[request_profile_guid]"
                     responseProfile="[response_profile_guid]"
                     syncTimeout="30"/>
  </Configuration>
</Operation>
```

See: `components/fss_operation_component.md`

### FSS Start Step
Configures process to receive Flow requests.

```xml
<connectoraction actionType="Listen"
                 connectorType="fss"
                 operationId="[operation_guid]">
```

See: `steps/fss_start_step.md`

### Flow Service Component
Exposes processes to Flow discovery.

```xml
<FlowService basePath="myService" name="myService">
  <flowActions name="MyAction" path="MyAction" processId="[process_guid]">
    <description/>
  </flowActions>
</FlowService>
```

See: `components/flow_service_component.md`

## Deployment Workflow

### Complete Deployment Sequence

```bash
# 1. Push all Integration components (order matters for dependencies)
# Each XML must have folderId attribute set to the target folder GUID
bash scripts/boomi-component-create.sh profiles/request.xml
bash scripts/boomi-component-create.sh profiles/response.xml
bash scripts/boomi-component-create.sh operations/fss_op.xml
bash scripts/boomi-component-create.sh processes/fss_process.xml
bash scripts/boomi-component-create.sh flow-services/my_service.xml

# 2. Deploy process (makes it executable)
bash scripts/boomi-deploy.sh processes/fss_process.xml

# 3. Deploy Flow Service (makes it discoverable by Flow)
bash scripts/boomi-deploy.sh flow-services/my_service.xml

# 4. Verify deployment (Flow should now see the service)
```

### Common Deployment Mistakes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| Forgot to deploy Flow Service | Flow connector shows no actions | Deploy Flow Service component |
| Deployed to wrong environment | Flow can't find service | Check environment IDs match |
| Process not deployed | Flow calls fail at runtime | Deploy process before Flow Service |
| Missing Return Documents step | Flow receives empty response | Add returndocuments shape to process |

## Integration Patterns

### Simple Request/Response
```
Flow sends request → FSS process executes → Response returned to Flow

Process structure:
[FSS Start] → [Process Logic] → [Return Documents]
```

### Subprocess Pattern (Testable)
```
Wrapper handles FSS, subprocess contains testable logic:

Wrapper Process:
[FSS Start] → [Process Call to Subprocess] → [Return Documents]

Subprocess (testable via GUI):
[Passthrough Start] → [Business Logic] → [Return Documents]
```

### Error Handling Pattern
```
[FSS Start] → [Try/Catch wrapping logic] → [Return Documents]
                    │
                    └── Catch path builds error response → [Return Documents]
```

### Multiple Actions Pattern
One Flow Service exposing multiple processes:
```xml
<FlowService basePath="customerOps" name="customerOps">
  <flowActions name="Get" path="Get" processId="[get_process]"/>
  <flowActions name="Create" path="Create" processId="[create_process]"/>
  <flowActions name="Update" path="Update" processId="[update_process]"/>
</FlowService>
```

## Known Constraints

1. **No Atomic Multi-Component Deployment**: Process and Flow Service must be deployed separately. No single-command deployment for both.

2. **Environment Alignment**: Flow Service and referenced process must be deployed to the same environment.

3. **Single Operation Type**: FSS only supports `operationType="action"` (unlike WSS with multiple types).

4. **No Connection Component**: FSS doesn't use a connection component - platform handles Flow-to-Integration connectivity.

5. **Sync Timeout Limits**: Flow has timeout expectations. Long-running processes may need increased `syncTimeout` in FSS operation or asynchronous patterns.

6. **Profile Discovery**: Flow generates types from deployed Integration profiles. Profile changes require redeployment and Flow service refresh.

7. **Testing Limitation**: Processes with FSS start cannot be tested via GUI. Use subprocess pattern for testability.
