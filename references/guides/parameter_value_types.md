# Parameter Value Types Reference

Single source of truth for `<parametervalue>` elements — the dynamic value machinery shared across steps and components.

## Contents
- Purpose and Scope
- Configuration Structure
- Substitution and Evaluation
- Valid valueTypes
- GUI Picker Mapping
- Value Type Details
- Profile Element ID Mapping
- GUI Display Requirements for trackparameter
- Troubleshooting

## Purpose and Scope

The same parameter value types, XML forms, and runtime behavior apply wherever `<parametervalue>` appears:

- Notify parameters (`<notifyParameters>`) — message placeholders
- Message parameters (`<msgParameters>`) — template placeholders
- Set Properties source values (`<sourcevalues>`)
- Connector step parameters, Decision/Exception/Program Command inputs
- Nested inputs of the lookup types below (connector call, cross reference, document cache, SQL/stored procedure)

Context-specific behavior stays in the step docs: quote escaping (`references/steps/message_step.md`), `perExecution` restrictions (`references/steps/notify_step.md`), source value concatenation (`references/steps/set_properties_step.md`).

## Configuration Structure

```xml
<parametervalue key="0" usesEncryption="false" valueType="[type]">
  <!-- one child element per type; `current` and `unique` are self-closing -->
</parametervalue>
```

- `key` — arbitrary configuration-time identifier, **ignored at runtime**. The GUI writes a 0-based sequence (`key="0"`, `key="1"`, …); gaps from GUI deletions are fine; element order is what matters.
- `usesEncryption` — the GUI stamps `usesEncryption="false"` on top-level parameters and on nested inputs of `crossref`/`connector` (not on nested inputs of `sql`/`documentcache`).

## Substitution and Evaluation

Message templates (Notify `notifyMessage`, Message `msgTxt`, Exception messages) share one
substitution engine. **Placeholders substitute by XML element order, NOT the key attribute:**
- `{1}` → first `<parametervalue>` element
- `{2}` → second `<parametervalue>` element, and so on

```xml
<msgTxt>{1} {2} {3}</msgTxt>
<msgParameters>
  <parametervalue key="2" valueType="static"><staticparameter staticproperty="first"/></parametervalue>
  <parametervalue key="4" valueType="static"><staticparameter staticproperty="second"/></parametervalue>
  <parametervalue key="5" valueType="static"><staticparameter staticproperty="third"/></parametervalue>
</msgParameters>
<!-- Output: "first second third" — key values and gaps are irrelevant -->
```

- Parameters evaluate in element order, left to right. A failing parameter errors that document/path after earlier parameters have already been evaluated (earlier `keygen` counters are consumed).
- **Lookup misses** (cross reference miss, document cache miss, profile element on an empty document): in message templates the placeholder substitutes the literal string `null` — not empty string, not an error. In Set Properties source values the same misses set the target property to **empty string** (the property IS set — never the string `null`, never an error); within a concatenation a miss contributes an empty segment.
- In Set Properties, source values concatenate in element order instead of filling placeholders.

## Valid valueTypes

The platform accepts exactly these `valueType` values: `static`, `process`, `sql`, `sp`, `unique`, `track`, `profile`, `errormessage`, `execution`, `keygen`, `date`, `command`, `connector`, `current`, `crossref`, `tradingpartnerref`, `documentcache`, `definedparameter`. Anything else (e.g. `document`, `currentdata`) is rejected on push with HTTP 400.

Three of these have no GUI picker entry — do not use them:
- `errormessage` — substitutes `null` in all contexts, including Try/Catch catch paths. To log a caught error, use `track` with `meta.base.catcherrorsmessage`.
- `command` — fails the execution with `Unexpected parameter type COMMAND`.
- `tradingpartnerref` — substitutes empty string outside a trading partner context.

## GUI Picker Mapping

The standard parameter picker offers 15 entries (Document Property fans out into three sub-types):

