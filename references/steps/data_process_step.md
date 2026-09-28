# Data Process Step Reference

## Contents
- Purpose
- Configuration Structure
- Critical Step Name Convention
- Custom Scripting
- Search/Replace
- Split Documents
- Combine Documents
- Base64 Encode/Decode
- Zip/Unzip
- Chaining Operations
- Available Data Process Type Reference
- Important Notes

## Purpose
Data Process steps are the "Swiss army knife" for document manipulation - performing inline operations including custom scripting, splitting, combining, encoding/decoding, compression, and transformations without requiring external components.

**Use when:**
- Transforming data that Maps can't handle elegantly
- Splitting or combining documents
- Base64 encoding/decoding
- Compressing or decompressing content
- Custom Groovy scripting for complex logic
- Search and replace operations

## Configuration Structure
```xml
<shape image="dataprocess_icon" name="[shapeName]" shapetype="dataprocess" userlabel="[label]" x="[x]" y="[y]">
  <configuration>
    <dataprocess>
      <step index="[sequence]" key="[key]" name="[operation-name]" processtype="[type-code]">
        <!-- Operation-specific configuration -->
      </step>
    </dataprocess>
  </configuration>
  <dragpoints>
    <dragpoint name="[shapeName].dragpoint1" toShape="[nextShape]" x="[x]" y="[y]"/>
  </dragpoints>
</shape>
```

## CRITICAL: Step Name Convention
**ALWAYS use standard operation names in the step `name` attribute**:
- Process Type 12 → `name="Custom Scripting"`
- Process Type 1 → `name="Search/Replace"`
- Process Type 8 → `name="Split Documents"`
- Process Type 9 → `name="Combine Documents"`
- Process Type 6 → `name="Base64 Encode"`
- Process Type 7 → `name="Base64 Decode"`
- Process Type 5 → `name="Unzip"`
- Process Type 4 → `name="Zip"`

**Use the shape `userlabel` attribute for descriptive naming** (e.g., `userlabel="Generate Mock Data"`).

Customizing the step name causes GUI display issues. Keep step names generic and standard.

## Custom Scripting (Process Type 12)

Inline or component-backed scripting in Groovy (1.5/2.4) or JavaScript. See `references/steps/data_process_custom_scripting.md`, which covers:
- Development philosophy: Minimalism and reliability
- Mandatory dataContext loop pattern
- Dynamic Document Properties (DDPs) and Dynamic Process Properties (DPPs)
- Complete working examples
- Scripting languages and language tokens
- Referencing a reusable Process Script component (`type="script.processing"`)
- Critical rules and gotchas
- Common patterns reference

**Quick reference**:
- Step name MUST be `name="Custom Scripting"` (use `userlabel=""` for description)
- ALWAYS call `dataContext.storeStream()` or document disappears
- Default to Groovy 2.4 (`language="groovy2"`); JavaScript (`javascript`) and Groovy 1.5 (`groovy`) are also supported
- Keep scripts minimal
- Prefer native Boomi components over complex scripting

## Search/Replace (Process Type 1)

Replace text within documents. **Prefer `searchType="document"`** for reliable pattern matching across the entire document.

### Search Type Options

- `document`: Process entire document at once (recommended - no boundary issues)
- `line`: Process line by line
- `char_limit`: Process in chunks (may miss patterns split by chunk boundaries)

### Basic String Replacement

Simple text substitution across the entire document:

```xml
<step index="1" key="1" name="Search/Replace" processtype="1">
  <dataprocessreplace
    texttofind="placeholder"
    replacewith="actual-value"
    searchType="document"/>
</step>
```

### Removing Line Breaks for JSON Payloads

When embedding dynamic content in e.g. JSON payloads, line breaks break JSON structure:

```xml
<step index="2" key="2" name="Search/Replace" processtype="1">
  <dataprocessreplace
    replacewith=""
    searchType="document"
    texttofind="[\r\n]"/>
</step>
```

Removes all carriage returns and line feeds for safe JSON embedding.

### Configuration Attributes

- `texttofind`: String or regex pattern
- `replacewith`: Replacement string (empty string removes matches)
- `searchType`: "document" (recommended), "line", or "char_limit"
- `searchCharacterLimit`: Chunk size in characters (required for char_limit)

