# Process Call Step

## Contents
- Purpose
- Key Use Cases
- Critical Configuration
- Step XML Structure
- Configuration Elements
- Return Path Mapping
- Common Pattern
- Implementation Notes

## Purpose
Routes documents into a subprocess for modular design. Returns documents from all subprocess branches simultaneously to the parent process.

**Use when:**
- Modularizing logic for reusability and testability
- Wrapping the core business logic of listener processes to enable test mode for core business logic
- Combining documents from separate subprocess branches
- Breaking complex processes into maintainable components

## Key Use Cases

### 1. Test Mode Enablement
When wrapping processes in listener start shapes (which disable test mode), use a process call to move the main logic to a subprocess that can still be tested independently.

### 2. Cross-Branch Document Combination
Documents from separate branches in a subprocess all return to the parent simultaneously, enabling combine operations that wouldn't be possible within a single process level.

## Critical Configuration

### Subprocess Start Shape
The subprocess MUST use a **data passthrough** start configuration to receive documents from the parent:
```xml
<configuration>
  <passthroughaction/>
</configuration>
```

### Return Paths
- Each return document shape in the subprocess creates a potential output branch
- The parent process call step must define return paths matching subprocess return shapes
- 0-to-many branches possible

## Step XML Structure

### Basic Process Call
```xml
<shape image="processcall_icon" name="shape30" shapetype="processcall" userlabel="" x="1583.0" y="528.0">
  <configuration>
    <processcall abort="true" processId="0caf8ec6-8a73-46a3-be54-4dd47f692af0" wait="true">
      <parameters/>
      <returnpaths>
        <returnpaths childShapeName="shape2"/>
      </returnpaths>
    </processcall>
  </configuration>
  <dragpoints>
    <dragpoint identifier="shape2" name="shape30.dragpoint1" toShape="shape26" x="1759.0" y="536.0"/>
  </dragpoints>
</shape>
```

## Configuration Elements

### processcall
- `abort`: Whether parent process aborts if subprocess fails
- `processId`: GUID of the subprocess component
- `wait`: Whether to wait for subprocess completion

### returnpaths
- Each `<returnpaths>` child defines one return branch
- `childShapeName`: Must equal a subprocess `returndocuments` shape's `name` (see [Return Path Mapping](#return-path-mapping))
- `returnLabel`: Optional, display-only — a free-form branch label (defaults to the subprocess return shape's `label`). No effect on routing; the GUI populates it, XML authoring may omit it
- Creates corresponding dragpoint with matching `identifier`

## Return Path Mapping
`childShapeName` must equal the **`name`** of a `returndocuments` shape in the subprocess — not its `label`/`userlabel`. Each `childShapeName` needs a matching dragpoint `identifier`.
- Subprocess: `<shape name="shape2" shapetype="returndocuments">`
- Parent: `<returnpaths childShapeName="shape2"/>` + `<dragpoint identifier="shape2">`

Find the subprocess's return shape names before wiring:
```bash
grep 'shapetype="returndocuments"' <subprocess>.xml
```

**A mismatch routes nothing, silently.** A `childShapeName` with no matching subprocess return shape delivers 0 documents — the process completes with no error, and the mismatch is not caught at save time (in the GUI the branch shows an unresolved `+` stub). The only signal is a WARNING in the parent's process log: `Ignoring returned documents for unknown shape <name>`. If a downstream branch receives no documents, verify the name match.

## Common Pattern: Listener with Testable Logic
```
Main Process:
[Web Services Listener] → [Process Call] → [Send Response]
                              ↓
                         Subprocess:
                    [Passthrough Start] → [Business Logic] → [Return Documents]
```

This pattern enables test mode for the business logic while maintaining the listener wrapper.

## Implementation Notes
- Subprocess must have passthrough start to receive parent data
- Return shape names in subprocess display in the parent process, which is helpful for visual editing
- All subprocess branches complete before returning to parent
- A DPP set inside a `wait="true"` subprocess persists into the parent and is readable after the call returns (read with `valueType="process"`). A side-effect subprocess can return its result via a DPP instead of a returned document — e.g. a sub that returns only on error, with the parent reading the DPP in a later step
- A process can call itself recursively via Process Call. When doing this, always include a recursion depth guard (e.g. a DPP counter checked by a Decision step) to cap depth at no more than 5 levels and prevent runaway processes
