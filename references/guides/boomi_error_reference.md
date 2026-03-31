# Boomi Error Reference

A comprehensive guide to Boomi error patterns, silent failures, and issues that don't throw errors but cause wrong behavior. **Read this early in any troubleshooting effort** - most Boomi debugging dead-ends trace back to one of these known issues.

**When to use this guide:**
- Variables appearing literally in output instead of being substituted
- Deployments that don't seem to update runtime behavior
- API authentication failures with no error messages
- Components landing in wrong folders despite configuration

---

## Quick Diagnostic Guide

**Symptoms → Likely Issue:**

| Symptom | Check Issue # |
|---------|----------------|
| Variables appear literally in output | #1 (Quote Escaping) |
| API authentication failures (no error) | #2 (Environment Variables) |
| Subprocess updates not taking effect | #3 (Deployment Dependency) |
| Map output ignored by connector | #4 (Connector Parameters) |
| GET request errors with body | #5 (REST GET Clearing) |
| Documents flowing but content lost | #6 (Profile Type Trap) |
| Components in wrong folder | #7 (Folder Placement) |
| XML validation errors during push | #8 (Schema Mistakes) |
| Stack overflow in map editor | #9 (Map Function Attributes) |
| GUI label overlap | #10 (Layout Spacing) |
| "null" displays in GUI | #11 (Display Attributes) |
| Test data in production | #12 (Test Payloads) |
| SSL certificate verification errors | #13 (SSL Verification) |
| Blank canvas in GUI (JavaScript error) | #14 (Branch numBranches) |
| Stack overflow opening process in GUI | #15 (Stop continue Attribute) |
| Empty action picklist in WSS operation | #16 (WSS actionType) |
| Script engine null error in Data Process | #17 (Groovy Attributes) |
| "No document" error with perExecution | #18 (Notify perExecution) |
| WSS requests hitting wrong process | #19 (Listener Path Collision) |
| MCP tool schema changes not applied | #20 (MCP Profile/Schema Sync) |
| MCP 503 after valid token auth | #21 (MCP 503 After Valid Auth) |
| EDI map producing split/duplicate documents | #22 (EDI TagList elementKey Target) |
| White screen opening SF operation in GUI | #28 (SF Operation Missing Sorts Element) |
| Extension values lost after push/deploy | #23 (Empty processOverrides) |
| DPP value always empty despite being set | #24 (DPP valueType="track") |
| MANDATORY_ELEMENT_MISSING on map output with identity fields | #25 (Identity Field Mandatory) |
| Record silently missing from multi-record flat file output | #26 (Identity Value Trimming) |
| "No data produced from map" on data positioned profile | #26 (Identity Value Trimming) |
| HTTP 500 on concurrent listener requests / listener queuing | #27 (Listener Process Options) |

---

## Quick Reference Index

| # | Issue | Frequency | Detection |
|---|--------|-----------|-----------|
| 1 | Message/Notify Quote Escaping | Very High | Silent - wrong output |
| 2 | Environment Variables in Component XML | High | Silent - auth failures |
| 3 | Parent-Subprocess Deployment Dependency | High | Silent - old behavior |
| 4 | Connector Parameters Override Document Content | Medium | Silent - data ignored |
| 5 | REST GET Document Clearing | Medium | Runtime error |
| 6 | REST Connector Profile Type Trap | Medium | Silent - document loss |
| 7 | Folder Placement Verification | High | Design-time visibility |
| 8 | Common XML Schema Mistakes | High | Design-time validation |
| 9 | Map Function GUI Requirements | Low | GUI rendering error |
| 10 | Process Layout Spacing | Low | GUI label overlap |
| 11 | GUI Display Attributes | Low | "null" displays in GUI |
| 12 | Subprocess Test Payloads in Production | Medium | Silent - wrong data source |
| 13 | SSL Certificate Verification in Testing | Medium | Runtime connection failures |
| 14 | Branch Step Missing numBranches Attribute | Medium | GUI rendering error - blank canvas |
| 15 | Stop Step Missing continue Attribute | Medium | GUI rendering error - stack overflow |
| 16 | WSS Start Step Invalid actionType | Medium | GUI rendering error - empty action picklist |
| 17 | Data Process Script Engine Attributes | Medium | Runtime error - cryptic null error |
| 18 | Notify perExecution="true" Loses Document Context | Medium | Runtime error - "no document" |
| 19 | WSS Listener Path Collision | Medium | Silent - wrong process handles requests |
| 20 | MCP Server Profile/Schema Sync | High | Silent - old validation rules active |
| 21 | MCP Server 503 After Valid Auth | Medium | Runtime error - 503 after auth |
| 22 | EDI TagList elementKey Target | High | Runtime - split documents or silent data loss |
| 23 | Empty processOverrides Destroys Extensions | High | Silent - extension values lost |
| 24 | DPP valueType="track" Returns Empty | High | Silent - empty string instead of value |
| 25 | Identity Field mandatory="true" on Map Output | High | Runtime error - MANDATORY_ELEMENT_MISSING |
| 26 | Identity Value Trimming in Data Positioned Profiles | High | Silent - record missing from output / ERROR if only record |
| 27 | Listener Process with Default Process Options | High | Silent - queuing/rejection of concurrent requests |

---

## Issue #1: Message/Notify Quote Escaping

**Frequency:** Very High (Most common issue in Boomi development)
**Detection:** Silent failure - produces literal output instead of variable substitution

### The Problem

Message and Notify steps fail to substitute variables, outputting literal `{1}` instead of actual values. No errors are thrown - output is just wrong.

### Why It Happens

Single quotes toggle between literal mode and variable substitution. Inside single quotes, variables are literal text. GUI auto-escapes; programmatic generation doesn't.

### Wrong Patterns - Variables Appear Literally

```xml
<!-- Pattern 1: Full JSON wrapped in quotes, variables remain in literal mode -->
<msgTxt>'{
  "status": "{1}",
  "result": "{2}",
  "data": {3}
}'</msgTxt>
<!-- OUTPUT: {"status": "{1}", "result": "{2}", "data": {3}} ← Variables NOT substituted! -->
```

### Correct Patterns - Variables Get Substituted

```xml
<!-- Pattern 1: Toggle quotes around each variable -->
<msgTxt>'{
  "status": "'{1}'",
  "result": "'{2}'",
  "data": '{3}'
}'</msgTxt>
<!-- OUTPUT: {"status": "success", "result": "completed", "data": {...}} ← Variables substituted! -->

<!-- Pattern 2: XML doesn't depend on {} so requires no toggling -->
<msgTxt><?xml version="1.0"?>
<customer>
  <email>{1}</email>
</customer></msgTxt>
<!-- OUTPUT: <?xml version="1.0"?><customer><email>test@email.com</email></customer> ← Variables substituted! -->

<!-- Pattern 3: No quotes for simple substitution -->
<msgTxt>Processing order {1} for {2}</msgTxt>
<!-- OUTPUT: Processing order 12345 for ABC Corp ← Variables substituted! -->
```

### Quote Toggle Mechanics

- **Default mode**: Variables like `{1}` get substituted
- **Single quote enters literal mode**: No substitution until next quote
- **Single quote exits literal mode**: Back to variable substitution
- **Literal single quote**: Use two single quotes (`''`) to output one quote
- **Critical Pattern**: `'literal text '{variable}' more literal '{variable2}' end'`

### Copy-Paste Templates (Working Patterns)

