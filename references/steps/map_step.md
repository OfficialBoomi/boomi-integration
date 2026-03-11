# Map Step Reference

## Contents
- Purpose
- Key Concepts
- Configuration Structure
- Required Components
- Component Dependencies
- Common Patterns
- Important Notes
- Reference XML Example
- Workflow Considerations

## Purpose
Map steps transform documents from one profile to another using a Map component. They transform both structure AND format, not just values - restructuring data organization while converting types and applying transformations.

**Use when:**
- Transforming existing structured data between different schemas
- Converting API responses to internal formats
- Mapping database results to API request payloads
- Restructuring data between systems (preferred for elegant, human-readable transformations)
- Distilling specific useful content out of a large payload

## Key Concepts
- **Component Reference**: Map steps don't contain transformation logic - they reference a Map component by ID
- **Map Component Required**: The referenced Map component must exist before adding the step
- **Profile Dependencies**: Map components require source and destination profiles to define the transformation
- **GUID Reference**: Uses the Map component's GUID, not its name

## Configuration Structure
```xml
<shape image="map_icon" name="[shapeName]" shapetype="map" userlabel="[label]" x="[x]" y="[y]">
  <configuration>
    <map mapId="[map-component-guid]"/>
  </configuration>
  <dragpoints>
    <dragpoint name="[shapeName].dragpoint1" toShape="[nextShape]" x="[x]" y="[y]"/>
  </dragpoints>
</shape>
```

## Required Components
Before adding a Map step, ensure these components exist:
1. **Map Component**: Contains the actual field mappings and transformation rules
2. **Source Profile**: Defines the structure of incoming data
3. **Destination Profile**: Defines the structure of outgoing data

## Component Dependencies
```
Map Step 
  └── references → Map Component (by mapId)
                     ├── uses → Source Profile
                     └── uses → Destination Profile
```

## Common Patterns
- Transform API responses to internal formats
- Convert between JSON and XML
- Restructure data for different endpoints
- Map database results to API payloads
- Normalize data from multiple sources

### Profile Reuse Pattern
**CRITICAL PRINCIPLE**: Reuse existing profiles when structure matches - don't create duplicates.

**Common scenario - WSS Wrapper + Subprocess:**
- WSS wrapper defines `request` and `response` profiles for API JSON structure
- Subprocess needs to transform same JSON structure
- **CORRECT**: Subprocess Map references existing WSS request profile as source
- **WRONG**: Creating duplicate "subprocess_request_profile" with identical structure

**Benefits**: Fewer components, consistent validation, easier maintenance.

## Important Notes
- The Map step is lightweight - all logic lives in the Map component
- If transformation fails, the process typically errors unless wrapped in try/catch
- Multiple Map steps can reference the same Map component
- Map components are reusable across different processes

## Reference XML Example

### Basic Map Step
```xml
<shape image="map_icon" name="shape16" shapetype="map" userlabel="" x="1584.0" y="208.0">
  <configuration>
    <map mapId="b54f4cd0-9b04-41e0-8fce-66a03aa2ce86"/>
  </configuration>
  <dragpoints>
    <dragpoint name="shape16.dragpoint1" toShape="shape17" x="1760.0" y="216.0"/>
  </dragpoints>
</shape>
```

## Workflow Considerations
When building a process with Map steps:
1. Create source Profile component first
2. Create destination Profile component
3. Create Map component with field mappings
4. Add Map step to process canvas referencing the Map component
5. Test with sample data matching the source profile structure