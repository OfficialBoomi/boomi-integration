# XML Profile Component

## Contents
- Purpose
- Minimum Configuration
- Building DataElements
- XML Attributes
- Namespaces
- Instance Identifiers and Qualifiers
- Common Patterns
- Key Generation Rules
- Critical Notes
- Large Profiles (WSDL/SOAP)
- Example: Simple API Response

## Purpose
Defines the structure and data types for XML documents flowing through a Boomi process. Used for parsing incoming XML and generating outgoing XML.

## Minimum Configuration

```xml
<bns:Component xmlns:bns="http://api.platform.boomi.com/"
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               componentId=""
               name="YourProfileName"
               type="profile.xml"
               folderId="{folder-id}">
  <bns:encryptedValues/>
  <bns:object>
    <XMLProfile modelVersion="2" strict="true">
      <ProfileProperties>
        <XMLGeneralInfo/>
        <XMLOptions encoding="utf8" implicitElementOrdering="true" parseRespectMaxOccurs="true">
          <XMLFlavor><CustomStandardFlavor/></XMLFlavor>
        </XMLOptions>
      </ProfileProperties>
      <DataElements>
        <!-- Root element structure goes here -->
      </DataElements>
      <Namespaces/>
    </XMLProfile>
  </bns:object>
</bns:Component>
```

## Building DataElements

### Basic Field Structure
Each XMLElement requires:
- `key` - Unique sequential identifier
- `name` - Element/attribute name
- `dataType` - character, number, datetime, bit
- `isMappable` - true for fields you want to map
- `isNode` - true for elements (false for attributes)
- `maxOccurs` - 1 for single, -1 for unbounded/repeating
- `minOccurs` - 0 for optional, 1 for required

### Simple Flat Structure
```xml
<XMLElement dataType="character" isMappable="true" isNode="true" key="1" maxOccurs="1" minOccurs="0" name="RootElement" useNamespace="-1">
  <DataFormat>
    <ProfileCharacterFormat/>
  </DataFormat>
  <XMLElement dataType="character" isMappable="true" isNode="true" key="2" maxOccurs="1" minOccurs="0" name="Field1" useNamespace="-1">
    <DataFormat>
      <ProfileCharacterFormat/>
    </DataFormat>
  </XMLElement>
  <XMLElement dataType="number" isMappable="true" isNode="true" key="3" maxOccurs="1" minOccurs="0" name="Field2" useNamespace="-1">
    <DataFormat>
      <ProfileNumberFormat numberFormat=""/>
    </DataFormat>
  </XMLElement>
</XMLElement>
```

### Nested Object Structure
For nested objects, parent has `isMappable="false"`:
```xml
<XMLElement dataType="character" isMappable="false" isNode="true" key="10" maxOccurs="1" minOccurs="0" name="NestedObject" useNamespace="-1">
  <DataFormat>
    <ProfileCharacterFormat/>
  </DataFormat>
  <XMLElement dataType="character" isMappable="true" isNode="true" key="11" maxOccurs="1" minOccurs="0" name="ChildField" useNamespace="-1">
    <DataFormat>
      <ProfileCharacterFormat/>
    </DataFormat>
  </XMLElement>
</XMLElement>
```

### Repeating Elements (Arrays)
Use `maxOccurs="-1"` for unbounded repeating:
```xml
<XMLElement dataType="character" isMappable="true" isNode="true" key="20" maxOccurs="-1" minOccurs="0" name="RepeatingItem" useNamespace="-1">
  <DataFormat>
    <ProfileCharacterFormat/>
  </DataFormat>
  <XMLElement dataType="character" isMappable="true" isNode="true" key="21" maxOccurs="1" minOccurs="0" name="ItemField" useNamespace="-1">
    <DataFormat>
      <ProfileCharacterFormat/>
    </DataFormat>
  </XMLElement>
</XMLElement>
```

### Data Type Formats

#### Character (String)
```xml
<DataFormat>
  <ProfileCharacterFormat/>
</DataFormat>
```

#### Number
```xml
<DataFormat>
  <ProfileNumberFormat numberFormat=""/>
</DataFormat>
```

