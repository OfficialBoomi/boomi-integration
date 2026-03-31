# Process Property Component Reference

## Contents
- Component Type
- Component Structure
- Property Definition Fields
- Data Types
- Allowed Values
- Persistence
- Process Property vs Dynamic Process Property
- Referencing in Set Properties
- Referencing in Groovy Scripts
- Environment Extensions
- Complete Examples

## Component Type
`processproperty`

Boomi component type string: `type="processproperty"` in the `bns:Component` wrapper.

Process Property components define reusable, typed collections of named values available throughout a process execution. Common uses: environment-specific configuration (API base URLs, batch sizes, feature flags), structured runtime parameters with data type validation, values that need to be overridden per-environment via extensions. 

Dynamic Process Properties are generally more versatile than process property components. Prefer to use DPPs unless there is a user request or other clear reason to use a full rigid process property component.

## Component Structure

```xml
<?xml version="1.0" encoding="UTF-8"?>
<bns:Component xmlns:bns="http://api.platform.boomi.com/"
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               componentId="" name="Order Processing Config"
               type="processproperty" folderId="{FOLDER_ID}">
  <bns:encryptedValues/>
  <bns:object>
    <DefinedProcessProperties xmlns="">
      <definedProcessProperty key="prop-batch-size">
        <helpText>Maximum records per batch</helpText>
        <label>Batch Size</label>
        <type>number</type>
        <defaultValue>100</defaultValue>
        <allowedValues/>
        <persisted>false</persisted>
      </definedProcessProperty>
      <definedProcessProperty key="prop-target-url">
        <helpText>Target system base URL</helpText>
        <label>Target URL</label>
        <type>string</type>
        <defaultValue>https://api.example.com</defaultValue>
        <allowedValues/>
        <persisted>false</persisted>
      </definedProcessProperty>
    </DefinedProcessProperties>
  </bns:object>
</bns:Component>
```

## Property Definition Fields

Each `definedProcessProperty` element defines one property in the collection.

| Element/Attribute | Type | Required | Purpose |
|---|---|---|---|
| `key` (attribute) | string | Yes | Unique identifier. GUI generates UUIDs (e.g., `f6d86c20-f274-4c60-9235-ce832fd8779c`). Programmatic creation can use descriptive keys (e.g., `prop-batch-size`). |
| `label` | string | Yes | Display name shown in GUI dialogs and environment extensions |
| `type` | enum | Yes | Data type — determines validation and GUI input behavior |
| `defaultValue` | string | Yes | Value used when no override is set. Self-closing `<defaultValue/>` for empty. |
| `helpText` | string | Yes | Description shown in GUI. Self-closing `<helpText/>` when empty. |
| `allowedValues` | element | Yes | Restricted value list (see Allowed Values section). Self-closing `<allowedValues/>` when unrestricted. |
| `persisted` | boolean | Yes | Whether value carries over to the next execution |

## Data Types

| Type | XML Value | Default Value Format | Description |
|---|---|---|---|
| String | `string` | Any text | Free-form text, optional allowed values list |
| Number | `number` | Numeric string (e.g., `"2222"`) | Numeric values, optional allowed values list |
| Boolean | `boolean` | `"true"` or `"false"` | True/false toggle |
| Date | `date` | ISO 8601 (e.g., `"2026-01-01T00:00:00Z"`) | Date values |
| Password | `password` | Plaintext string | GUI masks the value and the Environment Extensions dialog uses a secure input field, but `defaultValue` is stored and returned as plaintext by the API. Anyone with API access can read it. **Always leave `defaultValue` empty** for password-type properties — supply real values via Environment Extensions overrides only. When pulling an existing component with non-empty password `defaultValue`, warn the user and recommend migrating to Environment Extensions. |

Data types cannot be changed after a component is created and pushed to the platform. Attempting to push a type change returns HTTP 400: `"Changing the data type for the saved component '...' (key:...) is not allowed."`

## Allowed Values

String and Number types support restricted value lists via `allowedValues`. When defined, the property can only be set to one of the listed values.

```xml
<definedProcessProperty key="prop-log-level">
  <helpText>Logging verbosity</helpText>
  <label>Log Level</label>
  <type>string</type>
  <defaultValue>INFO</defaultValue>
  <allowedValues>
    <allowedValueSet label="Debug" value="DEBUG"/>
    <allowedValueSet label="Info" value="INFO"/>
    <allowedValueSet label="Warning" value="WARN"/>
    <allowedValueSet label="Error" value="ERROR"/>
  </allowedValues>
  <persisted>false</persisted>
</definedProcessProperty>
```

### allowedValueSet Attributes

| Attribute | Type | Purpose |
|---|---|---|
| `label` | string | Display name in GUI dropdown |
| `value` | string | Actual value stored and returned at runtime |

When no restrictions are needed, use self-closing: `<allowedValues/>`

When an `allowedValues` list is defined, the `defaultValue` must also be present in that list. The platform rejects a component push if `defaultValue` is not one of the listed values.

## Persistence

When `persisted` is `true`, the property's value at the end of an execution carries over as the starting value for the **next execution of the same process** on the same Atom/environment. Persistence is scoped per-process — two processes referencing the same component maintain completely independent persisted state. Writing a value in Process A does not affect what Process B sees.

- The `defaultValue` is used only for the very first execution of a given process (before any persisted value exists for that process)
- A Set Properties step or Groovy script can update the persisted value during execution

## Process Property vs Dynamic Process Property

