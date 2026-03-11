# REST Connector Step Reference

## Contents
- Purpose
- Key Concepts
- Configuration Structure
- Required Components
- Component Dependencies
- Dynamic Properties
- Common Dynamic Property Types
- Query Parameters Configuration
- Critical GUI Display Requirements
- Complete Examples
- Testing Considerations

## Purpose
REST Connector steps integrate with external REST APIs using HTTP methods (GET, POST, PUT, DELETE, PATCH). They execute HTTP operations using Connection and Operation components.

## Key Concepts
- **Dual Component Reference**: Requires both a Connection component (credentials/endpoint base uri) and Operation component (specific action, headers, parameters, endpoint path)
- **Component Dependencies**: Both components must exist before adding the connector step
- **Dynamic Properties**: Can pass runtime values (paths, headers, query parameters) via DDPs/DPPs
- **REST Connector Type**: Uses `officialboomi-X3979C-rest-prod` identifier
- **HTTP Action Types**: GET, HEAD, POST, DELETE, PUT, PATCH, OPTIONS, TRACE

## Configuration Structure
```xml
<shape image="connectoraction_icon" name="[shapeName]" shapetype="connectoraction" userlabel="[label]" x="[x]" y="[y]">
  <configuration>
    <connectoraction actionType="[GET|HEAD|POST|DELETE|PUT|PATCH|OPTIONS|TRACE]"
                    allowDynamicCredentials="NONE" 
                    connectionId="[connection-component-guid]" 
                    connectorType="[connector-type-identifier]" 
                    hideSettings="false" 
                    operationId="[operation-component-guid]">
      <parameters/>
      <dynamicProperties>
        <propertyvalue childKey="" key="[property-key]" name="[display-name]" valueType="track">
          <trackparameter defaultValue="" propertyId="[property-id]" propertyName="[property-display-name]"/>
        </propertyvalue>
      </dynamicProperties>
    </connectoraction>
  </configuration>
  <dragpoints>
    <dragpoint name="[shapeName].dragpoint1" toShape="[nextShape]" x="[x]" y="[y]"/>
  </dragpoints>
</shape>
```

## Required Components
Before adding a Connector step, ensure these components exist:
1. **Connection Component**: Contains endpoint URL, credentials, and connection settings
2. **Operation Component**: Defines the specific operation (resource path, method, headers, request/response profiles)

## Component Dependencies
```
Connector Step 
  ├── references → Connection Component (by connectionId)
  │                  └── contains → Base URL, Auth, Timeouts
  └── references → Operation Component (by operationId)
                     ├── defines → Resource Path, Method
                     ├── uses → Request Profile (optional)
                     └── uses → Response Profile (optional)
```

## Dynamic Properties
Modern REST connectors use a **DUAL CONFIGURATION** pattern: operation component defines parameter "slots", process step fills them with runtime values.

### **The Two-Part Architecture**

#### **Part 1: Operation Component (Parameter Slots)**
Operation component defines what parameters exist:
```xml
<!-- In operation component -->
<properties key="lat" value=""/>          <!-- Empty placeholder -->
<properties key="lon" value=""/>          <!-- Empty placeholder -->
<properties key="appid" value="demo"/>    <!-- Default value -->
<properties key="units" value="metric"/>  <!-- Static value (not overridden) -->
```

#### **Part 2: Process Step (Runtime Values)**
Process step populates those parameters with dynamic values:
```xml
<!-- In process connector step -->
<dynamicProperties>
  <propertyvalue childKey="lat" key="queryParameters" valueType="track">
    <trackparameter propertyId="dynamicdocument.DDP_LATITUDE"/>
  </propertyvalue>
  <propertyvalue childKey="lon" key="queryParameters" valueType="track">
    <trackparameter propertyId="dynamicdocument.DDP_LONGITUDE"/>
  </propertyvalue>
  <propertyvalue childKey="appid" key="queryParameters" valueType="static">
    <staticparameter staticproperty="real-api-key"/>
  </propertyvalue>
  <!-- Note: 'units' not specified here, so keeps operation default 'metric' -->
</dynamicProperties>
```

### **Name Matching is Critical**
- Operation `key="lat"` **must match** Process Step `childKey="lat"`
- Process step **overrides** operation values by exact name matching
- Parameters not specified in dynamic properties keep their operation defaults

### Common Dynamic Property Types:
- **path**: URL path segments (a dynamic path can be set into a DDP prior to the step, and then referenced dynamically. The {reference} format does NOT work directly within the step configuration)
- **headers**: Custom headers
- **queryParameters**: URL query string parameters
- **requestBody**: For POST/PUT operations

### Query Parameters Configuration
**CORRECT Pattern**: Operation defines slots + Process step fills values

