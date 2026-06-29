# Process Route Step

## Contents
- Purpose
- When to Use (and When Not To)
- How Routing Works
- Step XML Structure
- Configuration Elements
- Return Path Wiring
- The resource::rout: Reference (Critical)
- Deployment Model (Critical)
- Edition and Distribution Limits
- Building Instructions

## Purpose
The Process Route step calls a separate **Process Route component**, which selects a subprocess to execute based on a route key resolved at execution time. It combines the multi-path selection of a Route step with the subprocess invocation of a Process Call: one step can dispatch documents to any of several subprocesses depending on a value, and the chosen subprocess can return documents back along named return paths.

**Use when:**
- A value resolved at execution time must select which subprocess runs (document property, profile field, extension value, trading partner, etc.)
- The set of subprocesses must be changeable and deployable independently of the parent process

## When to Use (and When Not To)
Default to a plain **Process Call** subprocess for ordinary modular/shared logic — it is a dependent component that copies, packages, and deploys with its parent. Reach for a Process Route only when the dynamic, independently-deployable indirection is actually needed. The Process Route trades portability and deployment simplicity (see Deployment Model and Edition and Distribution Limits) for that indirection.

## How Routing Works
The step carries one or more `<routeParameter>` slots. Their resolved value(s) form the **route key**, which is matched against the `key` attribute of a `processEntry` in the referenced Process Route component. The matching entry's subprocess executes; its returned documents exit the step along the mapped return path. A route key that matches no `processEntry` exits the always-present **Default** path, and no subprocess runs.

- The route key is the resolved parameter value, not the `routeParameter/@key` (which is the parameter slot index). With `valueType="current"`, the route key is the current document's content — document content of `1` matches `processEntry key="1"`.
- On a match, the document is **replaced** by the subprocess's returned content. On the Default path (no match), the original document passes through unchanged.
- Route key matching is exact string matching.

## Step XML Structure
```xml
<shape image="processroute_icon" name="shape2" shapetype="processroute" userlabel="" x="320.0" y="96.0">
  <configuration>
    <processroutecall abort="true" processRouteId="resource::rout:4e7d63ad-ae6b-4e09-9120-ae03bdabef10"
                      processRouteName="Order Router" routeType="processroute" wait="true">
      <returnpaths>
        <returnpaths childShapeName="route1" returnLabel="Success"/>
        <returnpaths childShapeName="route2" returnLabel="Failure"/>
      </returnpaths>
      <routeParameter key="0" usesEncryption="false" valueType="current"/>
    </processroutecall>
  </configuration>
  <dragpoints>
    <dragpoint identifier="route1"  name="shape2.dragpoint1" text="Success" toShape="shape5" x="496.0" y="184.0"/>
    <dragpoint identifier="default" name="shape2.dragpoint2" text="Default" toShape="shape3" x="496.0" y="104.0"/>
    <dragpoint identifier="route2"  name="shape2.dragpoint3" text="Failure" toShape="shape7" x="496.0" y="280.0"/>
  </dragpoints>
</shape>
```

## Configuration Elements

### processroutecall
- `processRouteId`: Reference to the Process Route component, prefixed `resource::rout:` (see below). **Required prefix.**
- `processRouteName`: Display name of the referenced component.
- `routeType`: `processroute` (route by a Process Route component) or `tradingpartnergroup` (route by a Processing Group). Use `processroute` unless routing by a Processing Group.
- `wait`: Whether the parent waits for the subprocess to complete before continuing. Forced on (and cannot be cleared) when the called process is a passthrough process.
- `abort`: Whether the parent stops and is marked failed if a subprocess fails.

### routeParameter
- Standard parameter slot. `key` is the slot **index** (`0`, `1`, …), not the route key value.
- `valueType` selects the value source (e.g. `current` for the current document's content). Multiple `routeParameter` slots combine to form a composite route key.

### returnpaths
- The `<returnpaths>` wrapper holds one `<returnpaths>` child per return path defined on the Process Route component.
- `childShapeName`: the **return path id** (`route1`, `route2`, …) from the component — NOT a subprocess shape name. (This differs from a plain Process Call, where `childShapeName` is a subprocess return-shape name.)
- `returnLabel`: the return path's label.

## Return Path Wiring
Each `<returnpaths>` child has a matching `<dragpoint>` whose `identifier` equals the return path id. A `default` dragpoint (`identifier="default"`) is **always present** for documents whose route key matches no entry. Wire every dragpoint — including `default` — to a downstream shape.

## The resource::rout: Reference (Critical)
`processRouteId` must be the component GUID prefixed with `resource::rout:`:

```
processRouteId="resource::rout:4e7d63ad-ae6b-4e09-9120-ae03bdabef10"
```

A bare GUID (no prefix) is **accepted on push and on deploy with no validation**, then fails only at execution with an unresolved-reference error (`Process Route component does not exist with id <bare-guid>`). The execution engine keys deployed route components by the full `resource::rout:` resource id, so the prefix must be emitted exactly. This is a silent-failure trap — there is no design-time or deploy-time check.

`processEntry/@processId` inside the Process Route component, by contrast, is a **bare** subprocess GUID (no prefix).

## Deployment Model (Critical)
Every Process Route participant must be **deployed independently**:
1. the parent process,
2. the Process Route component, and
3. **every** subprocess named in the route table.

Deploying the parent does **not** bundle the Process Route component, and deploying the Process Route component does **not** bundle its subprocesses. A missing piece fails only at execution, and each execution error names just the next missing component. This is unlike a plain Process Call, where subprocesses deploy along with the parent.

The same applies to pulling: because the route is referenced only by GUID and is not a dependent component, pulling the parent retrieves only the parent — the Process Route component and subprocesses are not discovered or pulled with it. Track and pull all participants explicitly.

## Edition and Distribution Limits
- Available only in **Professional and Enterprise** editions (Advanced Workflow).
- A process containing a Process Route step **cannot** be published to a process library, made available via an integration pack, shared in a Bundle, or deployed as a unit via the API.

## Building Instructions
1. Build the subprocesses first; each needs a Return Documents shape if it returns data on a path. Capture their GUIDs and Return Documents shape names.
2. Build the Process Route component (see `components/process_route_component.md`) mapping route keys → subprocess GUIDs and return paths → subprocess Return Documents shapes. Capture its GUID.
3. Add the `processroutecall` shape to the parent, referencing the component as `resource::rout:<component-guid>`.
4. Add one `<returnpaths>` child per return path (with `childShapeName` = the component's return path id), plus the matching dragpoints and the `default` dragpoint. Wire all paths.
5. Configure the `routeParameter` value source so its resolved value matches a `processEntry/@key`.
6. Deploy the parent, the component, and every subprocess separately.
