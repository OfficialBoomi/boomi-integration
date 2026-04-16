# Set Properties Step Reference

## Contents
- Purpose
- Key Concepts
- Settable Property Types
- Configuration Structure
- Source Value Concatenation
- Source Value Types
- Profile Element ID Mapping
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

### static
Hard-coded value.
```xml
<parametervalue key="1" valueType="static">
  <staticparameter staticproperty="value"/>
</parametervalue>
```

### current
Capture the entire current document's raw content as a string. Self-closing — no child element.
```xml
<parametervalue key="1" valueType="current"/>
```

### unique
System-generated unique 19-digit integer. Self-closing — no child element.
```xml
<parametervalue key="1" valueType="unique"/>
```

### date
Date/time value with format mask. The `dateparametertype` attribute controls which date is used.

**Current date/time** — snapshot at execution time:
```xml
<parametervalue key="1" valueType="date">
  <dateparameter dateparametertype="current" datetimemask="yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"/>
</parametervalue>
```

**Relative date** — offset from current date/time:
```xml
<parametervalue key="1" valueType="date">
  <dateparameter dateparametertype="relative" datetimemask="MMddyyyy">
    <datedelta sign="minus" unit="days" value="1"/>
  </dateparameter>
</parametervalue>
```

| `datedelta` Attribute | Purpose | Values |
|---|---|---|
| `sign` | Direction of offset | `plus`, `minus` |
| `unit` | Time unit | `years`, `months`, `days`, `hours`, `minutes`, `seconds` |
| `value` | Amount to offset | Integer as string (e.g. `"1"`, `"30"`) |

**Last run date** — timestamp of the previous process execution (regardless of success/failure):
```xml
<parametervalue key="1" valueType="date">
  <dateparameter dateparametertype="last" datetimemask="MMddyyyy"/>
</parametervalue>
```

**Last successful run date** — timestamp of the most recent error-free execution:
```xml
<parametervalue key="1" valueType="date">
  <dateparameter dateparametertype="lastsuccessful" datetimemask="MMddyyyy"/>
</parametervalue>
```

| `dateparametertype` | Description |
|---|---|
| `current` | Current date/time at execution |
| `relative` | Current date/time offset by `datedelta` |
| `last` | Date/time of last process execution |
| `lastsuccessful` | Date/time of last error-free execution |

`last` and `lastsuccessful` require `updateRunDates="true"` on the `<process>` element. On first-ever execution (no prior run history), both return the Unix epoch (`1970-01-01T00:00:00`) — not empty string. Processes should treat epoch as the "no prior execution" sentinel.

### keygen
Auto-incrementing sequential counter. Counter values are stored per-Runtime and can be viewed/reset in Manage > Runtime Management > Counters.
```xml
<parametervalue key="1" valueType="keygen">
  <keygenparameter keyfixtolength="[length]" keyname="[counterName]"/>
</parametervalue>
```

| Attribute | Purpose |
|---|---|
| `keyname` | Unique name for the counter. If omitted, a GUID is assigned |
| `keyfixtolength` | Pad the value with leading zeros to this length |

### track
Reference an existing property value. Covers multiple property namespaces via the `propertyId` prefix:
```xml
<parametervalue key="1" valueType="track">
  <trackparameter defaultValue="" propertyId="[namespace.property]" propertyName="[Display Name]"/>
</parametervalue>
```

| Namespace Pattern | Property Type | Example `propertyId` | Example `propertyName` |
|---|---|---|---|
| `dynamicdocument.[NAME]` | Dynamic Document Property | `dynamicdocument.DDP_USERNAME` | `Dynamic Document Property - DDP_USERNAME` |
| `meta.base.[prop]` | Standard Document Property | `meta.base.size` | `Base - Size` |
| `mime.[header]` | MIME Property | `mime.MIME-Version` | `MIME Property - MIME-Version` |

Standard Document Properties (`meta.base.*`) include base metadata like `size` (document byte count). The `meta.base.*` namespace is open-ended — non-existent keys return empty without error. MIME Properties include standard headers (`MIME-Version`, `Content-Type`, `Content-ID`, `Content-Disposition`, etc.) plus custom headers. MIME properties can be set in one Set Properties step (using `propertyId="mime.[header]"` on the `documentproperty`) and read in a subsequent step via `track`.

