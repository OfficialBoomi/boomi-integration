# Set Properties Step Reference

## Contents
- Purpose
- Key Concepts
- Settable Property Types
- Configuration Structure
- Source Value Concatenation
- Source Value Types (full reference: `references/guides/parameter_value_types.md`)
- Common Patterns
- Reference XML Examples

## Purpose
Set Properties steps (shapetype="documentproperties") create or update properties that travel with documents or persist across a process execution. Beyond Dynamic Document Properties (DDPs) and Dynamic Process Properties (DPPs), the step can also set MIME headers, outbound connector parameters, and Process Property component values.

**Use when:**
- Extracting values from API responses for later use
- Building dynamic URL paths or file names
- Setting timestamps for tracking
- Preparing parameters for downstream connectors (e.g. setting outbound filename before a Disk write)
- Managing state across branches
- Concatenating many data points from various locations into a single string
- Looking up values from cross reference tables, document caches, or databases
- Capturing execution metadata (process name, execution ID)
- Generating unique identifiers or sequential counters
- Setting MIME headers on documents before HTTP/mail operations
- Writing values into Process Property components for cross-process state

## Key Concepts
- **DDP vs DPP**: 
  - DDP (Dynamic Document Property): Scoped to individual documents, prefix `dynamicdocument.`
  - DPP (Dynamic Process Property): Scoped to entire process execution, prefix `process.`
