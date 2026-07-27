# Map Component Functions

## Contents
- Overview
- Function Architecture
- Available Functions
  - Connector — Connector Call
  - Custom Scripting — Scripting (inline or Map Scripting component)
  - Date — Date Format, Get Current Date
  - Language — Japanese Character Conversion
  - Lookup — Cross Reference, Simple, Document Cache, SQL
  - Numeric — Math operations, Number Format, Running Total, Sum, Count, Line Item Increment, Sequential Value
  - Properties — Get/Set Dynamic Process Property, Get/Set Document Property, Set Trading Partner, Get/Set Process Property
  - String — trims, Append/Prepend, Concat, Replace/Remove, To Lower/Upper, Split
  - User-Defined
- Complete Working Example
- Key Observations

## Overview
Map functions allow transformation logic beyond simple field-to-field mapping to be applied to individual field values as they are being mapped. They're added to the `<Functions>` element within a Map component and referenced in mappings using `fromFunction` or `toFunction` attributes.

## Function Architecture

### Key Concepts
- Functions are identified by unique `key` attributes (assigned by creation order, gaps possible from deletions)
- Functions can have multiple inputs and outputs
- Mappings reference functions using `fromFunction` or `toFunction`
- Input/output keys follow **standardized patterns by function type**:
  - **Date functions**: Output key="2" (fixed)
  - **Numeric functions**: Output key="2" (fixed)
  - **Property functions**: Output key="3" for the Dynamic Process Property and Document Property gets (`PropertyGet`, `DocumentPropertyGet`); output key="1" for the component-based `DefinedProcessPropertyGet`
  - **String functions**: Output key is a small integer assigned at creation — **not a fixed constant** (two functions with the same input shape can differ), and it may coincide with an input key (e.g. an output at key="2" alongside an input at key="2"). Mapping direction disambiguates a coinciding pair.
  - **Scripting functions**: Sequential creation order (typical pattern: define all inputs first, then outputs get next available keys)
  - **Set operations**: No outputs (side effects only)
- Functions container carries an `optimizeExecutionOrder` attribute that governs execution order (see Function Execution Order below)

### CRITICAL: Never Chain One Function Directly Into Another

**A `<Mapping>` must never have `function` on both ends.** Every mapping must have a profile on at least one side. A mapping where both `fromType="function"` and `toType="function"` wires one function's output straight into another function's input with no profile anchor — this is invalid and **must never be generated**.

**The exact rule to self-check before emitting any `<Mapping>`:** if the line contains both `fromType="function"` and `toType="function"`, it is invalid. At least one endpoint must be `fromType="profile"` or `toType="profile"`.

**FORBIDDEN — function-to-function chain:**
```xml
<!-- INVALID: both ends are function, no profile anchor -->
<Mapping fromFunction="1" fromKey="2" fromType="function"
         toFunction="2" toKey="1" toType="function"/>
```

**CORRECT Patterns**:
1. **Individual functions CAN have multiple inputs/outputs** - this is perfectly fine:
   ```xml
   <!-- Multiple inputs to one function -->
   <Mapping fromKey="5" fromType="profile" toFunction="1" toKey="1" toType="function"/>
   <Mapping fromKey="6" fromType="profile" toFunction="1" toKey="2" toType="function"/>

   <!-- Multiple outputs from one function -->
   <Mapping fromFunction="1" fromKey="3" fromType="function" toKey="10" toType="profile"/>
   <Mapping fromFunction="1" fromKey="4" fromType="function" toKey="11" toType="profile"/>
   ```

2. **For complex multi-step transformations requiring a pipeline**, prefer a User-Defined Function component (see point 3); use a single scripting function that handles all the steps internally only when the logic genuinely needs code. Never multiple chained function widgets in the map.

3. **If two functions appear to need chaining** (e.g. `Get Current Date` → `Date Format`), do NOT wire them together. Chaining is what a **User-Defined Function** component is for — a standalone `transform.function` component where step-to-step wiring is legal, referenced from the map as a single function step. See the User-Defined section below and `user_defined_function_component.md`.

### CRITICAL: Function Coordinates for GUI Rendering

Every `<FunctionStep>` MUST carry `x` and `y` canvas coordinates:
- `x="10.0"` and `y="Y_COORD"` on every function
- Start the first function at `y="10.0"` and increment ~140px per function (150.0, 288.0, …) so they don't overlap

This vertical-column layout (fixed x, increasing y) applies to map-level functions only. Steps **inside** a User-Defined Function lay out the opposite way — left-to-right, x increasing with position — see `user_defined_function_component.md`.

Coordinates do not affect API push or process execution, but **without them the GUI cannot render the map**. A single coordinate-less function is enough to break rendering, and a map that won't open also can't be repaired in the GUI — so always emit coordinates.

Other `FunctionStep` attributes beyond coordinates:

- `cacheEnabled` and `sumEnabled` are GUI-authored (typically `true`/`false` respectively — the aggregating Numeric functions Sum and Count invert them to `false`/`true`; see the Numeric section) and are **not** required for push, execution, or rendering. Emitting them matches what the GUI writes and avoids a no-op version bump when the map is first opened and saved; omitting them is harmless.
- `enabled="true"` and `cacheOption="none"` are also optional; omitting them is equivalent to these defaults (identical push, deploy, and execution). The GUI writes them inconsistently (it may omit both on a map's first function and write them on the rest), so a pulled map showing this variance is normal. A GUI-edited output port may likewise carry `isReset="false"`, another optional default.
- **Never emit `enabled="false"` — it is a trap.** The runtime ignores it (the function fires normally, no error or warning), but the GUI honors it: the function renders greyed out and locked, with no Edit/Defaults/Delete controls and no way to re-enable it from the canvas. Recovery requires re-pushing the XML with the attribute removed or set to `"true"`. To switch a function off, remove the function and its mappings.

### Function Execution Order

The `optimizeExecutionOrder` attribute on `<Functions>` controls whether the order functions run in is guaranteed:

- `optimizeExecutionOrder="true"` (default) — execution order is **not guaranteed**. Acceptable when functions are independent.
- `optimizeExecutionOrder="false"` — functions run in the order their `<FunctionStep>` elements appear in the XML.

The sequence is carried by the **document order of the `<FunctionStep>` elements**, not by the `position` attribute (`position` is a fixed per-function ordinal, like `key`, and does not track execution order). Note this is map-level behavior only — **inside a User-Defined Function component the rule inverts**: `position` is the execution-order authority there (see `user_defined_function_component.md`).

When one function depends on another — most commonly a property Set feeding a Get of the same property within one map (Dynamic and component-based Process Property pairs behave identically) — set `optimizeExecutionOrder="false"` and place the producing `<FunctionStep>` before the consuming one. Under the default `"true"`, the Get may run before the Set and read the stale or empty value.

### Function Result Caching

The optional `cacheOption` attribute on a `<FunctionStep>` reuses a function's output when it is called again with the same inputs. It is a per-function setting available across the standard function categories — offered as **None** / **By Document** / **By Map**, defaulting to **None** — but is only worth changing from the default for expensive functions such as Lookups, Connector Calls, or heavy Scripting; leave it at None for cheap functions (Math, String, Date):

- `cacheOption="none"` (**None**, default) or the attribute omitted — no caching; the function runs on every invocation.
- `cacheOption="document"` (**By Document**) — the cache is cleared after each document (reuse only within a single document's processing).
- `cacheOption="map"` (**By Map**) — the cache persists across all documents processed by the map.

This is distinct from the `cacheEnabled` flag above, and from a Document Cache component — a map function cache cannot be shared elsewhere in the process.

### Input Default Values

Any function input can carry a default value stored as a `default="…"` attribute on its `<Inputs><Input>` element (not mirrored in `<Configuration>`; an absent attribute means no default).

```xml
<Inputs>
  <Input default="STANDARD" key="1" name="customer_tier"/>
</Inputs>
```

The default is applied whenever the input's **effective value is empty** — either the input is not wired from any source, or it is mapped from a source that resolves to empty. A non-empty mapped value takes precedence and the default is ignored. (Same `empty → default` trigger as the map-level `<Defaults>` element, but stored per function input.)

### Parameter Data Types

Some function parameters carry a `dataType` attribute — `character`, `integer`, `float`, or `datetime` — on the `<Configuration>` `<Input>`/`<Output>` entry (the outer `<Inputs>`/`<Outputs>` ports carry `key`, `name`, and optionally `default`, but never `dataType`). Which functions type their parameters:

- **Scripting** — inputs carry `dataType`; outputs do not (an output's type is inferred from the value the script assigns).
- **SQL Lookup** — both inputs and outputs carry `dataType`.
- Cross Reference / Simple / Document Cache Lookup and the Date/Property/Numeric/String functions do not type their parameters.

`dataType` is not cosmetic — the incoming value is coerced to its Java type before the function uses it (under `integer`, `"007"` becomes `7`), so a non-`character` type on a zero-padded or otherwise string-semantic value can silently change a lookup match. Match the type to the key/column's semantics. See the Scripting section for the per-type Java class and null behavior.

### Minimal Functions Container
```xml
<Functions optimizeExecutionOrder="true">
  <!-- Function definitions go here -->
</Functions>
```

### Mapping References
```xml
<!-- Sending data TO a function -->
<Mapping fromKey="3" fromType="profile" 
         toFunction="1" toKey="1" toType="function"/>

<!-- Getting data FROM a function -->
<Mapping fromFunction="1" fromKey="3" fromType="function" 
         toKey="4" toType="profile"/>
```

## Available Functions

Functions come in two types, Standard and User-Defined:

- **Standard functions** — single-step built-in operations, grouped into the following categories:
  - **Connector** — Connector Call
  - **Custom Scripting** — Scripting (inline, or a referenced Map Scripting component)
  - **Date** — Date Format, Get Current Date
  - **Language** — Japanese Character Conversion
  - **Lookup** — SQL Lookup, Cross Reference Lookup, Document Cache Lookup, Simple Lookup
  - **Numeric** — Math Absolute Value, Math Add, Math Subtract, Math Multiply, Math Divide, Math Ceil, Math Floor, Math Set Precision, Number Format, Running Total, Sum, Count, Line Item Increment, Sequential Value
  - **Properties** — Get/Set Dynamic Process Property, Get/Set Document Property (with Dynamic Document Property, Document Property, and MIME Property variants), Set Trading Partner, Get/Set Process Property
  - **String** — Left/Right Character Trim, Whitespace Trim, String Append, String Prepend, String Concat, String Replace, String Remove, String To Lower, String To Upper, String Split
- **User-Defined functions** — reusable, standalone components (`type="transform.function"`) that chain multiple standard function steps together in a defined sequence. They can be shared across maps, and are consumed via `FunctionStep category="userdefined"` and `type="userdefined"`. See the User-Defined section below and `user_defined_function_component.md`.

The subsections below document the individual functions by category (the Standard functions), followed by a **User-Defined** section. Categories, functions, or configuration variants not yet implemented in this skill are marked as such — if you encounter one, inform the user that you don't have documentation for it.

### Connector

Calls out to an application connector mid-map to fetch supplemental data — the classic "look up a foreign key's display value" enrichment pattern.

#### Connector Call

Invokes a connector **operation once per source row** to fetch or enrich data during the transform. It is a map function — a `<FunctionStep type="ConnectorCall" category="Connector">` inside `<Functions>`, wired to source/target through two `<Mapping>` entries (one `toType="function"` feeding an input, one `fromType="function"` reading an output). It is **not** a process step; all connector detail lives inside the Map component. **Not supported by the Runtime Map Extension or Environment Map Extension API objects** (as with SQL Lookup).

**Two key namespaces** — getting these right is the whole task:

| Level | Where | Meaning |
|---|---|---|
| **Function slots** | `<FunctionStep><Inputs>/<Outputs>` `key` | Function-local I/O ports, referenced by `<Mapping>` `toKey`/`fromKey` with `toType`/`fromType="function"`. GUI-assigned and arbitrary — **read them, never assume** (a function can be `key="3"` with input slots `1`,`2` and output slots `3`–`7`). |
| **Binding keys** | `<ConnectorCall><Input>/<Output>` `key` | Bind each function slot to a **key in the operation's request/response profile** (or elsewhere, for some connectors — see the per-connector table). The `index` attribute equals the function-slot `key` it corresponds to. |

Value flow: source element → (`Mapping toType="function"`) → function Input slot → (`ConnectorCall Input index=slot`) → request binding key → operation runs → response binding key → (`ConnectorCall Output index=slot`) → function Output slot → (`Mapping fromType="function"`) → target element.

**Connector-agnostic skeleton** (placeholder GUIDs; this shape is what Database V2 and REST use):

```xml
<FunctionStep cacheEnabled="true" cacheOption="none" category="Connector" key="1"
              name="Connector Call" position="1" sumEnabled="false" type="ConnectorCall" x="10.0" y="10.0">
  <Inputs>
    <Input key="1" name="account_id"/>          <!-- optional default="…" used when the mapped input is empty -->
  </Inputs>
  <Outputs>
    <Output key="2" name="account_name"/>
  </Outputs>
  <Configuration>
    <ConnectorCall actionType="GET"
                   connectorType="{CONNECTOR_TYPE}"
                   connectionId="{CONNECTION_ID}"
                   operationId="{OPERATION_ID}"
                   parameter-profile="{REQUEST_PROFILE_ID}"
                   output-profile="{RESPONSE_PROFILE_ID}"
                   enforceSingleResult="true">
      <Input  index="1" key="{REQUEST_PROFILE_ELEMENT_KEY}"  name="account_id"/>
      <Output index="2" key="{RESPONSE_PROFILE_ELEMENT_KEY}" name="account_name"/>
    </ConnectorCall>
  </Configuration>
</FunctionStep>
```

The two mappings that wire it (a source element in, a target element out):
```xml
<Mapping fromKey="{SOURCE_KEY}" fromType="profile" toFunction="1" toKey="1" toType="function"/>
<Mapping fromFunction="1" fromKey="2" fromType="function" toKey="{TARGET_KEY}" toType="profile"/>
```

**`<ConnectorCall>` attributes:** `connectorType` (connector type id), `connectionId` (connection GUID), `operationId` (operation GUID to invoke), `actionType` (the operation's action — value space is connector-specific), `parameter-profile` (request binding — usually the request-profile GUID; see the HTTP exception), `output-profile` (response-profile GUID), and `enforceSingleResult` (`true` enforces exactly one result per call for enrichment semantics — see the note below). On each `<Input>`/`<Output>`, `index` equals the function-slot `key` and `key` is the bound element key. An `index` that matches no function-slot `key` is dropped **silently** — the binding is skipped, the map still completes, and the output field is simply absent (no error) — so verify `index` equals the slot `key` by inspection.

**The called operation must have bound request/response profiles.** The operation named by `operationId` needs `requestProfile`/`responseProfile` (with their `…Type`) set — those profiles supply the element keys the `<ConnectorCall><Input>/<Output>` bind to. Without a parameter profile the map **pushes without error but fails at execution**: `[Function: Connector Call]: Unable to invoke EXECUTE action for <operation>, parameters have been defined but no parameter profile has been configured.`

**Re-resolve binding keys against the live profile.** Editing an operation's profiles — notably a GUI **Import Operation** — can regenerate them in place (same component ID, renumbered keys). A stale binding key fails at execution with `[Function: Connector Call]: Error building XML from parameters.  Parameter does not exist in profile for key: N`. After any operation/profile change, re-pull the request/response profiles and resolve each binding by field **name → current key** before emitting or patching the Connector Call.

**Extra function outputs are harmless** — an `<Output>` slot declared but not wired to a target (no `fromFunction` mapping) is simply omitted from the result; the map runs clean.

**`enforceSingleResult` behavior.** This only matters for connectors/operations that emit **multiple documents from a single call** — e.g. a **Database V2 GET emits one document per row**, so a query matching N rows is an N-result call. For such a call, `enforceSingleResult="true"` errors the document (`Nested connector call returned more than 1 document.`); `="false"` does **not** error — it silently takes the **first** result document (no fan-out), which can mask an over-broad query. Set it `true` for enrichment and design the operation to return a single result. **REST and HTTP Client return exactly one result document per call** (the whole HTTP response body, even a JSON array), so the >1 branch is unreachable and `enforceSingleResult` is a no-op for them — pulling one value out of an array response is ordinary scalar-from-repeating map behavior, not this setting.

##### Per-connector binding varies — do not generalize

The `<ConnectorCall>` shell is connector-agnostic, but **what the attributes and keys bind to differs substantially by connector type**, and the differences are not derivable from first principles:

| | Database V2 | REST | HTTP Client |
|---|---|---|---|
| `connectorType` | `officialboomi-X3979C-dbv2da-prod` | `officialboomi-X3979C-rest-prod` | `http` |
| `parameter-profile` | request-profile **GUID** | request-profile **GUID** | literal `EMBEDDED\|HttpParameterChooser\|<operationId>` |
| `<Input key>` binds to | request-profile element key | request-profile element key | **path-element key** (GET) or request-profile key (Send) |
| `<Output key>` binds to | response-profile element key | response-profile element key | response-profile element key |
| `actionType` | `GET`/`CREATE`/… (upper) | `GET`/`POST`/… (matches operation) | `Get`/`Send` (title-case) |

Database V2 and REST share the skeleton above. **HTTP Client is the outlier**: its `parameter-profile` is a literal sentinel (not a GUID), and for a `HttpGetAction` operation the `<Input key>` values are **path-element keys** from the operation (large ids like `2000001`), not request-profile keys:

```xml
<!-- HTTP Client GET: inputs bind to path-element keys; parameter-profile is a literal -->
<ConnectorCall actionType="Get" connectorType="http" connectionId="{CONNECTION_ID}"
               operationId="{OPERATION_ID}" output-profile="{RESPONSE_PROFILE_ID}"
               enforceSingleResult="true"
               parameter-profile="EMBEDDED|HttpParameterChooser|{OPERATION_ID}">
  <Input  index="1" key="2000001" name="latitude"/>   <!-- path-element key, not a profile key -->
  <Output index="3" key="7" name="temperature"/>      <!-- response-profile element key -->
</ConnectorCall>
```
An HTTP Client `HttpSendAction` (POST/Send) instead binds `<Input key>` to request-profile element keys (the POST body), like Database V2.

##### Authoring rule: only auto-emit verified connector templates

Because the binding XML is connector-specific and unforecastable, **only auto-author a Connector Call for a connector type with a documented template — currently Database V2, REST, and HTTP Client.** For any other connector type:
1. Build everything else (the operation with request/response profiles, source/target profiles, the passthrough Map, the process), then
2. **Tell the user to add the Connector Call function itself in the GUI**, and offer to pull the map afterward to capture and verify the wiring — rather than emitting guessed `<ConnectorCall>` XML that will likely fail.

**Database (Legacy)** (`connectorType="database"`) is not usable in a Connector Call — use SQL Lookup for a Database (Legacy) lookup instead. The platform does **not** reject `connectorType="database"` on push (a map carrying it saves cleanly); the exclusion lives in the GUI connector picker, so never *emit* it. For **Database V2**, a Get (parameterized or not) is fully API-authorable and needs no GUI Import — **but its operation XML must include `<field id="schemaName" type="string" value=""/>`**. Without it the Get executes yet silently returns zero rows, so the Connector Call enriches nothing. Request/response profiles may be hand-authored. See `databasev2_connector_operation_component.md`.

### Custom Scripting

**Purpose**: Custom field-level transformation logic via the **Scripting** function, written in Groovy or JavaScript

**Critical Concept**: The names you define for inputs/outputs become BOTH:
- The mappable nodes visible in the Boomi GUI
- The actual variable names available in your script

For example, if you define `<Input key="1" name="customer_name"/>`, then:
- "customer_name" appears as a mappable node in the GUI
- `customer_name` is directly available as a variable in your script — it's pre-declared, so don't re-declare it

**Minimal Configuration**:
```xml
<FunctionStep category="Scripting" cacheEnabled="true" key="1" name="Scripting"
              position="1" sumEnabled="false" type="Scripting" x="10.0" y="10.0">
  <Inputs>
    <Input key="1" name="first_input"/>
    <Input key="2" name="second_input"/>
  </Inputs>
  <Outputs>
    <Output key="3" name="first_output"/>
    <Output key="4" name="second_output"/>
  </Outputs>
  <Configuration>
    <Scripting language="groovy2">
      <ScriptToExecute><![CDATA[
// Input variables are automatically available by the names you defined
// first_input and second_input are directly usable here

// Process the inputs
String processedValue = first_input + " - " + second_input

// Set output variables by the names you defined
first_output = processedValue
second_output = "some other value"
      ]]></ScriptToExecute>
      <Input dataType="character" index="1" name="first_input"/>
      <Input dataType="character" index="2" name="second_input"/>
      <Output index="3" name="first_output"/>
      <Output index="4" name="second_output"/>
    </Scripting>
  </Configuration>
</FunctionStep>
```

**Observed Patterns**:
- XML entities in script: `>` becomes `&gt;`, `<` becomes `&lt;`
- Input names are defined twice (in Inputs section and Configuration/Scripting section)
- Index values in Configuration match key values in Inputs/Outputs
- Outputs bind by assignment to the named output variable; a `return` statement is not needed for output binding (a returned value is ignored)

**Script storage form**: author the script body in CDATA (`<![CDATA[ ... ]]>`) or entity-escaped — both are accepted on create. The platform stores and returns it entity-escaped, never CDATA (so a CDATA-authored local copy shows a cosmetic diff against the pulled copy).

**Input Data Types**: each `<Input>` in the `<Configuration><Scripting>` section carries a `dataType` that sets the Java type and null behavior of the script variable:

| `dataType` | Java type | Null behavior |
|------------|-----------|---------------|
| `character` | `java.lang.String` | Never null — a null, blank, or omitted source value becomes `""` |
| `integer` | `java.lang.Long` | Can be null |
| `float` | `java.lang.Double` | Can be null (double-precision; out-of-range values are rounded) |
| `datetime` | `java.util.Date` | Can be null |

Leave an input as `character` for text fields, but **for numeric or date fields prefer the real `dataType`**: an `integer`/`float`/`datetime` input arrives as a ready-to-use Java `Long`/`Double`/`Date` (a `datetime` is a `Date` you format directly), sparing you the manual string parsing that `character` would force. Typed values can be null, so null-check before operating (and test a date with `instanceof Date` rather than parsing a string). The function-input `dataType` above is a distinct vocabulary from a profile field's `dataType`: a profile field of type `number` feeds an `integer` or `float` function input, and a profile field of type `datetime` feeds a `datetime` function input. Outputs carry no `dataType` — their type is inferred from the value the script assigns.

**Scripting language**: the `language` attribute selects the script language, for both inline scripts and Map Scripting components:

| Language | `language` value |
|-----------|------------------|
| Groovy 1.5 | `groovy` |
| Groovy 2.4 | `groovy2` |
| JavaScript | `javascript` |

**Default to `groovy2` (Groovy 2.4)** — it is consistent with the rest of the skill's scripting and handles the typed inputs above as native Java objects. Avoid Groovy 1.5 for new work. Use JavaScript only on explicit request or when existing assets are JavaScript: it runs on the Nashorn engine (access Java classes via `Packages`/`importClass`) and does not support Java-style `class` declarations. Outputs bind by assignment to the named output variable in every language — a `return` value is ignored.

**Inline vs. reusable component**: an inline script lives only in its own map; a standalone `script.mapping` component can be referenced by multiple maps and tracked as its own component. Use inline for a single-map transformation, and a component when the same script is (or may be) reused across maps — both are equally valid. See `map_script_component.md`.

### Date

Date functions reformat or generate date/time values.

#### Date Format

**Purpose**: Convert date strings between formats

**CRITICAL**: All three inputs are required. The input/output mask parameters must have default values or be mapped - the function fails without them.

**Minimal Configuration**:
```xml
<FunctionStep cacheEnabled="true" category="Date" key="3" name="Date Format"
              position="3" sumEnabled="false" type="DateFormat" x="10.0" y="150.0">
  <Inputs>
    <Input key="1" name="Date String"/>
    <Input key="2" name="Input Mask" default="yyyyMMdd HHmmss"/>
    <Input key="3" name="Output Mask" default="yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"/>
  </Inputs>
  <Outputs>
    <Output key="2" name="Result"/>
  </Outputs>
  <Configuration/>
</FunctionStep>
```

**Output Key Pattern**: Date functions standardize on output key="2"
- Uses Java SimpleDateFormat patterns
- Input/Output masks require default values or profile mappings

**CRITICAL - Mask Selection Based on Profile dataType:**
- **Input Mask**: If source field is `dataType="datetime"`, use `yyyyMMdd HHmmss.SSS`. If source is character, match actual data format.
- **Output Mask**: If target field is `dataType="datetime"`, use `yyyyMMdd HHmmss.SSS`. If target is character, use desired format.

See map_component.md "Datetime Field Mapping" section for complete decision matrix.

#### Get Current Date

**Purpose**: Generate current timestamp

**Minimal Configuration**:
```xml
<FunctionStep cacheEnabled="true" category="Date" key="4" name="Get Current Date"
              position="4" sumEnabled="false" type="CurrentDate" x="10.0" y="288.0">
  <Inputs/>
  <Outputs>
    <Output key="2" name="Result"/>
  </Outputs>
  <Configuration/>
</FunctionStep>
```

**Output Key Pattern**: Date functions standardize on output key="2"

**Output format**: the Boomi internal datetime format `yyyyMMdd HHmmss.SSS` (e.g. `20260721 083015.994`) — note the milliseconds. To reformat, feed the result to a Date Format function with `yyyyMMdd HHmmss.SSS` as the Input Mask; since one function must never feed another inside a plain map, do the chaining inside a User-Defined Function (see `user_defined_function_component.md`).

### Language

Alphabet and character transliteration.

#### Japanese Character Conversion

Convert an input string between supported Japanese character sets — Katakana and Hiragana (full-width or half-width). **Not yet implemented in this skill** — if you encounter one, inform the user that you don't have documentation for it.

### Lookup

Lookup functions retrieve values from an external system, component, or embedded table by matching on one or more inputs.

#### Cross Reference Lookup

**Purpose**: Look up values from a Cross Reference Table component by matching one or more input columns and returning one or more output columns.

**Minimal Configuration**:
```xml
<FunctionStep cacheEnabled="true" cacheOption="none" category="Lookup"
              key="1" name="Cross Reference Lookup" position="1"
              sumEnabled="false" type="CrossRefLookup" x="10.0" y="10.0">
  <Inputs>
    <Input key="1" name="source_code"/>
  </Inputs>
  <Outputs>
    <Output key="2" name="target_code"/>
  </Outputs>
  <Configuration>
    <CrossRefLookup crossRefTableId="{CROSSREF_COMPONENT_ID}"
                    skipLookupIfNoInputs="true">
      <Input index="1" name="source_code" refId="1"/>
      <Output index="2" name="target_code" refId="2"/>
    </CrossRefLookup>
  </Configuration>
</FunctionStep>
```

**Key details:**
- `refId` is 1-based (column 1 = first `columnHeader` in the table)
- `index` in Configuration must match the `key` of the corresponding Input/Output — a mismatch errors at execution, not at push
- Multiple inputs match as an AND over all columns; multiple outputs are supported. When more than one row matches, the first row wins
- `skipLookupIfNoInputs="true"` skips the lookup on empty input; `"false"` makes an empty input match the first row (silent wrong data) — prefer `"true"`

See `cross_reference_table_component.md` for full details: multi-input examples, parameter value usage outside maps, match types, column indexing, and lookup behavior.

#### Simple Lookup

**Purpose**: Translate a key to a value using a small key/value table **embedded in the function** — no separate component. Use it for a fixed, map-local mapping (e.g. code → label); use Cross Reference Lookup instead when the table is shared across maps.

**Minimal Configuration**:
```xml
<FunctionStep cacheEnabled="true" cacheOption="none" category="Lookup" key="1"
              name="Simple Lookup" position="1" sumEnabled="false"
              type="SimpleLookup" x="10.0" y="10.0">
  <Inputs><Input key="1" name="Key"/></Inputs>
  <Outputs><Output key="1" name="Value"/></Outputs>
  <Configuration>
    <SimpleLookup>
      <Input index="1" refId="1"/>
      <Output index="1" refId="2"/>
      <CrossRefTableObj>
        <CrossRefTable atomEnabled="false" modelVersion="3">
          <ColumnHeaders>
            <columnHeader>Key</columnHeader>
            <columnHeader>Value</columnHeader>
          </ColumnHeaders>
          <Rows>
            <row><Values><ref colIdx="0" value="US"/><ref colIdx="1" value="United States"/></Values></row>
            <row><Values><ref colIdx="0" value="CA"/><ref colIdx="1" value="Canada"/></Values></row>
          </Rows>
        </CrossRefTable>
      </CrossRefTableObj>
    </SimpleLookup>
  </Configuration>
</FunctionStep>
```

Wire it into the map — the input and output ports both use `key="1"`, so mapping direction disambiguates them:
```xml
<Mapping fromKey="{SOURCE_FIELD_KEY}" fromType="profile" toFunction="1" toKey="1" toType="function"/>
<Mapping fromFunction="1" fromKey="1" fromType="function" toKey="{TARGET_FIELD_KEY}" toType="profile"/>
```

**Key details:**
- The lookup table is stored **inline** as `<CrossRefTableObj><CrossRefTable>`, not referenced by ID — the structural difference from Cross Reference Lookup. Carry `atomEnabled="false"` and `modelVersion="3"` verbatim (GUI-authored table metadata).
- Input `Key` and output `Value` both use `key="1"`. Each `<Input>`/`<Output>` `index` matches its port `key`; `refId` is 1-based over columns (`refId="1"` → first column / `colIdx="0"`, `refId="2"` → second column).
- Rows serialize as `<row><Values><ref colIdx="N" value="…"/></Values></row>` (zero-based `colIdx`).
- **Duplicate keys** resolve **first-match-wins** in row order (later duplicates are ignored, no error); nothing prevents duplicates, so enforce key uniqueness yourself.
- **No match:** the document still flows, but the target field is left unwritten — the output serializes with the field absent (not `""`). Handle the empty case downstream.
- **Cannot be pushed inside a User-Defined Function via the Component API**: the `transform.function` component schema rejects the embedded lookup table on create (HTTP 400), though the identical XML is accepted in a map. When a static key/value table is needed inside a UDF, use a Cross Reference Lookup instead — the same platform-stored table, externalized into a `crossref` component.

#### Document Cache Lookup

**Purpose**: Retrieve fields from a document previously stored in a Document Cache component, matching on one of the cache's indexes — typically to enrich a document with data cached earlier in the process. See `document_cache_component.md`.

**Minimal Configuration**:
```xml
<FunctionStep cacheEnabled="true" cacheOption="none" category="Lookup" key="1"
              name="Document Cache Lookup" position="1" sumEnabled="false"
              type="DocumentCacheLookup" x="10.0" y="10.0">
  <Inputs>
    <Input key="3" name="id"/>
  </Inputs>
  <Outputs>
    <Output key="1" name="name"/>
    <Output key="2" name="color"/>
  </Outputs>
  <Configuration>
    <DocumentCacheLookup cacheIndex="1" docCache="{DOC_CACHE_COMPONENT_ID}">
      <Input index="3" keyId="2" name="id"/>
      <Output index="1" key="4" name="name"/>
      <Output index="2" key="5" name="color"/>
    </DocumentCacheLookup>
  </Configuration>
</FunctionStep>
```

**Key details:**
- `docCache` is the Document Cache **component ID**; `cacheIndex` is that cache's `CacheIndex/@indexId` value (not a zero-based position).
- Each Configuration `<Input keyId="…">` binds the input to a specific cache key (the cache's `cacheKey/@id`) — this selects which index key is matched. `<Input>`/`<Output>` `index` matches the function's own port `key`.
- Each `<Output key="…">` is an element **key in the cache's profile** (not the target profile) — the field pulled from the cached document.
- **A key matching more than one cached document errors** (`Found more than 1 document in the document cache …`) and fails the map. Use an index that is unique for the key; if you need one-output-per-match fan-out, that is a Document Cache join, not this function.
- A no-match returns empty (output fields omitted, no error; the document still flows).

#### SQL Lookup

**Purpose**: Run a SELECT (or stored procedure) against a **Database (Legacy) connection** and return column values — typically a cross-reference lookup or supplemental data pulled from a database.

**Minimal Configuration** (Standard SELECT):
```xml
<FunctionStep cacheEnabled="true" cacheOption="none" category="Lookup" key="1"
              name="Sql Lookup" position="1" sumEnabled="false" type="SqlLookup"
              x="10.0" y="10.0">
  <Inputs>
    <Input key="3" name="lookup_key"/>
  </Inputs>
  <Outputs>
    <Output key="2" name="name"/>
  </Outputs>
  <Configuration>
    <SqlLookup connection="{DATABASE_LEGACY_CONNECTION_ID}"
               executionType="sql" spResultOption="resultset"
               storedProcedureName="">
      <SqlToExecute>SELECT name FROM acc_name WHERE name = ?</SqlToExecute>
      <Input dataType="character" index="3" name="lookup_key"/>
      <Output dataType="character" index="2" name="name"/>
    </SqlLookup>
  </Configuration>
</FunctionStep>
```

**Key details:**
- `connection` is the **Database (Legacy) connection** component ID — the function owns its SQL directly; no operation component or database profile is involved.
- `executionType` is the mode switch: `"sql"` (Standard — statement in `<SqlToExecute>`, `storedProcedureName` empty) or `"storedproc"` (Stored Procedure — `storedProcedureName` populated, `<SqlToExecute>` empty). For stored procedures, `spResultOption` is the Result Option — `"resultset"` (Result Set) or `"paramoutputs"` (Output Parameters); it is inert for Standard. The input/output binding is identical for both result options.
- One `<Input>` per `?` parameter (positional), one `<Output>` per selected column. Both are double-declared: the outer `<Inputs>`/`<Outputs>` ports and the `<Configuration>` `<Input>`/`<Output>` entries, whose `index` matches the port `key` and which carry `dataType`. A statement with no `?` needs no inputs (empty `<Inputs/>`) — valid for a constant or probe query.
- A no-match leaves the target field unwritten (empty document, not `""`), like the other Lookup functions. Consider `cacheOption="map"` for a lookup called repeatedly with the same key.
- The Runtime Map Extension and Environment Map Extension API objects do **not** support SQL Lookup (nor Connector Call).

### Numeric

Mathematical operations, number formatting, and counters. Every Numeric function is a `<FunctionStep category="Numeric">` with a distinct `type`, a single output port `<Output key="2" name="Result"/>` (**output key="2" is universal across all Numeric functions** — read a result with `fromFunction="N" fromKey="2"`), and input ports keyed `key="1"`, `key="2"`, `key="3"` in port order. Parameters are carried as `<Input default="…">` ports with an empty `<Configuration/>`; **only Sequential Value** carries a populated `<Configuration>`. Numeric parameters do not carry `dataType`.

**Author each function by its `type` (in the subsection heading below), not its common name — they differ.** One collision is dangerous: **"Running Total" persists as `type="Sum"`, while "Sum" persists as `type="Sum2"`.** Getting these backwards silently builds the wrong function.

**Input default overridden by a wired mapping.** An `<Input default="…">` value is the effective input only when that input is unwired; a mapping into the input takes precedence (same empty→default rule as other functions).

**Flags on the aggregating functions.** Most Numeric functions carry `cacheEnabled="true" cacheOption="none" sumEnabled="false"`. **Sum (`Sum2`) and Count (`Count`) instead carry `cacheEnabled="false" sumEnabled="true"` and omit `cacheOption`.** These flags are cosmetic and inert at request time — setting `sumEnabled="false"` does not stop Sum aggregating. Emit them as shown to match what the platform writes, but aggregation is a property of the function `type`, not the flag.

**Scalar vs. per-record vs. aggregating.** Three behavioral shapes, and the **target profile shape** decides how multi-record results surface:
- **Scalar Math** (Absolute Value, Add, Subtract, Multiply, Divide, Ceil, Floor, Set Precision, Number Format) — one Result per invocation.
- **Per-record counters** (Running Total, Line Item Increment, Sequential Value) — emit one value **per output row**. The number of values equals the number of rows the map produces, so **drive iteration with a source→repeating-target mapping**: a lone `function→target` mapping (no source field mapped into the repeating element) yields a single row and the counter fires only once.
- **Aggregators** (Sum, Count) — collapse across records, producing one value **per unique Reset Value**. Into a **scalar/header** target → **one output document per unique Reset Value**; into a **repeating/detail** target → the group's aggregate is **broadcast onto every member row** of that group.

**Exact-decimal arithmetic and error behavior.** Math functions compute in exact decimal, not binary float — `0.1 + 0.2` is exactly `0.3` and `1.1 × 3` is exactly `3.3`, with no drift. A **non-numeric input aborts the whole document** (a `NumberFormatException`-class error), as do a structurally invalid parameter (Number Format with an empty output mask, Set Precision with a non-integer precision) and Math Divide by zero — the same document-failing behavior as any erroring map function. By contrast an **empty or absent operand falls back to that input's `default`** (Math Add with an empty second operand computes as `+ 0`) and does not error.

#### Math Absolute Value (`MathAbs`)

Absolute value of the single `Value` input (`-37.5` → `37.5`).

```xml
<FunctionStep cacheEnabled="true" cacheOption="none" category="Numeric" key="1"
              name="Math Absolute Value" position="1" sumEnabled="false"
              type="MathAbs" x="10.0" y="10.0">
  <Inputs><Input default="" key="1" name="Value"/></Inputs>
  <Outputs><Output key="2" name="Result"/></Outputs>
  <Configuration/>
</FunctionStep>
```

#### Math Add / Subtract / Multiply / Divide (`MathAdd` / `MathSubtract` / `MathMultiply` / `MathDivide`)

Two inputs — `Value` (key=1) and the operand (key=2, named "Value to Add" / "Value to Subtract" / "Value to Multiply" / "Value to Divide"). The operand may be a static default or wired from a source field. Examples: `12 + 5 = 17`, `12 − 3 = 9`, `12 × 2 = 24`, `12 ÷ 4 = 3`.

```xml
<FunctionStep cacheEnabled="true" cacheOption="none" category="Numeric" key="2"
              name="Math Add" position="2" sumEnabled="false"
              type="MathAdd" x="10.0" y="104.0">
  <Inputs>
    <Input default="" key="1" name="Value"/>
    <Input default="0" key="2" name="Value to Add"/>
  </Inputs>
  <Outputs><Output key="2" name="Result"/></Outputs>
  <Configuration/>
</FunctionStep>
```

> **Math Divide by zero errors the function and fails the whole document** — `java.lang.ArithmeticException: Division by zero`; no output document is produced and the process ends in ERROR. Guard the divisor, and isolate any divide that might hit zero (an erroring function aborts the document's downstream flow — the same behavior as any erroring map function).

**Divide result scale:** a non-terminating quotient does **not** error — it is carried to **10 decimal places, rounded HALF_UP** (`10 ÷ 3 → 3.3333333333`, `2 ÷ 3 → 0.6666666667`). Precision beyond 10 places is lost, so account for it when a ratio must stay exact.

#### Math Ceil (`MathCeil`) / Math Floor (`MathFloor`)

Round the single `Value` to a whole number — Ceil rounds up, Floor rounds down (`8.675` → `9` / `8`).

```xml
<FunctionStep cacheEnabled="true" cacheOption="none" category="Numeric" key="6"
              name="Math Ceil" position="6" sumEnabled="false"
              type="MathCeil" x="10.0" y="576.0">
  <Inputs><Input default="" key="1" name="Value"/></Inputs>
  <Outputs><Output key="2" name="Result"/></Outputs>
  <Configuration/>
</FunctionStep>
```

`MathFloor` is identical but for `type="MathFloor"`.

#### Math Set Precision (`MathPrecision`)

Round `Value` (key=1) to `Number of Precision` (key=2) decimal places (`8.675` at precision `2` → `8.68`). The precision input accepts a static default or a wired source value. **Rounding is HALF_UP** (half rounds away from zero): `0.125 @ 2 → 0.13`, `−2.5 @ 0 → −3`. A precision **greater than** the value's decimals **pads trailing zeros** to that scale (`8.6 @ 4 → 8.6000`), and precision `0` yields an integer. The precision must be a whole number — a non-integer precision errors the document.

```xml
<FunctionStep cacheEnabled="true" cacheOption="none" category="Numeric" key="8"
              name="Math Set Precision" position="8" sumEnabled="false"
              type="MathPrecision" x="10.0" y="764.0">
  <Inputs>
    <Input default="" key="1" name="Value"/>
    <Input default="2" key="2" name="Number of Precision"/>
  </Inputs>
  <Outputs><Output key="2" name="Result"/></Outputs>
  <Configuration/>
</FunctionStep>
```

#### Number Format (`NumberFormat`)

Reformat `Number String` (key=1) from `Input Mask` (key=2) to `Output Mask` (key=3), using Java DecimalFormat-style masks. **The result is a string**, rounded to the output mask's decimals (`8.675` with input mask `#0.00` and output mask `#,##0.00` → `"8.68"`). Map the result into a `character` target field. You can often avoid Number Format by giving the source/target profile fields a `number` `dataType` with a format instead.

```xml
<FunctionStep cacheEnabled="true" cacheOption="none" category="Numeric" key="9"
              name="Number Format" position="9" sumEnabled="false"
              type="NumberFormat" x="10.0" y="882.0">
  <Inputs>
    <Input default="" key="1" name="Number String"/>
    <Input default="#0.00" key="2" name="Input Mask"/>
    <Input default="#,##0.00" key="3" name="Output Mask"/>
  </Inputs>
  <Outputs><Output key="2" name="Result"/></Outputs>
  <Configuration/>
</FunctionStep>
```

#### Running Total (`type="Sum"`)

Maintains a cumulative running total of `Value to Sum`, emitting the incremental total **once per source record** (per-detail): amounts `10.25, 5.75, 20.00` → `10.25, 16.00, 36.00`. Map into a repeating (detail) target. **The `type` is `Sum`, not `RunningTotal`** (see the collision note above).

```xml
<FunctionStep cacheEnabled="true" cacheOption="none" category="Numeric" key="10"
              name="Running Total" position="10" sumEnabled="false"
              type="Sum" x="10.0" y="1023.0">
  <Inputs><Input default="" key="1" name="Value to Sum"/></Inputs>
  <Outputs><Output key="2" name="Result"/></Outputs>
  <Configuration/>
</FunctionStep>
```

#### Sum (`type="Sum2"`)

Aggregates `Value to Sum` (key=1) into a single total **per unique Reset Value** (key=2). A constant Reset Value yields one grand total (`10.25 + 5.75 + 20.00 = 36.00`); a Reset Value that varies by group yields a separate sum per group (e.g. category A = 30, B = 12). Into a header target the groups surface as one document each; into a repeating target the group sum is broadcast per member row. Grouping is **global and order-insensitive** — records sharing a Reset Value aggregate together even when interleaved (`A,B,A,B` still yields one A total and one B total); an empty/unwired Reset Value puts every record in a single group. **The `type` is `Sum2`, not `Sum`.**

```xml
<FunctionStep cacheEnabled="false" category="Numeric" key="11"
              name="Sum" position="11" sumEnabled="true"
              type="Sum2" x="10.0" y="1117.0">
  <Inputs>
    <Input default="" key="1" name="Value to Sum"/>
    <Input default="" key="2" name="Reset Value"/>
  </Inputs>
  <Outputs><Output key="2" name="Result"/></Outputs>
  <Configuration/>
</FunctionStep>
```

#### Count (`Count`)

Increments by 1 for each source record whose **Field to Count element exists**, producing a total **per unique Reset Value** — the same global, order-insensitive grouping mechanic as Sum. **Presence is by element existence, not value:** an **absent** counted element (a missing JSON key or an omitted XML element — the two behave identically) is not counted, but a present-but-empty value (`""`, whitespace, or JSON `null`) still counts. **This gating is only observable when the Field to Count is what brings the record into the map.** If any other always-present field of the same record is also mapped, every record is presented and Count returns the **total record count** regardless of the counted field's presence. Four records → `4`; grouped by category → `2` and `2`.

```xml
<FunctionStep cacheEnabled="false" category="Numeric" key="12"
              name="Count" position="12" sumEnabled="true"
              type="Count" x="10.0" y="1235.0">
  <Inputs>
    <Input default="" key="1" name="Field to Count"/>
    <Input default="" key="2" name="Reset Value"/>
  </Inputs>
  <Outputs><Output key="2" name="Result"/></Outputs>
  <Configuration/>
</FunctionStep>
```

#### Line Item Increment (`LineItemIncrement`)

A built-in counter that emits **+1 per source record** (`1, 2, 3, …`), one value per detail record. **The "Increment Basis" input (key=1) is inert** — the step is always 1 regardless of its default or a wired value; only record occurrence drives it. **The `Reset Value` (key=2) is a control-break reset:** the counter restarts at 1 whenever the Reset Value **differs from the immediately preceding record**, so it is **order-sensitive** — contiguous `A,A,B,B` yields `1,2,1,2`, but interleaved `A,B,A,B` yields `1,1,1,1`. (This differs from Sum/Count, whose Reset Value groups globally, regardless of order.) Map into a repeating (detail) target.

```xml
<FunctionStep cacheEnabled="true" cacheOption="none" category="Numeric" key="13"
              name="Line Item Increment" position="13" sumEnabled="false"
              type="LineItemIncrement" x="10.0" y="1353.0">
  <Inputs>
    <Input default="1" key="1" name="Increment Basis"/>
    <Input default="" key="2" name="Reset Value"/>
  </Inputs>
  <Outputs><Output key="2" name="Result"/></Outputs>
  <Configuration/>
</FunctionStep>
```

#### Sequential Value (`SequentialValue`)

A persistent counter configured entirely in `<Configuration><SequentialValue …/>`:
- `keyname` — the counter's identity; its latest value **persists per runtime across process executions** (it does not reset between runs).
- `keyfixtolength` — a **fixed** width the value is zero-padded to (`6` → `000011`), not a minimum: a value wider than the width is **truncated to its low-order digits** (`100` at width 2 → `00`), which can silently collide, so size the width for the counter's expected range. Omitting it (or `0`) applies no padding. The output is a **string**.
- `batchSize` — reserve this many values in memory per execution; the next execution resumes `batchSize` higher (with `batchSize="10"`, a run that consumes `31,32,33` is followed by a run starting at `41`).

Emits one value per source record. **Its input port (key=1) is vestigial** — a wired value is ignored; the counter is driven solely by record occurrence and the Configuration. Map the zero-padded result into a **`character`** target field.

```xml
<FunctionStep cacheEnabled="true" cacheOption="none" category="Numeric" key="14"
              name="Sequential Value" position="14" sumEnabled="false"
              type="SequentialValue" x="10.0" y="1471.0">
  <Inputs><Input default="" key="1" name="Value"/></Inputs>
  <Outputs><Output key="2" name="Result"/></Outputs>
  <Configuration><SequentialValue batchSize="1" keyfixtolength="6" keyname="myCounter"/></Configuration>
</FunctionStep>
```

**Serialization gotcha (Sequential Value & Number Format).** Both emit zero-padded / mask-formatted **strings**. Mapping such a value into a `number` target field produces invalid JSON — a zero-padded `000011` serializes as the bare token `000011` (leading zeros). Type any zero-padded or mask-formatted numeric output field as `character`.

### Properties

Properties functions read and write process-level and document-level properties, and set the outbound trading partner. When a Set and a Get for the same property run in one map, their order is not guaranteed by default — see Function Execution Order to make functions run in a particular order.

#### Get Dynamic Process Property (DPP)

**Purpose**: Retrieve process-wide dynamic property value

**Minimal Configuration**:
```xml
<FunctionStep cacheEnabled="true" category="ProcessProperty" key="5"
              name="Get Dynamic Process Property"
              position="5" sumEnabled="false" type="PropertyGet" x="10.0" y="10.0">
  <Inputs>
    <Input default="PROPERTY_NAME" key="1" name="Property Name"/>
    <Input key="2" name="Default Value"/>
  </Inputs>
  <Outputs>
    <Output key="3" name="Result"/>
  </Outputs>
  <Configuration/>
</FunctionStep>
```

**Output Key Pattern**: DPP and DDP get functions standardize on output key="3" (the component-based Get Process Property below instead uses key="1")

#### Set Dynamic Process Property (DPP)

**Purpose**: Store value in process-wide dynamic property

**Minimal Configuration**:
```xml
<FunctionStep cacheEnabled="true" category="ProcessProperty" key="6"
              name="Set Dynamic Process Property"
              position="6" sumEnabled="false" type="PropertySet" x="10.0" y="10.0">
  <Inputs>
    <Input default="PROPERTY_NAME" key="1" name="Property Name"/>
    <Input key="2" name="Property Value"/>
  </Inputs>
  <Outputs/>
  <Configuration/>
</FunctionStep>
```

**Output Key Pattern**: Property set functions have no outputs (side effect only)

#### Get Document Property

**Purpose**: Retrieve a document-scoped property value.

The variant is set by the `propertyId` prefix in `<Configuration><DocumentProperty>`. All three variants below are implemented; for any other prefix, inform the user that you don't have documentation for it.

| `propertyId` prefix | Property Type |
|---|---|
| `dynamicdocument.<name>` | Dynamic Document Property |
| `meta.base.<metaPropertyId>` | Document Property → Meta Data (read-only — no Set counterpart) |
| `mime.<header>` | MIME Property |

All variants share the same shape: `type="DocumentPropertyGet"`, empty `<Inputs/>`, a single `<Output key="3">`, property named in `<Configuration>` (not Inputs), and an output-only wiring mapping (`fromFunction`/`fromKey="3"` → target element). Only `propertyId` and `propertyName` differ.

**Minimal Configuration (Dynamic Document Property, or DDP)**:
```xml
<FunctionStep cacheEnabled="true" category="ProcessProperty" key="7"
              name="Get Document Property"
              position="7" sumEnabled="false" type="DocumentPropertyGet" x="10.0" y="10.0">
  <Inputs/>
  <Outputs>
    <Output key="3" name="Dynamic Document Property - PROPERTY_NAME"/>
  </Outputs>
  <Configuration>
    <DocumentProperty defaultValue="" persist="false" 
                     propertyId="dynamicdocument.PROPERTY_NAME" 
                     propertyName="Dynamic Document Property - PROPERTY_NAME"/>
  </Configuration>
</FunctionStep>
```

**Minimal Configuration (Document Property — Meta Data)**:
```xml
<FunctionStep cacheEnabled="true" category="ProcessProperty" key="8"
              name="Get Document Property"
              position="8" sumEnabled="false" type="DocumentPropertyGet" x="10.0" y="80.0">
  <Inputs/>
  <Outputs>
    <Output key="3" name="Base - Size"/>
  </Outputs>
  <Configuration>
    <DocumentProperty defaultValue="" persist="false"
                     propertyId="meta.base.size"
                     propertyName="Base - Size"/>
  </Configuration>
</FunctionStep>
```

**Meta Data property IDs are not derivable from their labels** — several slugs drop words from the label. Use this lookup table verbatim:

| Label | `propertyId` | Populated by |
|---|---|---|
| Application Status Code | `meta.base.applicationstatuscode` | Outbound connector steps |
| Application Status Message | `meta.base.applicationstatusmessage` | Outbound connector steps |
| Business Rules Result Message | `meta.base.businessrulesmessage` | Business Rules step |
| Cleanse Result Message | `meta.base.cleansemessage` | Cleanse step |
| Listener Batch Index | `meta.base.batchindex` | Listener-created batches |
| Listener Batch Payload Sequence | `meta.base.batchpayloadsequence` | Listener-created batches |
| Size | `meta.base.size` | Always (document byte count) |
| Try/Catch Message | `meta.base.catcherrorsmessage` | Try/Catch step catch path |

**Meta Data key details:**
- `propertyName` and the output port `name` both use the form `Base - <Label>` (e.g. `Base - Try/Catch Message`).
- Meta Data properties are **read-only** — populated by the steps above, never by a Set (the Set Document Property picker offers no Meta Data source).
- These are the same properties other surfaces call **Standard Document Properties** — same IDs and `Base - <Label>` names as the Set Properties parameter-source table (`set_properties_step.md`) and `trackparameter` reads.
- **An unpopulated property returns empty without error**: the function executes cleanly and the mapped target field is **absent** from the output document (not `""`) — the standard empty-function-result behavior. In a process without the populating step, that is the expected outcome for every property except `size`.
- Values arrive as strings (`size` for a 67-byte document maps as `"67"`) — map into `character` target fields.

**Minimal Configuration (MIME Property)**:
```xml
<FunctionStep cacheEnabled="true" category="ProcessProperty" key="9"
              name="Get Document Property"
              position="9" sumEnabled="false" type="DocumentPropertyGet" x="10.0" y="150.0">
  <Inputs/>
  <Outputs>
    <Output key="3" name="MIME Property - Content-Type"/>
  </Outputs>
  <Configuration>
    <DocumentProperty defaultValue="" persist="false"
                     propertyId="mime.Content-Type"
                     propertyName="MIME Property - Content-Type"/>
  </Configuration>
</FunctionStep>
```

**MIME slugs keep exact RFC header casing** — `mime.<Header-Name>` matching the label verbatim, for all thirteen standard headers: MIME-Version, Content-ID, Content-Description, Content-Transfer-Encoding, Content-Type, Content-Features, Content-Disposition, Content-Language, Content-MD5, Content-Location, Content-Base, Content-Duration, Content-Alternative. Three entries break that pattern:

| Label | `propertyId` |
|---|---|
| Name | `mime.name` (lowercase) |
| Mime Document | `mime.mimedocument` (lowercase) |
| Custom | `mime.<entered header name>` — verbatim, case preserved; nothing in the XML distinguishes a Custom pick from a built-in header of the same name |

**MIME key details:**
- `propertyName` and the output port `name` use the form `MIME Property - <Label>` (for Custom, the label is the entered header name).
- **MIME properties round-trip within a plain process** — a write to `propertyId="mime.<header>"` (from a Set Properties step, see `set_properties_step.md`, or a Set Document Property function, below) is read back by a Get function configured with the identical `propertyId`; no mail/multipart source is required. The `propertyId` is case-sensitive at this boundary: a value written as `mime.content-type` is not readable as `mime.Content-Type`, and the mismatch fails **silently** — no error anywhere, the target field is simply absent. Keep the slug exact.
- An unset property returns empty without error; the target field is **absent** from the output (not `""`) — same as the other variants.
- `mime.mimedocument` is empty in a plain single-part process — it does not carry the document body. Its behavior in multipart/mail contexts (as with `mime.name`) is not yet documented in this skill.

**Output Key Pattern**: Document property get functions standardize on output key="3"

#### Set Document Property

**Purpose**: Store a value in a document-scoped property.

As for Get, the variant is set by the `propertyId` prefix, minus `meta.base.` (meta-data properties are read-only). Both variants below are implemented; for any other prefix, inform the user that you don't have documentation for it.

| `propertyId` prefix | Property Type |
|---|---|
| `dynamicdocument.<name>` | Dynamic Document Property |
| `mime.<header>` | MIME Property |

**Minimal Configuration (Dynamic Document Property, or DDP)**:
```xml
<FunctionStep cacheEnabled="true" category="ProcessProperty" key="9"
              name="Set Document Property"
              position="9" sumEnabled="false" type="DocumentPropertySet" x="10.0" y="10.0">
  <Inputs>
    <Input key="1" name="Dynamic Document Property - PROPERTY_NAME"/>
  </Inputs>
  <Outputs/>
  <Configuration>
    <DocumentProperty defaultValue="" persist="false" 
                     propertyId="dynamicdocument.PROPERTY_NAME" 
                     propertyName="Dynamic Document Property - PROPERTY_NAME"/>
  </Configuration>
</FunctionStep>
```

**Minimal Configuration (MIME Property)**:
```xml
<FunctionStep cacheEnabled="true" category="ProcessProperty" key="10"
              name="Set Document Property"
              position="10" sumEnabled="false" type="DocumentPropertySet" x="10.0" y="80.0">
  <Inputs>
    <Input key="1" name="MIME Property - Content-Type"/>
  </Inputs>
  <Outputs/>
  <Configuration>
    <DocumentProperty defaultValue="" persist="false"
                     propertyId="mime.Content-Type"
                     propertyName="MIME Property - Content-Type"/>
  </Configuration>
</FunctionStep>
```

Wired with a single profile→function mapping (`toFunction`/`toKey="1"`) — the mirror of the Get side's output-only wiring.

**MIME Set key details:**
- Slugs and naming are identical to the Get side — the same RFC-cased headers, `mime.name`/`mime.mimedocument` lowercase exceptions, Custom-verbatim rule, and `MIME Property - <Label>` form (see the Get Document Property MIME section). Every entry in the Choose Property dialog is settable, including Custom.
- The write lands on the map **output** document's property set and persists to subsequent steps — readable downstream via `track` parameters and Get Document Property functions alike.

**Output Key Pattern**: Document property set functions have no outputs (side effect only)

#### Set Trading Partner (`TradingPartnerSet`)

Set the trading partner for the outbound message, resolved against the Trading Partner steps in the process. **Set-only** — no outputs, and no Get counterpart exists. It serializes under `category="ProcessProperty"` like the other Properties functions. Unlike Get/Set Process Property there is **no component reference** — the `<Configuration>` carries only two attributes, matching the GUI dropdowns:

- `standard` — the EDI standard, lowercase: `x12` (default), `edifact`, `hl7`, `odette`, `rosettanet`, `tradacoms`, `edicustom`. The value space is closed — any other value is rejected at push with an XML-schema HTTP 400. GUI dropdown labels are the uppercase standard names, except **CUSTOM**, which is `edicustom`.
- `inputType` — `identifier` (default) or `controlInformation` (label "Control Info" — note the serialized long form).

The `inputType` sets the input-port layout, with fixed port names:

| `inputType` | Input ports |
|---|---|
| `identifier` | `Identifier` (key 1) |
| `controlInformation` | `Interchange ID Qualifier` (key 1), `Interchange ID` (key 2), `Application Code` (key 3) |

**Only pair `controlInformation` with `standard="x12"`.** The pairing is not schema-enforced — a non-X12 Control Info function pushes and executes without error — but the GUI renders it as an empty, unusable function box, so never emit it. `identifier` works with every standard.

```xml
<FunctionStep cacheEnabled="true" cacheOption="none" category="ProcessProperty" key="1"
              name="Set Trading Partner" position="1" sumEnabled="false"
              type="TradingPartnerSet" x="10.0" y="10.0">
  <Inputs>
    <Input key="1" name="Identifier"/>
  </Inputs>
  <Outputs/>
  <Configuration>
    <TradingPartnerSet inputType="identifier" standard="x12"/>
  </Configuration>
</FunctionStep>
```

The Control Info variant differs only in the input ports and `inputType="controlInformation"`; each input may carry an optional `default="…"`. Wire one mapping per input (`toKey="1|2|3"`), as for any multi-input function.

**Key details:**
- **Mechanism:** the function stores the partner choice as a per-document property; a downstream **Trading Partner Send step** reads it per document to select the outbound partner, whose envelope settings then drive the outbound interchange. With no Trading Partner steps in the process, the function executes silently — no error, no log output, no visible effect.
- **What each `inputType` matches:** `identifier` matches the Trading Partner component's **root `identifier` attribute** (`<TradingPartner identifier="…">`) — **not** the ISA interchange ID. `controlInformation` (X12) matches the partner's control info — Interchange ID Qualifier, Interchange ID, and Application Code (ISA05/07, ISA06/08, GS02/03) — and **all three inputs must match**; a correct qualifier + interchange ID with a wrong application code is a no-match.
- **No match:** with two or more partners on the Send step, the document errors and is neither enveloped nor sent: `X12 Document does not match defined trading partners. More than one trading partner defined.  The receiving partner must be set as a document property.` With exactly **one** partner on the Send step, a non-matching value is ignored and the sole partner is used — no error.
- Precedence between multiple Set Trading Partner functions in one map is **not yet documented in this skill**.

#### Get Process Property (`DefinedProcessPropertyGet`)

Retrieve the value of a property defined in a **Process Property component** — the component-based counterpart to Get Dynamic Process Property (which uses inline, ad-hoc property names). See `process_property_component.md`.

The property is addressed by the **pair** in `<Configuration><DefinedProcessProperty>`: `componentId` (the Process Property component) + `propertyKey` (the `key` of the individual `definedProcessProperty`, a GUID in GUI-created components). `componentName` and `propertyName` are GUI display only — always populate them so the reference stays identifiable. (Note the asymmetry with the Set Properties step's `<definedprocessparameter>`, which calls the same display value `propertyLabel`.)

No inputs; one output. **The output is `key="1"`** — this function does not follow the key="3" convention of the DPP/DDP gets.

```xml
<FunctionStep cacheEnabled="true" cacheOption="none" category="ProcessProperty" key="1"
              name="Get Process Property" position="1" sumEnabled="false"
              type="DefinedProcessPropertyGet" x="10.0" y="10.0">
  <Inputs/>
  <Outputs>
    <Output key="1" name="My String"/>
  </Outputs>
  <Configuration>
    <DefinedProcessProperty componentId="{PROCESS_PROPERTY_COMPONENT_ID}"
                            componentName="My Process Properties"
                            propertyKey="{PROPERTY_KEY_GUID}"
                            propertyName="My String"/>
  </Configuration>
</FunctionStep>
```

Wired with a single function→profile mapping (nothing feeds into it):
```xml
<Mapping fromFunction="1" fromKey="1" fromType="function" toKey="{TARGET_KEY}" toType="profile"/>
```

**Key details:**
- **Values cross the function boundary as opaque strings.** A `boolean`/`number`/`date`-typed property arrives verbatim (`true`, `111`, `2026-07-17T09:30:00Z`) — no coercion, and date values are **not** converted to the internal map datetime format. The target profile element's `dataType` governs any rendering/coercion.
- Get is side-effect free and reads the **live** value: a value written earlier in the execution, else the component's `defaultValue`.
- **An empty result omits the target field.** A property whose effective value is empty (e.g. never written, with an empty `defaultValue`) yields an empty Get result, and the mapped target field is **absent** from the output document — not `""`. Treat a missing field as the empty-value signature downstream.
- All five property types read and write through these functions, including `password` (GUI type "Hidden") — whose value round-trips in plaintext through map functions and execution logs.

#### Set Process Property (`DefinedProcessPropertySet`)

Set the value of a property defined in a **Process Property component** — the component-based counterpart to Set Dynamic Process Property. Exact mirror of Get: one input (`key="1"`), no outputs, identical `<Configuration><DefinedProcessProperty>` addressing.

```xml
<FunctionStep cacheEnabled="true" cacheOption="none" category="ProcessProperty" key="2"
              name="Set Process Property" position="2" sumEnabled="false"
              type="DefinedProcessPropertySet" x="10.0" y="78.0">
  <Inputs>
    <Input key="1" name="My String"/>
  </Inputs>
  <Outputs/>
  <Configuration>
    <DefinedProcessProperty componentId="{PROCESS_PROPERTY_COMPONENT_ID}"
                            componentName="My Process Properties"
                            propertyKey="{PROPERTY_KEY_GUID}"
                            propertyName="My String"/>
  </Configuration>
</FunctionStep>
```

Wired with a single profile→function mapping (nothing leaves it):
```xml
<Mapping fromKey="{SOURCE_KEY}" fromType="profile" toFunction="2" toKey="1" toType="function"/>
```

**Key details:**
- One function step per property written. Writes accept all five property types as strings — the same opaque-string semantics as Get.
- A Set is visible to steps immediately after the Map (e.g. a Set Properties step reading via `valueType="definedparameter"`). A write to a `persisted="true"` property is durably persisted at execution end, exactly like a Set Properties step write (per-process, per-runtime scope — see `process_property_component.md` Persistence).
- **Mixing Get and Set of the same property in one map requires explicit ordering**: set `optimizeExecutionOrder="false"` and place the Set `<FunctionStep>` before the Get in document order (see Function Execution Order) — document order deterministically controls which runs first. Under the default `"true"` the Get may read the pre-map value.
- **`allowedValues` is not enforced on a map-function write.** An out-of-list value is silently accepted — no execution error, no log output — and becomes the live property value. The restriction is a GUI/design-time control; don't rely on it to reject bad values at request time.
- **A map whose only mapping feeds a Set function fails at execution** with `No data produced from map '…', please check source profile and make sure it matches source data.` — the Set side effect does not count as map output. Include at least one profile→profile field mapping so the document survives.

### String

String manipulation — trimming, append/prepend, concatenation, search-and-replace, case conversion, and splitting. Every String function is a `<FunctionStep category="String">` with a distinct `type` (below).

**Where parameters live:** Trim, Append, Prepend, Replace, and Remove carry their parameters as `<Input default="…">` ports (an unmapped input uses its default as the effective value — see Input Default Values above), and their `<Configuration>` is empty. Only **String Concat** and **String Split** carry settings in a `<Configuration>` child element.

**Port names are author-supplied labels.** The platform stores whatever names you assign and generates no defaults — `Original String`, `Result`, `input1`, etc. are conventional labels, not required values. Names are cosmetic (the wiring is by `key`); use descriptive ones.

**Empty result → absent target field.** When any String function's result is empty (e.g. `LeftTrim` of an empty value, `WhitespaceTrim` of an all-whitespace value), the map writes **no** target field — the element is absent from the output, not `""`. This is the same absent-not-empty behavior called out for String Split underflow below.

#### Left Character Trim (`LeftTrim`) / Right Character Trim (`RightTrim`)

Fix the value to `Fix to Length` characters by discarding from one side: `LeftTrim` discards from the **left** (retains the rightmost N), `RightTrim` discards from the **right** (retains the leftmost N). **When the input is shorter than `Fix to Length`, the value is returned unchanged** — no padding, no fill, no error.

```xml
<FunctionStep cacheEnabled="true" cacheOption="none" category="String" key="1"
              name="Left Character Trim" position="1" sumEnabled="false"
              type="LeftTrim" x="10.0" y="10.0">
  <Inputs>
    <Input default="" key="1" name="Original String"/>
    <Input default="3" key="2" name="Fix to Length"/>
  </Inputs>
  <Outputs><Output key="3" name="Result"/></Outputs>
  <Configuration/>
</FunctionStep>
```

`RightTrim` is identical but for `type="RightTrim"`. Examples: `LeftTrim` of `ABCDE` at length 3 → `CDE`; `RightTrim` of `ABCDE` at length 3 → `ABC`.

#### String Append (`StringAppend`) / String Prepend (`StringPrepend`)

Pad `Original String` out to `Fix to Length` using `Char to Append` / `Char to Prepend` as the **fill string, repeated as a unit** — Append pads on the right, Prepend on the left. **When the input already meets or exceeds `Fix to Length`, it is truncated to that length** — Append keeps the leftmost characters (`ABCDEF` / 4 → `ABCD`), Prepend the rightmost (`ABCDEF` / 4 → `CDEF`). The Char parameter is a repeating fill, not a one-time literal.

```xml
<FunctionStep cacheEnabled="true" cacheOption="none" category="String" key="4"
              name="String Append" position="4" sumEnabled="false"
              type="StringAppend" x="10.0" y="340.0">
  <Inputs>
    <Input default="" key="1" name="Original String"/>
    <Input default="8" key="2" name="Fix to Length"/>
    <Input default="x" key="3" name="Char to Append"/>
  </Inputs>
  <Outputs><Output key="2" name="Result"/></Outputs>
  <Configuration/>
</FunctionStep>
```

`StringPrepend` is identical but for `type="StringPrepend"` and the input name `Char to Prepend`. Examples: `AB` / length 5 / fill `x` → Append `ABxxx`, Prepend `xxxAB`; multi-char fill `xy` / length 6 → `ABxyxy` / `xyxyAB`.

#### Whitespace Trim (`WhitespaceTrim`)

Remove leading and trailing whitespace only; **interior whitespace is preserved** (`  a  b  ` → `a  b`). Single input, empty configuration.

```xml
<FunctionStep cacheEnabled="true" cacheOption="none" category="String" key="3"
              name="Whitespace Trim" position="3" sumEnabled="false"
              type="WhitespaceTrim" x="10.0" y="246.0">
  <Inputs><Input default="" key="1" name="Original String"/></Inputs>
  <Outputs><Output key="2" name="Result"/></Outputs>
  <Configuration/>
</FunctionStep>
```

#### String To Lower (`String2Lower`) / String To Upper (`String2Upper`)

Convert the value to lower- or uppercase. Single input, empty configuration. Note the type spelling uses a digit: `String2Lower` / `String2Upper`.

```xml
<FunctionStep cacheEnabled="true" cacheOption="none" category="String" key="9"
              name="String To Lower" position="9" sumEnabled="false"
              type="String2Lower" x="10.0" y="1022.0">
  <Inputs><Input default="" key="1" name="Original String"/></Inputs>
  <Outputs><Output key="2" name="Result"/></Outputs>
  <Configuration/>
</FunctionStep>
```

#### String Concat (`StringConcat`)

Join the input ports **in port order**, inserting `delimiter` between adjacent inputs; `fixedLength` then truncates the joined result to that many characters (leftmost N). An **empty delimiter** joins with no separator; **omitting the `fixedLength` attribute** means no truncation. Settings live in a `<Configuration>` child; the input ports (`key="1".."N"`) are the values to join.

```xml
<FunctionStep cacheEnabled="true" cacheOption="none" category="String" key="6"
              name="String Concat" position="6" sumEnabled="false"
              type="StringConcat" x="10.0" y="622.0">
  <Inputs>
    <Input default="" key="1" name="input1"/>
    <Input default="" key="2" name="input2"/>
    <Input default="" key="3" name="input3"/>
  </Inputs>
  <Outputs><Output key="2" name="Result"/></Outputs>
  <Configuration><StringConcat delimiter="-" fixedLength="20"/></Configuration>
</FunctionStep>
```

Example: inputs `A`,`B`,`C` with `delimiter="-"` → `A-B-C`; empty delimiter → `ABC`; `delimiter="-" fixedLength="3"` → `A-B`. An empty input keeps its position (both delimiters are still emitted): `A`,``,`C` with `delimiter="-"` → `A--C`.

#### String Replace (`StringReplace`) / String Remove (`StringRemove`)

Search `Original String` for `String to Search` (Replace) / `String to Remove` (Remove). **The search parameter is a regular expression, and the operation applies to all matches**, not just the first. Replace substitutes each match with `String to Replace`; Remove deletes each match. A plain literal is a valid (degenerate) regex.

```xml
<FunctionStep cacheEnabled="true" cacheOption="none" category="String" key="7"
              name="String Replace" position="7" sumEnabled="false"
              type="StringReplace" x="10.0" y="763.0">
  <Inputs>
    <Input default="" key="1" name="Original String"/>
    <Input default="[0-9]+" key="2" name="String to Search"/>
    <Input default="#" key="3" name="String to Replace"/>
  </Inputs>
  <Outputs><Output key="2" name="Result"/></Outputs>
  <Configuration/>
</FunctionStep>
```

`StringRemove` is identical but for `type="StringRemove"` and drops the third input (only `Original String` + `String to Remove`). Examples: Replace `abc123def` search `[0-9]+` replace `#` → `abc#def`; Replace `x-y-z` search `-` replace `_` → `x_y_z` (all matches); Remove `a1b2c3` remove `[0-9]` → `abc`.

#### String Split (`StringSplit`)

Split `Original String` into multiple output ports, keyed sequentially from 1 (`output1..N`). Two mutually exclusive modes, set by a single attribute on the `<Configuration>` child:
- `<StringSplit delimiter=","/>` — split on the delimiter.
- `<StringSplit splitLength="3"/>` — split into fixed-length chunks (`ceil(len/splitLength)` pieces; the final piece is the short remainder).

```xml
<FunctionStep cacheEnabled="true" cacheOption="none" category="String" key="11"
              name="String Split" position="11" sumEnabled="false"
              type="StringSplit" x="10.0" y="1210.0">
  <Inputs><Input default="" key="1" name="Original String"/></Inputs>
  <Outputs>
    <Output key="1" name="output1"/>
    <Output key="2" name="output2"/>
    <Output key="3" name="output3"/>
  </Outputs>
  <Configuration><StringSplit delimiter=","/></Configuration>
</FunctionStep>
```

Tokens fill `output1..N` positionally. **CRITICAL: if the split produces more tokens than there are defined output ports, the map fails at execution** with `Invalid split, expected to have at most N outputs but found M` — extra tokens are neither dropped nor merged into the last output. Define at least as many output ports as the maximum token count you expect. This makes **delimiter mode risky for variable input** (token count is data-dependent); size the outputs for the worst case, or split in a script when the count is unbounded. Underflow is safe: if fewer tokens than outputs, the surplus output fields are simply **absent** from the result (not empty strings). Output `key="1"` coincides with the input's `key="1"` — mapping direction disambiguates.

### User-Defined

User-Defined functions chain multiple standard function steps into a reusable, standalone component (`type="transform.function"`) that can be shared across maps. The component's anatomy — interface, internal steps, wiring, execution order — is documented in `user_defined_function_component.md`; this section covers the map side.

A map consumes a UDF as a `FunctionStep` with `category="userdefined"` and `type="userdefined"`, referencing the UDF component by its componentId in the **`id` attribute** — the steps are not defined inline:

```xml
<FunctionStep category="userdefined" id="[UDF_COMPONENT_ID]" key="1"
              name="[UDF_NAME]" position="1" type="userdefined" x="10.0" y="10.0">
  <Inputs>
    <Input key="1" name="in_value"/>
  </Inputs>
  <Outputs>
    <Output key="1" name="out_value"/>
  </Outputs>
  <Configuration/>
</FunctionStep>
```

- The `<Inputs>`/`<Outputs>` are a **mirror copy of the UDF's declared interface — same keys, same names**; map-level `<Mapping>` entries anchor to these embedded keys exactly as with any function step. `<Configuration/>` is always empty.
- The reference is **unversioned** (no version attribute exists). Packaging a process snapshots the then-current UDF revision; an already-deployed process keeps its snapshot, and consumers pick up a newer UDF revision only when repackaged and redeployed.
- **Interface drift breaks consumers**: if the UDF's interface keys change, a map still holding the old embedded copy fails at execution (zero output documents, with a misleading "check source profile" document error). Port renames with unchanged keys are harmless. See `user_defined_function_component.md` (Interface Changes).
- A side-effect-only UDF (empty `<Outputs/>`) is mapped input-only, with no output mapping at all. A UDF fires only when at least one of its interface ports — input or output — is wired; a userdefined FunctionStep with no mappings touching it is silently inert.
- UDF references coexist with standard function steps in the same `<Functions>` list.
- A UDF must never reference another UDF — the API accepts it but execution fails at process initialization. Do not attempt to chain standard functions directly in the map as a substitute either; see "Never Chain One Function Directly Into Another" above.

## Complete Working Example

```xml
<?xml version="1.0" encoding="UTF-8"?>
<bns:Component xmlns:bns="http://api.platform.boomi.com/" 
               componentId="" 
               folderId="[FOLDER_ID]" 
               name="Order Processing Map" 
               type="transform.map">
  <bns:object>
    <Map fromProfile="[SOURCE_PROFILE_ID]" toProfile="[TARGET_PROFILE_ID]">
      <Mappings>
        <!-- Send order data to custom processor -->
        <Mapping fromKey="5" fromType="profile" 
                 toFunction="1" toKey="1" toType="function"/>
        <Mapping fromKey="6" fromType="profile" 
                 toFunction="1" toKey="2" toType="function"/>
        
        <!-- Get both outputs from processor -->
        <Mapping fromFunction="1" fromKey="3" fromType="function" 
                 toKey="10" toType="profile"/>
        <Mapping fromFunction="1" fromKey="4" fromType="function" 
                 toKey="11" toType="profile"/>
      </Mappings>
      
      <Functions optimizeExecutionOrder="true">
        <FunctionStep cacheEnabled="true" category="Scripting" key="1" name="Order Processor"
                      position="1" sumEnabled="false" type="Scripting" x="10.0" y="10.0">
          <Inputs>
            <Input key="1" name="order_amount"/>
            <Input key="2" name="customer_tier"/>
          </Inputs>
          <Outputs>
            <Output key="3" name="final_price"/>
            <Output key="4" name="discount_applied"/>
          </Outputs>
          <Configuration>
            <Scripting language="groovy2">
              <ScriptToExecute><![CDATA[
// Variables order_amount and customer_tier are directly available
BigDecimal amount = new BigDecimal(order_amount ?: "0")
String tier = customer_tier ?: "STANDARD"

// Calculate based on tier
BigDecimal discount = 0
if (tier == "GOLD") discount = amount * 0.1
if (tier == "PLATINUM") discount = amount * 0.15

// Set the output variables we defined
final_price = (amount - discount).toString()
discount_applied = discount.toString()
              ]]></ScriptToExecute>
              <Input dataType="character" index="1" name="order_amount"/>
              <Input dataType="character" index="2" name="customer_tier"/>
              <Output index="3" name="final_price"/>
              <Output index="4" name="discount_applied"/>
            </Scripting>
          </Configuration>
        </FunctionStep>
      </Functions>
      
      <Defaults/>
      <DocumentCacheJoins/>
    </Map>
  </bns:object>
</bns:Component>
```

## Key Observations

### Function Key Patterns
- **Function keys** assigned by creation order (1,2,3...), gaps possible from deletions (e.g., 1,3,4,5,6,7,9)
- **Input keys** must be unique among a function's inputs, and **output keys** unique among its outputs — but an input key and an output key **may coincide** (mapping direction disambiguates, as in Simple Lookup and String Split)
- **Keys referenced in mappings** to connect data flow
- **Output-key conventions** by function type (see patterns above)

### DPP vs DDP
- **DPP (Dynamic Process Property)**: Shared across all documents in the process
- **DDP (Dynamic Document Property)**: Specific to individual document, travels with it through the flow