#### DateTime
Common patterns:
```xml
<DataFormat>
  <ProfileDateFormat dateFormat="yyyy-MM-dd"/>  <!-- Date only -->
</DataFormat>

<DataFormat>
  <ProfileDateFormat dateFormat="yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"/>  <!-- ISO timestamp -->
</DataFormat>
```

#### Boolean (bit)
```xml
<DataFormat>
  <ProfileBitFormat/>
</DataFormat>
```

## XML Attributes
Set `isNode="false"` for attributes:
```xml
<XMLElement dataType="character" isMappable="true" isNode="false" key="30" maxOccurs="1" minOccurs="0" name="attributeName" useNamespace="-1">
  <DataFormat>
    <ProfileCharacterFormat/>
  </DataFormat>
</XMLElement>
```

## Namespaces
When XML uses namespaces, define them:
```xml
<Namespaces>
  <Namespace key="1" prefix="ns" uri="http://example.com/namespace"/>
</Namespaces>
```

Then reference in elements with `useNamespace="1"` (matching the key).

## Instance Identifiers and Qualifiers

XML profiles support instance identifiers using `<tagLists>`. The block goes inside `<XMLProfile>`, AFTER `<Namespaces>`:

```
XMLProfile element ordering:
  ProfileProperties → DataElements → Namespaces → tagLists
```

### Structure

```xml
<XMLProfile modelVersion="2" strict="true">
  <ProfileProperties>...</ProfileProperties>
  <DataElements>...</DataElements>
  <Namespaces/>
  <tagLists>
    <TagList elementKey="3" listKey="1">
      <GroupingExpression operator="and">
        <TagExpression identifierKey="4" identifierName="Type" identifierType="value">
          <identifierValue>Buyer</identifierValue>
        </TagExpression>
      </GroupingExpression>
    </TagList>
    <TagList elementKey="3" listKey="2">
      <GroupingExpression operator="and">
        <TagExpression identifierKey="4" identifierName="Type" identifierType="value">
          <identifierValue>Seller</identifierValue>
        </TagExpression>
      </GroupingExpression>
    </TagList>
  </tagLists>
</XMLProfile>
```

### TagList Attributes

| Attribute | Type | Purpose |
|-----------|------|---------|
| `elementKey` | int | Key of the repeating element this instance identifier applies to |
| `listKey` | int | Unique identifier for this TagList (referenced by maps as `fromTagListKey` / `toTagListKey`) |
| `parentListKey` | int | For nested instances: `listKey` of the parent TagList this child nests within. Default `-1` (no parent) |

### TagExpression Attributes

| Attribute | Type | Required | Purpose |
|-----------|------|----------|---------|
| `identifierKey` | int | Yes | For `identifierType="value"`: key of the child element that holds the qualifier value. For `identifierType="occurrence"`: use `-1` (conventional; runtime ignores this value for occurrence expressions) |
| `identifierName` | string | Yes | For value type: name of the qualifier element (e.g., `"Type"`). For occurrence type: `"occurrence"` |
| `identifierType` | enum | No | `"value"` (match by qualifier value) or `"occurrence"` (match by position) |

The `<identifierValue>` child element holds:
- For `identifierType="value"`: the qualifier string to match
- For `identifierType="occurrence"`: a 1-based positional selector — `"1"` for first, `"2"` for second, `"-1"` for last. `"0"` is invalid and causes a silent map failure

### Map Integration

Maps use `fromTagListKey` and `toTagListKey` attributes on `<Mapping>` elements to reference the TagList's `listKey`. See map_component.md for full mapping syntax.

## Common Patterns

### REST API Response Profile
Typically a root container with repeating records:
```xml
<XMLElement dataType="character" isMappable="true" isNode="true" key="1" maxOccurs="-1" minOccurs="0" name="Record" useNamespace="-1">
  <!-- Individual record fields -->
</XMLElement>
```

### SOAP Response Profile  
Often includes envelope/body wrapper:
```xml
<XMLElement dataType="character" isMappable="false" isNode="true" key="1" maxOccurs="1" minOccurs="1" name="Envelope" useNamespace="1">
  <XMLElement dataType="character" isMappable="false" isNode="true" key="2" maxOccurs="1" minOccurs="1" name="Body" useNamespace="1">
    <!-- Actual response data -->
  </XMLElement>
</XMLElement>
```

