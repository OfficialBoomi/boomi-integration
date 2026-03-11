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

Covers:
- Development philosophy: Minimalism and reliability
- Mandatory dataContext loop pattern
- Dynamic Document Properties (DDPs) and Dynamic Process Properties (DPPs)
- Complete working examples
- Critical rules and gotchas
- Common patterns reference

**Quick reference**:
- Step name MUST be `name="Custom Scripting"` (use `userlabel=""` for description)
- ALWAYS call `dataContext.storeStream()` or document disappears
- Keep scripts minimal
- Prefer native Boomi components over complex Groovy

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

Split documents based on profile elements (JSON arrays or XML repeating elements).

```xml
<step index="3" key="3" name="Split Documents" processtype="8">
  <documentsplit profileType="json">
    <SplitOptions>
      <JSONOptions 
        linkElementKey="9" 
        linkElementName="ArrayElement1 (Root/Object/samplearray/samplearray/ArrayElement1)" 
        profileId="8aa8e4ca-e5ef-497f-84ae-adb50f871c4b"/>
    </SplitOptions>
  </documentsplit>
</step>
```

Configuration:
- `profileType`: "json" or "xml"
- `profileId`: GUID of the profile component
- `linkElementKey`: Element key from profile
- `linkElementName`: Human-readable path to element

For XML splitting:
```xml
<documentsplit profileType="xml">
  <SplitOptions>
    <XMLOptions linkElementKey="[key]" linkElementName="[path]" profileId="[guid]"/>
  </SplitOptions>
</documentsplit>
```

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
| 12 | Custom Scripting (Groovy) | `<dataprocessscript>` - See references/steps/data_process_groovy_step.md |

## Important Notes
- Operations execute in index order
- Each step needs unique index and key values
- Most operations stream data (memory efficient)
- Split/Combine operations require profile components
- Custom Scripting (Groovy) has extensive requirements including language and useCache attributes (see references/steps/data_process_groovy_step.md)