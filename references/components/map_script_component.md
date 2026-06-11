# Map Scripting Component

## Contents
- Purpose
- When to Use
- Component Structure
- MappingScript Attributes
- Scripting Languages
- Input/Output Declarations
- Typed Inputs
- Script Storage Form
- Referencing the Component from a Map
- Authoring Strategies
- Dependency Visibility
- Complete Example

## Purpose
A Map Scripting component (`type="script.mapping"`) is a standalone, reusable script that a Map's Scripting function can reference instead of embedding the script inline. The same script component can be referenced by multiple maps.

This is the component-backed alternative to the inline Scripting function documented in `map_component_functions.md`. The input/output naming model, the `dataType` enum, and the runtime Java classes are identical between inline and component-backed scripting — see those sections below and in `map_component_functions.md`.

## When to Use
Choose based on reuse — inline and component-backed scripting are equally valid:
- **Inline Scripting function** (see `map_component_functions.md`) — for a transformation used by a single map.
- **Standalone Map Scripting component** — when the same script is (or may be) needed in more than one map, you want it maintained as a single shared component with its own dependency edges, or the user asks for a reusable component.

## Component Structure

```xml
<?xml version="1.0" encoding="UTF-8"?>
<bns:Component xmlns:bns="http://api.platform.boomi.com/"
               componentId=""
               name="[SCRIPT_COMPONENT_NAME]"
               type="script.mapping"
               folderId="[FOLDER_ID]">
  <bns:object>
    <MappingScript xmlns="" language="groovy2" preserveOrder="true" useCache="true">
      <script><![CDATA[
// Input variables are available by the names you declare below.
String fnEmail = (first_name ?: "").toLowerCase()
String lnEmail = (last_name  ?: "").toLowerCase()
corporate_email = fnEmail + "." + lnEmail + "@example.com"
      ]]></script>
      <Input dataType="character" index="1" name="first_name"/>
      <Input dataType="character" index="2" name="last_name"/>
      <Output index="3" name="corporate_email"/>
    </MappingScript>
  </bns:object>
</bns:Component>
```

### Key structural facts
- Component `type="script.mapping"`.
- Body root element is `<MappingScript>`.
- Script text element is `<script>` — **not** `<ScriptToExecute>` (that element is used only inside a map's inline `<Scripting>`).
- Inputs and outputs are declared **once**, directly inside `<MappingScript>` after `<script>`. There is no separate key-based `<Inputs>`/`<Outputs>` node section (that section exists only in a map's FunctionStep).

## MappingScript Attributes

| Attribute | Value | Notes |
|-----------|-------|-------|
| `xmlns` | `""` | Empty namespace, present on the element |
| `language` | `groovy2` | Groovy 2.4 — see Scripting Languages below |
| `preserveOrder` | `true` | Always set to `true` to preserve the order of the component's input/output variables in the referencing map's variable list |
| `useCache` | `true` | Script caching flag; mirror the value that platform-created components use |

## Scripting Languages
The `<MappingScript>` `language` attribute takes `groovy` (Groovy 1.5), `groovy2` (Groovy 2.4), or `javascript` (JavaScript). **Default to `groovy2`.** See `map_component_functions.md` (Scripting language) for language-selection guidance and the JavaScript/Nashorn engine notes.

## Input/Output Declarations
- `<Input dataType=".." index=".." name=".."/>` — one per input.
- `<Output index=".." name=".."/>` — one per output. Outputs carry no `dataType`.
- `index` values need not be contiguous; gaps are allowed.
- The `name` of each input/output is the exact variable name available in the script (inputs are read, outputs are assigned), and is also the mappable node a map wires to.
- Outputs bind **by assignment** to the named output variable; a `return` statement is not used and any returned value is ignored.

## Typed Inputs
Each `<Input>` carries a `dataType` (`character`/`integer`/`float`/`datetime`) that sets the script variable's Java type and null behavior — identical to inline scripting. See `map_component_functions.md` (Input Data Types) for the full type/null table and the guidance to leave inputs as `character` unless doing date or numeric work. Outputs carry no `dataType`; their type is inferred from the value the script assigns.

## Script Storage Form
The `<script>` body may be authored in CDATA or entity-escaped; the platform stores and returns it entity-escaped either way. See `map_component_functions.md` (Script storage form).

## Referencing the Component from a Map
A map references a script component through its Scripting FunctionStep. The `<Configuration><Scripting>` element gains `useComponent="true"`, `componentId="[SCRIPT_COMPONENT_ID]"`, and `preserveOrder="true"` (inline scripting uses `useComponent="false"` and no `componentId`):

```xml
<FunctionStep cacheEnabled="true" category="Scripting" key="1" name="Email Builder"
              position="1" sumEnabled="false" type="Scripting" x="10.0" y="10.0">
  <Inputs>
    <Input key="1" name="first_name"/>
    <Input key="2" name="last_name"/>
  </Inputs>
  <Outputs>
    <Output key="3" name="corporate_email"/>
  </Outputs>
  <Configuration>
    <Scripting componentId="[SCRIPT_COMPONENT_ID]" language="groovy2"
               preserveOrder="true" useCache="true" useComponent="true">
      <ScriptToExecute><![CDATA[
String fnEmail = (first_name ?: "").toLowerCase()
String lnEmail = (last_name  ?: "").toLowerCase()
corporate_email = fnEmail + "." + lnEmail + "@example.com"
      ]]></ScriptToExecute>
      <Input dataType="character" index="1" name="first_name"/>
      <Input dataType="character" index="2" name="last_name"/>
      <Output index="3" name="corporate_email"/>
    </Scripting>
  </Configuration>
</FunctionStep>
```

- The FunctionStep retains its `<Inputs>`/`<Outputs>` node section (key + name) and the `<Configuration><Scripting>` `<Input dataType../>`/`<Output../>` declarations. These carry the `key`s the map's `<Mappings>` anchor to — author them in a component-backed map exactly as for inline scripting.
- The runtime resolves and compiles the referenced component's script at request time, so the embedded `<ScriptToExecute>` body is optional — it may be left empty (`<ScriptToExecute/>`) and the platform fetches the referenced script. The referenced script is never written back into the map's stored XML.

## Authoring Strategies
A single create persists the `componentId` reference and forms the dependency edge — no follow-up update push is needed. Two equivalent ways to author the map's `<ScriptToExecute>`:

1. **Self-contained (embedded body).** Include the full script and the `<Input>`/`<Output>` declarations (mirroring what a pull returns); the embedded body runs directly.
2. **Thin reference (empty body).** Leave `<ScriptToExecute/>` empty; the runtime resolves and runs the referenced component's script.

Both execute correctly on a normal create.

## Dependency Visibility
The map→script relationship is a standard `DEPENDENT` ComponentReference edge: the map appears as `parentComponentId` with `type="DEPENDENT"`, discoverable from the script component side as a `referenced-by` record. The edge is present as soon as the referencing map is created.

## Complete Example
The standalone component (above, Component Structure) plus a map that references it (above, Referencing the Component from a Map) form a complete pair. Build order:
1. Create the source and target profiles.
2. Create the `script.mapping` component; note its `componentId`.
3. Create the map with `useComponent="true"` + `componentId` and the FunctionStep wired into `<Mappings>`.
4. Reference the map from a Map step in a process (see `map_step.md`).
