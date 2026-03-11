# Flow Services Server (FSS) Start Step

**FSS** is the commonly used acronym for Flow Services Server - the connector enabling Flow-to-Integration connectivity.

## Contents
- Critical Requirements
- Overview
- Step Configuration
- Process-Level Configuration
- Reference XML Examples
- Component Dependencies
- Testing Considerations
- Implementation Notes

## Critical Requirements

**FSS start steps MUST use:**
- `actionType="Listen"` - ONLY valid value for FSS listeners
- `connectorType="fss"` - Flow Services Server connector type
- `operationId` - GUID reference to FSS operation component

**Invalid actionType values cause empty action picklist in GUI.**

## Overview

The Flow Services Server (FSS) start step configures a process to receive requests from Boomi Flow. When Flow invokes an action defined in a Flow Service component, the corresponding Integration process is triggered through this start step.

FSS follows the same listener pattern as Web Services Server (WSS), but instead of exposing HTTP endpoints, it creates Flow-callable integration points.

## Step Configuration

### FSS Start Step Structure
```xml
<shape image="start" name="shape1" shapetype="start" userlabel="" x="96.0" y="94.0">
  <configuration>
    <connectoraction actionType="Listen"
                     allowDynamicCredentials="NONE"
                     connectorType="fss"
                     hideSettings="true"
                     operationId="[operation_guid]">
      <parameters/>
      <dynamicProperties/>
    </connectoraction>
  </configuration>
  <dragpoints>
    <dragpoint name="shape1.dragpoint1" toShape="[nextShape]" x="[x]" y="[y]"/>
  </dragpoints>
</shape>
```

### Connector Action Attributes

| Attribute | Value | Description |
|-----------|-------|-------------|
| `actionType` | `"Listen"` | Process waits for incoming Flow requests |
| `connectorType` | `"fss"` | Flow Services Server connector type |
| `operationId` | GUID | Reference to FSS operation component |
| `allowDynamicCredentials` | `"NONE"` | No dynamic authentication (Flow handles auth) |
| `hideSettings` | `"true"` | Standard for listener configurations |

## Process-Level Configuration

When using FSS, the process element should include:
```xml
<process allowSimultaneous="true"
         enableUserLog="false"
         processLogOnErrorOnly="false"
         purgeDataImmediately="false"
         updateRunDates="false"
         workload="general">
```

**Key attribute**: `allowSimultaneous="true"` allows multiple concurrent Flow requests to be processed.

See `components/process_component.md` for the full decision table of recommended process options by start step type.

## Reference XML Examples

### Complete FSS Process Example
```xml
<?xml version="1.0" encoding="UTF-8"?>
<bns:Component xmlns:bns="http://api.platform.boomi.com/"
           type="process"
           name="Flow Action Process"
           folderId="[folder_guid]">
  <bns:encryptedValues/>
  <bns:description/>
  <bns:object>
    <process allowSimultaneous="true"
             enableUserLog="false"
             processLogOnErrorOnly="false"
             purgeDataImmediately="false"
             updateRunDates="false"
             workload="general">
      <shapes>
        <shape image="start" name="shape1" shapetype="start" userlabel="" x="96.0" y="94.0">
          <configuration>
            <connectoraction actionType="Listen"
                             allowDynamicCredentials="NONE"
                             connectorType="fss"
                             hideSettings="true"
                             operationId="7eb18dde-2c38-4299-96a4-bf22fe6c5535">
              <parameters/>
              <dynamicProperties/>
            </connectoraction>
          </configuration>
          <dragpoints>
            <dragpoint name="shape1.dragpoint1" toShape="shape2" x="304.0" y="104.0"/>
          </dragpoints>
        </shape>
        <!-- Process logic shapes here -->
        <shape image="returndocuments_icon" name="shape3" shapetype="returndocuments" x="464.0" y="96.0">
          <configuration>
            <returndocuments/>
          </configuration>
          <dragpoints/>
        </shape>
      </shapes>
    </process>
  </bns:object>
  <bns:processOverrides/>
</bns:Component>
```

### Simple FSS Start Shape
```xml
<shape image="start" name="shape1" shapetype="start" userlabel="" x="96.0" y="94.0">
  <configuration>
    <connectoraction actionType="Listen"
                     allowDynamicCredentials="NONE"
                     connectorType="fss"
                     hideSettings="true"
                     operationId="[fss_operation_guid]">
      <parameters/>
      <dynamicProperties/>
    </connectoraction>
  </configuration>
  <dragpoints>
    <dragpoint name="shape1.dragpoint1" toShape="shape2" x="304.0" y="104.0"/>
  </dragpoints>
</shape>
```

## Component Dependencies

### Required Components
1. **FSS Operation Component** (`type="connector-action"`, `subType="fss"`)
   - Defines request/response profiles
   - Referenced by `operationId` in start step

2. **Flow Service Component** (`type="flowservice"`)
   - Makes the process discoverable by Flow
   - References the process by `processId`
   - Required for Flow to invoke the process

### Optional Components
- **Request Profile** - Defines expected input structure from Flow
- **Response Profile** - Defines response structure returned to Flow

## Testing Considerations

### GUI Test Mode Limitation
Once configured with FSS start shape, the process cannot be run in test mode via the GUI. This is the same behavior as WSS processes.

### Testing Approaches
1. **Flow Testing**: Deploy process and Flow Service, then test via Flow
2. **Subprocess Pattern**: Create a wrapper that calls the main logic as a subprocess, allowing the subprocess to be tested with passthrough start

### Deployment Requirement
FSS processes require both:
1. Process deployment to environment
2. Flow Service component deployment to same environment

## Implementation Notes

1. **Response Handling**: Use Return Documents step to send data back to Flow. Without it, Flow receives no response.

2. **Error Handling**: Wrap process logic in Try/Catch to control error responses to Flow.

3. **Timeout Awareness**: FSS operation's `syncTimeout` controls how long Flow waits. Ensure process completes within this window.

4. **Profile Alignment**: Request/response profiles in FSS operation should match the data structure Flow sends/expects.

5. **No Connection Required**: Unlike other connectors, FSS doesn't need a connection component. Platform handles connectivity.

6. **Comparison to WSS**:
   | Aspect | FSS | WSS |
   |--------|-----|-----|
   | Connector Type | `fss` | `wss` |
   | Consumer | Boomi Flow | Any HTTP client |
   | Discovery | Flow Service component | URL path |
   | Authentication | Flow-managed | Atom-configured |
   | Operation Types | `action` only | GET, CREATE, UPDATE, etc. |
