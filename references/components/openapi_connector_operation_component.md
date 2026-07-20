# OpenAPI Connector Operation Component

## Contents
- Overview
- Hand-Authoring
- Component Structure
- GenericOperationConfig Attributes
- Request/Response Profiles (differs from REST)
- The `<cookie>` Metadata
- Parameters (Path / Query / Header)
  - The Three Coordinated Artifacts
  - The base64 `id` Token
- Setting a Parameter via Dynamic Operation Property
- Response Field Selection

## Overview
OpenAPI Connector Operation components define a single endpoint+method drawn from the connection's OpenAPI specification, along with the request/response profiles and parameter definitions generated from that spec. They run as the connector action on a connector step (or start shape) and pair with an OpenAPI Connection component.

`type="connector-action"`, `subType="officialboomi-X3979C-opena2-prod"` (same `connectorType` as the connection).

## Hand-Authoring

OpenAPI operations and their JSON profiles can be **authored entirely by hand** and pushed via API — the GUI **Import Operation** wizard is not required. The import wizard is a **design-time convenience** that *generates* these artifacts.

**Request-time mechanism** — at request time the connector:
- composes the request URL from the connection's `url` + the operation's `objectTypeId` (a nonexistent path returns a live 404 from the target);
- sets the outbound `Content-Type` from the INPUT cookie's `requestContentType`;
- sends the current document as the request body;
- binds path/query/header parameters by their base64 token `id` (see below).

It never dereferences the connection `spec` field. Reproducing the wizard's *output* by hand is therefore sufficient for correct execution.

> **Caveat — mismatches fail silently.** The base64 parameter tokens, the cookie JSON shape, and the profile field keys must be exact. A one-character token mismatch (e.g. trailing `==` left on a base64 `id`) drops the parameter with **no error**. Hand-authoring trades the wizard's correctness-by-construction for full local control — get the tokens, cookie shape, and keys right.

`copiedFromComponentId` is **optional** — omit it when authoring locally. (Imported operations may carry it referencing the generated source, but it is not required for execution.)

**When to use the GUI import wizard instead:** as a starting point when you don't have the endpoint/schema details on hand, or to generate a reference artifact you then pull and adapt. Otherwise author locally per this document.

## Component Structure
```xml
<?xml version="1.0" encoding="UTF-8"?>
<bns:Component xmlns:bns="http://api.platform.boomi.com/"
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               componentId=""
               name="{operationId}"
               type="connector-action"
               subType="officialboomi-X3979C-opena2-prod"
               folderId="{folder-id}">
  <bns:encryptedValues/>
  <bns:object>
    <Operation returnApplicationErrors="false" trackResponse="false">
      <Archiving directory="" enabled="false"/>
      <Configuration>
        <GenericOperationConfig ...>
          <!-- parameter <field> + <dynamicOperationField> entries -->
          <cookie role="INPUT"><value>{...}</value></cookie>
          <cookie role="OUTPUT"><value>{...}</value></cookie>
          <Options>
            <QueryOptions>
              <Fields><ConnectorObject .../></Fields>
              <Inputs/>
            </QueryOptions>
          </Options>
        </GenericOperationConfig>
      </Configuration>
      <Tracking><TrackedFields/></Tracking>
      <Caching/>
    </Operation>
  </bns:object>
</bns:Component>
```

## GenericOperationConfig Attributes

| attribute | Example | Meaning |
|---|---|---|
| `customOperationType` | `GET`, `POST` | HTTP method (the connector supports the 8 REST methods) |
| `objectTypeId` | `/{id}/info.0.json` | Endpoint path (templated `{param}` segments preserved) |
| `objectTypeName` | `getComicById` | The spec `operationId` (also the component name) |
| `operationType` | `EXECUTE` | Fixed Boomi operation type |
| `requestProfile` / `requestProfileType` | `89e4…` / `json` | Request profile reference (see below) |
| `responseProfile` / `responseProfileType` | `5498…` / `json` | Response profile reference |

## Request/Response Profiles (differs from REST)

> **Note — opposite of the REST connector.** The REST Connector Operation must NOT carry `requestProfileType`/`responseProfileType`. The OpenAPI operation **does** use them — it references JSON profiles (wizard-generated or hand-authored) by component id. Do not strip these attributes from OpenAPI operations.

- **Methods with a request body** (e.g. POST) carry both `requestProfile` (a component id) and `requestProfileType="json"`.
- **Methods without a request body** (e.g. GET) carry `requestProfileType="none"` and **no `requestProfile` attribute at all**.
- Response side: `responseProfile` (component id) + `responseProfileType="json"`, derived from the lowest-numbered 2xx JSON response in the spec.

When hand-authoring, build these JSON profiles per `json_profile_component.md` and reference them by component id (push the profile first, then use its generated id on the operation).

## The `<cookie>` Metadata

Two `<cookie>` elements persist the operation's shape as JSON. This is where path/query/header parameters live — there are no `queryParameters`/`requestHeaders` `customproperties` fields like the REST connector uses.

