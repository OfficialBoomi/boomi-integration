# Process Script Component

## Contents
- Purpose
- When to Use
- Component Structure
- ProcessingScript Attributes
- Scripting Languages
- Script Storage Form
- Referencing the Component from a Data Process Step
- Language Must Match the Code
- Dependency Visibility
- Build Order

## Purpose
A Process Script component (`type="script.processing"`) is a standalone, reusable script that a Data Process step's Custom Scripting operation (process type 12) can reference instead of embedding the script inline. The same script component can be referenced by multiple Data Process steps across processes.

This is the component-backed alternative to the inline Custom Scripting documented in `references/steps/data_process_custom_scripting.md`. The `dataContext` loop contract, the `storeStream` requirement, and the property model are identical between inline and component-backed scripting — see that reference.

## When to Use
Choose based on reuse — inline and component-backed scripting are equally valid:
- **Inline Custom Scripting** (see `data_process_custom_scripting.md`) — for a script used by a single Data Process step.
- **Standalone Process Script component** — when the same script is (or may be) needed in more than one step or process, you want it maintained as a single shared component with its own dependency edges, or the user asks for a reusable component.

## Component Structure

```xml
<?xml version="1.0" encoding="UTF-8"?>
<bns:Component xmlns:bns="http://api.platform.boomi.com/"
               componentId=""
               name="[SCRIPT_COMPONENT_NAME]"
               type="script.processing"
               folderId="[FOLDER_ID]">
  <bns:object>
    <ProcessingScript xmlns="" language="groovy2" useCache="true">
      <script><![CDATA[
import java.util.Properties;
import java.io.InputStream;

for( int i = 0; i < dataContext.getDataCount(); i++ ) {
    InputStream is = dataContext.getStream(i);
    Properties props = dataContext.getProperties(i);

    /* Your logic here */

    dataContext.storeStream(is, props);
}
      ]]></script>
    </ProcessingScript>
  </bns:object>
</bns:Component>
```

### Key structural facts
- Component `type="script.processing"`.
- Body root element is `<ProcessingScript>` (not `<dataprocessscript>`, which is the *step-level* reference element).
- The script text element is `<script>`, holding the same `dataContext` loop / `storeStream` contract as an inline Data Process script.
- There are no input/output declarations — unlike a Map Scripting component, a Process Script operates on the document stream via `dataContext`, not named variables.

Create it through the skill's normal component-create tooling (it is a generic component create — no special handling needed).

## ProcessingScript Attributes

| Attribute | Value | Notes |
|-----------|-------|-------|
| `xmlns` | `""` | Empty namespace, present on the element |
| `language` | `groovy2` | Engine token — see Scripting Languages below |
| `useCache` | `true` | Script compilation caching; mirror the platform default |

## Scripting Languages
The `<ProcessingScript>` `language` attribute enumeration is exactly **`javascript`, `groovy`, `groovy2`**:

| GUI label | `language` token |
|-----------|------------------|
| Groovy 2.4 | `groovy2` |
| Groovy 1.5 | `groovy` |
| JavaScript | `javascript` |

- **Default to `groovy2`.** Avoid Groovy 1.5 (`groovy`) for new work.
- JavaScript runs on the Nashorn engine (access Java via `Packages`/`importClass`; no `class` declarations). The engine actually used is echoed in the process execution log as `[1] Scripting: <token>`.

## Script Storage Form
The `<script>` body may be authored in CDATA or entity-escaped; the platform stores and returns it entity-escaped either way. See `data_process_custom_scripting.md` for details.

## Referencing the Component from a Data Process Step
A Data Process step's Custom Scripting processing step points at the component by setting `useComponent="true"` + `componentId` on its `<dataprocessscript>` element (the GUI's **Select Script Source → Process Script Component**). The runtime then executes the component's script, ignores the step's inline body, and treats the step's own `language` as inert (the component's `language` governs).

The reference XML and its full behavior are a step-side concern — see `data_process_custom_scripting.md` (Referencing a Process Script Component) for the complete `<dataprocessscript>` example, the redeploy-after-edit rule, and the inline-vs-component choice.

## Language Must Match the Code
The component's `language` must match the language its `<script>` is actually written in. A JavaScript-bodied component declared `language="groovy"` passes push (it is a valid enum value) but fails at **runtime**.

## Dependency Visibility
The Data Process step's process → script relationship is a standard `DEPENDENT` ComponentReference edge: the process appears as `parentComponentId` with `type="DEPENDENT"`, discoverable from the script component side as a `referenced-by` record.

## Build Order
1. Create the `script.processing` component; note its `componentId`.
2. Create (or edit) the process whose Data Process step references it with `useComponent="true"` + `componentId` (see `data_process_custom_scripting.md` and `data_process_step.md`).
3. Deploy and execute.

**Redeploy referencing processes after editing the component.** A deployed process captures the referenced component's version at deploy time — the component is bundled into the process's deployment, not resolved live (unlike a Process Route component, which deploys independently). After editing a `script.processing` component, **redeploy every referencing process** for the change to take effect; the running process otherwise keeps executing the version captured at its last deploy.
