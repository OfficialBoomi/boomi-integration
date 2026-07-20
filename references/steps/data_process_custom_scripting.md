# Data Process Step: Custom Scripting Reference
## Contents
- Purpose
- Development Philosophy
- Critical Step Naming Convention
- Core Groovy Patterns
- Working with Properties
- Complete Examples
- XML Configuration
- Scripting Languages
- Referencing a Process Script Component
- Critical Rules and Gotchas
- Common Patterns Reference

## Purpose
Custom Scripting is one of the Data Process step's processing steps (Process Type 12) — not a standalone process step; it is configured inside a Data Process shape (see `data_process_step.md`). It executes a script for document manipulation, property management, and transformations that cannot be achieved through standard Boomi components. The script can be written **inline** in the step or stored in a **reusable Process Script component** that the step references (see Referencing a Process Script Component). Either way it may be Groovy (1.5 or 2.4) or JavaScript — see Scripting Languages below. The examples in this reference are Groovy (the default); the `dataContext` contract is identical in every language.

**Groovy scripting is a last resort.** A core Boomi value proposition is that integrations are manageable by humans through the platform UI. Native components (Maps, Decisions, Set Properties, Message steps) are visible, configurable, and debuggable in the GUI. Scripts are opaque — only the original author can maintain them. Always use native Boomi components first, even when scripting would be faster to write.

**Use only when** native components genuinely cannot accomplish the task:
- Transformations that Maps cannot express (e.g., conditional logic across unrelated fields)
- Dynamic property calculations with no Set Properties equivalent
- Parsing truly unstructured data that no profile can model
- Document manipulation that no Data Process type supports

**Groovy is sandboxed.** Scripts cannot make external network calls (HTTP, HTTPS, sockets). For any external communication, use a connector step (REST, HTTP, etc.). Groovy is strictly for in-process data manipulation: parsing, transforming, property management.

**Scripts cannot reference other Boomi components** such as connections, profiles, or maps — they operate only on the raw document streams and properties exposed through `dataContext`. To use those components, build them as their own steps in the process.

**Before writing any Groovy, exhaust these alternatives:**
1. Map step for structured transformations (even complex ones)
2. Message step for content generation
3. Decision/Branch for routing logic
4. Set Properties + concatenation for property manipulation
5. Subprocess with native components for multi-step logic
6. External HTTP/HTTPS calls → REST connector step, never Groovy

## Development Philosophy: Minimalism and Reliability

### Core Principle: Simplest Approach That Works

Boomi's Groovy runtime has limitations. Large, complex scripts often encounter unsupported functionality or performance issues. **Always prefer the simplest, most basic approach.** If you find yourself writing more than a few lines of Groovy, stop and reconsider whether native components can achieve the same result.

**Guiding principles:**
1. **Native components first** — Let Boomi do what Boomi does best. The extra build effort pays for itself in maintainability.
2. **Minimal code** — Fewer lines = fewer failure points
3. **Basic Java/Groovy only** — Avoid advanced language features
4. **No external libraries** — Unless material benefit outweighs complexity (discuss with developer first)
5. **Readable over clever** — Future maintainers should understand instantly

### What to Avoid

**Complex transformations that a Map step can handle:**
```groovy
/* AVOID - Use profiles + Map step for structured transformations */
def transformed = recursiveTransform(data)  /* Complex logic better suited to Map step */
```

**Large scripts:**
```groovy
/* AVOID - Scripts over 50 lines
   If you need this much code, break into multiple Data Process steps
   or use native Boomi components */
```

### What to Prefer

**Simple loops and conditionals:**
```groovy
/* PREFER - Basic Java patterns */
for( int i = 0; i < dataContext.getDataCount(); i++ ) {
    InputStream is = dataContext.getStream(i);
    Properties props = dataContext.getProperties(i);

    /* Simple, clear logic */
    if (someCondition) {
        props.setProperty("document.dynamic.userdefined.DDP_FLAG", "true");
    }

    dataContext.storeStream(is, props);
}
```

