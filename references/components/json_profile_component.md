# JSON Profile Component

JSON Profile components define the structure of JSON documents for field-level mapping and validation.

## Contents
- JSON Transformation Pipeline
- Required XML Structure
- Data Type Mappings
- Implementation Notes
- Instance Identifiers and Qualifiers
- Complete Example

## JSON Transformation Pipeline

Raw JSON → Normalized JSON → Boomi XML Profile

**Normalization Rules:**
- String/null values → `"string"`
- Numbers → `1`
- Booleans → `true`
- Empty arrays → `[]`
- Primitive arrays → `["string"]`, `[1]`, or `[true]`
- Object arrays → Single representative object with ALL unique fields from ALL array elements

**Array Field Consolidation Example:**
```json
// Raw JSON
{"dogs": [{"name": "fido", "breed": "lab"}, {"name": "spot", "location": "tulsa"}]}

// Normalized (all fields consolidated)
{"dogs": [{"name": "string", "breed": "string", "location": "string"}]}
```

## Required XML Structure

```xml
<?xml version="1.0" encoding="UTF-8"?>
<bns:Component xmlns:bns="http://api.platform.boomi.com/"
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               componentId=""
               name="{profile-name}"
               type="profile.json"
               folderId="{folder-id}">
  <bns:encryptedValues/>
  <bns:object>
    <JSONProfile strict="false">
      <DataElements>
        <JSONRootValue dataType="character" isMappable="true" isNode="true" key="1" name="Root">
          <DataFormat><ProfileCharacterFormat/></DataFormat>
          <JSONObject isMappable="false" isNode="true" key="2" name="Object">
            <!-- Profile entries go here -->
          </JSONObject>
          <Qualifiers><QualifierList/></Qualifiers>
        </JSONRootValue>
      </DataElements>
      <tagLists/>
    </JSONProfile>
  </bns:object>
</bns:Component>
```

**Platform Requirements** (validated against Boomi API):
- `strict="false"` on JSONProfile
- `<tagLists/>` closing element
- `isMappable="true"` on JSONRootValue, `isMappable="false"` on JSONObject
- `<DataFormat>` on JSONRootValue
- `<Qualifiers><QualifierList/></Qualifiers>` on JSONRootValue
- `folderId` attribute (not `folderFullPath`)
- `<bns:encryptedValues/>` element

## Data Type Mappings

**String:**
```xml
<JSONObjectEntry dataType="character" isMappable="true" isNode="true" key="{key}" name="{name}">
  <DataFormat><ProfileCharacterFormat/></DataFormat>
</JSONObjectEntry>
```

**Number:**
```xml
<JSONObjectEntry dataType="number" isMappable="true" isNode="true" key="{key}" name="{name}">
  <DataFormat><ProfileNumberFormat numberFormat=""/></DataFormat>
</JSONObjectEntry>
```

**Boolean:**
```xml
<JSONObjectEntry dataType="boolean" isMappable="true" isNode="true" key="{key}" name="{name}">
  <DataFormat><ProfileBooleanFormat/></DataFormat>
</JSONObjectEntry>
```

**DateTime:**
```xml
<JSONObjectEntry dataType="datetime" isMappable="true" isNode="true" key="{key}" name="{name}">
  <DataFormat><ProfileDateFormat/></DataFormat>
</JSONObjectEntry>
```

**Arrays** (container + definition + element):
```xml
<JSONObjectEntry dataType="character" isMappable="false" isNode="true" key="{key}" name="{array-name}">
  <DataFormat><ProfileCharacterFormat/></DataFormat>
  <JSONArray elementType="repeating" isMappable="false" isNode="true" key="{key+1}" name="{array-name}">
    <JSONArrayElement dataType="character" isMappable="false" isNode="true" key="{key+2}"
                      maxOccurs="-1" minOccurs="0" name="ArrayElement1">
      <!-- For object arrays: nest <JSONObject>. For primitives: add <DataFormat> -->
    </JSONArrayElement>
  </JSONArray>
</JSONObjectEntry>
```

