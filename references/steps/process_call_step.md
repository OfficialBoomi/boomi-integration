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

### Multiple Return Paths
Each return path needs its **own target step** — two paths on one target render unreadably on the canvas. See `BOOMI_THINKING.md` § Converging Outcomes for the mechanism and the alternative remedy.

When the parent has one logical next step for all outcomes, keep the single shared step and put **one inert Notify per return path** in front of it:

```xml
<shape image="processcall_icon" name="shape3" shapetype="processcall" x="432.0" y="48.0">
  <configuration>
    <processcall abort="true" processId="[subprocess GUID]" wait="true">
      <parameters/>
      <returnpaths>
        <returnpaths childShapeName="shape7"/>
        <returnpaths childShapeName="shape8"/>
      </returnpaths>
    </processcall>
  </configuration>
  <dragpoints>
    <dragpoint identifier="shape7" name="shape3.dragpoint1" toShape="shape4" x="608.0" y="56.0"/>
    <dragpoint identifier="shape8" name="shape3.dragpoint2" toShape="shape5" x="608.0" y="296.0"/>
  </dragpoints>
</shape>
<!-- shape4 / shape5: one Notify per outcome, both wired to the shared shape6 -->
```

Documents pass through the Notify steps unchanged, at a small fixed log cost — give each a useful message (see `notify_step.md`).

The `text` attribute on a return dragpoint is display-only and optional; the GUI back-fills it from the subprocess return step's label the first time the process is opened and saved there. The same save regenerates every return dragpoint's `x`/`y` from its target step's position, so authored coordinates do not survive.

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

**A mismatch routes nothing, silently.** A `childShapeName` with no matching subprocess return shape delivers 0 documents — the push is accepted, the process completes with no error, and the downstream step is skipped (`No documents found. Skipping execution for the <step> step.`). The only signal is a WARNING in the parent's process log: `Ignoring returned documents for unknown shape <name>` — where `<name>` is the subprocess return shape whose documents found no matching return path, not the name the parent declared. With multiple return paths, a mismatch affects only its own path; correctly matched paths still route. If a downstream branch receives no documents, verify the name match.

**GUI symptom of a mismatch:** the Build canvas first draws the connection from the XML dragpoint, then immediately detaches it (once the subprocess's return shapes are resolved), leaving the return path as an unresolved `+` stub. The dragpoint and its `toShape` remain in the XML, so inspecting the parent XML alone makes the wiring look intact — verify `childShapeName` against the subprocess's returndocuments shape names instead. If shapes "appear connected briefly, then disconnect on their own," check for this mismatch.

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
- All subprocess branches complete before returning to parent; the parent's return branches then execute sequentially in `returnpaths` order, each receiving only the documents from its matching subprocess return shape
- A DPP set inside a `wait="true"` subprocess persists into the parent and is readable after the call returns (read with `valueType="process"`). A side-effect subprocess can return its result via a DPP instead of a returned document — e.g. a sub that returns only on error, with the parent reading the DPP in a later step
- A process can call itself recursively via Process Call. When doing this, always include a recursion depth guard (e.g. a DPP counter checked by a Decision step) to cap depth at no more than 5 levels and prevent runaway processes