**Standard Java utilities:**
```groovy
/* PREFER - Basic Java libraries (always available) */
String timestamp = String.valueOf(System.currentTimeMillis());
String formatted = String.format("ID-%05d", i);
String upper = text.toUpperCase();
```

### When to Stop and Use Other Components

**Decision tree:**

1. **Transforming structured data?** → Use Map step with profiles
2. **Routing based on content?** → Use Decision step
3. **Simple property manipulation?** → Use Set Properties step
4. **Creating new documents?** → Use Message step
5. **Complex multi-step logic?** → Use subprocess with native components
6. **Still need Groovy?** → Keep script under 50 lines, basic patterns only

### Code Complexity Guidelines

**Maximum recommended lengths:**
- **Single script**: <50 lines of logic (excluding imports and dataContext loop)
- **Single operation**: 5-10 lines per operation
- **Decision logic**: 3-4 levels of if/else maximum

**If exceeding these limits:**
1. Break into multiple Data Process steps (chain operations)
2. Use subprocess with native Boomi components
3. Reconsider if Groovy is the right tool

## CRITICAL: Step Naming Convention

**ALWAYS use "Custom Scripting" as the step name attribute**:

```xml
<!-- CORRECT: Generic step name, descriptive userlabel -->
<shape image="dataprocess_icon" name="shape5" shapetype="dataprocess" userlabel="Tag Documents" x="352.0" y="112.0">
  <configuration>
    <dataprocess>
      <step index="1" key="1" name="Custom Scripting" processtype="12">

<!-- WRONG: Custom step name causes GUI display issues -->
<shape image="dataprocess_icon" name="shape3" shapetype="dataprocess" userlabel="Tag Documents" x="592.0" y="240.0">
  <configuration>
    <dataprocess>
      <step index="1" key="1" name="Tag Documents" processtype="12">
```

**Pattern**: Keep step `name="Custom Scripting"` (generic), use shape `userlabel="[descriptive name]"` for identification.

This convention applies to all Data Process step types.

## Core Groovy Patterns

### Mandatory dataContext Loop Pattern

Every Groovy script MUST follow this structure:

```groovy
import java.util.Properties;
import java.io.InputStream;

for( int i = 0; i < dataContext.getDataCount(); i++ ) {
    InputStream is = dataContext.getStream(i);
    Properties props = dataContext.getProperties(i);

    /* Your logic here (keep simple!) */

    dataContext.storeStream(is, props);  /* CRITICAL: Without this, document disappears! */
}
```

**Why this pattern:**
- Boomi processes multiple documents (dataContext.getDataCount())
- Each document has content (InputStream) and properties (Properties)
- **MUST call `dataContext.storeStream()`** or document is dropped from process flow
- Loop handles 1 to N documents automatically

### Stream Management Rules

**Pattern for passthrough (no content modification):**
```groovy
InputStream is = dataContext.getStream(i);
Properties props = dataContext.getProperties(i);

/* Modify properties only, preserve stream */
props.setProperty("document.dynamic.userdefined.DDP_STATUS", "processed");

dataContext.storeStream(is, props);  /* Original stream, updated properties */
```

**Pattern for content modification:**
```groovy
InputStream is = dataContext.getStream(i);
Properties props = dataContext.getProperties(i);

/* Read and modify content */
String content = new String(is.readAllBytes(), "UTF-8");
String modified = content.replace("old", "new");

/* Create new stream from modified content */
InputStream newStream = new ByteArrayInputStream(modified.getBytes("UTF-8"));
dataContext.storeStream(newStream, props);
```

## Working with Properties

### Dynamic Document Properties (DDPs)

**Critical Prefix**: All user-defined DDPs MUST use: `document.dynamic.userdefined.`

```groovy
/* Getting DDPs */
String fileName = props.getProperty("document.dynamic.userdefined.DDP_FILENAME");
String status = props.getProperty("document.dynamic.userdefined.DDP_STATUS");

/* Setting DDPs (never set null!) */
if (newValue != null) {
    props.setProperty("document.dynamic.userdefined.DDP_STATUS", newValue);
}
```

