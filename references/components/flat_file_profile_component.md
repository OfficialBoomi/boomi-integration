# Flat File Profile Component Reference

## Contents
- Component Type
- When NOT to Use Flat File Profile
- Primary Use Cases
- XML Templates
- Configuration Options
- Data Positioned Field Attributes
- Multi-Record Format Configuration
- Required Field Attributes
- FillerFF Usage Pattern

## Component Type
`profile.flatfile`

## When NOT to Use Flat File Profile

**If you need hierarchical output where child records must appear immediately after their parent record, use another type of profile - often this will be in an EDI/B2B context so you would use an EDI Profile (`profile.edi` with `standard="userdef"`) instead.**

Flat file profiles produce all records as independent rows - they cannot express parent-child relationships. For example, if you need reference records (439) to appear immediately after their parent shipment (139) or location (239) records, you MUST use an EDI profile with nested `EdiLoop` structures.

See: `components/edi_profile_component.md` - especially the "Hierarchical Nesting for Parent-Child Output" section.

## Primary Use Cases

### 1. CSV/Delimited File Processing
Define structure for CSV, TSV, and other delimited formats.

### 2. Fixed-Width/Data Positioned File Processing
Define structure for legacy fixed-width formats where each field occupies a specific column position. Common in EDI-adjacent formats (TMW, mainframe exports).

### 3. FillerFF Pattern (Map Function Placeholder)
Use minimal flat file profile as source when map only uses functions (no field mappings). Avoids JSON/XML validation errors on arbitrary input documents.

## XML Templates

### FillerFF (Minimal Placeholder)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<bns:Component xmlns:bns="http://api.platform.boomi.com/" componentId=""
           name="FillerFF" type="profile.flatfile" folderId="{FOLDER_ID}">
  <bns:encryptedValues/>
  <bns:object>
    <FlatFileProfile modelVersion="2" strict="true">
      <ProfileProperties>
        <GeneralInfo fileType="delimited" useColumnHeaders="false"/>
        <Options>
          <DataOptions/>
          <DelimitedOptions fileDelimiter="stardelimited" removeEscape="false" textQualifier="na"/>
        </Options>
      </ProfileProperties>
      <DataElements>
        <FlatFileRecord detectFormat="numberofcolumns" isNode="true" key="1" name="Record">
          <FlatFileElements isNode="true" key="2" name="Elements">
            <FlatFileElement dataType="character" enforceUnique="false" isMappable="true" isNode="true"
                           key="3" mandatory="false" maxLength="0" minLength="0"
                           name="New Flat File Element" useToIdentifyFormat="false" validateData="false">
              <DataFormat>
                <ProfileCharacterFormat/>
              </DataFormat>
            </FlatFileElement>
          </FlatFileElements>
        </FlatFileRecord>
      </DataElements>
    </FlatFileProfile>
  </bns:object>
</bns:Component>
```

### Data Positioned (Fixed-Width) Template
```xml
<FlatFileProfile modelVersion="2" strict="true">
  <ProfileProperties>
    <GeneralInfo fileType="datapositioned" useColumnHeaders="false"/>
    <Options>
      <DataOptions padcharacter=" "/>
      <DelimitedOptions fileDelimiter="bardelimited" removeEscape="false" textQualifier="na"/>
    </Options>
  </ProfileProperties>
  <DataElements>
    <FlatFileRecord detectFormat="numberofcolumns" isNode="true" key="1" name="Record">
      <FlatFileElements isNode="true" key="2" name="Elements">
        <FlatFileElement dataType="character" enforceUnique="false" isMappable="true" isNode="true"
                        key="3" name="RecordType" startColumn="0" length="3"
                        justification="left" mandatory="false" validateData="false">
          <DataFormat>
            <ProfileCharacterFormat/>
          </DataFormat>
        </FlatFileElement>
        <FlatFileElement dataType="character" enforceUnique="false" isMappable="true" isNode="true"
                        key="4" name="CarrierCode" startColumn="3" length="4"
                        justification="left" mandatory="false" validateData="false">
          <DataFormat>
            <ProfileCharacterFormat/>
          </DataFormat>
        </FlatFileElement>
        <FlatFileElement dataType="character" enforceUnique="false" isMappable="true" isNode="true"
                        key="5" name="ShipmentID" startColumn="7" length="14"
                        justification="left" mandatory="false" validateData="false">
          <DataFormat>
            <ProfileCharacterFormat/>
          </DataFormat>
        </FlatFileElement>
      </FlatFileElements>
    </FlatFileRecord>
  </DataElements>