| Aspect | Process Property Component | Dynamic Process Property (DPP) |
|---|---|---|
| Definition | Standalone component with typed fields | Created inline in Set Properties steps |
| Data types | String, Number, Boolean, Date, Password | String only |
| Validation | Type enforcement, optional allowed values | No validation |
| Environment extensions | `processProperties` section in Extensions API | `properties` section in Extensions API |
| Naming | Label + unique key per property | Freeform name (e.g., `DPP_BATCH_ID`) |
| Reusability | Same component referenced by multiple processes | Defined per-process |
| Scripting access | `ExecutionUtil.getProcessProperty(componentId, key)` | `ExecutionUtil.getDynamicProcessProperty(name)` |

Both types are available throughout the entire process execution, including across subprocess calls via Process Call steps.

## Referencing in Set Properties

Process Property component values are read as a parameter value source using `valueType="definedparameter"` with a `<definedprocessparameter>` element.

```xml
<documentproperty name="Dynamic Document Property - DDP_SAMPLE_VALUE"
                  persist="false"
                  propertyId="dynamicdocument.DDP_SAMPLE_VALUE"
                  shouldEncrypt="false">
  <sourcevalues>
    <parametervalue key="1" usesEncryption="false"
                    valueType="definedparameter">
      <definedprocessparameter
        componentId="{PROCESS_PROPERTY_COMPONENT_ID}"
        componentName="Sample process property"
        propertyKey="f6d86c20-f274-4c60-9235-ce832fd8779c"
        propertyLabel="sample1"/>
    </parametervalue>
  </sourcevalues>
</documentproperty>
```

### definedprocessparameter Attributes

| Attribute | Type | Purpose |
|---|---|---|
| `componentId` | string | Component ID of the Process Property component — functional |
| `componentName` | string | Display name of the component — GUI display only, not used at runtime |
| `propertyKey` | string | The `key` attribute of the specific property — functional |
| `propertyLabel` | string | The `label` of the specific property — GUI display only, not used at runtime |

Only `componentId` and `propertyKey` affect runtime behavior. Always include `componentName` and `propertyLabel` so the reference remains identifiable in the Boomi GUI.

## Referencing in Groovy Scripts

Access Process Property component values in Data Process (Groovy) steps or map scripting functions:

```groovy
import com.boomi.execution.ExecutionUtil;

// Read a Process Property component value
String targetUrl = ExecutionUtil.getProcessProperty(
    "{PROCESS_PROPERTY_COMPONENT_ID}", "prop-target-url");

// Set a Process Property component value
ExecutionUtil.setProcessProperty(
    "{PROCESS_PROPERTY_COMPONENT_ID}", "prop-target-url", "https://new-api.example.com");
```

The component ID must be the full GUID. The property key is the `key` attribute from the `definedProcessProperty` element.

## Environment Extensions

Process Property components integrate with environment extensions via the `DefinedProcessPropertyOverrides` section in the process XML `processOverrides`. In the Environment Extensions API, they appear in a `processProperties` section (separate from the `properties` section used by DPPs).

See `process_extensions.md` for the full `processOverrides` XML structure and Environment Extensions API patterns.

## Complete Examples

### Basic Configuration Component

Two string properties for environment-specific settings:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<bns:Component xmlns:bns="http://api.platform.boomi.com/"
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               componentId="" name="API Settings"
               type="processproperty" folderId="{FOLDER_ID}">
  <bns:encryptedValues/>
  <bns:object>
    <DefinedProcessProperties xmlns="">
      <definedProcessProperty key="prop-api-url">
        <helpText>Base URL for target API</helpText>
        <label>API Base URL</label>
        <type>string</type>
        <defaultValue>https://sandbox.example.com/api</defaultValue>
        <allowedValues/>
        <persisted>false</persisted>
      </definedProcessProperty>
      <definedProcessProperty key="prop-api-key">
        <helpText>API authentication key</helpText>
        <label>API Key</label>
        <type>password</type>
        <defaultValue/>
        <allowedValues/>
        <persisted>false</persisted>
      </definedProcessProperty>
    </DefinedProcessProperties>
  </bns:object>
</bns:Component>
```

### Mixed Types with Allowed Values

```xml
<?xml version="1.0" encoding="UTF-8"?>
<bns:Component xmlns:bns="http://api.platform.boomi.com/"
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               componentId="" name="Batch Processing Config"
               type="processproperty" folderId="{FOLDER_ID}">
  <bns:encryptedValues/>
  <bns:object>
    <DefinedProcessProperties xmlns="">
      <definedProcessProperty key="prop-batch-size">
        <helpText>Records per batch</helpText>
        <label>Batch Size</label>
        <type>number</type>
        <defaultValue>500</defaultValue>
        <allowedValues>
          <allowedValueSet label="Small (100)" value="100"/>
          <allowedValueSet label="Medium (500)" value="500"/>
          <allowedValueSet label="Large (1000)" value="1000"/>
        </allowedValues>
        <persisted>false</persisted>
      </definedProcessProperty>
      <definedProcessProperty key="prop-retry-enabled">
        <helpText>Enable automatic retry on failure</helpText>
        <label>Retry Enabled</label>
        <type>boolean</type>
        <defaultValue>true</defaultValue>
        <allowedValues/>
        <persisted>false</persisted>
      </definedProcessProperty>
      <definedProcessProperty key="prop-last-sync">
        <helpText>Timestamp of last successful sync</helpText>
        <label>Last Sync Time</label>
        <type>date</type>
        <defaultValue/>
        <allowedValues/>
        <persisted>true</persisted>
      </definedProcessProperty>
    </DefinedProcessProperties>
  </bns:object>
</bns:Component>
```