**`defaultValue` is GUI-only** — it is not substituted at runtime when the tracked property is empty. If a tracked property has no value, the result is empty string. Contrast with `processpropertydefaultvalue` on the `process` valueType, which IS a runtime fallback.

**Note:** To read Dynamic Process Properties, use `valueType="process"` — not `track` with `process.*`. The `track` type returns empty for DPPs set within the same process.

### process
Read a Dynamic Process Property by name. Must match the exact name used when the DPP was created (case-sensitive).
```xml
<parametervalue key="1" valueType="process">
  <processparameter processproperty="DPP_NAME" processpropertydefaultvalue=""/>
</parametervalue>
```

| Attribute | Purpose |
|---|---|
| `processproperty` | DPP name (without `process.` prefix) |
| `processpropertydefaultvalue` | Fallback value if the DPP does not exist or is blank |

### execution
Read a runtime execution property. These are set automatically by the engine and cannot be modified.
```xml
<parametervalue key="1" valueType="execution">
  <executionparameter executionproperty="Process Name"/>
</parametervalue>
```

Available `executionproperty` values (title case required — e.g. `"Execution Id"` not `"Execution ID"`):

| Value | Description |
|---|---|
| `Account Id` | Account under which the process runs |
| `Atom Id` | Runtime/Atom where the process runs |
| `Atom Name` | Name assigned to the Runtime/Atom |
| `Document Count` | Number of documents at the current step |
| `Execution Id` | Unique ID for this execution (format: `execution-{GUID}-{YYYY.MM.DD}`) |
| `Node Id` | Node ID (clusters/clouds only) |
| `Process Id` | ID of the currently executing process |
| `Process Name` | Name of the process at deploy time |

### definedparameter
Read a value from a Process Property component. See `process_property_component.md` → "Referencing in Set Properties" for full details.
```xml
<parametervalue key="1" valueType="definedparameter">
  <definedprocessparameter componentId="[componentGuid]" componentName="[Component Name]" 
                           propertyKey="[propertyGuid]" propertyLabel="[PropertyLabel]"/>
</parametervalue>
```

### profile
Extract a value from the current document using a profile element.
```xml
<parametervalue key="1" valueType="profile">
  <profileelement elementId="[id]" elementName="[path]" profileId="[guid]" profileType="profile.json"/>
</parametervalue>
```

