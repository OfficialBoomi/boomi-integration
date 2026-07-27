# User-Defined Function Component

## Contents
- Purpose
- When to Use
- Component Structure
- The Interface (Function-Level Inputs/Outputs)
- Internal Steps (FunctionStep)
- Internal Wiring (Mappings)
- Execution Order Is the `position` Attribute
- Canvas Layout and GUI Drag Behavior
- Step Types Inside a UDF
- Referencing the Component from a Map
- Update and Redeploy Semantics
- Interface Changes and Consuming Maps
- Side-Effect-Only UDFs
- Nesting Is Not Supported
- Dependency Visibility
- Build Order

## Purpose
A User-Defined Function (UDF) is a standalone, reusable component (`type="transform.function"`) that chains multiple map-function steps into a single callable function with a declared input/output interface. It is the platform's mechanism for multi-step function pipelines: inside a plain map, one function step must never feed another (see "Never Chain One Function Directly Into Another" in `map_component_functions.md`), but inside a UDF, step-to-step wiring is exactly how the chain is built.

UDFs are managed through the standard Component API — create, push, pull, and version history all work with no special handling.

## When to Use
- **A transformation needs two or more function steps feeding one another** (e.g. Get Current Date → Date Format, or lookup → string cleanup → property set).
- **The same logic is needed in more than one map** — a UDF is referenced by ID, so all consumers share one definition. A single-step UDF is legal but only worthwhile for this reuse case; for a single-step, single-map transformation, use a plain inline function instead — the UDF adds indirection for no gain.
- **When a transformation is expressible as a chain of standard function types, prefer a UDF over a Scripting function** — the same native-components-first principle as the rest of this skill (see BOOMI_THINKING.md): function steps stay visible, configurable, and maintainable in the GUI, while scripts are opaque to non-authors. Reach for Scripting (inline or a `script.mapping` component) only when the logic genuinely needs code — arbitrary branching or computation that a standard-function chain cannot express.

## Component Structure

```xml
<?xml version="1.0" encoding="UTF-8"?>
<bns:Component xmlns:bns="http://api.platform.boomi.com/"
               componentId=""
               name="[UDF_NAME]"
               type="transform.function"
               folderId="[FOLDER_ID]">
  <bns:object>
    <Function xmlns="">
      <Inputs>
        <Input key="1" name="in_value"/>
      </Inputs>
      <Outputs>
        <Output key="1" name="out_value"/>
      </Outputs>
      <Steps>
        <FunctionStep cacheEnabled="true" cacheOption="none" category="String" key="2"
                      name="String Concat" position="1" sumEnabled="false" type="StringConcat"
                      x="100.0" y="100.0">
          <Inputs>
            <Input key="1" name="1"/>
            <Input default="_S1" key="2" name="2"/>
          </Inputs>
          <Outputs><Output key="2" name="Result"/></Outputs>
          <Configuration><StringConcat delimiter=""/></Configuration>
        </FunctionStep>
        <FunctionStep cacheEnabled="true" cacheOption="none" category="String" key="3"
                      name="String Concat" position="2" sumEnabled="false" type="StringConcat"
                      x="400.0" y="100.0">
          <Inputs>
            <Input key="1" name="1"/>
            <Input default="_S2" key="2" name="2"/>
          </Inputs>
          <Outputs><Output key="2" name="Result"/></Outputs>
          <Configuration><StringConcat delimiter=""/></Configuration>
        </FunctionStep>
      </Steps>
      <Mappings>
        <Mapping fromFunction="0" fromKey="1" fromNamePath="Editor/in_value" fromType="function"
                 toFunction="2" toKey="1" toNamePath="String Concat/1" toType="function"/>
        <Mapping fromFunction="2" fromKey="2" fromNamePath="String Concat/Result" fromType="function"
                 toFunction="3" toKey="1" toNamePath="String Concat/1" toType="function"/>
        <Mapping fromFunction="3" fromKey="2" fromNamePath="String Concat/Result" fromType="function"
                 toFunction="0" toKey="1" toNamePath="Editor/out_value" toType="function"/>
      </Mappings>
    </Function>
  </bns:object>
</bns:Component>
```

This example appends `_S1` then `_S2` to the input: `BASE` → `BASE_S1_S2`.

