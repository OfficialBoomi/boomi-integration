# EDI Profile Component Reference

## Contents
- Component Type
- Primary Use Cases
- XML Structure Overview
- ProfileProperties Configuration
- EdiGeneralInfo
- When to Use UserDef Standard
- EdiFileOptions
- DataPositioned vs Delimited
- EdiDelimitedOptions
- Standard-Specific Options
- Element Hierarchy
- EdiLoop Attributes
- Hierarchical Nesting for Parent-Child Output
- EdiSegment Attributes
- EdiDataElement Attributes
- Data Types Reference
- Validation Rules
- Composites and Sub-Composites
- Instance Identifiers and Qualifiers
- Key Numbering Strategy
- Required Attributes Checklist
- Critical: Segment Terminator Mismatch

## Component Type
`profile.edi`

## Primary Use Cases
Defining EDI document schemas for parsing inbound EDI or generating outbound EDI in Boomi transformations. Used as source or destination profiles in Map components.

## XML Structure Overview

```xml
<?xml version="1.0" encoding="UTF-8"?>
<bns:Component xmlns:bns="http://api.platform.boomi.com/"
               componentId="" name="EDI_Profile_Name" type="profile.edi" folderId="{FOLDER_ID}">
  <bns:encryptedValues/>
  <bns:object>
    <EdiProfile strict="true">
      <ProfileProperties>
        <EdiGeneralInfo conditionalValidationEnabled="true" standard="x12"/>
        <EdiFileOptions fileType="delimited">
          <EdiDelimitedOptions fileDelimiter="stardelimited" repeatDelimiter="tildedelimited" segmentchar="newline"/>
          <EdiDataOptions/>
        </EdiFileOptions>
        <EdiOptions>
          <EdiX12Options isacontrolstandard="U" isacontrolversion="00401" stdversion="4010" tranfuncid="QM" transmission="214"/>
        </EdiOptions>
      </ProfileProperties>
      <DataElements>
        <!-- EdiLoop, EdiSegment, and EdiDataElement hierarchy -->
      </DataElements>
    </EdiProfile>
  </bns:object>
</bns:Component>
```

### EdiProfile Root Attributes

| Attribute | Type | Default | Purpose |
|-----------|------|---------|---------|
| `strict` | boolean | false | Enable strict parsing mode |

## ProfileProperties Configuration

ProfileProperties contains three required child elements:
1. `EdiGeneralInfo` - General profile settings
2. `EdiFileOptions` - File format and delimiter settings
3. `EdiOptions` - Standard-specific options (X12, EDIFACT, etc.)

## EdiGeneralInfo

```xml
<EdiGeneralInfo conditionalValidationEnabled="true" standard="x12"/>
```

| Attribute | Type | Default | Purpose |
|-----------|------|---------|---------|
| `standard` | enum | - | EDI standard type (see table below) |
| `conditionalValidationEnabled` | boolean | - | Enable conditional validation rules |
| `description` | string | - | Profile description |
| `modelVersion` | int | 1 | Internal model version |
| `disableEscape` | boolean | false | Disable escape character handling |

### EdiStandard Values

| Value | Description |
|-------|-------------|
| `x12` | Primary US EDI standard |
| `edifact` | UN international standard |
| `hl7` | Healthcare interoperability standard |
| `odette` | European automotive (EDIFACT-based) |
| `tradacoms` | UK retail sector standard |
| `userdef` | Custom/proprietary formats |
| `idoc` | SAP IDoc format |
| `ucs` | Uniform Communication Standard |
| `vics` | Voluntary Interindustry Commerce Solutions |

## When to Use UserDef Standard

Use `standard="userdef"` when:
- Custom/proprietary file formats (e.g., TMW, carrier-specific formats)
- Legacy mainframe formats
- Any format that doesn't follow X12/EDIFACT/HL7/etc. standards
- Fixed-width positional formats with non-standard structure

**Key characteristic**: UserDef profiles provide complete control over record structure without X12/EDIFACT envelope requirements (ISA/GS, UNB/UNG).

**Important**: If you need hierarchical output where child records must appear immediately after their parent records, you MUST use an EDI profile (typically with `standard="userdef"`). Flat file profiles (`profile.flatfile`) cannot express parent-child relationships - they treat all records as independent rows.

## EdiFileOptions

```xml
<EdiFileOptions fileType="delimited" requireFirstSegmentOfLoop="false">
  <EdiDelimitedOptions .../>
  <EdiDataOptions/>
</EdiFileOptions>
```

| Attribute | Type | Default | Purpose |
|-----------|------|---------|---------|
| `fileType` | enum | - | `delimited` or `datapositioned` |
| `requireFirstSegmentOfLoop` | boolean | false | Require first segment presence in loops |

## DataPositioned vs Delimited

### fileType="datapositioned" (Fixed-Width)
- Fields defined by `startColumn` and `length` attributes
- Used when fields have exact column positions
- Common in mainframe/legacy formats
- `padcharacter` fills unused space in output

### fileType="delimited"
- Fields separated by delimiter characters
- Uses `EdiDelimitedOptions` for delimiter configuration
- More flexible for variable-length data
- Standard X12/EDIFACT/HL7 documents use delimited format

## EdiDelimitedOptions

Controls how Boomi parses EDI segment and element boundaries.

```xml
<EdiDelimitedOptions
    fileDelimiter="stardelimited"
    repeatDelimiter="tildedelimited"
    segmentchar="newline"
    compositeDelimiter="colondelimited"
    subCompositeDelimiter="ampersanddelimited"/>
```

### Delimiter Attributes

