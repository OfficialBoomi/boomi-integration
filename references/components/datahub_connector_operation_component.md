# Boomi Data Hub Connector Operation Component

## Contents
- Overview
- The Operation Is Selected by `customOperationType` (not a legacy `action`)
- Operation Catalog
- Component Structure
- GenericOperationConfig Attributes
- Per-Operation Detail
  - Update Golden Records (write)
  - Get Golden Record
  - Query Golden Records
  - Get Quarantine Entry
- Operation Fields
- The Connector Step (`connectoraction`)
- Not Documented Here
- What the agent Can / Cannot Do

## Overview

The Boomi Data Hub connector reads and writes golden records, quarantine entries, and channel updates against a deployed Boomi Data Hub (MDM) model. An operation component defines one action (e.g. write golden records, fetch one by id) plus its request/response profiles, and runs as the connector action on a connector step (or start shape). It pairs with a Boomi Data Hub Connection component.

`type="connector-action"`, `subType="officialboomi-X3979C-boomid-prod"` (the connection carries the same `connectorType`).

This is the current **Boomi Data Hub** connector. It supersedes the older **Boomi Master Data Hub (legacy)** connector, which is a different connector with a different XML shape. Do not mix the two.

The paired connection (`type="connector-settings"`, same `subType`) holds the repository credentials — `cloudName`, `accountId` (the `<account-id>.<repo-token-id>` pair), and `token`. If the `boomi-datahub` skill is available in this workspace, it can create the connection from the workspace `.env`: `datahub-connection.sh bootstrap connector <name> <folder-id>`. Otherwise have the user create it in the Boomi UI and supply its component ID. A REST Client connection pointed at the Data Hub repository API is a separate integration path, not a substitute for this one — the operations below only work against the connector's own connection.

## The Operation Is Selected by `customOperationType` (not a legacy `action`)

The operation is driven entirely by **`GenericOperationConfig/@customOperationType`** (with a matching `operationType`). There is **no `action` attribute** on this connector's operation.

> **Critical — the legacy `action="UPSERT"` form deploys cleanly but fails at execution.** Authoring the write as a legacy-style `action="UPSERT"` (with no `customOperationType`) is accepted by the API and deploys without error, then **fails when the process runs** with `java.lang.IllegalArgumentException: Custom operation ID null is not supported` — no record is written. Because push and deploy both succeed, the mistake is invisible until the process executes. Always author the write with `customOperationType="updateGoldenRecords"`.

The literal string `UPSERT` still appears — but only as the generic `operationType` on the write op, never as an `action`.

## Operation Catalog

| Operation (Action drop-down / step `actionType`) | `customOperationType` | `operationType` | Profile side |
|---|---|---|---|
| Update Golden Records | `updateGoldenRecords` | `UPSERT` | request (xml) |
| Get Golden Record | `getGoldenRecord` | `GET` | response (xml) |
| Query Golden Records | `queryGoldenRecords` | `QUERY` | response (xml) + OUTPUT cookie |
| Get Quarantine Entry | `getQuarantineEntry` | `GET` | response (xml) |

