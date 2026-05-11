# API Service Component (REST)

## Contents
- Critical Requirements
- Overview
- When to Use It (vs bare WSS Listener)
- Component Structure
- REST Route Overrides
- URL Path Construction
- Path Collisions
- Profile Overrides
- Required Placeholder Elements
- Dependencies
- Common Patterns
- Out of Scope

## Critical Requirements

- Component `type="webservice"` (the UI calls this an "API Service Component"; the XML and Platform API both use `webservice`).
- **Request routing works only when the target runtime has `SharedServerInformation.apiType = "advanced"`.** Deploying to a runtime with `apiType = "basic"` or `"intermediate"` completes successfully — the Deploy API returns `SUCCESS` and the package attaches — **but every route returns HTTP 404 "Unknown operation for the given URL path" at request time.**
- The discriminator is the `apiType` field on `SharedServerInformation/{atomId}`, values `basic | intermediate | advanced`. **It is NOT the `Atom.type` field** (which returns `CLOUD | ATOM | MOLECULE | CLOUDMOLECULE` and is orthogonal to API tier). An agent querying `Atom/{id}` to check API-Service-Component eligibility will reach the wrong conclusion. Note: the Platform API resource is literally named `Atom` — "runtime" is the business-facing term for the same concept.
- **The API Service Component and each linked Listen process must both be independently deployed to the target runtime.** Deploying only the component leaves routes registered but listeners unbound — requests fail at request time. Deploy API returns `SUCCESS` on the component-only case and does not surface the missing listener.
- **Path collisions on the same runtime are silently accepted** at every gate (save, package, deploy). First-deployed serves the route; the second component is silently shadowed at request time. See the Path Collisions section for reclaim mechanics and detection.
- Requires API Management to be enabled on the account.
- Every REST route MUST reference a `processId` whose linked process has a WSS Start step (`actionType="Listen"`) bound to a `connector-action` of `subType="wss"`.
- The following sub-elements MUST be present in the XML even when unused: `<soapApi>`, `<odataApi/>`, `<metaInfo>`, `<profileOverrides>` (or `<profileOverrides/>` if empty), `<capturedHeaders/>`, `<apiRoles/>`. Platform serializes them on round-trip.

## Overview

An API Service Component binds one or more Listen-typed processes to a shared URL tree on an Advanced runtime. Each REST route in the component points at one process. The component also carries API-level metadata (title, version) and generates an OpenAPI specification at deploy time.

Contrast with the bare WSS listener paradigm documented in `web_services_server_start_shape_operation.md`: that pattern deploys a single Listen process directly to a Basic or Intermediate runtime, producing a fixed `/ws/simple/{operationType}{objectName}` URL. The API Service Component replaces that direct-deploy path with a curated URL tree and is the **only** way to stand up REST listeners on Advanced runtimes.

**Recommended build order:** author the Listen process (with its WSS operation and profiles) first, then wrap it with the API Service Component. Route overrides inherit from the linked WSS operation when left empty, so having the process in place gives the API a contract to lean on.

## When to Use It (vs bare WSS Listener)

| Situation | Use |
|---|---|
| Basic or Intermediate runtime, simple URL pattern acceptable | Bare WSS listener process — `web_services_server_start_shape_operation.md` |
| Advanced runtime, any REST API deployment | **API Service Component (this doc)** |
| Need curated URL paths different from `/ws/simple/...` | API Service Component |
| Need multiple endpoints under one deployable unit | API Service Component |
| Need generated OpenAPI spec | API Service Component |

## Component Structure

### Minimal single-route REST API

```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<bns:Component xmlns:bns="http://api.platform.boomi.com/" type="webservice" name="MyApi">
  <bns:encryptedValues/>
  <bns:description/>
  <bns:object>
    <webservice xmlns="" urlPath="my_base_path">
      <restApi>
        <route processId="{linked-process-guid}">
          <overrides
            httpMethod=""
            inputProfileKey=""
            inputType=""
            objectName=""
            outputProfileKey=""
            outputType=""
            urlPath="hello"/>
          <description/>
        </route>
      </restApi>
      <soapApi fullEnvelopePassthrough="false" singleWsdlSchema="false"
               suppressWrappers="false" wsdlNamespace="" wsdlServiceName="">
        <SOAPVersion>SOAP_1_1</SOAPVersion>
      </soapApi>
      <odataApi/>
      <metaInfo title="MyApi" version="1" contactEmail="" contactName=""
                contactUrl="" licenseName="" licenseUrl="">
        <description/>
        <termsOfService/>
      </metaInfo>
      <profileOverrides/>
      <capturedHeaders/>
      <apiRoles/>
    </webservice>
  </bns:object>
</bns:Component>
```