| Attribute | Purpose | Default |
|-----------|---------|---------|
| `fileDelimiter` | Element separator | - |
| `fileDelimiterSpecial` | Custom character when `othercharacter` | - |
| `segmentchar` | Segment terminator | - |
| `segmentcharSpecial` | Custom character when `othercharacter` | - |
| `compositeDelimiter` | Composite element separator | `colondelimited` |
| `compositeDelimiterSpecial` | Custom character when `othercharacter` | - |
| `subCompositeDelimiter` | Sub-composite separator | `ampersanddelimited` |
| `subCompositeDelimiterSpecial` | Custom character when `othercharacter` | - |
| `repeatDelimiter` | Repeat element separator | - |
| `repeatDelimiterSpecial` | Custom character when `othercharacter` | - |

### EdiDelimiterValue Enum
For `fileDelimiter`, `repeatDelimiter`, `compositeDelimiter`, `subCompositeDelimiter`:

| Value | Character |
|-------|-----------|
| `stardelimited` | * |
| `commadelimited` | , |
| `tabdelimited` | Tab |
| `tickdelimited` | ` |
| `bardelimited` | \| |
| `plusdelimited` | + |
| `colondelimited` | : |
| `caratdelimited` | ^ |
| `ampersanddelimited` | & |
| `tildedelimited` | ~ |
| `bytecharacter` | Custom byte value |
| `othercharacter` | Custom (requires *Special attribute) |

### EdiSegmentChar Enum
For `segmentchar`:

| Value | Character |
|-------|-----------|
| `newline` | LF (\n) |
| `singlequote` | ' |
| `tilde` | ~ |
| `carriagereturn` | CR (\r) |
| `bytecharacter` | Custom byte value |
| `othercharacter` | Custom (requires segmentcharSpecial) |

### EdiDataOptions

```xml
<EdiDataOptions padcharacter=" "/>
```

| Attribute | Purpose |
|-----------|---------|
| `padcharacter` | Padding character for data positioned files |

## Standard-Specific Options

The `EdiOptions` element contains one child element based on the selected standard.

### EdiX12Options

```xml
<EdiX12Options isacontrolstandard="U" isacontrolversion="00401" stdversion="4010" tranfuncid="QM" transmission="214"/>
```

| Attribute | Type | Purpose |
|-----------|------|---------|
| `stdversion` | string | Standard version (e.g., "4010", "5010") |
| `transmission` | string | Transaction set ID (e.g., "214", "850") |
| `tranfuncid` | string | Functional group ID (e.g., "QM", "PO") |
| `isacontrolversion` | string | ISA control version (e.g., "00401") |
| `isacontrolstandard` | string | ISA control standard (e.g., "U") |
| `useloop` | boolean | Enable loop processing |
| `ignoreseg` | boolean | Ignore unknown segments |
| `ignoreelem` | boolean | Ignore unknown elements |

### EdiEdifactOptions

```xml
<EdiEdifactOptions messageType="INVOIC" version="D" release="96A" controlAgency="UN"/>
```

| Attribute | Type | Purpose |
|-----------|------|---------|
| `messageType` | string | EDIFACT message type |
| `version` | string | Version number |
| `release` | string | Release number |
| `controlAgency` | string | Controlling agency |

### EdiHL7Options

```xml
<EdiHL7Options messageType="ADT" version="2.5" messageCode="A01" eventType="A01" messageStructure="ADT_A01"/>
```

| Attribute | Type | Purpose |
|-----------|------|---------|
| `messageType` | string | HL7 message type |
| `version` | string | Version number |
| `messageCode` | string | Message code |
| `eventType` | string | Trigger event |
| `messageStructure` | string | Message structure ID |
| `description` | string | Description |

### EdiOdetteOptions

```xml
<EdiOdetteOptions messageType="DELFOR" version="D" release="96A" controlAgency="ODETTE"/>
```

| Attribute | Type | Purpose |
|-----------|------|---------|
| `messageType` | string | ODETTE message type |
| `version` | string | Version |
| `release` | string | Release |
| `controlAgency` | string | Agency |
| `assocAssignedCode` | string | Association assigned code |
| `odetteType` | string | ODETTE type identifier |

### EdiTradacomsOptions

```xml
<EdiTradacomsOptions messageType="ORDERS" version="9"/>
```

| Attribute | Type | Purpose |
|-----------|------|---------|
| `messageType` | string | Message type |
| `version` | string | Version |
| `description` | string | Description |

### EdiIDOCOptions

```xml
<EdiIDOCOptions idoctype="ORDERS05" messagetype="ORDERS" basictype="ORDERS05"/>
```

| Attribute | Type | Purpose |
|-----------|------|---------|
| `idoctype` | string | IDoc type |
| `messagetype` | string | Message type |
| `basictype` | string | Basic type |
| `extension` | string | Extension |

### EdiUserDefOptions
Empty element - no attributes. Used for custom/proprietary formats.

```xml
<EdiUserDefOptions/>
```

## Element Hierarchy

| Element | Purpose | Typical Count |
|---------|---------|---------------|
| `EdiLoop` | Hierarchical container for segments | 10-20 per profile |
| `EdiSegment` | EDI segment definition (ST, B10, L11, etc.) | 50+ per profile |
| `EdiDataElement` | Individual data element within segment | 200+ per profile |

## EdiLoop Attributes

```xml
<!-- X12 profiles use three root containers — all other nodes start at key=4 -->
<EdiLoop key="1" name="Header" loopId="1" loopRepeat="1" loopingOption="unique" isContainer="true" isNode="true">
  <!-- Header-level segments and loops (ST, BEG, REF, N1, etc.) -->
</EdiLoop>
<EdiLoop key="2" name="Detail" loopId="2" loopRepeat="-1" loopingOption="unique" isContainer="true" isNode="true">
  <!-- Line-item loops and segments (PO1 loop, etc.) -->