**JSON API Response:**
```xml
<msgTxt>'{
  "id": "'{1}'",
  "status": "'{2}'",
  "timestamp": "'{3}'",
  "data": '{4}'
}'</msgTxt>
```

**JSON Error Response:**
```xml
<msgTxt>'{
  "error": "'{1}'",
  "message": "'{2}'",
  "timestamp": "'{3}'"
}'</msgTxt>
```

**XML Output:**
```xml
<msgTxt><order>
  <id>{1}</id>
  <status>{2}</status>
  <customer>{3}</customer>
</order></msgTxt>
```

### Pre-Push Checklist

Before pushing Message/Notify steps: Scan for `"{1}"` inside single quotes → Verify quote toggles `"'{1}'"` 

### Affected Steps

- Message steps (`shapetype="message"`)
- Notify steps (`shapetype="notify"`)
- Set Properties (different syntax)
- Map steps (different templating system)

---

## Issue #2: Environment Variables in Component XML

**Frequency:** High
**Detection:** Silent - API authentication failures with no design-time warnings

### The Problem

Environment variable references like `${APPLICATION_API_KEY}` are stored literally in component XML, causing API calls to fail with authentication errors despite appearing correctly configured.

### Why It Happens

**Project tools DO NOT currently perform variable substitution on XML files** - they read and send component XML as-is to the Boomi platform. The Boomi platform has no access to your local environment variables.

### Wrong Pattern - Causes Silent API Authentication Failures

```xml
<staticparameter staticproperty="${APPLICATION_API_KEY}"/>
```
**RESULT**: Platform stores the literal string `${APPLICATION_API_KEY}` → API calls fail with authentication errors → No design-time warnings

### Correct Pattern - Working API Authentication

```xml
<staticparameter staticproperty="demo-sk-abc123..."/>
```
**RESULT**: Platform executes with actual credential value → API calls succeed

### Critical Rule: No Variable References in XML Components

- **XML Component Files**: Must not contain `${ENV_VAR}` or other variable references — Boomi has no access to local environment variables
- `{ComponentName}` → **Local XML ONLY** (resolved by agent orchestration during creation)

### Connection Workflow

See `BOOMI_THINKING.md` § Connection Discovery and `cli_tool_reference.md` § Credential Management for the full connection resolution and credential handling workflows.

### Pre-Push Checklist

Before pushing ANY component with credentials:
1. Search for `${...}` patterns in connection/operation XML files — remove any variable references
2. Verify `type="password"` fields are not populated with real credentials
3. Never commit real credentials to version control

---

## Issue #3: Parent-Subprocess Deployment Dependency

**Frequency:** High (Most blocking deployment issue)
**Detection:** Silent - old behavior persists despite updates

### The Problem

Parent processes snapshot subprocess versions at deployment time. Updating/deploying a subprocess does NOT automatically update parent processes that reference it.

**Real-World Symptoms:**
- HTTP endpoints return old responses despite subprocess changes
- Process Call steps execute outdated logic
- Platform test tool shows new subprocess behavior, but WSS wrapper shows old behavior
- Multiple "fixes" that don't seem to work (because parent wasn't redeployed)

### Why It Happens

Deploy parent → Runtime captures subprocess v1 → Update subprocess → v2 deployed → Parent still executes v1 (silent failure). Parent deployment creates snapshot; runtime doesn't auto-update dependencies.

### Wrong Pattern - Subprocess Updates Ignored

```bash
# 1. Update subprocess
bash scripts/boomi-component-push.sh subprocess.xml
bash scripts/boomi-deploy.sh subprocess.xml

# 2. Test parent process
curl -X POST "${SERVER_BASE_URL}/ws/simple/endpoint"
# ← Still executes OLD subprocess version!
```

### Correct Pattern - Parent Picks Up Subprocess Changes

```bash
# 1. Update subprocess
bash scripts/boomi-component-push.sh subprocess.xml
# Subprocess does not need to be deployed independently

# 2. CRITICAL: Redeploy parent to pick up subprocess changes
bash scripts/boomi-deploy.sh parent-wrapper.xml

# 3. Wait for propagation (10-15 seconds)
sleep 15

# 4. Now test - parent will use updated subprocess
curl -X POST "${SERVER_BASE_URL}/ws/simple/endpoint"
```

### Pre-Deployment Checklist

When updating subprocesses:
1. Push subprocess updates to platform
2. **Repackage and redeploy parent** (required to pick up subprocess changes)
3. Wait 10-15s for propagation
4. Test parent process

**Applies to ALL component references**: Process Call steps, Map components, Profile references.

**Exception — Standalone subprocess testing**: When testing a subprocess in isolation via `boomi-test-execute.sh` (not through its parent), you must deploy the subprocess independently. The parent deploy rule above applies when testing through the parent; standalone execution requires its own deployment to pick up latest pushes.

---

## Issue #4: Connector Parameters Override Document Content

**Frequency:** Medium
**Detection:** Silent - document content reaching the connector step is ignored

### The Problem

Parameters configured on connector steps override document content - they don't merge. Document content is completely ignored when connector parameters are set.

**Example:** Salesforce Update with Id parameter ignores document payload from Map step.

### Why It Happens

Connector steps have two ways to provide data:
1. **Document content** - data from upstream Map/Message steps
2. **Connector parameters** - configured directly on connector step

When both are present, **parameters win completely** - document content is ignored.

### Wrong Pattern - Document Content Ignored

```xml
<!-- Map step builds complete payload including Id field -->
<map mapId="guid-for-salesforce-map"/>

<!-- Connector step also has Id parameter configured -->
<salesforce connectionId="conn-guid" operationId="op-guid">
  <dynamicProperties>
    <propertyvalue childKey="Id" key="recordFields" valueType="track">
      <trackparameter propertyId="dynamicdocument.DDP_RECORD_ID"/>
    </propertyvalue>
  </dynamicProperties>
</salesforce>
<!-- Result: Map output IGNORED, only DDP_RECORD_ID is sent (other fields missing!) -->
```

### Correct Patterns

**Solution Pattern A - Document-Only (Preferred for complex payloads):**
```xml
<!-- Map step builds complete payload including all fields -->
<map mapId="guid-for-salesforce-map"/>

<!-- Connector step with NO parameters - uses document content -->
<salesforce connectionId="conn-guid" operationId="op-guid">
  <!-- No dynamicProperties - document flows through normally -->
</salesforce>
```

**Solution Pattern B - Parameters-Only:** Set ALL fields via connector parameters (no Map step needed).

### Pre-Push Checklist

Decide: document-only OR parameters-only (never both). Test to verify complete payload sent.

---

## Issue #5: REST GET Document Clearing Pattern

**Frequency:** Medium
**Detection:** Runtime error or unexpected behavior

### The Problem

REST GET requests should not send document content, but they inherit documents from upstream steps. This can cause execution errors or unexpected API behavior.

### Why It Happens

REST GET connectors:
- Should send only query parameters, no request body
- Inherit document content from previous steps in process flow
- Platform may attempt to send inherited document as request body
- Some APIs reject GET requests with body content

### Wrong Pattern - Inherited Document Causes Issues

```xml
<!-- Message step creates document -->
<message combined="false">
  <msgTxt>{"search": "criteria"}</msgTxt>
</message>

<!-- REST GET inherits document content -->
<connector connectionId="conn-guid" operationId="get-op-guid">
  <!-- GET request may fail due to unexpected body content -->
</connector>
```

### Correct Pattern - Clear Document Before GET

