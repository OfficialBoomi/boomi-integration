# Map Component Functions

## Contents
- Overview
- Function Architecture
- Available Functions
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
  - **Property functions**: Output key="3" (fixed)
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

2. **For complex multi-step transformations requiring a pipeline**, use a single scripting function that handles all the steps internally instead of multiple chained function widgets.

3. **If two functions appear to need chaining** (e.g. `Get Current Date` → `Date Format`), do NOT wire them together. There are multi-step function components in the platform called User Defined Functions (`FunctionStep category="userdefined"` and `type="userdefined"`), but they are not yet implemented. If you encounter them inform the user that you don't have documentation.

### CRITICAL: Function Coordinates for GUI Rendering

Every `<FunctionStep>` MUST carry `x` and `y` canvas coordinates:
- `x="10.0"` and `y="Y_COORD"` on every function
- Start the first function at `y="10.0"` and increment ~140px per function (150.0, 288.0, …) so they don't overlap

Coordinates do not affect API push or process execution, but **without them the GUI cannot render the map**. A single coordinate-less function is enough to break rendering, and a map that won't open also can't be repaired in the GUI — so always emit coordinates.

`cacheEnabled` and `sumEnabled` are GUI-authored (`true`/`false` respectively) and are **not** required for push, execution, or rendering. Emitting them matches what the GUI writes and avoids a no-op version bump when the map is first opened and saved; omitting them is harmless.

### Function Execution Order

The `optimizeExecutionOrder` attribute on `<Functions>` controls whether the order functions run in is guaranteed:

- `optimizeExecutionOrder="true"` (default) — execution order is **not guaranteed**. Acceptable when functions are independent.
- `optimizeExecutionOrder="false"` — functions run in the order their `<FunctionStep>` elements appear in the XML.

The sequence is carried by the **document order of the `<FunctionStep>` elements**, not by the `position` attribute (`position` is a fixed per-function ordinal, like `key`, and does not track execution order).

When one function depends on another — most commonly a **Set Process Property** feeding a **Get Process Property** for the same property within one map — set `optimizeExecutionOrder="false"` and place the producing `<FunctionStep>` before the consuming one. Under the default `"true"`, the Get may run before the Set and read an empty value.

### Function Result Caching

The optional `cacheOption` attribute on a `<FunctionStep>` reuses a function's output when it is called again with the same inputs — worthwhile for expensive functions such as Lookups or Connector Calls:

- `cacheOption="none"` or the attribute omitted (default) — no caching; the function runs on every invocation.
- `cacheOption="document"` — the cache is cleared after each document (reuse only within a single document's processing).
- `cacheOption="map"` — the cache persists across all documents processed by the map.

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

Some function parameters carry a `dataType` attribute — `character`, `integer`, `float`, or `datetime` — on the `<Configuration>` `<Input>`/`<Output>` entry (the outer `<Inputs>`/`<Outputs>` ports carry only `key` and `name`). Which functions type their parameters:

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
  - **Properties** — Get/Set Process Property, Get/Set Document Property, Set Trading Partner
  - **String** — Left/Right Character Trim, Whitespace Trim, String Append, String Prepend, String Concat, String Replace, String Remove, String To Lower, String To Upper, String Split
- **User-Defined functions** — reusable, standalone components that chain multiple standard function steps together in a defined sequence. They can be shared across maps. **User-Defined functions are not yet implemented in this skill** (`FunctionStep category="userdefined"` and `type="userdefined"`). If you encounter one, inform the user that you don't have documentation for it.

The subsections below document the individual **Standard functions**. Categories or functions not yet documented in this skill are marked as such — if you encounter one, inform the user that you don't have documentation for it.

### Connector

Calls out to an application connector — typically for cross-reference lookups or supplemental data (the **Connector Call** function). _Not yet documented in this skill._

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

| GUI label | `language` value |
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

### Language

Alphabet and character transliteration (the **Japanese Character Conversion** function). _Not yet documented in this skill._

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

Mathematical operations, number formatting, and counters — Math Add/Subtract/Multiply/Divide, Absolute Value, Ceil, Floor, Set Precision, Number Format, Running Total, Sum, Count, Line Item Increment, and Sequential Value. _Not yet documented in this skill._

### Properties

Properties functions read and write process-level and document-level properties. When a Set and a Get for the same property run in one map, their order is not guaranteed by default — see Function Execution Order to make the Set run first.

#### Get Dynamic Process Property (DPP)

**Purpose**: Retrieve process-wide property value

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

**Output Key Pattern**: Property get functions standardize on output key="3"

#### Set Dynamic Process Property (DPP)

**Purpose**: Store value in process-wide property

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

#### Get Document Property (DDP)

**Purpose**: Retrieve document-specific property value

**Minimal Configuration**:
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

**Output Key Pattern**: Document property get functions standardize on output key="3"
- Property name defined in Configuration, not Inputs
- propertyId prefixed with "dynamicdocument."

#### Set Document Property (DDP)

**Purpose**: Store value in document-specific property

**Minimal Configuration**:
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

**Output Key Pattern**: Document property set functions have no outputs (side effect only)
- propertyId prefixed with "dynamicdocument."

_Set Trading Partner is not yet documented in this skill._

### String

String manipulation — trimming, append/prepend, concatenation, search-and-replace, case conversion, and splitting. _Not yet documented in this skill._

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
- **Input/output keys** must be unique within each function
- **Keys referenced in mappings** to connect data flow
- **Standardized output keys** by function type (see patterns above)

### DPP vs DDP
- **DPP (Dynamic Process Property)**: Shared across all documents in the process
- **DDP (Dynamic Document Property)**: Specific to individual document, travels with it through the flow