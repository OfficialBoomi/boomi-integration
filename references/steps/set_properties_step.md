# Set Properties Step Reference

## Contents
- Purpose
- Key Concepts
- Configuration Structure
- Source Value Types
- Common Patterns
- Reference XML Examples

## Purpose
Set Properties steps (shapetype="documentproperties") create or update Dynamic Document Properties (DDPs) and Dynamic Process Properties (DPPs). These properties act as "floating" variables accessible downstream in the process.

**Use when:**
- Extracting values from API responses for later use
- Building dynamic URL paths or file names
- Setting timestamps for tracking
- Preparing parameters for downstream connectors
- Managing state across branches
- Concatenating many data points from various locations into a single string

## Key Concepts
- **DDP vs DPP**: 
  - DDP (Dynamic Document Property): Scoped to individual documents, prefix `dynamicdocument.`
  - DPP (Dynamic Process Property): Scoped to entire process execution, prefix `process.`
- **Property Persistence**: DDPs travel with documents, DPPs persist across branches
- **Concatenation**: Multiple source values combine to build the final property value
- **Property Naming**: Properties typically use UPPERCASE_WITH_UNDERSCORES convention

## Configuration Structure
```xml
<shape image="documentproperties_icon" name="[shapeName]" shapetype="documentproperties" userlabel="[label]" x="[x]" y="[y]">
  <configuration>
    <documentproperties>
      <documentproperty defaultValue="" isDynamicCredential="false" isTradingPartner="false" 
                       name="[Display Name]" persist="false" 
                       propertyId="[dynamicdocument.PROPERTY_NAME or process.PROPERTY_NAME]" 
                       shouldEncrypt="false">
        <sourcevalues>
          <parametervalue key="[sequence]" valueType="[type]">
            <!-- Value configuration based on type -->
          </parametervalue>
        </sourcevalues>
      </documentproperty>
    </documentproperties>
  </configuration>
  <dragpoints>
    <dragpoint name="[shapeName].dragpoint1" toShape="[nextShape]" x="[x]" y="[y]"/>
  </dragpoints>
</shape>
```

## Source Value Concatenation
**Multiple source values concatenate in XML element order** to build the final property value:
```xml
<sourcevalues>
  <parametervalue key="1" valueType="static">
    <staticparameter staticproperty="/user/"/>
  </parametervalue>
  <parametervalue key="2" valueType="track">
    <trackparameter propertyId="dynamicdocument.DDP_USERNAME"/>
  </parametervalue>
</sourcevalues>
<!-- Result: "/user/" + DDP_USERNAME value -->
```

**The `key` attribute is ignored at runtime** - it's a GUI-assigned identifier that persists through edits. Element order determines concatenation sequence.

## Source Value Types
- **static**: Hard-coded values
  ```xml
  <staticparameter staticproperty="value"/>
  ```
- **track**: Reference other properties
  ```xml
  <trackparameter defaultValue="" propertyId="[property]" propertyName="[display name]"/>
  ```
- **date**: Current date/time with formatting
  ```xml
  <dateparameter dateparametertype="current" datetimemask="yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"/>
  ```
- **profile**: Extract from document using profile
  ```xml
  <profileelement elementId="[id]" elementName="[path]" profileId="[guid]" profileType="profile.json"/>
  ```
- **current**: Capture the current document's raw content as a string (self-closing, no child element)
  ```xml
  <parametervalue key="1" valueType="current"/>
  ```

### Profile Element ID Mapping
**CRITICAL:** When referencing profile elements, the `elementId` must match the `key` attribute from the profile XML, and `elementName` must follow the GUI display format.

**Profile XML structure:**
```xml
<XMLElement dataType="character" key="6" name="Name" ...>           <!-- Root level -->
<XMLElement dataType="character" key="61" name="Name" ...>          <!-- Nested: Account/Name -->
<XMLElement dataType="character" key="149" name="Email" ...>        <!-- Nested: Owner/Email -->
```

**Correct reference with GUI format:**
```xml
<!-- Root-level field -->
<profileelement elementId="6" elementName="Name (Opportunity/Name)" profileId="..." profileType="profile.xml"/>

<!-- Nested field (1 level) -->
<profileelement elementId="61" elementName="Name (Opportunity/Account/Name)" profileId="..." profileType="profile.xml"/>

<!-- Nested field (2 levels) -->
<profileelement elementId="149" elementName="Email (Opportunity/Owner/Email)" profileId="..." profileType="profile.xml"/>
```

**elementName Format Rule:**
- Pattern: `FieldName (RootElement/Full/Path/To/FieldName)`
- Use the final segment as the field name before the parentheses
- Include complete XPath from document root in parentheses
- This format ensures proper GUI display (runtime ignores it but human readability requires correct format)

