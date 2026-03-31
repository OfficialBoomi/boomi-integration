# Document Cache Steps Reference

## Contents
- Add to Cache Step
- Retrieve From Cache Step
- Remove From Cache Step
- Cache Lookup as Parameter Source
- Common Patterns
- Scope and Lifecycle
- Reference XML Examples

The Document Cache component definition (indexes, keys, profile types) is documented in `references/components/document_cache_component.md`.

---

## Add to Cache Step

`shapetype="doccacheload"` / `image="doccacheload_icon"`

Loads documents into the referenced cache. Add to Cache **consumes documents** — downstream steps receive zero documents even if a connection exists. Always use as the **last step in a branch** with empty `<dragpoints/>`.

### Configuration Structure

```xml
<shape image="doccacheload_icon" name="[shapeName]" shapetype="doccacheload" userlabel="[label]" x="[x]" y="[y]">
  <configuration>
    <doccacheload docCache="[documentCacheComponentId]"/>
  </configuration>
  <dragpoints/>
</shape>
```

### Attributes

| Attribute | Description |
|-----------|-------------|
| `docCache` | GUID of the Document Cache component |

Single attribute — all cache structure is defined in the referenced component.

### Key Behaviors
- All key values across all indexes are extracted and stored when documents enter the step
- The entire document and all index entries are cached, not just key values
- If any key value is an empty string or explicit null, the step **fails with an error** (`Error indexing document. Could not determine value for Index key: [keyName]`). However, if the key field is entirely **absent** from the document, Add to Cache silently accepts it (no error raised)
- **Documents are consumed** — Add to Cache is a document sink. Downstream steps receive zero documents even when connected via dragpoints. Always use as the terminal step in a branch.
- **Format validation varies by profile type**: JSON and XML caches error on format mismatch. Flat file and EDI caches silently accept any text — mismatched documents produce 0 records with no error. See component reference for details.

---

## Retrieve From Cache Step

`shapetype="doccacheretrieve"` / `image="doccacheretrieve_icon"`

Retrieves documents from the cache. Retrieved documents **completely replace** the current document data and its document properties (including DDPs). This is a full replacement, not a merge — the flowing document is entirely discarded.

### Configuration Structure

```xml
<shape image="doccacheretrieve_icon" name="[shapeName]" shapetype="doccacheretrieve" userlabel="[label]" x="[x]" y="[y]">
  <configuration>
    <doccacheretrieve docCache="[documentCacheComponentId]" emptyCacheBehavior="[behavior]" loadAllDoc="[boolean]">
      <cacheKeyValues>
        <cacheKeyValue cacheKeyId="[keyId]">
          <parametervalue key="[key]" valueType="[type]">
            <!-- parameter source -->
          </parametervalue>
        </cacheKeyValue>
      </cacheKeyValues>
    </doccacheretrieve>
  </configuration>
  <dragpoints>
    <dragpoint name="[shapeName].dragpoint1" toShape="[nextShape]" x="[x]" y="[y]"/>
  </dragpoints>
</shape>
```

### Attributes

| Attribute | Required | Description |
|-----------|----------|-------------|
| `docCache` | Yes | GUID of the Document Cache component |
| `emptyCacheBehavior` | No | `stopprocess` (recommended) — ends document processing without error. `returnerror` — fails document with error (`Error getting document references; Caused by: No documents found in cache`). **Default when omitted is `returnerror`** — always set explicitly to `stopprocess` if you want graceful empty-cache handling. |
| `loadAllDoc` | No | When `true`, retrieves all documents from cache. Requires `enforceSingleLucene="true"` on the component — validated at process initialization, not runtime. |
| `docCacheIndex` | When not loadAllDoc | References the cache component's `indexId` attribute value (e.g., `1`), NOT a zero-based array position. Using a non-existent indexId causes init error. |

### Retrieval Modes

**All Documents** (`loadAllDoc="true"`):
- Returns every document in the cache
- Requires `enforceSingleLucene="true"` on the component — if false, the process **fails at initialization** before any shapes execute: `Retrieve all is only supported for document caches which are set to enforce single document`
- `cacheKeyValues` ignored

**By Index** (`loadAllDoc="false"` or omitted):
- Requires `docCacheIndex` to specify which index
- Requires `cacheKeyValues` with a value for each key in the selected index
- If key values are null or empty, no matching documents are found

---

## Remove From Cache Step

`shapetype="doccacheremove"` / `image="doccacheremove_icon"`

Removes documents from the cache.

### Configuration Structure

