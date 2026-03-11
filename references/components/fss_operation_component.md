# Flow Services Server (FSS) Operation Component

**FSS** is the commonly used acronym for Flow Services Server - the connector enabling Flow-to-Integration connectivity.

## Contents
- Critical Requirements
- Overview
- Component Structure
- Configuration Parameters
- Dependencies
- Common Patterns
- Important Notes

## Critical Requirements

**Start step referencing this operation MUST use:**
- `actionType="Listen"` (ONLY valid value for FSS listeners)
- `connectorType="fss"`

**Operation type is fixed:**
- `operationType="action"` - FSS only supports this single operation type

## Overview

A Flow Services Server (FSS) operation component defines an endpoint that can receive requests from Boomi Flow through the Flow Services connector. This component is used with an FSS Start step to create callable actions that Flow can invoke.

Unlike Web Services Server (WSS) which exposes HTTP endpoints, FSS creates Flow-specific integration points that are discovered and called through the Boomi Flow platform.

## Component Structure

### Standard Configuration
```xml
<?xml version="1.0" encoding="UTF-8"?>
<bns:Component xmlns:bns="http://api.platform.boomi.com/"
           type="connector-action"
           subType="fss"
           name="[Operation Name]"
           folderId="[folder_guid]">
  <bns:encryptedValues/>
  <bns:description/>
  <bns:object>
    <Operation>
      <Archiving directory="" enabled="false"/>
      <Configuration>
        <FSSListenAction operationType="action"
                         requestProfile="[request_profile_guid]"
                         responseProfile="[response_profile_guid]"
                         syncTimeout="30"/>
      </Configuration>
      <Tracking>
        <TrackedFields/>
      </Tracking>
      <Caching/>
    </Operation>
  </bns:object>
</bns:Component>
```

### Minimal Configuration (No Profiles)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<bns:Component xmlns:bns="http://api.platform.boomi.com/"
           type="connector-action"
           subType="fss"
           name="[Operation Name]"
           folderId="[folder_guid]">
  <bns:encryptedValues/>
  <bns:description/>
  <bns:object>
    <Operation>
      <Archiving directory="" enabled="false"/>
      <Configuration>
        <FSSListenAction operationType="action"
                         syncTimeout="30"/>
      </Configuration>
      <Tracking>
        <TrackedFields/>
      </Tracking>
      <Caching/>
    </Operation>
  </bns:object>
</bns:Component>
```

## Configuration Parameters

### FSSListenAction Attributes

| Attribute | Required | Description |
|-----------|----------|-------------|
| `operationType` | Yes | Must be `"action"` - the only supported value |
| `requestProfile` | No | GUID of JSON/XML profile defining expected input structure |
| `responseProfile` | No | GUID of JSON/XML profile defining response structure |
| `syncTimeout` | No | Timeout in seconds for synchronous calls (e.g., `"30"`) |

### Component Attributes

| Attribute | Required | Description |
|-----------|----------|-------------|
| `type` | Yes | Must be `"connector-action"` |
| `subType` | Yes | Must be `"fss"` |
| `name` | Yes | Descriptive operation name |
| `folderId` | Yes | Target folder GUID for organization |

## Dependencies

- **Profile Components**: When using request/response profiles for structured data
- **FSS Start Step**: References this operation component via `operationId`
- **Flow Service Component**: Wraps the process that uses this operation (for Flow discovery)

## Common Patterns

### JSON Request/Response
```xml
<FSSListenAction operationType="action"
                 requestProfile="cc77a7ff-3d76-4a71-9481-4de2ad7b8cde"
                 responseProfile="446a67a1-5190-428f-a3dd-59c339b7a8f1"
                 syncTimeout="30"/>
```

### Extended Timeout for Long Operations
```xml
<FSSListenAction operationType="action"
                 requestProfile="[request_profile_guid]"
                 responseProfile="[response_profile_guid]"
                 syncTimeout="120"/>
```

## Important Notes

1. **Single Operation Type**: Unlike WSS which has multiple operation types (GET, CREATE, UPDATE, etc.), FSS only uses `operationType="action"`.

2. **Flow Discovery**: The FSS operation alone doesn't make a process discoverable by Flow. You must also create a Flow Service component that references the process.

3. **Profile Handling**: Request and response profiles define the data contract between Flow and the Integration process. Flow passes data matching the request profile, and expects responses matching the response profile.

4. **Sync vs Async**: The `syncTimeout` attribute controls how long Flow waits for a response. For long-running processes, consider increasing this value or using asynchronous patterns.

5. **No Connection Component**: Unlike other connectors, FSS does not require a separate connection component. The platform handles the Flow-to-Integration connectivity.