**INPUT** (body-less GET):
```json
{"requestBodyRequired":false,"requestContentType":null,"rootSchemaType":null,"pathParameters":[],"queryParameters":[],"headerParameters":[]}
```
**INPUT** (POST with JSON body):
```json
{"requestBodyRequired":true,"requestContentType":"application/json","headerParameters":[],"rootSchemaType":"object","queryParameters":[],"pathParameters":[]}
```
**OUTPUT**:
```json
{"contentType":"application/json","rootSchemaType":"object"}
```

## Parameters (Path / Query / Header)

A spec parameter is stored in the INPUT cookie's `pathParameters` / `queryParameters` / `headerParameters` array. **Only parameters the spec explicitly declares** (`in: path` / `in: query` / `in: header`) become slots — narrative prose in the spec like "accepts any headers" does **not** generate a parameter; an endpoint with only `in: query` parameters imports with `headerParameters:[]`.

**PATH and HEADER share `style="SIMPLE"`/`explode=false`; QUERY differs** (`style="FORM"`/`explode=true`) — do not assume one shape across locations:

```json
"pathParameters":[{"style":"SIMPLE","explode":false,"parameterType":"PATH","id":"cGF0aF9pZA","dataType":"INTEGER"}]
"queryParameters":[{"style":"FORM","explode":true,"parameterType":"QUERY","id":"cXVlcnlfaWQ","dataType":"STRING"}]
"headerParameters":[{"style":"SIMPLE","explode":false,"parameterType":"HEADER","id":"aGVhZGVyX1gtRWNoby1Ub2tlbg","dataType":"STRING"}]
```

| key | PATH | QUERY | HEADER |
|---|---|---|---|
| `style` | `SIMPLE` | `FORM` | `SIMPLE` |
| `explode` | `false` | `true` | `false` |
| `parameterType` | `PATH` | `QUERY` | `HEADER` |
| `id` | base64 join token (see below) | base64 join token | base64 join token |
| `dataType` | e.g. `INTEGER` | e.g. `STRING` | e.g. `STRING` |

### The Three Coordinated Artifacts
Each parameter emits three artifacts inside `GenericOperationConfig`, all keyed by the same `id`:

```xml
<field id="cGF0aF9pZA" type="integer" value=""/>
<dynamicOperationField displayType="list" id="cGF0aF9pZA" label="Path id" overrideable="true" type="integer"/>
<!-- ...and the entry inside the INPUT cookie's pathParameters array -->
```

- `overrideable="true"` on the `<dynamicOperationField>` is what surfaces the parameter as a settable Dynamic Operation Property at the step.
- The `<field>` slot serializes with an empty `value=""`.
- When the spec parameter has a `description`, it surfaces as a `<helpText>` child of the `<dynamicOperationField>` (otherwise the element is self-closing):
  ```xml
  <dynamicOperationField displayType="list" id="cXVlcnlfaWQ" label="Query id" overrideable="true" type="string"><helpText>Echoed when present</helpText></dynamicOperationField>
  ```

### The base64 `id` Token
The `id` is `base64("{location}_{paramName}")` with trailing `=` padding stripped. The **location is lowercased** (`path`, `query`, `header`); the **parameter name is kept verbatim** (case and hyphens preserved). Compute with `printf '%s' path_id | base64`:

| `{location}_{name}` | token |
|---|---|
| `path_id` | `cGF0aF9pZA` |
| `query_id` | `cXVlcnlfaWQ` |
| `query_user-name` | `cXVlcnlfdXNlci1uYW1l` |
| `header_X-Echo-Token` | `aGVhZGVyX1gtRWNoby1Ub2tlbg` |

This same token is the join key across the `<field>`, the `<dynamicOperationField>`, the cookie entry, and the process-step override.

## Setting a Parameter via Dynamic Operation Property

On the process shape, the connector action overrides the parameter in a `<dynamicProperties>` block, referencing it by the **base64 token** as `key`:

```xml
<connectoraction actionType="GET" allowDynamicCredentials="NONE" connectionId="{connection-id}"
                 connectorType="officialboomi-X3979C-opena2-prod" hideSettings="false"
                 operationId="{operation-id}">
  <parameters/>
  <dynamicProperties>
    <propertyvalue childKey="" key="cGF0aF9pZA" name="Path id" valueType="static">
      <staticparameter staticproperty="1"/>
    </propertyvalue>
  </dynamicProperties>
</connectoraction>
```

- POST operations additionally carry `parameter-profile="{requestProfileId}"` on the `<connectoraction>` (referencing the request profile); GET operations omit it. When no parameters are overridden, `<dynamicProperties/>` serializes empty.
- `key` = the operation's `dynamicOperationField` `id` (the base64 token); `name` = its `label`.
- `valueType="static"` with `<staticparameter staticproperty="{value}"/>` supplies a literal value.

## Response Field Selection

`Options/QueryOptions/Fields` enumerates the response schema's leaf fields as `<ConnectorField>` entries, all `selected="true"` by default. Array nodes flatten with `items` segments:

```xml
<ConnectorObject name="getComicById">
  <FieldList>
    <ConnectorField filterable="true" name="title" selectable="true" selected="true" sortable="true"/>
    <ConnectorField filterable="true" name="choices/items/message/content" selectable="true" selected="true" sortable="true"/>
  </FieldList>
</ConnectorObject>
```

When authoring locally, populate this list from the response schema's leaf fields (alphabetical, `/` for nesting, `/items/` for arrays) to match wizard output.
