# Process Route Component

## Contents
- Purpose
- Component XML Structure
- Configuration Elements
- Route Keys and Return Paths
- Passthrough
- Relationship to the Process Route Step
- Deployment and Distribution Limits

## Purpose
A Process Route component (`type="processroute"`) is a standalone routing table. It maps **route keys** to **subprocesses** and defines the **return paths** along which those subprocesses send documents back. A Process Route step (`steps/process_route_step.md`) references this component by GUID and, at execution time, resolves a route key to select which subprocess runs.

**Use when:** building the routing table for a Process Route step — defining which subprocess each route key calls and how each subprocess's Return Documents shapes map back to the step's return paths.

## Component XML Structure
```xml
<ProcessRoute enforcePassthrough="true" startShapeType="passthrough">
  <returnPath id="route1" label="Success"/>
  <returnPath id="route2" label="Failure"/>
  <processEntry key="1" keyLabel="Success" processId="a14cc563-4e37-4b45-bc44-9c7340bdaf98">
    <returnPathMap childShapeName="shape3" returnLabel="Return Documents" routePathId="route1"/>
  </processEntry>
  <processEntry key="0" keyLabel="Error" processId="7b123253-7d2c-4868-adf8-fb782ac94e7b">
    <returnPathMap childShapeName="shape3" returnLabel="Return Documents" routePathId="route2"/>
  </processEntry>
</ProcessRoute>
```

## Configuration Elements

### ProcessRoute
- `startShapeType`: `passthrough` or `other` (default `other`).
- `enforcePassthrough`: boolean; pairs with `startShapeType="passthrough"`.

### returnPath
- `id`: stable id (`route1`, `route2`, …) referenced by the step's `<returnpaths childShapeName>` and by `returnPathMap/@routePathId`.
- `label`: display name of the path.

A **Default** path always exists implicitly for documents whose route key matches no entry; it is not declared here (the step provides the `default` dragpoint).

### processEntry
- `key`: the **route key value** matched at execution time against the step's resolved route parameter value (e.g. document content `1` matches `key="1"`). Must be unique within the component.
- `keyLabel`: display-only label for the key.
- `processId`: **bare** GUID of the subprocess to call (no prefix).
- `processName`: optional display name of the subprocess.

### returnPathMap
Maps a Return Documents shape in the subprocess to one of this component's return paths.
- `childShapeName`: the `name` of a Return Documents shape **in the subprocess**.
- `returnLabel`: that shape's label.
- `routePathId`: the `returnPath/@id` this maps to.

A subprocess return path may be left unmapped if it is not expected to return data. The same Return Documents step cannot be mapped to more than one return path.

## Route Keys and Return Paths
- **Route keys** (`processEntry/@key`) determine *which subprocess* runs.
- **Return paths** (`returnPath`) determine *which path out of the step* a subprocess's returned documents take, via `returnPathMap`.
- Return path declaration order here does not control execution order; the Process Route step controls the return path execution sequence, and the Default path runs last.

## Passthrough
With `startShapeType="passthrough"` / `enforcePassthrough="true"`, the subprocesses called must use a data-passthrough start shape, and incoming documents are grouped by route key (the matching subprocess is called once for all documents sharing that key). When the component is not passthrough, any subprocess type may be called and the step executes once per document.

## Relationship to the Process Route Step
The step references this component as `processRouteId="resource::rout:<this-component-guid>"` (the `resource::rout:` prefix is required). The step's `<returnpaths childShapeName="...">` values are this component's `returnPath/@id`s. See `steps/process_route_step.md`.

## Deployment and Distribution Limits
- The Process Route component and its subprocesses are **not** dependent components of the parent process. The parent, this component, and **every** subprocess must each be deployed independently — deploying one does not bundle the others.
- Because the parent references this component only by GUID and does not carry it, replicating a build to another account requires deploying this component (and its subprocesses) into that account independently and confirming every referencing step points to the correct GUID.
- Available only in **Professional and Enterprise** editions (Advanced Workflow). A process using a Process Route step cannot be shared via process library, integration pack, or Bundle, nor deployed as a unit via the API.