**Critical rules:**
- **Never set null values** - causes NullPointerException at assignment time
- **Always use full prefix** - `document.dynamic.userdefined.` is mandatory
- **Property names are case-sensitive**
- **All values are Strings** - convert numbers/booleans explicitly

**Common patterns:**
```groovy
/* Check if property exists */
String value = props.getProperty("document.dynamic.userdefined.DDP_CUSTOM_ID");
if (value != null) {
    /* Property exists, use it */
}

/* Set with default */
String priority = props.getProperty("document.dynamic.userdefined.DDP_PRIORITY");
if (priority == null) {
    props.setProperty("document.dynamic.userdefined.DDP_PRIORITY", "normal");
}

/* Numeric properties (store as String) */
int counter = 0;
String counterStr = props.getProperty("document.dynamic.userdefined.DDP_COUNTER");
if (counterStr != null) {
    counter = Integer.parseInt(counterStr);
}
counter++;
props.setProperty("document.dynamic.userdefined.DDP_COUNTER", String.valueOf(counter));
```

### Dynamic Process Properties (DPPs)

Process-wide properties accessed via ExecutionUtil (shared across all documents in execution):

```groovy
import com.boomi.execution.ExecutionUtil;

/* Get DPP (always returns String or null) */
String batchId = ExecutionUtil.getDynamicProcessProperty("DPP_BATCH_ID");

/* Set DPP (value must be String, never null)
   persist=false: memory only (faster, lost on restart)
   persist=true: survives restart (slower, disk write) */
ExecutionUtil.setDynamicProcessProperty("DPP_COUNTER", "100", false);

/* Check and initialize pattern */
String sessionId = ExecutionUtil.getDynamicProcessProperty("DPP_SESSION_ID");
if (sessionId == null) {
    sessionId = "SESSION_" + System.currentTimeMillis();
    ExecutionUtil.setDynamicProcessProperty("DPP_SESSION_ID", sessionId, false);
}
```

**DPP vs DDP comparison:**

| Feature | DDP | DPP |
|---------|-----|-----|
| Scope | Per document | Per process execution |
| Access | via Properties object | via ExecutionUtil |
| Prefix | `document.dynamic.userdefined.` | No prefix |
| Persistence | Always with document | Always within a process execution, Optional across executions within the same process (persist parameter) |
| Use case | Document-specific data | Execution-wide state |

## Complete Examples

### Basic Document Passthrough with Property Tagging

```groovy
import java.util.Properties;
import java.io.InputStream;

for( int i = 0; i < dataContext.getDataCount(); i++ ) {
    InputStream is = dataContext.getStream(i);
    Properties props = dataContext.getProperties(i);

    /* Tag document with sequence number */
    props.setProperty("document.dynamic.userdefined.DDP_SEQUENCE", String.valueOf(i + 1));
    props.setProperty("document.dynamic.userdefined.DDP_TOTAL_COUNT", String.valueOf(dataContext.getDataCount()));

    dataContext.storeStream(is, props);
}
```

### Simple Content Transformation

```groovy
import java.util.Properties;
import java.io.InputStream;
import java.io.ByteArrayInputStream;

for( int i = 0; i < dataContext.getDataCount(); i++ ) {
    InputStream is = dataContext.getStream(i);
    Properties props = dataContext.getProperties(i);

    /* Read content */
    String content = new String(is.readAllBytes(), "UTF-8");

    /* Replace arbitrary string placeholder ({{...}} is not special Boomi syntax) */
    String modified = content.replace("{{timestamp}}", String.valueOf(System.currentTimeMillis()));

    /* Update properties */
    props.setProperty("document.dynamic.userdefined.DDP_TRANSFORMED", "true");

    /* Store with new stream */
    InputStream newStream = new ByteArrayInputStream(modified.getBytes("UTF-8"));
    dataContext.storeStream(newStream, props);
}
```

### Batch Processing with DPPs