```xml
<shape image="doccacheremove_icon" name="[shapeName]" shapetype="doccacheremove" userlabel="[label]" x="[x]" y="[y]">
  <configuration>
    <doccacheremove allIndices="[boolean]" docCache="[documentCacheComponentId]" removeAllDocuments="[boolean]">
      <cacheKeyValues>
        <cacheKeyValue cacheKeyId="[keyId]">
          <parametervalue key="[key]" valueType="[type]">
            <!-- parameter source -->
          </parametervalue>
        </cacheKeyValue>
      </cacheKeyValues>
    </doccacheremove>
  </configuration>
  <dragpoints/>
</shape>
```

### Attributes

| Attribute | Required | Description |
|-----------|----------|-------------|
| `docCache` | Yes | GUID of the Document Cache component |
| `removeAllDocuments` | No | When `true`, removes all documents from the cache |
| `allIndices` | No | When `true`, removes from all indices |
| `docCacheIndex` | When targeted removal | References the cache component's `indexId` attribute value (e.g., `1`), NOT a zero-based array position. |

### Removal Modes

**All Documents** (`removeAllDocuments="true"`):
- Clears the entire cache
- Always available regardless of `enforceSingleLucene` setting

**By Key** (`removeAllDocuments="false"`):
- Requires `enforceSingleLucene="true"` on the component — if false, the process **fails at initialization** before any shapes execute: `Remove By Key is only supported for document caches which are set to enforce single document`
- Requires `docCacheIndex` and `cacheKeyValues` with values for each key in the selected index

---

## Cache Lookup as Parameter Source

Document cache values can be used as parameter sources in Set Properties, Map functions, and other parameter-accepting steps via `documentcacheparameter`.

```xml
<parametervalue key="[key]" valueType="documentcache">
  <documentcacheparameter docCache="[cacheComponentId]" docCacheIndex="[indexId]" elementId="[elementId]" elementName="[elementName]">
    <cacheKeyValues>
      <cacheKeyValue cacheKeyId="[keyId]">
        <parametervalue key="[key]" valueType="static">
          <staticparameter staticproperty="[lookupValue]"/>
        </parametervalue>
      </cacheKeyValue>
    </cacheKeyValues>
  </documentcacheparameter>
</parametervalue>
```

| Attribute | Description |
|-----------|-------------|
| `docCache` | GUID of the Document Cache component |
| `docCacheIndex` | References the cache component's `indexId` attribute value (e.g., `1`), NOT a zero-based array position. |
| `elementId` | Profile element ID to retrieve from cached document |
| `elementName` | Element display name (e.g., `"id (Root/Object/id)"`) |

The `cacheKeyValues` specify the lookup criteria — which cached document to retrieve the element from. Key values can come from multiple source types:

**Static value:**
```xml
<parametervalue key="[key]" valueType="static">
  <staticparameter staticproperty="[lookupValue]"/>
</parametervalue>
```

**Current document profile element** (dynamic lookup from the flowing document):
```xml
<parametervalue key="[key]" valueType="profile">
  <profileelement elementId="[elementId]" elementName="[elementName]" profileId="[profileComponentId]" profileType="[profileType]"/>
</parametervalue>
```

---

## Common Patterns

### Branch-Based Cache and Retrieve
The standard pattern uses branches: earlier branches cache data, later branches retrieve it. Branches execute sequentially, so all caching completes before retrieval begins.

```
Start → Branch
  Branch 1: [Get/Generate Data] → Add to Cache
  Branch 2: [Process Data] → Retrieve From Cache → [Continue] → Stop
```

### Multiple Source Cache Join
Cache data from multiple sources in separate branches, then join in a final branch using cache lookups in Maps or Set Properties.

```
Start → Branch
  Branch 1: Message (Authors CSV) → Split Docs → Add to Authors Cache
  Branch 2: Message (Books CSV) → Split Docs → Add to Books Cache
  Branch 3: Message (lookup key) → Map (with cache joins) → Notify → Stop
```

### Cache as Temporary Collection
Use cache to accumulate documents across multiple processing steps, then retrieve all at once.

```
Start → Message → Split → Branch
  Branch 1: [Filter/Cleanse] → Decision → (match) Set Props → Add to Cache
  Branch 2: Retrieve All From Cache → Notify → Stop
```

### Flat File: Split Before Cache
Flat file documents with multiple records must be split before caching for per-record key extraction and retrieval. Use Data Process "Split Documents" (split by line) before the Add to Cache step.

---

## Scope and Lifecycle