**Gotcha:** `char_limit` can miss patterns split across boundaries. For example, searching for "philadelphia" with a 1024-character chunk might fail if the boundary splits it as "phil|adelphia". Use `char_limit` only for single characters or very short strings.

## Split Documents (Process Type 8)

Split one document into many. Four profile types are supported, each with its own options element and its own attribute set.

| `profileType` | Options element | Splits by |
|---|---|---|
| `json` | `JSONOptions` | array element |
| `xml` | `XMLOptions` | repeating element |
| `ff` (Flat File) | `FFOptions` | line, or profile link element |
| `edi` | `EDIOptions` | segment or data element |

Attributes are emitted alphabetically. `batchCount="0"` is never emitted, even when explicitly set to `0`.

### JSON and XML

```xml
<step index="3" key="3" name="Split Documents" processtype="8">
  <documentsplit profileType="json">
    <SplitOptions>
      <JSONOptions batchCount="25" linkElementKey="5"
                   linkElementName="ArrayElement1 (Root/Object/orders/orders/ArrayElement1)"
                   profileId="[guid]"/>
    </SplitOptions>
  </documentsplit>
</step>
```

```xml
<documentsplit profileType="xml">
  <SplitOptions>
    <XMLOptions batchCount="25" linkElementKey="2" linkElementName="order (orders/order)"
                profileId="[guid]"/>
  </SplitOptions>
</documentsplit>
```

- `profileId`: GUID of the profile component
- `linkElementKey`: element key from the profile
- `linkElementName`: `name (slash/separated/path)` — the GUI labels this picker **Split Element** for XML and JSON, but it still writes `linkElement*`
- `batchCount`: elements per output document; `0` (the default) means one per document

`batchCount` is honored only when there are **no peer elements** along the path to the split element. With peers — or, for JSON, when the split element is an absolute array or object element — the "non-batch" split method is used and `batchCount` is ignored, with no error and status COMPLETE. The two paths are distinguishable in the output: the batch method emits compact single-line output, the non-batch method emits pretty-printed, indented output.

For JSON, the doubled path segment (`orders/orders`) is the `JSONObjectEntry` → `JSONArray` pair; both carry the array's name.

### Flat File

Flat file has two sub-modes, selected by `splitOption`. **Always set it explicitly.** A `split_profile` step missing its link element — whether because `splitOption` was omitted and fell back to `split_profile`, or because the GUI produced it (see below) — pushes, packages and deploys cleanly, then fails when a document reaches the step:

```
java.lang.IllegalArgumentException: The Link Element was not selected for a Split Documents By Profile processing step.
```

Two GUI paths produce that config: switching `Split Options` to `Split By Profile` leaves `Profile` and `Link Element` unset and saves without warning, and a `Split By Profile` → `Split By Line` → `Split By Profile` round trip clears both pickers and does not restore them (`profileId` and `batchCount` survive; `linkElementKey` and `linkElementName` do not).

```xml
<!-- Split by line -->
<documentsplit profileType="ff">
  <SplitOptions>
    <FFOptions batchCount="1000" headersOption="retain" splitOption="split_line"/>
  </SplitOptions>
</documentsplit>
```

```xml
<!-- Split by profile -->
<documentsplit profileType="ff">
  <SplitOptions>
    <FFOptions batchCount="5" headersOption="retain" linkElementKey="3"
               linkElementName="customer_code (Record/Elements/customer_code)"
               profileId="[guid]" splitOption="split_profile"/>
  </SplitOptions>
</documentsplit>
```

- `splitOption`: `split_line` or `split_profile`
- `headersOption`: `retain`, `remove`, `none`, or omitted — `none` and omitted are equivalent. Meaning depends on `splitOption`:

  | | `split_line` (no profile reference) | `split_profile` (has `profileId`) |
  |---|---|---|
  | `retain` | header line kept on every output document | header line kept on every output document |
  | `remove` | header stripped; no output document has one | header stripped; no output document has one |
  | `none` | **header line is treated as a DATA record** and batched like any other row | header stripped — identical to `remove` |
  | omitted | identical to `none` | identical to `none` and `remove` |

  In `split_profile` the step holds a `profileId`, so a profile with `useColumnHeaders="true"` has its header line recognized and stripped regardless; `headersOption` then only decides whether it is re-emitted onto each output document. In `split_line` there is no profile to read, so `none` or omission leaves the header line in the data.
