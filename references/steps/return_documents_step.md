# Return Documents Step

## Contents
- Purpose
- Behavior
- Step XML Structure
- Configuration
- Usage Notes

## Purpose
Returns documents to the calling context - either a parent process or external caller.

**Use when:**
- Ending subprocess execution to return documents to parent
- Returning API responses in listener processes
- Creating multiple return paths from a subprocess (each return step becomes a branch in parent)
- Terminating a process path (alternative to Stop step)

## Behavior
- **In subprocess**: Returns documents to parent process call step
- **In listener process**: Returns response to external caller (e.g., HTTP response for web services listener)

## Step XML Structure

### Basic Return (No Label)
```xml
<shape image="returndocuments_icon" name="shape2" shapetype="returndocuments" x="256.0" y="96.0">
  <configuration>
    <returndocuments/>
  </configuration>
  <dragpoints/>
</shape>
```

### Return with Display Name
```xml
<shape image="returndocuments_icon" name="shape2" shapetype="returndocuments" userlabel="Display name" x="256.0" y="96.0">
  <configuration>
    <returndocuments label="Display name"/>
  </configuration>
  <dragpoints/>
</shape>
```

## Configuration
- `label`: Optional display name that appears in parent process call branches for human readability
- `userlabel`: Should match the label for consistency

## Usage Notes
- Multiple return document steps in a subprocess create multiple return branches in parent
- The `label` value (e.g., "Successfully processed") becomes the branch identifier displayed in parent process call step
- No dragpoints - this is always a terminal step
- Documents retain their properties (DDPs) when returned