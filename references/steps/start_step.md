# Start Step Reference

## Contents
- Purpose
- Key Concepts
- Configuration Options
- Common Patterns
- Reference XML Examples
- Component Dependencies
- Testing Considerations
- Implementation Notes

## Purpose
Start steps are the entry point for every Boomi process. They receive incoming documents from triggers (schedules, listeners, API calls) or test executions and pass them into the process flow.

## Key Concepts
- **Required**: Every process must have exactly one Start step
- **Two Main Modes**: Passthrough (simple) or Connector-based (listener/polling)
- **Two Simple Modes** (distinct behaviors):
  - `<noaction/>` = "No Data" in GUI - creates empty document, for scheduled/manual processes
  - `<passthroughaction/>` = "Data Passthrough" in GUI - receives documents from parent process call, for subprocesses. Still runs and behaves as a "No Data" step when standalone and not via a parent process.
- **No Multiple Starts**: If multiple starts are necessary the process should have a data passthrough start shape and be referenced via process vall by the various start possibilities.
- **Naming Convention**: Typically named "shape1" as the first shape

## Configuration Options

### 1. No Data Configuration
Creates an empty document - used for scheduled or manual processes without incoming data.

```xml
<shape image="start" name="shape1" shapetype="start" userlabel="" x="[x]" y="[y]">
  <configuration>
    <noaction/>
  </configuration>
  <dragpoints>
    <dragpoint name="shape1.dragpoint1" toShape="[nextShape]" x="[x]" y="[y]"/>
  </dragpoints>
</shape>
```

#### Process-Level Configuration for No Data
```xml
<process allowSimultaneous="false" enableUserLog="false" processLogOnErrorOnly="false" purgeDataImmediately="false" updateRunDates="true" workload="general">
```
- **updateRunDates="true"**: Scheduled processes benefit from run date tracking for incremental pulls.

### 2. Data Passthrough Configuration
Receives documents from parent process call - used for subprocesses. When run standalone (not via parent), behaves like No Data.

```xml
<shape image="start" name="shape1" shapetype="start" userlabel="" x="[x]" y="[y]">
  <configuration>
    <passthroughaction/>
  </configuration>
  <dragpoints>
    <dragpoint name="shape1.dragpoint1" toShape="[nextShape]" x="[x]" y="[y]"/>
  </dragpoints>
</shape>
```

#### Process-Level Configuration for Data Passthrough
```xml
<process allowSimultaneous="false" enableUserLog="false" processLogOnErrorOnly="false" purgeDataImmediately="false" updateRunDates="false" workload="general">
```
- **updateRunDates="false"**: Subprocesses don't need independent run date tracking.

### 3. Web Services Server Configuration (API Listener)
**CRITICAL**: WSS start steps MUST use `actionType="Listen"`. Invalid values cause empty action picklist in GUI.

Listens for incoming web service calls - the process acts as an API endpoint.

```xml
<shape image="start" name="shape1" shapetype="start" userlabel="" x="[x]" y="[y]">
  <configuration>
    <connectoraction actionType="Listen" allowDynamicCredentials="NONE" connectorType="wss" hideSettings="true" operationId="[operation_guid]">
      <parameters/>
      <dynamicProperties/>
    </connectoraction>
  </configuration>
  <dragpoints>
    <dragpoint name="shape1.dragpoint1" toShape="[nextShape]" x="[x]" y="[y]"/>
  </dragpoints>
</shape>
```

#### Web Services Server Attributes
- **actionType="Listen"**: Process waits for incoming requests
- **connectorType="wss"**: Web Services Server connector type
- **operationId**: GUID reference to the WSS operation component
- **allowDynamicCredentials="NONE"**: No dynamic authentication
- **hideSettings="true"**: Standard for listener configurations

#### Process-Level Configuration for WSS
When using WSS, the process element typically includes:
```xml
<process allowSimultaneous="true" enableUserLog="false" processLogOnErrorOnly="false" purgeDataImmediately="false" updateRunDates="false" workload="general">
```
- **allowSimultaneous="true"**: Allows multiple simultaneous executions (important for APIs)

See `components/process_component.md` for the full decision table of recommended process options by start step type.

### 4. Disk V2 LISTEN Start Configuration
Disk V2 file-watching processes use a connector start shape with `actionType="LISTEN"` and `connectorType="disk-sdk"`. See `components/diskv2_connector_operation_component.md` - LISTEN Operation for the full operation config and start shape XML.

### 5. Trading Partner Start Configuration
B2B/EDI processes use a Trading Partner Start shape with `<tradingpartneraction actionType="Listen">`. See `steps/trading_partner_steps.md` for full reference.

## Common Patterns
- Position at left side of canvas (typical x="48.0" or x="96.0")
- Connect to setup steps (Set Properties) or main logic
- For WSS: Often followed by process call to invoke main logic, then Return Documents step to send response back to caller

## Reference XML Examples

### Basic Passthrough Start
```xml
<shape image="start" name="shape1" shapetype="start" userlabel="" x="48.0" y="46.0">
  <configuration>
    <passthroughaction/>
  </configuration>
  <dragpoints>
    <dragpoint name="shape1.dragpoint1" toShape="shape2" x="224.0" y="56.0"/>
  </dragpoints>
</shape>
```

### Web Services Server Start (API Listener)
```xml
<shape image="start" name="shape1" shapetype="start" userlabel="" x="96.0" y="94.0">
  <configuration>
    <connectoraction actionType="Listen" allowDynamicCredentials="NONE" connectorType="wss" hideSettings="true" operationId="e468be9c-e350-4ed8-8841-e8001793031b">
      <parameters/>
      <dynamicProperties/>
    </connectoraction>
  </configuration>
  <dragpoints>
    <dragpoint name="shape1.dragpoint1" toShape="shape5" x="304.0" y="120.0"/>
  </dragpoints>
</shape>
```

## Component Dependencies

### For Passthrough
- None - simplest configuration

### For Web Services Server
- Requires a Web Services Server Operation component (separate component)
- Operation defines the API endpoint path, HTTP method, request/response profiles
- Referenced by GUID in the operationId attribute

**Listener Path**: For standalone WSS processes (not wrapped in API Service component), the endpoint URL is `/ws/simple/{operationType}{ObjectName}` derived from the WSS Operation component. Multiple deployed processes on the same path cause unpredictable routing - requests may hit stale versions. **Use unique, project-specific objectName values** (e.g., `productsMySpecificProject` or `products22Jan2026` instead of just `products`). See `references/guides/boomi_error_reference.md` Issue #19 for diagnostics if collision suspected.

## Testing Considerations

### Passthrough Mode
- Creates empty document by default
- Use Message step after start to create initial content if needed
- **Subprocess context**: Even when the design would normally receive content from the parent, it can still be tested in GUI - behaves like No Data trigger

### Web Services Server Mode
- Once configured as the start shape - prevents user from running in test mode via GUI
- In deployment, listens on configured endpoint
- Typically paired with Process Call shape for main business logic and Return Documents step to send response

## Implementation Notes
- Start with passthrough for initial development/testing
- Add WSS configuration when ready to expose as API
- The operation component handles the actual endpoint configuration
- Process needs allowSimultaneous="true" for concurrent API calls