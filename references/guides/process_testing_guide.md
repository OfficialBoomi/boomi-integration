## Testing and Feedback System

## Contents
- Testing Patterns by Process Type
- Subprocess Testing Strategy
- Regular Processes (Non-Listener)
- Web Services Server (WSS) Listener Processes
- WSS Endpoint URL Construction
- Testing Workflow Requirements

#### **Testing Patterns by Process Type**
- **WSS Listeners**: HTTP calls with inline JSON, review response payload
- **Regular processes (Non-listener)**: Trigger with ExecutionRequest API, review process log
- **Subprocesses**: Prefer testing via parent endpoint; use isolation harness only when:
- Instructed by the user
- Encountering persistent issues that require deeper visibility than calling the wrapper provides
- Working through a complex build and needing to test incrementally as you progress

### **Subprocess Testing Strategy**

**Default approach**: If a listener subprocess - deploy the full stack and test via the listener endpoint. This is simplest and tests real integration. If not a listener - execute the parent process.

**Isolation testing** (when subprocess-level debugging is needed): Build a permanent test harness that activates only when the subprocess runs standalone. This hydrates the documents and properties that the subprocess would otherwise expect to get from the parent/wrapper process and allows it to execute correctly.

**Subprocess execution visibility**: Parent-invoked subprocesses do not get their own ExecutionRecord — only the parent appears in execution queries. All subprocess Notify output, errors, and step details appear inline in the parent's ProcessLog. When debugging a parent-subprocess chain, download the parent's logs — there is no separate subprocess log to retrieve. If a subprocess errors and the Process Call step has `abort="true"`, the parent's status becomes ERROR and the parent's log contains the full subprocess error stack trace.

**Stale deployment trap**: If standalone subprocess tests produce unexpected errors (wrong data, auth failures, missing fields), a common cause is a stale deployment. Standalone execution uses the last independently deployed version of the subprocess — not the version bundled with the parent's last deployment. Always deploy the subprocess itself before testing it in isolation.

**The Pattern:**
1. **In wrapper**: Set a marker dynamic process property `DPP_FROM_WRAPPER=true` before calling subprocess
2. **In subprocess**: Decision step checks if `DPP_FROM_WRAPPER` equals `true`
   - **True path** → Normal processing (called from wrapper with real data)
   - **False path** → Test path: Message step creates mock payload, Set Properties seeds expected properties, then routes to main logic

**Why this works**: The test path only activates during standalone execution (no wrapper = no marker). It's a permanent fixture that doesn't interfere with production flow.

**When to use**:
- Debugging complex subprocess logic in isolation
- Building reusable test fixtures for ongoing development
- Subprocess needs specific input combinations hard to trigger via wrapper

**Anti-pattern**: Inserting temporary Message steps in the main path. These function in a pinch but must be removed before production and are easily forgotten.

### **Regular Processes (Non-Listener)**
```bash
# Standard: Trigger process execution
bash scripts/boomi-test-execute.sh --process-id <guid>

# Advanced: Send Process Properties (rare)
bash scripts/boomi-test-execute.sh --process-id <guid> --test-data file.json
```

**ExecutionRequest Limitations:**
- Cannot send document payloads (no inbound data injection)
  - To generate a test document you must populate the payload in the process configuration, as a message step.
  - Many processes fetch their own data (REST connectors, databases, etc.)

**Results:** Saved to `active-development/feedback/execution-results/execution_TIMESTAMP_REQUESTID.json` with execution record.

### **Web Services Server (WSS) Listener Processes**

**WSS ENDPOINT QUICK REFERENCE CARD**

Save this pattern - use it EVERY time:

| XML Attributes                                 | Formula             | Result                      |
|------------------------------------------------|---------------------|-----------------------------|
| `operationType="GET"` `objectName="Hello"`     | `get` + `Hello`     | `/ws/simple/getHello`       |
| `operationType="CREATE"` `objectName="User"`   | `create` + `User`   | `/ws/simple/createUser`     |
| `operationType="QUERY"` `objectName="Time"`    | `query` + `Time`    | `/ws/simple/queryTime`      |
| `operationType="UPDATE"` `objectName="Record"` | `update` + `Record` | `/ws/simple/updateRecord`   |