## The Interface (Function-Level Inputs/Outputs)
The `<Inputs>`/`<Outputs>` directly under `<Function>` are the UDF's public interface — the ports a consuming map wires to.

- Either side may be empty — but not both: a UDF with zero inputs AND zero outputs has no wireable ports and can never fire (see Side-Effect-Only UDFs below). A UDF with zero outputs is legal and used purely for side effects; a UDF with zero inputs is legal as a generator.
- Interface keys need not be 1-based or contiguous (interfaces starting at key 3 or 5 occur). Keys are assigned at authoring time and are the stable identity of each port — **never renumber an existing key**; consuming maps reference ports by key (see Interface Changes below).

## Internal Steps (FunctionStep)
Each `<FunctionStep>` inside `<Steps>` is one function in the chain, using the **same step vocabulary as inline map functions** — identical `category`/`type` values and `<Configuration>` payloads. See `map_component_functions.md` for each function type's ports and configuration.

| Attribute | Meaning |
|---|---|
| `key` | Unique step id within the UDF, referenced by Mappings. Key `0` is implicitly reserved for the "Editor" — the UDF's own interface. |
| `category` / `type` | Function taxonomy, e.g. `String`/`StringConcat`, `Lookup`/`SqlLookup`, `Scripting`/`Scripting`. |
| `position` | **Execution order (1..n)** — see Execution Order below. |
| `x`, `y` | Canvas coordinates in the UDF editor. **Not cosmetic** — the GUI recomputes `position` from coordinates on any drag. Follow the layout convention in Canvas Layout and GUI Drag Behavior below. |
| `cacheEnabled`, `cacheOption`, `sumEnabled`, `enabled` | Same semantics and defaults as map-level function steps (see `map_component_functions.md`). GUI-authored steps typically carry `cacheEnabled="true" cacheOption="none" sumEnabled="false"`. |