- `batchCount`: **meaning depends on `splitOption`.** With `split_line` it is **rows** per output document. With `split_profile` it is the number of link-element **groups** per output document — a group is never split across documents, so `batchCount="2"` over 3 distinct link values yields 2 documents (groups 1+2, then group 3), not a row-capped split. `0` (the default) means one row per document and one group per document respectively.

A natively authored `split_line` config carries **no** profile attributes. `split_profile` requires all three — `profileId`, `linkElementKey`, `linkElementName` — and the profile must contain the link element.

**But `split_line` can carry an orphaned `profileId`.** Switching `Split Options` from `Split By Profile` to `Split By Line` in the GUI drops `linkElementKey` and `linkElementName` while leaving `profileId` behind. The orphan is inert — the step splits by line and the profile reference is ignored — but it is still a live component reference, so it appears in dependency queries and is packaged on deploy. **Always read `splitOption` to determine the sub-mode; never infer it from the presence of `profileId`.**

Splitting by profile **groups** rows: rows sharing the same link element value land in the same output document, and they need not be consecutive in the source — the step scans the whole document. `headersOption="retain"` puts the header line on **every** output document, not only the first.

One attribute, two GUI controls: a three-way `Headers Option` radio in `split_line`, a `Keep Headers` checkbox in `split_profile`. They never appear together, and switching sub-mode carries the stored value across — so a `split_profile` step can arrive with `Keep Headers` already checked from a `retain` set in `split_line`. All four values are reachable from the GUI, so when reading a pulled config, `headersOption` tells you nothing about which control set it; only `splitOption` fixes its meaning.

For a profile with `useColumnHeaders="true"`, `headersOption="retain"` is the **only correct value** whenever a downstream step parses the split output against that profile — and in `split_line` mode it is the step's only way to supply it, because the step holds no profile reference and cannot read `useColumnHeaders` itself. The other two values corrupt data without naming the cause:

| `headersOption` | What the downstream parse sees | Result |
|---|---|---|
| `retain` | every document starts with the header line | correct; all rows survive |
| `remove` | no document has a header line | the **first data row of every document** is eaten as the header — one row lost per document, silently, status COMPLETE. A document left with **zero** data rows raises `No data produced from map '<name>', please check source profile and make sure it matches source data.` and **no documents reach the next step at all** |
| omitted (`none`) | the header line is a data row, so only document 1 starts with it | document 1 parses correctly; documents 2..N each lose their first data row, silently, status COMPLETE |

The error text names the **map** and the **source profile**, never the Split step or `headersOption`, so the diagnostic points away from the actual cause.

### EDI

```xml
<documentsplit profileType="edi">
  <SplitOptions>
    <EDIOptions linkElementKey="13" linkElementName="PO1 (Detail/PO1/PO1)" profileId="[guid]"/>
  </SplitOptions>
</documentsplit>
```

`EDIOptions` has **no `batchCount`** — the field does not exist for EDI.

The link element may be a segment or a data element inside one; both use the same `name (slash/separated/path)` format, differing only in depth:

| Target | `linkElementName` |
|---|---|
| Segment | `PO1 (Detail/PO1/PO1)` |
| Data element | `PO101 (Detail/PO1/PO1/PO101)` |

When a repeating loop wraps the segment, the loop appears in the display path but the binding is to the segment's own key, not the loop's.

Unlike flat file, **EDI splitting does not group** — each link element instance and its data become a distinct document. Editing any element in the EDI profile resets the link element selection, so re-select it after profile changes.

### Multiple Input Documents

Split Documents operates per document. To split across a batch, put a Combine Documents step before it.

### Reading Split Counts in a Process Log

The step emits two count lines and they do not always agree. In `split_line` mode `Split resulted in N document(s).` counts only **full** batches and omits a trailing partial one — 9 rows at `batchCount="2"` logs `Split resulted in 4` immediately above `Completed with 5 documents out`. Trust `Completed with N documents out`.

### Output Document Shape