### Multi-endpoint REST API (mixed HTTP methods, shared object segment)

```xml
<restApi>
  <route processId="{query-process-guid}">
    <overrides contentType="" httpMethod="POST" inputProfileKey=""
               inputType="" objectName="" outputProfileKey=""
               outputType="" urlPath="query"/>
    <description/>
  </route>
  <route processId="{user-profile-process-guid}">
    <overrides contentType="" httpMethod="GET" inputProfileKey=""
               inputType="" objectName="resource" outputProfileKey=""
               outputType="" urlPath="userdetails"/>
    <description/>
  </route>
  <route processId="{policy-process-guid}">
    <overrides contentType="" httpMethod="GET" inputProfileKey=""
               inputType="" objectName="resource" outputProfileKey=""
               outputType="" urlPath="leave_policy"/>
    <description/>
  </route>
</restApi>
```

Multiple routes can share the same `objectName` to produce a common URL segment under the base path.

## REST Route Overrides

Attributes on `<route><overrides .../>`. An empty string means "inherit from the linked WSS operation"; any non-empty value replaces the inherited value for this route only. **Per-attribute inheritance is the single most important invariant when reading or editing the component XML.**

| Attribute | Purpose | Values |
|---|---|---|
| `urlPath` | Final path segment appended after base path and `objectName` | Free-form string (e.g. `test_listener`, `query`, `userdetails`) |
| `objectName` | Path segment between the base path and `urlPath`; empty string omits the segment | Free-form string, or `""` to omit |
| `httpMethod` | HTTP method for this route | `GET`, `POST`, `PUT`, `DELETE`, `PATCH`, or `""` to inherit |
| `inputType` | Input body shape for this route | `none`, `singledata`, `singlejson`, `multijson`, `singlexml`, `multixml`, or `""` to inherit |
| `outputType` | Output body shape for this route | Same value set as `inputType`, or `""` to inherit |
| `inputProfileKey` | Key into `<profileOverrides>` to select a request profile for this route | Synthetic key string, or `""` to inherit |
| `outputProfileKey` | Key into `<profileOverrides>` to select a response profile for this route | Synthetic key string, or `""` to inherit |
| `contentType` | Response content type override | MIME type string, or `""` to inherit |

## URL Path Construction

Effective route path:

```
/<base>/<objectName>/<urlPath>
```

Full URL: `<SharedServerInformation.url>/ws/rest/<base>/<objectName>/<urlPath>` — the `url` field returned by `boomi-shared-server-info.sh` supplies the authority (`https://<host>` on cloud runtimes).

Each segment's effective value follows the override-inheritance rule: if the route's `<overrides>` attribute is non-empty it replaces; otherwise the value inherits from the linked WSS operation. An effective value of `""` omits that segment.

| Route (source) | Route override `objectName` | Linked WSS op `objectName` | Effective URL |
|---|---|---|---|
| `hr/query` | `""` → inherit | `HubGR` | `/hr/HubGR/query` |
| `hr/userdetails` | `resource` → replaces | `currentUserProfile` | `/hr/resource/userdetails` |
| `ao_.../interface_input_handler` | `""` → inherit | `""` | `/ao_project01/interface_modules/interface_input_handler` |

### Path Parameters

The route's `urlPath` may contain path parameters in `{name}` form (e.g. `items/{id}`). Captured values are available to the linked process as dynamic process properties named `param_<name>`. Values are captured verbatim — numeric and string forms both work. A request missing the parameter segment returns HTTP 404.

### Case Sensitivity and HTTP Method

REST API Service Component routes are case-sensitive and verbatim: `/widgets` is not equivalent to `/Widgets`. This differs from bare `/ws/simple/` URLs, which apply sentence-casing to `objectName` — see `web_services_server_start_shape_operation.md` for the bare-WSS rules.

An HTTP method that does not match the route's configured `httpMethod` returns HTTP 404, not 405. When debugging a 404, check both the URL path and the HTTP method before concluding the route is unregistered.

## Path Collisions