</EdiLoop>
<EdiLoop key="3" name="Summary" loopId="3" loopRepeat="1" loopingOption="unique" isContainer="true" isNode="true">
  <!-- CTT, SE segments -->
</EdiLoop>
```

| Attribute | Type | Default | Purpose |
|-----------|------|---------|---------|
| `key` | int | - | Unique identifier (sequential) |
| `name` | string | - | Loop display name |
| `loopId` | string | - | Loop identifier code |
| `loopRepeat` | int | 1 | Maximum repetitions (-1 = unlimited) |
| `loopingOption` | enum | "unique" | `unique` or `occurrence` only |
| `isContainer` | boolean | false | Container flag |
| `isNode` | boolean | true | Node flag |
| `isMappable` | boolean | false | Mappable in transforms |
| `externId` | string | - | External identifier |

**X12 section containers**: `isContainer="true"` marks the three root-level section loops (Header/Detail/Summary). These always use keys 1/2/3 with matching `loopId` values. Detail has `loopRepeat="-1"` (unlimited); Header and Summary have `loopRepeat="1"`. All inner content — loops, segments, elements — uses sequential keys starting at 4.

### LoopingOption Values

| Value | Purpose |
|-------|---------|
| `unique` | Standard loop - one instance |
| `occurrence` | Loop can repeat multiple times |

**Warning**: Only `unique` or `occurrence` are valid values. Using `loopingOption="implicit"` or other values will cause validation errors:
```
cvc-enumeration-valid: Value 'implicit' is not facet-valid with respect to
enumeration '[unique, occurrence]'.
```

## Hierarchical Nesting for Parent-Child Output

**Key Insight**: Flat file profiles produce records as independent rows. EDI profiles with nested EdiLoop structures can produce hierarchical output where child records appear immediately after their parent.

**Always nest child segments inside their parent loop.** Placing related segments as sibling loops (e.g., N9_Loop and MTX_Loop as peers) causes lock-step positional iteration. When iteration counts are uneven — such as an N9 with no MTX followed by an N9 with MTX — the sibling structure silently assigns child data to the wrong parent. Nesting MTX inside the N9 loop eliminates this: each MTX is bound to its enclosing N9 instance regardless of count mismatches.

To make child records appear immediately after their parent record, nest the child loop INSIDE the parent loop:

```xml
<!-- Parent Loop -->
<EdiLoop key="100" loopId="2" loopRepeat="1" loopingOption="unique" name="Shipment"
         isContainer="true" isNode="true">
  <!-- Parent Segment -->
  <EdiSegment key="110" name="139" segmentName="139" loopingOption="unique" isNode="true">
    <!-- Parent fields -->
  </EdiSegment>

  <!-- Child Loop (NESTED INSIDE parent loop) -->
  <EdiLoop key="120" loopId="21" loopRepeat="-1" loopingOption="occurrence" name="ShipmentRefs"
           isContainer="true" isNode="true">
    <EdiSegment key="121" name="439" segmentName="439" loopingOption="occurrence" isNode="true">
      <!-- Child fields -->
    </EdiSegment>
  </EdiLoop>
</EdiLoop>
```

**Result**: Each 439 child record appears immediately after its parent 139 record in the output.

This pattern is essential for formats like TMW where reference records (439) must contextually belong to their parent header (139) or location (239) records.

### HL Loop Pattern (856 ASN and similar)

Transactions using HL segments (856, 835, etc.) require nested HL loops with `autoGenOption` and `useAdditionalCriteria` to discriminate levels. Example 856 S/O/P/I structure:

```xml
<EdiLoop isContainer="true" isNode="true" key="2" loopId="2" loopRepeat="-1" name="Detail">
  <EdiLoop isNode="true" key="16" loopId="S" loopRepeat="200000" name="HL_S">
    <EdiSegment isNode="true" key="17" name="HL" segmentName="Hierarchical Level"
                mandatory="true" maxUse="1" position="010"
                useAdditionalCriteria="true" additionalElementKey="20"
                additionalElementName="HL03" additionalElementValue="S">
      <EdiDataElement key="18" name="HL01" autoGenOption="hierarc1" mandatory="true" dataType="AN" maxLength="12" minLength="1"/>
      <EdiDataElement key="19" name="HL02" autoGenOption="hierarc2" mandatory="false" dataType="AN" maxLength="12" minLength="1"/>
      <EdiDataElement key="20" name="HL03" mandatory="true" dataType="ID" maxLength="2" minLength="1"/>
      <EdiDataElement key="21" name="HL04" mandatory="false" dataType="ID" maxLength="1" minLength="1"/>
    </EdiSegment>
    <!-- Shipment-level segments (TD1, TD5, REF, DTM, N1 loop, etc.) -->

    <EdiLoop isNode="true" key="115" loopId="O" loopRepeat="200000" name="HL_O">
      <EdiSegment isNode="true" key="234" name="HL" segmentName="Hierarchical Level"
                  mandatory="true" maxUse="1" position="010"
                  useAdditionalCriteria="true" additionalElementKey="237"
                  additionalElementName="HL03" additionalElementValue="O">
        <EdiDataElement key="235" name="HL01" autoGenOption="hierarc1" mandatory="true" dataType="AN" maxLength="12" minLength="1"/>
        <EdiDataElement key="236" name="HL02" autoGenOption="hierarc2" mandatory="true" dataType="AN" maxLength="12" minLength="1"/>
        <EdiDataElement key="237" name="HL03" mandatory="true" dataType="ID" maxLength="2" minLength="1"/>
        <EdiDataElement key="238" name="HL04" mandatory="false" dataType="ID" maxLength="1" minLength="1"/>
      </EdiSegment>
      <!-- Order-level segments (PRF, REF, TD1, etc.) -->

      <EdiLoop isNode="true" key="142" loopId="P" loopRepeat="200000" name="HL_P">
        <!-- HL segment with additionalElementValue="P", HL01 hierarc1, HL02 hierarc2 -->
        <!-- Pack-level segments (MAN, etc.) -->

        <EdiLoop isNode="true" key="257" loopId="I" loopRepeat="200000" name="HL_I">
          <!-- HL segment with additionalElementValue="I", HL01 hierarc1, HL02 hierarc2 -->
          <!-- Item-level segments (LIN, SN1, etc.) -->
        </EdiLoop>
      </EdiLoop>
    </EdiLoop>
  </EdiLoop>