</FlatFileProfile>
```

### Multi-Record Format Template
For files with multiple record types (e.g., header/detail/trailer or TMW 139/239/339/439 records):
```xml
<DataElements>
  <FlatFileRecord detectFormat="uniquevalues" isNode="true" key="1" name="HeaderRecord">
    <FlatFileElements isNode="true" key="2" name="Elements">
      <FlatFileElement dataType="character" enforceUnique="false" isMappable="true" isNode="true"
                      key="3" name="RecordType" startColumn="0" length="3"
                      useToIdentifyFormat="true" identityValue="139"
                      justification="left" mandatory="false" validateData="false">
        <DataFormat>
          <ProfileCharacterFormat/>
        </DataFormat>
      </FlatFileElement>
      <!-- Header-specific fields with sequential keys and startColumn positions -->
    </FlatFileElements>
  </FlatFileRecord>
  <FlatFileRecord detectFormat="uniquevalues" isNode="true" key="10" name="AddressRecord">
    <FlatFileElements isNode="true" key="11" name="Elements">
      <FlatFileElement dataType="character" enforceUnique="false" isMappable="true" isNode="true"
                      key="12" name="RecordType" startColumn="0" length="3"
                      useToIdentifyFormat="true" identityValue="239"
                      justification="left" mandatory="false" validateData="false">
        <DataFormat>
          <ProfileCharacterFormat/>
        </DataFormat>
      </FlatFileElement>
      <!-- Address-specific fields -->
    </FlatFileElements>
  </FlatFileRecord>
</DataElements>
```

### Multiple Field Types Example (Delimited)
```xml
<FlatFileProfile modelVersion="2" strict="true">
  <ProfileProperties>
    <GeneralInfo fileType="delimited" useColumnHeaders="false"/>
    <Options>
      <DataOptions/>
      <DelimitedOptions fileDelimiter="commadelimited" removeEscape="false" textQualifier="na"/>
    </Options>
  </ProfileProperties>
  <DataElements>
    <FlatFileRecord detectFormat="numberofcolumns" isNode="true" key="1" name="Record">
      <FlatFileElements isNode="true" key="2" name="Elements">
        <FlatFileElement dataType="character" enforceUnique="false" isMappable="true" isNode="true"
                       key="3" mandatory="false" maxLength="0" minLength="0"
                       name="TextField" validateData="false">
          <DataFormat>
            <ProfileCharacterFormat/>
          </DataFormat>
        </FlatFileElement>
        <FlatFileElement dataType="number" enforceUnique="false" isMappable="true" isNode="true"
                       key="4" mandatory="false" maxLength="0" minLength="0"
                       name="NumberField" validateData="false">
          <DataFormat>
            <ProfileNumberFormat/>
          </DataFormat>
        </FlatFileElement>
        <FlatFileElement dataType="datetime" enforceUnique="false" isMappable="true" isNode="true"
                       key="5" mandatory="false" maxLength="0" minLength="0"
                       name="DateField" validateData="false">
          <DataFormat>
            <ProfileDateFormat dateFormat="yyyyMMdd HHmmss"/>
          </DataFormat>
        </FlatFileElement>
      </FlatFileElements>
    </FlatFileRecord>
  </DataElements>
</FlatFileProfile>
```

## Configuration Options

### File Types
- `fileType="delimited"` - Variable-length fields separated by delimiter
- `fileType="datapositioned"` - Fixed-width fields at specific column positions

### Pad Character (Data Positioned Only)
```xml
<DataOptions padcharacter=" "/>
```
- Space (`" "`) - Most common for fixed-width files
- Empty (`""`) - No padding
- Fills unused space when writing output; stripped when reading input

### Delimiter Options (fileDelimiter)
For delimited files:
- `stardelimited` - Star (*) Delimited
- `commadelimited` - Comma Delimited
- `tabdelimited` - Tab Delimited
- `tickdelimited` - Tick Mark (`) Delimited
- `bardelimited` - Bar (|) Delimited
- `otherdelimited` - Custom character (requires `fileDelimiterSpecial`)

### Custom Delimiter Example
```xml
<DelimitedOptions fileDelimiter="otherdelimited"
                  fileDelimiterSpecial="~!~"
                  removeEscape="false"
                  textQualifier="na"/>
```

### CSV Configuration
```xml
<DelimitedOptions fileDelimiter="commadelimited"
                  removeEscape="false"
                  textQualifier="doublequote"/>
```

### Data Types
- `character` - Text/string data
- `number` - Numeric values
- `datetime` - Date/time values (use `ProfileDateFormat` with `dateFormat` pattern)

## Data Positioned Field Attributes

For `fileType="datapositioned"` profiles, each FlatFileElement uses:

| Attribute | Description |
|-----------|-------------|
| `startColumn` | 0-indexed column position (first column is 0) |
| `length` | Field width in characters |
| `justification` | `"left"` (pad right) or `"right"` (pad left) |

Note: `minLength`/`maxLength` are for delimited files only.

