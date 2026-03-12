# Trading Partner Steps Reference

## Contents
- Trading Partner Start Shape
- Trading Partner Send Shape
- Shared Configuration Element
- Output Paths (Start Shape)
- Output Paths (Send Shape)
- Path Execution Order
- Inbound Validation and Error Routing by Standard
- Reference XML Examples
- Component Dependencies

## Trading Partner Start Shape

The Trading Partner Start shape is a start step variant for B2B/EDI processes. It uses `shapetype="start"` (same as all other start shapes) with a `<tradingpartneraction actionType="Listen">` configuration element.

```xml
<shape image="start" name="shape1" shapetype="start" userlabel="" x="48.0" y="46.0">
  <configuration>
    <tradingpartneraction actionType="Listen" standard="x12"
                          errorHandlingOption="false" includeArchivePath="false">
      <TradingPartners/>
    </tradingpartneraction>
  </configuration>
  <dragpoints>
    <dragpoint identifier="1" name="shape1.dragpoint1" text="Documents" toShape="shape2" x="274.0" y="56.0"/>
    <dragpoint identifier="2" name="shape1.dragpoint2" text="Acknowledgments" toShape="shape3" x="274.0" y="176.0"/>
  </dragpoints>
</shape>
```

## Trading Partner Send Shape

The Trading Partner Send shape has its own unique shapetype `tradingpartneraction`. It sends documents to trading partners via the configured communication method. It is not a terminal shape — documents flow through it to downstream steps.

An Errors path is always attached to the Send step. If outbound validation is configured in the trading partner component, invalid documents route to the Errors path. An Archive path is attached when the Archiving option is selected.

```xml
<shape image="tradingpartneraction_icon" name="shape2" shapetype="tradingpartneraction"
       userlabel="" x="290.0" y="46.0">
  <configuration>
    <tradingpartneraction actionType="Send" standard="x12" communicationMethod="as2">
      <TradingPartners/>
    </tradingpartneraction>
  </configuration>
  <dragpoints/>
</shape>
```

| Property | Start | Send |
|---|---|---|
| `shapetype` | `start` | `tradingpartneraction` |
| `image` | `start` | `tradingpartneraction_icon` |
| `actionType` | `Listen` | `Send` |
| Outgoing paths | Documents, Acknowledgments, [Errors], [Archive] | Errors, [Archive] |

## Shared Configuration Element

Both shapes use the same `<tradingpartneraction>` element, differentiated by `actionType`.

### Attributes

| Attribute | Type | Default | Purpose |
|---|---|---|---|
| `actionType` | string | — | `Listen` and `Send` are valid values. Platform preserves case as pushed; GUI-created processes use lowercase (`listen`, `send`) |
| `standard` | string | — | EDI standard: `x12`, `edifact`, `hl7`, `odette`, `tradacoms`, `edicustom`, `edimulti` |
| `customStandardId` | string | — | Component ID for `edicustom` standard |
| `communicationMethod` | string | — | Protocol filter: `as2`, `disk`, `ftp`, `sftp`, `http`, `mllp`, `oftp`. Optional — omitted when not set |
| `myTradingPartnerId` | string | — | Component ID of My Company trading partner |
| `useGroupComponent` | boolean | `false` | Use a TP Group component instead of individual partners |
| `tpGroupId` | string | — | Component ID of TP Group (when `useGroupComponent="true"`) |
| `includeArchivePath` | boolean | `false` | Enable Archive output path |
| `errorHandlingOption` | boolean | `false` | Enable Errors output path |

### Child Elements

| Element | Content | Purpose |
|---|---|---|
| `TradingPartners` | 0+ `TradingPartner` references | Partner component references |
| `MyCompanies` | 0+ `MyCompany` references | My Company component references (accepted on both Start and Send) |

`partnerId` values in `TradingPartner` references are validated by the platform — invalid component IDs are rejected with HTTP 400.

#### Populated TradingPartners/MyCompanies Structure

To wire a TP shape to specific partners, populate the child elements with component references:

```xml
<TradingPartners>
  <TradingPartner keyIndex="1" partnerId="{componentId}" standard="x12"/>
</TradingPartners>
<MyCompanies>
  <MyCompany standard="x12">
    <TradingPartner default="true" keyIndex="1" partnerId="{myCompanyComponentId}"/>
  </MyCompany>
</MyCompanies>
```

| Attribute | Element | Purpose |
|---|---|---|
| `keyIndex` | `TradingPartner` | Sequential index (1-based) |
| `partnerId` | `TradingPartner` | Component ID of the trading partner |
| `standard` | `TradingPartner`, `MyCompany` | EDI standard (matches parent config) |
| `default` | `TradingPartner` (within `MyCompany`) | Marks as default for communication settings |

## Output Paths (Start Shape)

The Start shape supports multiple output paths controlled by boolean attributes:

| errorHandlingOption | includeArchivePath | id=1 | id=2 | id=3 | id=4 |
|---|---|---|---|---|---|
| false | false | Documents | Acknowledgments | — | — |
| true | false | Documents | Errors | Acknowledgments | — |
| false | true | Documents | Acknowledgments | Archive | — |
| true | true | Documents | Errors | Acknowledgments | Archive |

Errors inserts at position 2 when enabled. Archive appends at the end. Acknowledgments is always present.

