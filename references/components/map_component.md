# Map Component

## Contents
- Purpose
- Key Concepts
- Component Structure
- Default Values
- Datetime Field Mapping
- Map Generation Rules
- Mapping Patterns
- Instance Identifier and Qualifier Mappings
- Observed Patterns
- Complete Examples
- Map Functions
- Usage in Process
- Best Practices

## Purpose
Maps transform documents from one profile structure to another. They are the primary data transformation mechanism in Boomi, handling field-to-field mappings between different data formats.

## Key Concepts

### Profile Dependency
- Maps require both source (`fromProfile`) and destination (`toProfile`) profiles to exist
- **Same profile for both source/destination** can be useful:
  - **Field filtering**: Transform 100kb Salesforce record to smaller payload by mapping only needed fields
  - **Function access**: Use map functions (like datetime formatting) even when no structural transformation is needed
- Profile component IDs must be valid GUIDs in your account

### Mapping Approach
Boomi maps use **key-based mapping** where keys correspond to fields in the profile structure. Profile keys are assigned by the platform during profile creation using hierarchical depth-first traversal.

keyPath and namePath attributes are display metadata — the engine matches on `fromKey`/`toKey` alone. See § Mapping Patterns.

### Array Handling
One `Mapping` per leaf field covers every occurrence of a repeating element — the engine iterates. How many output documents that produces is governed by the target profile; see § Instance Identifier and Qualifier Mappings.

## Component Structure

### Minimal Creation Format
```xml
<?xml version="1.0" encoding="UTF-8"?>
<bns:Component xmlns:bns="http://api.platform.boomi.com/" 
               componentId="" 
               folderId="[FOLDER_ID]" 
               name="[MAP_NAME]" 
               type="transform.map">
  <bns:object>
    <Map fromProfile="[SOURCE_PROFILE_ID]" toProfile="[TARGET_PROFILE_ID]">
      <Mappings>
        <!-- Individual field mappings -->
      </Mappings>
      <Functions/>
      <Defaults/>
      <DocumentCacheJoins/>
    </Map>
  </bns:object>
</bns:Component>
```

### Required Elements
- `<Mappings>`: Container for individual field mappings
- `<Functions/>`: For transformation functions (empty if unused)
- `<Defaults/>`: For default/fallback values (empty if unused)
- `<DocumentCacheJoins/>`: For lookups (empty if unused)

All four elements must be present even if empty.

## Default Values

Defaults provide fallback values for target fields or populate static fields. They apply when:
- No mapping exists for the target field
- A mapping exists but produces an empty value

### Syntax
```xml
<Defaults>
  <Default toKey="15" value="static content"/>
  <Default toKey="4" value="fallback if mapping is empty"/>
</Defaults>
```

### Attributes
- `toKey`: Target profile element key (required)
- `value`: Default value string (required)
- `toTagListKey`: Target instance identifier (optional, int). Routes the default into a specific instance of a repeating target element

### Use Cases
- **Static values**: Target fields with no source equivalent (e.g., `Auto_Complete="true"`)
- **Fallback values**: Safety net when mappings may return empty
- **Schema superset handling**: When target requires fields the source doesn't have

### Instance-Aware Defaults

When the target profile uses instance identifiers, defaults can target specific instances:

```xml
<Defaults>
  <Default toKey="13" toTagListKey="1" value="BUYER-DEFAULT-CITY"/>
  <Default toKey="13" toTagListKey="2" value="SELLER-DEFAULT-CITY"/>
</Defaults>
```

- Multiple Defaults for the same `toKey` with different `toTagListKey` values target different instances
- Without `toTagListKey`, a Default on an instanced field creates a new unqualified instance — it does NOT apply to all instances
- `toTagListKey=0` (default) means "unqualified", not "all instances"

### Example: Defaults with Mapping
```xml
<Mappings>
  <Mapping fromKey="5" fromType="profile" toKey="4" toType="profile"/>
</Mappings>
<Defaults>
  <Default toKey="4" value="fallback if source empty"/>
</Defaults>
```
If source key 5 is empty, target key 4 receives "fallback if source empty".

### Datetime Field Defaults
When a target field has `dataType="datetime"`, default values must use Boomi's internal format:
```xml
<Default toKey="15" value="20250115 120000.000"/>  <!-- Correct -->
<Default toKey="15" value="2025-01-15"/>           <!-- FAILS -->
```

## Datetime Field Mapping

