# Thinking Like a Boomi Developer
This guide covers Boomi's core mental models and development philosophy.

## Contents
- Core Mental Models
- Dependency-Aware Development
- Properties as Variables
- Document Tracking (Account-Level)
- Datetime Field Pipeline
- Connector Architecture & Behavior
- Step Design Principles
- Document Cache (When and Why)
- Architectural Patterns
- Critical Silent Failures Awareness
- Naming Conventions
- Development Workflow Principles
- Critical Deployment Pattern
- Profile Type Selection: Flat File vs EDI Profile
- EDI Profile Design Mental Models (X12 and EDIFACT)
- Platform Services Awareness

## Core Mental Models
### 1. Document Flow is Everything
- Think of data as documents flowing through a pipeline, processed left-to-right
- Each step either passes documents through unchanged, transforms them, replaces them with new documents (including potentially empty documents), or halts the document flow down that branch
- All documents are processed on a given step before any documents move to the next step
- Documents will be fully processed down a branch before a subsequent branch begins processing

### 2. Component Hierarchy & Reusability
- **Steps** = Process-specific instances on the canvas
- **Components** = Reusable definitions across processes (and processes themselves are also components) 
- **Nesting** = Components contain other components (e.g. Process → Map → Profiles)

### 3. Profile-Oriented Development
- Before you can reference any field in structured data, you generally need a profile component (exception: scripting)
- Profiles define the schema/structure of your documents (JSON, XML, Database, Flat File, EDI)
- No profile = no field access in Set Properties or Maps (but documents still flow through connectors)
- Most APIs use JSON or XML profiles
- Flat File profiles for CSVs and less-structured data
- EDI profiles for EDI documents and hierarchical record formats
- It is often beneficial to build a connector, execute it, view the process log, and create a profile based on the response. Alternatively you can often call the API yourself while designing, to see the output

## Dependency-Aware Development
Components reference other components. Think in dependency chains:
- Process components include steps that reference connection components, connector operation components, map components, profile components, etc. 
- Connector operation components and map components reference profile components (often an operation and a map and a process will all reference the same profile at different points)

You CAN create a process with placeholder steps before the referenced components exist (wireframe approach), but you CANNOT reference profile fields in Set Properties/Maps until the profile component exists.

## Properties as Variables
- **DDP (Dynamic Document Property)** = Per-document variable, travels with document through branches
- **DPP (Dynamic Process Property)** = Process-wide single value, last write wins, crosses branches
- **Connector Properties** = Special properties like file names, email subjects
- Prefer DDPs over DPPs when possible - they don't overwrite each other
- Use all-caps naming convention: `DPP_USEFUL_VARIABLE_NAME` or `DDP_USEFUL_VARIABLE_NAME`
- **Environment** = A deployment target grouping one or more runtimes (Atoms) with shared configuration.
- **Environment Extensions** = Connections, operations, and DPPs can be made configurable per-environment.

## Document Tracking (Account-Level)
Boomi accounts can define up to 20 **custom tracked fields** (Setup > Account > Document Tracking). These are account-wide field slots — not tied to any specific component type. Once defined at the account level, tracked fields can be bound to specific data sources in Trading Partner components, connector operations, or other contexts.

Each tracked field gets an account-scoped `fieldId` (a long integer). These IDs are **not universal platform constants** — they are assigned per-account when fields are created. To discover a given account's tracked field IDs, query the `CustomTrackedField` API object. Tracked field values appear in the Boomi dashboard for document-level visibility across process executions.

A use is in B2B/EDI Trading Partner components, where tracked fields extract values (e.g., PO Number from BEG03) from EDI documents for correlation and dashboard visibility. But the feature itself is a general-purpose platform capability.

## Datetime Field Pipeline
Profile fields with `dataType="datetime"` used in a map component, trigger Boomi's internal datetime processing. The `dateFormat` attribute controls representation external to the map only - within the map, Boomi always uses `yyyyMMdd HHmmss.SSS`.

**Mapping behavior by field type:**

