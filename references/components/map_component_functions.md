# Map Component Functions

## Contents
- Overview
- Function Architecture
- Available Functions
- Complete Working Example
- Key Observations

## Overview
Map functions transform data beyond simple field-to-field mapping. They're added to the `<Functions>` element within a Map component and referenced in mappings using `fromFunction` or `toFunction` attributes.

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
- Functions container includes `optimizeExecutionOrder="true"` in observed examples

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

### CRITICAL: Required GUI Attributes
All functions MUST include these attributes for proper GUI rendering:
- `cacheEnabled="true"` - Required for all functions
- `sumEnabled="false"` - Required for all functions
- `x="10.0"` and `y="Y_COORD"` - Canvas positioning coordinates
- **Positioning**: Start first function at y="10.0", increment by ~140 pixels (150.0, 288.0, etc.)
- **Without coordinates**: GUI cannot render the map and causes stack overflow errors

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

### 1. Custom Scripting

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

### 2. Date Format

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

### 3. Get Current Date

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

### 4. Get Dynamic Process Property (DPP)

**Purpose**: Retrieve process-wide property value

**Minimal Configuration**:
```xml
<FunctionStep category="ProcessProperty" key="5" 
              name="Get Dynamic Process Property" 
              position="5" type="PropertyGet">
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

### 5. Set Dynamic Process Property (DPP)

**Purpose**: Store value in process-wide property

**Minimal Configuration**:
```xml
<FunctionStep category="ProcessProperty" key="6" 
              name="Set Dynamic Process Property" 
              position="6" type="PropertySet">
  <Inputs>
    <Input default="PROPERTY_NAME" key="1" name="Property Name"/>
    <Input key="2" name="Property Value"/>
  </Inputs>
  <Outputs/>
  <Configuration/>
</FunctionStep>
```

**Output Key Pattern**: Property set functions have no outputs (side effect only)

### 6. Get Document Property (DDP)

**Purpose**: Retrieve document-specific property value

**Minimal Configuration**:
```xml
<FunctionStep category="ProcessProperty" key="7" 
              name="Get Document Property" 
              position="7" type="DocumentPropertyGet">
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

### 7. Set Document Property (DDP)

**Purpose**: Store value in document-specific property

**Minimal Configuration**:
```xml
<FunctionStep category="ProcessProperty" key="9" 
              name="Set Document Property" 
              position="9" type="DocumentPropertySet">
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

### 8. Cross Reference Lookup

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
- `index` in Configuration must match the `key` of the corresponding Input/Output
- Supports multiple inputs (match on 2+ columns) and multiple outputs

See `cross_reference_table_component.md` for full details: multi-input examples, parameter value usage outside maps, match types, column indexing, and lookup behavior.

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
        <FunctionStep category="Scripting" key="1" name="Order Processor" 
                      position="1" type="Scripting">
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