**Nested Objects:**
```xml
<JSONObjectEntry dataType="character" isMappable="false" isNode="true" key="{key}" name="{object-name}">
  <DataFormat><ProfileCharacterFormat/></DataFormat>
  <JSONObject isMappable="false" isNode="true" key="{key+1}" name="Object">
    <!-- Nested entries here -->
  </JSONObject>
</JSONObjectEntry>
```

**Key Rules:**
- Unique across entire profile, sequential from 1
- Don't restart numbering in nested structures

## Implementation Notes

**Type Detection:**
- Numbers → `number`
- `true`/`false` → `boolean`
- ISO dates → `datetime` (default to `character` if uncertain)
- Everything else → `character`

**Mappable vs Container:**
- Leaf fields (actual data) → `isMappable="true"`
- Containers (objects, arrays) → `isMappable="false"`
- Mapping to a key with `isMappable="false"` silently drops the value — no push error, no runtime error, data simply vanishes. Always verify the target key references an `isMappable="true"` element.

**Array Field Discovery:**
Scan ALL array elements to consolidate unique fields before generating profile

## Instance Identifiers and Qualifiers

JSON profiles support instance identifiers on repeating arrays using `<tagLists>`. The `elementKey` targets the `JSONArrayElement`, and `identifierKey` can reference any descendant `JSONObjectEntry` within the array element's subtree (not limited to immediate children):

```xml
<JSONProfile strict="false">
  <DataElements>
    ...
    <JSONArrayElement key="5" maxOccurs="-1" ...>
      <JSONObject key="6" ...>
        <JSONObjectEntry key="7" name="type" .../>  <!-- identifier field -->
        <JSONObjectEntry key="8" name="name" .../>
      </JSONObject>
    </JSONArrayElement>
    ...
  </DataElements>
  <tagLists>
    <TagList elementKey="5" listKey="1">
      <GroupingExpression operator="and">
        <TagExpression identifierKey="7" identifierName="type" identifierType="value">
          <identifierValue>Buyer</identifierValue>
        </TagExpression>
      </GroupingExpression>
    </TagList>
    <TagList elementKey="5" listKey="2">
      <GroupingExpression operator="and">
        <TagExpression identifierKey="7" identifierName="type" identifierType="value">
          <identifierValue>Seller</identifierValue>
        </TagExpression>
      </GroupingExpression>
    </TagList>
  </tagLists>
</JSONProfile>
```

### TagList Attributes

| Attribute | Type | Purpose |
|-----------|------|---------|
| `elementKey` | int | Key of the `JSONArrayElement` this instance identifier applies to |
| `listKey` | int | Unique identifier for this TagList (referenced by maps as `fromTagListKey` / `toTagListKey`) |
| `parentListKey` | int | For nested instances: `listKey` of the parent TagList this child nests within. Default `-1` (no parent) |

### TagExpression Attributes

| Attribute | Type | Required | Purpose |
|-----------|------|----------|---------|
| `identifierKey` | int | Yes | For `identifierType="value"`: key of the `JSONObjectEntry` that holds the qualifier value. For `identifierType="occurrence"`: use `-1` (conventional; runtime ignores this value for occurrence expressions) |
| `identifierName` | string | Yes | For value type: name of the qualifier entry (e.g., `"type"`). For occurrence type: `"occurrence"` |
| `identifierType` | enum | No | `"value"` (match by qualifier value) or `"occurrence"` (match by position within the filtered subset) |

The `<identifierValue>` child element holds:
- For `identifierType="value"`: the qualifier string to match
- For `identifierType="occurrence"`: a 1-based positional selector — `"1"` for first, `"2"` for second, `"-1"` for last. `"0"` is invalid and causes a silent map failure (no output documents produced)

### Occurrence (Positional) Selection

An occurrence TagExpression selects an array element by position. It can be used standalone (select the Nth or last element in the array) or combined with a value TagExpression to select by position within the filtered subset.

**Standalone — last element in array:**
```xml
<TagList elementKey="5" listKey="1">
  <GroupingExpression operator="and">
    <TagExpression identifierKey="-1" identifierName="occurrence" identifierType="occurrence">
      <identifierValue>-1</identifierValue>  <!-- 1-based: 1=first, 2=second, -1=last -->
    </TagExpression>
  </GroupingExpression>
</TagList>
```

