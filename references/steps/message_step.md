# Message Step Reference

## Contents
- Purpose
- THE #1 BOOMI BUG: Quote Escaping Causes Silent Variable Substitution Failures
- CRITICAL GOTCHA WARNING - QUOTE ESCAPING
- Configuration Structure
- Parameter Value Types (full reference: `references/guides/parameter_value_types.md`)
- REMINDER Quote Escaping Rules (CRITICAL)
- Common Patterns
- Message Step Properties
- Reference XML Examples
- TROUBLESHOOTING QUOTE ESCAPING ISSUES

## Purpose
Message steps are template engines that generate content from scratch or with variable substitution. Despite the name, they don't just "send messages" - they create document content using templates with dynamic parameters.

**Use when:**
- Building API request payloads (JSON, XML)
- Creating test data for subprocess testing
- Generating formatted output messages
- Clearing document content (empty message)
- Aggregating data from multiple documents

# **CRITICAL: READ THIS FIRST - ESSENTIAL GOTCHA**

## THE #1 BOOMI BUG: Quote Escaping Causes Silent Variable Substitution Failures

**THIS IS THE MOST COMMON MESSAGE STEP FAILURE MODE - IT FAILS SILENTLY AND SHOWS NO ERRORS**

Before reading anything else, understand this critical pattern:

**NOTE**: This exact same issue affects **Notify steps** (shapetype="notify") as well — full escaping patterns in `references/guides/boomi_error_reference.md` Issue #1.

## **CRITICAL GOTCHA WARNING - QUOTE ESCAPING**
**Single quotes around JSON/XML completely disable variable substitution - NO ERROR IS SHOWN!**

**WRONG - This FAILS silently** (variables appear literally):
```
'{"result": "{1}", "status": "{2}"}'
```
**Output**: `{"result": "{1}", "status": "{2}"}` ← Variables NOT substituted!

**Wrong - ALL JSON must be wrapped** (even if no variable substituion necessary):
```
{"result": "hello", "status": "world"}
```
**Output**: Platform considers `{"result...` an invalid variable argument and errors 

**CORRECT - This WORKS** (variables get substituted):
```
'{"result": "'{1}'", "status": "'{2}'"}'
```
**Output**: `{"result": "actual_value", "status": "success"}` ← Variables substituted!

**CORRECT - ALL JSON must be wrapped** (even if no variable substituion necessary):
```
'{"result": "hello", "status": "world"}'
```
**Output**: `{"result": "hello", "status": "world"}` 

## Configuration Structure
```xml
<shape image="message_icon" name="[shapeName]" shapetype="message" userlabel="[label]" x="[x]" y="[y]">
  <configuration>
    <message combined="false">
      <msgTxt>[template content with {1} placeholders]</msgTxt>
      <msgParameters>
        <parametervalue key="[arbitrary id — GUI writes a 0-based sequence]" valueType="[type]">
          <!-- Value configuration based on type -->
        </parametervalue>
      </msgParameters>
    </message>
  </configuration>
  <dragpoints>
    <dragpoint name="[shapeName].dragpoint1" toShape="[nextShape]" x="[x]" y="[y]"/>
  </dragpoints>
</shape>
```

## Parameter Value Types

Message parameters accept the full standard parameter value set. **See `references/guides/parameter_value_types.md`** for the GUI picker mapping, per-type XML forms, valid valueTypes, substitution/evaluation rules (placeholders map to elements by order — keys are ignored and may have gaps; misses substitute literal `null`; default fallback semantics), Profile Element ID Mapping, and `trackparameter` GUI display requirements.

Message-specific note: `valueType="current"` resolves the document *entering* the Message step — the inbound document the template output replaces.

## REMINDER Quote Escaping Rules (CRITICAL)
Single quotes toggle between "variable substitution mode" and "literal mode":