| GUI picker entry | `valueType` | Child element |
|---|---|---|
| Static | `static` | `staticparameter` |
| Current Data | `current` | none (self-closing) |
| Date/Time | `date` | `dateparameter` |
| Document Property → Document Property | `track` | `trackparameter` (`meta.base.*`) |
| Document Property → Dynamic Document Property | `track` | `trackparameter` (`dynamicdocument.*`) |
| Document Property → MIME Property | `track` | `trackparameter` (`mime.*`) |
| Dynamic Process Property | `process` | `processparameter` |
| Process Property | `definedparameter` | `definedprocessparameter` |
| Execution Property | `execution` | `executionparameter` |
| Profile Element | `profile` | `profileelement` |
| Sequential Value | `keygen` | `keygenparameter` |
| Unique Value | `unique` | none (self-closing) |
| Connector Call | `connector` | `connectorparameter` |
| Cross Reference Lookup | `crossref` | `crossrefparameter` |
| Document Cache Lookup | `documentcache` | `documentcacheparameter` |
| SQL Statement | `sql` | `sqlparameter` |
| Stored Procedure | `sp` | `spparameter` |

## Value Type Details

### static
Hard-coded value.
```xml
<parametervalue key="1" valueType="static">
  <staticparameter staticproperty="value"/>
</parametervalue>
```

### current
The entire current document's raw content as a string. Self-closing — no child element.
```xml
<parametervalue key="1" valueType="current"/>
```

### unique
System-generated unique positive integer (18–19 digits), new value per evaluation. Self-closing — no child element.
```xml
<parametervalue key="1" valueType="unique"/>
```

### date
Date/time value with format mask. The `dateparametertype` attribute controls which date is used.

| `dateparametertype` | Description |
|---|---|
| `current` | Current date/time at execution |
| `relative` | Current date/time offset by `datedelta` |
| `last` | Start time of the previous execution, regardless of outcome |
| `lastsuccessful` | Start time of the most recent error-free execution |

**Current date/time:**
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
| `unit` | Time unit | `years`, `months`, `weeks`, `days`, `hours`, `minutes`, `seconds` |
| `value` | Amount to offset | Integer as string (e.g. `"1"`, `"30"`) |

`months` offsets are calendar-aware (day-of-month and time preserved).