**Wrong - causes incorrect GUI display:**
```xml
<profileelement elementId="6" elementName="Name" .../>              <!-- Missing path notation -->
<profileelement elementId="61" elementName="Account/Name" .../>     <!-- Wrong format -->
```

To find the correct `elementId`, you MUST search the profile XML for `<XMLElement ... name="FieldName"` and use its `key` attribute value.

## Common Patterns
- Build URL paths by concatenating static strings with dynamic values
- Extract values from API responses for later use
- Set timestamps for tracking
- Prepare request parameters for connectors

## Reference XML Examples

### Setting Multiple Properties (DDPs)
```xml
<shape image="documentproperties_icon" name="shape4" shapetype="documentproperties" userlabel="Sets example DDPs and DPPs" x="432.0" y="48.0">
  <configuration>
    <documentproperties>
      <documentproperty defaultValue="" isDynamicCredential="false" isTradingPartner="false" 
                       name="Dynamic Document Property - DDP_USERNAME" persist="false" 
                       propertyId="dynamicdocument.DDP_USERNAME" shouldEncrypt="false">
        <sourcevalues>
          <parametervalue key="5" valueType="static">
            <staticparameter staticproperty="ccapp"/>
          </parametervalue>
        </sourcevalues>
      </documentproperty>
      <documentproperty defaultValue="" isDynamicCredential="false" isTradingPartner="false" 
                       name="Dynamic Document Property - DDP_EXAMPLE_DATETIME_PROP" persist="false" 
                       propertyId="dynamicdocument.DDP_EXAMPLE_DATETIME_PROP" shouldEncrypt="false">
        <sourcevalues>
          <parametervalue key="6" valueType="date">
            <dateparameter dateparametertype="current" datetimemask="yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"/>
          </parametervalue>
        </sourcevalues>
      </documentproperty>
    </documentproperties>
  </configuration>
  <dragpoints>
    <dragpoint name="shape4.dragpoint1" toShape="shape7" x="608.0" y="56.0"/>
  </dragpoints>
</shape>
```

### Building Concatenated Values
```xml
<shape image="documentproperties_icon" name="shape7" shapetype="documentproperties" userlabel="Prepares DDP_PATH for rest client" x="624.0" y="48.0">
  <configuration>
    <documentproperties>
      <documentproperty defaultValue="" isDynamicCredential="false" isTradingPartner="false" 
                       name="Dynamic Document Property - DDP_PATH" persist="false" 
                       propertyId="dynamicdocument.DDP_PATH" shouldEncrypt="false">
        <sourcevalues>
          <parametervalue key="1" valueType="static">
            <staticparameter staticproperty="/user/"/>
          </parametervalue>
          <parametervalue key="2" valueType="track">
            <trackparameter defaultValue="" propertyId="dynamicdocument.DDP_USERNAME" 
                          propertyName="Dynamic Document Property - DDP_USERNAME"/>
          </parametervalue>
        </sourcevalues>
      </documentproperty>
    </documentproperties>
  </configuration>
  <dragpoints>
    <dragpoint name="shape7.dragpoint1" toShape="shape5" x="800.0" y="56.0"/>
  </dragpoints>
</shape>
```

### Setting Process Properties (DPPs) from Profile Elements
```xml
<shape image="documentproperties_icon" name="shape14" shapetype="documentproperties" userlabel="Sets example DPPs" x="1200.0" y="48.0">
  <configuration>
    <documentproperties>
      <documentproperty defaultValue="" isDynamicCredential="false" isTradingPartner="false" 
                       name="Dynamic Process Property - DPP_SAMPLE_PROCESS_PROP" persist="false" 
                       propertyId="process.DPP_SAMPLE_PROCESS_PROP" shouldEncrypt="false">
        <sourcevalues>
          <parametervalue key="7" valueType="profile">
            <profileelement elementId="6" elementName="lastName (Root/Object/lastName)" 
                          profileId="75c5b9ff-7e48-40f5-91e7-a4703caa86df" profileType="profile.json"/>
          </parametervalue>
          <parametervalue key="8" valueType="static">
            <staticparameter staticproperty=", "/>
          </parametervalue>
          <parametervalue key="6" valueType="profile">
            <profileelement elementId="5" elementName="firstName (Root/Object/firstName)" 
                          profileId="75c5b9ff-7e48-40f5-91e7-a4703caa86df" profileType="profile.json"/>
          </parametervalue>
        </sourcevalues>
      </documentproperty>
    </documentproperties>
  </configuration>
  <dragpoints>
    <dragpoint name="shape14.dragpoint1" toShape="shape15" x="1376.0" y="56.0"/>
  </dragpoints>
</shape>
```