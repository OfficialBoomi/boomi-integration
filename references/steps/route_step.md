# Route Step

## Contents
- Purpose
- Key Concepts
- Configuration Structure
- Value Sources
- Qualifier Types
- Building Instructions
- XML Reference

## Purpose
The route step evaluates a single value against multiple conditions and sends documents down the first matching path. It's the multi-path counterpart to the decision step (which is binary true/false).

**Use when:**
- Routing documents to 3+ destinations based on a value
- Implementing switch/case logic (e.g. route by status, type, region)
- Any scenario where chaining multiple decision steps would be unwieldy

## Key Concepts

### Multi-Path Routing
- Each route value defines a named path with a comparison qualifier and target value
- Documents flow down the **first** matching path — evaluation order is the **XML element order** of `<routevalue>` elements, NOT the `key` attribute value. Reordering elements changes routing behavior even if keys stay the same.
- Unmatched documents go to the **Default** path
- The Default path always exists and must be included
- Each document in a batch is independently evaluated — a batch of 3 documents can each route to different paths

### Dragpoint-Key Linkage
Each `<routevalue>` has a `key` attribute (numeric string). The corresponding `<dragpoint>` uses `identifier` set to that same key. The Default dragpoint uses `identifier="default"`.

### Display Name
Set `userlabel` on the `<shape>` element. Unlike the decision step, the `<route>` element itself has no `name` attribute.

## Configuration Structure
```xml
<shape image="route_icon" name="[shapeName]" shapetype="route" userlabel="[display label]" x="[x]" y="[y]">
  <configuration>
    <route>
      <routeproperty valueType="[track|profile]">
        <!-- value source element (see Value Sources) -->
      </routeproperty>
      <routevalues>
        <routevalue key="[key]" name="[display name]" qualifier="[qualifier]" value="[compare value]"/>
        <!-- additional routevalue elements -->
      </routevalues>
    </route>
  </configuration>
  <dragpoints>
    <dragpoint identifier="default" name="[shape].dragpoint1" text="Default" toShape="[target]" x="[x]" y="[y]"/>
    <dragpoint identifier="[key]" name="[shape].dragpoint2" text="1 - [routevalue name]" toShape="[target]" x="[x]" y="[y]"/>
    <!-- one dragpoint per routevalue, plus the default -->
  </dragpoints>
</shape>
```

## Value Sources

### Document Property (`valueType="track"`)
Routes based on a DDP value. Common source.
```xml
<routeproperty valueType="track">
  <trackparameter defaultValue="" propertyId="dynamicdocument.DDP_NAME" propertyName="Dynamic Document Property - DDP_NAME"/>
</routeproperty>
```

For DPPs, use `valueType="process"` with `<processparameter>` instead — `trackparameter` only reads DDPs.

### Profile Element (`valueType="profile"`)
Routes based on a field value from the current document's profile. Common source.
```xml
<routeproperty valueType="profile">
  <profileelement elementId="[id]" elementName="[path]" profileId="[guid]" profileType="[type]"/>
</routeproperty>
```

### Other Sources (out of scope)
SQL Statement, Process Properties (the component), and Stored Procedure are also available as value sources in the platform GUI but are not covered by this reference.

## Qualifier Types

All qualifiers from the decision step are available:

| Qualifier | Description |
|-----------|-------------|
| `equals` | Exact match (case-sensitive) |
| `notequals` | Does not match |
| `greaterthan` | Greater than (string/numeric) |
| `greaterthaneq` | Greater than or equal to |
| `lessthan` | Less than (string/numeric) |
| `lessthaneq` | Less than or equal to |
| `regex` | Java regular expression match |
| `wildcard` | Wildcard match (`*` any chars, `?` single char) |

String comparison behavior (case sensitivity, numeric coercion) follows the same rules as the decision step — see `decision_step.md` for details.

## Building Instructions

### Step 1: Determine Value Source
Decide what value to route on — a document property, dynamic process property, or profile element.

### Step 2: Define Route Values
For each path, specify a qualifier and comparison value. Assign each a unique numeric `key` (start at 3, increment). Names must match the comparison and value of the criteria as shown in the examples. Do not creatively name the dragpoints. **Place `<routevalue>` elements in the intended evaluation order** — the platform evaluates them by XML position, not by key value.

### Step 3: Wire Dragpoints
Create one dragpoint per route value plus the Default dragpoint. Each dragpoint's `identifier` must match its routevalue's `key`. The Default dragpoint uses `identifier="default"`.

Dragpoint `text` format: `"{index} - {routevalue name}"` for numbered routes, `"Default"` for the default path.

### Step 4: Connect All Paths
Every dragpoint must connect to a downstream shape — including Default.

## XML Reference

### Route by Document Property (multiple qualifiers)
```xml
<shape image="route_icon" name="shape2" shapetype="route" userlabel="Route by Status" x="240.0" y="48.0">
  <configuration>
    <route>
      <routeproperty valueType="track">
        <trackparameter defaultValue="" propertyId="dynamicdocument.DDP_STATUS" propertyName="Dynamic Document Property - DDP_STATUS"/>
      </routeproperty>
      <routevalues>
        <routevalue key="3" name="Status is Active" qualifier="equals" value="active"/>
        <routevalue key="4" name="Status is Pending" qualifier="equals" value="pending"/>
        <routevalue key="5" name="Status matches Error pattern" qualifier="wildcard" value="*error*"/>
      </routevalues>
    </route>
  </configuration>
  <dragpoints>
    <dragpoint identifier="default" name="shape2.dragpoint1" text="Default" toShape="shape3" x="416.0" y="56.0"/>
    <dragpoint identifier="3" name="shape2.dragpoint2" text="1 - Status is Active" toShape="shape6" x="416.0" y="216.0"/>
    <dragpoint identifier="4" name="shape2.dragpoint3" text="2 - Status is Pending" toShape="shape7" x="416.0" y="376.0"/>
    <dragpoint identifier="5" name="shape2.dragpoint4" text="3 - Status matches Error pattern" toShape="shape8" x="416.0" y="536.0"/>
  </dragpoints>
</shape>
```

### Route by Profile Element
```xml
<shape image="route_icon" name="shape12" shapetype="route" userlabel="Route by Price" x="736.0" y="144.0">
  <configuration>
    <route>
      <routeproperty valueType="profile">
        <profileelement elementId="8" elementName="price (Root/Object/products/products/ArrayElement1/Object/price)" profileId="fe31f94e-50a8-4eb5-9ac8-56e3b3692e86" profileType="profile.json"/>
      </routeproperty>
      <routevalues>
        <routevalue key="3" name="Price equals threshold" qualifier="equals" value="100"/>
        <routevalue key="4" name="Price above threshold" qualifier="greaterthan" value="100"/>
      </routevalues>
    </route>
  </configuration>
  <dragpoints>
    <dragpoint identifier="default" name="shape12.dragpoint1" text="Default" toShape="shape13" x="868.0" y="154.0"/>
    <dragpoint identifier="3" name="shape12.dragpoint2" text="1 - Price equals threshold" toShape="shape14" x="868.0" y="192.0"/>
    <dragpoint identifier="4" name="shape12.dragpoint3" text="2 - Price above threshold" toShape="shape15" x="868.0" y="232.0"/>
  </dragpoints>
</shape>
```