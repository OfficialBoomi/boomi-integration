---
name: boomi-integration
description: Develops and deploys Boomi integrations, APIs, and platform services including Event Streams, Flow Services, and web service endpoints. Use when building, modifying, or deploying Boomi components (processes, profiles, connections, operations, maps, API components, Flow Services). Handles bi-directional sync, deployment automation, testing, and provides comprehensive Boomi reference documentation for complete solution development.
---

# Implementing Boomi with this Skill
This is the Boomi Process Development Framework - a reusable skill that enables AI coding agents to build Boomi integration processes programmatically. It provides CLI tools, reference documentation, and patterns for bi-directional synchronization with the Boomi platform API.

**Architecture**: The framework is separated from project components:
- **boomi-integration skill**: Reusable infrastructure, tools, documentation
- **active-development/** (project root): All working files - components, sync state, feedback

**Running CLI tools**: The `scripts/` directory lives inside the skill, not the project workspace. When you see `bash scripts/boomi-*.sh` in documentation, resolve the path relative to the skill's location. Run from the project workspace directory so `.env` and `active-development/` are found correctly.

## Documentation Architecture

**SKILL.md is the navigation hub**: This file contains file references and routing guidance. Other documentation files contain minimal cross-references by design - this prevents deep hierarchical dependencies (which causes skimming at lower levels) and keeps navigation centralized.

**Complex tasks require multiple files**: Most Boomi development tasks require consulting 3-5+ documentation files together. The "Use when" guidance throughout this file indicates which combinations to load for specific scenarios.

**Common multi-file workflows:**
- **Adding any step**: BOOMI_THINKING.md + process_component.md + steps/[step].md + dependency component docs
- **Creating connectors**: connection_component.md + operation_component.md + connector_step.md + BOOMI_THINKING.md
- **Map transformations**: map_component.md + map_component_functions.md + source/target profile docs
- **Event Streams**: event_streams_connection + operation + steps + platform_entities/event_streams.md
- **B2B/EDI Trading Partners**: trading_partner_component.md + trading_partner_steps.md + edi_profile_component.md + platform_entities/edi_b2b.md
- **Disk V2 (File System)**: diskv2_connection_component + diskv2_connector_operation_component + diskv2_connector_step
- **MFT (Managed File Transfer)**: mft_connection_component + mft_connector_operation_component + mft_connector_step
- **MCP Server (AI Tool Exposure)**: mcp_server_connection_component + mcp_server_operation_component + mcp_server_start_step + platform_entities/mcp_server.md
- **Agent Step (AI Agent in process)**: agent_step.md
- **Flow Services**: fss_operation_component + fss_start_step + flow_service_component + platform_entities/flow.md
- **Debugging**: boomi_error_reference.md + relevant step/component docs
- **Branch & Merge** (opt-in only): branch_merge_guide.md + cli_tool_reference.md branch workflows section

## First-Time User Detection
**Check before starting any Boomi work**: The `scripts/` directory is provided by this skill — ensure it is loaded before invoking CLI tools. Run `bash scripts/boomi-env-check.sh` to see which variables are SET vs UNSET (values are never exposed). Then run `bash scripts/boomi-folder-create.sh --test-connection` to verify platform access. If credentials are missing, guide the user through `references/guides/user_onboarding_guide.md` or `/bc-integration:env-setup-guide`.

## Connection Discovery & Credential Security
**Connection re-use is recommended.** Pulling existing connections keeps credentials out of the conversation. Offer the connection discovery workflow first, but respect the user's choice if they prefer to provide credentials directly. See `references/BOOMI_THINKING.md` § Connection Discovery for the full workflow.

## Workspace Organization & Knowledge Base
### Physical Directory Structure & Documentation Inventory
**Core Mental Models:**
- `references/BOOMI_THINKING.md` - Core mental models and development philosophy (always read first)
- `references/guides/boomi_patterns.md` - Step-by-step implementation recipes for common integration scenarios (read when designing a new process or refactoring significantly)
- `references/guides/boomi_error_reference.md` - Error patterns, silent failures, and troubleshooting (read early in any troubleshooting effort)
- `references/guides/boomi_platform_reference.md` - Platform services catalog (DataHub, Flow, API Gateway, B2B/EDI) with scope boundaries (read when designing a new process, evaluating designs that expand beyond integration, or refactoring significantly)
- `references/guides/problem_solving_guide.md` - Tiered escalation framework for handling unexpected situations, unknown components, and undocumented scenarios (read when encountering undocumented components or unexpected behavior)

**Step Type References:**
Step documentation in `references/steps/` covers all in-scope step types with working examples.

**Component Type References:**
Component documentation in `references/components/` covers all in-scope component types with working examples.

### Reading Discipline
**Required Reading for Boomi Work:**
When working on any Boomi process or component modifications:
1. **Always start by reading** `references/BOOMI_THINKING.md` - contains essential Boomi development philosophy and patterns
2. **Then load specific references** based on the task:
   - Building/modifying a process? Load `references/components/process_component.md`
   - Adding a specific step? Load `references/steps/[step_type].md` (e.g., `rest_connector_step.md`, `map_step.md`)
   - Creating a component? Load `references/components/[component_type].md`

**READ BEFORE WRITING**: Always read `references/steps/[step_type].md` completely before generating XML. Validation errors typically mean the XML doesn't match documented structure.

**Large Profiles**: When attempting to read a profile file (XML, EDI, or Flat File) and encountering a "file too large" error, immediately run `boomi-profile-inspect.py` (Python stdlib) on it. This generates a searchable JSON inventory at `active-development/profiles/distilled_<name>.json`. Search that file for field keys/paths, and grep the original XML by key if comments are needed.

**External Documentation Strategy:**
Default to the local `references/` content — it is curated and verified for this skill's use cases. As a fallback, `developer.boomi.com` and `help.boomi.com` are fetchable and can supplement local docs. `community.boomi.com` remains inaccessible (JavaScript-heavy). If all sources fail: ask the user to paste content. Do not proceed without critical information.

**Skill Repository:**
```
 boomi-integration/                   # full skill path provided at skill load time
├── SKILL.md                     # Main skill definition and navigation hub
├── README.md                    # Installation and setup for new users
│
├── references/             # Comprehensive Boomi platform knowledge base
│   ├── BOOMI_THINKING.md        # Core mental models and development philosophy (always read first)
│   │
│   ├── guides/                  # Topical guidance and workflow docs
│   │   ├── user_onboarding_guide.md     # First-time user setup: .env creation, connection testing
│   │   ├── cli_tool_reference.md        # Read when: using CLI tools - command syntax, workflows, sync state, error recovery
│   │   ├── pulling_components.md        # Read when: user provides platform URL or component ID to work on
│   │   ├── process_testing_guide.md     # Read when: deploying and testing processes - execution workflows, log analysis
│   │   ├── api_conversion_patterns.md   # Read when: converting process to API or building WSS listeners
│   │   ├── boomi_patterns.md            # Step-by-step implementation recipes for common scenarios
│   │   ├── boomi_error_reference.md     # Error patterns, silent failures, and troubleshooting
│   │   ├── boomi_platform_reference.md  # Platform services catalog (DataHub, Flow, APIM, B2B/EDI) with scope boundaries
│   │   ├── api_endpoint_guide.md        # Sample developer friendly APIs for experimentation
│   │   ├── branch_merge_guide.md        # Read when: user explicitly requests branch/merge workflows — branch lifecycle, merge requests, conflict resolution (opt-in, do not use unless directed)
│   │   └── branch_merge_api_behavior.md # API-level branch semantics — last resort when CLI tools don't cover an edge case. Use branch_merge_guide.md if at all possible.
│   │
│   ├── components/              # Component XML reference documentation
│   │   ├── process_component.md              # Use when: creating/editing process XML - defines shape positioning, dragpoint connections, and canvas structure
│   │   ├── json_profile_component.md         # Use when: defining JSON document schemas for validation, accessing JSON fields in Maps/Set Properties, consolidating array elements
│   │   ├── xml_profile_component.md          # Use when: defining XML document schemas with namespaces, accessing XML elements/attributes in Maps/Set Properties
│   │   ├── flat_file_profile_component.md    # Use when: defining CSV/delimited file schemas, creating placeholder profiles for Map component sources
│   │   ├── edi_profile_component.md          # Use when: defining EDI document schemas, troubleshooting EDI parsing failures, understanding Boomi-specific EDI configuration
│   │   ├── map_component.md                  # Use when: creating field-to-field transformations between profiles, understanding map generation rules and mapping patterns
│   │   ├── map_component_functions.md        # Use when: applying transformations within maps - string manipulation, date formatting, conditionals, math, lookups
│   │   ├── rest_connection_component.md      # connectorType: "officialboomi-X3979C-rest-prod". Use when: creating REST API connections - base URLs, authentication patterns, timeouts, connection pooling
│   │   ├── rest_connector_operation_component.md # Use when: defining REST operations - HTTP methods, resource paths, headers, query parameters, request/response profiles
│   │   ├── databasev2_connection_component.md    # connectorType: "officialboomi-X3979C-dbv2da-prod". Use when: creating database connections - JDBC URLs, drivers, credentials, connection management
│   │   ├── databasev2_connector_operation_component.md # Use when: defining database operations - SQL queries, dynamic operations, GET/INSERT/UPDATE/DELETE, response profiles
│   │   ├── event_streams_connection_component.md # connectorType: "officialboomi-X3979C-events-prod". Use when: creating Boomi Event Streams connections - environment tokens, cloud service authentication
│   │   ├── event_streams_listen_operation_component.md # Use when: defining Listen operations for continuous event-driven or pub/sub processing (start shape subscribers)
│   │   ├── event_streams_consume_operation_component.md # Use when: defining Consume operations for on-demand message batch retrieval (mid-process - not event triggered or pub/sub)
│   │   ├── event_streams_produce_operation_component.md # Use when: defining Produce operations for publishing messages to Boomi Event Streams topics (pub/sub publishers)
│   │   ├── salesforce_connection_component.md    # connectorType: "salesforce". Use when: working with Salesforce connections (GUI-created only, but able to be used by this skill) - OAuth flows, session authentication
│   │   ├── salesforce_connector_operation_component.md # Use when: working with existing Salesforce operations (GUI-imported) - filters, field selection, query options
│   │   ├── boomi_for_sap_connection_component.md # connectorType: "invixoconsultinggroupas-OZI90V-boomia-prod". Use when: creating SAP connections via Boomi for SAP Core - endpoint URLs, credentials, timeouts
│   │   ├── boomi_for_sap_connector_operation_component.md # Use when: defining SAP object queries with filters and field selection, working with Core-exposed services
│   │   ├── custom_connector_connection_component.md # Use when: creating connections for custom SDK connectors - connector type format, GenericConnectionConfig structure
│   │   ├── diskv2_connection_component.md       # connectorType: "disk-sdk". Use when: creating Disk V2 connections - local/network file system access, directory configuration, cloud runtime restrictions
│   │   ├── diskv2_connector_operation_component.md # Use when: defining Disk V2 operations - file CREATE/UPSERT/GET/QUERY/LIST/DELETE/LISTEN, filters, actionIfFileExists, directory overrides
│   │   ├── mft_connection_component.md         # connectorType: "thru-8SHH0W-thrumf-technology". Use when: creating MFT connections - Thru MFT partner connector credentials
│   │   ├── mft_connector_operation_component.md # Use when: defining MFT operations - file pickup, drop-off, status updates
│   │   ├── web_services_server_start_shape_operation.md # connectorType: "wss". Use when: converting process to API, creating HTTP listener endpoints, defining request/response profiles for Boomi processes to be exposed as web services/ API end points
│   │   ├── fss_operation_component.md    # connectorType: "fss". Use when: creating Flow Services Server operations for Flow-callable Integration processes
│   │   ├── flow_service_component.md     # Use when: wrapping Integration processes as Flow-discoverable services, exposing actions to Boomi Flow
│   │   ├── mcp_server_connection_component.md  # connectorType: "officialboomi-X3979C-mcp-prod". Use when: creating MCP Server connections - server naming, authentication, conversation starters
│   │   ├── mcp_server_operation_component.md   # Use when: defining MCP tools - JSON schema for tool parameters, HTML encoding, dynamic operation fields
│   │   ├── trading_partner_component.md       # Use when: creating B2B/EDI trading partner components - AS2 config, X12 ISA/GS control info, document types, tracked fields, acknowledgments
│   │   ├── cross_reference_table_component.md # Use when: creating static lookup tables for value translation between systems, using cross reference lookups in maps or parameter values (Set Properties, Message, Notify)
│   │   ├── process_property_component.md    # Use when: creating typed, reusable process property collections for environment-specific config, reading process property values in Set Properties or Groovy scripts
│   │   ├── document_cache_component.md      # Use when: creating Document Cache components - defining indexes, keys, profile types for in-memory document caching
│   │   └── process_extensions.md              # Use when: making connections, operations, or DPPs configurable per-environment via processOverrides and the Environment Extensions API
│   │
│   ├── steps/                   # Process step XML reference documentation
│   │   ├── start_step.md        # Process entry points. Use when configuring new process canvases - includes scheduled, manual, and listener API processes
│   │   ├── rest_connector_step.md    # REST API calls. Use when: calling external HTTP/REST APIs
│   │   ├── databasev2_connector_step.md # Database operations. Use when: querying/updating databases, executing SQL, working with relational data
│   │   ├── salesforce_connector_step.md # Salesforce operations (requires GUI setup). Use when: querying/updating Salesforce objects, working with CRM data
│   │   ├── boomi_for_sap_step.md    # Boomi for SAP operations. Use when: querying Core-exposed SAP objects with JSON responses, runtime parameter binding for SAP filters
│   │   ├── custom_connector_step.md # Custom SDK connectors. Use when: using connectors built with Boomi's Java Connector SDK
│   │   ├── diskv2_connector_step.md # Disk V2 file operations. Use when: reading, writing, querying, listing, or deleting files on local/network file systems
│   │   ├── mft_connector_step.md    # MFT operations. Use when: picking up or dropping off files via Boomi MFT (Thru)
│   │   ├── event_streams_steps.md   # Event Streams operations. Use when: pub/sub messaging, event-driven processing, async communication between processes
│   │   ├── agent_step.md            # AI Agent step. Use when: integrating Agent Control Tower agents into processes
│   │   ├── message_step.md      # Template engines for generating content. Use when: building payloads, creating test data, clearing documents
│   │   ├── map_step.md          # Data transformation between profiles. Use when: transforming existing structured data between different schemas
│   │   ├── set_properties_step.md # Variable creation (DDPs/DPPs). Use when: extracting values for later use, building dynamic paths, managing state, settings arbitrary variables
│   │   ├── data_process_step.md # Document manipulation and custom scripting. Use when: transforming data Maps can't handle, splitting/combining documents, encoding/compression, custom scripted logic
│   │   ├── data_process_groovy_step.md # Use when: writing Groovy scripts in Data Process steps - development philosophy, dataContext patterns, property management, critical rules
│   │   ├── decision_step.md     # Conditional routing based on comparisons. Use when: implementing if/then logic, routing based on property values or field comparisons
│   │   ├── route_step.md        # Multi-path conditional routing. Use when: routing documents to 3+ paths based on a value (switch/case), replacing chained decision steps
│   │   ├── branch_step.md       # Sequential multi-path document routing. Use when: same data needs different processing for different targets or a process should execute multiple distinct workflows
│   │   ├── process_call_step.md # Subprocess invocation and return handling. Use when: modularizing logic, enabling test mode for listener-based processes, combining documents across branches
│   │   ├── try_catch_step.md    # Error handling and exception routing. Use when: wrapping operations that may fail, implementing process-wide error handling
│   │   ├── exception_step.md   # Terminate execution with error message. Use when: failing a document or process on validation failure, unhappy-path exits from Decision/Route
│   │   ├── notify_step.md       # Debug logging with variable substitution. Use when: debugging execution flow, logging property values, logging document payloads at certain points in a process
│   │   ├── return_documents_step.md # Terminal step returning documents to caller. Use when: ending subprocess execution and returning data to parent, returning API responses
│   │   ├── fss_start_step.md    # Flow Services Server start step. Use when: creating process entry points for Flow-callable Integration processes
│   │   ├── mcp_server_start_step.md  # MCP Server entry point. Use when: creating listener processes that expose tools to AI agents via MCP protocol
│   │   ├── trading_partner_steps.md # B2B/EDI start and send shapes. Use when: building processes that receive from or send to trading partners via AS2, FTP, SFTP, etc.
│   │   ├── document_cache_steps.md # Document Cache steps (Add, Retrieve, Remove). Use when: adding documents to cache, retrieving cached documents, removing from cache, using cache lookups as parameter sources
│   │   └── shape_notes.md       # Canvas annotations visible in GUI. Use when: user explicitly requests adding documentation notes to process shapes
│   │
│   └── platform_entities/       # Platform service configuration and management
│       ├── edi_b2b.md           # B2B/EDI architecture, trading partner concepts, supported standards, acknowledgment flows, validation, communication connectors
│       ├── event_streams.md     # Topics, subscriptions, and GraphQL entity management
│       ├── boomi_for_sap.md     # Boomi for SAP architecture, scope boundaries, JSON-formatted SAP integration via Core module
│       ├── flow.md              # Boomi Flow integration: FSS deployment workflow, Flow Service components, multi-platform development (build Integration first, then Flow)
│       └── mcp_server.md          # MCP Server architecture, URL patterns, client configuration, known limitations (Technology Preview)
│
└── scripts/                       # CLI tools for development lifecycle (bash + curl + jq)
    ├── boomi-common.sh          # Shared utilities sourced by all tools
    ├── boomi-folder-create.sh   # Create organized project folders on platform
    ├── boomi-component-create.sh # Create new components and push to platform
    ├── boomi-component-push.sh  # Update existing components with local changes
    ├── boomi-component-pull.sh  # Download components with dependency resolution
    ├── boomi-deploy.sh          # Deploy components to runtime environment
    ├── boomi-test-execute.sh    # Trigger process execution via API and return execution ID
    ├── boomi-execution-query.sh # Query execution records and download logs for any process type
    ├── boomi-profile-inspect.py # Extract field metadata from large profiles (Python stdlib only)
    ├── boomi-undeploy.sh        # Remove deployments from runtime environment
    ├── event-streams-setup.sh   # Create Event Streams topics and subscriptions
    └── boomi-branch.sh         # Branch and merge operations (list, create, delete, merge, status)
```

**User Project Workspace** (separate for each project):
```
user-project/
├── .env                        # Credentials (gitignored)
└── active-development/         # All working files
    ├── processes/
    ├── profiles/
    ├── connections/
    ├── operations/
    ├── maps/
    ├── flow-services/          # Flow Service components
    ├── document-caches/
    ├── scripts/
    ├── .sync-state/            # Sync tracking
    └── feedback/               # Test results
```

Component organization follows standard folder structure (see `references/guides/cli_tool_reference.md` for component type to folder mapping).

## Development Philosophy

**Project-First Organization:**
Create dedicated Boomi platform folders for each integration/feature/API using the naming convention: `ProjectName-ShortDescription` (e.g., `JDPowerPOC-EmailNotification`, `AcmeMVP-InventorySync`). Never push components without a folder ID.

**Complete Programmatic Development:**
- Implement ALL steps programmatically (Set Properties, Maps, REST connectors, Decision, Process Components)
- Read `references/` documentation BEFORE writing code
- Fix XML structure when errors occur rather than escalating to GUI
- Use GUI only for true platform limitations: OAuth user authorization grant flows, metadata refresh, branded connector initial import
- Out-of-scope or undocumented types: Follow escalation framework in `references/guides/problem_solving_guide.md`

**Key Boomi Concepts** (from `BOOMI_THINKING.md`):
- Documents flow sequentially through steps (pipeline model)
- Steps = canvas instances, Components = reusable definitions
- Profile-first development: create profiles before referencing fields
- Push-as-you-go: create → push → use generated IDs for next component
- Properties (DDP/DPP) carry data through process
- Complex projects: wireframe first, then incrementally add/update steps (push after each)

## Critical Boomi Issues
Boomi has several silent failure patterns that are critical to understand. These don't throw errors but produce wrong behavior. **Read `references/guides/boomi_error_reference.md` early in any troubleshooting effort** — most debugging dead-ends trace back to a known issue.

**Most Critical Patterns:**
1. **Message step Quote Escaping with a JSON body** - Use `"'{1}'"` not `"{1}"` in JSON - single quotes toggle curly-brace {} variable substitution mode. Example valid message shape content with JSON: `'{"example":"'{1}'"}'`. Message steps without JSON don't generally require this toggle.
2. **Environment Variables Don't Work** - XML components need actual credential values, not `${ENV_VAR}` references
3. **Parent-Subprocess Deployments** - Must redeploy parent after updating subprocess to pick up changes

**Quick diagnostic:** Variables appearing literally? → Issue #1. API auth failures? → Issue #2. Subprocess changes ignored? → Issue #3.

## Core Development Workflow

### Component Lifecycle: Prefer Existing Over New
**Decision Framework:**
1. **Connections**: Resolve via connection discovery workflow first (see § Connection Discovery above)
2. **Other components**: Check for existing components to update/reuse before creating new ones
3. Update when possible: Use push/pull workflow for existing components
4. Create only when necessary: New components only when genuinely needed
5. Consolidate, don't duplicate: Enhance existing similar components

See `references/guides/cli_tool_reference.md` for workflow selection and command syntax.

### Pulling Components with Dependencies
When user provides component ID or platform URL: Pull the component, scan for dependencies, pull missing ones recursively. See `references/guides/pulling_components.md` for complete workflow.

**XML Modification Philosophy:**
- Leave pulled XML as-is (if platform accepted it, it's valid)
- Create new components using minimal format from templates
- Don't normalize existing verbose XML

## Architecture and Key Concepts

**Local-First Development Model:**
1. **Local Development**: Create/edit XML files in `active-development/` folder
2. **Platform Sync**: CLI tools handle bi-directional sync with Boomi platform
3. **State Tracking**: `.sync-state/` maintains component IDs, versions, conflict detection
4. **Testing Integration**: Integrated deployment, execution, result polling, log extraction
5. **Knowledge Base**: `references/` contains patterns and templates

**Sync State Management:**
The `.sync-state/` directory tracks component synchronization (IDs, versions, conflict detection). Managed automatically by CLI tools—never manually edit.

**CLI Tools:**
Ten specialized tools handle development lifecycle. All tools are bash scripts (except profile-inspect which is Python stdlib). They require `curl` and `jq` and source credentials directly from `.env` — no Python dependencies, no virtual environments.

- `boomi-folder-create.sh` - Create project folders on platform
  - Required: `folder_name` (positional)
  - Optional: `--parent-folder-id`, `--test-connection`

- `boomi-component-create.sh` - Create new component on platform (generates component ID)
  - Required: `file_path` (positional)
  - Optional: `--branch`, `--test-connection`

- `boomi-component-push.sh` - Update existing component on platform
  - Required: `file_path` (positional)
  - Optional: `--branch`, `--test-connection`

- `boomi-component-pull.sh` - Download component from platform to local
  - Required: `--component-id`
  - Optional: `--branch`, `--target-path`

- `boomi-deploy.sh` - Deploy process to runtime environment
  - Required: `file_path` (positional)
  - Optional: `--deployment-notes`, `--list-environments`
  - Auto-detects branch from XML/sync state and warns before deploying branch components

- `boomi-branch.sh` - Branch and merge operations (only for Branch & Merge enabled accounts)
  - `list` — list all branches
  - `create --name NAME --parent NAME` — create branch from parent
  - `delete --branch NAME_OR_ID` — delete a branch
  - `merge --source NAME --dest NAME [--strategy OVERRIDE|CONFLICT_RESOLVE]` — create merge request
  - `merge-status --id ID` — check merge request status and component details
  - `merge-execute --id ID` — execute a pending merge
  - `merge-revert --id ID` — revert a completed merge (permanent)
  - `merge-delete --id ID` — cancel a pending merge request

- `boomi-undeploy.sh` - Remove deployments from a runtime environment
  - Modes: `<deploymentId>` (direct removal), `--by-component <file_path>` (lookup and remove via component file)

- `boomi-test-execute.sh` - Trigger process execution via API and return execution ID
  - Required: `--process-id`
  - Optional: `--test-data`, `--no-wait`

- `boomi-execution-query.sh` - Query execution records and download logs for any process type
  - Optional: `--process-id`, `--status`, `--since`, `--limit` (default 3)
  - Log download: `--execution-id <id> --logs`

- `boomi-profile-inspect.py` (Python stdlib) - Extract field inventory from large profiles (XML, EDI, Flat File)
  - Required: `profile_path` (positional)
  - Use when: A profile file is too large to read directly. Outputs searchable JSON to `active-development/profiles/distilled_<name>.json`
  - Python stdlib only — no pip dependencies

- `event-streams-setup.sh` - Create and manage Event Streams topics, subscriptions, and tokens
  - Commands: `query-tokens`, `create-token <name>`, `create-topic <name>`, `create-subscription <topic> <name>`, `query-topic <name>`

The CLI tools reside in the skill's `scripts/` directory (i.e. at the same level from which the SKILL.md file is being read). They are not in a given active development workspace.

See `references/guides/cli_tool_reference.md` for workflows, error recovery, and usage patterns.

Re-use existing connections (see § Connection Discovery above). Component XML requires actual credential values, not environment variables. See `references/guides/cli_tool_reference.md` for patterns.

**Environment Variables:**
Required for building and testing. Full setup in `references/guides/user_onboarding_guide.md`.
- Platform API: `BOOMI_API_URL`, `BOOMI_USERNAME`, `BOOMI_API_TOKEN`, `BOOMI_ACCOUNT_ID`, `BOOMI_ENVIRONMENT_ID`, `BOOMI_TEST_ATOM_ID`, `BOOMI_VERIFY_SSL`, `BOOMI_TARGET_FOLDER`
- Shared Web Server: `SERVER_BASE_URL`, `SERVER_USERNAME`, `SERVER_TOKEN`, `SERVER_VERIFY_SSL` - used for WSS testing and **FSS connectivity** (see `references/guides/process_testing_guide.md`, `references/platform_entities/flow.md`)

## Development Patterns

### Push-as-You-Go Workflow (Recommended)
1. Create component locally → Push immediately → Verify sync state
2. Read `.sync-state/` for generated component IDs
3. Update dependent components with actual GUIDs
4. Repeat for next component

**Dependency order (per section):** When a step needs a component, create its dependencies first: profiles → connections → operations → then the step.

**Complex processes:** Create wireframe with placeholder steps first, push, then incrementally update step-by-step (push after each).

**Anti-pattern:** Creating many components locally before pushing causes "big bang" sync failures.

### Web Services Listener Pattern
Complete guidance in `references/guides/api_conversion_patterns.md`. Quick decisions:
- Converting existing process to API? → Wrap it
- Building new API endpoint? → Wrapper + subprocess pattern
- Deployment issues? → Check atom type compatibility

### Iterative Development Workflow

**Default: Push for Review**
Load `BOOMI_THINKING.md` + relevant references → Create/modify XML → Verify Message/Notify quote escaping → Push.

**Full Deploy & Test**
**REQUIRED: Read `references/guides/process_testing_guide.md` before running any tests.** The testing workflow has critical constraints that affect how you approach testing different process types.

When you need to test a process: Push → Deploy (`boomi-deploy.sh`) → Wait 10-15s → Execute tests → Analyze results.

**Critical ExecutionRequest Limitation:** The Boomi API cannot inject document payloads into process executions. The `--test-data` flag is for Process Properties only (rarely used). Injecting test payloads is best achieved with message set properties steps in the process canvas. 

Review references/guides/process_testing_guide.md for more info about methods and techniques to work with test payloads.

**Testing Philosophy**
- Projects vary - simple one-shots may not need testing; interactive sessions where users test in GUI don't require your testing.
- When working autonomously on end-to-end projects, test frequently: build a section → add Notify steps to log outputs → deploy → run → review logs.
- When building a listener process, test via curl to the WSS endpoint (see `references/guides/process_testing_guide.md` for URL construction).
- When testing subprocess logic in isolation, you can add a temporary Message step with test payload at the start.

**Push vs Deploy:** Push = design-time update (GUI visible, not executable). Deploy = runtime update (executable, required for testing).

**Handling Validation Errors:**
Read error → Check `references/steps/` documentation → Compare with examples → Fix XML → Retry. Common issues: wrong shapetype, wrong configuration element, missing attributes (see `references/guides/boomi_error_reference.md` Issue #8).

For situations beyond validation errors — unknown components, unexpected API behavior, undocumented features — see `references/guides/problem_solving_guide.md`.

### Critical Deployment Pattern
**Parent-Subprocess Dependency:** When updating subprocesses, ALWAYS redeploy parent to pick up changes. The parent deploy includes the subprocess — deploying the subprocess alone will not cause the parent to reflect those changes.

```bash
# 1. Update subprocess
bash scripts/boomi-component-push.sh subprocess.xml

# 2. CRITICAL: Redeploy parent
bash scripts/boomi-deploy.sh parent-wrapper.xml

# 3. Test
```

**Exception — Standalone subprocess testing or execution:** When testing a subprocess in isolation via `boomi-test-execute.sh` (not through its parent), the subprocess must be deployed independently. The runtime will otherwise rn a stale version that doesn't reflect recent pushes unless the subprocess itself is deployed.

This also applies to designs where a subprocess may either run independentely or be called by a parent - in that scenario also the subprocess must be deployed independently in addition to deploying the parent process.

```bash
# Isolated subprocess testing
bash scripts/boomi-component-push.sh subprocess.xml
bash scripts/boomi-deploy.sh subprocess.xml  # Required for standalone execution
bash scripts/boomi-test-execute.sh --process-id <subprocess-guid>
```

See `references/guides/boomi_error_reference.md` Issue #3 for details.

### Folder Management & Component Creation
**Organization Hierarchy:**
- Root → ClaudeCode (`BOOMI_TARGET_FOLDER`) → Project-Specific → Components
- **ALL components MUST go into organized folders**, never create components into the account root
- Create project folders using naming convention: `ProjectName-ShortDescription`
- Example: `bash scripts/boomi-folder-create.sh "JDPower-EmailNotification"`

**Component Creation Workflow:**
```bash
# 1. Create project folder with proper naming convention
bash scripts/boomi-folder-create.sh "Acme-MVP-WeatherAPI"
# Returns: folder_abc123def

# 2. Create components with folderId in XML (push after each to get IDs for dependencies)
bash scripts/boomi-component-create.sh active-development/profiles/profile.xml
```

**Folder Naming Convention:**
Format: `ProjectName-ShortDescription`
- Examples: `JDPower-EmailNotification`, `TechCorp-OrderSync`, `Acme-APIShowcase`

**Critical Requirements:**
- Use actual folder GUID in `folderId` attribute (not `folderFullPath`)
- Use descriptive names: `SystemName_Action_Type` (e.g., `Petstore_GetPet_Response_JSON_Profile`)
- Keep componentId and version as empty strings for CREATE operations
- Reference templates in `references/components/`

See `references/guides/boomi_error_reference.md` Issue #7 for folder placement verification.

**Handling Blocked Dependencies:**
When dependencies are unavailable (missing credentials, GUI-required components, API access pending), use placeholder pattern: Create named placeholder step → Add parallel test Message step with mock data → Route both to downstream logic → Replace placeholder when dependency available. Inform user of blocking issue.

**GUI-Required Components:** OAuth flows (browser authorization) and branded connectors (Salesforce, NetSuite - metadata import) require GUI for initial setup. For all connections, follow the connection discovery workflow (see § Connection Discovery above) — re-use existing connections or have the user create new ones in the GUI. Once pulled, preserve encrypted values exactly during subsequent pull/push cycles.

### Step Addition Workflow
**ALWAYS read `references/steps/[step_type].md` completely before writing XML.**

**Sequential Process:**
1. Read complete step documentation (study reference examples)
2. Create required dependencies for this step (profiles, connections, operations as needed)
3. Follow exact XML structure from documentation
4. Validate before push
5. Read sync state and update dependent component references

**Common XML Mistakes** (see `references/guides/boomi_error_reference.md` Issue #8):
- Set Properties: Use `shapetype="documentproperties"` NOT `"setproperties"`
- Map step: Simple `<map mapId="guid"/>` with no child elements
- Missing display attributes: Include `name` and `propertyName` for GUI

## Reference

**Boomi Terminology:**
- **Steps** = Canvas elements (formerly "shapes")
- **Components** = Reusable definitions referenced by steps
- **Documents** = Data chunks flowing through process
- **DDP** = Dynamic Document Property (per-document variable)
- **DPP** = Dynamic Process Property (process-wide variable)

**Authentication:**
- API Token format: `BOOMI_TOKEN.{username}`
- Credentials: Username + API token (not password)

**Deployment:**
- Always use environment IDs (GUIDs), not environment names

**Development Guidelines:**
- Never manually edit sync state files
- Build processes elegantly and simply (visually interpretable by moderately-tenured Boomi developers)
- Avoid convoluted scripting when simpler approaches exist
- If user makes GUI changes, re-pull component before editing