When profile fields have `dataType="datetime"`, Boomi's internal datetime pipeline activates. See BOOMI_THINKING.md for the full mental model.

### Input Mask Selection for Date Format Functions

| Source dataType | Date Format Input Mask |
|-----------------|------------------------|
| character | Match actual incoming data format |
| datetime | `yyyyMMdd HHmmss.SSS` (Boomi internal) |

### Output Mask Selection for Date Format Functions

| Target dataType | Date Format Output Mask |
|-----------------|-------------------------|
| character | Desired output format |
| datetime | `yyyyMMdd HHmmss.SSS` (Boomi internal) |

### Direct Mapping (No Function)

| Source | Target | Works? |
|--------|--------|--------|
| character | character | Yes |
| character | datetime | Yes Date Format function must output date mask of `yyyyMMdd HHmmss.SSS` |
| datetime | datetime | Yes (auto-conversion) |
| datetime | character | Yes Date Format function must have an input mask of `yyyyMMdd HHmmss.SSS`|

## Map Generation Rules

### CRITICAL: Filter by isMappable Before Generating Mappings

**When generating Boomi map components, you must filter profile elements before creating mappings:**

1. **Load both profile XMLs** (source and destination)
2. **Parse and filter** to only elements where `isMappable="true"`
3. **Generate mappings** using only the filtered element keys

**Core Principle**: Profile elements have two types:
- **Structural containers** (`isMappable="false"`) - Objects, arrays, root wrappers that organize hierarchy
- **Data fields** (`isMappable="true"`) - Leaf fields containing actual values (strings, numbers, etc.)

**The Rule**: Map XML `<Mapping>` entries should ONLY reference keys from elements where `isMappable="true"`. This matches Boomi GUI behavior where only mappable fields appear in dropdown selections.

### Incorrect vs Correct Mapping Generation

**WRONG - Mapping structural containers**:
```xml
<!-- Source profile has these elements: -->
<!-- <Element key="7" name="weather" isMappable="false">  ← Container -->
<!--   <Element key="8" name="weather" isMappable="false">  ← Container -->
<!--     <Element key="9" name="id" isMappable="true" type="string"/>  ← Data -->

<!-- DON'T generate mappings for container keys: -->
<Mapping fromKey="7" fromType="profile" toKey="..." toType="profile"/>  
<Mapping fromKey="8" fromType="profile" toKey="..." toType="profile"/>  
```

**CORRECT - Mapping only data fields**:
```xml
<!-- Only generate mappings for leaf data fields: -->
<Mapping fromKey="9" fromType="profile" toKey="..." toType="profile"/>  
```

## Mapping Patterns

### Key-Based Mapping
```xml
<Mapping fromKey="3" fromType="profile"
         toKey="8" toType="profile"/>
```

**Key Discovery**: Profile keys are assigned by the Boomi platform during profile creation. Keys follow the hierarchical structure of the profile (depth-first traversal). Complementary keyPath and namePath attributes are added on a GUI save — a map created through the API keeps exactly the attributes it was pushed with, and a push/pull round trip will not generate them. Entries that are manually created by a user after the main profile is generated may not align with the expected sequencing.

### Important Attributes
- `fromType="profile"` and `toType="profile"` are **REQUIRED**
- These tell Boomi to look up fields in the profiles
- Without these, mappings won't work

## Instance Identifier and Qualifier Mappings

When source or target profiles use instance identifiers and qualifiers (tagLists), mappings need additional attributes to specify which loop instance to read from or write to.

### When tagLists Are Needed

**Whether tagLists are needed is decided by the source, not the target.** A repeating target element alone never requires them — reaching for them when the source already repeats adds configuration that does no work. A repeating source means an EDI loop, a repeating XML element, a JSON array, or a Flat File record.

| Source | Target | Result | tagLists |
|---|---|---|---|
| Repeating | Repeating (`maxOccurs="-1"`) | 1 document, N target occurrences in source order | Not needed |
| Repeating | Non-repeating | N split documents, non-repeating fields duplicated across all | Not needed — set the target to `maxOccurs="-1"` |
| N non-repeating fields | The same repeating element | 1 occurrence, last-write-wins | Required |

A JSON array mapped to an XML element with `maxOccurs="-1"` needs only that `maxOccurs` on the target profile's element. The map itself is one `Mapping` per leaf field with no `fromTagListKey`/`toTagListKey`, and the profile's `<tagLists>` block stays empty. The engine carries the occurrence count from the data. Zero source occurrences emit no target element at all — an empty array and an absent property produce identical output.