**Combined with value filter — last element where type="text":**
```xml
<TagList elementKey="5" listKey="1">
  <GroupingExpression operator="and">
    <TagExpression identifierKey="7" identifierName="type" identifierType="value">
      <identifierValue>text</identifierValue>
    </TagExpression>
    <TagExpression identifierKey="-1" identifierName="occurrence" identifierType="occurrence">
      <identifierValue>-1</identifierValue>
    </TagExpression>
  </GroupingExpression>
</TagList>
```

When combined, the occurrence operates within the value-filtered subset, not the full array.

### Qualifiers

Qualifiers must be added to profile elements that participate in instance identification. They are required for the instance identifier configuration to be visible and editable in the Boomi GUI. Always include them even when generating profiles programmatically.

Add a `<Qualifiers>` block to the element referenced by `identifierKey` in value-type TagExpressions:

```xml
<JSONObjectEntry key="7" name="type" ...>
  <Qualifiers>
    <QualifierList>
      <Qualifier description="type=text" qualifierValue="text"/>
    </QualifierList>
  </Qualifiers>
</JSONObjectEntry>
```

The `description` attribute is a human-readable label (freeform). The `qualifierValue` must match the `<identifierValue>` in the corresponding TagExpression.

### Map Integration

Maps use `fromTagListKey` and `toTagListKey` attributes on `<Mapping>` elements to reference the TagList's `listKey`. See map_component.md for full mapping syntax.

## Complete Example

**Raw API response:**
```json
{"orderId": "ORD-123", "amount": 99.99, "items": [{"sku": "ABC", "qty": 2}, {"sku": "DEF", "description": "Widget"}]}
```

**Normalized:**
```json
{"orderId": "string", "amount": 1, "items": [{"sku": "string", "qty": 1, "description": "string"}]}
```

**XML Profile:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<bns:Component xmlns:bns="http://api.platform.boomi.com/"
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               componentId="" name="Order_Profile" type="profile.json" folderId="{folder-id}">
  <bns:encryptedValues/>
  <bns:object>
    <JSONProfile strict="false">
      <DataElements>
        <JSONRootValue dataType="character" isMappable="true" isNode="true" key="1" name="Root">
          <DataFormat><ProfileCharacterFormat/></DataFormat>
          <JSONObject isMappable="false" isNode="true" key="2" name="Object">
            <JSONObjectEntry dataType="character" isMappable="true" isNode="true" key="3" name="orderId">
              <DataFormat><ProfileCharacterFormat/></DataFormat>
            </JSONObjectEntry>
            <JSONObjectEntry dataType="number" isMappable="true" isNode="true" key="4" name="amount">
              <DataFormat><ProfileNumberFormat numberFormat=""/></DataFormat>
            </JSONObjectEntry>
            <JSONObjectEntry dataType="character" isMappable="false" isNode="true" key="5" name="items">
              <DataFormat><ProfileCharacterFormat/></DataFormat>
              <JSONArray elementType="repeating" isMappable="false" isNode="true" key="6" name="items">
                <JSONArrayElement dataType="character" isMappable="false" isNode="true" key="7"
                                  maxOccurs="-1" minOccurs="0" name="ArrayElement1">
                  <JSONObject isMappable="false" isNode="true" key="8" name="Object">
                    <JSONObjectEntry dataType="character" isMappable="true" isNode="true" key="9" name="sku">
                      <DataFormat><ProfileCharacterFormat/></DataFormat>
                    </JSONObjectEntry>
                    <JSONObjectEntry dataType="number" isMappable="true" isNode="true" key="10" name="qty">
                      <DataFormat><ProfileNumberFormat numberFormat=""/></DataFormat>
                    </JSONObjectEntry>
                    <JSONObjectEntry dataType="character" isMappable="true" isNode="true" key="11" name="description">
                      <DataFormat><ProfileCharacterFormat/></DataFormat>
                    </JSONObjectEntry>
                  </JSONObject>
                </JSONArrayElement>
              </JSONArray>
            </JSONObjectEntry>
          </JSONObject>
          <Qualifiers><QualifierList/></Qualifiers>
        </JSONRootValue>
      </DataElements>
      <tagLists/>
    </JSONProfile>
  </bns:object>
</bns:Component>
```