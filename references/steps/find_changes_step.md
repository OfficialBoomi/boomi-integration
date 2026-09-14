# Find Changes Step Reference

## Contents
- Purpose
- Critical Configuration Requirements
- Shape Identity
- Configuration Structure
- profileType Enumeration
- KeyColumn Derivation
- Output Paths & Wiring
- State Model
- Record Granularity
- Testing
- Troubleshooting
- Reference XML Examples

## Purpose
The Find Changes step (Change Data Capture / CDC) compares the current inbound document set against a snapshot stored from the last successful execution, and routes each record down an **Add**, **Update**, or **Delete** path. It is a routing shape: one inbound path in, three labeled outbound paths out. No connection or operation component is involved.

**Use when:**
- Every execution carries the **complete** dataset and you must detect adds, updates, and deletes
- The source cannot provide incremental "modified since" queries
- A lightweight in-process CDC solution is needed and record structure/keys are stable across executions

**Edition gating:** Advanced Workflow feature — available only in Professional, Professional Plus, Enterprise, and Enterprise Plus editions.

## Critical Configuration Requirements

- **`profileType` is a closed enumeration: `ff` | `db` | `xml`.** No other value is accepted (see below). `json` is rejected at create/push time.
- **`profileId`** must reference a profile component whose type matches the `profileType` token.
- **At least one `<KeyColumn>`** must identify each record. Its `index` and `name` are derived from the profile (see KeyColumn Derivation).
- **Exactly three output dragpoints**, with `identifier`/`text` of `Add`, `Update`, and `Delete`.

## Shape Identity

| Property | Value |
|---|---|
| `shapetype` | `changedatacapture` |
| `image` | `changedatacapture_icon` |
| GUI name | **Find Changes** |
| Config element | `<changedatacapture profileId="…" profileType="…">` with one or more `<KeyColumn>` children |

## Configuration Structure
```xml
<shape image="changedatacapture_icon" name="[shapeName]" shapetype="changedatacapture" userlabel="[display label]" x="[x]" y="[y]">
  <configuration>
    <changedatacapture profileId="[profile GUID]" profileType="[ff|db|xml]">
      <KeyColumn index="[element key]" name="[field] ([root]/…/[field])"/>
      <!-- additional KeyColumn children form a composite key -->
    </changedatacapture>
  </configuration>
  <dragpoints>
    <dragpoint identifier="Add"    name="[shapeName].dragpoint1" text="Add"    toShape="[addTarget]"    x="[x]" y="[y]"/>
    <dragpoint identifier="Update" name="[shapeName].dragpoint2" text="Update" toShape="[updateTarget]" x="[x]" y="[y]"/>
    <dragpoint identifier="Delete" name="[shapeName].dragpoint3" text="Delete" toShape="[deleteTarget]" x="[x]" y="[y]"/>
  </dragpoints>
</shape>
```

The display name is set via `userlabel` on the `<shape>` element; the `<changedatacapture>` element itself has no name attribute. A blank `userlabel` displays as "Find Changes".

## profileType Enumeration

`profileType` accepts only three short tokens, which map to profile component types:

| Profile component type | `profileType` token | Profile element carrying the key |
|---|---|---|
| `profile.flatfile` | `ff` | `FlatFileElement` |
| `profile.db` | `db` | `DatabaseElement` |
| `profile.xml` | `xml` | `XMLElement` |

`profile.json` is **not supported**. A shape with `profileType="json"` is rejected at create/push time with `HTTP 400: cvc-enumeration-valid: Value 'json' is not facet-valid with respect to enumeration '[ff, db, xml]'`. To perform CDC over JSON data, convert JSON → XML upstream (a Map, or a JSON-to-XML Data Process step) and use `profileType="xml"`.

Note the token is the short form (`ff`/`db`/`xml`), **not** the `profile.*` string used in other shapes' `profileType` attributes.

## KeyColumn Derivation

