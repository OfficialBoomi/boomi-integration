# B2B/EDI Platform Reference

## Contents
- Overview
- Architecture
- Supported EDI Standards
- Trading Partner Components
- Trading Partner Start/End Shapes
- Acknowledgment Flows
- Document Processing Paths
- Instance Identifiers
- Validation Architecture
- B2B Communication Connectors

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
│   │   ├── Documents path (valid documents)
│   │   ├── Errors path (failed validation)
│   │   ├── Acknowledgments path (generated acks)
│   │   └── Archive path (custom archiving)
│   └── Trading Partner End (generates envelopes/acknowledgments)
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
| EDIFACT | International | Cross-border trade, UN-developed syntax |
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

## Trading Partner Start/End Shapes

These process shapes handle EDI document processing within Boomi processes.

### Trading Partner Start
Receives and validates inbound EDI documents.

**Output Paths:**
| Path | Purpose |
|------|---------|
| Documents | Valid documents for processing |
| Errors | Documents that failed validation |
| Acknowledgments | Generated acknowledgment documents |
| Archive | For custom archiving logic |

### Trading Partner End
Generates EDI envelopes and acknowledgments for outbound documents.

## Acknowledgment Flows

Boomi automatically generates acknowledgments based on trading partner configuration.

| Standard | Acknowledgment Types | Purpose |
|----------|---------------------|---------|
| X12 | 997 (Functional Acknowledgment) | Default acknowledgment for transaction sets |
| X12 | 999 (Implementation Acknowledgment) | Healthcare (5010+), more detailed errors |
| X12 | TA1 (Interchange Acknowledgment) | ISA/IEA level validation |
| EDIFACT | CONTRL | Interchange-level acknowledgment |
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

## Document Processing Paths

### Inbound Processing
1. Document received via communication connector
2. Trading Partner Start validates against EDI profile
3. Valid documents route to Documents path
4. Invalid documents route to Errors path
5. Acknowledgments generated and route to Acknowledgments path
6. Optional custom archiving via Archive path

### Outbound Processing
1. Documents mapped/transformed in process
2. Trading Partner End generates EDI envelopes
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