```groovy
import java.util.Properties;
import java.io.InputStream;
import com.boomi.execution.ExecutionUtil;

/* Process-level setup (runs once for first document) */
String batchId = ExecutionUtil.getDynamicProcessProperty("DPP_BATCH_ID");
if (batchId == null) {
    batchId = "BATCH_" + System.currentTimeMillis();
    ExecutionUtil.setDynamicProcessProperty("DPP_BATCH_ID", batchId, false);
}

/* Initialize counter */
String counterStr = ExecutionUtil.getDynamicProcessProperty("DPP_COUNTER");
int counter = (counterStr != null) ? Integer.parseInt(counterStr) : 0;

/* Document processing */
for( int i = 0; i < dataContext.getDataCount(); i++ ) {
    InputStream is = dataContext.getStream(i);
    Properties props = dataContext.getProperties(i);

    /* Increment counter */
    counter++;

    /* Tag document with batch info */
    props.setProperty("document.dynamic.userdefined.DDP_BATCH_ID", batchId);
    props.setProperty("document.dynamic.userdefined.DDP_BATCH_SEQUENCE", String.valueOf(counter));

    dataContext.storeStream(is, props);
}

/* Update process counter */
ExecutionUtil.setDynamicProcessProperty("DPP_COUNTER", String.valueOf(counter), false);
```

## XML Configuration
```
<step index="1" key="1" name="Custom Scripting" processtype="12">
  <dataprocessscript language="groovy2" useCache="true">
    <script><![CDATA[
      import java.util.Properties;
      import java.io.InputStream;

      for( int i = 0; i < dataContext.getDataCount(); i++ ) {
          InputStream is = dataContext.getStream(i);
          Properties props = dataContext.getProperties(i);

          /* Your logic here */

          dataContext.storeStream(is, props);
      }
    ]]></script>
  </dataprocessscript>
</step>
```

**Configuration attributes:**
- `language` (**required**): script engine token — `groovy2` (Groovy 2.4, default), `groovy` (Groovy 1.5), `javascript` (JavaScript). See Scripting Languages below. Without it, runtime fails with "Failed loading script engine null".
- `useCache="true"` (**recommended**): script compilation caching flag. Not required for execution — a step runs to completion whether `useCache` is `"true"`, `"false"`, or omitted — but set `"true"` to mirror the platform default.

## Scripting Languages
The `language` attribute on an **inline** `<dataprocessscript>` selects the engine. The engine actually used is echoed in the process execution log as `[1] Scripting: <token>`.

| GUI label | `language` token(s), inline |
|-----------|-----------------------------|
| Groovy 2.4 | `groovy2` |
| Groovy 1.5 | `groovy` |
| JavaScript | `javascript` |

- **Default to `groovy2`** — it matches the rest of the skill's scripting and the examples above. Avoid Groovy 1.5 (`groovy`) for new work.
- The token must match the source language: JavaScript source under `language="groovy"` fails at runtime with a Groovy `MultipleCompilationErrorsException` (`status=ERROR`, no output document). The runtime logs a `Script compilation failed, falling back to evaluated mode` WARNING and recompiles once first — this is not a recovery; the execution still ends in ERROR.
- JavaScript runs on the Nashorn engine: access Java classes via `Packages`/`importClass`, and `class` declarations are not supported. The `dataContext` API is identical to Groovy.

## Referencing a Process Script Component
The script body may live in a standalone, reusable **Process Script component** (`type="script.processing"`) instead of inline — the component-backed alternative, analogous to Map Scripting components. Reference it by adding `useComponent="true"` and `componentId` to `<dataprocessscript>`:

```xml
<step index="1" key="1" name="Custom Scripting" processtype="12">
  <dataprocessscript componentId="[SCRIPT_PROCESSING_GUID]" language="groovy2" useCache="true" useComponent="true">
    <script><![CDATA[
      import java.util.Properties;
      import java.io.InputStream;
      for( int i = 0; i < dataContext.getDataCount(); i++ ) {
          dataContext.storeStream(dataContext.getStream(i), dataContext.getProperties(i));
      }
    ]]></script>
  </dataprocessscript>
</step>
```