```xml
<!-- Message step creates document for other purposes -->
<message combined="false">
  <msgTxt>{"search": "criteria"}</msgTxt>
</message>

<!-- Empty Message step clears document content -->
<message combined="false">
  <msgTxt></msgTxt>
  <msgParameters/>
</message>

<!-- REST GET connector with clean slate -->
<connector connectionId="conn-guid" operationId="get-op-guid">
  <!-- No document content, only query parameters work correctly -->
</connector>
```

### When to Use

- Before any REST GET connector that doesn't need request body data
- When upstream steps create document content that shouldn't be sent to GET endpoint
- To prevent "request body not allowed" type errors from APIs

### Pre-Push Checklist

For REST GET: Check upstream creates content → Add empty Message step before GET if needed.

---

## Issue #6: REST Connector Profile Type Trap

**Frequency:** Medium
**Detection:** Silent - document flow continues but content is corrupted

### The Problem

REST connector operations in Boomi GUI do NOT support `requestProfileType` or `responseProfileType` attributes despite what some documentation suggests. Including these attributes causes silent document content loss.

### Why It Happens

Connector reports success, logs show documents flowing, but content is lost/corrupted. No design-time errors - fails silently at runtime.

### Wrong Pattern - Silent Document Loss

```xml
<!-- CAUSES SILENT DOCUMENT FLOW FAILURES -->
<GenericOperationConfig customOperationType="GET"
                        operationType="EXECUTE"
                        requestProfileType="none"
                        responseProfileType="json">
```

### Correct Pattern - No Profile Type Attributes

```xml
<!-- CORRECT: No profile type attributes -->
<GenericOperationConfig customOperationType="GET"
                        operationType="EXECUTE">
```

### Pre-Push Checklist

Remove `requestProfileType` and `responseProfileType` attributes. Use Map/Set Properties for response parsing instead.

---

## Issue #7: Folder Placement Verification

**Frequency:** High
**Detection:** Design-time visibility (components appear in wrong folder)

### The Problem

Components land in account root folder instead of designated project folder despite configuration. No errors are thrown - components just appear in wrong location.

### Why It Happens

**Common causes:**
- Using `folderFullPath` instead of `folderId` attribute in XML
- Folder ID placeholder patterns (`{FOLDER_GUID}`) not resolved before API call
- Environment variable `BOOMI_TARGET_FOLDER` not resolving correctly
- Tool folder resolution logic issues

### Wrong Patterns

```xml
<!-- Pattern 1: Using folderFullPath instead of folderId -->
<bns:Component componentId=""
               name="Component_Name"
               type="profile.json"
               folderFullPath="ClaudeCode/ProjectFolder">
<!-- Result: Component lands in root folder -->

<!-- Pattern 2: Placeholder not resolved -->
<bns:Component componentId=""
               name="Component_Name"
               type="profile.json"
               folderId="{FOLDER_GUID}">
<!-- Result: Literal string "{FOLDER_GUID}" sent to API, lands in root -->

<!-- Pattern 3: Empty folder ID -->
<bns:Component componentId=""
               name="Component_Name"
               type="profile.json"
               folderId="">
<!-- Result: Component lands in root folder -->
```

### Correct Pattern - Actual Folder GUID

```xml
<bns:Component componentId=""
               name="Component_Name"
               type="profile.json"
               folderId="folder_abc123def">
<!-- Result: Component correctly placed in designated folder -->
```

### MANDATORY Verification Step

**ALWAYS verify folder placement immediately after component creation:**
1. **Check Boomi platform GUI** to confirm components landed in correct project folder
2. **If components appear in root folder**, STOP and investigate MCP tool folder resolution
3. **Never proceed with root folder components** - delete and recreate properly
4. **Verify resolution**: Check that folder ID resolves to actual GUID before API call

### Pre-Creation and Verification

Before creating: Folder created with `boomi-folder-create.sh`, folder ID is actual GUID, XML uses `folderId` attribute. After creating: Immediately verify placement in Boomi GUI - if in root folder, delete and troubleshoot before recreating.

---

## Issue #8: Common XML Schema Mistakes

**Frequency:** High
**Detection:** Design-time validation errors during push

### The Problem

Common XML attribute and element mistakes that cause validation errors during component push operations. These are easy to fix once identified but can be confusing without examples.

### Message Step Errors

**Wrong:**
```xml
<message combineDocuments="false" messageType="static">
```

**Error:**
```
cvc-attribute.3: The value 'combineDocuments' of attribute is not valid
```

**Correct:**
```xml
<message combined="false">
```

**Why:** Use `combined="false"` for single document output.

### Stop Step Errors

**Wrong:** `<stopaction/>`
**Correct:** `<stop continue="true"/>`
**Why:** Element name is `stop`, not `stopaction`.

### JSON Profile Type Errors

**Wrong:** `<bns:Component type="profile" subType="json">`
**Correct:** `<bns:Component type="profile.json">`
**Why:** JSON profiles use `type="profile.json"`, not separate subType.

### Set Properties Step Errors

**Wrong:**
```xml
<shape shapetype="setproperties">
  <setproperties>
    <!-- configuration -->
  </setproperties>
</shape>
```

**Error:**
```
cvc-enumeration-valid: Value 'setproperties' is not facet-valid
```

**Correct:**
```xml
<shape shapetype="documentproperties">
  <documentproperties>
    <!-- configuration -->
  </documentproperties>
</shape>
```

**Why:** Use `documentproperties` (not `setproperties`) for both shapetype and element.

### Component ID Mismatch Errors

**Wrong:** UPDATE with empty componentId
**Correct:** CREATE uses `componentId=""`, UPDATE uses actual platform GUID
**Why:** CREATE requires empty ID, UPDATE requires matching GUID.

---

## Issue #9: Map Function GUI Requirements

**Frequency:** Low
**Detection:** GUI rendering error - stack overflow in map editor

### The Problem

Map component functions missing required attributes cause stack overflow errors when opening in Boomi GUI map editor.

### Wrong Pattern

```xml
<functions>
  <function default="false" functionType="groovy2">
    <!-- Missing required attributes -->
    <script>return input1 + input2</script>
  </function>
</functions>
```

### Correct Pattern

```xml
<functions>
  <function default="false" functionType="groovy2"
            cacheEnabled="true" sumEnabled="false"
            x="100" y="100">
    <script>return input1 + input2</script>
  </function>
</functions>
```

### Required Attributes

- `cacheEnabled="true"` - Enable function result caching
- `sumEnabled="false"` - Disable sum aggregation
- `x="100"` and `y="100"` - Canvas coordinates for GUI positioning

### Additional Consideration

**Map function independence:** Each function widget should be standalone - no chaining function outputs to other function inputs. For complex multi-step transformations, use single Groovy function instead of chaining.

---

## Issue #10: Process Layout Spacing

**Frequency:** Low
**Detection:** GUI label overlap

### The Problem

Steps positioned too close together cause label overlap in Boomi GUI, making process difficult to read.

### Correct Pattern

Use **250-unit spacing** between shapes on same horizontal line to prevent label overlap.

```xml
<shape x="250" y="100" shapetype="start">
  <!-- Start step -->
</shape>

<shape x="500" y="100" shapetype="connector">
  <!-- Connector step (250 units from start) -->
</shape>

<shape x="750" y="100" shapetype="stop">
  <!-- Stop step (250 units from connector) -->
</shape>
```

### Spacing Guidelines