See [Profile Element ID Mapping](#profile-element-id-mapping) for critical `elementId` and `elementName` rules.

### connector
Inline connector call — executes a connector operation and returns a single field from the response. Accepts input parameters to provide values for the operation's filters/inputs.
```xml
<parametervalue key="1" valueType="connector">
  <connectorparameter actionType="[action]" connectionId="[connectionGuid]" 
                      connectorType="[connector-type]" enforceSingleResult="true" 
                      operationId="[operationGuid]" outputParamId="[elementId]" 
                      outputParamName="[elementName (path)]">
    <inputs>
      <parametervalue elementToSetId="[filterId]" elementToSetName="[filterName]" 
                      key="0" usesEncryption="false" valueType="[type]">
        <!-- input value (profile, static, track, etc.) -->
      </parametervalue>
    </inputs>
  </connectorparameter>
</parametervalue>
```

| Attribute | Purpose |
|---|---|
| `actionType` | Operation action (CREATE, GET, QUERY, LIST, etc.) |
| `connectionId` | GUID of the connection component |
| `connectorType` | Connector technology identifier (e.g. `disk-sdk`, `http`, `salesforce`) |
| `enforceSingleResult` | When `true`, expects exactly one result document. Returns empty string on zero results (no error) |
| `operationId` | GUID of the operation component |
| `outputParamId` | Profile element ID of the field to return from the response |
| `outputParamName` | Display name with path (e.g. `"fileName (File/Object/fileName)"`) |

The `inputs` block accepts any standard parameter value type to provide values for the operation's input filters. Each input `parametervalue` requires `elementToSetId` (the filter's numeric ID from the operation) and `elementToSetName` (the filter's display name, e.g. `"fileName:EQUALS"`).

### crossref
Cross Reference Table lookup. Returns a single column value given one or more input column values. See `cross_reference_table_component.md` → "Cross Reference Lookup as Parameter Value Source" for full structure, attribute tables, and multi-input examples.
```xml
<parametervalue key="1" valueType="crossref">
  <crossrefparameter crossRefTableId="[componentGuid]" outputParamId="[colIndex]" outputParamName="[Column Name]">
    <inputs>
      <parametervalue elementToSetId="[colIndex]" elementToSetName="[Column Name]" key="0" usesEncryption="false" valueType="[type]">
        <!-- input value -->
      </parametervalue>
    </inputs>
  </crossrefparameter>
</parametervalue>
```

### documentcache
Document Cache lookup. Retrieves a single profile element from a cached document by index and key. See `document_cache_steps.md` → "Cache Lookup as Parameter Source" for full structure, attributes, and key value options.
```xml
<parametervalue key="1" valueType="documentcache">
  <documentcacheparameter docCache="[cacheComponentGuid]" docCacheIndex="[indexId]" 
                          elementId="[elementId]" elementName="[elementName]">
    <cacheKeyValues>
      <cacheKeyValue cacheKeyId="[keyId]">
        <parametervalue key="0" valueType="[type]">
          <!-- key lookup value -->
        </parametervalue>
      </cacheKeyValue>
    </cacheKeyValues>
  </documentcacheparameter>
</parametervalue>
```

### sql
Execute a SQL statement against a database connection and return a value from the result. **Requires a legacy database connection** — does not work with newer database connector types.
```xml
<parametervalue key="1" valueType="sql">
  <sqlparameter cachevalues="false" connection="[connectionGuid]" outputdatatype="1" outputpos="1">
    <sqltoexecute>[SQL SELECT statement]</sqltoexecute>
    <parameters/>
  </sqlparameter>
</parametervalue>
```

| Attribute | Purpose |
|---|---|
| `connection` | GUID of the database connection component |
| `outputpos` | 1-based column number to return from query results |
| `outputdatatype` | Data type of the output (1 = character) |
| `cachevalues` | `true` to cache results in temporary memory for performance |

The `<parameters>` element can contain `parametervalue` entries for parameterized queries.

### sp
Execute a stored procedure against a database connection and return a value from the result. **Requires a legacy database connection** — does not work with newer database connector types. Structure mirrors `sql` type.
```xml
<parametervalue key="1" valueType="sp">
  <spparameter cachevalues="false" connection="[connectionGuid]" outputdatatype="1" outputpos="1" 
               sqltoexecute="[procedure_name]">
    <parameters/>
  </spparameter>
</parametervalue>
```

The `sqltoexecute` attribute contains the stored procedure name (not a full SQL statement). The `<parameters>` element holds input parameters passed to the procedure in positional order. Attributes and behavior match the `sql` type. If the procedure doesn't exist in the database, the error is `Could not find stored procedure '[name]'`.

---

## Profile Element ID Mapping
**CRITICAL:** When referencing profile elements, the `elementId` must match the `key` attribute from the profile XML, and `elementName` must follow the GUI display format.

**Profile XML structure:**
```xml
<XMLElement dataType="character" key="6" name="Name" ...>           <!-- Root level -->
<XMLElement dataType="character" key="61" name="Name" ...>          <!-- Nested: Account/Name -->
<XMLElement dataType="character" key="149" name="Email" ...>        <!-- Nested: Owner/Email -->
```

**Correct reference with GUI format:**
```xml
<!-- Root-level field -->
<profileelement elementId="6" elementName="Name (Opportunity/Name)" profileId="..." profileType="profile.xml"/>

<!-- Nested field (1 level) -->
<profileelement elementId="61" elementName="Name (Opportunity/Account/Name)" profileId="..." profileType="profile.xml"/>

<!-- Nested field (2 levels) -->
<profileelement elementId="149" elementName="Email (Opportunity/Owner/Email)" profileId="..." profileType="profile.xml"/>
```

**elementName Format Rule:**
- Pattern: `FieldName (RootElement/Full/Path/To/FieldName)`
- Use the final segment as the field name before the parentheses
- Include complete XPath from document root in parentheses
- This format ensures proper GUI display (runtime ignores it but human readability requires correct format)

**Wrong - causes incorrect GUI display:**
```xml
<profileelement elementId="6" elementName="Name" .../>              <!-- Missing path notation -->
<profileelement elementId="61" elementName="Account/Name" .../>     <!-- Wrong format -->
```

To find the correct `elementId`, you MUST search the profile XML for `<XMLElement ... name="FieldName"` and use its `key` attribute value.

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
