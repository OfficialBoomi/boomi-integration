# Flow Service Component

## Contents
- Overview
- Component Structure
- Configuration Parameters
- Multiple Actions
- Dependencies
- Deployment Workflow
- Common Patterns
- Important Notes

## Overview

A Flow Service component wraps one or more Integration processes and exposes them as callable actions to Boomi Flow. This is a standalone component type (`type="flowservice"`) that references processes by their component ID.

Flow Services act as a discovery mechanism - Flow queries deployed Flow Service components to find available actions, then invokes those actions which trigger the corresponding Integration processes.

## Component Structure

### Single Action Configuration
```xml
<?xml version="1.0" encoding="UTF-8"?>
<bns:Component xmlns:bns="http://api.platform.boomi.com/"
           type="flowservice"
           name="[Flow Service Name]"
           folderId="[folder_guid]">
  <bns:encryptedValues/>
  <bns:description/>
  <bns:object>
    <FlowService basePath="[base_path]" name="[service_name]">
      <flowActions name="[Action Name]"
                   path="[action_path]"
                   processId="[process_guid]">
        <description/>
      </flowActions>
    </FlowService>
  </bns:object>
</bns:Component>
```

### Multiple Actions Configuration
```xml
<?xml version="1.0" encoding="UTF-8"?>
<bns:Component xmlns:bns="http://api.platform.boomi.com/"
           type="flowservice"
           name="[Flow Service Name]"
           folderId="[folder_guid]">
  <bns:encryptedValues/>
  <bns:description/>
  <bns:object>
    <FlowService basePath="customerAPI" name="customerAPI">
      <flowActions name="GetCustomer"
                   path="GetCustomer"
                   processId="[get_customer_process_guid]">
        <description>Retrieves customer details by ID</description>
      </flowActions>
      <flowActions name="CreateCustomer"
                   path="CreateCustomer"
                   processId="[create_customer_process_guid]">
        <description>Creates a new customer record</description>
      </flowActions>
      <flowActions name="UpdateCustomer"
                   path="UpdateCustomer"
                   processId="[update_customer_process_guid]">
        <description>Updates existing customer information</description>
      </flowActions>
    </FlowService>
  </bns:object>
</bns:Component>
```

## Configuration Parameters

### FlowService Attributes

| Attribute | Required | Description |
|-----------|----------|-------------|
| `basePath` | Yes | Base path identifier for the service (used in Flow connector URL) |
| `name` | Yes | Display name of the service |

### flowActions Attributes

| Attribute | Required | Description |
|-----------|----------|-------------|
| `name` | Yes | Action name displayed in Flow |
| `path` | Yes | Action path identifier (typically matches name) |
| `processId` | Yes | GUID of the Integration process to invoke |

### flowActions Child Elements

| Element | Required | Description |
|---------|----------|-------------|
| `<description/>` | No | Optional description text for the action |

### Component Attributes

| Attribute | Required | Description |
|-----------|----------|-------------|
| `type` | Yes | Must be `"flowservice"` |
| `name` | Yes | Component name for Boomi platform |
| `folderId` | Yes | Target folder GUID for organization |

## Multiple Actions

A single Flow Service can expose multiple actions, each pointing to a different process:

```xml
<FlowService basePath="orderManagement" name="orderManagement">
  <flowActions name="CreateOrder" path="CreateOrder" processId="[guid1]">
    <description>Creates a new order</description>
  </flowActions>
  <flowActions name="GetOrderStatus" path="GetOrderStatus" processId="[guid2]">
    <description>Retrieves order status</description>
  </flowActions>
  <flowActions name="CancelOrder" path="CancelOrder" processId="[guid3]">
    <description>Cancels an existing order</description>
  </flowActions>
</FlowService>
```

This allows logical grouping of related actions under a single service.

## Dependencies

### Required for Each Referenced Process
1. **Integration Process** - Must have FSS start step configured
2. **FSS Operation** - Referenced by the process's start step
3. **Profiles** - Request/response profiles if structured data is used

### Dependency Chain
```
Flow Service Component
  └── references Process (via processId)
        └── has FSS Start Step
              └── references FSS Operation (via operationId)
                    └── references Profiles (optional)
```

## Deployment Workflow

Flow Service components require a specific deployment sequence:

### Step-by-Step Deployment
```bash
# Each XML must have folderId attribute set to the target folder GUID

# 1. Create and push profiles (if needed)
bash scripts/boomi-component-create.sh active-development/profiles/request_profile.xml
bash scripts/boomi-component-create.sh active-development/profiles/response_profile.xml

# 2. Create and push FSS operation (references profiles)
bash scripts/boomi-component-create.sh active-development/operations/fss_operation.xml

# 3. Create and push process (references operation)
bash scripts/boomi-component-create.sh active-development/processes/fss_process.xml

# 4. Create and push Flow Service (references process)
bash scripts/boomi-component-create.sh active-development/flow-services/my_flow_service.xml

# 5. Deploy process to environment
bash scripts/boomi-deploy.sh active-development/processes/fss_process.xml

# 6. Deploy Flow Service to environment (CRITICAL - often forgotten)
bash scripts/boomi-deploy.sh active-development/flow-services/my_flow_service.xml
```

### Common Mistake
Forgetting to deploy the Flow Service component. The process deployment alone doesn't make it discoverable by Flow - both must be deployed.

## Common Patterns

### Simple Single-Action Service
```xml
<FlowService basePath="weatherLookup" name="weatherLookup">
  <flowActions name="GetWeather" path="GetWeather"
               processId="6c03b953-8fb6-4ec8-8466-73a1c8dbb6f8">
    <description>Returns current weather for a location</description>
  </flowActions>
</FlowService>
```

### CRUD Operations Service
```xml
<FlowService basePath="contacts" name="contacts">
  <flowActions name="Create" path="Create" processId="[create_guid]">
    <description/>
  </flowActions>
  <flowActions name="Read" path="Read" processId="[read_guid]">
    <description/>
  </flowActions>
  <flowActions name="Update" path="Update" processId="[update_guid]">
    <description/>
  </flowActions>
  <flowActions name="Delete" path="Delete" processId="[delete_guid]">
    <description/>
  </flowActions>
</FlowService>
```

## Important Notes

1. **Naming Convention**: `basePath` and `name` are often identical. Use descriptive, lowercase names without spaces (e.g., `customerAPI`, `orderManagement`).

2. **Process Requirements**: Each referenced process MUST have an FSS start step. Processes with other start types (passthrough, WSS, scheduled) cannot be called via Flow Service.

3. **Folder Placement**: Flow Service components follow standard folder rules - always specify `folderId` for proper organization.

4. **Deploy Both Components**: Both the process AND the Flow Service must be deployed to the same environment for Flow to discover and invoke actions.

5. **Update Propagation**: When updating a referenced process:
   - Push the process changes
   - Redeploy the process
   - Flow Service does NOT need redeployment (references by ID, picks up deployed version)

6. **Multiple Processes, One Service**: A Flow Service can reference multiple processes, making it a convenient way to group related Integration capabilities.

7. **Flow Connector Configuration**: In Flow, you install a "Boomi Integration" connector pointing to your runtime. The connector discovers deployed Flow Services and their actions automatically.

8. **Component Type**: This is `type="flowservice"` - a distinct component type, not a process or connector-action.
