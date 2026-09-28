# Trading Partner Steps Reference

## Contents
- Trading Partner Start Shape
- Trading Partner Send Shape
- Shared Configuration Element
- Output Paths (Start Shape)
- Output Paths (Send Shape)
- Inbound Validation and Error Routing by Standard
- Component Dependencies

## Trading Partner Start Shape

The Trading Partner Start shape is a start step variant for B2B/EDI processes. It uses `shapetype="start"` (same as all other start shapes) with a `<tradingpartneraction>` configuration element.

```xml
<shape image="start" name="shape1" shapetype="start" userlabel="" x="48.0" y="48.0">
  <configuration>
    <tradingpartneraction actionType="get" communicationMethod="disk"
                          errorHandlingOption="false" includeArchivePath="false"
                          myTradingPartnerId="{myCompanyComponentId}"
                          standard="x12" useGroupComponent="false">
      <TradingPartners>
        <TradingPartner keyIndex="1" partnerId="{partnerComponentId}" standard="x12"/>
      </TradingPartners>
    </tradingpartneraction>
  </configuration>
  <dragpoints>
    <dragpoint identifier="documents" name="shape1.dragpoint1" text="Documents" toShape="shape2" x="224.0" y="57.0"/>
    <dragpoint identifier="acknowledgements" name="shape1.dragpoint2" text="Acknowledgments" toShape="shape3" x="224.0" y="217.0"/>
    <dragpoint identifier="errors" name="shape1.dragpoint3" text="Errors" toShape="shape4" x="224.0" y="377.0"/>
  </dragpoints>
</shape>
```

`myTradingPartnerId` and at least one partner reference are required on both placements. Omitting `myTradingPartnerId` pushes and deploys, then fails at execution: `Unable to initialize trading partner, trading partner not defined.`

## Trading Partner Send Shape

The Trading Partner Send shape uses `shapetype="tradingpartneraction"` and sends documents via the partner's configured communication method. A successfully sent document does not continue to a downstream step — only the Errors and Archive paths carry documents onward, so treat the Send as the end of its branch, but not as a terminal shape (see Output Paths (Send Shape)).

The Send does not determine a document's type from its content; it reads EDI metadata attached upstream. A document built by a Message step envelopes with a blank transaction set ID (`ST*   *0001`) and blank functional group code, with no error raised.

`shape2` below is the target of the Start example's Documents path:

```xml
<shape image="tradingpartneraction_icon" name="shape2" shapetype="tradingpartneraction"
       userlabel="" x="240.0" y="48.0">
  <configuration>
    <tradingpartneraction actionType="get" communicationMethod="disk"
                          includeArchivePath="false"
                          myTradingPartnerId="{myCompanyComponentId}"
                          standard="x12" useGroupComponent="false">
      <TradingPartners>
        <TradingPartner keyIndex="1" partnerId="{partnerComponentId}" standard="x12"/>
      </TradingPartners>
    </tradingpartneraction>
  </configuration>
  <dragpoints>
    <dragpoint identifier="errors" name="shape2.dragpoint1" text="Errors" toShape="shape5" x="416.0" y="57.0"/>
  </dragpoints>
</shape>
```

| Property | Start | Send |
|---|---|---|
| `shapetype` | `start` | `tradingpartneraction` |
| `image` | `start` | `tradingpartneraction_icon` |
| `actionType` | `get` | `get` |
| `errorHandlingOption` | `false` (emitted by the GUI) | omitted |
| Outgoing paths | Documents, Acknowledgments, Errors, [Archive] | Errors, [Archive] |

## Shared Configuration Element

Both shapes use the same `<tradingpartneraction>` element. Receive vs send is determined by the enclosing shape's `shapetype`, not by any attribute of the element itself.

### Attributes

| Attribute | Type | Default | Purpose |
|---|---|---|---|
| `actionType` | string | — | `get` in both placements — not `Listen`/`Send`. Not validated: a wrong value deploys, and the Start shape then completes reporting `0 document(s) found for processing` with input left unread |
| `standard` | string | — | EDI standard: `x12`, `edifact`, `hl7`, `odette`, `tradacoms`, `edicustom`, `edimulti` |
| `customStandardId` | string | — | Component ID for `edicustom` standard |
| `communicationMethod` | string | — | `as2`, `disk`, `ftp`, `sftp`, `http`, `mllp`, `oftp`. Optional. Filters the partner picklist only — no effect on transport selection |
| `connectorType` | string | — | Selects the communication implementation the runtime loads partner settings for. Optional; when omitted, transport comes from the partner component's configured method. When present it must match that method — a mismatch deploys, then fails at execution with `Unable to load settings from XML` |
| `myTradingPartnerId` | string | — | Component ID of My Company trading partner. Required |
| `useGroupComponent` | boolean | `false` | Use a TP Group component instead of individual partners |
| `tpGroupId` | string | — | Component ID of TP Group (when `useGroupComponent="true"`) |
| `includeArchivePath` | boolean | `false` | Populates the Archive output path. Archive data requires this **and** a wired `archive` dragpoint; either alone is inert |
| `errorHandlingOption` | boolean | `false` | No observable effect in either placement — it neither adds nor removes output paths nor controls stop-vs-continue on error. The GUI emits `false` on the Start shape; match that |

### Child Elements

