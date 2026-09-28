# B2B/EDI Platform Reference

## Contents
- Overview
- Architecture
- Supported EDI Standards
- Trading Partner Components
- Trading Partner Start/Send Shapes
- Acknowledgment Flows
- Document Processing Paths
- Instance Identifiers
- Validation Architecture
- B2B Communication Connectors
- EDIFACT and X12 Envelope Layers
- EDIFACT Connector Record API Fields

## Overview

Boomi's B2B/EDI is a unified platform combining EDI document processing with modern integration capabilities. A single process can serve multiple trading partners with different document standards.

Key differentiators from traditional EDI:
- Single platform model eliminates need for separate EDI and integration systems
- Host + multiple partner configuration model
- Multi-standard flexibility within single processes
- Instance identifiers for disambiguating repeating segments
- Built-in validation with automatic acknowledgment generation

## Architecture

```
B2B/EDI Architecture:
├── Trading Partner Components
│   ├── My Company (Host partner - one required)
│   └── Trading Partners (Remote partners - multiple)
├── EDI Profiles (Document structure definition)
│   └── See: components/edi_profile_component.md
├── Process Integration
│   ├── Trading Partner Start (receives/validates documents)
│   │   ├── Documents path (accepted documents)
│   │   ├── Acknowledgments path (generated acks)
│   │   ├── Errors path (rejected documents)
│   │   └── Archive path (custom archiving)
│   └── Trading Partner Send (generates envelopes/acknowledgments, then transmits)
└── Communication Connectors (Transport layer)
    ├── AS2 (with MDN receipts)
    ├── MLLP (healthcare)
    ├── OFTP2 (ODETTE automotive)
    ├── FTP/SFTP
    ├── HTTP
    └── Disk
```

## Supported EDI Standards

| Standard | Region/Industry | Typical Use Cases |
|----------|-----------------|-------------------|
| X12 | North America | Purchase orders (850), invoices (810), shipment notices (856), status (214) |
| EDIFACT | International | Cross-border trade (ORDERS, INVOIC, DESADV), UN-developed syntax. Envelope: UNB/UNZ (interchange) > optional UNG/UNE (group) > UNH/UNT (message) |
| HL7 | Healthcare | Clinical data exchange, ADT messages |
| ODETTE | European Automotive | EDIFACT-based, automotive supply chain |
| Tradacoms | UK Retail | UK retail sector |
| User-Defined | Custom | Proprietary formats not covered by standards |

Standards map to EDI profile `standard` attribute values: `x12`, `edifact`, `hl7`, `odette`, `tradacoms`, `userdef`.

## Trading Partner Components

Trading Partner components define the configuration for EDI document exchange with business partners.

### Partner Types

| Type | Description | Per Account |
|------|-------------|-------------|
| My Company (Host) | Your organization's EDI settings | One required |
| Trading Partner | External partners you exchange documents with | Multiple allowed |

### Key Characteristics
- Partner type cannot be changed after creation
- Document standard cannot be changed after creation
- Each partner requires configuration of:
  - Document standard (X12, EDIFACT, HL7, etc.)
  - Communication method
  - Document types to exchange
  - Acknowledgment options

### Communication Methods

| Method | Protocol | Use Case |
|--------|----------|----------|
| AS2 | Applicability Statement 2 | Secure B2B with MDN receipts |
| MLLP | Minimum Lower Layer Protocol | Healthcare (HL7) |
| OFTP2 | Odette File Transfer Protocol 2 | European automotive |
| FTP | File Transfer Protocol | File-based exchange |
| SFTP | SSH File Transfer Protocol | Secure file exchange |
| HTTP | Web-based | REST/web service integration |
| Disk | Local/network file system | Directory-based exchange |

## Trading Partner Start/Send Shapes

These process shapes handle EDI document processing within Boomi processes.

### Trading Partner Start
Receives and validates inbound EDI documents.

**Output Paths:**
| Path | Purpose |
|------|---------|
| Documents | Accepted documents, including those that validated with errors |
| Acknowledgments | Generated acknowledgment documents |
| Errors | Rejected documents — routing varies by failure class and standard |
| Archive | For custom archiving logic |