- **Horizontal spacing**: 250 units between steps on same line
- **Vertical spacing**: 100 units for branches/parallel paths
- **Special offset**: Test data Message shapes ~100px below main path

---

## Issue #11: GUI Display Attributes

**Frequency:** Low
**Detection:** "null" displays in GUI (steps work correctly at runtime)

### The Problem

Missing display attributes cause "null" to appear in Boomi GUI instead of property names, though steps execute correctly.

### Affected Steps

**Connector Steps:**
```xml
<!-- Missing display attributes -->
<propertyvalue childKey="userId" key="queryParameters" valueType="track">
  <trackparameter propertyId="dynamicdocument.DDP_USER_ID"/>
  <!-- GUI shows "null" for property name -->
</propertyvalue>
```

**Correct:**
```xml
<propertyvalue childKey="userId" key="queryParameters"
               name="Query Parameters" valueType="track">
  <trackparameter propertyId="dynamicdocument.DDP_USER_ID"
                  propertyName="Dynamic Document Property - DDP_USER_ID"
                  defaultValue=""/>
</propertyvalue>
```

**Message/Notify Steps:**
```xml
<!-- Missing display attributes -->
<parametervalue key="1" valueType="track">
  <trackparameter propertyId="dynamicdocument.DDP_ORDER_ID"/>
  <!-- GUI shows "null" for property name -->
</parametervalue>
```

**Correct:**
```xml
<parametervalue key="1" valueType="track">
  <trackparameter propertyId="dynamicdocument.DDP_ORDER_ID"
                  propertyName="Dynamic Document Property - DDP_ORDER_ID"
                  defaultValue=""/>
</parametervalue>
```

### Required Attributes

- **Connector steps**: `name="Query Parameters"` on propertyvalue
- **All trackparameter elements**: `propertyName="..."` and `defaultValue=""`
- **Pattern**: All programmatically generated steps with `<trackparameter>` elements need GUI display attributes

### Impact

- **Runtime**: Steps execute correctly regardless of display attributes
- **GUI**: Shows "null" instead of property names, harder for humans to review
- **Best Practice**: Include display attributes for human-friendly processes

---

## Issue #12: Subprocess Test Payloads in Production

**Frequency:** Medium
**Detection:** Silent - test data used instead of real data

### The Problem

Temporary test Message shapes added for subprocess isolated testing are forgotten and left active in production deployments, causing processes to use test data instead of real data from parent process.

### Subprocess Testing Context

**Challenge:** When testing subprocess in isolation (via boomi-test-execute.sh or GUI), subprocess expects document from parent wrapper but has no data source.

**Common Solution:** Add temporary Message shape with test JSON payload that mimics expected structure from WSS request.

### Wrong Pattern - Test Code Left Active

```xml
<!-- Subprocess starts -->
<shape shapetype="start">
  <passthroughaction/>
</shape>

<!-- Test Message shape for isolated testing -->
<shape x="100" y="200" shapetype="message">
  <message combined="false">
    <msgTxt>{"test": "data", "mode": "development"}</msgTxt>
  </message>
</shape>

<!-- Business logic -->
<shape x="250" y="100" shapetype="map">
  <!-- Routes from both start AND test message -->
</shape>
<!-- Result: Production deployment uses test data! -->
```

### Correct Pattern - Test Code Removed

```xml
<!-- Subprocess starts -->
<shape shapetype="start">
  <passthroughaction/>
</shape>

<!-- Business logic directly after start -->
<shape x="250" y="100" shapetype="map">
  <!-- Routes only from start -->
</shape>
<!-- Result: Production uses real data from parent process -->
```

### Alternative: Dynamic Routing for Permanent Testability

If subprocess needs ongoing isolated testing capability:

1. Parent wrapper: Add Set Properties step setting `DPP_FROM_WRAPPER=true`
2. Subprocess: Start with Decision step checking if `DPP_FROM_WRAPPER` exists
3. Path when DPP present (called from parent) → proceed to business logic
4. Path when DPP absent (isolated testing) → Message shape with test payload → business logic
5. Subprocess remains permanently testable without removing test code

### Pre-Deployment Checklist

Before deploying WSS wrapper + subprocess to production:
1. [ ] Identify all Message shapes in subprocess
2. [ ] Verify test Message shapes are removed OR
3. [ ] Verify dynamic routing properly detects parent vs isolated testing
4. [ ] Test parent-to-subprocess flow uses real data path
5. [ ] Document which Message shapes are permanent vs temporary

---

## Issue #13: SSL Certificate Verification in Testing

**Frequency:** Medium
**Detection:** Runtime connection failures - SSL certificate verification errors

### The Problem

Development and testing environments often use self-signed SSL certificates. Python CLI tools and curl commands fail with SSL certificate verification errors when connecting to these environments, despite credentials being correct.

**Common Scenarios:**
- Local/custom Boomi instances with self-signed certificates
- Development runtime servers with non-production certificates
- Testing against localhost HTTPS endpoints

### Why It Happens

By default, both Python's `requests` library and `curl` refuse to connect to HTTPS endpoints with untrusted or self-signed certificates for security reasons.

### Wrong Pattern - Hard-Coded Insecure Flags

```bash
# Disabling SSL without configuration visibility
curl -k -X POST "${SERVER_BASE_URL}/ws/simple/endpoint"
```

**Problem:** Future developers don't know when `-k` flag is needed or why.

### Correct Pattern - Configurable SSL Verification

**Configuration Variables:**
```bash
# .env file
BOOMI_VERIFY_SSL=false        # Platform API SSL verification
SERVER_VERIFY_SSL=false       # Runtime server SSL verification
```

**Python Tools:** All CLI tools automatically respect `BOOMI_VERIFY_SSL` setting:
```python
# Handled automatically by tools
verify_ssl_config = self.config.get('api', {}).get('verify_ssl', 'true')
self.verify_ssl = str(verify_ssl_config).lower() != 'false'
response = requests.get(url, verify=self.verify_ssl)
```

**Curl Commands:** Use conditional SSL flag based on SERVER_VERIFY_SSL:
```bash
# SSL verification helper (add -k flag if SERVER_VERIFY_SSL=false)
SSL_FLAG=$([ "${SERVER_VERIFY_SSL}" = "false" ] && echo "-k" || echo "")

# Inline JSON with SSL support
curl $SSL_FLAG -X POST \
  -u "${SERVER_USERNAME}:${SERVER_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"key":"value"}' \
  "${SERVER_BASE_URL}/ws/simple/endpoint"
```

### Configuration Separation

Two separate settings control SSL verification in different contexts:

**BOOMI_VERIFY_SSL:**
- Controls: Platform API calls (component pull/push/create, deployments)
- Used by: All Python CLI tools in `scripts/` directory
- Set to `false` when: Platform API URL uses self-signed certificate

**SERVER_VERIFY_SSL:**
- Controls: Runtime server HTTP testing (WSS listener curl commands)
- Used by: Manual curl testing commands
- Set to `false` when: Shared Web Server uses self-signed certificate

**Important:** Platform API and runtime server may use different certificates. Configure each independently based on your environment.

### Pre-Testing Checklist

Before testing processes:
1. Identify if environment uses self-signed certificates
2. Set `BOOMI_VERIFY_SSL=false` if platform API uses self-signed cert
3. Set `SERVER_VERIFY_SSL=false` if runtime server uses self-signed cert
4. For production environments, always use `true` (verify certificates)
5. Document SSL configuration in environment setup notes

### Security Note