Two API Service Components on the same runtime with the same effective URL (`/<base>/<objectName>/<urlPath>`) both save, both package, both deploy `active=true`, and both appear in `DeployedPackage` queries — but only the first-deployed serves requests. The second component's route is silently dropped at request time.

Once shadowed, a component stays shadowed: undeploying the first does not activate the second, because the loser's route was never registered. Reclaiming the slot requires undeploying the winner, then redeploying the other component fresh. Redeploying the original winner on top of an active second does not reclaim — first-fresh-deploy into an empty slot is what owns the route.

**Detection**: query `DeployedPackage` for `componentType="webservice"` on the environment, pull each active deployment, and compare base + route URL paths across all webservice components. The Platform API does not do this for you.

The Platform Build UI surfaces a soft warning on the Base API Path field when another deployed API shares that base path ("You already have deployed API(s) with the same base path. Duplicate base paths create routing issues if the APIs are deployed to the same environment."). The warning fires on base-path duplication only, not on full effective-URL collision, and the Platform API does not return it at all — automated deploy pipelines receive no collision signal.

Cross-pattern collisions between bare WSS (`/ws/simple/...`) and ASC routes are not possible on Advanced runtimes: bare WSS paths are not registered on that tier, so the routing surfaces never overlap.

## Profile Overrides

If a pulled component contains a non-empty `<profileOverrides>` block, preserve those entries and any `inputProfileKey`/`outputProfileKey` attributes on `<route>/<overrides>` verbatim on round-trip. Do not author these programmatically — the binding uses synthetic keys that the Build UI generates, and regenerating them silently breaks the reference. For new components, leave `<profileOverrides/>` empty and handle profile selection via the linked WSS operation instead.

## Required Placeholder Elements

Even for REST-only API Service Components, the pulled XML always contains fully-formed placeholder elements for the other API shapes:

- `<soapApi fullEnvelopePassthrough="false" singleWsdlSchema="false" suppressWrappers="false" wsdlNamespace="" wsdlServiceName=""><SOAPVersion>SOAP_1_1</SOAPVersion></soapApi>` — present with defaults
- `<odataApi/>` — self-closing
- `<metaInfo ...>` with `title`, `version`, and `<description/>`, `<termsOfService/>` children — present; title and version are the only non-empty attributes typically
- `<profileOverrides/>` or `<profileOverrides>...</profileOverrides>` — always present
- `<capturedHeaders/>` — present; self-closing when no headers are captured
- `<apiRoles/>` — present; self-closing when no API roles are linked

Agents creating a new API Service Component should emit these placeholders even when the feature is unused.

## Dependencies

- **Linked process component** (`type="process"`) — must have a WSS Start step (`actionType="Listen"`) referencing a `connector-action` of `subType="wss"`. Required per route. **Must be deployed independently to the same runtime as the API Service Component** (see Critical Requirements).
- **Linked WSS operation component** (`type="connector-action"`, `subType="wss"`) — referenced transitively via the process. See `web_services_server_start_shape_operation.md` for its structure.
- **Profile components** — referenced by the WSS operation (`requestProfile`, `responseProfile`) and optionally by `<profileOverrides>` for per-route substitution.
- **Advanced runtime** — deployment target.
- **Repo convention**: pull scripts write this component type to `active-development/webservice/`. Component folders are created on demand using the platform's lowercase component-type identifier.

## Common Patterns

### API-wraps-existing-listener (default build pattern)

1. Author the Listen process first (WSS Start step bound to a WSS operation, with request/response profiles).
2. Create an API Service Component with one `<route>` pointing at that process.
3. Leave all route overrides as `""` (inherit) and let the WSS operation drive method, types, and profiles.
4. Set `<webservice urlPath="...">` to the desired base path.
5. Package and deploy **both** the Listen process and the API Service Component to the Advanced runtime. Component-only deployment silently leaves the route unbound.

### Grouping multiple Listen processes under one API

One API Service Component can host many `<route>` entries, each pointing at a different Listen process. Use shared `objectName` values to group routes under a common URL segment (see variant 2 example).

## Out of Scope

- SOAP and OData endpoint shapes of the `webservice` component.
- API Proxy components, Cloud API Management (Mashery), and API Control Plane (apiida). See `references/guides/boomi_platform_reference.md`.
- Gateway-layer policies: rate limiting, subscription plans, developer portal.