### Trading Partner Send
Generates EDI envelopes and acknowledgments for outbound documents and sends them via the partner's configured communication method. Successfully sent documents end their branch here.

Both shapes require a wired Errors path — see `steps/trading_partner_steps.md`.

## Acknowledgment Flows

Boomi automatically generates acknowledgments based on trading partner configuration.

| Standard | Acknowledgment Types | Purpose |
|----------|---------------------|---------|
| X12 | 997 (Functional Acknowledgment) | Default acknowledgment for transaction sets |
| X12 | 999 (Implementation Acknowledgment) | Healthcare (5010+), more detailed errors |
| X12 | TA1 (Interchange Acknowledgment) | ISA/IEA level validation |
| EDIFACT | CONTRL | Single acknowledgment type covering syntax and service reporting. Two options: Do Not Acknowledge (`donotackitem`) or Acknowledge (`ackitem`). No granularity equivalent to X12's group-vs-transaction choice |
| HL7 | ACK | Accept/Application acknowledgments |
| Tradacoms | None | No acknowledgment mechanism |
| RosettaNet | Always generated | Standard requires acknowledgments |

### X12 Acknowledgment Options
- Do Not Acknowledge
- Acknowledge Functional Groups (997 at group level)
- Acknowledge Transaction Sets (997/999 at transaction level)

### Filter Options
- Filter Functional Acknowledgements: Prevent 997/TA1 from passing to process
- Reject Duplicate ISA: Reject documents with duplicate ISA control numbers

### Transaction Pair Dependencies

When scaffolding a process around a received transaction, plan routes for the expected responses:

| Trigger | Expected Responses |
|---|---|
| 850 (PO) | 997/999 ack → 855 (acknowledgment) → 856 (ASN) → 810 (invoice) |
| 830 (planning schedule) | 862 (shipping schedule) → 856 → 810 |
| 837 (health-care claim) | 999 (implementation ack) → 277CA (claim receipt) → 835 (remittance). 277CA and 835 return as separate inbound interchanges from the payer and require receive-side TP configuration. |
| 270 (eligibility inquiry) | 271 (eligibility response) |
| 276 (claim status inquiry) | 277 (claim status response) |
| 834 (benefit enrollment) | 999 (implementation ack) |
| EDIFACT ORDERS | CONTRL (syntax ack) → ORDRSP → DESADV → INVOIC |

## Document Processing Paths

### Inbound Processing
1. Document received via communication connector
2. Trading Partner Start parses and validates against EDI profile
3. Parsed documents route to Documents or Errors; the split is standard-specific
4. X12 documents that fail to parse reach no path and error the execution
5. Acknowledgments generated and route to Acknowledgments path
6. Optional custom archiving via Archive path

Failure-class routing and per-standard differences: `steps/trading_partner_steps.md`.

### Outbound Processing
1. Documents mapped/transformed in process
2. Trading Partner Send generates EDI envelopes
3. Control numbers auto-generated (ISA, GS, ST for X12)
4. Documents sent via configured communication method

### Envelope Grouping Options
- Group By Interchange: All documents in single interchange
- Group By Functional Group: Grouped by functional group
- Group By Transaction Set: Each transaction in own group

## Instance Identifiers

Instance identifiers enable targeting specific occurrences of repeating loops/segments.

### Concept
In EDI, the same segment can repeat with different qualifier values. For example, an N1 loop might contain:
- Ship From (SF qualifier)
- Ship To (ST qualifier)

Instance identifiers allow mapping to specific occurrences.

### Example: N1 Loop with Qualifiers
```
N1*SF*BOOMI HQ~           <- Ship From
N3*801 CASSATT ROAD~
N4*BERWYN*PA*19132~
N1*ST*FOOD STORES~        <- Ship To
N3*123 SOUTH STREET~
N4*CHICAGO*IL*84593~
```

### Configuration
- Add qualifiers to the identifying element (N101)
- Add instance identifiers at loop level for each qualifier
- Reference specific instance in Decision steps and Maps

### Limits
- Maximum 200 instance identifiers per profile
- Nested instance identifiers count toward limit

## Validation Architecture