</EdiLoop>
```

Key rules:
- Each HL level is a nested `EdiLoop` — child levels inside parent levels
- Every HL segment sets `useAdditionalCriteria="true"` with `additionalElementValue` matching the HL03 level code (S, O, P, I)
- Every HL01 gets `autoGenOption="hierarc1"`, every HL02 gets `autoGenOption="hierarc2"` — do not map these fields
- `loopRepeat="200000"` is typical for HL loops (effectively unlimited)
- The `additionalElementKey` must reference the HL03 element's key within that specific segment

## Loop Boundary Parsing and Segment Ordering

The EDI parser determines loop boundaries from the profile hierarchy. When processing segments inside a repeating loop, if the parser encounters a segment defined at a higher level in the profile, it closes the current loop.

This matters when incoming data has segments physically positioned between iterations of a repeating loop. For example, if the profile defines TD5 at the transaction level (sibling to the N1 loop) but the trading partner sends TD5 between N1\*ST and N1\*BT:

```
N1*ST*Ship To~    ← N1 loop iteration 1
N3*Address~
N4*City*ST*Zip~
TD5*O*93*67~      ← transaction-level segment; parser closes N1 loop here
N1*BT*Bill To~    ← N1 loop iteration 2 — now unreachable
N3*Address~
N4*City*ST*Zip~
```

The second N1 iteration (BT) becomes orphaned. TagList consolidation cannot bridge across the interruption, causing silent data loss or unexpected document splitting in maps. This occurs regardless of whether the interrupting segment is mapped.

When building profiles for real trading partner data, verify that the physical segment ordering in sample data is compatible with your profile hierarchy. If a trading partner sends segments between loop iterations, the profile structure may need to accommodate that ordering rather than following the theoretical X12 standard layout.

### Repeated Segments and Loops — Instance Identifiers, Not Duplication

When the same segment code appears multiple times within the same loop level, model it as a single segment with `loopRepeat` > 1 and add instance identifiers (`tagLists`) keyed on the qualifying element (typically the 01 element), rather than creating separate segment definitions. For example, if sample data contains `REF*BM*12345~` and `REF*CN*67890~` within the same loop, create one REF segment and add `tagLists` entries for BM and CN — not two separate REF segments.

The same principle applies at the loop level. When an entire loop repeats with different qualifier values (e.g., N1 loop appearing for Ship From and Ship To), define the loop once with instance identifiers keyed on the qualifying element of the lead segment (e.g., N101). All child segments (N2, N3, N4) remain nested within that single loop definition.

## EdiSegment Attributes

```xml
<EdiSegment key="10" name="ST" segmentName="Transaction Set Header"
            position="010" mandatory="true" maxUse="1">
  <!-- EdiDataElement children -->
</EdiSegment>
```

| Attribute | Type | Default | Purpose |
|-----------|------|---------|---------|
| `key` | int | - | Unique identifier |
| `name` | string | - | EDI segment identifier (ST, N1, BEG, etc.) — the parser matches this against segment IDs in the data stream |
| `segmentName` | string | - | Human-readable segment description (e.g., "Transaction Set Header") |
| `position` | string | - | Position in hierarchy |
| `mandatory` | boolean | false | Required segment |
| `repeatAction` | enum | - | Repeat action type |
| `maxUse` | int | -1 | Maximum occurrences (not enforced at runtime; useful as metadata and cultural standard) |
| `loopingOption` | enum | "unique" | `unique` or `occurrence` |
| `useAdditionalCriteria` | boolean | false | Enable qualifier matching |
| `additionalElementKey` | int | -1 | Key of qualifier element |
| `additionalElementName` | string | - | Name of qualifier element |
| `additionalElementValue` | string | - | Expected qualifier value |
| `isNode` | boolean | true | Node flag |
| `isMappable` | boolean | false | Mappable flag |
| `maxRepeatSets` | int | 3 | Max repeat sets |
| `externId` | string | - | External ID |

### RepeatActionOption Values

| Value | Purpose |
|-------|---------|
| `na` | Not applicable |
| `readconcatenate` | Concatenate on read |
| `writerepeat` | Repeat on write |
| `readbreakrepeatedsets` | Break repeated sets on read |
| `writecombinerepeatedsets` | Combine repeated sets on write |

## EdiDataElement Attributes

```xml
<EdiDataElement key="11" name="ST01" dataType="ID" mandatory="true"
                minLength="3" maxLength="3" isMappable="true" isNode="true">
  <DataFormat>
    <ProfileCharacterFormat/>
  </DataFormat>
</EdiDataElement>
```

### Child Element Ordering

EdiDataElement children must appear in this order:

```
EdiDataElement
  └─ DataFormat          (required)
  └─ QualifierList       (optional — standards metadata for qualifying elements)
  └─ AutoGenerateOptionDetail  (optional)
