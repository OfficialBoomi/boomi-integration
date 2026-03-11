# Boomi Implementation Patterns

This document provides tactical implementation blueprints for common Boomi integration scenarios. These are proven architectural recipes that solve recurring problems.

## Contents
- API Integration Patterns
- Event Streams Patterns
- Multi-Target Distribution
- Debugging and Testing Strategies
- Web Services Listener Architecture
- Profile Reuse Strategies

## API Integration Pattern

Standard pattern for calling external REST APIs and processing responses.

**Implementation Blueprint:**
1. Start step (WSS listener or No Data)
2. Try-Catch wrapper (right after start)
3. [Try] Message step to build request body
4. [Try] HTTP connector step (connection + operation components)
5. [Try] JSON/XML profile for response structure
6. [Try] Set Properties to extract key values
7. [Try] Map step to transform for next system
8. [Try] Stop or Return Documents
9. [Catch] Notify step with error details + Stop

**When to use**: Any external API call requiring error handling and response transformation.

## Event Streams Patterns

### Event Streams Listener Pattern

Standard pattern for consuming messages from Event Streams topics.

**Implementation Blueprint:**
1. Start step (Event Streams Listen operation)
2. Try-Catch wrapper
3. [Try] Process incoming message
4. [Try] Transform/enrich data (Map, Set Properties, connectors)
5. [Try] Route to target systems or Produce to another topic
6. [Try] Stop (listener continues running for next message)
7. [Catch] Notify step with error details + Stop

**When to Use Listen vs Consume:**
- **Listen**: Process launches automatically on message arrival (event-driven, most common)
- **Consume**: Process retrieves messages on-demand (scheduled/mid-process pull, batch control)

### Event Streams Development Workflow (New Integrations)

**Step-by-step component creation:**
1. Query existing topics - reuse if found, create via GraphQL if needed (eventStreamsTopicCreate)
2. Query existing subscriptions - reuse if found, create via GraphQL if needed (eventStreamsSubscriptionCreate)
3. Query existing environment tokens - reuse appropriate token or create if needed (eventStreamsTokenCreate)
4. Check for existing connection/operation components - reuse where possible
5. Create new connection component with environment token (if needed)
6. Create new operation components referencing topics/subscriptions (if needed)
7. Build Integration process with Event Streams connector steps

**Note**: For pulled components with encrypted environmentToken, preserve encrypted values exactly as-is (standard credential management pattern).

## Multi-Target Distribution Pattern

Standard pattern for sending same data to multiple systems with system-specific transformations.

**Implementation Blueprint:**
1. Start step
2. Branch step
3. [Branch 1] Profile + Map + Connector for System A + Stop
4. [Branch 2] Profile + Map + Connector for System B + Stop
5. Each branch completely independent - Branch 2 initiates after Branch 1 finishes

**When to use**: Single data source feeding multiple target systems with different schemas/formats.

**Key architectural note**: Branches execute sequentially, not in parallel. Each branch receives copy of input document.

## Debugging and Testing Strategies

### Strategic Notify Placement

Essential debug points during development:
- After Message steps - verify payload construction
- After Connector calls - capture response for profile creation
- Before failing connectors - debug input payload
- After Set Properties - validate DDP/DPP values

**Pattern**: Notify steps = your console.log()

### Debugging with Notify Steps

Add Notify steps after Message steps, connector calls, Set Properties steps to validate behavior during development. Use `valueType="current"` for document content, `valueType="track"` for DDPs.

