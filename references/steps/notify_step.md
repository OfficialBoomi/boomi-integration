# Notify Step Reference

## Contents
- Purpose
- Quote Escaping Warning
- Configuration Structure
- perExecution Attribute Behavior
- Parameter Value Types (full reference: `references/guides/parameter_value_types.md`)
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
        <parametervalue key="[arbitrary id — GUI writes a 0-based sequence]" valueType="[type]">
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

| perExecution | Execution Mode | Document Context |
|--------------|----------------|------------------|
| `false` (default) | Message evaluated once per document (keygen/unique produce a new value per document) | Yes |
| `true` | One aggregated evaluation per execution | No — document-scoped parameters **cause an error** |

### Safe Use of perExecution="true"

**DO use** when your Notify parameters need no document context:
- Static text
- Date/Time parameters
- Execution Properties
- Dynamic Process Properties (DPPs, `valueType="process"`)
- Process Property components (`valueType="definedparameter"`)
- Sequential Value (`keygen`) and Unique Value (`unique`) — evaluated once for the single aggregated entry

**DON'T use** with document-scoped parameters — each fails the path with a type-specific error:

| Parameter type | Error |
|---|---|
| `track` (any document property, incl. DDPs) | `Attempting dynamic document property extraction with no document` |
| `current` | `Attempting document content extraction with no document` |
| `profile` | `Attempting profile value extraction with no document` |

A `trackparameter defaultValue` does not prevent the failure — extraction is attempted before the fallback. The failure sets the execution to ERROR and blocks downstream steps on that path.

`perExecution="true"` does not clear or destroy DDPs. Documents continue flowing to subsequent steps with all DDPs intact. The attribute only affects whether that specific Notify step has document context available. **Important** If the notify step attempts to reference document level data it will hard-break the process and block further execution down that path.

## Parameter Value Types

Notify parameters accept the full standard parameter value set. **See `references/guides/parameter_value_types.md`** for the GUI picker mapping, per-type XML forms, valid valueTypes, substitution/evaluation rules (placeholders map to elements by order, misses substitute literal `null`, default fallback semantics), and `trackparameter` GUI display requirements.

Notify-specific notes:
- `perExecution="true"` restricts which types are usable — see perExecution Attribute Behavior above.
- To log a caught error on a Try/Catch path, use `track` with `meta.base.catcherrorsmessage` (the `errormessage` valueType does NOT resolve caught errors — it substitutes `null`).
- `keygen` and `unique` produce a new value per document when `perExecution="false"`.

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

### Logging a Dynamic Process Property (DPP)
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

### Logging a Process Property Component Value and Execution Metadata
```xml
<shape image="notify_icon" name="shape5" shapetype="notify" userlabel="Log config + execution id" x="656.0" y="48.0">
  <configuration>
    <notify disableEvent="true" enableUserLog="false" perExecution="false" title="">
      <notifyMessage>BatchSize={1} Execution={2}</notifyMessage>
      <notifyMessageLevel>INFO</notifyMessageLevel>
      <notifyParameters>
        <parametervalue key="0" usesEncryption="false" valueType="definedparameter">
          <definedprocessparameter componentId="[componentGuid]" componentName="[Component Name]"
                                   propertyKey="[propertyGuid]" propertyLabel="BatchSize"/>
        </parametervalue>
        <parametervalue key="1" usesEncryption="false" valueType="execution">
          <executionparameter executionproperty="Execution Id"/>
        </parametervalue>
      </notifyParameters>
    </notify>
  </configuration>
  <dragpoints>
    <dragpoint name="shape5.dragpoint1" toShape="shape6" x="832.0" y="56.0"/>
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
- Add `propertyName` and `defaultValue` attributes to `<trackparameter>` elements (see `references/guides/parameter_value_types.md` → GUI Display Requirements)

**Literal `null` in the logged message?**
- A lookup parameter failed to resolve: cross reference miss, document cache miss/unpopulated cache, or profile element on an empty document. These substitute `null` without erroring.

**Process errors at the Notify step with `... extraction with no document`?**
- The step has `perExecution="true"` and a document-scoped parameter (`track`, `current`, or `profile`). See perExecution Attribute Behavior above.