**Last run date / last successful run date:**
```xml
<parametervalue key="1" valueType="date">
  <dateparameter dateparametertype="last" datetimemask="yyyyMMdd HHmmss"/>
</parametervalue>
```
- After a failed run, `last` and `lastsuccessful` diverge (`last` = the failed run's start time).
- `last` and `lastsuccessful` require `updateRunDates="true"` on the `<process>` element. On first-ever execution both render the Unix epoch in the runtime's local time zone — treat epoch as the "no prior run" sentinel.
- Run dates are tracked per process on the runtime and survive repackaging/redeployment.

**Date masks:** `datetimemask` accepts any Java SimpleDateFormat pattern, not just the GUI dropdown options. Quoted literals (e.g. `yyyy-MM-dd'T'HH:mm:ss`) render correctly — mask-level quotes are unaffected by message-level single-quote stripping. An invalid pattern passes push and deploy but fails at execution (`Illegal pattern character`).

### keygen
Auto-incrementing named counter, stored per-Runtime; view/reset in Manage > Runtime Management > Counters.
```xml
<parametervalue key="1" valueType="keygen">
  <keygenparameter keyfixtolength="[length]" keyname="[counterName]"/>
</parametervalue>
```

| Attribute | Purpose |
|---|---|
| `keyname` | Unique name for the counter. If omitted, a GUID is assigned |
| `keyfixtolength` | Pad the value with leading zeros to this length |

A fresh counter starts at 1. Increments per evaluation — per document in per-document contexts — and is consumed even if the execution later fails.

### track
Reference an existing document property value. The `propertyId` prefix selects the namespace:

| Namespace Pattern | Property Type | Example `propertyId` | Example `propertyName` |
|---|---|---|---|
| `dynamicdocument.[NAME]` | Dynamic Document Property | `dynamicdocument.DDP_USERNAME` | `Dynamic Document Property - DDP_USERNAME` |
| `meta.base.[prop]` | Standard Document Property | `meta.base.size` | `Base - Size` |
| `mime.[header]` | MIME Property | `mime.Content-Type` | `MIME Property - Content-Type` |

```xml
<parametervalue key="1" valueType="track">
  <trackparameter defaultValue="" propertyId="[namespace.property]" propertyName="[Display Name]"/>
</parametervalue>
```

Standard Document Properties (`meta.base.*`) include base metadata like `size` (document byte count). The `meta.base.*` namespace is open-ended — non-existent keys return empty without error. MIME properties include standard headers plus custom ones; they can be set in a Set Properties step (`propertyId="mime.[header]"`) and read back via `track`.

**`defaultValue` is a runtime fallback with one precise rule** (identical wherever a document is in context): it substitutes only when the tracked `dynamicdocument.*` property was **never set** in the execution. A property explicitly set to empty resolves as empty string and suppresses the fallback. `process.*` propertyIds always resolve to empty string — whether or not the DPP is set — and never trigger the fallback. With no document in context (Notify `perExecution="true"`), `track` extraction hard-fails before any fallback — see `references/steps/notify_step.md`.

**`track` cannot read DPPs.** To read Dynamic Process Properties, use `valueType="process"`.

### process
Read a Dynamic Process Property by name (case-sensitive, exact match to the name used when set).
```xml
<parametervalue key="1" valueType="process">
  <processparameter processproperty="DPP_NAME" processpropertydefaultvalue=""/>
</parametervalue>
```

| Attribute | Purpose |
|---|---|
| `processproperty` | DPP name (without `process.` prefix) |
| `processpropertydefaultvalue` | Runtime fallback if the DPP does not exist or is blank |

Does NOT resolve Process Property component values — naming a component property's label here returns empty; use `definedparameter` for those.

### execution
Read a runtime execution property. Set automatically by the engine; cannot be modified. Title case required (e.g. `"Execution Id"`, not `"Execution ID"`).
```xml
<parametervalue key="1" valueType="execution">
  <executionparameter executionproperty="Process Name"/>
</parametervalue>
```

| Value | Description |
|---|---|
| `Account Id` | Account under which the process runs |
| `Atom Id` | Runtime where the process runs |
| `Atom Name` | Name assigned to the Runtime |
| `Document Count` | Number of documents at the current step |
| `Execution Id` | Unique ID for this execution (format: `execution-{GUID}-{yyyy.MM.dd}`) |
| `Node Id` | Node ID (clusters/clouds only) |
| `Process Id` | ID of the currently executing process |
| `Process Name` | Name of the process at deploy time |

### definedparameter
Read a value from a Process Property component. When nothing has been written to the property this execution, resolves the property's `defaultValue`. See `references/components/process_property_component.md` for full details; the write counterpart is a Set Properties `documentproperty` with `propertyId="definedprocess.[componentId]@[propertyKey]"`.
```xml
<parametervalue key="1" valueType="definedparameter">
  <definedprocessparameter componentId="[componentGuid]" componentName="[Component Name]"
                           propertyKey="[propertyGuid]" propertyLabel="[PropertyLabel]"/>
</parametervalue>
```
`componentId` + `propertyKey` are functional; `componentName` + `propertyLabel` are display-only.

### profile
Extract a value from the current document using a profile element. See [Profile Element ID Mapping](#profile-element-id-mapping) for the critical `elementId`/`elementName` rules.
```xml
<parametervalue key="1" valueType="profile">
  <profileelement elementId="[id]" elementName="[path]" profileId="[guid]" profileType="profile.json"/>
</parametervalue>
```
An empty or non-matching flat file document is a lookup miss (see Substitution and Evaluation); a payload that fails profile parsing (e.g. invalid JSON against a JSON profile) errors.

### connector
Inline connector call — executes the operation live at parameter-resolution time and returns a single field from the response. Accepts input parameters for the operation's filters/inputs.
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
| `outputParamId` | Response-profile element ID of the field to return |
| `outputParamName` | Display name with path (e.g. `"fileName (File/Object/fileName)"`) |

The `inputs` block accepts any standard parameter value type. Each input requires `elementToSetId` (the filter's ID from the operation — may be operation-defined, not 1-based) and `elementToSetName` (the filter's display name, e.g. `"fileName:EQUALS"`).

### crossref
Cross Reference Table lookup — returns a single column value given one or more input column values. See `references/components/cross_reference_table_component.md` → "Cross Reference Lookup as Parameter Value Source" for full structure and multi-input examples.
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
Input `elementToSetId` values are 1-based column indexes. A table miss is a lookup miss (see Substitution and Evaluation); the input value is not passed through.

### documentcache
Document Cache lookup — retrieves a single profile element from a cached document by index and key. See `references/steps/document_cache_steps.md` → "Cache Lookup as Parameter Source" for full structure and key options.
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
A cache miss — or an unpopulated cache — is a lookup miss (see Substitution and Evaluation). A cache populated earlier in the same execution is readable.

### sql
Execute a SQL statement against a database connection and return a value from the result. **Requires a legacy database connection** — does not work with newer database connector types. The statement is a **child element**.
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
| `outputdatatype` | Output data type — valid values `1`–`4` (1 = character) |
| `cachevalues` | `true` to cache results in temporary memory for performance |

The `<parameters>` element can contain `parametervalue` entries for parameterized queries (positional — no `elementToSet*` attributes).

### sp
Execute a stored procedure against a database connection and return a value from the result. **Requires a legacy database connection.** Unlike `sql`, the procedure name is an **attribute** (`sqltoexecute="[procedure_name]"`), and the `<parameters/>` child is present even when empty.
```xml
<parametervalue key="1" valueType="sp">
  <spparameter cachevalues="false" connection="[connectionGuid]" outputdatatype="1" outputpos="1"
               sqltoexecute="[procedure_name]">
    <parameters/>
  </spparameter>
</parametervalue>
```
Attributes match `sql`, with one `sp`-specific behavior: `outputdatatype` registers the JDBC out-parameter type for the call — `1` = character (CHAR), `2` = numeric (NUMERIC), `4` = date/time (TIMESTAMP) — and the registered type must match the routine's actual return type. A mismatch fails at execution with `A CallableStatement function was executed and the out parameter 1 was of type java.sql.Types=<actual> however type java.sql.Types=<registered> was registered.`; a routine returning a type outside this set (e.g. VARCHAR) cannot be matched by any valid value. Input parameters pass to the procedure in positional order. If the procedure doesn't exist, the error is `Could not find stored procedure '[name]'`.

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
- Runtime ignores it, but correct format is required for proper GUI display

**Wrong - causes incorrect GUI display:**
```xml
<profileelement elementId="6" elementName="Name" .../>              <!-- Missing path notation -->
<profileelement elementId="61" elementName="Account/Name" .../>     <!-- Wrong format -->
```

To find the correct `elementId`, search the profile XML for `<XMLElement ... name="FieldName"` and use its `key` attribute value.

## GUI Display Requirements for trackparameter

**A Programmatic Generation Gotcha**: Missing display attributes cause "null" values in the Boomi GUI even though the step works at runtime.

**Every `<trackparameter>` element MUST include:**
- **propertyName** — human-readable label (e.g. `"Dynamic Document Property - DDP_XXX"`), display-only
- **defaultValue** — the runtime fallback (see [track](#track)); may be empty

```xml
<!-- WRONG: works at runtime but shows "null" entries in the GUI -->
<parametervalue key="1" valueType="track">
  <trackparameter propertyId="dynamicdocument.DDP_CITY"/>
</parametervalue>

<!-- CORRECT: works at runtime AND displays properly -->
<parametervalue key="1" valueType="track">
  <trackparameter defaultValue="" propertyId="dynamicdocument.DDP_CITY"
                  propertyName="Dynamic Document Property - DDP_CITY"/>
</parametervalue>
```

## Troubleshooting

**Literal `null` in output?**
- A lookup parameter failed to resolve: cross reference miss, document cache miss/unpopulated cache, or profile element on an empty document. Message templates substitute `null` without erroring. (The same misses in Set Properties source values yield empty-string properties instead.)

**HTTP 400 on push mentioning `ParameterType` enumeration?**
- The `valueType` is not one of the 18 valid values (see Valid valueTypes above).

**Date renders wrong or execution fails with `Illegal pattern character`?**
- The `datetimemask` is not a valid SimpleDateFormat pattern; push/deploy do not validate masks.

**Variables appearing literally (`{1}` in output)?**
- Quote escaping issue in the message text — see `references/steps/message_step.md` and `references/guides/boomi_error_reference.md` Issue #1.

**"null" entries in the GUI parameter list?**
- Missing `propertyName`/`defaultValue` on `trackparameter` (see GUI Display Requirements above).
