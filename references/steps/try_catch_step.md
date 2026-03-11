# Try/Catch Step (catcherrors)

## Contents
- Purpose
- Key Concepts
- Common Pattern
- Configuration Elements
- Building Instructions
- Important Notes
- Common Gotchas
- XML Reference
- Typical Error Handler Pattern
- Best Practices
- Testing Considerations

## Purpose
The try/catch step provides exception handling in Boomi processes, allowing you to gracefully handle errors and optionally retry operations. It creates two execution paths: a "Try" path for normal execution and a "Catch" path for error handling.

**Use when:**
- Wrapping segments that may fail
- Implementing process-wide error handling (place directly after Start step)
- Retrying failed operations before escalating to error handling
- Gracefully handling and logging errors without process failure

## Key Concepts

### Dual Path Structure
- **Try Path** (`identifier="default"`): Normal execution path where your process logic runs
- **Catch Path** (`identifier="error"`): Error handling path executed when exceptions occur in the try block

### Retry Mechanism
The step can automatically retry the try path logic before falling through to the catch path. Set `retryCount` to control retry attempts (0 = no retry, just catch).

### Error Scope
- `catchAll="true"`: Catches all errors from any step in the try path
- `catchAll="false"`: Only catches specific configured error types (advanced use)

### Error Message Access
When an error is caught, Boomi populates the `meta.base.catcherrorsmessage` document property with the error details. This is commonly displayed using a notify step on the catch path.

## Common Pattern
The catch path typically leads to a notify step that displays the error message:
```xml
<!-- Notify step following catch path -->
<shape image="notify_icon" shapetype="notify">
  <configuration>
    <notify>
      <notifyMessage>{1}</notifyMessage>
      <notifyParameters>
        <parametervalue key="1" valueType="track">
          <trackparameter propertyId="meta.base.catcherrorsmessage" 
                         propertyName="Base - Try/Catch Message"/>
        </parametervalue>
      </notifyParameters>
    </notify>
  </configuration>
</shape>
```
**Note:** Placeholders are 1-based (`{1}`, `{2}`, `{3}`) and map to `<parametervalue>` elements by XML order, not key attribute. See references/steps/notify_step.md for complete parameter substitution rules and XML reference.

## Configuration Elements

### Basic Try/Catch
- `catchAll`: Boolean - whether to catch all errors or specific types
- `retryCount`: Number of retry attempts before executing catch path

### Canvas Positioning
The try/catch step requires two dragpoints:
1. Default dragpoint for the try path
2. Error dragpoint for the catch path

## Building Instructions

### Step 1: Create the Try/Catch Step
Add the catcherrors shape to the canvas with proper configuration.

### Step 2: Connect the Try Path
Connect the default dragpoint to your normal process logic.

### Step 3: Connect the Catch Path  
Connect the error dragpoint to your error handling logic (typically a notify step).

### Step 4: Configure Retry Behavior
Set appropriate retry count based on your use case:
- `0`: No retry, immediate error handling
- `1-3`: Common retry counts for transient errors

## Important Notes

### Error Scope: Document vs Batch
- Try/catch operates at **document level** - individual documents can error and route to catch while others continue
- **Exception**: Groovy script failures in Data Process steps cause **batch failures** - all documents fail together

### Error Propagation
- Errors within the try path bubble up to the catch handler
- The original document that entered the try/catch is passed to the catch path
- Document properties set in the try path may not be available in catch path

### Retry Behavior
- Each retry attempt re-executes the entire try path from the beginning
- Retries happen immediately without delay (no exponential backoff)
- Consider retry count carefully to avoid excessive API calls or processing

### Nested Try/Catch
- Try/catch blocks can be nested for granular error handling
- Inner catches execute before outer catches (nearest catch wins)
- Once caught, errors don't bubble up to outer catch blocks
- Use sparingly to maintain process readability

## Common Gotchas
1. **Missing Catch Path**: Always connect the catch dragpoint, even if just to a stop step
2. **Property Scope**: DDPs set in try path aren't guaranteed in catch path
3. **Retry Storm**: High retry counts can cause performance issues with failing operations
4. **Error Message Truncation**: Very long error messages may be truncated in the property

## XML Reference

```xml
<shape image="catcherrors_icon" name="shape19" shapetype="catcherrors" userlabel="" x="288.0" y="400.0">
  <configuration>
    <catcherrors catchAll="true" retryCount="2"/>
  </configuration>
  <dragpoints>
    <dragpoint identifier="default" name="shape19.dragpoint1" text="Try" toShape="shape10" x="416.0" y="376.0"/>
    <dragpoint identifier="error" name="shape19.dragpoint2" text="Catch" toShape="shape20" x="368.0" y="536.0"/>
  </dragpoints>
</shape>
```

## Typical Error Handler Pattern

A complete error handling pattern typically includes:
1. **Try/Catch Step**: Captures the error
2. **Notify Step**: Logs the error message (using `meta.base.catcherrorsmessage`)
3. **Additional Logic**: Could include sending alerts, writing to error queue, etc.
4. **Stop Step**: Ends the error path (with `continue="true"` or `continue="false"` based on requirements)

## Best Practices

### Use Try/Catch For
- External API calls that might fail
- Database operations that could timeout
- File operations that might encounter locks
- Any operation with known failure modes

### Avoid Try/Catch For
- Simple data transformations
- Internal process logic that should never fail
- Every single step (over-engineering)

### Retry Guidelines
- Network operations: 2-3 retries
- File system operations: 1-2 retries  
- Database operations: 1 retry (beware of duplicate transactions)
- Data transformation: 0 retries (if it fails once, it will fail again)

## Testing Considerations
- Test both success path and error path
- Verify retry count behavior
- Ensure error messages provide actionable information
- Test with various error types to verify catch scope