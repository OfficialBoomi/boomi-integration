# Message Step Reference

## Contents
- Purpose
- Critical Quote Escaping Gotcha
- Parameter Indexing Rules
- Configuration Structure
- Parameter Value Types
- Date Parameter Patterns
- GUI Display Requirements
- Quote Escaping Rules
- Common Patterns
- Message Step Properties
- Reference XML Examples
- Troubleshooting

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

**NOTE**: This exact same issue affects **Notify steps** (shapetype="notify") - see **notify_step.md** for details.

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

## Parameter Substitution: XML Element Order
**Parameters substitute based on XML element order, NOT the key attribute:**
- `{1}` → first `<parametervalue>` element
- `{2}` → second `<parametervalue>` element
- `{3}` → third `<parametervalue>` element

**The `key` attribute is ignored at runtime** - it's a GUI-assigned configuration time identifier that persists through edits.

## Configuration Structure
```xml
<shape image="message_icon" name="[shapeName]" shapetype="message" userlabel="[label]" x="[x]" y="[y]">
  <configuration>
    <message combined="false">
      <msgTxt>[template content with {1} placeholders]</msgTxt>
      <msgParameters>
        <parametervalue key="[1-based index]" valueType="[type]">
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
- **static**: Hard-coded values
- **track**: References to DDPs or DPPs
- **profile**: References to profile elements
- **current**: The current document content
- **date**: Date/time values (current or relative)

### Profile Element ID Mapping
**CRITICAL:** When referencing profile elements, the `elementId` must match the `key` attribute from the profile XML, and `elementName` must follow the GUI display format.

**Profile XML structure:**
```xml
<XMLElement dataType="character" key="6" name="Name" ...>           <!-- Root level -->
<XMLElement dataType="character" key="61" name="Name" ...>          <!-- Nested: Account/Name -->
<XMLElement dataType="character" key="149" name="Email" ...>        <!-- Nested: Owner/Email -->
```

**Correct reference with GUI format:**
```xml
<!-- Root-level field -->
<parametervalue key="1" valueType="profile">
  <profileelement elementId="6" elementName="Name (Opportunity/Name)" profileId="..." profileType="profile.xml"/>
</parametervalue>

<!-- Nested field (1 level) -->
<parametervalue key="2" valueType="profile">
  <profileelement elementId="61" elementName="Name (Opportunity/Account/Name)" profileId="..." profileType="profile.xml"/>
</parametervalue>

<!-- Nested field (2 levels) -->
<parametervalue key="3" valueType="profile">
  <profileelement elementId="149" elementName="Email (Opportunity/Owner/Email)" profileId="..." profileType="profile.xml"/>
</parametervalue>
```

**elementName Format Rule:**
- Pattern: `FieldName (RootElement/Full/Path/To/FieldName)`
- Use the final segment as the field name before the parentheses
- Include complete XPath from document root in parentheses
- This format ensures proper GUI display (runtime ignores it but human readability requires correct format)

**Wrong - causes incorrect GUI display:**
```xml
<profileelement elementId="6" elementName="Name" .../>              <!-- Missing path notation -->
<profileelement elementId="61" elementName="Account/Name" .../>     <!-- Wrong format -->
```

To find the correct `elementId`, you MUST search the profile XML for `<XMLElement ... name="FieldName"` and use its `key` attribute value.

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

## Parameter Substitution Rules

**XML element order determines substitution:**
```xml
<msgTxt>Hello {1}, your order {2} totals ${3}</msgTxt>
<msgParameters>
  <!-- {1} → first element (key value irrelevant) -->
  <parametervalue key="0" valueType="track">
    <trackparameter propertyId="dynamicdocument.DDP_CUSTOMER_NAME"/>
  </parametervalue>
  <!-- {2} → second element -->
  <parametervalue key="1" valueType="track">
    <trackparameter propertyId="dynamicdocument.DDP_ORDER_ID"/>
  </parametervalue>
  <!-- {3} → third element -->
  <parametervalue key="2" valueType="track">
    <trackparameter propertyId="dynamicdocument.DDP_ORDER_TOTAL"/>
  </parametervalue>
</msgParameters>
```

**Key values can have gaps** (from GUI deletions) without affecting substitution:
```xml
<msgTxt>{1} {2} {3}</msgTxt>
<msgParameters>
  <parametervalue key="2" valueType="static"><staticparameter staticproperty="first"/></parametervalue>
  <parametervalue key="4" valueType="static"><staticparameter staticproperty="second"/></parametervalue>
  <parametervalue key="5" valueType="static"><staticparameter staticproperty="third"/></parametervalue>
</msgParameters>
<!-- Output: "first second third" -->
```

**This applies to Notify steps as well** - both use XML element order for parameter substitution.

## **CRITICAL GUI Display Requirements**

**A Programmatic Generation Gotcha**: Missing display attributes cause "null" values in Boomi GUI even though the message step works at runtime.

### **Required Attributes for GUI Rendering**

**Every `<trackparameter>` element MUST include:**
- **propertyName="Dynamic Document Property - DDP_XXX"** - Human-readable property label for GUI
- **defaultValue=""** - Initializes the default value field (can be empty)

### **WRONG Pattern - Causes GUI Display Issues**
```xml
<!-- Missing GUI display attributes -->
<parametervalue key="1" valueType="track">
  <trackparameter propertyId="dynamicdocument.DDP_ORDER_ID"/>
</parametervalue>
```
**Result**: Works at runtime but shows "null" entries in Boomi GUI

### **CORRECT Pattern - Full GUI Compatibility**
```xml
<!-- Complete attributes for proper GUI rendering -->
<parametervalue key="1" valueType="track">
  <trackparameter defaultValue="" propertyId="dynamicdocument.DDP_ORDER_ID"
                  propertyName="Dynamic Document Property - DDP_ORDER_ID"/>
</parametervalue>
```
**Result**: Works at runtime AND displays properly in Boomi GUI

### **Why This Matters**
- **Runtime**: Process executes correctly either way
- **GUI Experience**: Missing attributes cause confusing "null" displays
- **Team Development**: Other developers see proper labels when reviewing/modifying components
- **Debugging**: Clear property names aid troubleshooting

**Note**: This same pattern applies to Notify steps - both Message and Notify steps use identical `<trackparameter>` syntax.

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
- [ ] Parameter keys are 1-based: key="1", key="2", key="3"
- [ ] Parameter keys match placeholder numbers exactly

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