**Critical gotchas**: Notify steps have IDENTICAL quote escaping issues as Message steps with single-quote toggle for curly-brace substitution (see references/guides/boomi_error_reference.md Issue #1 for comprehensive patterns). Parameter keys are 1-based: key="1", key="2" (not 0-based).

**Production cleanup**: Remove test payloads or re-route around them intelligently before deployment.

### Debugging Strategy Reminders

- Notify steps can show document content, properties, metadata
- Always include on Catch paths for error visibility
- Place strategically to see document state at critical points
- Remove or bypass for production deployments

## Web Services Listener Architecture

### API Conversion: Reuse, Don't Recreate

**When converting existing processes to APIs**: Keep existing process as subprocess, create minimal WSS wrapper. Change `<stop continue="true"/>` to `<returndocuments/>` in existing process, reference it via Process Call step.

### Recommended Wrapper + Subprocess Structure

**Implementation Blueprint:**
```
WSS Listener Process (Wrapper):
├── 1. WSS Start step with 'listen' action
├── 2. Process Call step → Main Business Logic Subprocess
└── 3. Return Documents step (uses WSS response profile)

Main Business Logic Subprocess:
├── 1. Start step (passthroughaction)
├── 2-N. [Business logic: maps, connectors, transforms, etc.]
└── N+1. Return Documents step
```

### Architecture Benefits

- **Testability**: Main business logic remains testable via standard platform tools
- **Modularity**: Business logic can be developed and debugged independently
- **Separation of concerns**: HTTP/routing logic separate from business transformation logic
- **Reusability**: Business logic subprocess can be called from multiple wrappers

### Critical Testing Pattern

- **WSS Wrapper Process**: Test via direct HTTP calls to shared web server (not boomi-test-execute.sh)
- **Business Logic Subprocess**: Test via boomi-test-execute.sh and GUI test mode
- **Why subprocess matters**: WSS listeners cannot be tested with platform execution tools - they expect HTTP requests

**Critical design requirement:** Subprocess MUST use passthrough start configuration to receive parent documents.

### Subprocess Isolated Testing - Data Dependency Pattern

**Challenge**: When testing subprocess in isolation (via boomi-test-execute.sh or GUI), subprocess expects input document from parent wrapper but has no data source.

#### Solution 1 - Temporary Test Message Shape

**Pattern:**
- Add Message shape at subprocess start with test JSON/XML payload
- Message shape mimics expected JSON/XML structure from WSS request
- Test subprocess with synthetic data
- **Remove Message shape before production deployment**

**When to use**: Quick testing during development, simpler implementation

#### Solution 2 - Dynamic Routing for Permanent Testability

**Pattern:**
1. Parent wrapper: Add Set Properties step setting `DPP_FROM_WRAPPER=true`
2. Subprocess: Start with Decision step checking if `DPP_FROM_WRAPPER` exists
3. Path when DPP present (called from parent) → proceed to business logic
4. Path when DPP absent (isolated testing) → Message shape with test payload → business logic
5. Subprocess remains permanently testable without removing test code

**When to use**: Subprocess needs ongoing isolated testing in a long term project, prevents forgotten test code

**CRITICAL VALIDATION**: Before production deployment, verify test Message shapes or static test properties have been removed (Solution 1) OR test parent-to-subprocess flow uses real data path, not test path (Solution 2).

## Profile Reuse Strategies

### Profile Reuse in Wrapper + Subprocess Pattern

**CRITICAL PRINCIPLE**: Same structure = reuse profile. Different structure = new profile.

### Common Scenario - Subprocess Connector Calls

- WSS wrapper has `request` and `response` profiles defining API JSON structure
- Subprocess needs to make connector call with same JSON structure
- **CORRECT**: Subprocess connector operation references existing WSS request profile
- **WRONG**: Creating duplicate "subprocess_request_profile" with identical structure

### When to Reuse Profiles

- Subprocess Set Properties step extracting fields → use WSS request profile
- Subprocess Map step transforming inbound data → source = WSS request profile
- Subprocess connector POST/PUT using same JSON → reuse WSS request profile
- Any operation working with same data structure → reuse existing profile

### When to Create New Profiles

- External API has different JSON structure than WSS endpoint
- Response from connector differs from WSS request/response
- Transformation target has unique structure

**Benefits**: Fewer components, consistent validation, easier maintenance, MVP compliance through maximum reuse.