- **Default mode**: Variables like `{1}` are substituted
- **Single quote enters literal mode**: Everything becomes literal text until the next single quote
- **Single quote exits literal mode**: Back to variable substitution
- **Literal single quote**: Use `''` (two single quotes) to output one literal single quote

### The JSON Variable Pattern (Most Common Gotcha)

**WRONG** - Variables won't substitute:
```
'{
  "user": "{1}",
  "timestamp": "{2}"
}'
```
*Everything inside the outer quotes is literal - `{1}` and `{2}` appear literally in output*

**CORRECT** - Toggle in/out for each variable:
```
'{
  "user": "'{1}'",
  "timestamp": "'{2}'"
}'
```

**Breakdown of correct pattern:**
1. `'` - Enter literal mode (JSON structure)
2. `"user": "` - Literal text
3. `'` - Exit literal mode (enable substitution)
4. `{1}` - Variable gets substituted
5. `'` - Enter literal mode again
6. `"` - Literal quote
7. Continue pattern...

### Quote Toggle Examples

**Simple text with variables:**
```
Hello {1}, today is {2}
```
*No quotes needed - default substitution mode*

**Mixed literal and variables:**
```
'Static text here' but {1} gets substituted 'and this is literal again'
```

**JSON with multiple variables:**
```
'{"name": "'{1}'", "age": '{2}', "active": true}'
```

### Literal Single Quote Escaping (Advanced)

**When you need literal single quotes in output** (e.g., SQL string literals), use `''` as an escape sequence within literal blocks:

```xml
<!-- To output: SELECT 'CURRENT' as TYPE -->
<msgTxt>'{
  "statement": "SELECT ''''CURRENT'''' as TYPE"
}</msgTxt>
```

**How it works:**
- Within literal mode (`'{...}'`), `''` outputs one literal `'` character
- `''''TEXT''''` produces `'TEXT'` in the output
- Each `''` pair = one `'` in the result

**Common use case:** SQL statements with string literals inside JSON payloads

### Literal `{}` Output

Bare `{}` in `<msgTxt>` pushes and deploys cleanly but fails at execution time (`can't parse argument number: ; Caused by: For input string: ""`) — `{` starts a variable reference and the empty argument number cannot parse. To output a literal `{}` (e.g. an empty JSON body), wrap it in single quotes: `<msgTxt>'{}'</msgTxt>`.

## Common Patterns
- Generate JSON/XML payloads with dynamic values
- Create formatted messages combining multiple properties
- Clear document content (empty message)
- Build API request bodies

## Message Step Properties

### Combined Documents Option
The `combined` attribute controls document aggregation behavior:

```xml
<message combined="false">   <!-- Default: Each document processed separately -->
<message combined="true">    <!-- Combine all documents into single output -->
```

With `combined="true"` the template is evaluated once per input document — document-scoped parameters (`track`, `current`, `profile`) resolve against each document, and `keygen`/`unique` advance per document — then the rendered instances concatenate in document order into a single output document. The attribute changes output packaging only; parameter evaluation is identical to `combined="false"`.

**Use combined="true" for:**
- Aggregating multiple document values into single output
- Collecting fields from many documents into one DPP for use on subsequent branch
- Creating batch payloads from multiple inputs

**Example use case:** Process receives 100 documents, each with a customer ID. Use combined="true" Message step to aggregate all IDs into single comma-separated list stored in DPP, then use on next branch.

### Content Creation Flexibility
Message steps can create documents with or without content:
- **Empty message** (`<msgTxt/>`): Clears inherited content, creates empty document
- **Static content**: Pure text with no variables
- **Dynamic content**: Template with {N} variable substitution

## Reference XML Examples