Fan-in has no data-borne occurrence count, so both mappings write to the same instance and the earlier value is discarded silently: accepted on push, deploys, and executes with status COMPLETE. `toTagListKey` supplies what is missing by naming which instance each mapping writes to.

### Controlling Document Splitting

Two sibling repeating sources mapped to a non-repeating target multiply: a source carrying 2 `refs` and 2 `parties` yields 4 output documents, one per combination, walked in source order with `refs` as the outer loop. Making the target elements repeating collapses the same source to a single document. Three mechanisms consolidate:
- **Repeating target element**: When the target is also repeating (arrays, repeating XML elements), each source element is walked independently and its iterations become children of a single output document. The target hierarchy **must mirror the source nesting**. A target whose repeating elements sit as siblings where the source nests them flattens the result — every value survives and nothing splits, but the parent-child grouping is discarded, with no error and no warning.
- **tagLists with `fromTagListKey`**: Route qualified loop iterations to different target fields, consolidating into one output document. Works across EDI, XML, and JSON profiles.
- **`additionalElementValue` on segments**: For qualified repeating segments (e.g., REF*CN vs REF*BM), define separate segment entries in the EDI profile with `useAdditionalCriteria="true"` — each gets unique keys, eliminating the cross-product.

Complex EDI transactions (e.g., 856 with S/O/P/I hierarchy) typically need all three: nested arrays for the HL hierarchy, `additionalElementValue` for qualified segments (REF, DTM, MAN), and tagLists for qualified loops (N1). Combined, these achieve 1 output document per transaction set.

For EDI profiles specifically, tagList `elementKey` must point to the loop, not a segment within it -- see Issue #22 in references/guides/boomi_error_reference.md.

### Source-Side: `fromTagListKey`

When the **source** profile has tagLists, add `fromTagListKey` to reference the TagList's `listKey`:

```xml
<Mapping fromKey="23"
         fromKeyPath="*[@key='1']/*[@key='20'][@tagListKey='1']/*[@key='21'][@tagListKey='1']/*[@key='23'][@tagListKey='1']"
         fromNamePath="Header/N1[N1/N101='SF']/N1/N102"
         fromTagListKey="1"
         fromType="profile"
         toKey="12" toKeyPath="*[@key='1']/*[@key='10']/*[@key='12']"
         toNamePath="PurchaseOrder/Ship_From/SF_Name"
         toType="profile"/>
```

The same `fromKey` can appear in multiple mappings with different `fromTagListKey` values — each routing a different loop instance to a different target field.

### Destination-Side: `toTagListKey`

When the **target** profile has tagLists, add `toTagListKey` to specify which instance to write to:

```xml
<Mapping fromKey="2" fromKeyPath="*[@key='1']/*[@key='2']" fromNamePath="Data/BuyerName"
         fromType="profile"
         toKey="12" toKeyPath="*[@key='1']/*[@key='10'][@tagListKey='1']/*[@key='12'][@tagListKey='1']"
         toNamePath="Order/Party[Party/Type='Buyer']/Name"
         toTagListKey="1" toType="profile"/>
```

#### Auto-Population Behavior

When using `toTagListKey`, Boomi automatically populates qualifier elements in the target:

- All qualifier fields (elements referenced by `identifierKey` in TagExpressions) are auto-populated with their `identifierValue`
- This works for compound qualifiers — every TagExpression in the GroupingExpression contributes
- Explicit mappings to qualifier fields override auto-population
- Without `toTagListKey`, multiple mappings from non-repeating source fields to the same repeating element collapse into a single instance (last-write-wins). This is the fan-in case only — a repeating source iterating into a repeating target does not need `toTagListKey`

### keyPath Pattern

The `fromTagListKey` / `toTagListKey` attributes are the only runtime-critical attributes for instance routing. The `[@tagListKey='X']` selectors in `fromKeyPath` are cosmetic metadata for GUI readability — the engine ignores them. All three of these produce identical runtime results:

```
Full selectors:    *[@key='1']/*[@key='20'][@tagListKey='1']/*[@key='21'][@tagListKey='1']/*[@key='23'][@tagListKey='1']
Loop-only:         *[@key='1']/*[@key='20'][@tagListKey='1']/*[@key='21']/*[@key='23']
No selectors:      *[@key='1']/*[@key='20']/*[@key='21']/*[@key='23']   (with fromTagListKey="1")
```