```

### QualifierList

Optional child element that declares valid qualifier values for an element per the EDI standard. Used on elements whose values classify or distinguish repeating structures (e.g., N101 Entity Identifier Code, REF01 Reference Identification Qualifier).

`QualifierList` is standards metadata for profile completeness — it does not control instance routing. Instance routing is controlled exclusively by `tagLists` (see Instance Identifiers and Qualifiers section). When building profiles with instance identifiers, include both: `QualifierList` on the qualifying element for completeness, and `tagLists` at the profile level for functional routing.

```xml
<!-- Element with qualifier values (used with tagLists for instance routing) -->
<EdiDataElement key="53" name="N101" dataType="ID" mandatory="true" maxLength="3">
  <DataFormat><ProfileCharacterFormat/></DataFormat>
  <QualifierList codeList="98">
    <Qualifier description="Buying Party (Purchaser)" qualifierValue="BY"/>
    <Qualifier description="Selling Party" qualifierValue="SE"/>
    <Qualifier description="Ship To" qualifierValue="ST"/>
  </QualifierList>
</EdiDataElement>

<!-- Element with codeList reference only (no specific qualifier values) -->
<EdiDataElement key="8" name="BEG01" dataType="ID" mandatory="true" maxLength="2">
  <DataFormat><ProfileCharacterFormat/></DataFormat>
  <QualifierList codeList="353"/>
</EdiDataElement>
```

| Attribute | Required | Purpose |
|-----------|----------|---------|
| `codeList` | No | EDI standard code list number (e.g., "98" for Entity Identifier Code, "128" for Reference Identification Qualifier). Informational reference to the standard |

**Qualifier child element:**

| Attribute | Required | Purpose |
|-----------|----------|---------|
| `qualifierValue` | Yes | The qualifier value string (e.g., "BY", "SE", "ST") |
| `description` | Yes | Human-readable description (e.g., "Buying Party (Purchaser)") |

`QualifierList` can contain more `Qualifier` entries than are referenced by tagLists — list all valid values per the EDI standard, and define tagLists only for the specific values the integration needs to route.

| Attribute | Type | Default | Purpose |
|-----------|------|---------|---------|
| `key` | int | - | Unique identifier |
| `name` | string | - | Element name (e.g., ST01, N101) |
| `dataType` | enum | - | EDI data type |
| `mandatory` | boolean | false | Required element |
| `validateData` | boolean | false | Enable data validation |
| `disableEscape` | boolean | false | Disable escape handling |
| `writeRule` | enum | - | Write rule type |
| `setRepeatType` | enum | - | Repeat type |
| `startColumn` | int | - | For data positioned (0-based index) |
| `length` | int | - | Field length per the EDI standard spec. Set to the standard's defined length for each element |
| `fillCharacter` | string | - | Padding character |
| `justification` | enum | - | `left` or `right` |
| `minLength` | int | 0 | Minimum length per the EDI standard spec |
| `maxLength` | int | 999 | Maximum length per the EDI standard spec |
| `composite` | enum | - | Composite position |
| `comments` | string | - | Developer notes (multi-line, GUI "Comments" field in Advanced section) |
| `elementPurpose` | string | - | Business purpose description (single-line, GUI "Purpose" field in Advanced section) |
| `isMappable` | boolean | true | Mappable in transforms |
| `autoGenOption` | enum | - | Auto-generate option |
| `isNode` | boolean | true | Node flag |
| `compId` | string | - | Composite ID reference |
| `externId` | string | - | External ID |
| `repeating` | boolean | false | Repeating element |

**Field length behavior**: Unlike XML/Flat File/Database profiles which raise errors on length violations, EDI profiles silently truncate (too long) or pad (too short) data to fit the configured lengths. Set `length`, `minLength`, and `maxLength` to the EDI standard's defined values for each element -- this documents the spec correctly and enables downstream Cleanse step validation if needed (Cleanse step is not currently in scope for this skill).

### WriteRule Values

| Value | Purpose |
|-------|---------|
| `na` | Not applicable |
| `notnull` | Write only if not null |
| `notzero` | Write only if not zero |

### SetRepeatType Values

| Value | Purpose |
|-------|---------|
| `na` | Not applicable |
| `constant` | Constant repeat |
| `repeated` | Dynamic repeat |

### Justification Values

| Value | Purpose |
|-------|---------|
| `left` | Left-justify (pad right) |
| `right` | Right-justify (pad left) |

### AutoGenerateOption Values

| Value | Purpose | Use On |
|-------|---------|--------|
| `na` | No auto-generation | Default for most elements |
| `hierarc1` | Auto-generates sequential HL ID (depth-first) | HL01 |
| `hierarc2` | Auto-generates parent HL ID pointer from loop nesting | HL02 |
| `hierarcsum` | Auto-generates count of HL segments | CTT01 |
| `hierarctl1` | Hierarchical control level 1 | - |
| `hierarctl2` | Hierarchical control level 2 | - |
| `hierarctl3` | Hierarchical control level 3 | - |
| `hierarctl4` | Hierarchical control level 4 | - |

**HL auto-numbering behavior:**

- `hierarc1` on HL01: auto-generates sequential HL ID numbers (depth-first traversal order). Do NOT map HL01 — the runtime populates it.
- `hierarc2` on HL02: auto-generates correct parent ID pointers based on loop nesting. Do NOT map HL02 — the runtime populates it. Requires physical nesting inside a parent HL loop.
- `hierarcsum` on CTT01: auto-generates the total count of HL segments. Do NOT map CTT01.
- With `autoGenOption="na"` and no mapped value, HL01/HL02 are empty, causing `MANDATORY_ELEMENT_MISSING` errors.
- Loop nesting controls parent-child interleaving — child HL loops must be nested inside parent HL loops for correct HL02 parent pointers.

## Data Types Reference

### EdiDataType Enum

**IMPORTANT**: The `dataType` attribute is strictly validated. Using invalid values causes HTTP 400 on push. Do NOT use generic type names — use only the values below:

| Type | Description | Common Mistake |
|------|-------------|----------------|
| `AN` | Alphanumeric | Not "string" or "character" |
| `ID` | Identifier | |
| `DT` | Date | Not "date" |
| `TM` | Time | |
| `N0` | Numeric, 0 implied decimals | Not "integer" or "numeric" |
| `N1` | Numeric, 1 implied decimal | |
| `N2` | Numeric, 2 implied decimals | Not "decimal" |
| `N4` | Numeric, 4 implied decimals | |
| `N6` | Numeric, 6 implied decimals | |
| `N` | Numeric | Not "number" |
| `R` | Decimal/Real | Not "decimal" or "float" |
| `B` | Binary | |
| `DTM` | Date/Time | |
| `FT` | Formatted Text | Not "text" |
| `GTS` | General Timestamp | |
| `IS` | Integer String | |
| `NM` | Numeric (HL7) | |
| `SI` | Sequence ID | |
| `SNM` | Signed Numeric | |
| `ST` | String (HL7) | |
| `TX` | Text | |
| `TS` | Timestamp | |
| `TN` | Telephone Number | |

**N-types vs R: implied decimal shifting.** The parser applies decimal shifting at parse time for N-type data types. A wire value of `6237` with `dataType="N2"` produces `62.37`; the same wire value with `dataType="R"` produces `6237`. This is silent — no error, no warning. Using the wrong type on monetary/quantity fields corrupts values by orders of magnitude. Always match the X12 element spec: amount fields are typically N2, not R.

### Data Format Elements

```xml
<DataFormat>
  <ProfileCharacterFormat/>   <!-- For character/string data -->
  <ProfileNumberFormat numberFormat="" impliedDecimal="0" signedField="false"/>
  <ProfileDateFormat dateFormat="yyyyMMdd"/>
  <ProfileBooleanFormat/>
