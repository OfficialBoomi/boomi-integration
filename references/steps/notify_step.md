# Notify Step Reference

## Contents
- Purpose
- Quote Escaping Warning
- Configuration Structure
- Parameter Value Types
- Date Parameter Patterns
- Critical Parameter Indexing Rules
- Critical GUI Display Requirements
- Common Patterns
- Reference XML Examples
- Troubleshooting

## Purpose
Notify steps log messages to execution logs for debugging and monitoring.

**Use when:**
- Debugging execution flow and document state
- Logging property values during development
- Tracking which branch or path was executed
- Capturing API responses after connector calls
- Displaying document content at key process points
- Logging errors in catch paths (especially `meta.base.catcherrorsmessage`)

**Note:** Notify steps allow documents to pass through - they're non-blocking logging statements. The most common notify step error happens when referencing a profile entry variable and receiving an unexpected payload type (e.g. the step references a JSON profile entry but the incoming document to the step is not valid JSON).

## Quote Escaping Warning

Notify steps have the same quote escaping behavior as Message steps. However, **this rarely affects notify steps in practice** because:
- Notify is for logging, not document/JSON construction
- Simple variable substitution doesn't require quotes: `Processing {1} with status {2}`

**If you need quote escaping patterns (i.e. if you're using JSON in the body of your notify step)**, apply the single-quote toggle pattern for curly-brace variable substitution. See references/guides/boomi_error_reference.md Issue #1 for comprehensive escaping patterns and examples.

**Common mistake to avoid:**
```xml
<!-- WRONG - wrapping simple text in quotes (unnecessary) -->
<notifyMessage>'Processing user {1} with status {2}'</notifyMessage>
<!-- Variables appear literally! -->

<!-- CORRECT - no quotes needed for simple logging -->
<notifyMessage>Processing user {1} with status {2}</notifyMessage>
<!-- Variables substitute correctly -->
```

## Configuration Structure
```xml
<shape image="notify_icon" name="[shapeName]" shapetype="notify" userlabel="[label]" x="[x]" y="[y]">
  <configuration>
    <notify disableEvent="true" enableUserLog="false" perExecution="false" title="">
      <notifyMessage>[Message with {1} placeholders]</notifyMessage>
      <notifyMessageLevel>INFO</notifyMessageLevel>
      <notifyParameters>
        <parametervalue key="[1-based index]" valueType="[type]">
          <!-- Value configuration based on type -->
        </parametervalue>
      </notifyParameters>
    </notify>
  </configuration>
  <dragpoints>
    <dragpoint name="[shapeName].dragpoint1" toShape="[nextShape]" x="[x]" y="[y]"/>
  </dragpoints>
</shape>
```

## perExecution Attribute Behavior

The `perExecution` attribute controls how many times the Notify step executes:

| perExecution | Execution Mode | Document Context | Can Access DDPs |
|--------------|----------------|------------------|-----------------|
| `false` (default) | Once per document | Yes | Yes |
| `true` | Once per execution | No | **No - causes error** |

### When perExecution="true" Causes Errors

The error `Attempting dynamic document property extraction with no document` occurs when:
1. The notify step has `perExecution="true"` AND
2. That step's parameters reference document-level data (DDPs, current data, profile elements)

### Safe Use of perExecution="true"

**DO use** when your Notify message uses only:
- Static text
- Process Properties (DPPs)
- Date parameters

**DON'T use** when your Notify message references:
- Dynamic Document Properties (DDPs)
- Current document content (`valueType="current"`)
- Profile element values

`perExecution="true"` does not clear or destroy DDPs. Documents continue flowing to subsequent steps with all DDPs intact. The attribute only affects whether that specific Notify step has document context available. **Important** If the notify step attempts to reference document level data it will hard-break the process and block further execution down that path.

## Parameter Value Types
- **current**: Logs the entire current document
- **track**: References DDPs or DPPs
- **process**: References process properties
- **static**: Hard-coded values
- **date**: Date/time values (current or relative)

Only the types listed above are valid. Other valueTypes (e.g. `document`, `currentdata`) will cause HTTP 400 errors on push.

## Date Parameter Patterns

**Current datetime:**
```xml
<parametervalue key="N" valueType="date">
  <dateparameter dateparametertype="current" datetimemask="yyyyMMdd HHmmss.SSS"/>
</parametervalue>
```

**Relative datetime (with offset):**
```xml
<parametervalue key="N" valueType="date">
  <dateparameter dateparametertype="relative" datetimemask="yyyyMMdd HHmmss.SSS">
    <datedelta sign="minus" unit="minutes" value="73"/>
  </dateparameter>
</parametervalue>
```

**Units:** seconds, minutes, hours, days, weeks, months
**Signs:** plus, minus

## Parameter Substitution: XML Element Order
**Parameters substitute based on XML element order, NOT the key attribute:**
- `{1}` → first `<parametervalue>` element
- `{2}` → second `<parametervalue>` element
- `{3}` → third `<parametervalue>` element

**The `key` attribute is ignored at runtime** - it's a GUI-assigned configuration time identifier that persists through edits.

## **CRITICAL GUI Display Requirements**

**A Programmatic Generation Gotcha**: Missing display attributes cause "null" values in Boomi GUI even though the notify step works at runtime.

### **Required Attributes for GUI Rendering**

**Every `<trackparameter>` element MUST include:**
- **propertyName="Dynamic Document Property - DDP_XXX"** - Human-readable property label for GUI
- **defaultValue=""** - Initializes the default value field (can be empty)

### **WRONG Pattern - Causes GUI Display Issues**
```xml
<!-- Missing GUI display attributes -->
<parametervalue key="1" valueType="track">
  <trackparameter propertyId="dynamicdocument.DDP_CITY"/>
</parametervalue>
```
**Result**: Works at runtime but shows "null" entries in Boomi GUI

### **CORRECT Pattern - Full GUI Compatibility**
```xml
<!-- Complete attributes for proper GUI rendering -->
<parametervalue key="1" valueType="track">
  <trackparameter defaultValue="" propertyId="dynamicdocument.DDP_CITY"
                  propertyName="Dynamic Document Property - DDP_CITY"/>
</parametervalue>
```
**Result**: Works at runtime AND displays properly in Boomi GUI

### **Why This Matters**
- **Runtime**: Process executes correctly either way
- **GUI Experience**: Missing attributes cause confusing "null" displays
- **Team Development**: Other developers see proper labels when reviewing/modifying components
- **Debugging**: Clear property names aid troubleshooting

## Common Patterns
- Log API responses after connector calls
- Display property values for debugging
- Show document content at key process points

## Reference XML Examples

### Logging Current Document
```xml
<shape image="notify_icon" name="shape8" shapetype="notify" userlabel="Notify shapes can show useful info about the data in a process" x="1008.0" y="48.0">
  <configuration>
    <notify disableEvent="true" enableUserLog="false" perExecution="false" title="">
      <notifyMessage>Response from GET: {1}</notifyMessage>
      <notifyMessageLevel>INFO</notifyMessageLevel>
      <notifyParameters>
        <parametervalue key="1" valueType="current"/>
      </notifyParameters>
    </notify>
  </configuration>
  <dragpoints>
    <dragpoint name="shape8.dragpoint1" toShape="shape14" x="1184.0" y="56.0"/>
  </dragpoints>
</shape>
```

### Logging Process Property
```xml
<shape image="notify_icon" name="shape10" shapetype="notify" userlabel="" x="432.0" y="368.0">
  <configuration>
    <notify disableEvent="true" enableUserLog="false" perExecution="false" title="">
      <notifyMessage>The data that reaches the branch shape is passed into all branches. Manipulations of document, and document properties are not carried from branch 1 into branch 2.

Dynamic Process Properties from a previous branch are carried into subsequent branches. E.g. {1}</notifyMessage>
      <notifyMessageLevel>INFO</notifyMessageLevel>
      <notifyParameters>
        <parametervalue key="1" valueType="process">
          <processparameter processproperty="DPP_SAMPLE_PROCESS_PROP" processpropertydefaultvalue=""/>
        </parametervalue>
      </notifyParameters>
    </notify>
  </configuration>
  <dragpoints>
    <dragpoint name="shape10.dragpoint1" toShape="shape11" x="608.0" y="376.0"/>
  </dragpoints>
</shape>
```

### Logging with CDATA Wrapper (Prevents XML Issues)
```xml
<shape image="notify_icon" name="shape6" shapetype="notify" userlabel="FINAL PAYLOAD FROM TEST" x="496.0" y="96.0">
  <configuration>
    <notify disableEvent="true" enableUserLog="false" perExecution="false" title="">
      <notifyMessage>&lt;![{1}]&gt;</notifyMessage>
      <notifyMessageLevel>INFO</notifyMessageLevel>
      <notifyParameters>
        <parametervalue key="1" valueType="current"/>
      </notifyParameters>
    </notify>
  </configuration>
  <dragpoints>
    <dragpoint name="shape6.dragpoint1" toShape="shape7" x="671.0" y="104.0"/>
  </dragpoints>
</shape>
```

## Troubleshooting

**Variables appearing literally in logs?**
- Check for unnecessary single quotes wrapping the entire message
- For simple logging, use: `Processing {1} with status {2}` (no quotes)
- For complex JSON patterns, use single-quote toggle for curly-brace substitution (see references/guides/boomi_error_reference.md Issue #1)

**"null" displays in GUI?**
- Add `propertyName` and `defaultValue` attributes to `<trackparameter>` elements (see GUI Display Requirements above)