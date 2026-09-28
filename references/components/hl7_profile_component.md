# HL7 v2 Profile Reference

An EDI profile with `standard="hl7"`. Documents only the HL7 divergences — read
`edi_profile_component.md` for shared EDI profile mechanics.

## Contents
- Component Type
- How HL7 Differs from X12/EDIFACT
- EdiHL7Options
- Delimiter Defaults
- Profile Structure: Header Only
- Message Groups
- Segment Position Numbering
- MSH Starts at MSH02
- Version Differences
- Composites: the compId Model
- Expanding a Composite for Field-Level Mapping
- Repeating Fields
- The Write Path
- Escaping
- Attribute Surface
- Data Types and DataFormat
- QualifierList Uses HL7 Table OIDs
- Repeating Segments
- Trap: Double-Declared Repetition

## Component Type

`profile.edi` with `<EdiGeneralInfo standard="hl7"/>`. Generated in the GUI: EDI Profile → HL7
standard → import a message structure, which builds the full segment/element tree from Boomi's
bundled HL7 metadata.

## How HL7 Differs from X12/EDIFACT

| Aspect | X12 / EDIFACT | HL7 v2 |
|---|---|---|
| Section containers | Content spread across Header/Detail/Summary | **All content in Header**; Detail and Summary always empty |
| Repeating structures | Named `EdiLoop` per qualifier group | HL7 message **groups** become loops; repeating segments stay bare |
| Composites | Expanded to `.N` sub-elements with `composite` attribute | **Not expanded** — one element carrying `compId` |
| `position` | Banded strings (`010`, `020`) | Sequential integers counting group markers |
| Element lengths | `length` + `minLength` + `maxLength` | `maxLength` only |

## EdiHL7Options

```xml
<EdiOptions>
  <EdiHL7Options description="ADT/ACK - Admit/visit notification" eventType="A01"
                 messageCode="ADT" messageStructure="ADT_A01" messageType="ADT_A01"
                 version="v251"/>
</EdiOptions>
```

| Attribute | Purpose | Example |
|---|---|---|
| `messageCode` | The 3-character HL7 message code | `ADT`, `ORU`, `ACK` |
| `eventType` | Trigger event. **Empty string** where the message has none (ACK) | `A01`, `R01`, `""` |
| `messageStructure` | HL7 message structure ID | `ADT_A01`, `ORU_R01`, `ACK` |
| `messageType` | Holds the **structure**, not the code — same value as `messageStructure`. Inverting the two is the most common hand-authoring error | `ADT_A01` |
| `version` | `v` + version digits, dots removed | `v23`, `v251`, `v27` |
| `description` | The HL7 standard's own description string | `ADT/ACK - Admit/visit notification` |

| Profile | Version | `messageCode` | `eventType` | `messageStructure` | `messageType` | `version` |
|---|---|---|---|---|---|---|
| ACK | 2.3 | `ACK` | *(empty)* | `ACK` | `ACK` | `v23` |
| ACK | 2.5.1 | `ACK` | *(empty)* | `ACK` | `ACK` | `v251` |
| ACK | 2.7 | `ACK` | *(empty)* | `ACK` | `ACK` | `v27` |
| ADT_A01 | 2.5.1 | `ADT` | `A01` | `ADT_A01` | `ADT_A01` | `v251` |
| ORU_R01 | 2.5.1 | `ORU` | `R01` | `ORU_R01` | `ORU_R01` | `v251` |