A split is a filter, not an unwrap — each output document keeps the parent wrapper, holding only the split element occurrences belonging to that document. At the default `batchCount`, `{"orders":[A,B,C]}` yields `{"orders":[A]}`, `{"orders":[B]}`, `{"orders":[C]}` — never bare `A`/`B`/`C`. A higher `batchCount` puts several occurrences in each wrapper rather than one. XML behaves the same.

Downstream steps must therefore reuse the pre-split profile and its nested keys (`Root/Object/orders/orders/ArrayElement1/Object/id`, not `Root/Object/id`). A flattened single-element profile fails — see `references/guides/boomi_error_reference.md` Issue #34 for the per-step failure modes.

## Combine Documents (Process Type 9)

Combine multiple documents into arrays or repeating elements.

```xml
<step index="4" key="4" name="Combine Documents" processtype="9">
  <dataprocesscombine profileType="json">
    <JSONOptions 
      combineIntoLinkElementKey="null"
      linkElementKey="9" 
      linkElementName="ArrayElement1 (Root/Object/samplearray/samplearray/ArrayElement1)" 
      profileId="8aa8e4ca-e5ef-497f-84ae-adb50f871c4b"/>
  </dataprocesscombine>
</step>
```

Configuration:
- `profileType`: "json" or "xml"
- `profileId`: GUID of the profile component
- `linkElementKey`: Element to combine into
- `linkElementName`: Human-readable path
- `combineIntoLinkElementKey`: Parent element key (often "null" for root)

## Base64 Encode (Process Type 6)

Encode document content to Base64.

```xml
<step index="5" key="5" name="Base64 Encode" processtype="6"/>
```

No additional configuration required.

## Base64 Decode (Process Type 7)

Decode Base64 content to binary.

```xml
<step index="6" key="6" name="Base64 Decode" processtype="7"/>
```

No additional configuration required.

## Unzip (Process Type 5)

Extract files from ZIP archives.

```xml
<step index="7" key="7" name="Unzip" processtype="5">
  <dataprocessunzip connectorType=""/>
</step>
```

Optional `connectorType` attribute for specific handling.

## Zip (Process Type 4)

Compress documents into ZIP archive.

```xml
<step index="8" key="8" name="Zip" processtype="4">
  <dataprocesszip/>
</step>
```

Empty configuration element required.

## Chaining Operations

Multiple operations execute in sequence based on index values:

```xml
<dataprocess>
  <step index="1" key="1" name="Unzip" processtype="5">
    <dataprocessunzip connectorType=""/>
  </step>
  <step index="2" key="2" name="Search/Replace" processtype="1">
    <dataprocessreplace texttofind="old" replacewith="new" searchType="char_limit" searchCharacterLimit="1024"/>
  </step>
  <step index="3" key="3" name="Base64 Encode" processtype="6"/>
</dataprocess>
```

## Additional Data Process Mechanisms

The step includes other available operations that we've left out of scope on this project. If you see them in a user's design try your best to handle the objective and inform the user you don't have specific documentation of that step:
- **GZIP Compress/Decompress**: Process types for GZIP compression
- **Character Encoding**: Convert between character sets (UTF-8, ISO-8859-1, etc.)
- **Change Case**: Convert to upper, lower, or title case
- **Add Data**: Prefix or suffix content
- **Remove Data**: Strip content by pattern or position

## Available Data Process Type Reference
| Type | Operation | Configuration Element |
|------|-----------|----------------------|
| 1 | Search/Replace | `<dataprocessreplace>` |
| 4 | Zip | `<dataprocesszip>` |
| 5 | Unzip | `<dataprocessunzip>` |
| 6 | Base64 Encode | None |
| 7 | Base64 Decode | None |
| 8 | Split Documents | `<documentsplit>` |
| 9 | Combine Documents | `<dataprocesscombine>` |
| 12 | Custom Scripting | `<dataprocessscript>` - See references/steps/data_process_custom_scripting.md |

## Important Notes
- Operations execute in index order
- Each step needs unique index and key values
- Most operations stream data (memory efficient)
- Combine, and every Split mode except flat file `split_line`, require a profile component
- Custom Scripting requires the `language` attribute on `<dataprocessscript>` (`useCache` is an optional performance flag); see references/steps/data_process_custom_scripting.md