- `useComponent="true"` is the switch: the runtime executes the referenced component's script and **ignores the inline `<script>` body**. Keep a valid passthrough placeholder there (a `dataContext` loop that just re-stores each stream).
- When `useComponent="true"`, the reference's own `language` attribute is **inert** — the referenced component's `language` governs the engine. (When `useComponent="false"`, the reference's `language` governs the inline body.)
- Choose inline vs. component on reuse: inline for a script used by one step; a Process Script component when the same script is (or may be) shared across steps/processes. See `references/components/process_script_component.md` for the component body, its language tokens, and the build order.
- **Redeploy after editing the component.** The referenced component is captured at the process's deploy time. After editing a referenced `script.processing` component, redeploy every process that references it, or it keeps running the previously deployed version.

**CDATA is a push-side authoring convenience, not the canonical storage form.** The platform accepts both CDATA-wrapped and entity-escaped `<script>` bodies on push; they are stored identically. On pull, the platform always returns the `<script>` body as entity-escaped plain text (`<` → `&lt;`, `&` → `&amp;`) — the CDATA envelope is stripped regardless of how it was pushed. Tools that pull, edit, and re-push groovy components do not need to re-wrap in CDATA; the pulled form is itself a legal push body.

## Critical Rules and Gotchas

### Rule #1: Always Call storeStream()
**ALWAYS call `dataContext.storeStream()`** or document vanishes from process flow.

```groovy
/* WRONG - Document disappears! */
for( int i = 0; i < dataContext.getDataCount(); i++ ) {
    InputStream is = dataContext.getStream(i);
    Properties props = dataContext.getProperties(i);

    props.setProperty("document.dynamic.userdefined.processed", "true");
    /* Missing storeStream() - DOCUMENT LOST! */
}

/* CORRECT */
for( int i = 0; i < dataContext.getDataCount(); i++ ) {
    InputStream is = dataContext.getStream(i);
    Properties props = dataContext.getProperties(i);

    props.setProperty("document.dynamic.userdefined.processed", "true");
    dataContext.storeStream(is, props);  /* Document preserved */
}
```

### Rule #2: Never Set Null Property Values
**Never set null DDP values** - throws NullPointerException at assignment time.

```groovy
/* WRONG - Throws NullPointerException */
String value = someMethodThatReturnsNull();
props.setProperty("document.dynamic.userdefined.field", value);  /* FAILS if value is null! */

/* CORRECT - Check before setting */
String value = someMethodThatReturnsNull();
if (value != null) {
    props.setProperty("document.dynamic.userdefined.field", value);
}
```

### Rule #3: DDP Prefix Required
**DDP prefix required**: All user-defined properties MUST use `document.dynamic.userdefined.` prefix.

```groovy
/* WRONG - Won't work as expected */
props.setProperty("custom_field", "value");

/* CORRECT */
props.setProperty("document.dynamic.userdefined.DDP_CUSTOM_FIELD", "value");
```

### Rule #4: DPPs Are Always Strings
**DPPs are always Strings** - convert numbers explicitly.

```groovy
/* WRONG - Type error */
ExecutionUtil.setDynamicProcessProperty("DPP_COUNTER", 100, false);

/* CORRECT - Convert to String */
ExecutionUtil.setDynamicProcessProperty("DPP_COUNTER", String.valueOf(100), false);

/* Reading back */
String counterStr = ExecutionUtil.getDynamicProcessProperty("DPP_COUNTER");
int counter = Integer.parseInt(counterStr);
```

### Rule #5: Keep Scripts Minimal
**Large scripts hit unsupported functionality** - keep under 50 lines of logic.

```groovy
/* If you need more than this...stop and reconsider approach! */
import java.util.Properties;
import java.io.InputStream;

for( int i = 0; i < dataContext.getDataCount(); i++ ) {
    InputStream is = dataContext.getStream(i);
    Properties props = dataContext.getProperties(i);

    /* 10-40 lines of simple logic max
       If more needed: break into multiple steps or use native components */

    dataContext.storeStream(is, props);
}
```

## Common Patterns Reference

### Reading Document Content
```groovy
/* Read as String (most common) */
InputStream is = dataContext.getStream(i);
String content = new String(is.readAllBytes(), "UTF-8");
```

### Writing New Content
```groovy
/* From String */
String newContent = "{ \"status\": \"success\" }";
InputStream newStream = new ByteArrayInputStream(newContent.getBytes("UTF-8"));
dataContext.storeStream(newStream, props);
```

### JSON Handling
`groovy.json.JsonSlurper` is available in Boomi's Groovy 2.4 runtime. Prefer Map steps for structured transformations, but JsonSlurper is useful for filtering or conditional logic that Maps can't express.

```groovy
def data = new groovy.json.JsonSlurper().parseText(content)
props.setProperty("document.dynamic.userdefined.DDP_STATUS", data.status ?: "")
```

### Debugging with Logging
Use ExecutionUtil.getBaseLogger() to write to process execution logs:

```groovy
import com.boomi.execution.ExecutionUtil;
import java.util.logging.Logger;

Logger logger = ExecutionUtil.getBaseLogger();

for( int i = 0; i < dataContext.getDataCount(); i++ ) {
    InputStream is = dataContext.getStream(i);
    Properties props = dataContext.getProperties(i);

    /* Log to process execution logs */
    logger.info("Processing document " + (i+1) + " of " + dataContext.getDataCount());
    logger.warning("Missing required property: DDP_CUSTOMER_ID");

    dataContext.storeStream(is, props);
}
```

**Critical:** This is the primary debugging mechanism in Boomi. Logs appear in process execution reports.

### Property Validation
```groovy
/* Validate required property exists */
String requiredField = props.getProperty("document.dynamic.userdefined.DDP_CUSTOMER_ID");
if (requiredField == null || requiredField.trim().isEmpty()) {
    props.setProperty("document.dynamic.userdefined.DDP_VALIDATION_ERROR", "Missing customer_id");
    props.setProperty("document.dynamic.userdefined.DDP_IS_VALID", "false");
} else {
    props.setProperty("document.dynamic.userdefined.DDP_IS_VALID", "true");
}
```

### Error Handling (Keep Simple!)
```groovy
import java.util.Properties;
import java.io.InputStream;
import java.io.ByteArrayInputStream;

for( int i = 0; i < dataContext.getDataCount(); i++ ) {
    InputStream is = dataContext.getStream(i);
    Properties props = dataContext.getProperties(i);

    try {
        String content = new String(is.readAllBytes(), "UTF-8");
        String result = simpleTransformation(content);  /* Keep simple! */

        InputStream newStream = new ByteArrayInputStream(result.getBytes("UTF-8"));
        props.setProperty("document.dynamic.userdefined.DDP_STATUS", "success");
        dataContext.storeStream(newStream, props);

    } catch (Exception e) {
        /* Tag error, let process handle it */
        props.setProperty("document.dynamic.userdefined.DDP_STATUS", "error");
        props.setProperty("document.dynamic.userdefined.DDP_ERROR_MESSAGE", e.getMessage());
        dataContext.storeStream(is, props);  /* Passthrough on error */
    }
}
```

### Performance Considerations
```groovy
/* BAD - Creates new object in every iteration */
for( int i = 0; i < dataContext.getDataCount(); i++ ) {
    InputStream is = dataContext.getStream(i);
    Properties props = dataContext.getProperties(i);

    String timestamp = new java.util.Date().toString();  /* Wasteful! */
    props.setProperty("document.dynamic.userdefined.DDP_TIMESTAMP", timestamp);

    dataContext.storeStream(is, props);
}

/* GOOD - Create once, reuse */
String batchTimestamp = new java.util.Date().toString();
for( int i = 0; i < dataContext.getDataCount(); i++ ) {
    InputStream is = dataContext.getStream(i);
    Properties props = dataContext.getProperties(i);

    props.setProperty("document.dynamic.userdefined.DDP_TIMESTAMP", batchTimestamp);

    dataContext.storeStream(is, props);
}
```