</DataFormat>
```

## Validation Rules

Segments can include validation rules that define conditional field requirements.

### EdiValidationRuleType Enum

| Type | Meaning |
|------|---------|
| `allOrNone` | All specified fields must be present, or none |
| `oneOrMore` | At least one of the specified fields required |
| `oneOrNone` | At most one of the specified fields allowed |
| `oneAndOnlyOne` | Exactly one of the specified fields required |
| `ifFirstAll` | If first field present, all others required |
| `ifFirstAtLeastOne` | If first field present, at least one other required |
| `ifFirstNone` | If first field present, none of others allowed |
| `custom` | Custom validation rule logic |

### Validation Rule XML Structure

```xml
<EdiSegment key="50" name="PER" segmentName="PER">
  <!-- Data elements -->
  <validationRules>
    <validationRule type="ifFirstAll" xsi:type="EdiPredefinedRule">
      <firstInput elementKey="47" name="PER03"/>
      <inputs>
        <input elementKey="48" name="PER04"/>
      </inputs>
    </validationRule>
  </validationRules>
</EdiSegment>
```

## Composites and Sub-Composites

EDI elements may contain composites (sub-elements separated by composite delimiter) and sub-composites (nested within composites).

### CompositeOption Enum

| Value | Purpose |
|-------|---------|
| `na` | Not a composite element |
| `start` | First element in a composite |
| `comp` | Continuation element in composite |
| `startsub` | First element in a sub-composite |
| `startsubstart` | First element in sub-composite that is also first in composite |
| `subcomp` | Continuation element in sub-composite |

### Composite Naming Convention
- Composite: `ElementName.N` (e.g., PV107.1, PV107.2)
- Sub-composite: `ElementName.N.M` (e.g., PV107.2.1, PV107.2.2)

## Instance Identifiers and Qualifiers

Instance identifiers and qualifiers work together to target specific occurrences of repeating loops/segments. Qualifiers are the data values (e.g., "SF", "ST") that distinguish one occurrence from another. Instance identifiers are the named instances defined on a parent element to isolate subsets of data based on those qualifiers.

For example, an EDI 850 may contain multiple N1 loops — one for Ship From (SF) and one for Ship To (ST). Instance identifiers let maps pull from the correct loop based on the qualifier element value.

Supported on EDI, XML, and JSON profiles. Not available for flat file or database profiles.

**Two-tier configuration:** When creating profiles with instance identifiers, configure both:
1. **QualifierList** on the qualifying element (e.g., N101) — declares valid qualifier values for standards completeness (see QualifierList under EdiDataElement Attributes)
2. **tagLists** at the profile level — defines the named instances that control runtime routing in maps

tagLists are the sole functional mechanism for instance routing. QualifierList does not affect runtime behavior but should be included for profile completeness.

### tagLists (Instance Identifiers)

Instance identifiers are defined in a `<tagLists>` block inside the profile, AFTER `<DataElements>`. The `loopingOption` on the instanced loop has no effect when tagLists are present — tagLists fully control instance routing regardless of this setting.

```
EdiProfile element ordering:
  ProfileProperties → DataElements → tagLists
```

#### Structure

```xml
<EdiProfile>
  <ProfileProperties>...</ProfileProperties>
  <DataElements>...</DataElements>
  <tagLists>
    <TagList elementKey="20" listKey="1">
      <GroupingExpression operator="and">
        <TagExpression identifierKey="22" identifierName="N101" identifierType="value">
          <identifierValue>SF</identifierValue>
        </TagExpression>
      </GroupingExpression>
    </TagList>
    <TagList elementKey="20" listKey="2">
      <GroupingExpression operator="and">
        <TagExpression identifierKey="22" identifierName="N101" identifierType="value">
          <identifierValue>ST</identifierValue>
        </TagExpression>
      </GroupingExpression>
    </TagList>
  </tagLists>