For programmatic map generation, you can omit `[@tagListKey]` from keyPaths entirely — just set `fromTagListKey` / `toTagListKey` on the Mapping element.

### namePath Filter Syntax

The `fromNamePath` / `toNamePath` include a human-readable filter showing the qualifier:
```
Header/N1[N1/N101='SF']/N1/N102
Order/Party[Party/Type='Buyer']/Name
```

### Attribute Reference

| Attribute | Type | Purpose |
|-----------|------|---------|
| `fromTagListKey` | string | References source profile's `<TagList listKey>` |
| `toTagListKey` | string | References target profile's `<TagList listKey>` |

Both attributes can coexist on a single Mapping for instanced-to-instanced routing (e.g., EDI qualifiers to XML qualifiers). Each resolves independently against its own profile's tagLists — the `listKey` numbers do not need to match between source and target profiles.

## Observed Patterns

### Array Path Notation
A JSON array leaf resolves to a namePath that repeats the array name, then inserts the array-element and object wrappers. For an array named `lines` carrying a `sku` field:
```
Root/Object/lines/lines/ArrayElement1/Object/sku
```

### Functions Element
A map with no transformations carries a plain `<Functions/>` with no attributes. Once a map has functions the container carries `optimizeExecutionOrder`, which defaults to `"true"` — see references/components/map_component_functions.md § Function Execution Order.

## Complete Examples

### Example 1: Minimal Key-Based Map
```xml
<?xml version="1.0" encoding="UTF-8"?>
<bns:Component xmlns:bns="http://api.platform.boomi.com/" 
               folderId="Rjo3OTMxMDM3" 
               name="Customer JSON to XML Map" 
               type="transform.map">
  <bns:object>
    <Map fromProfile="[JSON_PROFILE_ID]" toProfile="[XML_PROFILE_ID]">
      <Mappings>
        <Mapping fromKey="2" fromType="profile" toKey="1" toType="profile"/>
        <Mapping fromKey="3" fromType="profile" toKey="2" toType="profile"/>
        <Mapping fromKey="4" fromType="profile" toKey="3" toType="profile"/>
      </Mappings>
      <Functions/>
      <Defaults/>
      <DocumentCacheJoins/>
    </Map>
  </bns:object>
</bns:Component>
```

### Example 2: Same Profile Field Filtering
```xml
<?xml version="1.0" encoding="UTF-8"?>
<bns:Component xmlns:bns="http://api.platform.boomi.com/"
               folderId="[FOLDER_ID]"
               name="Salesforce Field Filter Map"
               type="transform.map">
  <bns:object>
    <Map fromProfile="[SALESFORCE_PROFILE_ID]" toProfile="[SALESFORCE_PROFILE_ID]">
      <Mappings>
        <Mapping fromKey="5" fromType="profile" toKey="5" toType="profile"/>
        <Mapping fromKey="12" fromType="profile" toKey="12" toType="profile"/>
        <Mapping fromKey="23" fromType="profile" toKey="23" toType="profile"/>
      </Mappings>
      <Functions/>
      <Defaults/>
      <DocumentCacheJoins/>
    </Map>
  </bns:object>
</bns:Component>
```

## Map Functions

Map functions allow transformation logic beyond simple field-to-field mapping to be applied to individual field values as they are being mapped.

Functions come in two types:

- **Standard functions** — single-step built-in operations spanning these categories: Connector, Custom Scripting, Date, Language, Lookup, Numeric, Properties, and String.
- **User-Defined functions** — reusable, standalone components (`type="transform.function"`) that chain multiple standard function steps together in a defined sequence.

See references/components/map_component_functions.md for comprehensive function documentation, and references/components/user_defined_function_component.md for authoring User-Defined Function components.

## Usage in Process

Maps are referenced by Map steps in the process canvas:
1. Create Map component with source/destination profiles
2. Add Map step to process
3. Configure step to reference the Map component ID
4. Documents flow through and are transformed

## Best Practices

### Design Decisions
- One map per transformation
- Use meaningful names describing the transformation
- Test with representative data samples
- Only map fields you need - unmapped fields simply don't appear in output

### Key Management
- Keys are platform-generated during profile creation
- Use key-based mapping for programmatic map generation
- Platform provides human-readable paths for reference

### Profile Management
- Ensure profiles are complete before creating maps
- Update maps when profiles change