### Example Field Positions
For a record like `139USIT8379418       22951026`:
```xml
<FlatFileElement name="RecordType" startColumn="0" length="3"/>   <!-- "139" -->
<FlatFileElement name="CarrierCode" startColumn="3" length="4"/>  <!-- "USIT" -->
<FlatFileElement name="ShipmentID" startColumn="7" length="14"/>  <!-- "8379418       " -->
<FlatFileElement name="OrderNum" startColumn="21" length="10"/>   <!-- "22951026  " -->
```

## Multi-Record Format Configuration

For files containing multiple record types (common in EDI-adjacent formats):

### Record Format Detection
- `detectFormat="numberofcolumns"` - Detect by field count (default)
- `detectFormat="uniquevalues"` - Detect by identity value in a field

### Identity Value Configuration
On the element that identifies the record type:
```xml
<FlatFileElement name="RecordType"
                useToIdentifyFormat="true"
                identityValue="139"
                mandatory="false"
                .../>
```

**Identity fields should default to `mandatory="false"`.** Identity detection relies on `identityValue` comparison alone — it does not require `mandatory="true"`. If this profile is ever used as map output and not all record types are mapped, `mandatory="true"` on identity fields causes `MANDATORY_ELEMENT_MISSING` errors on unmapped records. Since profiles are often reused across contexts, `mandatory="false"` on identity fields is the safe default. See `references/guides/boomi_error_reference.md` Issue #25.

Note: `mandatory="true"` remains valid on regular data fields when you want input validation or output enforcement.

**Data positioned profiles: `identityValue` must be the trimmed identifier — never padded to field width.** Boomi trims extracted field values before comparing against `identityValue`, but does NOT trim `identityValue` itself. If an identity value is shorter than the field width (e.g., "BF" in a 3-char field), the extracted "BF " gets trimmed to "BF" but `identityValue="BF "` stays as-is — causing a silent match failure where the record vanishes from output with no error. This is specific to data positioned profiles because fixed-width fields pad shorter values with whitespace. See `references/guides/boomi_error_reference.md` Issue #26.

### Key Numbering for Multi-Record
Each `FlatFileRecord` and its elements need unique keys:
- Record 1: key="1", Elements key="2", fields start at key="3"
- Record 2: key="10", Elements key="11", fields start at key="12"
- Record 3: key="20", Elements key="21", fields start at key="22"

### Record Output Behavior
Multi-record data-positioned output concatenates records **without newline characters**. Record boundaries are determined by position/length, not line breaks. Example output (HDR + 2 DTL + TRL, each 40 chars):
```
HDRORD-00123420260113CUST-ABC123         DTL001WIDGET-01     10     25.99         DTL002GADGET-02      5    149.50         TRL    2        1007.40
```

## Critical: enforceUnique Attribute

**All `FlatFileElement` nodes MUST include `enforceUnique="false"`.**

Omitting this attribute causes:
```
java.lang.NullPointerException at FlatFileDataParser.addRecord
```

This error occurs during process runtime initialization (not execution). The Boomi API silently accepts profiles without this attribute, but they fail at runtime.

This requirement applies to ALL profile types: delimited, data-positioned, and multi-record.

### Minimum Required Element
```xml
<FlatFileElement dataType="character" enforceUnique="false" isMappable="true"
                isNode="true" key="3" name="FieldName"/>
```

### Recommended (Not Required)
These attributes are good practice but do not cause NPE if omitted:
- `useToIdentifyFormat="false"` - Recommended on non-identity fields
- `<DataFormat><ProfileCharacterFormat/></DataFormat>` - Optional
- `validateData="false"` - Recommended
- `mandatory="false"` - Recommended

## Required Field Attributes

### Delimited Files
**Required:**
- `key` - Sequential unique identifier
- `name` - Field identifier
- `dataType` - character/number/datetime
- `enforceUnique="false"` - Prevents NullPointerException
- `isMappable="true"` - For data fields
- `isNode="true"` - Always true

**Recommended:**
- `maxLength="0"` / `minLength="0"` - 0 = unlimited
- `validateData="false"` - Skip validation
- `useToIdentifyFormat="false"` - Explicit on non-identity fields

### Data Positioned Files
**Required:**
- `key` - Sequential unique identifier
- `name` - Field identifier
- `dataType` - character/number/datetime
- `enforceUnique="false"` - Prevents NullPointerException
- `isMappable="true"` - For data fields
- `isNode="true"` - Always true
- `startColumn` - 0-indexed start position
- `length` - Field width

**Recommended:**
- `justification` - "left" or "right" (defaults to left)
- `validateData="false"` - Skip validation
- `useToIdentifyFormat="false"` - Explicit on non-identity fields

## FillerFF Usage Pattern
Use minimal flat file profile when map only needs functions, not field mappings:
- Accepts any document without format validation
- Single placeholder field is sufficient
- Reuse across processes