"Update Golden Records" was called **Upsert** on the legacy connector. Three further operations — **Fetch Channel Updates** (the legacy connector's **Query**), **Query Quarantine Entries**, and **Match Entities** — are named under [Not Documented Here](#not-documented-here).

## Component Structure

```xml
<?xml version="1.0" encoding="UTF-8"?>
<bns:Component xmlns:bns="http://api.platform.boomi.com/"
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               componentId=""
               name="Update Golden Records"
               type="connector-action"
               subType="officialboomi-X3979C-boomid-prod"
               folderId="{folder-id}">
  <bns:encryptedValues/>
  <bns:object>
    <Operation returnApplicationErrors="true" trackResponse="false">
      <Archiving directory="" enabled="false"/>
      <Configuration>
        <GenericOperationConfig customOperationType="updateGoldenRecords"
                                operationType="UPSERT"
                                objectTypeId="universeId_{model-guid}"
                                objectTypeName="{model}"
                                requestProfile="{request-profile-id}"
                                requestProfileType="xml"
                                responseProfileType="xml">
          <field id="source" type="string" value="{sourceId}"/>
          <field id="stagingId" type="string" value=""/>
          <Options>
            <QueryOptions>
              <Fields><ConnectorObject name="{model}"/></Fields>
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

| Attribute | Example | Meaning |
|---|---|---|
| `customOperationType` | `updateGoldenRecords` | Selects the Data Hub operation (see catalog). The operation selector. |
| `operationType` | `UPSERT`, `GET`, `QUERY` | Generic Boomi operation type paired with the `customOperationType`. |
| `objectTypeId` | `universeId_01490234-…` | The deployed model (universe), prefixed `universeId_`. |
| `objectTypeName` | `{model}` | The model name. |
| `requestProfile` / `requestProfileType` | `4de6b7a5-…` / `xml` | Request profile (write ops). |
| `responseProfile` / `responseProfileType` | `624f649e-…` / `xml` | Response profile (read ops). |

A write op carries `requestProfile` + `requestProfileType="xml"` and `responseProfileType="xml"` with **no** `responseProfile`. A read op carries `responseProfile` + `responseProfileType="xml"` and `requestProfileType="xml"` with **no** `requestProfile`. The connector's generated profiles are XML (`requestProfileType`/`responseProfileType` = `xml`).

## Per-Operation Detail

### Update Golden Records (write)

- `customOperationType="updateGoldenRecords"`, `operationType="UPSERT"`, `trackResponse="false"`.
- Submits a batch of source entities to the model. Per the deployed match rules each entity may create, update, end-date, link, or quarantine a golden record.
- **Asynchronous — connector success is not proof of a write.** The operation batches the entities for routing and returns no golden-record body, so the step succeeds without reporting what the Hub did with the entities. Confirm an effect by reading back (Get/Query Golden Records) or via the Data Hub batch report.
- Per-record behavior is requested by the payload's `@op` attribute (default empty = upsert-by-match-rules): `CREATE` requests creation, `DELETE` requests removal. The model's match rules and source configuration decide the actual outcome, so a requested `CREATE` can still land as a link or a quarantine entry.
- `<field id="source">` (required — the contributing source id) and `<field id="stagingId">` (optional staging area id) supply the Source and Staging Area ID.
- `<Fields>` carries a bare `<ConnectorObject name="{model}"/>`; `<Inputs/>` is empty.

### Get Golden Record

- `customOperationType="getGoldenRecord"`, `operationType="GET"`.
- Returns exactly one golden record addressed by **source entity id** (the input ID is the source entity id, not the internal `recordId`).
- `<Inputs><Input key="0" name="ID"/></Inputs>` binds the id. `<field id="source">` scopes the source.
- Carries a `responseProfile`; `<FieldList>` enumerates the model's fields.

### Query Golden Records

- `customOperationType="queryGoldenRecords"`, `operationType="QUERY"`.
- Returns a filtered list of active golden records.
- Requires a `responseProfile` **and** an output cookie that Get Golden Record does not. Omitting the cookie deploys, then fails at execution with `argument "content" is null`.
- `<field id="includeSourceLinks" type="boolean">` and `<field id="maxRecords" type="integer">` tune the query.
- `<FieldList>` here uses uppercase `type` values (`STRING`, `INTEGER`, `SPECIAL_DATE`, `SPECIAL`, `SOURCE_LINK`); model attribute fields appear as `@createdDate`, `@updatedDate`, `@recordIds`, etc.

Nesting matters — `<cookie>` is a sibling of the `<field>` elements, while `<FieldList>`, `<Filter>`, and `<Sorts/>` all sit inside `<ConnectorObject>` and `<Inputs>` sits under `<QueryOptions>`:

```xml
<GenericOperationConfig customOperationType="queryGoldenRecords" operationType="QUERY" …>
  <field id="includeSourceLinks" type="boolean" value="true"/>
  <field id="maxRecords" type="integer" value="10"/>
  <cookie role="OUTPUT"><value>{"make":"MAKE","model":"MODEL"}</value></cookie>
  <Options>
    <QueryOptions>
      <Fields>
        <ConnectorObject name="{model}">
          <FieldList>
            <ConnectorField filterable="true" name="make" selectable="true" selected="true" sortable="true" type="STRING"/>
          </FieldList>
          <Filter>
            <ConnectorBaseFilter>
              <ConnectorFilterExpression expressionField="make" expressionOperator="EQUALS" key="1" name="make" type="STRING"/>
            </ConnectorBaseFilter>
          </Filter>
          <Sorts/>
        </ConnectorObject>
      </Fields>
      <Inputs><Input key="1" name="make"/></Inputs>
    </QueryOptions>
  </Options>
</GenericOperationConfig>
```

- A single filter expression sits directly under `<ConnectorBaseFilter>`. Two or more MUST be wrapped in `<ConnectorFilterLogical logicalOperator="or|and">`.
- Each `<ConnectorFilterExpression>` needs a matching `<Input>` under `<Inputs>` with the same `key`.

### Get Quarantine Entry

- `customOperationType="getQuarantineEntry"`, `operationType="GET"`.
- Returns one quarantine entry (`cause`, `reason`, `fields`, `matchRule`, `resolution`, plus `[@transactionId]`, `[@sourceId]`, `[@entityId]`, `[@createdDate]`).
- Same GET shape as Get Golden Record: `responseProfile` + `<Input key="0" name="ID"/>`.

## Operation Fields

`<field>` entries inside `GenericOperationConfig` carry operation settings, keyed by `id`:

| `id` | Type | On | Meaning |
|---|---|---|---|
| `source` | string | write / read ops | Contributing (or accepting) source id. |
| `stagingId` | string | Update Golden Records | Optional staging area id; empty = not staged. |
| `includeSourceLinks` | boolean | Query Golden Records | Include source links in results. |
| `maxRecords` | integer | Query Golden Records | Cap on records returned. |

## The Connector Step (`connectoraction`)

On a process shape, the operation runs via a `connectoraction` whose **`actionType` is the operation's display name** — not a generic `Send`/`Get` verb:

```xml
<shape image="connectoraction_icon" shapetype="connectoraction" name="shape2" ...>
  <configuration>
    <connectoraction actionType="Update Golden Records"
                     allowDynamicCredentials="NONE"
                     connectionId="{connection-id}"
                     connectorType="officialboomi-X3979C-boomid-prod"
                     hideSettings="false"
                     operationId="{operation-id}"
                     parameter-profile="{request-profile-id}">
      <parameters/>
      <dynamicProperties/>
    </connectoraction>
  </configuration>
</shape>
```

- `actionType` = the operation label: `Update Golden Records`, `Get Golden Record`, `Query Golden Records`, `Get Quarantine Entry`, …
- `connectorType` equals the connection/operation `subType` (`officialboomi-X3979C-boomid-prod`).
- `connectionId` → the Boomi Data Hub Connection component; `operationId` → the operation component.
- Write-op steps carry `parameter-profile` referencing the request profile; `<parameters/>` and `<dynamicProperties/>` serialize empty when nothing is overridden.

## Not Documented Here

These connector operations exist, but their XML shape is not yet documented in this skill. Name them correctly, and pull a real component to confirm the `customOperationType`/step shape before authoring one:

- **Fetch Channel Updates** — pulls batches of source update requests (<=200/batch); previously called **Query** on the legacy connector. Supports automatic vs. manual acknowledgement (the `MDM Current Delivery Id` tracked property).
- **Query Quarantine Entries** — filtered list of quarantine entries.
- **Match Entities** — lists match results for a batch of entities from a contributing source.

## What the agent Can / Cannot Do

**Can:**
- Author any of the catalogued operations, selecting it with `customOperationType`.
- Set `source`/`stagingId`, adjust Query filters/`maxRecords`, and wire the `connectoraction` step (`actionType` = operation label).
- Point the user at `boomi-datahub`'s `datahub-connection.sh bootstrap connector` for the paired connection, rather than sending them to the UI.

**Cannot / must confirm first:**
- Bind an operation to a model without a valid `objectTypeId` (`universeId_…`) for a **deployed** model — the model must be published with an open source channel for writes to land.
- Treat a write step's success as proof the Hub accepted the records — read back to confirm.
- Author Fetch Channel Updates / Query Quarantine Entries / Match Entities from names alone — pull a real component first.