## Key Generation Rules
- Keys must be unique across the entire profile
- Start from 1 and increment sequentially
- When adding nested elements, continue the sequence (don't restart at 1)

## Critical Notes
- `isNode="true"` for XML elements, `isNode="false"` for XML attributes
- Parent containers of nested objects should have `isMappable="false"`
- Leaf nodes (actual data fields) should have `isMappable="true"`
- Always include `useNamespace="-1"` unless using defined namespaces
- The `strict="true"` setting enforces validation
- Date formats use Java SimpleDateFormat patterns
- Always include `<XMLFlavor><CustomStandardFlavor/></XMLFlavor>` inside `<XMLOptions>`. 
  - GUI-created profiles contain an empty `<XMLFlavor/>` element that fails schema validation on PUT/POST (`cvc-complex-type.2.4.b`). Including the expanded form avoids this and is safe for all profiles. 
  - Important: If you pull down an xml profile from the GUI you will likely need to modify that element before pushing the profile back into the platform.

## Large Profiles (WSDL/SOAP)
XML profiles derived from WSDL schemas (Workday, SAP, etc.) can exceed 1MB and contain duplicate field names in different contexts (e.g., 60+ "First_Name" fields). For profiles >500KB, use `boomi-profile-inspect.py` to generate a searchable field inventory with full hierarchical paths for element ID disambiguation. The tool also supports EDI and Flat File profiles.

### Depth Truncation
Boomi enforces a depth limit (~10 levels) during WSDL import. Elements beyond this depth have `typeExpanded="false"` and missing child attributes.

**Identifying truncated elements:**
```xml
<!-- Truncated - missing @type attribute -->
<XMLElement key="7348" name="ID" typeExpanded="false" typeKey="88" ...>
  <DataFormat><ProfileCharacterFormat/></DataFormat>
</XMLElement>
```

**Manual expansion fix:**
1. Change `typeExpanded="false"` → `typeExpanded="true"`
2. Add the missing attribute with a unique key (use a high number like 9001+):
```xml
<XMLElement key="7348" name="ID" typeExpanded="true" typeKey="88" ...>
  <DataFormat><ProfileCharacterFormat/></DataFormat>
  <XMLAttribute dataType="character" isMappable="true" isNode="true"
                key="9001" name="type" required="true" useNamespace="-1">
    <DataFormat><ProfileCharacterFormat/></DataFormat>
  </XMLAttribute>
</XMLElement>
```
3. Push modified profile to platform
4. Add map default for the new key: `<Default toKey="9001" value="ISO_3166-1_Alpha-3_Code"/>`

**Common in**: Workday, SAP, and other enterprise schemas where `ID` elements require `@type` attributes deep in the hierarchy.

## Example: Simple API Response
```xml
<DataElements>
  <XMLElement dataType="character" isMappable="true" isNode="true" key="1" maxOccurs="1" minOccurs="0" name="response" useNamespace="-1">
    <DataFormat>
      <ProfileCharacterFormat/>
    </DataFormat>
    <XMLElement dataType="character" isMappable="true" isNode="true" key="2" maxOccurs="1" minOccurs="0" name="status" useNamespace="-1">
      <DataFormat>
        <ProfileCharacterFormat/>
      </DataFormat>
    </XMLElement>
    <XMLElement dataType="character" isMappable="true" isNode="true" key="3" maxOccurs="-1" minOccurs="0" name="item" useNamespace="-1">
      <DataFormat>
        <ProfileCharacterFormat/>
      </DataFormat>
      <XMLElement dataType="character" isMappable="true" isNode="true" key="4" maxOccurs="1" minOccurs="0" name="id" useNamespace="-1">
        <DataFormat>
          <ProfileCharacterFormat/>
        </DataFormat>
      </XMLElement>
      <XMLElement dataType="character" isMappable="true" isNode="true" key="5" maxOccurs="1" minOccurs="0" name="name" useNamespace="-1">
        <DataFormat>
          <ProfileCharacterFormat/>
        </DataFormat>
      </XMLElement>
    </XMLElement>
  </XMLElement>
</DataElements>
```