Disabling SSL verification should only be used in development/testing environments with self-signed certificates. Production environments should always verify SSL certificates (`BOOMI_VERIFY_SSL=true` and `SERVER_VERIFY_SSL=true`).

---

## Issue #14: Branch Step Missing numBranches Attribute

**Frequency:** Medium
**Detection:** GUI rendering error - blank canvas with JavaScript console error

### The Problem

Branch steps without the `numBranches` attribute deploy successfully and execute correctly at runtime, but cause the Boomi GUI to render a blank canvas when opening the process. JavaScript errors appear in browser console.

**Symptom:** `Cannot read properties of null (reading 'a')` JavaScript error in AtomSphere GUI when opening process.

### Why It Happens

The Boomi GUI canvas renderer expects the `numBranches` attribute to determine how many outgoing paths exist. Without this attribute, the GUI attempts to read a null value and fails to render the entire process canvas.

**Critical Detail:** Process deploys and executes successfully - only GUI rendering fails.

### Wrong Pattern - Blank Canvas Despite Successful Deployment

```xml
<!-- Branch step without numBranches -->
<shape image="branch_icon" name="shape2" shapetype="branch" x="240.0" y="48.0">
  <configuration>
    <branch/>
  </configuration>
  <dragpoints>
    <dragpoint identifier="1" name="shape2.dragpoint1" text="1" toShape="shape4" x="416.0" y="56.0"/>
    <dragpoint identifier="2" name="shape2.dragpoint2" text="2" toShape="shape10" x="416.0" y="376.0"/>
  </dragpoints>
</shape>
<!-- Result: Deploys successfully, executes correctly, but GUI shows blank canvas -->
```

### Correct Pattern - GUI Renders Properly

```xml
<!-- Branch step with numBranches matching dragpoint count -->
<shape image="branch_icon" name="shape2" shapetype="branch" x="240.0" y="48.0">
  <configuration>
    <branch numBranches="2"/>
  </configuration>
  <dragpoints>
    <dragpoint identifier="1" name="shape2.dragpoint1" text="1" toShape="shape4" x="416.0" y="56.0"/>
    <dragpoint identifier="2" name="shape2.dragpoint2" text="2" toShape="shape10" x="416.0" y="376.0"/>
  </dragpoints>
</shape>
<!-- Result: Deploys, executes, AND renders correctly in GUI -->
```

### Critical Rule

**Always include `numBranches` attribute and match it to dragpoint count:**
- 2 dragpoints → `numBranches="2"`
- 3 dragpoints → `numBranches="3"`
- 4 dragpoints → `numBranches="4"`

### Pre-Push Checklist

Before pushing any process with branch steps:
1. [ ] Locate all `<branch/>` elements in process XML
2. [ ] Verify each has `numBranches="N"` attribute
3. [ ] Count dragpoints and verify number matches `numBranches` value
4. [ ] Test GUI rendering after deployment to confirm canvas displays

### Related Step Documentation

See references/steps/branch_step.md for complete branch step XML reference and configuration examples.

---

## Issue #15: Stop Step Missing continue Attribute

**Frequency:** Medium
**Detection:** GUI rendering error - process cannot be opened with stack overflow

### The Problem

Stop steps without the `continue="true"` attribute deploy successfully and execute correctly at runtime, but cause the Boomi GUI to fail with stack overflow error when attempting to open the process.

**Symptom:** `Cannot read properties of null (reading 'a')` and `Maximum call stack size exceeded` JavaScript errors in AtomSphere GUI.

### Why It Happens

The Boomi platform API accepts `<stop/>` without the `continue` attribute and validation passes. The process deploys and executes successfully at runtime. However, the GUI canvas renderer expects the `continue` attribute - without it, the renderer encounters a null reference that triggers infinite recursion, causing stack overflow.

**Critical Detail:** Process deploys and runs correctly - only GUI opening fails.

### Wrong Pattern - GUI Stack Overflow

```xml
<!-- Stop step without continue attribute -->
<shape image="stop_icon" name="shape9" shapetype="stop" x="1968.0" y="48.0">
  <configuration>
    <stop/>
  </configuration>
  <dragpoints/>
</shape>
<!-- Result: Deploys successfully, executes correctly, but GUI cannot open process -->
```

### Correct Pattern - GUI Opens Successfully

```xml
<!-- Stop step with continue attribute -->
<shape image="stop_icon" name="shape9" shapetype="stop" x="1968.0" y="48.0">
  <configuration>
    <stop continue="true"/>
  </configuration>
  <dragpoints/>
</shape>
<!-- Result: Deploys, executes, AND opens in GUI without errors -->
```

### Critical Rule

**Always include `continue="true"` attribute in all stop step configurations.** This is required for GUI compatibility, even though runtime execution succeeds without it.

### Pre-Push Checklist

Before pushing any process with stop steps:
1. [ ] Locate all `<stop/>` elements in process XML
2. [ ] Verify each has `continue="true"` attribute
3. [ ] Test GUI opening after deployment to confirm process is accessible

---

## Issue #16: WSS Start Step Invalid actionType

**Frequency:** Medium
**Detection:** GUI rendering error - empty action picklist in operation configuration

### The Problem

Web Services Server (WSS) start steps with invalid `actionType` values deploy successfully to the platform but fail to function as listeners. The Boomi GUI shows an empty action picklist when viewing the operation configuration, making it impossible to properly configure the operation through the GUI.

**Real-World Symptoms:**
- Process deploys without errors
- HTTP requests to the endpoint time out or return 404
- GUI shows empty dropdown for action selection in operation configuration
- No runtime errors - process simply doesn't listen for incoming requests

### Why It Happens

WSS start steps require `actionType="Listen"` - this is the only valid value for listener-based start shapes. Other plausible-sounding values like "EXECUTE", "POST", or "GET" pass platform validation during deployment but cause the operation configuration to fail silently.

**Root Cause:** Platform accepts invalid actionType during component push, but runtime initialization skips the listener setup when actionType doesn't match expected value.

### Wrong Pattern - Silent Listener Failure

```xml
<!-- WSS Start step with invalid actionType -->
<shape image="start" name="shape1" shapetype="start" userlabel="" x="96.0" y="94.0">
  <configuration>
    <connectoraction actionType="EXECUTE" allowDynamicCredentials="NONE" connectorType="wss" hideSettings="true" operationId="e468be9c-e350-4ed8-8841-e8001793031b">
      <parameters/>
      <dynamicProperties/>
    </connectoraction>
  </configuration>
  <dragpoints>
    <dragpoint name="shape1.dragpoint1" toShape="shape5" x="304.0" y="120.0"/>
  </dragpoints>
</shape>
<!-- Result: Deploys successfully, but doesn't listen for requests! -->
```

### Correct Pattern - Working Listener

```xml
<!-- WSS Start step with correct actionType -->
<shape image="start" name="shape1" shapetype="start" userlabel="" x="96.0" y="94.0">
  <configuration>
    <connectoraction actionType="Listen" allowDynamicCredentials="NONE" connectorType="wss" hideSettings="true" operationId="e468be9c-e350-4ed8-8841-e8001793031b">
      <parameters/>
      <dynamicProperties/>
    </connectoraction>
  </configuration>
  <dragpoints>
    <dragpoint name="shape1.dragpoint1" toShape="shape5" x="304.0" y="120.0"/>
  </dragpoints>
</shape>
<!-- Result: Deploys and correctly listens for incoming HTTP requests -->
```

### Critical Rule

