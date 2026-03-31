# Cross Reference Table Component Reference

## Contents
- Component Type
- Component Structure
- Column Headers and Rows
- Match Types
- Lookup Behavior
- Column Indexing
- Cross Reference Lookup in Maps
- Cross Reference Lookup as Parameter Value Source
- Multi-Input Lookups

## Component Type
`crossref`

Boomi component type string: `type="crossref"` in the `bns:Component` wrapper.

Cross reference tables are static, in-memory lookup tables for value translation between systems. Common uses: code mapping (system A codes to system B codes), status translation, environment-specific parameter values.

Cross reference tables cannot be updated dynamically at runtime.

## Component Structure

```xml
<?xml version="1.0" encoding="UTF-8"?>
<bns:Component xmlns:bns="http://api.platform.boomi.com/"
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               componentId="" name="Status Code Mapping"
               type="crossref" folderId="{FOLDER_ID}">
  <bns:encryptedValues/>
  <bns:object>
    <CrossRefTable xmlns="" atomEnabled="false" modelVersion="3">
      <ColumnHeaders>
        <columnHeader>source_code</columnHeader>
        <columnHeader>target_code</columnHeader>
        <columnHeader>description</columnHeader>
      </ColumnHeaders>
      <Rows>
        <row>
          <Values>
            <ref colIdx="0" value="ACTIVE"/>
            <ref colIdx="1" value="A"/>
            <ref colIdx="2" value="Active record"/>
          </Values>
        </row>
        <row>
          <Values>
            <ref colIdx="0" value="INACTIVE"/>
            <ref colIdx="1" value="I"/>
            <ref colIdx="2" value="Inactive record"/>
          </Values>
        </row>
      </Rows>
    </CrossRefTable>
  </bns:object>
</bns:Component>
```

### CrossRefTable Attributes

| Attribute | Type | Default | Purpose |
|---|---|---|---|
| `atomEnabled` | boolean | false | Enables Atom-specific (runtime-specific) row values |
| `matchType` | enum | (omitted = exact) | Matching mode for lookups |
| `modelVersion` | int | 3 | Internal model version |

## Column Headers and Rows

Column headers define the lookup table's schema. Each `columnHeader` element is a label for that column position.

- Minimum 2 columns, maximum 20
- Column position is implicit from element order (first `columnHeader` = column 0, etc.)

Row values use `ref` elements with explicit column indexing:

| Attribute | Type | Purpose |
|---|---|---|
| `colIdx` | int | 0-based column index |
| `value` | string | Cell value |

Every `ref` in a row must correspond to a `columnHeader` by position. A row contains a `Values` element wrapping all `ref` elements for that row.

## Match Types

The `matchType` attribute on `CrossRefTable` controls how input values are matched against table rows during lookup.

| Value | Attribute Setting | Description |
|---|---|---|
| Exact | Omit `matchType` (default) | Case-insensitive exact equality |
| Wildcard | `matchType="wildcard"` | Glob-style patterns: `*` (zero-or-more chars), `?` (single char) |
| Regex | `matchType="regex"` | Java regex — the table cell value is the pattern, the lookup input is the string matched against it |

```xml
<!-- Exact match (default - attribute omitted) -->
<CrossRefTable xmlns="" atomEnabled="false" modelVersion="3">

<!-- Wildcard match -->
<CrossRefTable xmlns="" atomEnabled="false" matchType="wildcard" modelVersion="3">

<!-- Regex match -->
<CrossRefTable xmlns="" atomEnabled="false" matchType="regex" modelVersion="3">
```

Match type is set on the table component itself, not at lookup time. All lookups against a given table use the same match mode.

## Lookup Behavior

### Case Sensitivity
Exact match is **case-insensitive**. An input of "JOHN" matches a table entry of "john".

### Multiple Matches
When multiple rows match the input, the **first matching row** (by row order in the table definition) is returned. No error, no aggregation.

### No Match
When no row matches the input, the lookup returns an **empty string**. No error is thrown and the process continues normally. Downstream logic should check for empty results if a missing match requires special handling.

### skipLookupIfNoInputs
In map CrossRefLookup functions, `skipLookupIfNoInputs="true"` silently skips the lookup when the input value is empty. The output field produces no value (not an empty string — the field is absent from the output document). No error is thrown and the process continues normally.

## Column Indexing

**Critical**: The table stores values with 0-based `colIdx`, but all lookup references (in maps and parameter values) use 1-based column IDs.

| Context | Indexing | Example: "first" column |
|---|---|---|
| `ref colIdx` in table rows | 0-based | `colIdx="0"` |
| `refId` in map CrossRefLookup | 1-based | `refId="1"` |
| `outputParamId` in parameter value | 1-based | `outputParamId="1"` |
| `elementToSetId` in parameter value inputs | 1-based | `elementToSetId="1"` |

## Cross Reference Lookup in Maps

Cross reference lookups are available as a map function (`type="CrossRefLookup"`, `category="Lookup"`). The function takes one or more input columns to match on and returns one or more output columns.

```xml
<FunctionStep cacheEnabled="true" cacheOption="none" category="Lookup"
              key="1" name="Cross Reference Lookup" position="1"
              sumEnabled="false" type="CrossRefLookup" x="10.0" y="10.0">
  <Inputs>
    <Input key="1" name="first"/>
  </Inputs>
  <Outputs>
    <Output key="2" name="first"/>
    <Output key="3" name="email"/>
    <Output key="4" name="Reference 5"/>
  </Outputs>
  <Configuration>
    <CrossRefLookup crossRefTableId="{CROSSREF_COMPONENT_ID}"
                    skipLookupIfNoInputs="true">
      <Input index="1" name="first" refId="1"/>
      <Output index="2" name="first" refId="1"/>
      <Output index="3" name="email" refId="3"/>
      <Output index="4" name="Reference 5" refId="5"/>
    </CrossRefLookup>
  </Configuration>
</FunctionStep>
```