### Inbound Validation
Trading Partner Start validates documents against:
- Mandatory fields
- Data types
- Min/max lengths
- Segment validation rules
- Qualifier validation (enabled by default, can be disabled)

### Outbound Validation
Optional validation before transmission:

| Option | Behavior |
|--------|----------|
| Filter Errored Documents | Individual errors sent to Errors path |
| Fail Interchange if Any Have Errors | Entire interchange fails on any error |

### Validation Levels
- Interchange level
- Transaction Set level (X12)
- Message level (EDIFACT/ODETTE)
- Transmission level (HL7)

## B2B Communication Connectors

Boomi provides specialized connectors for B2B communication protocols.

### AS2 Connector
Applicability Statement 2 protocol with:
- Message Disposition Notifications (MDN)
- Digital signatures
- Encryption support
- Receipt verification

### MLLP Connector
Minimum Lower Layer Protocol for healthcare:
- HL7 message transport
- Often used with additional security layer
- Client and Server modes

### OFTP2 Connector
Odette File Transfer Protocol 2:
- European automotive standard
- Encryption and digital certificates
- Designed for sensitive transmission

### Standard Connectors
FTP, SFTP, HTTP, and Disk connectors also support B2B scenarios with appropriate configuration.

## EDIFACT and X12 Envelope Layers

| Layer | X12 | EDIFACT | Key Difference |
|-------|-----|---------|----------------|
| Interchange | ISA/IEA (mandatory) | UNB/UNZ (mandatory) | Functionally equivalent, different field set |
| Functional Group | GS/GE (mandatory) | UNG/UNE (**optional**) | EDIFACT messages can sit directly inside UNB/UNZ (`useFunctionalGroups="false"`) |
| Transaction/Message | ST/SE | UNH/UNT | UNH carries version, release, and controlling agency metadata |

### Transaction-Level Equivalence

Common correspondences when a process bridges X12 and EDIFACT partners:

| X12 | EDIFACT | Purpose |
|---|---|---|
| 850 | ORDERS | Purchase order |
| 855 | ORDRSP | Purchase order response |
| 856 | DESADV | Despatch advice / ASN |
| 810 | INVOIC | Invoice |
| 820 | REMADV | Remittance advice |
| 832 | PRICAT | Price / sales catalog |
| 830 | DELFOR | Delivery forecast / schedule |
| 997 | APERAK | Functional / application acknowledgment |
| TA1 | CONTRL | Interchange / syntax acknowledgment |

## EDIFACT Connector Record API Fields

The Boomi platform API uses different object types and field names for EDIFACT vs X12 document queries. Query endpoint: `POST .../EDIFACTConnectorRecord/query` (vs `.../X12ConnectorRecord/query`).

| EDIFACT Field | X12 Equivalent | Notes |
|---|---|---|
| `messageType` | `transactionSet` | Different field name — different query operations required |
| `messageReferenceNumber` | `stControl` | Message-level control number |
| `interchangeControlReference` | `isaControl` | Interchange-level control number |
| `interchangeDate` / `interchangeTime` | *(no ISA-level equivalent)* | X12 API exposes `gsDate`/`gsTime` (group level) but no interchange-level date/time |
| `version` + `release` | `gsVersion` | EDIFACT splits version into two fields |
| `controllingAgency` | `agencyCode` | Typically `UN` for EDIFACT |
| `ackStatus` / `ackReport` | `ackStatus` + `isaAckStatus` | X12 has two ack levels; EDIFACT has one |
| `senderID` / `receiverID` | `senderID` + `senderIDQualifier` | EDIFACT API response omits qualifier fields |
| `outboundValidationStatus` / `outboundValidationReport` | *(same names)* | Same fields, same purpose |
| `customFields/CorrelationID` | `customFields/CorrelationID` | Same — custom tracking field |
| *(not present)* | `functionalID` | EDIFACT has no functional group concept in API |

**Multi-standard routing pattern**: In processes that handle both X12 and EDIFACT, the API response XML root element differs (`X12ConnectorRecord` vs `EDIFACTConnectorRecord`). A common pattern is to store the raw document in a Dynamic Document Property and regex-match: `^.*EDIFACTConnectorRecord.*$` vs `^.*X12ConnectorRecord.*$` to route to standard-specific subprocesses.