**Always use `actionType="Listen"` for WSS start steps.** This is the only valid value for listener-based connectors.

**Valid actionType values by start step type:**
- **WSS listeners**: `actionType="Listen"` (ONLY valid value)
- **Event Streams listeners**: `actionType="Listen"` (subscriber processes)
- **Passthrough**: `<passthroughaction/>` (no actionType attribute)

### Pre-Push Checklist

Before pushing any process with WSS start steps:
1. [ ] Locate all WSS start shapes (`connectorType="wss"`)
2. [ ] Verify each has `actionType="Listen"` (exact spelling, capitalization)
3. [ ] Confirm operationId references valid WSS operation component
4. [ ] Test endpoint after deployment to confirm listener is active

### Related Step Documentation

See references/steps/start_step.md for complete start step XML reference and WSS configuration examples.

---

## Issue #17: Data Process Script Engine Attributes

**Frequency:** Medium
**Detection:** Runtime error - cryptic error message about null script engine

### The Problem

Data Process Custom Scripting steps missing required `language` and `useCache` attributes deploy successfully to the platform but fail at runtime with cryptic error: "Failed loading script engine null". The XML pushes without validation errors, but execution fails.

**Real-World Symptoms:**
- Process deploys without errors
- Runtime execution fails with "Error executing data process"
- Error message shows "Failed loading script engine null"
- Caused by: java.lang.NullPointerException
- No design-time warnings or validation errors

### Why It Happens

The platform API accepts `<dataprocessscript>` elements without the `language` attribute during component push. However, at runtime, the Groovy script engine initialization requires this attribute to determine which scripting engine to load. Without it, the engine lookup returns null, causing immediate NullPointerException.

**Root Cause:** Platform validation doesn't enforce required scripting attributes, but runtime engine requires them.

### Wrong Pattern - Cryptic Runtime Failure

```xml
<!-- Data Process step without required attributes -->
<step index="1" key="1" name="Custom Scripting" processtype="12">
  <dataprocessscript>
    <script><![CDATA[
      import java.util.Properties;
      import java.io.InputStream;

      for( int i = 0; i < dataContext.getDataCount(); i++ ) {
          InputStream is = dataContext.getStream(i);
          Properties props = dataContext.getProperties(i);

          props.setProperty("document.dynamic.userdefined.DDP_PROCESSED", "true");

          dataContext.storeStream(is, props);
      }
    ]]></script>
  </dataprocessscript>
</step>
<!-- Result: Deploys successfully, but fails at runtime with "Failed loading script engine null" -->
```

### Correct Pattern - Working Script Execution

```xml
<!-- Data Process step with required attributes -->
<step index="1" key="1" name="Custom Scripting" processtype="12">
  <dataprocessscript language="groovy2" useCache="true">
    <script><![CDATA[
      import java.util.Properties;
      import java.io.InputStream;

      for( int i = 0; i < dataContext.getDataCount(); i++ ) {
          InputStream is = dataContext.getStream(i);
          Properties props = dataContext.getProperties(i);

          props.setProperty("document.dynamic.userdefined.DDP_PROCESSED", "true");

          dataContext.storeStream(is, props);
      }
    ]]></script>
  </dataprocessscript>
</step>
<!-- Result: Deploys and executes successfully at runtime -->
```

### Critical Rule

**Always include both required attributes on `<dataprocessscript>` elements:**
- `language="groovy2"` - Specifies Groovy 2.4 runtime (REQUIRED)
- `useCache="true"` - Enables script compilation caching (REQUIRED for performance)

Without these attributes, the script engine cannot initialize and runtime execution fails immediately.

### Pre-Push Checklist

Before pushing any Data Process Custom Scripting steps:
1. [ ] Locate all `<dataprocessscript>` elements in component XML
2. [ ] Verify each has `language="groovy2"` attribute
3. [ ] Verify each has `useCache="true"` attribute
4. [ ] Test execution after deployment to confirm script runs successfully

### Related Step Documentation

See references/steps/data_process_groovy_step.md for complete Custom Scripting (Groovy) XML reference and examples.

---

## Issue #18: Notify perExecution="true" Loses Document Context

**Frequency:** Medium
**Detection:** Runtime error - "Attempting dynamic document property extraction with no document"

### The Problem

Notify steps with `perExecution="true"` that reference DDPs, current data / document content, or profile elements fail at runtime. The error message suggests documents are missing, but in reality it is that the step ignores the documents and IMPORTANTLY errors if it attempts to reference document level data. If no document level data is attempted to be referenced, the documents will continue to flow through as expected.

### Why It Happens

`perExecution="true"` changes the Notify step to execute once per process execution instead of once per document. In this mode, there is no "current document" - the step runs outside the document iteration loop.

**Critical clarification:** The notify step with perException=true does NOT destroy DDPs or documents. Subsequent steps can access DDPs normally. But if the error is encountered, further processing down that path will halt, breaking the process.

### Wrong Pattern - Error When Step References DDPs

```xml
<notify perExecution="true" ...>
  <notifyMessage>Processing user: {1}</notifyMessage>
  <notifyParameters>
    <parametervalue key="1" valueType="track">
      <trackparameter propertyId="dynamicdocument.DDP_USER_EMAIL"/>
    </parametervalue>
  </notifyParameters>
</notify>
<!-- Result: "Attempting dynamic document property extraction with no document" -->
```

### Correct Patterns

**Option A - Remove perExecution (log per document):**
```xml
<notify perExecution="false" ...>
  <notifyMessage>Processing user: {1}</notifyMessage>
  <!-- DDPs work fine with perExecution="false" -->
</notify>
```

**Option B - Use static/DPP values only:**
```xml
<notify perExecution="true" ...>
  <notifyMessage>Process started at {1}</notifyMessage>
  <notifyParameters>
    <parametervalue key="1" valueType="date">
      <dateparameter dateparametertype="current" datetimemask="yyyy-MM-dd HH:mm:ss"/>
    </parametervalue>
  </notifyParameters>
</notify>
<!-- Works - no document-level references -->
```

**Option C - Copy DDP to DPP first:**
```xml
<!-- Step 1: Set Properties copies DDP to DPP -->
<!-- Step 2: Notify uses DPP instead -->
<notify perExecution="true" ...>
  <notifyMessage>Batch processing for: {1}</notifyMessage>
  <notifyParameters>
    <parametervalue key="1" valueType="process">
      <processparameter processproperty="DPP_BATCH_NAME"/>
    </parametervalue>
  </notifyParameters>
</notify>
```

### Pre-Push Checklist

Before pushing Notify steps with `perExecution="true"`:
1. [ ] Verify no DDP references in parameters
2. [ ] Verify no `valueType="current"` (document content)
3. [ ] Verify no profile element references
4. [ ] Only static, date, or DPP references allowed

---

## Issue #19: WSS Listener Path Collision

**Frequency:** Medium
**Detection:** Silent - requests route to wrong/stale process

### The Problem

Multiple deployed processes on the same WSS path cause unpredictable routing. Requests may hit an older process instead of the newly deployed one.

**Symptoms:** Process deploys successfully but returns old responses. Process Reporting shows executions hitting processes "last updated weeks ago."

### Diagnostic

Query active listeners using ListenerStatus API:

```bash
# Start async query
curl -X POST "https://api.boomi.com/api/rest/v1/${BOOMI_ACCOUNT_ID}/async/ListenerStatus/query" \
  -u "BOOMI_TOKEN.${BOOMI_USERNAME}:${BOOMI_TOKEN}" \
  -H "Content-Type: application/json" -H "Accept: application/json" \
  -d '{"QueryFilter":{"expression":{"operator":"EQUALS","property":"containerId","argument":["'${BOOMI_CONTAINER_ID}'"]}}}'
# Returns {"asyncToken":{"token":"abc123..."}}

# Poll for results (replace TOKEN)
curl "https://api.boomi.com/api/rest/v1/${BOOMI_ACCOUNT_ID}/async/ListenerStatus/response/{TOKEN}" \
  -u "BOOMI_TOKEN.${BOOMI_USERNAME}:${BOOMI_TOKEN}" -H "Accept: application/json"
```

Look for multiple `connectorType="wss"` entries sharing paths.

### Prevention

Use unique, project-specific objectName values in WSS Operations:

```xml
<!-- Collision-prone -->
<WssOperation objectName="products" operationType="create"/>

<!-- Unique per project -->
<WssOperation objectName="productsMyProject" operationType="create"/>
```

### Resolution

Change objectName to unique path, redeploy, and undeploy stale processes via AtomSphere GUI.

---

## Issue #20: MCP Server Profile/Schema Sync

**Frequency:** High
**Detection:** Silent - old validation rules active after schema changes

### The Problem

MCP Server `toolSchema` changes don't propagate to the JSON Profile. The tool validates against the old profile until you reimport and redeploy.

### Correct Pattern

After any schema change:
1. Reimport JSON Profile from new schema
2. Update operation (`toolSchema`, `cookie/value`, `defaultValue` must all match)
3. Redeploy ALL processes using this connection

```bash
bash scripts/boomi-component-push.sh mcp-profile.xml
bash scripts/boomi-component-push.sh mcp-operation.xml
bash scripts/boomi-deploy.sh mcp-process.xml
```

---

## Issue #21: MCP Server 503 After Valid Auth

**Frequency:** Medium
**Detection:** Runtime - 503 "Server Shutting Down" after successful token validation

### The Problem

MCP Server returns 503 after auth succeeds. Token is valid, but session initialization fails.

### Workaround

Restart the Atom. Redeploying alone does not fix this - the Atom itself needs to be restarted.

---

## Issue #22: EDI TagList elementKey Target

**Frequency:** High (any EDI profile with qualified repeating loops)
**Detection:** Runtime - map produces more output documents than expected, or address/child segment data silently missing

### The Problem

When configuring tagLists on an EDI profile, `elementKey` must point to the **loop** element, not a segment within the loop. Two failure modes:

**No tagLists**: Mapping from a repeating EDI loop (e.g., N1 loop with N1*ST and N1*BT) produces separate output documents per loop iteration. Header and detail data are duplicated across all split documents.

**Segment-level elementKey**: Pointing `elementKey` at a segment (e.g., the N1 segment) instead of the containing loop causes splitting AND silent data loss -- sibling segments within the loop (N3 address, N4 city/state/zip) are excluded from scope entirely. No error is raised.

### The Fix

Set `elementKey` to the loop's key, not a segment's key. With loop-level `elementKey`, the map consolidates qualified iterations into different target fields of a single output document per transaction set.

```xml
<!-- CORRECT: elementKey points to the N1 Loop (key=20) -->
<TagList elementKey="20" listKey="1">

<!-- WRONG: elementKey points to the N1 Segment (key=21) — causes splitting + data loss -->
<TagList elementKey="21" listKey="1">
```

---

## Issue #23: Empty processOverrides Destroys Extensions

**Frequency:** High (any pull-modify-push workflow on processes with extensions)
**Detection:** Silent - extension values disappear from environment after deployment

### The Problem

Pushing a process with empty `<bns:processOverrides/>` or empty `<Overrides xmlns=""/>` actively **removes** that process's extension declarations from the environment. Extension values previously set via the Environment Extensions API are lost.

### Why It Happens

The platform stores exactly what is pushed. An empty processOverrides element is not "no change" -- it is "this process has no extensions." When deployed, the environment removes the extension declarations for that process.

### Wrong Pattern - Extensions Silently Destroyed

```xml
<!-- Pulled process had extensions, but processOverrides was emptied or left as self-closing -->
<bns:Component ...>
  <bns:object>...</bns:object>
  <bns:processOverrides/>
</bns:Component>
<!-- Result: After push + deploy, all extension values for this process are gone -->
```

### Correct Pattern - Preserve Extensions

```xml
<bns:Component ...>
  <bns:object>...</bns:object>
  <bns:processOverrides>
    <Overrides xmlns="">
      <Connections>
        <ConnectionOverride id="c7d489dc-...">
          <field id="url" label="URL" overrideable="true"/>
        </ConnectionOverride>
      </Connections>
      <Properties>
        <PropertyOverride name="DPP_MY_SETTING"/>
      </Properties>
    </Overrides>
  </bns:processOverrides>
</bns:Component>
<!-- Result: Extension declarations preserved after push + deploy -->
```

### Pre-Push Checklist

Before pushing any process that may have extensions:
1. Check if pulled XML contained populated `<bns:processOverrides>` content
2. Never replace populated overrides with self-closing `<bns:processOverrides/>`
3. When creating new processes, use self-closing form only if the process genuinely has no extensions

---

## Issue #24: DPP valueType="track" Returns Empty

**Frequency:** High
**Detection:** Silent - DPP values appear as empty string in output

### The Problem

Reading a Dynamic Process Property (DPP) with `valueType="track"` / `<trackparameter>` always returns empty string, regardless of whether the DPP was set by environment extensions, Set Properties steps, or Groovy scripts. No error is thrown -- the value is simply empty.

Additionally, `valueType="track"` with `perExecution="true"` (no document context) throws: `ProcessException: Attempting tracked document property extraction with no document`.

### Why It Happens

`valueType="track"` with `<trackparameter>` is designed for Dynamic **Document** Properties (DDPs). Despite `propertyId="process.DPP_NAME"` appearing to reference a DPP, the track mechanism does not resolve process-level properties.

### Wrong Pattern - DPP Always Empty

```xml
<parametervalue key="0" valueType="track">
  <trackparameter defaultValue="" propertyId="process.DPP_SF_CLIENT_ID"
                  propertyName="Dynamic Process Property - DPP_SF_CLIENT_ID"/>
</parametervalue>
<!-- Result: Always returns empty string, silently -->
```

### Correct Pattern - DPP Value Retrieved

```xml
<parametervalue key="0" valueType="process">
  <processparameter processproperty="DPP_SF_CLIENT_ID" processpropertydefaultvalue=""/>
</parametervalue>
<!-- Result: Returns the actual DPP value -->
```

### The Rule

- **DPPs** -> always use `valueType="process"` with `<processparameter>`
- **DDPs** -> use `valueType="track"` with `<trackparameter>`

This applies everywhere a `<parametervalue>` element is used: Message steps, Notify steps, Set Properties source values, and connector dynamic properties.

---

## Issue #25: Identity Field mandatory="true" on Map Output

**Frequency:** High (any multi-record flat file profile used as map output)
**Detection:** Runtime error - `MANDATORY_ELEMENT_MISSING`

### The Problem

Multi-record flat file profiles with `mandatory="true"` on identity fields (Code/Qual fields with `useToIdentifyFormat="true"`) cause runtime errors when the profile is used as a **map output**. Unmapped record types have empty identity fields, which triggers mandatory validation failure.