**Valid operationTypes:** GET, QUERY, CREATE, UPDATE, UPSERT, DELETE, EXECUTE (NOT "POST", "PUT", or "PATCH")

**Key Rule:** `lowercase(OPERATION_TYPE) + sentenceCase(OBJECT_NAME) = endpoint_path`

**Remember:** sentence case means first letter uppercase, so `"hello"` becomes `"Hello"`

**CRITICAL: WSS Endpoint URL Construction**

The endpoint URL for a Web Services Server listener is built by concatenating the `operationType` and `objectName` attributes from the WSS operation XML.

**The Formula:**
```
${SERVER_BASE_URL}/ws/simple/{lowercase_operationType}{sentencecase_objectName}
```

**IMPORTANT:** Boomi transforms the operationType to lowercase, then concatenates with objectName (sentence case). NO separator is added between them.

**Algorithm (copy this pattern every time):**
```python
# Pseudo-code for constructing WSS endpoint
def build_wss_endpoint(operation_xml):
    operation_type = extract_attribute("operationType")  # e.g., "GET"
    object_name = extract_attribute("objectName")        # e.g., "hello" or "Hello"

    # Step 1: Lowercase the operation type
    method = operation_type.lower()  # "GET" → "get"

    # Step 2: Convert objectName to sentence case
    # First character uppercase, rest preserved
    resource = object_name[0].upper() + object_name[1:] if object_name else ""
    # "hello" → "Hello", "Hello" → "Hello", "user" → "User"

    # Step 3: Concatenate with NO separator
    path = method + resource  # "get" + "Hello" = "getHello"

    # Step 4: Build full URL
    return f"{SERVER_BASE_URL}/ws/simple/{path}"
```

**Step-by-Step Construction Process (FOLLOW EXACTLY):**

1. **Read the WSS operation XML file** (e.g., `active-development/operations/MyOperation.xml`)
2. **Find the `<WebServicesServerListenAction>` element**
3. **Extract `operationType`** attribute value (e.g., `"GET"`)
4. **Convert operationType to lowercase**
   - Example: `"GET"` → `"get"`
   - Example: `"POST"` → `"post"`
5. **Extract `objectName`** attribute value and convert to sentence case (first letter uppercase)
   - Example: `"hello"` → `"Hello"`
   - Example: `"time"` → `"Time"`
   - Example: `"user"` → `"User"`
6. **Concatenate with NO separator or slash**
   - Formula: `lowercase(operationType) + sentenceCase(objectName)`
   - Example: `"get" + "Hello"` = `"getHello"` (NOT "get-Hello" or "get/Hello")
7. **Build full URL**
   - Formula: `${SERVER_BASE_URL}/ws/simple/{concatenated_path}`
   - Example: `https://localhost:9091/ws/simple/getHello`
8. **Write down the final URL before testing** to verify correctness

**XML Example:**
```xml
<WebServicesServerListenAction
  objectName="Hello"
  operationType="GET" ... />
```
This produces the endpoint: `${SERVER_BASE_URL}/ws/simple/gethello`

**Quick Reference Examples:**
- `operationType="GET"` + `objectName="Hello"` → `/ws/simple/getHello`
- `operationType="CREATE"` + `objectName="User"` → `/ws/simple/createUser`
- `operationType="QUERY"` + `objectName="Weather"` → `/ws/simple/queryWeather`
- `operationType="UPDATE"` + `objectName="Pet"` → `/ws/simple/updatePet`

**CRITICAL:** The operationType must be one of the seven valid Boomi keywords: GET, QUERY, CREATE, UPDATE, UPSERT, DELETE, EXECUTE. Standard HTTP methods like "POST" or "PUT" are NOT valid and will fail.

**Common Mistakes to Avoid:**
1. DO NOT use standard HTTP methods: "POST", "PUT", "PATCH" are NOT valid - use CREATE, UPDATE, UPSERT instead
2. DO NOT use uppercase operationType in path: `GET` → must become `get` (Boomi lowercases it)
3. DO NOT use lowercase objectName: ALWAYS convert first letter to uppercase for sentence case
4. DO NOT add separators: `get` + `Hello` = `getHello` (NOT `get-hello` or `get/Hello`)
5. DO NOT add extra slashes: Use `/ws/simple/getHello` (NOT `/ws/simple//getHello`)
6. The pattern is: **lowercase operationType + sentence case objectName = compound endpoint**

