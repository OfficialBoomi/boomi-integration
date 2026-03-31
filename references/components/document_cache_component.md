# Document Cache Component

## Contents
- Purpose
- Component Structure
- Attributes
- CacheIndex Attributes
- Cache Key Types
- Requirements
- Map Lookup Constraints
- Reference XML Examples

## Purpose

The Document Cache component (`type="documentcache"`) defines the structure for in-memory document caching. Cache steps (Add, Retrieve, Remove) reference this component by ID — they do not define cache structure inline.

**Use when:**
- Creating a reusable cache definition for cross-reference lookups within a process execution
- Defining index and key structure for cached document retrieval
- Building lookup tables joined via map functions or Retrieve From Cache steps
- Caching destination system records for existence checks before insert/update (avoid per-record API calls)
- Accumulating documents across processing steps for aggregated retrieval

## Component Structure

### Minimal Creation Format
```xml
<?xml version="1.0" encoding="UTF-8"?>
<bns:Component xmlns:bns="http://api.platform.boomi.com/"
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               folderId="[FOLDER_ID]"
               name="[CACHE_NAME]"
               type="documentcache">
  <bns:object>
    <DocumentCache enforceSingleLucene="[boolean]" profile="[profileComponentId]" profileType="[type]">
      <CacheIndex indexId="[int]" indexName="[name]">
        <cacheKey alias="[alias]" elementKey="[int]" id="[int]" name="[name]" taglistKey="[int]" xsi:type="ProfileElementKeyConfig"/>
      </CacheIndex>
    </DocumentCache>
  </bns:object>
</bns:Component>
```

## Attributes

| Attribute | Required | Description |
|-----------|----------|-------------|
| `profileType` | Yes | **Must always be set.** Values: `profile.json`, `profile.xml`, `profile.flatfile`, `profile.database`, `profile.edi`, `profile.none`. Omitting this attribute entirely causes a runtime crash (`DataParserException: component null does not exist`). Use `profile.none` for format-agnostic caching (accepts any document format). |
| `profile` | When not `profile.none` | GUID of the profile component. Required for all profile types except `profile.none`. With `profile.none`, omit this attribute — no profile component is needed. |
| `enforceSingleLucene` | No | When `true` (GUI default), each document produces at most one index entry. Enables "retrieve all documents" and "remove by index name" operations. XSD default is `false` but platform GUI defaults to `true`. |

## CacheIndex Attributes

| Attribute | Required | Description |
|-----------|----------|-------------|
| `indexId` | Yes | Platform-assigned integer identifier. **Must be non-zero** — `indexId="0"` causes silent runtime failure (same as `cacheKey id="0"`). Use `1` or higher. |
| `indexName` | Yes | Human-readable name for the index |
| `loadDynamically` | No | Default `false`. Platform omits this attribute when default. |

## Cache Key Types

Keys use `xsi:type` for polymorphism. Three types:

**ProfileElementKeyConfig** (`keyType="profile"`) — maps to a profile element:
| Attribute | Description |
|-----------|-------------|
| `id` | Platform-assigned integer key identifier. **Must be non-zero** — `id="0"` causes silent runtime failure across all key types. Observed working values: `1`, `2`, `11`. |
| `alias` | Display alias. Format varies — may be short (`"id"`) or full path (`"id (Root/Object/id)"`) |
| `elementKey` | Profile element ID |
| `keyType` | Optional. `"profile"` for ProfileElementKeyConfig. Platform may omit — `xsi:type` already carries the type. |
| `name` | Element name. Format varies — may be short (`"id"`) or include full path (`"Id (Record/Elements/Id)"`) |
| `taglistKey` | Taglist element ID. `-1` or `0` when not in a taglist. Positive integer when referencing a taglist. |

**DocumentPropertyKeyConfig** (`keyType="docprop"`) — maps to a document property:
| Attribute | Description |
|-----------|-------------|
| `id` | Platform-assigned integer key identifier |
| `alias` | Display alias |
| `propertyId` | Document/dynamic document/MIME property ID |
| `propertyName` | Property display name |
| `defaultValue` | Default if property missing |

**UserDefKeyConfig** (`keyType="userdef"`) — **NOT supported at runtime**. The XSD and GUI allow creating this key type, but Add to Cache rejects it with `Error building LoadCacheConfig. UserDefined CacheKeyType not supported`. Do not use.