**Error message:**
```
[Output ProfileLocation: RecordName/Elements/Code; DocumentLocation: Record (1,0), FileRow 1]: Invalid Data Element: MANDATORY_ELEMENT_MISSING
```

### Why It Happens

When a flat file profile is used as map output, Boomi validates all `mandatory="true"` fields on every record type in the output document. If only some record types are mapped, unmapped record types produce empty identity fields. Those empty fields fail mandatory validation.

### Wrong Pattern - Runtime Error on Unmapped Records

```xml
<FlatFileElement name="RecordType" startColumn="0" length="3"
                useToIdentifyFormat="true" identityValue="139"
                mandatory="true" .../>
<!-- Result: MANDATORY_ELEMENT_MISSING when this profile is map output and not all records are mapped -->
```

### Correct Pattern - Identity Detection Works Without Mandatory

```xml
<FlatFileElement name="RecordType" startColumn="0" length="3"
                useToIdentifyFormat="true" identityValue="139"
                mandatory="false" .../>
<!-- Result: Identity detection works correctly; no validation error on unmapped records -->
```

### The Rule

**Default to `mandatory="false"` on identity fields** (`useToIdentifyFormat="true"`). Identity detection uses `identityValue` comparison alone — it does not depend on the mandatory flag. Since profiles are often reused across input and output contexts, `mandatory="false"` on identity fields avoids this error without sacrificing detection behavior.

`mandatory="true"` on identity fields is only safe when the profile will never be used as map output, or when every record type will always be mapped.

---

## Issue #26: Identity Value Trimming in Data Positioned Profiles

**Frequency:** High (any data positioned profile with `detectFormat="uniquevalues"`)
**Detection:** Silent in multi-record scenarios (record missing from output, no error). Explicit ERROR if the unmatched record is the only record in the data.

### The Problem

Boomi trims extracted field values before comparing them against `identityValue` in `uniquevalues` detection. But it does NOT trim the `identityValue` attribute itself. If `identityValue` contains trailing whitespace, the comparison fails silently.

**Multi-record scenario:** Other records match normally. The mismatched record silently vanishes — no error, no warning, the section is simply absent from output.

**Single-record scenario:** No records match. Error: `"No data produced from map, please check source profile and make sure it matches source data."`

### Why It Happens

In a data positioned profile, fields have fixed widths. If an identity value is shorter than the field width (e.g., "BF" in a 3-char field), the extracted value is "BF " (padded with trailing space). Boomi trims this to "BF" before comparison. But `identityValue="BF "` is compared as-is — "BF" ≠ "BF ".

### Wrong Pattern - Silent Record Loss

```xml
<!-- Field is 3 chars wide, but "BF" is only 2 chars -->
<FlatFileElement name="Qualifier" startColumn="2" length="3"
                useToIdentifyFormat="true" identityValue="BF "
                mandatory="false" .../>
<!-- Result: Extracted "BF " trimmed to "BF", compared against "BF " → no match → record vanishes -->
```

### Correct Pattern - Trimmed Identity Value

```xml
<FlatFileElement name="Qualifier" startColumn="2" length="3"
                useToIdentifyFormat="true" identityValue="BF"
                mandatory="false" .../>
<!-- Result: Extracted "BF " trimmed to "BF", compared against "BF" → match -->
```

### The Rule

**Always set `identityValue` to the trimmed identifier text, never padded to field width.** This applies regardless of the field's `length` attribute. Values that already fill the full field width (e.g., "CTL" in a 3-char field) are unaffected since trimming doesn't change them.

### Debugging Tip

If a specific record type is missing from output but others parse correctly, check whether its identity value is shorter than the field width. This is the most common cause.

---

## Issue #27: Listener Process with Default Process Options

**Frequency:** High (any listener process created without adjusting process options)
**Detection:** Silent - concurrent requests queued or rejected instead of processed in parallel

### The Problem

Listener processes (WSS, FSS, MCP Server, Event Streams) created with default process options have `allowSimultaneous="false"`, which causes concurrent requests to queue or fail. WSS processes return HTTP 500 to concurrent callers. Other listener types queue or reject subsequent triggers while one execution is in progress.

### Why It Happens

New processes default to `allowSimultaneous="false"` and `updateRunDates="true"` — appropriate for scheduled/batch processes but wrong for listeners. The Boomi GUI shows a yellow banner recommending changes when configuring a listener start step, but programmatic creation skips this prompt.

### Wrong Pattern - Listener with Default Options

```xml
<process allowSimultaneous="false" enableUserLog="false" processLogOnErrorOnly="false" purgeDataImmediately="false" updateRunDates="true" workload="general">
  <shapes>
    <shape image="start" name="shape1" shapetype="start" userlabel="" x="96.0" y="94.0">
      <configuration>
        <connectoraction actionType="Listen" connectorType="wss" .../>
      </configuration>
    </shape>
  </shapes>
</process>
<!-- Result: Second concurrent HTTP request gets HTTP 500; updateRunDates adds per-execution overhead -->
```

### Correct Pattern - Listener with Recommended Options

```xml
<process allowSimultaneous="true" enableUserLog="false" processLogOnErrorOnly="false" purgeDataImmediately="false" updateRunDates="false" workload="general">
  <shapes>
    <shape image="start" name="shape1" shapetype="start" userlabel="" x="96.0" y="94.0">
      <configuration>
        <connectoraction actionType="Listen" connectorType="wss" .../>
      </configuration>
    </shape>
  </shapes>
</process>
<!-- Result: Concurrent requests processed in parallel; no run date overhead -->
```

### Pre-Push Checklist

Before pushing any process with a listener start step:
1. [ ] Verify `allowSimultaneous="true"` on the `<process>` element
2. [ ] Verify `updateRunDates="false"` on the `<process>` element
3. [ ] Applies to all listener types: WSS, FSS, MCP Server, Event Streams Listen

See `components/process_component.md` for the full decision table of recommended values by start step type.

---

## Issue #28: SF Operation Missing Sorts Element

**Frequency:** High (any programmatically-created Salesforce query operation)
**Detection:** GUI white screen — `TypeError: Cannot read properties of null (reading 'a')` when opening the operation editor

### The Problem

A Salesforce query operation missing the `<Sorts/>` element inside `<SalesforceObject>` causes the Boomi GUI operation editor to white-screen crash. The runtime is unaffected — queries execute fine without it.

### Why It Happens

The GWT-based operation editor assumes `<Sorts>` exists as a child of `<SalesforceObject>` and NPEs when it's null. GUI-imported operations always include this element (even when empty). Programmatically-created operations may omit it.

### Wrong Pattern — GUI Crash

```xml
<SalesforceObject name="Account" objectAction="query">
  <FieldList>...</FieldList>
  <Filter>...</Filter>
  <!-- No <Sorts/> element — GUI white-screens -->
  <SalesforceObject name="Child Objects" objectType="childObjects"/>
  <SalesforceObject name="Parent Objects" objectType="parentObjects"/>
</SalesforceObject>
```

### Correct Pattern

```xml
<SalesforceObject name="Account" objectAction="query">
  <FieldList>...</FieldList>
  <Filter>...</Filter>
  <Sorts/>
  <SalesforceObject name="Child Objects" objectType="childObjects"/>
  <SalesforceObject name="Parent Objects" objectType="parentObjects"/>
</SalesforceObject>
```

### The Rule

Always include `<Sorts/>` inside `<SalesforceObject>` on query operations, after `</Filter>` and before child `<SalesforceObject>` elements. Even when empty, its presence is required for GUI rendering.

---
