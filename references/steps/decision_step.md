# Decision Step

## Contents
- Purpose
- Key Concepts
- Comparison Types
- Building Instructions
- Date Comparison Notes
- Common Patterns
- Important Notes
- Common Gotchas
- Testing Considerations
- XML Reference
- Best Practices

## Purpose
The decision step evaluates a condition and routes documents down either a "true" or "false" path based on the comparison result. It's Boomi's equivalent of an if/then statement, enabling conditional logic in integration processes.

**Use when:**
- Conditional routing based on property values or profile fields
- Implementing if/then logic workflows
- Routing documents based on field comparisons
- Routing execution based on status, flags, or thresholds

## Key Concepts

### Binary Routing
- **True Path** (`identifier="true"`): Taken when the condition evaluates to true
- **False Path** (`identifier="false"`): Taken when the condition evaluates to false
- Both paths must be connected (even if false path goes directly to stop)

### Comparison Values
Decision steps compare two values:
1. **Left Side**: The value being tested (often dynamic)
2. **Right Side**: The value to compare against (can be static or dynamic)

### Value Sources
Values can come from:
- `track`: Document properties (DDPs/DPPs)
- `profile`: Document fields from profiles
- `static`: Hard-coded values
- `date`: Date/time values (current or specific)

### Display Names
To set a meaningful display name for a decision step (visible in the UI and logs), you must set **both**:
1. `userlabel` attribute on the `<shape>` element
2. `name` attribute on the `<decision>` element (inside `<configuration>`)

Both attributes should contain the same value. If either is missing or empty, the display name will not render properly.

## Comparison Types

### equals
Exact match comparison (case-sensitive for strings).
```xml
<decision comparison="equals">
  <decisionvalue valueType="track">
    <trackparameter propertyId="dynamicdocument.DDP_TEST"/>
  </decisionvalue>
  <decisionvalue valueType="profile">
    <profileelement elementId="3" elementName="item1" profileId="..."/>
  </decisionvalue>
</decision>
```

### greaterthaneq / lessthaneq / greaterthan / lessthan
Numeric and date comparisons.
```xml
<decision comparison="greaterthaneq">
  <decisionvalue valueType="date">
    <dateparameter dateparametertype="current" datetimemask="yyyyMMdd HHmmss.SSS"/>
  </decisionvalue>
  <decisionvalue valueType="track">
    <trackparameter propertyId="dynamicdocument.DDP_TEST_DATE"/>
  </decisionvalue>
</decision>
```

### regex
Regular expression pattern matching. The pattern is on the right side.
```xml
<decision comparison="regex">
  <decisionvalue valueType="profile">
    <profileelement elementId="9" elementName="Email" profileId="..."/>
  </decisionvalue>
  <decisionvalue valueType="static">
    <staticparameter staticproperty="^([a-zA-Z0-9._%-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,6})*$"/>
  </decisionvalue>
</decision>
```

### wildcard
Simple pattern matching using * (any characters) and ? (single character).
```xml
<decision comparison="wildcard">
  <decisionvalue valueType="process">
    <processparameter processproperty="DPP_TEST"/>
  </decisionvalue>
  <decisionvalue valueType="static">
    <staticparameter staticproperty="*@boomi.com"/>
  </decisionvalue>
</decision>
```

### Checking for Empty Values
The Decision step has no `isempty` comparison type. To check if a value is empty, use `comparison="equals"` with an empty static value. The true path fires when the value IS empty; the false path fires when it has content.
```xml
<decision comparison="equals">
  <decisionvalue valueType="track">
    <trackparameter defaultValue="" propertyId="dynamicdocument.DDP_FIELD_TO_CHECK" propertyName="Dynamic Document Property - DDP_FIELD_TO_CHECK"/>
  </decisionvalue>
  <decisionvalue valueType="static">
    <staticparameter staticproperty=""/>
  </decisionvalue>
</decision>
```
To check "is NOT empty", use the same pattern but swap your true/false path logic.

## Building Instructions

### Step 1: Add Decision Step
Place the decision shape on the canvas.

### Step 2: Set Display Name
Configure both required name attributes with an identical, descriptive value:
- `userlabel` on the `<shape>` element
- `name` on the `<decision>` element

Example: "Check Email Valid", "Order Status Is Complete", "Date In Range"

### Step 3: Configure Comparison
Set the comparison type and both values to compare.

### Step 4: Connect Both Paths
- Connect the true dragpoint to the logic for successful condition
- Connect the false dragpoint to alternative logic (or stop step)