**Dragpoint identifiers:** The platform accepts both numeric (`"1"`, `"2"`, `"3"`, `"4"`) and semantic (`"documents"`, `"acknowledgements"`, `"errors"`, `"archive"`) identifier values. GUI-created processes use semantic identifiers. Both formats are preserved as pushed.

### Start Shape Path Purposes

- **Documents** — valid, processable documents
- **Acknowledgments** — generated acknowledgment messages (997/999 FA for X12, CONTRL for EDIFACT/ODETTE, ACK for HL7). Always present
- **Errors** — invalid documents that failed profile-based validation. Present when `errorHandlingOption="true"`
- **Archive** — raw document data for custom archiving logic. Present when `includeArchivePath="true"`

## Output Paths (Send Shape)

The Send step always needs an Errors path (it is default generated when a user creates the step the GUI). The GUI renders available output paths based on the shapetype and configuration — `<dragpoint>` children only appear in the XML when wired to a target shape. An unwired path is represented by `<dragpoints/>` with no children, which is valid and non-blocking at build time. When building a TP Send, wire the Errors path to a downstream step (typically a Stop step if no error handling logic is needed).

An Archive path is also available when the Archiving option is selected.

- **Errors** — documents that fail outbound validation. If outbound validation is not configured in the trading partner component, wire to a Stop step
- **Archive** — raw document data for custom archiving logic. Present when Archiving option is selected

## Path Execution Order

For the **Start shape** (inbound), paths execute in this order: Documents → Acknowledgments → Errors → Archive.

For the **Send shape** (outbound), paths execute in this order: Errors → Archive.

## Inbound Validation and Error Routing by Standard

The Start shape validates inbound documents against EDI profiles referenced in the trading partner's Document Types configuration. Error routing behavior varies by standard:

| Standard | Invalid Document Routing | Acknowledgment Generation |
|---|---|---|
| X12 | Invalid docs → Errors path. Exception: qualifier-only errors → Documents path with "Accepted with Errors" status | 997 or 999 FA messages, TA1 interchange acks (both configurable per document type) |
| EDIFACT | Errors path only if "Invalid Inbound Document Routing" set to "Errors path" in Document Types tab | CONTRL acknowledgments (configurable) |
| HL7 | Errors path only if "Invalid Inbound Document Routing" set to "Errors path" in Document Types tab | Accept and application acks (configurable per transmission) |
| ODETTE | Errors path only if "Invalid Inbound Document Routing" set to "Errors path" in Document Types tab | CONTRL acknowledgments (configurable) |
| RosettaNet | Invalid docs always → Errors path | Acknowledgments always generated |
| Tradacoms | — | No acknowledgments |

## Reference XML Examples

### TP Start — Full Config (4 Output Paths)

```xml
<shape image="start" name="shape1" shapetype="start" userlabel="" x="48.0" y="46.0">
  <configuration>
    <tradingpartneraction actionType="Listen" communicationMethod="as2"
                          errorHandlingOption="true" includeArchivePath="true"
                          standard="x12" useGroupComponent="false">
      <TradingPartners/>
      <MyCompanies/>
    </tradingpartneraction>
  </configuration>
  <dragpoints>
    <dragpoint identifier="1" name="shape1.dragpoint1" text="Documents" toShape="shape2" x="274.0" y="56.0"/>
    <dragpoint identifier="2" name="shape1.dragpoint2" text="Errors" toShape="shape3" x="274.0" y="176.0"/>
    <dragpoint identifier="3" name="shape1.dragpoint3" text="Acknowledgments" toShape="shape4" x="274.0" y="296.0"/>
    <dragpoint identifier="4" name="shape1.dragpoint4" text="Archive" toShape="shape5" x="274.0" y="416.0"/>
  </dragpoints>
</shape>
```

### TP Start — Minimal Config (2 Output Paths)

```xml
<shape image="start" name="shape1" shapetype="start" userlabel="" x="48.0" y="46.0">
  <configuration>
    <tradingpartneraction actionType="Listen" errorHandlingOption="false"
                          includeArchivePath="false" standard="x12">
      <TradingPartners/>
    </tradingpartneraction>
  </configuration>
  <dragpoints>
    <dragpoint identifier="1" name="shape1.dragpoint1" text="Documents" toShape="shape2" x="274.0" y="56.0"/>
    <dragpoint identifier="2" name="shape1.dragpoint2" text="Acknowledgments" toShape="shape3" x="274.0" y="176.0"/>
  </dragpoints>
</shape>
```

### TP Send

```xml
<shape image="tradingpartneraction_icon" name="shape2" shapetype="tradingpartneraction"
       userlabel="" x="290.0" y="46.0">
  <configuration>
    <tradingpartneraction actionType="Send" communicationMethod="as2" standard="x12">
      <TradingPartners/>
    </tradingpartneraction>
  </configuration>
  <dragpoints/>
</shape>
```

## Component Dependencies

- **Trading Partner component(s)** — referenced by `partnerId` in `TradingPartner` child elements
- **My Company trading partner** — referenced by `myTradingPartnerId` attribute or via `MyCompanies` child element
- **Trading Partner Group** (optional) — referenced by `tpGroupId` when `useGroupComponent="true"`