| Element | Content | Purpose |
|---|---|---|
| `TradingPartners` | 1+ `TradingPartner` references | Partner component references |
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

Output paths, in GUI order:

| `identifier` | `text` | Available |
|---|---|---|
| `documents` | Documents | Always |
| `acknowledgements` | Acknowledgments | Always |
| `errors` | Errors | Always |
| `archive` | Archive | When `includeArchivePath="true"` |

Routing resolves by `identifier`, not position — neither the presence of all dragpoints nor their order is enforced. Emit them in the order above to match GUI output. Note `acknowledgements` (British spelling) in `identifier` against `Acknowledgments` in `text`.

**An `identifier` outside those four values makes the dragpoint inert.** Do not carry the Branch shape's numeric `identifier="1"` convention over to a TP Start. A numeric identifier is accepted at push, deploys, survives a pull verbatim, and is not repaired by a GUI save — then routes nothing. The document is discarded at COMPLETE status with zero SEVERE and zero WARNING, while `toShape` and `text="Documents"` sit intact in the stored XML.

In the log the only signal is an absence. A wired path carrying no documents logs `No documents found. Skipping execution for the <label> step.`; a dragpoint whose `identifier` is unrecognized logs nothing at all. A target step appearing in neither its own log lines nor a skip line is not an empty path — it is not connected to one.

Wire every path (see error reference Issue #43). The `errors` dragpoint is mandatory on every TP Start, even when no rejections are expected — a Stop is the minimum target.

### Start Shape Path Purposes

- **Documents** — processable documents, including those that validated with errors
- **Acknowledgments** — generated acknowledgments (997/999 FA for X12, CONTRL for EDIFACT/ODETTE, ACK for HL7)
- **Errors** — documents rejected in profile-based validation. A document that validates *with* errors goes down Documents instead — see X12 Inbound Failure Classes
- **Archive** — the complete raw interchange including the ISA/GS…GE/IEA envelope (Documents carries the envelope-stripped transaction set)

## Output Paths (Send Shape)

The GUI attaches an Errors path by default; Archive is available when the Archiving option is selected. The `errors` dragpoint is mandatory on every TP Send — wire it even when no outbound validation is configured, with a Stop as the minimum target (see error reference Issue #43).

- **Errors** — an outbound-**validation** outlet, not a transport-failure outlet. Only documents a *rejecting*-class validation rule refuses arrive here; a document that validates *with* errors is sent normally
- **Archive** — raw document data for custom archiving logic

**In a Map-fed outbound process the Errors path is usually inert.** A Map writing to an EDI profile validates on write — presence, length, data type, date format — and rejects a bad document before the Send ever sees it. What survives the Map (code-list membership, cross-segment counts such as `CTT01`) the Send does not treat as rejecting, and sends. Validation also needs resolved EDI metadata to run at all, so it never fires on a document whose transaction set ID is blank. Wire the path anyway.

**Exception: EDI profile validation rules.** Maps ignore them, so a violating document reaches the Send. For X12, with the profile's `conditionalValidationEnabled="true"` and the document type's `outboundTSValidation="true"`, the Send treats the violation as rejecting: the document goes to Errors, is not sent, and the execution still reports COMPLETE.

## Inbound Validation and Error Routing by Standard

The Start shape validates inbound documents against EDI profiles referenced in the trading partner's Document Types configuration. Error routing behavior varies by standard:

| Standard | Invalid Document Routing | Acknowledgment Generation |
|---|---|---|
| X12 | Routes by failure class — see X12 Inbound Failure Classes below | 997 or 999 FA messages, TA1 interchange acks (both configurable per document type) |
| EDIFACT | Errors path only if "Invalid Inbound Document Routing" set to "Errors path" in Document Types tab | CONTRL acknowledgments (configurable) |
| HL7 | Errors path only if "Invalid Inbound Document Routing" set to "Errors path" in Document Types tab | Accept and application acks (configurable per transmission) |
| ODETTE | Errors path only if "Invalid Inbound Document Routing" set to "Errors path" in Document Types tab | CONTRL acknowledgments (configurable) |
| RosettaNet | Invalid docs always → Errors path | Acknowledgments always generated |
| Tradacoms | — | No acknowledgments |

### X12 Inbound Failure Classes

For X12, which path an invalid inbound document takes — and whether the execution errors — depends on how it fails, not on any Start shape attribute:

| Failure | Routed to | Acknowledgment | Execution status |
|---|---|---|---|
| Fails to parse (e.g. malformed date in a mandatory element) | No path — never becomes a routable document | None for that document | **ERROR**, reported at cleanup as `encountered N document error(s)` with a `First document failure:` detail |
| Parses, validates with errors (e.g. empty mandatory element, qualifier-only error, profile validation-rule violation) | Documents | 997 with `AK5*E` (accepted with errors) | COMPLETE |
| Rejected (e.g. `SE01` segment-count mismatch) | Errors | 997 with `AK5*R` (rejected) | COMPLETE |

A parse failure does not stop other documents in the same execution — valid documents still complete down the Documents path even though the execution reports ERROR.

## Component Dependencies

- **Trading Partner component(s)** — referenced by `partnerId` in `TradingPartner` child elements
- **My Company trading partner** — referenced by the required `myTradingPartnerId` attribute
- **Trading Partner Group** (optional) — referenced by `tpGroupId` when `useGroupComponent="true"`