## Requirements
- At least one index with at least one key
- **All ID attributes must be non-zero.** Both `indexId` and `cacheKey id` with value `0` cause silent runtime failure — the API accepts them, Add to Cache reports success, but nothing is actually indexed or retrievable. This affects all key types (ProfileElementKeyConfig and DocumentPropertyKeyConfig). The GUI never assigns `0` — it uses sequential `indexId` starting at `1` and non-sequential `cacheKey id` values (e.g., `2`, `3`, `4`). When creating programmatically, use `1`-based sequential `indexId` and any non-zero positive integer for `cacheKey id`.
- `profileType` must always be set — do NOT omit it. Omitting causes a runtime crash (`DataParserException: Unable to create data parser, component null does not exist`). Use `profile.none` for format-agnostic caching.
- `profile.none` caches only support DocumentPropertyKeyConfig keys (no profile elements to reference). They accept any document format with no validation.
- For profiled caches, DocumentPropertyKeyConfig keys still require the profile — the cache indexer parses documents through it regardless of key type. Format validation is enforced.
- Document format validation at Add to Cache varies by profile type:
  - **JSON**: Mismatch causes runtime error (`Unable to create JSON files from data, the document may not be well-formed json`)
  - **XML**: Mismatch causes runtime error (`Unable to create XML files from data, the document may not be well-formed xml`)
  - **Flat File**: No format validation — the parser treats any text as delimited data. Mismatched documents are silently accepted but produce 0 records (nothing is cached, no error raised)
  - **EDI**: No format validation — same silent-acceptance pattern as flat file. Non-EDI documents produce 0 records with no error.
  - **None** (`profile.none`): No format validation — any document format is accepted and cached.

## Map Lookup Constraints

When using Document Cache with Map components, two approaches exist with different capabilities:

**DocumentCacheLookup function** (configured per-field in the map):
- Requires a profile-based cache — `profile.none` caches produce no output (silent, no error)
- Must return exactly one cached document — multiple matches error: `Found more than 1 document in the document cache (index: [name], keys: [key = value])`
- For within-document arrays, returns only the first element
- Use when: single-record lookup by key (e.g., existence check, field enrichment)

**DocumentCacheJoins** (configured at the Map component level, adds cache as source):
- Produces one output document per matching cached document — handles multiple matches
- For within-document arrays, also returns only the first element (same limitation)
- Use when: multiple cached documents may match a key, or when joining cache data as a source profile

Neither approach iterates over repeating elements within a single cached document. To access all elements of an array, split the document before caching.

## Reference XML Examples

### JSON Profile with Profile Element Key
```xml
<DocumentCache enforceSingleLucene="true" profile="5deb50c5-9db1-4906-9545-44628a176470" profileType="profile.json">
  <CacheIndex indexId="1" indexName="id">
    <cacheKey alias="id (Root/Object/id)" elementKey="3" id="2" name="id (Root/Object/id)" taglistKey="0" xsi:type="ProfileElementKeyConfig"/>
  </CacheIndex>
</DocumentCache>
```

### Flat File Profile with Profile Element Key
```xml
<DocumentCache enforceSingleLucene="true" profile="5dc49285-b5ab-489b-a716-795b7148cb82" profileType="profile.flatfile">
  <CacheIndex indexId="1" indexName="Id">
    <cacheKey alias="Id" elementKey="9" id="11" keyType="profile" name="Id (Record/Elements/Id)" taglistKey="0" xsi:type="ProfileElementKeyConfig"/>
  </CacheIndex>
</DocumentCache>
```

### No Profile (profile.none) with Document Property Key
```xml
<DocumentCache enforceSingleLucene="true" profileType="profile.none">
  <CacheIndex indexId="1" indexName="DDP_CACHE_KEY">
    <cacheKey alias="Dynamic Document Property - DDP_CACHE_KEY"
              defaultValue="" id="2"
              propertyId="dynamicdocument.DDP_CACHE_KEY"
              propertyName="Dynamic Document Property - DDP_CACHE_KEY"
              xsi:type="DocumentPropertyKeyConfig"/>
  </CacheIndex>
</DocumentCache>
```

All examples are from GUI-created components. When creating programmatically, all ID attributes (`indexId` and `cacheKey id`) must be non-zero — value `0` causes silent runtime failure across all key types. `loadDynamically` is omitted when default, `keyType` may be present or absent (`xsi:type` is authoritative).