Each `<KeyColumn>` has two attributes, both derived from the referenced profile:

- **`index`** = the target profile element's own `key` attribute.
- **`name`** = `"<field-name> (<path>)"`, where `<path>` is the slash-joined chain of node `name` values from the profile's root node down to and including the field itself. The root node is included. The `name` is a display label; the shape resolves records by `index`.

To compute it: load the profile, find the element (read its `key` → `index`), walk its ancestors up to the root collecting each `name`, append the field's own `name`, join with `/`.

| Profile type | Profile element | Resulting KeyColumn |
|---|---|---|
| `ff` | `FlatFileElement key="3" name="First Name"` under `Record` → `Elements` | `index="3" name="First Name (Record/Elements/First Name)"` |
| `xml` | `XMLElement key="3" name="id"` under `Customers` → `Customer` | `index="3" name="id (Customers/Customer/id)"` |
| `db` | `DatabaseElement key="19" name="flag"` under `Statement` → `Fields` | `index="19" name="flag (Statement/Fields/flag)"` |

**Composite key:** emit multiple `<KeyColumn>` children (order preserved). The key field(s) must uniquely identify a record and hold stable values across executions.

If the profile changes so that an element's key no longer exists, the GUI flags that KeyColumn as invalid; remove and re-add it.

## Output Paths & Wiring

| `identifier` / `text` | Meaning |
|---|---|
| `Add` | Key present in current data but not in the stored snapshot |
| `Update` | Key present in both; record content differs (comparison spans the **entire** profile structure) |
| `Delete` | Key present in the stored snapshot but missing from current data; routes the **previously stored** version of the record |

- Each dragpoint's `identifier` and `text` must be exactly `Add` / `Update` / `Delete`.
- **Do not wire two of these outcomes into the same target shape** — the labels overprint into an unreadable canvas (the Converging Outcomes rule in `BOOMI_THINKING.md`). Give each path its own downstream step (even an inert Notify) before converging.

## State Model

The shape takes a **single inbound path** (the current dataset) and compares it against an internally-managed snapshot — the "previous" data is runtime state, not a second wired path.

- State is stored on the runtime under `<runtime_install_dir>/work/cdc/<component_ID_of_process>/…`, keyed by **Main Process ID + the shape's internal Step Number**.
- **First execution** (no state): every record routes to **Add**, then the snapshot is written.
- **Unchanged execution:** nothing routes to any path. With `stopProcessingIfZeroDocuments="true"` the process simply produces no downstream documents.
- The snapshot updates **only after a successful execution**. If the process errors after the shape, the snapshot may not update and the next execution can misclassify. Wrap the shape and its downstream steps in **Try/Catch**.
- **Reset** by deleting the `work/cdc/<component_ID>` directory on a local runtime (e.g. before promoting to production, or to reprocess everything as new). This directory is not directly accessible on a cloud runtime.

**Full-dataset requirement:** any key missing from the current set is treated as a **Delete**. A partial or incremental pull therefore produces **false deletes**. Only use Find Changes when every execution carries the complete dataset.

**Subprocess caveat:** because state is keyed by Main Process ID + Step Number, calling the same subprocess (containing a CDC shape) from multiple parents — or two subprocesses sharing an internal step number — can collide on the same state file. Keep CDC shapes in a single main process, or ensure unique identities.

## Record Granularity

**Find Changes compares one inbound document as one record**, matched by key and compared across the entire profile structure. The number of records evaluated equals the number of **inbound documents** reaching the shape — not the number of repeating elements inside a document.

- **Flat File** profiles are inherently record-oriented (the profile defines a `FlatFileRecord`). A single inbound file of N rows is split into **N per-record documents**, so Add/Update/Delete fire **per row** automatically.
- **XML** is **not** split automatically. A single inbound document — even one whose profile defines a repeating record element — is compared as **one record**, and the whole document routes down one path. The profile's `maxOccurs` on the record element does **not** change this; it affects XML parsing only. To get **per-record** XML CDC, the records must arrive as **individual documents** before the shape — e.g. split the batch with a Data Process "Split Documents" step (splitting on the repeating element) so each record reaches the shape as its own document.

