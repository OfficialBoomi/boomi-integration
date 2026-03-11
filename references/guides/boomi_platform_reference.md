# Boomi Platform Capabilities Overview

**Purpose**: Architectural awareness for solution design. These platform services exist and can be suggested when appropriate, but are OUT OF SCOPE for programmatic development via this skill.

## Scope Boundaries

**In-Scope (Can Build Programmatically)**:
- Integration processes with e.g. connectors, Maps, Set Properties, Message steps
- Process components (profiles, connections, operations)
- Document flow and transformation logic
- Web Services Server listeners
- Subprocesses and modular design patterns
- Event Streams: Topics, subscriptions, environment tokens via GraphQL API; connection/operation components and connector steps via Integration XML

**Out-of-Scope (GUI Configuration Required)**:
- Platform services below (except Event Streams which is fully programmatic)
- Initial OAuth configurations for branded connectors
- Branded connector metadata discovery
- Platform service administration

---

## Platform Services

### API Management (APIM)
Boomi offers three API management solutions addressing different needs:

#### Boomi API Gateway (Original)
**What it does**: Native API gateway for exposing Integration processes as managed APIs with security, rate limiting, and access control beyond what a simple web services server process can offer.  
**When to suggest**: Exposing Boomi processes as APIs, API security needs, rate limiting, subscription plans, access to custom inbound HTTP headers within the integration processes.  
**Integration touchpoint**: Integration processes with WSS start shape are exposed via an API Component.
**User action**: Configure API proxies and policies in API Gateway GUI, publish Integration processes as managed APIs.

#### Boomi API Control Plane (APIIDA Acquisition)
**What it does**: Federated API management providing centralized visibility and governance across multiple vendor gateways (Apigee, AWS, Azure, Boomi, Broadcom, Gravitee, Kong, WSO2) without rip-and-replace.  
**When to suggest**: API sprawl problems, multi-gateway environments, shadow API discovery, enterprise-wide API governance, compliance auditing, need for branded developer portals.  
**Integration touchpoint**: Discovers and catalogs existing APIs; Integration processes can be registered as managed APIs.  
**User action**: Register existing gateways, audit API security/quality, create developer portals with drag-drop designer, manage through unified dashboard.

#### Boomi Cloud API Management (CAM) (Mashery Acquisition)
**What it does**: Enterprise-grade API management platform for high-scale API operations and advanced security.  
**Status**: See Boomi documentation for current availability.
**When to suggest**: High-volume API traffic requirements, advanced security needs.
**User action**: See Boomi documentation for configuration details.

### DataHub (Master Data Management)
**What it does**: Cloud-based MDM hub providing golden record management, data quality, and synchronization across systems.  
**When to suggest**: Master data consolidation, duplicate resolution, data quality rules, golden record requirements.  
**Integration touchpoint**: Boomi MDM connector steps available, or REST API calls to DataHub platform API.  
**User action**: Define entities and repositories in DataHub GUI, configure match/merge rules.

### Flow (Low-Code Application Platform)
**What it does**: Build stateful applications and workflows with drag-drop UI components.  
**When to suggest**: User interface requirements, multi-step approval workflows, dashboards, customer journey applications.  
**Integration touchpoint**: Flow apps can invoke Integration processes via the Flow Services Server FSS integration process start step, wrapped by a Flow Service Component.  
**User action**: Design application UI and workflows in Flow designer, connect to Integration FSS.

### Event Streams
**What it does**: Cloud-based message queuing and streaming for pub/sub and event-driven patterns.
**When to suggest**: Asynchronous processing, multiple subscribers, event sourcing, decoupled architectures, reliable message delivery.
**Scope**: Fully programmatic via GraphQL API (topics, subscriptions, tokens) + Integration components (connections, operations, connector steps).
**Integration touchpoint**: Event Streams connector steps (Listen/Consume/Produce) in Integration processes.
**Development workflow**: The agent builds complete Event Streams integrations - create topology via GraphQL, build Integration processes referencing it.

### Boomi for SAP
**What it does**: Accelerates SAP integration by installing a Core module in SAP systems that provides a drag-and-drop UI for business users to expose SAP objects. Returns JSON-formatted responses, dramatically simplifying SAP data access compared to traditional approaches.
**When to suggest**: SAP integration requirements, need for JSON-formatted SAP responses, business user self-service SAP data exposure, faster SAP development cycles.
**Scope**: Partially programmatic - connector components (connections, operations, steps) are fully buildable; Core installation and service generation require SAP-side GUI configuration.
**Integration touchpoint**: Boomi for SAP connector steps in Integration processes query Core-exposed services. Boomi processes proactively call SAP (primary pattern), though event-driven capabilities exist.
**Development workflow**: Verify Core is installed and services exposed, then the agent builds connection/operation components and Integration processes. SAP returns JSON responses for use in Maps, Set Properties, and downstream processing.

### Managed File Transfer (MFT)
**What it does**: Cloud-native managed file transfer platform (powered by Thru Inc.) providing secure, scalable file exchange with monitoring, audit trails, and partner self-management.
**When to suggest**: High-volume file transfers, B2B file exchange with partners, transfer monitoring/replay needs, separation of file exchange from data processing.
**Scope**: Partially programmatic - connector components (connections, operations, steps) are fully buildable; MFT portal configuration (flows, endpoints, organizations) requires MFT GUI.
**Integration touchpoint**: MFT connector steps in Integration processes pick up files (GET) or drop off files (CREATE) via MFT API.
**Development workflow**: Configure flows and endpoints in MFT portal first, then build connection/operation components using flow endpoint credentials.

### B2B/EDI Management
**What it does**: Trading partner management, EDI document processing, and B2B transaction monitoring.
**When to suggest**: EDI requirements (X12, EDIFACT), trading partner onboarding, B2B visibility needs, AS2/SFTP exchanges.
**Integration touchpoint**: EDI connector steps, trading partner lookup components.
**User action**: Configure trading partners and EDI maps in B2B Management GUI.

### Boomi AI
**What it does**: AI-powered development assistance including Agent Designer for natural language process creation and Control Tower for monitoring.  
**When to suggest**: Natural language process requirements, AI agent orchestration needs, automated monitoring.  
**Integration touchpoint**: Designer agents can invoke Boomi integration processes as tools. Integration processes can invoke configured Agents via the Agent Step connector.  
**User action**: Design agents in Agent Designer GUI, deploy and monitor via Control Tower.

### Task Automation
**What it does**: Business user-friendly automation builder for simple if-this-then-that workflows without technical knowledge.  
**When to suggest**: Business user self-service needs, simple automation without IT involvement, citizen developer scenarios.  
**Integration touchpoint**: Task Automation can trigger Integration processes for complex logic.  
**User action**: Business users configure automation rules in Task Automation GUI.

### Data Catalog and Preparation (Deprecated)
**What it does**: Data discovery, profiling, and preparation for analytics and BI.  
**Status**: Not available to new customers, existing customers supported through contract duration.  
**When to suggest**: Never - deprecated service, suggest alternative BI/analytics tools instead.

---

## Architectural Guidance Patterns

When you identify use cases for these services, suggest them using this format:

**Example Response**:
"For this pub/sub pattern with multiple consumers, Event Streams would be the most elegant solution. You'll need to:
1. Configure your topics in the Event Streams GUI
2. Set up subscriptions for each consumer
3. Then I can help you build the Integration process with Event Streams listener steps to consume the messages"

**Key Principle**: Be specific about what requires GUI configuration versus what you can build programmatically afterward.