`description` is version-specific — ACK is `Standard Acknowlegdement` (Boomi's own typo) in 2.3
and 2.5.1 but `General Acknowledgment` in 2.7. Treat it as a label, not an identifier.

## Delimiter Defaults

```xml
<EdiFileOptions fileType="delimited">
  <EdiDelimitedOptions compositeDelimiter="caratdelimited" fileDelimiter="bardelimited"
                       repeatDelimiter="tildedelimited" segmentchar="carriagereturn"/>
  <EdiDataOptions/>
</EdiFileOptions>
```

| Delimiter | HL7 | Character | X12 |
|---|---|---|---|
| `fileDelimiter` (field) | `bardelimited` | `\|` | `stardelimited` (`*`) |
| `compositeDelimiter` (component) | `caratdelimited` | `^` | same |
| `repeatDelimiter` | `tildedelimited` | `~` | same |
| `segmentchar` | `carriagereturn` | CR (`\r`) | `tilde` or `newline` |

Delimiters do not vary by HL7 version. `subCompositeDelimiter` is **not written** — HL7's `&`
subcomponent delimiter comes from the schema default (`ampersanddelimited`), so a sub-composite
splits on `&` with none declared.

**`segmentchar="carriagereturn"` means CR — not LF, not CRLF.** A terminator mismatch is the
most common cause of silent HL7 parse failure; verify inbound bytes before debugging anything
else. See `edi_profile_component.md` § Critical: Segment Terminator Mismatch.

## Profile Structure: Header Only

```xml
<DataElements>
  <EdiLoop isContainer="true" isNode="true" key="1" loopId="1" loopRepeat="1"
           loopingOption="unique" name="Header">
    <!-- every segment and group in the message lives here -->
  </EdiLoop>
  <EdiLoop isContainer="true" isNode="true" key="2" loopId="2" loopRepeat="-1"
           loopingOption="unique" name="Detail"/>
  <EdiLoop isContainer="true" isNode="true" key="3" loopId="3" loopRepeat="1"
           loopingOption="unique" name="Summary"/>
</DataElements>
```

Detail and Summary are always emitted as empty self-closing loops — HL7 has no ISA/GS envelope
or SE trailer to delimit sections.

## Message Groups

HL7 message groups (`PATIENT_RESULT`, `ORDER_OBSERVATION`, `INSURANCE`, …) become nested
`EdiLoop` elements, nesting as deep as the message structure requires (ORU_R01 generates
`PATIENT_RESULT > PATIENT > VISIT`):

```xml
<EdiLoop isNode="true" key="369" loopId="OBSERVATION" loopRepeat="999"
         loopingOption="unique" name="OBSERVATION">
  <EdiSegment isNode="true" key="370" name="OBX" maxUse="1" position="24"
              mandatory="true" repeatAction="na" segmentName="Observation/Result">…</EdiSegment>
  <EdiSegment isNode="true" key="396" name="NTE" maxUse="-1" position="25"
              mandatory="false" repeatAction="na" segmentName="Notes and Comments">…</EdiSegment>
</EdiLoop>
```

`loopId` and `name` both carry the group name. `loopRepeat="999"` and
`loopingOption="unique"` on every group regardless of the standard's cardinality. No
`isContainer` attribute, unlike the three root containers.

## Segment Position Numbering

`position` is a sequential integer counting **every slot including group begin and end
markers**, so segment numbers appear to skip:

```
 4  ──── PATIENT begins
 5      PID
 6      PD1
 7      NTE
 8      NK1
 9  ──── VISIT begins
10        PV1
11        PV2
12  ──── VISIT ends
13  ──── PATIENT ends
```

Renumbering the whole message when hand-adding a segment is usually unnecessary, but a number
that collides or skips will not match what the platform generates.

## MSH Starts at MSH02

There is no `MSH01` — HL7's MSH-1 *is* the field separator, so it is not modeled. The first
element is `MSH02` (Encoding Characters), which carries `disableEscape="true"`:

```xml
<EdiDataElement dataType="ST" disableEscape="true" elementPurpose="Encoding Characters"
                isMappable="true" isNode="true" key="5" mandatory="false" maxLength="4"
                name="MSH02">
  <DataFormat><ProfileCharacterFormat/></DataFormat>
</EdiDataElement>
```

`MSH02` is the first element in every HL7 version; only the element count grows (see § Version
Differences). Field alignment carries no off-by-one: against `MSH|^~\&|SENDAPP|SENDFAC|…`,
`MSH03` resolves to `SENDAPP`.

**MSH only.** Every other segment's first declared element is the first field after the tag —
`PID01` is `PID-1`.

Keep `MSH02` a simple element. Expanding it as a composite splits the delimiter declaration
itself; the parser returns `^~\&` intact because it must read that field to learn the
delimiters.

## Version Differences

The generated structure is version-specific. Same message type (ACK) across three versions:

| | 2.3 | 2.5.1 | 2.7 |
|---|---|---|---|
| Segments | MSH, MSA, ERR | MSH, **SFT**, MSA, ERR | MSH, SFT, **UAC**, MSA, ERR |
| MSH elements | MSH02–MSH19 | MSH02–MSH21 | MSH02–MSH25 |
| `dataType` values used | `ST`, `ID`, `NM` | + `IS`, `TX` | + `TX`, `DTM` (no `IS`) |
| MSH07 (timestamp) | `ST` + `compId="TS"` | `ST` + `compId="TS"` | `DTM`, no `compId` |
| Delimiters | — identical — | | |

Do not assume a segment exists: SFT appears from 2.5.1, UAC from 2.7. Timestamp handling
changes shape at 2.7 (composite → primitive; see § Data Types and DataFormat). Generate the
profile from the platform importer for the version you need rather than hand-editing one
version's profile into another's.

## Composites: the compId Model

Platform-generated profiles do **not** expand composites. A composite field is one element
carrying `compId` (the HL7 data type name), `dataType="ST"`, and a `maxLength` spanning the
whole composite:

```xml
<EdiDataElement compId="XPN" dataType="ST" elementPurpose="Patient Name" isMappable="true"
                isNode="true" key="45" mandatory="true" maxLength="250" name="PID05">
  <DataFormat><ProfileCharacterFormat/></DataFormat>
</EdiDataElement>
```

- **A map reads the whole raw composite.** `PID05` against `PID|1||…||DOE^JOHN^A^JR^DR||…`
  returns `DOE^JOHN^A^JR^DR`, separators verbatim and un-split.
- **No sub-component paths exist.** As shipped, `PID05` is the deepest node on its path; there
  is no `<Composites>` block and no element carries a `composite` attribute.
- **`compId` is inert** — documentation only. The attribute the parser acts on is `composite`.

`compId` holds the HL7 data type name (`HD`, `TS`, `XPN`, `XAD`, `CX`, `CWE`, `XCN`, `CE`,
`EI`, `PL`, …) and always pairs with `dataType="ST"`.

## Expanding a Composite for Field-Level Mapping

> **Never expand a composite on a field that can repeat** — see § Repeating Fields. Applies to
> `PID-3`, `PID-13`, `NK1-5`, `AL1-3` and every other repeating composite.

Sub-components are unmodeled, not unreachable. The X12 `composite` mechanism works unchanged on
`standard="hl7"`: replace the single element with expanded sub-elements and the parser splits
on `^`.

```xml
<!-- was: one element, compId="XPN", maxLength="250" -->
<EdiDataElement composite="start" dataType="ST" elementPurpose="Patient Name - Family Name"
                isMappable="true" isNode="true" key="45" mandatory="true" maxLength="194"
                name="PID05.1">
  <DataFormat><ProfileCharacterFormat/></DataFormat>
</EdiDataElement>
<EdiDataElement composite="comp" dataType="ST" elementPurpose="Patient Name - Given Name"
                isMappable="true" isNode="true" key="900" maxLength="30" name="PID05.2">
  <DataFormat><ProfileCharacterFormat/></DataFormat>
</EdiDataElement>
```

Against `DOE^JOHN^A^JR^DR` this yields `DOE` and `JOHN`. The first sub-element takes
`composite="start"`, the rest `composite="comp"`. Keep the original element's `key` on the
`start` sub-element so existing mappings survive; give the rest unused keys. `compId` may stay
or go — no runtime difference. The platform preserves hand-authored `composite` attributes and
`.N` names verbatim through push and pull, and does not re-add `compId`.

**Model every sub-component you need.** The parser consumes exactly as many sub-components as
the profile declares and **silently discards the remainder** — the tail is not appended to the
last sub-element, does not overflow into the following element, and logs no warning. Modeling
two of `XPN` against `DOE^JOHN^A^JR^DR` yields `DOE` and `JOHN` and throws `A^JR^DR` away;
modeling five recovers all five. The output is indistinguishable from source data that
genuinely lacked those sub-components. Expand only the fields you map.

### Sub-composites (the `&` level)

When a component is itself a composite data type — `CX.4` is an `HD`, `XAD.1` is a `SAD` — its
parts separate on `&`. Expanding that level uses `startsub` / `subcomp`:

```xml
<EdiDataElement composite="start"    key="43"  name="PID03.1"   dataType="ST" maxLength="15"  isMappable="true" isNode="true"><DataFormat><ProfileCharacterFormat/></DataFormat></EdiDataElement>
<EdiDataElement composite="comp"     key="910" name="PID03.2"   dataType="ST" maxLength="1"   isMappable="true" isNode="true"><DataFormat><ProfileCharacterFormat/></DataFormat></EdiDataElement>
<EdiDataElement composite="comp"     key="911" name="PID03.3"   dataType="ST" maxLength="3"   isMappable="true" isNode="true"><DataFormat><ProfileCharacterFormat/></DataFormat></EdiDataElement>
<EdiDataElement composite="startsub" key="912" name="PID03.4.1" dataType="ST" maxLength="20"  isMappable="true" isNode="true"><DataFormat><ProfileCharacterFormat/></DataFormat></EdiDataElement>
<EdiDataElement composite="subcomp"  key="913" name="PID03.4.2" dataType="ST" maxLength="199" isMappable="true" isNode="true"><DataFormat><ProfileCharacterFormat/></DataFormat></EdiDataElement>
<EdiDataElement composite="subcomp"  key="914" name="PID03.4.3" dataType="ST" maxLength="6"   isMappable="true" isNode="true"><DataFormat><ProfileCharacterFormat/></DataFormat></EdiDataElement>
<EdiDataElement composite="comp"     key="915" name="PID03.5"   dataType="ST" maxLength="5"   isMappable="true" isNode="true"><DataFormat><ProfileCharacterFormat/></DataFormat></EdiDataElement>
```

`PID-3` = `MRN12345^^^HOSP&1.2.3.4&ISO^MR` yields `MRN12345`, then `HOSP`, `1.2.3.4`, `ISO`,
then `MR` — the parser resumes at component level after the sub-composite.

**Splitting depth is opt-in per element.** Leave `PID03.4` as a plain `composite="comp"` and it
returns `HOSP&1.2.3.4&ISO` whole with the `&` characters inert; the following component
resolves correctly either way.

Sub-composites write as well as they read: mapped sub-components join with `&`, and the
preserve-interior / truncate-trailing rule applies at the `&` level as at `^` — a lone mapped
`PID03.4.2` emits `PID|||^^^&1.2.3.4`. No `subCompositeDelimiter` is needed in either
direction.

**Empty components are suppressed on read.** A component empty in the source produces no
element at all, not an empty one.

## Repeating Fields

HL7 fields repeat on `~` (`PID-3`, `PID-13`, `NK1-5`, `AL1-3`). **The parser does not act on
the repeat delimiter, and no `EdiDataElement` attribute makes it addressable.** `PID03` against
`MRN1^^^HOSPA^MR~MRN2^^^HOSPB^MR` returns the whole raw string, `~` included, as one scalar.
That is lossless — the consumer splits it downstream.

`repeating="true"` and `setRepeatType` (valid values `na`, `constant`, `repeated`) are accepted
by the API and persist through a round trip, and neither affects parsing.

### Never expand a composite on a repeating field

The `^` splitter runs across the **entire raw field, repeat delimiter and all**. With `PID-3` =
`MRN1^^^HOSPA^MR~MRN2^^^HOSPB^MR` and `PID03` expanded to five components:

```
whole field split on ^ :  [1] MRN1
                          [2] (empty)
                          [3] (empty)
                          [4] HOSPA
                          [5] MR~MRN2   <-- straddles the repeat boundary
                          [6-9] (empty), (empty), HOSPB, MR
                                        <-- exceed the five modeled, silently discarded
```

Output: `C1=MRN1`, `C4=HOSPA`, `C5=MR~MRN2`. `HOSPB` appears nowhere. No error, one document,
status COMPLETE. It is invisible in the single-repeat case — `MRN1^^^HOSPA^MR` parses
perfectly — so the profile survives development, testing and go-live, then starts deleting data
the first time a patient arrives with two identifiers.

**Rule: if a field can repeat, leave its composite unexpanded** and split it downstream in a
Data Process step, script, or map function. Leaving it unexpanded is the *safe* choice;
expanding it for field-level convenience is what loses data. Element-level addressing does not
reach a repeat instance.

## The Write Path

Inspect generated output as bytes, not through the process log — the log renders CR as a space
and hides segment structure.

- **Expanded composites join with `^`.** `MSH09.1`/`.2`/`.3` = `ADT`/`A01`/`ADT_A01` emits
  `ADT^A01^ADT_A01`.
- **Interior empty positions are preserved, trailing ones truncated.** Mapping only `MSH09.2`
  emits `^A01`. Same at field level: unmapped MSH04–06 emit `||||` so MSH-7 stays in position
  7, while unmapped MSH13–21 produce no trailing `|`. Sparse mapping of an expanded composite
  is therefore positionally safe.
- **Segments are CR-terminated**, including the last. No LF is emitted.
- **Optional unmapped segments are not emitted** as empty shells.

### `mandatory` is enforced on write — but not on read

| Scope | Behavior |
|---|---|
| Element, in a segment the map instantiates | **Enforced hard.** Document fails |
| Element, in a segment nothing is mapped into | Never evaluated |
| **Segment**, at any depth, in or out of a loop | **Never enforced.** Silently omitted |
| Anything, on the **read** path | Never enforced, even with `strict="true"` |

The trigger is the map writing into the segment, not declared cardinality: `mandatory` means
"if you write this segment, fill this field", not "this segment must exist".

A platform-generated profile therefore works as a map destination **exactly as shipped** — no
stripping of `mandatory` needed, even for mandatory segments like `PR1` and `IN1` you never
populate. The same leniency means Boomi emits an ADT_A01 with no `PV1` and reports COMPLETE.
`mandatory` is not a completeness check for outbound messages; that is the map's
responsibility.

An unmapped `mandatory="true"` element in a segment the map *does* write fails the document,
errors the map shape and skips downstream shapes:

```
SEVERE  First document failure: [Output ProfileLocation: Header/MSH/MSH09.1]:
        Invalid Data Element: MANDATORY_ELEMENT_MISSING
```

**The trap:** expanding a composite on an output profile copies `mandatory="true"` onto the
`composite="start"` sub-element, narrowing the constraint from the composite to sub-component 1.
Nothing is visible at design time; an expanded-but-sparsely-populated composite then fails at
execution. Decide `mandatory` per sub-element when expanding an output composite.

### Boomi does not populate MSH-2

Generated output begins `MSH||…` — MSH-2 (Encoding Characters) is empty and Boomi never
auto-fills `^~\&`. Map or default it explicitly, or the message is not HL7-conformant.

## Escaping

HL7 v2 escapes are delimited on both sides (`\S\`, `\F\`, `\T\`, `\R\`, `\E\`). Boomi instead
uses backslash-plus-the-literal-character, and only for two of the four delimiters.

**Write** — source value `A&B|C~D^E` emits `A&B\|C~D\^E`:

| Delimiter | Role | Escaped? | Boomi emits | HL7 requires |
|---|---|---|---|---|
| `^` | component | **yes** | `\^` | `\S\` |
| `\|` | field | **yes** | `\\|` | `\F\` |
| `&` | sub-component | **no** | *(raw)* | `\T\` |
| `~` | repeat | **no** | *(raw)* | `\R\` |

Structural delimiters the writer produces itself are correctly left bare — `ADT^A01^ADT_A01`
from expanded components carries unescaped `^` in the same message. The data/structure
distinction is applied correctly; only the escape syntax is wrong.

**Read** — `\^` (Boomi's own form) decodes; `\S\` does not, arriving as a literal
`SMITH\S\JONES`. Decoding is coupled to composite expansion: an unexpanded field is fully
opaque, with no splitting and no unescaping.

**Boomi round-trips with itself and breaks against conformant partners in both directions.**
Outbound, `\^` and `\|` will not decode at a conformant receiver, and `&` and `~` go out raw
and are read as **structure** — splitting a sub-component or starting a phantom repeat. `&` is
not exotic; it appears in organization names ("Smith & Jones Medical") that land in `MSH-4`,
`PID-3.4`, `IN1-4`. That failure is quiet: structurally valid HL7 meaning something other than
what was mapped. Inbound, `SMITH\S\JONES` is loud and obvious.

- Strip or substitute `&` and `~` in the map before values reach the EDI profile.
- For conformant interop, translate escapes in a Data Process or script step in both
  directions, with `disableEscape="true"` on the elements concerned. `disableEscape` gives raw
  passthrough — it turns Boomi's escaping off, it does not add conformant escaping.
- **Do not concatenate composites in the map** as a substitute for expanding them: the `^` gets
  escaped and the receiver sees one literal value.

## Attribute Surface

| Element | Attributes emitted |
|---|---|
| `EdiLoop` | `isContainer`, `isNode`, `key`, `loopId`, `loopRepeat`, `loopingOption`, `name` |
| `EdiSegment` | `isNode`, `key`, `mandatory`, `maxUse`, `name`, `position`, `repeatAction`, `segmentName` |
| `EdiDataElement` | `compId`, `dataType`, `disableEscape`, `elementPurpose`, `isMappable`, `isNode`, `key`, `mandatory`, `maxLength`, `name` |

- `repeatAction="na"` on every segment, and no `loopingOption` on segments (X12 sets it on
  every one).
- `mandatory` is written only when `true`, the sole exception being `MSH02` (explicitly
  `false`).
- Never present anywhere: `composite`, `startColumn`, `autoGenOption`, `comments`,
  `validateData`, `writeRule`, `setRepeatType`, `repeating`, `justification`, `fillCharacter`,
  `useAdditionalCriteria`.
- `elementPurpose` carries the HL7 field description ("Sending Application"), `segmentName` the
  segment description ("Message Header").

**`compId`, `repeating` and `setRepeatType` are inert** — accepted by the API, preserved
through a round trip, never acted upon at execution. Their presence does not mean a behavior is
being handled. `composite` is the functional attribute for composites; there is no functional
attribute for repeats.

## Data Types and DataFormat

| `dataType` | DataFormat child |
|---|---|
| `ST`, `ID`, `IS`, `TX`, `FT` | `<ProfileCharacterFormat/>` |
| `NM` | `<ProfileNumberFormat numberFormat="#.#" signedField="false"/>` |
| `SI` | `<ProfileNumberFormat impliedDecimal="0" signedField="false"/>` |
| `DT` | `<ProfileDateFormat dateFormat="yyyyMMdd"/>` |
| `TM` | `<ProfileDateFormat dateFormat="HHmm"/>` |
| `DTM` | `<ProfileDateFormat dateFormat="yyyyMMdd HHmmss.SSSSZ"/>` |

The X12 types (`AN`, `N0`–`N6`, `R`, `B`) never appear. Which `dataType` values are in use is
version-dependent — it reflects the HL7 version's own primitives, not a Boomi-wide list (see
§ Version Differences).

**`TS` is not a `dataType`, and in 2.7 it stops existing.** In 2.3 and 2.5.1 a timestamp field
is a composite: `dataType="ST"` with `compId="TS"`, so reaching its parts requires composite
expansion. In 2.7 it is a primitive: `dataType="DTM"`, no `compId`, with a `ProfileDateFormat`.
A map written against one version's timestamp fields will not transfer unchanged.

## QualifierList Uses HL7 Table OIDs

`QualifierList` references the HL7 v2 table by **OID** and carries no `Qualifier` children:

```xml
<EdiDataElement dataType="ID" elementPurpose="Acknowledgment Code" isMappable="true"
                isNode="true" key="33" mandatory="true" maxLength="2" name="MSA01">
  <DataFormat><ProfileCharacterFormat/></DataFormat>
  <QualifierList codeList="2.16.840.1.113883.12.8"/>
</EdiDataElement>
```

The OID's final component is the HL7 table number — `…12.8` is table 0008 (Acknowledgment
Code), `…12.155` is table 0155. X12 profiles instead use bare table numbers (`"98"`, `"353"`).

## Repeating Segments

HL7 repeating segments are emitted **bare** — direct children of the Header container or of a
group loop, with `maxUse="-1"` and no wrapping `EdiLoop`:

```xml
<EdiSegment isNode="true" key="280" mandatory="false" maxUse="-1" name="OBX" position="12"
            repeatAction="na" segmentName="Observation/Result">…</EdiSegment>
```

One segment code may appear as several separate definitions at the same level where the HL7
structure places it at several positions — ADT_A01 generates four distinct `ROL` segments (keys
102, 258, 369, 594). That is expected platform output, not a duplication error.

Platform-generated profiles ship with `<tagLists/>` empty.

**Keying instance identifiers.** A bare repeating segment can be referenced by its own segment
key, and routes correctly only while it has no sibling segments in scope; once a sibling
exists, a segment-keyed `elementKey` splits the output into one document per instance and
silently drops the sibling segment's data. The general rule in `edi_profile_component.md`
§ tagLists applies unchanged: **key `tagLists` on an `EdiLoop`, not on an `EdiSegment`.** For a
group loop that is free — key the group. For a bare repeating segment, wrap it in a named
`EdiLoop`, key the loop, and demote the segment to `maxUse="1"`.

## Trap: Double-Declared Repetition

Wrapping a repeating segment in a loop **without demoting the segment** declares repetition
twice and silently corrupts instance routing:

```xml
<!-- WRONG — repetition declared on both the loop and the segment -->
<EdiLoop key="901" loopId="OBX" loopRepeat="-1" loopingOption="occurrence" name="OBX_Loop">
  <EdiSegment key="280" name="OBX" maxUse="-1" …>…</EdiSegment>
</EdiLoop>

<!-- CORRECT — the loop repeats, the segment does not -->
<EdiLoop key="901" loopId="OBX" loopRepeat="-1" loopingOption="occurrence" name="OBX_Loop">
  <EdiSegment key="280" name="OBX" maxUse="1" loopingOption="unique" …>…</EdiSegment>
</EdiLoop>
```

With two tagList instances defined on the loop, the wrong form emits **2 documents instead of
1**, one instance receiving every occurrence and the other nothing, completing green with no
error. The failure is silent in both directions, so it surfaces only if document counts *and*
per-instance values are both checked.