```xml
<dynamicProperties>
  <!-- Single query parameter -->
  <propertyvalue childKey="lat" key="queryParameters" name="Query Parameters" valueType="track">
    <trackparameter defaultValue="" propertyId="dynamicdocument.DDP_LATITUDE"
                    propertyName="Dynamic Document Property - DDP_LATITUDE"/>
  </propertyvalue>

  <!-- Multiple query parameters -->
  <propertyvalue childKey="lon" key="queryParameters" name="Query Parameters" valueType="track">
    <trackparameter defaultValue="" propertyId="dynamicdocument.DDP_LONGITUDE"
                    propertyName="Dynamic Document Property - DDP_LONGITUDE"/>
  </propertyvalue>

  <!-- Static query parameter -->
  <propertyvalue childKey="appid" key="queryParameters" name="Query Parameters" valueType="static">
    <staticparameter staticproperty="your-api-key"/>
  </propertyvalue>

  <!-- Process property query parameter -->
  <propertyvalue childKey="format" key="queryParameters" name="Query Parameters" valueType="process">
    <processparameter processproperty="DPP_OUTPUT_FORMAT" processpropertydefaultvalue="json"/>
  </propertyvalue>
</dynamicProperties>
```

## **CRITICAL GUI Display Requirements**

**A Programmatic Generation Gotcha**: Missing display attributes cause "null" values in Boomi GUI even though the connector works at runtime.

### **Required Attributes for GUI Rendering**

**Every `<propertyvalue>` element MUST include:**
- **name="Query Parameters"** - Without this, GUI shows "null" instead of parameter group name

**Every `<trackparameter>` element MUST include:**
- **propertyName="Dynamic Document Property - DDP_XXX"** - Human-readable property label for GUI
- **defaultValue=""** - Initializes the default value field (can be empty)

### **WRONG Pattern - Causes GUI Display Issues**
```xml
<!-- Missing GUI display attributes -->
<propertyvalue childKey="q" key="queryParameters" valueType="track">
  <trackparameter propertyId="dynamicdocument.DDP_CITY"/>
</propertyvalue>
```
**Result**: Works at runtime but shows "null" entries in Boomi GUI

### **CORRECT Pattern - Full GUI Compatibility**
```xml
<!-- Complete attributes for proper GUI rendering -->
<propertyvalue childKey="q" key="queryParameters" name="Query Parameters" valueType="track">
  <trackparameter defaultValue="" propertyId="dynamicdocument.DDP_CITY"
                  propertyName="Dynamic Document Property - DDP_CITY"/>
</propertyvalue>
```
**Result**: Works at runtime AND displays properly in Boomi GUI

### **Why This Matters**
- **Runtime**: Process executes correctly either way
- **GUI Experience**: Missing attributes cause confusing "null" displays
- **Team Development**: Other developers see proper labels when reviewing/modifying components
- **Debugging**: Clear property names aid troubleshooting

### Key Attributes:
- **childKey**: The specific query parameter name (e.g., "lat", "lon", "appid")
- **key**: Always "queryParameters" for query string parameters
- **name**: Always "Query Parameters" for query parameter groups (GUI display)
- **valueType**: "track" (DDP), "static", "process" (DPP), or "profile"
- **propertyName**: Full descriptive name for GUI display (e.g., "Dynamic Document Property - DDP_CITY")
- **defaultValue**: Default value initialization (often empty string "")

## REST Connector Type
- **Identifier**: `officialboomi-X3979C-rest-prod`
- **Protocol**: HTTP/HTTPS
- **Authentication**: Supports Basic, OAuth, API Key, Custom Headers

## Document Clearing for GET Requests

**CRITICAL PATTERN**: REST GET requests should not send document content in the request body. However, connectors inherit document content from upstream steps, which can cause issues.

### When to Clear Documents
- Before any REST GET connector that doesn't need request body data
- When upstream steps have created document content that shouldn't be sent to the GET endpoint
- To prevent "request body not allowed" errors from APIs

### Empty Message Step Pattern
Use an empty Message step immediately before the GET connector to clear inherited content:

```xml
<!-- Empty Message step clears document content -->
<shape image="message_icon" name="shape3" shapetype="message" x="400.0" y="48.0">
  <configuration>
    <message combined="false">
      <msgTxt></msgTxt>
      <msgParameters/>
    </message>
  </configuration>
  <dragpoints>
    <dragpoint name="shape3.dragpoint1" toShape="shape4" x="576.0" y="56.0"/>
  </dragpoints>
</shape>

<!-- REST GET connector with clean slate -->
<shape image="connectoraction_icon" name="shape4" shapetype="connectoraction" x="600.0" y="48.0">
  <configuration>
    <connectoraction actionType="GET"
                    connectionId="connection-guid"
                    operationId="operation-guid">
      <!-- No document content, only query parameters work correctly -->
    </connectoraction>
  </configuration>
</shape>
```