### CrossRefLookup Configuration

| Attribute | Type | Purpose |
|---|---|---|
| `crossRefTableId` | string | Component ID of the cross reference table |
| `skipLookupIfNoInputs` | boolean | When true, skips lookup if input values are empty |

### Input/Output Elements (inside Configuration)

| Attribute | Type | Purpose |
|---|---|---|
| `index` | int | Matches the `key` of the corresponding Input/Output in the function's Inputs/Outputs section |
| `name` | string | Column header label |
| `refId` | int | 1-based column reference in the cross reference table |

### Mapping Wiring

Follows standard map function patterns (see `map_component_functions.md`). The `fromKeyPath`/`toKeyPath` and `fromNamePath`/`toNamePath` values are profile-dependent — derive them from the actual source and target profiles.

```xml
<!-- Send source profile field to lookup input -->
<Mapping fromKey="{SOURCE_FIELD_KEY}" fromType="profile"
         toFunction="1" toKey="1" toType="function"/>

<!-- Get lookup outputs to target profile fields -->
<Mapping fromFunction="1" fromKey="2" fromType="function"
         toKey="{TARGET_FIELD_KEY}" toType="profile"/>
```

## Cross Reference Lookup as Parameter Value Source

Cross reference lookups can be used anywhere a parameter value is accepted (Set Properties, Message, Notify steps) via `valueType="crossref"`. In this approach the lookup will only return a single field.

### Single-Input Lookup (Set Properties)

```xml
<documentproperty name="Dynamic Document Property - DDP_EMAIL"
                  persist="false"
                  propertyId="dynamicdocument.DDP_EMAIL"
                  shouldEncrypt="false">
  <sourcevalues>
    <parametervalue key="1" usesEncryption="false" valueType="crossref">
      <crossrefparameter crossRefTableId="{CROSSREF_COMPONENT_ID}"
                         outputParamId="3" outputParamName="email">
        <inputs>
          <parametervalue elementToSetId="1" elementToSetName="first"
                         key="0" usesEncryption="false" valueType="profile">
            <profileelement elementId="3"
                           elementName="first (Root/Object/first)"
                           profileId="{PROFILE_COMPONENT_ID}"
                           profileType="profile.json"/>
          </parametervalue>
        </inputs>
      </crossrefparameter>
    </parametervalue>
  </sourcevalues>
</documentproperty>
```

### crossrefparameter Attributes

| Attribute | Type | Purpose |
|---|---|---|
| `crossRefTableId` | string | Component ID of the cross reference table |
| `outputParamId` | int | 1-based column index of the output value to return |
| `outputParamName` | string | Column header label of the output column |

### Input parametervalue Attributes

| Attribute | Type | Purpose |
|---|---|---|
| `elementToSetId` | int | 1-based column index to match against |
| `elementToSetName` | string | Column header label of the input column |
| `key` | int | Sequential key (0-based within the inputs block) |
| `valueType` | string | Source type: `profile`, `static`, `dynamicprocessproperty`, etc. |

Input values can come from any standard parameter value source — profile elements, static values, process properties, document properties, etc.

## Multi-Input Lookups

When matching on multiple columns simultaneously, add multiple `parametervalue` elements inside `inputs`. Each input targets a different column.

### Multi-Input Example (Message Step)

```xml
<parametervalue key="0" usesEncryption="false" valueType="crossref">
  <crossrefparameter crossRefTableId="{CROSSREF_COMPONENT_ID}"
                     outputParamId="4" outputParamName="phone">
    <inputs>
      <parametervalue elementToSetId="1" elementToSetName="first"
                     key="0" usesEncryption="false" valueType="static">
        <staticparameter staticproperty="john"/>
      </parametervalue>
      <parametervalue elementToSetId="2" elementToSetName="last"
                     key="1" usesEncryption="false" valueType="static">
        <staticparameter staticproperty="doe"/>
      </parametervalue>
    </inputs>
  </crossrefparameter>
</parametervalue>
```

This matches rows where column 1 (first) = "john" AND column 2 (last) = "doe", then returns the value from column 4 (phone).

### Multi-Input in Map CrossRefLookup

Add multiple `Input` elements in both the function's `Inputs` section and the `Configuration/CrossRefLookup` section:

```xml
<FunctionStep cacheEnabled="true" cacheOption="none" category="Lookup"
              key="1" name="Cross Reference Lookup" position="1"
              sumEnabled="false" type="CrossRefLookup" x="10.0" y="10.0">
  <Inputs>
    <Input key="1" name="first"/>
    <Input key="2" name="last"/>
  </Inputs>
  <Outputs>
    <Output key="3" name="email"/>
  </Outputs>
  <Configuration>
    <CrossRefLookup crossRefTableId="{CROSSREF_COMPONENT_ID}"
                    skipLookupIfNoInputs="true">
      <Input index="1" name="first" refId="1"/>
      <Input index="2" name="last" refId="2"/>
      <Output index="3" name="email" refId="3"/>
    </CrossRefLookup>
  </Configuration>
</FunctionStep>
```