### Message with Mixed Content and Variables
```xml
<shape image="message_icon" name="shape3" shapetype="message" userlabel="This step populates whatever arbitrary content we specify as the downstream document" x="1584.0" y="48.0">
  <configuration>
    <message combined="false">
      <msgTxt>We can populate arbitrary content into the body of this message shape and can populate variables with a format of {1}.

Furthermore we can shift in and out of "variable recognition mode" with a single quote (e.g. if we want to populate arbitrary json in here)

Example:
'
{"first":"hello world",
"second":"'{2}'"}</msgTxt>
      <msgParameters>
        <parametervalue key="0" valueType="track">
          <trackparameter defaultValue="" propertyId="dynamicdocument.DDP_USERNAME" propertyName="Dynamic Document Property - DDP_USERNAME"/>
        </parametervalue>
        <parametervalue key="1" valueType="profile">
          <profileelement elementId="9" elementName="phone (Root/Object/phone)" profileId="75c5b9ff-7e48-40f5-91e7-a4703caa86df" profileType="profile.json"/>
        </parametervalue>
      </msgParameters>
    </message>
  </configuration>
  <dragpoints>
    <dragpoint name="shape3.dragpoint1" toShape="shape6" x="1760.0" y="56.0"/>
  </dragpoints>
</shape>
```

### Empty Message to Clear Document
```xml
<shape image="message_icon" name="shape6" shapetype="message" userlabel="An empty message shape will clear the content and carry on with an empty docuemtn" x="1776.0" y="48.0">
  <configuration>
    <message combined="false">
      <msgTxt/>
      <msgParameters/>
    </message>
  </configuration>
  <dragpoints>
    <dragpoint name="shape6.dragpoint1" toShape="shape9" x="1952.0" y="56.0"/>
  </dragpoints>
</shape>
```

## **TROUBLESHOOTING QUOTE ESCAPING ISSUES**

### When Your Variables Appear Literally in Output

**Symptoms:**
- Process executes successfully (no errors)
- Output shows `{1}`, `{2}`, etc. instead of actual values
- JSON/XML contains literal placeholder text
- No error logs or warnings

**Root Cause:** Single quotes are disabling variable substitution

### Step-by-Step Fix Process

**1. Identify the Problem Pattern**
Look for these WRONG patterns in your `msgTxt`:
```xml
**WRONG** '{"field": "{1}"}'                    <!-- Full JSON wrapped -->
**WRONG** 'Text with {1} variable'              <!-- Text with variables wrapped -->
**WRONG** '<tag>{1}</tag>'                      <!-- XML with variables wrapped -->
```

**2. Apply the Correct Pattern**
Replace with these CORRECT patterns:
```xml
**CORRECT** '{"field": "'{1}'"}'                  <!-- Toggle quotes around variable -->
**CORRECT** 'Text with '{1}' variable'            <!-- Toggle quotes around variable -->
**CORRECT** '<tag>'{1}'</tag>'                    <!-- Toggle quotes around variable -->
```

**3. Verification Checklist**
- [ ] Each `{N}` variable is surrounded by quote toggles: `"'{N}'"`
- [ ] No variables appear between single quotes without toggles
- [ ] Placeholder numbers `{1}…{n}` match the count and XML order of `<parametervalue>` elements (`key` values are irrelevant)

**4. Test the Fix**
- Deploy the corrected process
- Execute with test data
- Verify variables are substituted in output
- Check that JSON/XML is properly formatted

### Common Misconceptions

**"The correct pattern looks wrong"** → This is normal! `"'{1}'"` looks like a syntax error but is correct Boomi syntax.

**"I can mix patterns"** → No! Either use quotes + toggles for the whole message, OR no quotes at all for simple text.

**"GUI and code work the same"** → No! Boomi GUI auto-handles escaping; programmatic generation must manually escape.

### Prevention Strategies

1. **Use templates**: Copy from the templates in `references/guides/boomi_error_reference.md` Issue #1
2. **Pattern match**: Always use `"'{N}'"` for variables within quoted strings
3. **Test early**: Deploy and test immediately after creating Message steps
4. **Double-check**: Scan every `msgTxt` for quote escaping issues before deployment