</EdiProfile>
```

#### TagList Attributes

| Attribute | Type | Purpose |
|-----------|------|---------|
| `elementKey` | int | Key of the loop this instance identifier applies to |
| `listKey` | int | Unique identifier for this TagList (referenced by maps as `fromTagListKey` / `toTagListKey`) |
| `parentListKey` | int | For nested instances: `listKey` of the parent TagList this child nests within. Default `-1` (no parent) |
| `refListKey` | int | Default `-1` (none). **Never use** — silently suppresses all data for tagged instances in every tested context (sibling and nested loops). Likely vestigial or reserved for unimplemented functionality. Use `parentListKey` for nested scoping instead |

**elementKey must reference a loop, not a segment.** When `elementKey` points to a segment within a loop, the engine treats each qualified segment as a separate repeating unit — producing separate output documents per instance instead of combining them into one document. Worse, sibling segments within the loop (e.g., N3/N4 address data alongside an N1 segment) are excluded from scope entirely, causing silent data loss with no error message. Always use the containing loop's key.

`listKey` values are any integer — positive, negative, or zero. Sequential positive numbering is conventional but not required — gaps (0, 10, 50) and negative values (-1, -2) all work without colliding with sentinel defaults. The profile's `listKey` must exactly match the map's `fromTagListKey`/`toTagListKey`; mismatches silently produce empty data.

The XML ordering of `<TagList>` elements within `<tagLists>` has no effect on runtime behavior. The engine matches by `listKey` and qualifier conditions, not element position.

#### GroupingExpression Attributes

| Attribute | Type | Purpose |
|-----------|------|---------|
| `operator` | enum | Required. `"and"` (all conditions must match) or `"or"` (any condition matches) |

#### TagExpression Attributes

| Attribute | Type | Required | Purpose |
|-----------|------|----------|---------|
| `identifierKey` | int | Yes | For `identifierType="value"`: key of the data element that holds the qualifier value. For `identifierType="occurrence"`: use `-1` (conventional; runtime ignores this value for occurrence expressions) |
| `identifierName` | string | Yes | For value type: name of the qualifier element (e.g., `"N101"`). For occurrence type: `"occurrence"` |
| `identifierType` | enum | No | `"value"` (match by qualifier value) or `"occurrence"` (match by position) |

#### identifierValue

The `<identifierValue>` child element holds the actual qualifier string to match (e.g., "SF", "ST", "BY").

Multiple `<identifierValue>` children in a single TagExpression create a first-match set filter — matches the first occurrence whose value is in the set:

```xml
<TagExpression identifierKey="22" identifierName="N101" identifierType="value">
  <identifierValue>SF</identifierValue>
  <identifierValue>SH</identifierValue>
</TagExpression>
```

This differs from `operator="or"`: multiple identifierValue returns only the first match (1 output document), while OR iterates over all matches (N output documents).

#### Occurrence-Based Matching

When `identifierType="occurrence"`, the `identifierValue` is a 1-based position number instead of a data value — `"1"` for first, `"2"` for second, `"-1"` for last. `"0"` is invalid and causes a silent map failure. Can be used standalone or combined with a value TagExpression:

```xml
<!-- Standalone: select first occurrence of the loop -->
<TagList elementKey="20" listKey="1">
  <GroupingExpression operator="and">
    <TagExpression identifierKey="-1" identifierName="occurrence" identifierType="occurrence">
      <identifierValue>1</identifierValue>
    </TagExpression>
  </GroupingExpression>
</TagList>

<!-- Combined: select last N1 loop where N101="SF" -->
<TagList elementKey="20" listKey="2">
  <GroupingExpression operator="and">
    <TagExpression identifierKey="22" identifierName="N101" identifierType="value">
      <identifierValue>SF</identifierValue>
    </TagExpression>
    <TagExpression identifierKey="-1" identifierName="occurrence" identifierType="occurrence">
      <identifierValue>-1</identifierValue>
    </TagExpression>
  </GroupingExpression>
</TagList>
```

The `identifierKey` attribute is still required for occurrence expressions but is not used for data matching — only position matters. Use when loop order is fixed and guaranteed.

#### Compound Qualifiers

Multiple `<TagExpression>` elements within a single `<GroupingExpression operator="and">` require ALL conditions to match:

```xml
<TagList elementKey="10" listKey="1">
  <GroupingExpression operator="and">
    <TagExpression identifierKey="12" identifierName="Type" identifierType="value">
      <identifierValue>Buyer</identifierValue>
    </TagExpression>
    <TagExpression identifierKey="13" identifierName="SubType" identifierType="value">
      <identifierValue>Primary</identifierValue>
    </TagExpression>
  </GroupingExpression>
</TagList>
```

This matches only when both Type=Buyer AND SubType=Primary. Use `operator="and"` only with TagExpressions that check different elements — when multiple TagExpressions check the same element with AND, the engine silently degrades to OR behavior (matching any value rather than requiring an impossible simultaneous match).

#### OR Matching

`operator="or"` matches when ANY TagExpression is true, grouping multiple qualifier values under a single listKey:

```xml
<TagList elementKey="20" listKey="1">
  <GroupingExpression operator="or">
    <TagExpression identifierKey="22" identifierName="N101" identifierType="value">
      <identifierValue>SF</identifierValue>
    </TagExpression>
    <TagExpression identifierKey="22" identifierName="N101" identifierType="value">
      <identifierValue>SH</identifierValue>
    </TagExpression>
  </GroupingExpression>
</TagList>
```

This matches when N101 is either "SF" or "SH". When multiple loop occurrences match the same listKey, the map iterates over all matches (standard Boomi looping behavior).

#### Nested Instance Identifiers

When loops are nested (e.g., REF segments inside N1 loops), child TagLists use `parentListKey` to scope within a specific parent instance:

```xml
<tagLists>
  <!-- Parent: N1 loop instances -->
  <TagList elementKey="20" listKey="1">  <!-- Buyer -->
    <GroupingExpression operator="and">
      <TagExpression identifierKey="22" identifierName="N101" identifierType="value">
        <identifierValue>BY</identifierValue>
      </TagExpression>
    </GroupingExpression>
  </TagList>
  <!-- Child: REF within Buyer -->
  <TagList elementKey="30" listKey="3" parentListKey="1">
    <GroupingExpression operator="and">
      <TagExpression identifierKey="32" identifierName="REF01" identifierType="value">
        <identifierValue>VR</identifierValue>
      </TagExpression>
    </GroupingExpression>
  </TagList>