Each step carries its own `<Inputs>`/`<Outputs>` ports plus a type-specific `<Configuration>`. **Static parameters are supplied as input `default` attributes** (e.g. a String Concat's fixed suffix, date masks, a property name), not as Configuration entries — same rule as inline map functions.

## Internal Wiring (Mappings)
Each `<Mapping>` connects one step's output to another step's input:

- `fromFunction`/`toFunction` name a FunctionStep `key`; **`0` is the Editor**, i.e. the UDF's own interface. `fromFunction="0"` feeds a UDF input into a step; `toFunction="0"` returns a step output as a UDF output.
- `fromKey`/`toKey` are the port keys on that step (or on the interface).
- `fromType`/`toType` are always `function` inside a UDF — step-to-step chaining is the point of the component.
- **Fan-out is allowed**: one output may feed multiple targets.
- **Wiring resolves by keys only; `fromNamePath`/`toNamePath` are display-only.** Wrong or stale namePaths have zero effect on execution. Treat them as comments — populate them for readability, never rely on them.
- **A wrong key is a silent failure, not an error.** A Mapping whose key points at a nonexistent port is accepted on push and the map executes without any error — the dangling wire is simply dropped and the downstream input reads empty. The result is silently wrong output. Verify every `fromFunction`/`fromKey`/`toFunction`/`toKey` against the declared steps and ports before pushing.

## Execution Order Is the `position` Attribute
Inside a UDF, steps execute in ascending `position`. This is the opposite of map-level inline functions (where `position` is inert and XML document order governs under `optimizeExecutionOrder="false"` — see `map_component_functions.md`). The `<Function>` element has no `optimizeExecutionOrder` attribute; `position` is the sole ordering authority inside a UDF.

- The platform honors `position` strictly, **even when it contradicts the wiring graph**: a step positioned before the step that feeds it reads an empty value — no error, no warning, no reordering.
- **Generation rule:** assign `position` as a topological order of the data flow (1..n, every step after the steps that feed it), keep the `<FunctionStep>` document order matching `position`, and lay the boxes out left-to-right with `x` increasing strictly with `position` (see Canvas Layout and GUI Drag Behavior below) so XML, runtime, and GUI all tell the same story.

## Canvas Layout and GUI Drag Behavior

**Layout convention — grouped lanes.** UDF steps lay out left-to-right, unlike map-level functions (which stack vertically at a fixed `x="10.0"`):

- **x increases strictly with `position` across the whole UDF** — ~300 apart (100, 400, 700, …), every step strictly right of the one before it, **never two steps at the same x**. Execution is strictly sequential by `position` (there is no parallelism inside a UDF), and x rank must encode that order completely.
- **y forms lanes for visual grouping** (~150 apart): keep a connected chain in one y-lane, and give independent chains — e.g. side-effect chains that never touch the UDF output — their own lane. y has no execution meaning; lanes communicate chain membership only.
- **Every feeder sits strictly left of its consumer** (automatic when x follows topological position order).

Example — three lanes, x strictly increasing 100→1300 UDF-wide: main chain at y=100 (steps at x=100, 400 feeding the output), a side-effect chain at y=250 (x=700, 1000), a solo side-effect step at y=400 (x=1300).

**Why the convention is load-bearing — GUI drag mechanics:**

- At rest the editor renders the stored `position` badges and validates nothing. Opening and viewing changes nothing; close-without-save is a true no-op; a save with no changes is refused outright — an API-authored UDF following this convention is canonical to the GUI, with zero pending normalization.
- **The moment any box is grabbed (mousedown, before any movement), the editor recomputes EVERY step's `position`** as sort-by-(x ascending, y ascending as tiebreak) and renders the new badges live. Saving persists the recompute — even a few-pixel nudge that changes no rank rewrites all positions.
- **Any wire whose feeder does not precede its consumer under the recomputed rank turns red during the drag and is silently deleted on mouse-release.** Save persists the deletion; there is no confirmation dialog.

A UDF whose x order matches its positions is fully drag-safe. A UDF where they disagree — or where steps share an x — is one drag-and-save away from silent semantic corruption: full renumbering plus deletion of every backward wire. Never emit such a layout. When pulling an existing UDF shaped like this, warn the user: it is safe to open and view, but a drag-and-save will rewrite its execution order and can delete wiring.

## Step Types Inside a UDF
Every standard function type behaves identically inside a UDF as at map level, with the exceptions listed below. Mirror each type's documented map-level XML (ports, `category`/`type`, `<Configuration>`) exactly inside the UDF — see `map_component_functions.md`. Identical behavior includes the stateful machinery:

- The **aggregators** (Running Total, Sum, Count, Line Item Increment) keep their cross-record semantics — grouping per Reset Value, order-sensitive control-break, presence gating, per-row broadcast — exactly as documented at map level. A UDF invocation is not an isolated per-record evaluation context.
- **Sequential Value** counters persist per `keyname` across executions identically.
- **Connector Call** performs live connector operations; the connection and operation become dependencies of the UDF itself.
- **Scripting** works inline and `script.mapping`-component-backed (empty embedded `<ScriptToExecute/>` resolves the referenced script); the same `script.mapping` component may be referenced by more than one step in a single UDF, and it registers as a dependency of the UDF.

Exceptions:
- **Simple Lookup cannot be created inside a UDF via the Component API.** The `transform.function` component schema rejects the embedded lookup table on create (`no declaration can be found for element 'CrossRefTable'`, HTTP 400) — the identical FunctionStep XML is accepted in a map. When a static key/value table is needed inside a UDF, use a Cross Reference Lookup instead: the same platform-stored table, externalized into a `crossref` component referenced by `crossRefTableId`. (The other Lookup types — SQL, Cross Reference, Document Cache — all work inside UDFs directly.)
- **Another UDF** — never (see Nesting Is Not Supported below).
- Set Trading Partner executes identically inside a UDF, but its envelope-selection effect on a downstream TP Send step is not yet documented from inside a UDF.

When a Scripting step uses `useComponent="true"`, the step-level `language` attribute can disagree with the referenced `script.mapping` component; the component's own language wins. Don't trust the step-level `language` on component-backed scripting steps.

## Referencing the Component from a Map
A map consumes a UDF as a FunctionStep with `category="userdefined"` and `type="userdefined"`, referencing the UDF by its componentId in the **`id` attribute** — unlike every other function step, which is defined inline:

```xml
<Functions optimizeExecutionOrder="true">
  <FunctionStep category="userdefined" id="[UDF_COMPONENT_ID]" key="1"
                name="[UDF_NAME]" position="1" type="userdefined" x="10.0" y="10.0">
    <Inputs>
      <Input key="1" name="in_value"/>
    </Inputs>
    <Outputs>
      <Output key="1" name="out_value"/>
    </Outputs>
    <Configuration/>
  </FunctionStep>
</Functions>
```

- The step's `<Inputs>`/`<Outputs>` are a **mirror copy of the UDF's interface — same keys, same names**. The map anchors its `<Mapping>` entries to these embedded keys.
- `<Configuration/>` is always empty; the reference carries **no version attribute** (see Update and Redeploy Semantics).
- Map-level mappings wire profile fields to the UDF exactly as with any function step (`toFunction`/`toKey` in, `fromFunction`/`fromKey` out), and UDF references coexist with standard function steps in the same `<Functions>` list.

Maps are not the only consumers — UDFs can also be embedded in Business Rules steps inside processes. That pattern is not yet implemented in this skill; if you encounter it, inform the user that you don't have documentation for it.

## Update and Redeploy Semantics
The map's reference to a UDF is unversioned. Packaging a process snapshots the then-current UDF revision:

- Editing and saving a new UDF revision does **not** change the behavior of an already-deployed process.
- The consumer picks up the latest UDF revision when its process is next packaged and redeployed — no map or process edit is required, and there is no way to pin an older UDF revision from the map side.

## Interface Changes and Consuming Maps
Each consuming map embeds a copy of the UDF's interface, matched to the live component **by key**:

- **Renaming** an interface input/output (key unchanged) is harmless — consumers keep working with the stale embedded name.
- **Removing or renumbering a key** that a consumer references breaks that consumer at execution: the map produces zero output documents and the process logs a document error — with a misleading message (`No data produced from map …, please check source profile and make sure it matches source data`). The source profile is fine; the real cause is UDF interface drift. After changing interface keys, update every consuming map's embedded interface copy and its map-level mappings.

## Side-Effect-Only UDFs
A UDF with an empty `<Outputs/>` interface is mapped input-only — its userdefined FunctionStep appears in the map with inputs wired and **no output mapping at all** — and its side effects (e.g. setting Dynamic Process/Document Properties) land normally.

**A UDF fires only when at least one of its interface ports — input or output — is wired in the consuming map.** A userdefined FunctionStep whose ports have no mappings touching them does not execute at all — its side effects silently do not happen. Declaring a port is not enough; it must be wired.

Zero-input UDFs are usable as generators: wire an output to a target field and the UDF fires (a map whose only mapping is that function→profile wire still emits an output document). A zero-input, **zero-output** UDF has no wireable ports and can never fire — the API accepts it, but the runtime never invokes it and its side effects never land. Every UDF this skill generates must declare at least one port and wire it in the consuming map.

## Nesting Is Not Supported
A UDF must not reference another UDF. The Component API accepts a `category="userdefined"` step inside a `transform.function`, and the consuming process even packages and deploys — but execution fails at process initialization (`Unable to instantiate function userdefined, Class not found`). **Never generate a userdefined step inside a UDF.** If logic needs sharing across UDFs, factor it into a `script.mapping` component, which multiple UDFs (and steps) can reference.

## Dependency Visibility
Standard `DEPENDENT` ComponentReference edges in both directions: consuming maps and processes appear as parents of the UDF, and the UDF's own references (e.g. `script.mapping` scripts, the database connection of an `SqlLookup`, the connection and operation of a `ConnectorCall`, `processproperty` components, `crossref` tables, document caches) appear as its dependencies. A pull-with-dependencies workflow for a map must recurse **through** the UDF one level deeper than for a plain map.

GUID-bearing attributes to scan when pulling a UDF: `componentId` on `<Scripting>` and `<DefinedProcessProperty>`, `connection` on `<SqlLookup>`, `crossRefTableId` on `<CrossRefLookup>`, `connectionId`/`operationId`/`parameter-profile`/`output-profile` on `<ConnectorCall>`, `docCache` on `<DocumentCacheLookup>`.

## Build Order
1. Create any components the UDF's steps reference (scripts, connections, process properties, cross-reference tables).
2. Create the `transform.function` component; note its componentId.
3. Create (or update) the map with a `category="userdefined"` FunctionStep whose `id` is that componentId and whose `<Inputs>`/`<Outputs>` mirror the UDF interface exactly, then wire map-level mappings to it.
4. Reference the map from a Map step in a process; package and deploy. Repackage and redeploy consumers after any later UDF edits.