### Step 5: Test Both Branches
Ensure test data exercises both true and false paths.

## Date Comparison Notes

### Date Formats
When comparing dates, ensure consistent formatting:
- Use `datetimemask` to specify format
- Common masks: `yyyyMMdd`, `yyyy-MM-dd'T'HH:mm:ss.SSS'Z'`
- Current date can use `dateparametertype="current"`

### Date Comparison Order
Be careful with comparison direction:
- `current date >= stored date`: Is the current date on or after the stored date?
- `stored date >= current date`: Has the stored date passed?

## Common Patterns

### Null/Empty Checking
Check if a field is empty by comparing against an empty static value (see "Checking for Empty Values" above). To check "is not empty", use the same equals-empty pattern and swap your true/false path wiring.

### Email Validation
Using regex for email format:
```xml
<staticparameter staticproperty="^([a-zA-Z0-9._%-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,6})*$"/>
```

### Domain Filtering
Using wildcard for domain checking:
```xml
<staticparameter staticproperty="*@yourdomain.com"/>
```

### Error Routing
Check for error keywords using wildcard pattern:
```xml
<decision comparison="wildcard">
  <decisionvalue valueType="track">
    <trackparameter propertyId="meta.base.catcherrorsmessage"/>
  </decisionvalue>
  <decisionvalue valueType="static">
    <staticparameter staticproperty="*404*"/>
  </decisionvalue>
</decision>
```

## Important Notes

### String Comparisons
- `equals`: Case-sensitive exact match
- `wildcard`: Case-sensitive pattern (use `*substring*` for contains-like behavior)
- For case-insensitive, transform to lowercase first using a map

### Numeric Comparisons
- Values are compared as strings unless both are numeric
- Ensure consistent number formats (no commas, consistent decimals)
- Leading zeros can cause string comparison behavior

### Empty vs Null
- Empty string ("") and null are different
- The equals-empty-static pattern catches empty string; null profile elements may need additional handling
- Profile elements that don't exist return null

## Common Gotchas

1. **Unconnected False Path**: Always connect both dragpoints, even if false goes to stop
2. **Type Mismatches**: Comparing "100" (string) with 100 (number) may not work as expected
3. **Date Format Mismatches**: Ensure both dates use same format/mask
4. **Regex Escaping**: Remember to escape special regex characters
5. **Wildcard Limitations**: Only * and ? supported

## Testing Considerations

### Common Test Scenarios
1. **Equals**: Exact match, case differences, trailing spaces
2. **Numeric**: Boundary values, negative numbers, decimals
3. **Dates**: Past, future, today, different formats
4. **Regex**: Valid patterns, edge cases, empty input
5. **Wildcard**: Multiple matches, no matches, special characters

## XML Reference

### Basic Decision Structure
```xml
<shape image="decision_icon" name="shape22" shapetype="decision" userlabel="Check Item Match" x="528.0" y="544.0">
  <configuration>
    <decision comparison="equals" name="Check Item Match">
      <decisionvalue valueType="track">
        <trackparameter defaultValue="" propertyId="dynamicdocument.DDP_TEST" 
                       propertyName="Dynamic Document Property - DDP_TEST"/>
      </decisionvalue>
      <decisionvalue valueType="profile">
        <profileelement elementId="3" elementName="item1 (Root/Object/item1)" 
                       profileId="8aa8e4ca-e5ef-497f-84ae-adb50f871c4b" 
                       profileType="profile.json"/>
      </decisionvalue>
    </decision>
  </configuration>
  <dragpoints>
    <dragpoint identifier="true" name="shape22.dragpoint1" text="True" 
              toShape="shape23" x="720.0" y="536.0"/>
    <dragpoint identifier="false" name="shape22.dragpoint2" text="False" 
              toShape="shape21" x="688.0" y="664.0"/>
  </dragpoints>
</shape>
```

**Display Name Note**: Both `userlabel` (on shape) and `name` (on decision) must be set to the same value for the display name to appear correctly in the Boomi UI.

## Best Practices

### Use Decision Steps For
- Routing based on data values
- Error type determination
- Business rule implementation
- Validation checks before processing

### Decision Chain Guidelines
When chaining multiple decisions:
1. Order from most to least likely (optimize for common path)
2. Check for nulls/empty first to avoid errors
3. Use clear userlabels to document each condition
4. Consider combining into business rules if > 3-4 decisions