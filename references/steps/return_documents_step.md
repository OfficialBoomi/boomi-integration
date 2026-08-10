# Return Documents Step

## Contents
- Purpose
- Behavior
- Step XML Structure
- Configuration
- Multiple Return Documents Steps in One Process
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

## Multiple Return Documents Steps in One Process
Legal, and one of the two remedies for outcomes converging on a single terminal (see `BOOMI_THINKING.md` § Converging Outcomes). The documents delivered are the same, in the same order, with the same content.

It does change the **return contract**, because each step declares a return path the process exposes:
- **One shared terminal** returns a single store holding all the documents; **one terminal per outcome** returns one store per terminal.
- **HTTP callers are unaffected.** With `outputType="singledata"`, the web server concatenates every returned document into one response body regardless of how many stores they arrived in, so a listener returns a byte-identical response either way.
- **A process-call caller is affected.** Splitting one terminal into two changes how many return paths the caller must wire, and a stale `childShapeName` routes zero documents silently. Check for callers before splitting.

When the return contract must stay fixed, keep the single terminal and interpose one inert Notify per outcome instead — see `process_call_step.md`.

## Usage Notes
- Multiple return document steps in a subprocess create multiple return branches in parent
- Valid as a terminal in a top-level process with no caller — the return store is built and discarded, and the process completes normally
- A terminal reached by more than one inbound outcome is entered **once per outcome**, each time with that outcome's documents — not once with the merged set
- The `label` is only the display text shown on the parent's branch — the parent routes by the return shape's `name` (matched by `childShapeName`), not the `label`
- No dragpoints - this is always a terminal step
- Documents retain their properties (DDPs) when returned