## Common REST Patterns
- Dynamic query parameters via DDP/DPP properties
- Custom headers for authentication and content negotiation
- Request body templating for POST/PUT operations
- Setting DDP_PATH before connector for dynamic resource URLs

## Reference XML Examples

### REST Connector with Dynamic Path
```xml
<shape image="connectoraction_icon" name="shape5" shapetype="connectoraction" userlabel="" x="816.0" y="48.0">
  <configuration>
    <connectoraction actionType="GET" 
                    allowDynamicCredentials="NONE" 
                    connectionId="9ec1815c-98ea-49d2-a0eb-627906e0f593" 
                    connectorType="officialboomi-X3979C-rest-prod" 
                    hideSettings="false" 
                    operationId="41e9dc91-ebdb-4dd4-9c4b-2344a3e183be">
      <parameters/>
      <dynamicProperties>
        <propertyvalue childKey="" key="path" name="Path" valueType="track">
          <trackparameter defaultValue="" propertyId="dynamicdocument.DDP_PATH" 
                        propertyName="Dynamic Document Property - DDP_PATH"/>
        </propertyvalue>
      </dynamicProperties>
    </connectoraction>
  </configuration>
  <dragpoints>
    <dragpoint name="shape5.dragpoint1" toShape="shape8" x="992.0" y="56.0"/>
  </dragpoints>
</shape>
```

### REST Connector with Dynamic Query Parameters
```xml
<shape image="connectoraction_icon" name="shape4" shapetype="connectoraction" userlabel="Call OpenWeather API" x="496.0" y="48.0">
  <configuration>
    <connectoraction actionType="GET"
                    allowDynamicCredentials="NONE"
                    connectionId="8e2c8fde-4c99-4879-86cb-3766ff5a8920"
                    connectorType="officialboomi-X3979C-rest-prod"
                    hideSettings="false"
                    operationId="ebb8868a-f0d2-451b-a4d9-96bdbf63634c">
      <parameters/>
      <dynamicProperties>
        <!-- Dynamic latitude from DDP -->
        <propertyvalue childKey="lat" key="queryParameters" name="Query Parameters" valueType="track">
          <trackparameter defaultValue="" propertyId="dynamicdocument.DDP_LATITUDE"
                        propertyName="Dynamic Document Property - DDP_LATITUDE"/>
        </propertyvalue>
        <!-- Dynamic longitude from DDP -->
        <propertyvalue childKey="lon" key="queryParameters" name="Query Parameters" valueType="track">
          <trackparameter defaultValue="" propertyId="dynamicdocument.DDP_LONGITUDE"
                        propertyName="Dynamic Document Property - DDP_LONGITUDE"/>
        </propertyvalue>
        <!-- Static API key -->
        <propertyvalue childKey="appid" key="queryParameters" name="Query Parameters" valueType="static">
          <staticparameter staticproperty="demo-weather-api-key-12345"/>
        </propertyvalue>
        <!-- Static units parameter -->
        <propertyvalue childKey="units" key="queryParameters" name="Query Parameters" valueType="static">
          <staticparameter staticproperty="metric"/>
        </propertyvalue>
      </dynamicProperties>
    </connectoraction>
  </configuration>
  <dragpoints>
    <dragpoint name="shape4.dragpoint1" toShape="shape5" x="640.0" y="56.0"/>
  </dragpoints>
</shape>
```

### REST Connector for Petstore API
```xml
<shape image="connectoraction_icon" name="shape8" shapetype="connectoraction" userlabel="Get Pet by ID [[LATEST]]" x="848.0" y="256.0">
  <configuration>
    <connectoraction actionType="GET"
                    allowDynamicCredentials="NONE"
                    connectionId="bdd783bd-4b07-4bf4-a6c0-47bd4c3dad08"
                    connectorType="officialboomi-X3979C-rest-prod"
                    hideSettings="false"
                    operationId="a11dad75-7073-4bbc-93c4-14c195041dac">
      <parameters/>
      <dynamicProperties>
        <propertyvalue childKey="" key="path" name="Path" valueType="track">
          <trackparameter defaultValue="" propertyId="dynamicdocument.DDP_PATH"
                        propertyName="Dynamic Document Property - DDP_PATH"/>
        </propertyvalue>
      </dynamicProperties>
    </connectoraction>
  </configuration>
  <dragpoints>
    <dragpoint name="shape8.dragpoint1" toShape="shape6" x="479.0" y="104.0"/>
  </dragpoints>
</shape>
```

## Workflow Considerations
When building a process with Connector steps:
1. Create Connection component with endpoint and credentials
2. Create request/response Profile components (if needed)
3. Create Operation component defining the specific action
4. Set up any DDPs needed for dynamic values (paths, headers)
5. Add Connector step referencing both Connection and Operation
6. Configure dynamic properties to use the DDPs
7. Add Notify step after to log responses during te