**XML parsing caveat:** an XML profile with the record element set to `maxOccurs="1"` and `parseRespectMaxOccurs="true"` **silently truncates** a multi-record document to its first occurrence before the shape sees it — the remaining records are discarded (which then read as deletes on the next execution). Model the repeating record element as `maxOccurs="-1"` so all records are retained.

## Testing

Feed the current dataset from an in-canvas **Message** step (CSV for `ff`, an XML document for `xml`), since a document payload cannot be injected over the API. Then:
1. Deploy and execute (execution 1): expect everything down **Add**.
2. Execute again with identical data (execution 2): expect **no** documents routed.
3. To see Update/Delete: change the Message content (modify a record → Update; remove a record → Delete) and redeploy between executions.
4. To re-baseline, delete `work/cdc/<component_ID>` on a local runtime.

## Troubleshooting

| Symptom | Cause / Fix |
|---|---|
| `HTTP 400 cvc-enumeration-valid` on create/push | `profileType` set to an unsupported value (e.g. `json`). Use `ff`/`db`/`xml`; convert JSON → XML first. |
| Everything routes to Delete unexpectedly | Inbound set is not the full dataset — missing keys read as deletes. Supply the complete dataset every execution. |
| No changes ever detected | Misconfigured key field or profile mismatch between executions. |
| Stale deletes / everything re-adds | Snapshot not reset after a structure/profile/key change, or a prior execution errored before the snapshot updated. Reset `work/cdc`. |
| XML detects one change for a whole batch | Batch arrived as a single document. Split into one document per record upstream. |
| XML records silently missing | Record element `maxOccurs="1"` truncated the input. Set `maxOccurs="-1"`. |
| Duplicates in Add/Update | Key is not unique. Refine the key column(s). |

## Reference XML Examples

### Flat File — composite key, per-record detection
```xml
<shape image="changedatacapture_icon" name="shape3" shapetype="changedatacapture" userlabel="Find Changes on First+Last Name" x="560.0" y="96.0">
  <configuration>
    <changedatacapture profileId="f2d43ecd-06c3-418c-af14-aa418f866209" profileType="ff">
      <KeyColumn index="3" name="First Name (Record/Elements/First Name)"/>
      <KeyColumn index="4" name="Last Name (Record/Elements/Last Name)"/>
    </changedatacapture>
  </configuration>
  <dragpoints>
    <dragpoint identifier="Add"    name="shape3.dragpoint1" text="Add"    toShape="shape4" x="800.0" y="8.0"/>
    <dragpoint identifier="Update" name="shape3.dragpoint2" text="Update" toShape="shape6" x="800.0" y="112.0"/>
    <dragpoint identifier="Delete" name="shape3.dragpoint3" text="Delete" toShape="shape8" x="800.0" y="216.0"/>
  </dragpoints>
</shape>
```

### XML — single key
```xml
<shape image="changedatacapture_icon" name="shape3" shapetype="changedatacapture" userlabel="Find Changes on customer id" x="560.0" y="96.0">
  <configuration>
    <changedatacapture profileId="fa90792b-6344-4f15-8de8-5e79ffceaf8d" profileType="xml">
      <KeyColumn index="3" name="id (Customers/Customer/id)"/>
    </changedatacapture>
  </configuration>
  <dragpoints>
    <dragpoint identifier="Add"    name="shape3.dragpoint1" text="Add"    toShape="shape4" x="800.0" y="8.0"/>
    <dragpoint identifier="Update" name="shape3.dragpoint2" text="Update" toShape="shape6" x="800.0" y="112.0"/>
    <dragpoint identifier="Delete" name="shape3.dragpoint3" text="Delete" toShape="shape8" x="800.0" y="216.0"/>
  </dragpoints>
</shape>
```