---
**MOST COMMON ERROR PATTERN**

If you're getting 404 errors on WSS endpoints:
1. You likely used the WRONG case pattern OR invalid operationType
2. Go back and re-read the operation XML
3. Verify operationType is one of: GET, QUERY, CREATE, UPDATE, UPSERT, DELETE, EXECUTE
4. Apply the formula EXACTLY: `lowercase(operationType) + sentenceCase(objectName)`
5. Remember: sentence case means first letter uppercase
6. Test the corrected path

**Real examples:**
- XML: `operationType="GET" objectName="Hello"` → Endpoint: `/ws/simple/getHello` (uppercase H)
- XML: `operationType="CREATE" objectName="user"` → Endpoint: `/ws/simple/createUser` (capitalize to User)
- XML: `operationType="QUERY" objectName="Weather"` → Endpoint: `/ws/simple/queryWeather` (uppercase W)

The objectName MUST be converted to sentence case (first letter uppercase):
- `"hello"` → `"Hello"` → `getHello`
- `"user"` → `"User"` → `createUser`
- `"weather"` → `"Weather"` → `queryWeather`
---

Test via direct HTTP calls (WSS listeners expect HTTP requests):

```bash
# SSL verification helper (add -k flag if SERVER_VERIFY_SSL=false)
SSL_FLAG=$([ "${SERVER_VERIFY_SSL}" = "false" ] && echo "-k" || echo "")

# Simple GET request (no auth if SERVER_USERNAME/SERVER_TOKEN are empty)
curl $SSL_FLAG -X GET "${SERVER_BASE_URL}/ws/simple/getHello"

# POST with JSON payload (auth-disabled server)
curl $SSL_FLAG -X POST \
  -H "Content-Type: application/json" \
  -d '{"key":"value"}' \
  "${SERVER_BASE_URL}/ws/simple/endpoint"

# POST with authentication (if SERVER_USERNAME/SERVER_TOKEN are configured)
curl $SSL_FLAG -X POST \
  -u "${SERVER_USERNAME}:${SERVER_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"key":"value"}' \
  "${SERVER_BASE_URL}/ws/simple/endpoint"
```

**Environment Variable Reference**
```
SERVER_BASE_URL=https://your-atom.integrate.boomi.com
SERVER_USERNAME=your_runtime_username@account.domain  # Leave empty if auth disabled
SERVER_TOKEN=your_runtime_token                        # Leave empty if auth disabled
SERVER_VERIFY_SSL=false                                # Set to false for self-signed certs
```

**Usage**: These runtime credentials enable direct HTTP testing of Web Services Server listener processes via curl/Postman, bypassing the platform execution mechanism which cannot test WSS endpoints.

**Authentication:**
- If `SERVER_USERNAME` and `SERVER_TOKEN` are empty in `.env`, the server may have authentication disabled — test with simple curl commands without Authorization headers. This would most likely apply to a user running a local Boomi Runtime on the same machine as the agent.
- Only add Authorization header if credentials are configured

**MANDATORY PRE-TEST CHECKLIST:**

Before testing ANY WSS endpoint, you MUST:
1. Read the WSS operation XML file
2. Extract `operationType` and `objectName` attributes
3. Apply formula: `lowercase(operationType) + sentenceCase(objectName)` (no separator)
4. Convert objectName first letter to uppercase for sentence case
5. Write out the exact endpoint path you will test
6. Verify the path matches the formula before running curl

**Example verification:**
```
XML: operationType="GET", objectName="Hello"
Step 1: lowercase("GET") = "get"
Step 2: sentenceCase("Hello") = "Hello" (first letter uppercase)
Step 3: Concatenate = "get" + "Hello" = "getHello"
Endpoint: /ws/simple/getHello
```

**WRONG examples to avoid:**
- `/ws/simple/GETHello` (uppercase operation)
- `/ws/simple/gethello` (lowercase h - must be uppercase)
- `/ws/simple/Hello` (missing operation)
- `/ws/simple/get/hello` (added separator)