- **Property Persistence**: DDPs travel with documents, DPPs persist across branches
- **Concatenation**: Multiple source values combine to build the final property value
- **Property Naming**: DDPs/DPPs typically use UPPERCASE_WITH_UNDERSCORES convention
- **Five property types**: The `propertyId` on `documentproperty` determines what is being set — see [Settable Property Types](#settable-property-types)

## Settable Property Types

The `propertyId` attribute on `documentproperty` determines what kind of property is being set:

| Property Type | `propertyId` Pattern | `name` Pattern |
|---|---|---|
| Dynamic Document Property | `dynamicdocument.[NAME]` | `Dynamic Document Property - [NAME]` |
| Dynamic Process Property | `process.[NAME]` | `Dynamic Process Property - [NAME]` |
| MIME Property | `mime.[header]` | `MIME Property - [header]` |
| Document Property (Connector) | `connector.[connectorType].[prop]` | `[Connector Display Name] - [Property Display Name]` |
| Process Property (Component) | `definedprocess.[componentId]@[propertyKey]` | `Process Property - [Component Name] - [Property Label]` |

### Dynamic Document Property (DDP)
Per-document variable. Travels with the document through branches. Each document carries its own copy.
```xml
<documentproperty name="Dynamic Document Property - DDP_USERNAME" persist="false"
                 propertyId="dynamicdocument.DDP_USERNAME" ...>
```

### Dynamic Process Property (DPP)
Process-wide single value. Last write wins. Crosses branches. Set `persist="true"` to persist the value across subsequent executions.
```xml
<documentproperty name="Dynamic Process Property - DPP_COUNTER" persist="false"
                 propertyId="process.DPP_COUNTER" ...>
```

### MIME Property
Attaches MIME headers to documents. Used before HTTP/mail connector steps. Standard headers include `Content-Type`, `Content-Disposition`, `MIME-Version`, etc. Custom headers are also supported.
```xml
<documentproperty name="MIME Property - Content-Type" persist="false"
                 propertyId="mime.Content-Type" ...>
```

### Document Property (Connector)
Sets outbound connector parameters before a connector step executes (e.g., filename for a Disk write, remote directory for FTP). The `connectorType` must match the SDK identifier used in the connector step (e.g., `disk-sdk`, `http`, `ftp`, `sftp`, `mail`). Property names use camelCase. The downstream connector honors the property automatically — no special operation configuration needed.
```xml
<documentproperty name="Disk v2 - File Name" persist="false"
                 propertyId="connector.disk-sdk.fileName" ...>
```

### Process Property (Component)
Writes a value into a Process Property component. The `propertyId` is a composite of the component GUID and the individual property key GUID, separated by `@`. This is the write counterpart to the `definedparameter` source value type (which reads from Process Property components).
```xml
<documentproperty name="Process Property - Document Details PROPS - DocumentType" persist="false"
                 propertyId="definedprocess.efe1e2bf-e03b-4c71-88a9-707c2d16db94@cd10bee6-2205-48b9-b8fc-7443f82c6d81" ...>
```

To construct the `propertyId`, use `definedprocess.[componentId]@[propertyKey]` where both IDs come from the Process Property component XML. The written value is immediately visible to `definedparameter` reads in subsequent steps within the same execution, overriding the component's default value.

## Configuration Structure
```xml
<shape image="documentproperties_icon" name="[shapeName]" shapetype="documentproperties" userlabel="[label]" x="[x]" y="[y]">
  <configuration>
    <documentproperties>
      <documentproperty defaultValue="" isDynamicCredential="false" isTradingPartner="false" 
                       name="[Display Name — see Settable Property Types]" persist="false" 
                       propertyId="[dynamicdocument.NAME | process.NAME | mime.HEADER | connector.TYPE.PROP | definedprocess.ID@KEY]" 
                       shouldEncrypt="false">
        <sourcevalues>
          <parametervalue key="[sequence]" valueType="[type]">
            <!-- Value configuration based on type -->
          </parametervalue>
        </sourcevalues>
      </documentproperty>
    </documentproperties>
  </configuration>
  <dragpoints>
    <dragpoint name="[shapeName].dragpoint1" toShape="[nextShape]" x="[x]" y="[y]"/>
  </dragpoints>
</shape>
```

## Source Value Concatenation
**Multiple source values concatenate in XML element order** to build the final property value:
```xml
<sourcevalues>
  <parametervalue key="1" valueType="static">
    <staticparameter staticproperty="/user/"/>
  </parametervalue>
  <parametervalue key="2" valueType="track">
    <trackparameter defaultValue="" propertyId="dynamicdocument.DDP_USERNAME"/>
  </parametervalue>
</sourcevalues>
<!-- Result: "/user/" + DDP_USERNAME value -->
```

**The `key` attribute is ignored at runtime** - it's a GUI-assigned identifier that persists through edits. Element order determines concatenation sequence.

## Source Value Types

Source values accept the full standard parameter value set. **See `references/guides/parameter_value_types.md`** for per-type XML forms, valid valueTypes, default fallback semantics, Profile Element ID Mapping, and `trackparameter` GUI display requirements.

Set Properties-specific notes:
- Multiple source values concatenate in XML element order (see Source Value Concatenation above).
- A lookup-type source (crossref, document cache, profile) that misses sets the target property to **empty string** — never the literal string `null` (that is message-template behavior), never an error. In a concatenation the miss contributes an empty segment (`pre_` + miss + `_post` → `pre__post`).
- To read Dynamic Process Properties use `valueType="process"` — `track` with a `process.*` propertyId always resolves empty.
- To read Process Property components use `valueType="definedparameter"`; the write counterpart is a `documentproperty` with `propertyId="definedprocess.[componentId]@[propertyKey]"` (see Settable Property Types above).
- MIME properties set here (`propertyId="mime.[header]"`) are readable in later steps via `track`.

## Common Patterns
- Build URL paths by concatenating static strings with dynamic values
- Extract values from API responses for later use
- Set timestamps for tracking
- Prepare request parameters for connectors
- Capture execution metadata for logging or error handling
- Generate unique filenames using `unique` or `keygen` combined with static strings
- Look up reference data from cross reference tables or document caches

## Reference XML Examples

### Setting Multiple Properties (DDPs)
```xml
<shape image="documentproperties_icon" name="shape4" shapetype="documentproperties" userlabel="Sets example DDPs and DPPs" x="432.0" y="48.0">
  <configuration>
    <documentproperties>
      <documentproperty defaultValue="" isDynamicCredential="false" isTradingPartner="false" 
                       name="Dynamic Document Property - DDP_USERNAME" persist="false" 
                       propertyId="dynamicdocument.DDP_USERNAME" shouldEncrypt="false">
        <sourcevalues>
          <parametervalue key="5" valueType="static">
            <staticparameter staticproperty="ccapp"/>
          </parametervalue>
        </sourcevalues>
      </documentproperty>
      <documentproperty defaultValue="" isDynamicCredential="false" isTradingPartner="false" 
                       name="Dynamic Document Property - DDP_EXAMPLE_DATETIME_PROP" persist="false" 
                       propertyId="dynamicdocument.DDP_EXAMPLE_DATETIME_PROP" shouldEncrypt="false">
        <sourcevalues>
          <parametervalue key="6" valueType="date">
            <dateparameter dateparametertype="current" datetimemask="yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"/>
          </parametervalue>
        </sourcevalues>
      </documentproperty>
    </documentproperties>
  </configuration>
  <dragpoints>
    <dragpoint name="shape4.dragpoint1" toShape="shape7" x="608.0" y="56.0"/>
  </dragpoints>
</shape>
```

### Building Concatenated Values
```xml
<shape image="documentproperties_icon" name="shape7" shapetype="documentproperties" userlabel="Prepares DDP_PATH for rest client" x="624.0" y="48.0">
  <configuration>
    <documentproperties>
      <documentproperty defaultValue="" isDynamicCredential="false" isTradingPartner="false" 
                       name="Dynamic Document Property - DDP_PATH" persist="false" 
                       propertyId="dynamicdocument.DDP_PATH" shouldEncrypt="false">
        <sourcevalues>
          <parametervalue key="1" valueType="static">
            <staticparameter staticproperty="/user/"/>
          </parametervalue>
          <parametervalue key="2" valueType="track">
            <trackparameter defaultValue="" propertyId="dynamicdocument.DDP_USERNAME" 
                          propertyName="Dynamic Document Property - DDP_USERNAME"/>
          </parametervalue>
        </sourcevalues>
      </documentproperty>
    </documentproperties>
  </configuration>
  <dragpoints>
    <dragpoint name="shape7.dragpoint1" toShape="shape5" x="800.0" y="56.0"/>
  </dragpoints>
</shape>
```

### Setting Process Properties (DPPs) from Profile Elements
```xml
<shape image="documentproperties_icon" name="shape14" shapetype="documentproperties" userlabel="Sets example DPPs" x="1200.0" y="48.0">
  <configuration>
    <documentproperties>
      <documentproperty defaultValue="" isDynamicCredential="false" isTradingPartner="false" 
                       name="Dynamic Process Property - DPP_SAMPLE_PROCESS_PROP" persist="false" 
                       propertyId="process.DPP_SAMPLE_PROCESS_PROP" shouldEncrypt="false">
        <sourcevalues>
          <parametervalue key="7" valueType="profile">
            <profileelement elementId="6" elementName="lastName (Root/Object/lastName)" 
                          profileId="75c5b9ff-7e48-40f5-91e7-a4703caa86df" profileType="profile.json"/>
          </parametervalue>
          <parametervalue key="8" valueType="static">
            <staticparameter staticproperty=", "/>
          </parametervalue>
          <parametervalue key="6" valueType="profile">
            <profileelement elementId="5" elementName="firstName (Root/Object/firstName)" 
                          profileId="75c5b9ff-7e48-40f5-91e7-a4703caa86df" profileType="profile.json"/>
          </parametervalue>
        </sourcevalues>
      </documentproperty>
    </documentproperties>
  </configuration>
  <dragpoints>
    <dragpoint name="shape14.dragpoint1" toShape="shape15" x="1376.0" y="56.0"/>
  </dragpoints>
</shape>
```