</tagLists>
```

`parentListKey="1"` means this child instance (VR REF) only resolves within the Buyer N1 context.

**Critical**: `parentListKey` is required for nested instance resolution. Without it, child instances silently produce no data. With the wrong value, child instances resolve in the wrong parent context.

Maps reference nested instances using the **child's** `listKey` as `fromTagListKey`, with the keyPath including both parent and child tagListKey selectors:

```
*[@key='1']/*[@key='20'][@tagListKey='1']/*[@key='30'][@tagListKey='3']/*[@key='33'][@tagListKey='3']
     ^Header      ^N1(Buyer)               ^REF(VR within Buyer)    ^REF02 field
```

### Segment-Level Qualifier Filter

An alternative to tagLists for simpler scenarios. Place qualifier attributes directly on an `EdiSegment` to filter repeating segments to a single matching occurrence:

```xml
<EdiSegment key="21" name="N1" segmentName="Name"
            useAdditionalCriteria="true"
            additionalElementKey="22"
            additionalElementName="N101"
            additionalElementValue="SF">
```

| Attribute | Purpose |
|-----------|---------|
| `useAdditionalCriteria` | Set `true` to enable qualifier filtering |
| `additionalElementKey` | Key of the element containing the qualifier value |
| `additionalElementName` | Name of that element (e.g., "N101") |
| `additionalElementValue` | The qualifier value to match (e.g., "SF") |

Non-matching loop iterations are excluded from the output entirely — only the matching occurrence appears. No map-level attributes are needed (no `fromTagListKey` or `toTagListKey`).

#### When to Use Which

| Scenario | Use |
|----------|-----|
| Need one specific qualifier from a repeating loop | Segment-level filter |
| Need to route multiple loop instances to different targets | tagLists |

### Runtime Behavior

- When a qualifier match is present in the data, Boomi routes that loop instance's fields to the mapped targets
- When a qualifier match is absent, Boomi outputs an empty element (e.g., `<Ship_From/>`) — no error, no exception
- The process completes successfully regardless of whether all qualifier matches are found
- Qualifiers are case sensitive
- Instances are exclusive — data matching an instance is removed from the original element. Mapping from the original element returns only occurrences that did not match any defined instance
- When both qualifier-based and occurrence-based instances target the same loop, qualifier instances claim matching repetitions first. Occurrence-based instances only count among unclaimed repetitions — `occurrence=1` means "the first unclaimed loop," not "the first loop in the document"
- On write, qualifier elements are auto-populated — the identifying element value is pre-filled automatically when writing to a profile with instance identifiers
- Nested instance identifiers are supported

### Limits
- Maximum 200 instance identifiers per profile
- Nested instance identifiers count toward the limit

### Use Cases
- Mapping specific N1 loop occurrences (Ship From vs Ship To)
- Decision step lookups against specific qualifier values
- Targeted data extraction in maps

## Key Numbering Strategy

The `key` attribute must be unique across the entire profile. For X12 profiles, keys 1, 2, 3 are reserved for the Header/Detail/Summary section containers. All other nodes (inner loops, segments, elements) use sequential integers starting at 4.

Custom banding (e.g. grouping a loop and its children in a range like 100-119) is readable but not required — the platform assigns dense sequential keys. Avoid keys below 4 for non-container nodes.

## Required Attributes Checklist

Missing required attributes cause validation failures on push. Ensure each element type includes:

**EdiLoop required attributes:**
- `key`, `loopId`, `loopRepeat`, `loopingOption`, `name`, `isContainer`, `isNode`

**EdiSegment required attributes:**
- `key`, `name`, `segmentName`, `loopingOption`, `isNode`

**EdiDataElement required attributes:**
- `key`, `name`, `dataType`, `length`, `minLength`, `maxLength`, `mandatory`, `isMappable`, `isNode`
- For `datapositioned`: also requires `startColumn`

## Critical: Segment Terminator Mismatch

**Symptom:** Silent data loss - Map executes without errors but output contains only default/unmapped values. No field values are extracted from the EDI source. The map produces structural output with defaults, masking the parsing failure.

**Root Cause:** EDI profile's `segmentchar` attribute doesn't match actual data format.

| Profile Setting | Expects | Won't Parse |
|-----------------|---------|-------------|
| `segmentchar="newline"` | Segments on separate lines | Single-line with `~` terminators |
| `segmentchar="tilde"` | Segments terminated with `~` | Multi-line format |

**Example - What `segmentchar="newline"` expects:**
```
ISA*00*          *00*          *02*USIT           *ZZ*DTFDENT        *260109*1302*U*00401*000163295*0*P*>
GS*QM*USIT*DTFDENT*20260109*1302*163295*X*004010
ST*214*0001
```

**Example - What won't parse with `segmentchar="newline"`:**
```
ISA*00*...*>~GS*QM*USIT*...~ST*214*0001~
```

**Detection:** If output contains record structure but all mapped field values are missing/default, verify segmentchar matches your data format.

**Validated:** Process `59bf6e30-78c7-46fb-a36c-b8fbba012651` with profile `2d3f82b1-7bf5-4274-bf9e-6c042bc9e4cf`. Identical components, only test data format changed. Newline-separated data produced full output; tilde-terminated data produced defaults only. No error was thrown.