- Cache is scoped to the entire execution chain (parent + all subprocesses)
- **Bidirectional subprocess access**: parent can cache → subprocess retrieves, OR subprocess can cache → parent retrieves after Process Call returns
- Purged after process execution completes (test or production)
- Not shared across separate process executions
- Documents and indexes stored to disk, loaded into memory when needed

### Molecule/Cloud Considerations
- Cache is **not shared across nodes** in Molecule/Cloud environments
- Parallel processing via Flow Control "Processes" type distributes across nodes — cache will not be accessible cross-node
- Use Flow Control "Threads" type (multithreading) instead to keep cache access on the same node

---

## Reference XML Examples

### Add to Cache (Branch-Terminal — Typical)
```xml
<shape image="doccacheload_icon" name="shape3" shapetype="doccacheload" userlabel="" x="608.0" y="48.0">
  <configuration>
    <doccacheload docCache="3ae62be4-10b8-458a-bd5f-ac14fb7346bf"/>
  </configuration>
  <dragpoints/>
</shape>
```

### Retrieve From Cache — All Documents
```xml
<shape image="doccacheretrieve_icon" name="shape5" shapetype="doccacheretrieve" userlabel="" x="480.0" y="192.0">
  <configuration>
    <doccacheretrieve docCache="3ae62be4-10b8-458a-bd5f-ac14fb7346bf" emptyCacheBehavior="stopprocess" loadAllDoc="true">
      <cacheKeyValues/>
    </doccacheretrieve>
  </configuration>
  <dragpoints>
    <dragpoint name="shape5.dragpoint1" toShape="shape6" x="608.0" y="200.0"/>
  </dragpoints>
</shape>
```

### Remove From Cache — All Documents
```xml
<shape image="doccacheremove_icon" name="shape16" shapetype="doccacheremove" userlabel="" x="512.0" y="656.0">
  <configuration>
    <doccacheremove allIndices="false" docCache="3ae62be4-10b8-458a-bd5f-ac14fb7346bf" removeAllDocuments="true">
      <cacheKeyValues/>
    </doccacheremove>
  </configuration>
  <dragpoints/>
</shape>
```

### Retrieve After Remove — Empty Cache (stopprocess)
```xml
<shape image="doccacheretrieve_icon" name="shape17" shapetype="doccacheretrieve" userlabel="" x="512.0" y="816.0">
  <configuration>
    <doccacheretrieve docCache="3ae62be4-10b8-458a-bd5f-ac14fb7346bf" emptyCacheBehavior="stopprocess" loadAllDoc="true">
      <cacheKeyValues/>
    </doccacheretrieve>
  </configuration>
  <dragpoints>
    <dragpoint name="shape17.dragpoint1" toShape="shape18" x="640.0" y="824.0"/>
  </dragpoints>
</shape>
```

### Cache Lookup in Set Properties — Static Key
```xml
<documentproperty name="Dynamic Document Property - DDP_CACHE" propertyId="dynamicdocument.DDP_CACHE" persist="false">
  <sourcevalues>
    <parametervalue key="1" usesEncryption="false" valueType="documentcache">
      <documentcacheparameter docCache="3ae62be4-10b8-458a-bd5f-ac14fb7346bf" docCacheIndex="1" elementId="4" elementName="name (Root/Object/name)">
        <cacheKeyValues>
          <cacheKeyValue cacheKeyId="2">
            <parametervalue key="0" valueType="static">
              <staticparameter staticproperty="123"/>
            </parametervalue>
          </cacheKeyValue>
        </cacheKeyValues>
      </documentcacheparameter>
    </parametervalue>
  </sourcevalues>
</documentproperty>
```

### Cache Lookup in Set Properties — Profile Element Key (Dynamic)
```xml
<documentproperty name="Dynamic Document Property - GENRE" propertyId="dynamicdocument.GENRE" persist="false">
  <sourcevalues>
    <parametervalue key="1" valueType="documentcache">
      <documentcacheparameter docCache="aa7042ad-e341-45e6-8136-61a8fa16c240" docCacheIndex="1" elementId="12" elementName="Genre or Tilte (Record/Elements/Genre or Tilte)">
        <cacheKeyValues>
          <cacheKeyValue cacheKeyId="11">
            <parametervalue key="1" valueType="profile">
              <profileelement elementId="6" elementName="Author (Record/Elements/Author)" profileId="840d6cf3-60e8-4b18-bdf2-e60785699e1a" profileType="profile.flatfile"/>
            </parametervalue>
          </cacheKeyValue>
        </cacheKeyValues>
      </documentcacheparameter>
    </parametervalue>
  </sourcevalues>
</documentproperty>
```
