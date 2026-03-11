# Boomi for SAP

## Overview
Boomi for SAP provides a proprietary, differentiated approach to SAP integration by installing a module (Core) in the SAP system that exposes a drag-and-drop interface for business users to expose SAP data. The primary benefit is JSON-formatted responses instead of traditional SAP data formats (IDOC, RFC, BAPI), reducing integration complexity.

**Key Value**: Users configure SAP object exposure via Core UI, Boomi processes query those services and receive JSON payloads—eliminating the need to handle traditional SAP data formats.

**Architecture**: Dual-component system with SAP-side configuration and Boomi-side connector for proactive queries. Boomi for SAP has a Boomi-proprietary UI that allows users to manage the services.

**Event Framework**: Boomi for SAP includes an event framework capable of sending SAP events to Boomi for event-driven patterns, though the primary usage pattern in scope for this skill is Boomi-initiated queries. Event framework implementation details are not documented in the current skill version.

## Architecture Components

### Boomi for SAP Core (SAP-Side)
**What it is**: SAP module/application installed on SAP systems (requires NW ABAP 7.40 SP8 or above per vendor documentation).

**Primary Capabilities**:
- Drag-and-drop UI for business users to expose SAP objects without ABAP coding
- Service generation creating accessible endpoints for SAP data
- JSON response formatting (eliminates complex SAP data format handling)
- Monitoring interface for technical SAP users

**Deployment**: Installed and configured directly on the SAP system.

### Boomi for SAP Connector (Boomi-Side)
**What it is**: Branded connector in Boomi Enterprise Platform for querying Core-exposed services.

**Capabilities**:
- Connection components for SAP system authentication
- Operation components for querying SAP objects with filter configuration
- Connector steps for runtime parameter binding and execution
- JSON response handling in Boomi processes

**Deployment**: Standard Boomi connector deployable on basic runtime, runtime cluster, public/private runtime clouds.

## Scope Boundaries

### In-Scope (Programmatically Configurations)
- **Operation component updates**: We can modify existing operation components (e.g. by modifying or adding filters)
- **Connection components**: We can manage connection components programmatically but most they would almost always be configured via the GUI, as a prerequiste for the user importing a connector operation
- **Connector steps**: Parameter binding, runtime execution in processes
- **Complete integration processes**: Using SAP connector with Maps, Set Properties, and other Boomi components

### Out-of-Scope (Requires SAP Core GUI & Configuration, or requires Boomi platform GUI configuration)
- **Operation component creation**: The operation components include a GUI-only import mechanism that handles service and schema discovery and generates profiles
- **Boomi for SAP Core installation**: SAP system module deployment
- **Service generation**: Using Core UI to expose SAP objects
- **Object metadata discovery**: Initial import and configuration of SAP object structures
- **Event framework configuration**: If using SAP-initiated event patterns

## Integration Pattern

**Primary Usage (Boomi-Initiated Queries)**:
1. Business users expose SAP objects via Boomi for SAP Core UI
2. SAP system becomes accessible via HTTPS endpoints
3. Boomi connection component references Boomi for SAP services
4. Operation components define queries with filters and field selection
5. Process connector steps execute queries with runtime parameters
6. Boomi for SAP returns JSON-formatted responses for use in Boomi processes

**Response Format**: JSON with array wrapper structure (see operation component documentation for examples).

## Usage Guidance

**When to suggest Boomi for SAP**:
- SAP integration requirements
- Need for simplified SAP data access with JSON responses
- Faster development cycle vs traditional SAP integration

**When to use standard connectors instead**:
- SAP OData services already available (use REST connector or SAP application connector)
- Direct RFC/BAPI requirements with existing infrastructure

**Development workflow**:
- Verify Boomi for SAP Core is installed and services are exposed
- Create or pull connection component with SAP credentials
- Define operation components for required objects (filters, fields)
- Build process with connector steps and parameter binding
- Use Set Properties or Map steps to work with JSON responses
- Test and deploy following standard connector patterns

## Connection Requirements
- SAP system with Boomi for SAP Core installed (NW ABAP 7.40 SP8+ per vendor documentation)
- Network access from Boomi runtime to SAP endpoint
- SAP objects exposed via Core UI before connector usage