**Complete Testing Workflow:**
```bash
# Step 1: Read WSS operation XML to extract endpoint details
# Look for operationType and objectName in <WebServicesServerListenAction>
# Apply formula: /ws/simple/{lowercase(operationType)}{sentenceCase(objectName)}
# Example: operationType="GET" + objectName="Hello" → /ws/simple/getHello

# Step 2: Deploy the process to runtime (run from workspace)
bash scripts/boomi-deploy.sh active-development/processes/YourProcess.xml

# Step 3: Wait for runtime propagation (10-15 seconds)
sleep 12

# Step 4: Test the endpoint using curl
# REMEMBER: lowercase the operationType, sentence case the objectName

# For GET requests (no body):
# If XML has operationType="GET" objectName="Hello"
curl -k -X GET ${SERVER_BASE_URL}/ws/simple/getHello

# For CREATE requests (with JSON body):
# If XML has operationType="CREATE" objectName="User"
curl -k -X POST \
  -H "Content-Type: application/json" \
  -d '{"key":"value"}' \
  ${SERVER_BASE_URL}/ws/simple/createUser

# NOTE: The HTTP method (GET/POST) is determined by inputType in the XML,
# NOT by the operationType. operationType only affects the URL path.

# The response will be whatever your process returns via the Return Documents step
```




### Execution Workflow

Every test execution follows this workflow. Log retrieval is not optional — always download and review logs after running a process.

**Regular processes (non-listener):**
- [ ] Deploy the process: `bash scripts/boomi-deploy.sh active-development/processes/<process>.xml`
- [ ] Wait for runtime propagation (~12 seconds)
- [ ] Execute: `bash scripts/boomi-test-execute.sh --process-id <guid>`
- [ ] Download logs: `bash scripts/boomi-execution-query.sh --execution-id <execution-id> --logs`
- [ ] Review logs — check Notify step output, errors, and processing flow

**WSS listener processes:**
- [ ] Deploy the process: `bash scripts/boomi-deploy.sh active-development/processes/<process>.xml`
- [ ] Wait for runtime propagation (~12 seconds)
- [ ] Send HTTP request via curl (see WSS Endpoint URL Construction above)
(if you have issues ensure your path is unique and not colliding)
- [ ] Query execution: `bash scripts/boomi-execution-query.sh --process-id <guid>`
- [ ] Download logs for the latest execution: `bash scripts/boomi-execution-query.sh --execution-id <execution-id> --logs`
- [ ] Review logs — check Notify step output, errors, and processing flow

**Querying executions (all filters optional):**
```bash
# Recent executions for a specific process
bash scripts/boomi-execution-query.sh --process-id <guid>

# Recent executions across the account
bash scripts/boomi-execution-query.sh

# Filter by status, date, or expand results
bash scripts/boomi-execution-query.sh --process-id <guid> --status ERROR --limit 10
```

### Testing Workflow Requirements
- **Deploy Before Test**: Testing ALWAYS requires prior deployment — test atoms cannot execute updated processes until deployed to runtime
- **Multiple Test Runs Pattern**: If tests show old behavior or require multiple runs, this typically indicates missing deployment step
- **Wait for Propagation**: After deployment, wait 10-15 seconds before testing to allow runtime propagation
- **Subprocess Dependency Rule**: When updating subprocesses, ALWAYS redeploy parent processes to pick up changes. **Exception**: When testing a subprocess standalone via `boomi-test-execute.sh`, deploy the subprocess itself — the runtime needs an independent deployment to reflect your latest push
- **Default Assumption**: Unless user explicitly requests testing, assume they want design-time push only for GUI review

### Instrumenting Processes for Testing

Add Notify steps to inspect document payloads and property values during development.

**When to add Notify steps:**
- After connector calls (REST, Database) to verify response data
- At section boundaries to confirm expected document structure
- Before and after Map steps to verify transformations
- In catch paths to log error details (`meta.base.catcherrorsmessage`)

**Key pattern - log full document payload:**
```xml
<parametervalue key="1" valueType="current"/>
```

**Iterative development workflow:**
1. Build a section of process functionality
2. Add Notify step(s) to log outputs at key points
3. Follow the execution workflow above (deploy → execute → download logs → review)
4. Continue to next section

See `references/steps/notify_step.md` for complete XML patterns and parameter types.