| Source | Target | Behavior |
|--------|--------|----------|
| character | character | Pass-through (full control) |
| character | datetime | A Date Format map function must output the Boomi standard format. It must NOT output the datetime format specified in the target profile entry. Upon exiting the map step, the platform will convert from the Boomi standard format into the format specified by the target profile entry, and that format will be carried along to the rest of the process |
| datetime | character | The reverse of the above - The date format entering the map must align to the datetime format specified in the profile. The platform converts this to the Boomi standard format, and any Date Format function must begin with the Boomi standard format. |
| datetime | datetime | Transparent (auto-conversion) from one format to another without a Date Format function |

**Strategic guidance:** When generating new profiles, prefer `dataType="character"` for date fields. This provides full control over format manipulation. Only use `datetime` when required by existing profiles.

## Connector Architecture & Behavior
### Connection + Operation + Step Pattern
All connectors (REST, Database, Salesforce, Event Streams) follow same architecture:
- Connection component: Base URL, credentials, timeouts
- Operation component: Specific action, endpoint, parameters
- Connector step: References both, executes operation

### Document Flow Through Connectors
- **Connectors inherit upstream documents**: Content flows from previous steps into connector
- **Connector responses generate NEW documents**: Depending on configuration output either replaces input (doesn't merge), or passes the input document through as-is
- **Some operations expect empty input**: GET requests for example - use empty Message step before connector to clear inherited content
- **Documents flow without profiles**: Profiles enable field access in maps/properties, not document flow in and out of the connector itself

### Connector Parameters Override Document Content
**CRITICAL DESIGN DECISION**: When connector step has parameters configured, they completely override document content.

**Decision framework:** Choose document-only OR parameters-only (never both)
- **Document approach**: Build payload with Map/Message → Connector has no parameters
- **Parameters approach**: Set all values via connector dynamicProperties → No upstream Map needed

### Connector Step Parameter Binding
Operations may define parameter "slots" (inputs). (Some types of operations do, some don't - do not assume a connector has a particular parameter. You will either see specific operation parameters documented if available). 

Steps fill them with values at runtime using three binding types:

| valueType | Source | Use When |
|-----------|--------|----------|
| `static` | Hardcoded value in step config | Same value every execution |
| `document` | Document property (DDP or connector property) | Value varies per document |
| `track` | Tracked property from previous step | Value from connector response metadata |

**Example pattern:**
```xml
<parametervalue elementToSetId="0" elementToSetName="{param-name}" key="0" valueType="static">
  <staticparameter staticproperty="{hardcoded-value}"/>
</parametervalue>
```

This is distinct from REST connector's `<dynamicProperties>` which handles URL/header substitution specifically.

### Connector Type Selection
When uncertain, default to technology connectors (REST, Database) over branded ones.

### Connector Implementation Approaches
- **Technology Connectors (REST, Database, Event Streams)**: Fully programmatic - connections, operations, all configuration via XML
- **Branded Connectors (Salesforce, NetSuite, Boomi for SAP)**: Require GUI configurations by the user for OAuth flows, metadata import, live discovery, or Core module setup. Reference existing components by ID, or use placeholder pattern when components don't exist yet, or create net new functionality as technology connectors.
- **MCP Server Connector**: Listener-based connector that exposes Boomi processes as AI-callable tools via Model Context Protocol. Uses Connection (server identity + auth) + Operation (tool definition with JSON schema) + Start Step (listener entry point). Unlike request-based connectors, MCP processes are always listener processes that wait for AI agent invocations. Technology Preview - not production-ready.
- **Agent Connector** (`connectorType="boomiai"`): Integrates AI agents from Agent Control Tower into processes. Connection + Operation require one-time GUI setup (Component API does not support creating these), but once created they are reusable across any number of programmatically-built processes by ID. Requires a Message step before it to construct the prompt. Output is an SSE event stream; downstream parsing needed to extract the agent's text response.

**Connection Discovery (recommended before building):**

Re-using existing connections avoids credential exposure in the context window. Offer this workflow first, but respect the user's preference if they want to take a different approach:

1. **Check `preferred_connections.md`** in the project workspace — match entries by description to needed connector types, confirm with user
2. **Ask the user** to create or provide a link or component ID for an existing connection — user pastes Boomi GUI link, agent extracts componentId and pulls.
3. User provides credentials directly for the agent to create a new connection (this is not a recommended best practice)
4. After resolving, offer to add newly discovered connections to `preferred_connections.md`

**Credential philosophy:**

- **Prefer pulling from platform**: Credentials configured in the Boomi GUI come down pre-encrypted — this keeps secrets out of the conversation entirely
- **User-provided credentials are OK**: If a user shares a credential directly, use it. If it appears to be a production secret, remind them of the pull-from-platform option — but respect their choice
- **Avoid reciting credentials** in plans, summaries, or overviews — they could be visible during screen sharing. The user can always ask you to surface them if needed

See `cli_tool_reference.md` § Credential Management for encryption behavior and password field handling.


### REST Connector Specifics
**CRITICAL**: The REST connector has a fundamentally different architecture from the older HTTP Client connector. Prefer REST for new work; for editing existing `connectorType="http"` components, see `components/http_client_component.md`.

**Dual Configuration Pattern**: Operation component defines parameter "slots", process step fills them with runtime values.

**Mental Model:**
```
REST CONNECTOR:
├── Connection Component: Base URL, auth, timeouts
├── Operation Component: Static config (parameter slots, static values)
└── Process Step: Dynamic runtime values via <dynamicProperties>
```

**Why this matters**: HTTP Client and REST bind dynamic values through different mechanisms. HTTP Client uses `isVariable="true"` on headers and path elements (the GUI "replacement variable" feature), resolved from DDPs of matching name set upstream. REST requires the process step's `<dynamicProperties>` element. Patterns do not port between them.

**Critical Silent Failure - Profile Type Attributes:**

- NEVER use `requestProfileType` or `responseProfileType` attributes in REST connector operations
- They don't exist in GUI and cause silent document flow failures
- Connector reports success, process shows documents flowing, but content is lost/corrupted
- No design-time validation
- REST connectors return raw responses - use Map/Set Properties steps for structured parsing

## Step Design Principles
### Message Steps
Template engines for generating document content from scratch or with variable substitution. Despite the name, they create document content, not just "send messages".

**CRITICAL**: Single quotes toggle curly brace variable substitution mode, which has the potential to cause silent failures in message steps preparing JSON payloads. Pattern: `'{"field":"'{1}'"}'` for JSON with variables. If you aren't working with JSON this likely does not apply

### Map Steps
Transform structured data between profiles. Restructure organization while converting types and applying transformations.

**Transformation Decision Tree**:

- **Use Maps**: For transforming existing structured data from one profile to another (_strongly_ bias toward maps - elegant for humans)
- **Use Message Steps**: For generating new content/payloads from scratch or with templating
- **Use Data Process Steps**: For specialized scripts/mechanisms not achievable with other two

### Set Properties Steps
Extract values from documents and store as DDPs/DPPs for downstream use. Enable carrying extracted values, dynamic parameters, and state information through subsequent steps.

### Event Streams Architecture
**Listen vs Consume - Fundamental Architectural Choice:**

- **Listen**: Event-driven, continuous processing, Start step only → Use for real-time event processing (a more common use of event streams)
- **Consume**: On-demand pull, scheduled/batch, Start or mid-process → Use for controlled batch operations

This choice affects entire process architecture - Listen processes will be triggered in real time by a mechanism external to the process, Consume processes will run on schedule or manually by a user.

### Data Process Steps
The "Swiss army knife" for document manipulation when Maps or Message steps aren't sufficient. Supports sequential processing actions where each operation's output feeds the next.

**Groovy Scripting — Last Resort Only** (Design-Critical):
A core Boomi value proposition is that integrations are manageable by humans through the platform UI. Native components (Maps, Decisions, Set Properties, Message steps) are visible, configurable, and debuggable in the GUI. Scripts are opaque black boxes that only the author can maintain. **Always use native Boomi components first, even when scripting would be faster to write.** The extra build effort pays for itself in maintainability.

Scripting is only appropriate when native components genuinely cannot accomplish the task. Before writing any Groovy, exhaust these alternatives:
1. Can Map step handle this transformation? → Use Map
2. Can Message step generate this content? → Use Message
3. Can Decision/Route/Branch handle this routing? → Use Decision/Route/Branch
4. Can Set Properties + concatenation solve this? → Use Set Properties
5. Can a subprocess with native components accomplish this? → Use subprocess
6. **None of the above work?** → Groovy, kept under 50 lines

**CRITICAL Groovy Scripting Rules (when scripting is unavoidable):**

- MUST call `dataContext.storeStream()` or documents disappear silently
- Keep scripts minimal (<50 lines) — if longer, break into native components
- Prefer Map steps for structured transformations, even complex ones
- **Batch failure mode**: Script errors fail ALL documents in batch (unlike native steps which fail per-document)

### Branch Steps
Branches execute sequentially (not simultaneously) - each branch gets a copy of the input document and completes fully before the next branch begins.

**Property behavior across branches:**

- **DDPs set before branch**: Carry down all branch paths
- **DDPs set within branch**: Only follow that specific branch path
- **DPPs set in earlier branches**: Persist and are accessible in subsequent branches

### Process Call Steps
Enables modular design by routing documents into subprocesses. All subprocess branches complete and return their documents simultaneously to the parent process - this is a key architectural behavior that enables cross-branch document combination that would be impossible within a single process.

**Key architectural use cases:**

- **Test Mode Enablement**: Listener start shapes disable test mode - wrap the core business logic in a subprocess to maintain testability
- **Cross-Branch Document Combination**: Documents from separate subprocess branches return together, enabling combination operations
- **Modularization**: Break complex processes into reusable, maintainable components

**Critical design requirement:** Subprocess MUST use passthrough start configuration to receive parent documents.

### Try-Catch Steps
Error handling with dual paths: Try for normal processing, Catch for errors. Place directly after Start step for process-wide error handling, or wrap specific operations that may fail.

**Error halting:** When a document errors, processing halts for that document - subsequent steps and parallel branches don't execute. Try-catch provides a handling path instead of process failure.

**Catch path pattern:** Always include Notify step to log error details (`meta.base.catcherrorsmessage`) and further handling or termination for the document as necessary.

### Dragpoints and Output Path Wiring
The `<dragpoints>` element is **required** on every shape — omitting it causes a schema validation failure. An empty `<dragpoints/>` means no outgoing connections and is valid for terminal shapes.

`<dragpoint>` children represent wired connections via `toShape="shapeN"`. For unwired output paths (e.g., a TP Send Errors path not yet connected), use `toShape="unset"` — this is the conventional representation and is preserved exactly by the platform. The GUI renders available output paths based on shapetype and configuration, independent of what `<dragpoint>` children exist in the XML.

Multi-path shapes (TP Send, Decision, Try/Catch, Branch) support partial wiring at the API level — some paths wired, others with `toShape="unset"`. However, always wire all paths to a downstream step (even if just a Stop step) as a best practice.

### Terminal Steps (Return Documents vs Stop)
**Return Documents:** Returns documents to calling context (parent process or external caller). In subprocess, creates return branches in parent. In listener, returns API response. Documents retain all properties when returned.

**Stop:** Ends processing on current path without returning documents. `continue="true"` lets other paths keep processing; `continue="false"` halts the entire process. **CRITICAL** The `continue` attribute must always be present — bare `<stop/>` causes runtime `NullPointerException` and GUI stack overflow (see error reference Issue #15). See `references/steps/stop_step.md`.

**Critical:** Use Return Documents OR Stop at path end, never both.

## Document Cache (When and Why)

The document cache is a way to store documents retrieved during a process so they can be used later. Many use it to correlate different types of data to one another or to pull a value from another document based on the value in the current document. Documents are kept only during the process execution (in memory) and do not carry over into later executions.

**Use a document cache when:**

- Building cross-reference lookups within a process execution (e.g., cache customer records, look up by ID while processing orders)
- Caching destination system records for existence checks before insert/update — avoids per-record API calls
- Accumulating documents across processing steps for aggregated retrieval
- Joining data from multiple sources via map cache joins or Retrieve From Cache steps

See `references/components/document_cache_component.md` and `references/steps/document_cache_steps.md` for component structure and step configuration.

## Architectural Patterns
### Wrapper + Subprocess Separation of Concerns
**Key Principle**: Separate API listener mechanics from business logic for testability.

**Why this matters**: Web Services Listeners cannot be tested via platform test tools (require HTTP requests). By isolating business logic in a subprocess with passthrough start, the core logic remains testable within the platform GUI by users, while the wrapper handles HTTP concerns.

**Architecture concept:**

- Thin wrapper: WSS listener → Process Call → Return Documents
- Thick subprocess: Business logic, transformations, connectors
- Subprocess can be tested independently, called from multiple wrappers, and developed without HTTP complexity

### Profile Reuse Principle

**CRITICAL PRINCIPLE**: Same structure = reuse profile. Different structure = new profile.

**Why this matters**: Profiles define data structure, not data flow. If two operations work with the same JSON/XML structure, they should reference the same profile component regardless of where they appear in the process hierarchy.

**Common anti-pattern**: Creating duplicate profiles for subprocess operations when parent already defines the structure (e.g., "subprocess_request_profile" when WSS wrapper already has request profile with identical structure).

**Benefits**: Fewer components, consistent validation, cleaner architecture.

### Debugging with Notify Steps

**Key Principle**: Notify steps = your console.log() for Boomi processes.

**Why this matters**: Boomi processes are opaque at runtime. Notify steps provide visibility into document content, property values, and execution flow at critical points.

**Essential concept**: Place Notify steps strategically (after Message steps, before/after connector calls, after Set Properties, always on Catch paths) to validate behavior and payloads during development. After or before notable process points, use `valueType="current"` to log the raw document for visibility.

## Critical Silent Failures Awareness
Key patterns that fail silently without errors:
- **Quote escaping**: Message/Notify variable substitution failures - MOST COMMON BUG
- **Connector parameters override document**: Document content ignored
- **Parent-subprocess deployments**: Updates not reflected until parent redeployed
- **XML schema mistakes**: Common validation errors

## Naming Conventions
If the user provides their own naming convention, defer to it — the conventions below are defaults only.

- `DPP_VARIABLE_NAME` for process properties
- `DDP_VARIABLE_NAME` for document properties
- Descriptive component names: `Query Salesforce Opportunity by ID`
- Specific profile names with a format: type.project.mechanism.request/response
  - Examples
  - j.PetStore.GetListings.REQ
  - x.Salesforce.UpdateOpportunity.RESP
- **Subprocess components**: Use `[SUB] ProcessName` format

## Development Workflow Principles
### Component Creation vs Update
**When to CREATE (New Components)**:

- Component doesn't exist on platform yet
- No sync state file (`.sync-state/{name}.json`) exists
- Building new integrations from scratch

**When to UPDATE (Existing Components)**:

- Component already exists on platform
- Sync state file exists with component ID or component can be found via a reference in a parent component
- XML has populated `componentId` from platform
- Modifying pulled components

### Component Dependency Order

**Creation Order (Dependencies First)**:

1. **Profile Components**: JSON, XML, Database schemas
2. **Connection Components**: Endpoints, authentication, timeouts
3. **Operation Components**: Specific API calls, references profiles & connections
4. **Process Components**: References all above components in steps

**Why this matters**: Each component type references the ones above it. Process steps can't reference operations that don't exist yet, operations can't reference connections that don't exist yet, etc. Design your orchestration with this hierarchy in mind.

### Push-As-You-Go Workflow

**Core Philosophy**: Create → Push → Use generated ID for next component

**Anti-pattern**: Creating many components locally before pushing causes "big bang" sync failures and reference resolution issues.

**Design approach**:

1. Identify component dependency chains
2. Create and push incrementally in dependency order (Profiles → maps → Processes)
3. Read `.sync-state/` for generated component IDs after each push
4. Use actual GUIDs in next dependent component

### Folder Management Principle

**Zero Tolerance for Root Folder Components**: All components must be placed in organized folders, never account root.

**Why this matters**: Account hygiene and organization. Root folder should not contain individual components. All components belong in project-specific folders for maintainability and team collaboration.

## Critical Deployment Pattern
**Parent-Subprocess Dependency**: When updating subprocesses, ALWAYS redeploy parent processes to pick up changes. This is the most dangerous deployment gotcha - parent processes snapshot subprocess versions at deployment time.

**Deployment Efficiency**: Parent deployment automatically includes all referenced components - deploy only the parent to update both parent and subprocess.

## Profile Type Selection: Flat File vs EDI Profile
Make this choice first, before building profiles for fixed-width or multi-record formats.

| Output Need | Profile Type |
|-------------|--------------|
| Independent rows (CSV, Excel-like tabular data) | `profile.flatfile` |
| Hierarchical parent-child relationships | `profile.edi` with `standard="userdef"` |

Flat file profiles cannot express that record B belongs to record A - they produce all records as independent rows. Only EDI profiles with nested `EdiLoop` structures can produce hierarchical output where child records appear immediately after their parent.

**Use EDI Profile (userdef) when:**

- Child records must follow their parent records in output
- Nested repeating groups (e.g., shipment → references, location → references)
- Complex proprietary formats (TMW, mainframe formats)
- Any format requiring hierarchical record relationships

## EDI Profile Design Mental Models (X12 and EDIFACT)

This section applies for EDI profile work. For segment-level structure and code lists, consult the trading partner's implementation guide / companion document and a sample transaction. For transaction-set routing facts (GS-01 codes, HIPAA GS-08 Implementation Convention references) see `components/edi_profile_component.md` § Transaction Set ID Reference. For the XML mechanics of qualifier-driven routing (tagLists, composite sub-element references, segment-level filters), see `components/edi_profile_component.md`.

### Correlation Keys: Extract Early

Every EDI document carries a primary identifier that trading partners use to correlate conversations (acknowledgments, invoices against an ASN, etc.). The Boomi instinct is to extract this identifier near the top of the process via Set Properties so it travels as a DDP for logging, tracked fields, and routing.
- **X12** uses a document-specific "B segment": `BEG03` (850 PO#), `BIG02` (810 Invoice#), `BSN02` (856 Shipment ID). Each transaction set has its own B-segment.
- **EDIFACT** uses the universal **BGM** segment across every message type: `BGM01.1` identifies the document type (UN/EDIFACT code list 1001), `BGM02` carries the reference number.

### Qualifier-Grouped Repeats

Both standards share the same pattern: a segment or loop repeats and a qualifier element on each occurrence identifies which instance it is. X12's N1 loop (qualified by `N101`: ST/BT/etc.) and EDIFACT's NAD segment (qualified by `NAD01`: BY/SU/etc.) are the canonical examples; REF/RFF and DTM follow the same shape. Plan profiles around the qualifier from the start — in Boomi you route instances via `tagLists` keyed on that element rather than by position.

EDIFACT qualifiers often live in composite sub-elements (e.g., `RFF01.1`, `DTM01.1`) rather than standalone elements, and EDIFACT segments use composites pervasively elsewhere too. For that reason EDIFACT work almost always pulls `components/edi_profile_component.md` alongside the partner's companion guide.

## Platform Services Awareness
Boomi offers platform services beyond Integration processes (Event Streams, DataHub, Flow, API Management, B2B/EDI, AI agents, MCP Server). These require GUI configuration but integrate with Integration processes.

**When designing solutions**: Consider whether Event Streams (pub/sub), DataHub (master data), Flow (UI/workflows), API Gateway (advanced API management), or MCP Server (exposing processes as AI-callable tools) fit the use case better than pure Integration processes.
