# REST Connector Operation Component

## Contents
- CRITICAL WARNING
- Overview
- Component Structure
- HTTP Methods
- Response Handling
- Authentication Headers
- Path Configuration
- Query Parameters
- Common Header Patterns
- Complete Examples
- Redirect Configuration
- Operation Naming Conventions
- Working with Connection Components
- Dynamic Value Replacement
- Implementation Notes

## **CRITICAL WARNING**

**DO NOT USE** `requestProfileType` or `responseProfileType` attributes in REST connector operations. These attributes **do not exist** in the Boomi GUI and will cause **silent document flow failures**:

```xml
<!-- WRONG - CAUSES SILENT FAILURES -->
<GenericOperationConfig requestProfileType="none" responseProfileType="json">

<!-- CORRECT -->
<GenericOperationConfig customOperationType="GET" operationType="EXECUTE">
```

If you see these attributes, remove them immediately. See references/guides/boomi_error_reference.md Issue #6 for details.

## Overview
REST Connector Operation components define specific API endpoints, HTTP methods, headers, query parameters, and request/response handling. They work with REST Connection components to execute API calls.

## Component Structure
```xml
<?xml version="1.0" encoding="UTF-8"?>
<bns:Component xmlns:bns="http://api.platform.boomi.com/" 
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               componentId="{generate-uuid}"
               name="{operation-name}"
               type="connector-action"
               subType="officialboomi-X3979C-rest-prod"
               folderId="{folder-id}">
  <bns:encryptedValues/>
  <bns:object>
    <Operation returnApplicationErrors="false" trackResponse="false">
      <Archiving directory="" enabled="false"/>
      <Configuration>
        <GenericOperationConfig>
          <!-- Method and profile configuration -->
          <!-- Headers, parameters, and path -->
        </GenericOperationConfig>
      </Configuration>
      <Tracking>
        <TrackedFields/>
      </Tracking>
      <Caching/>
    </Operation>
  </bns:object>
</bns:Component>
```

## HTTP Methods

### GET Request
```xml
<GenericOperationConfig customOperationType="GET"
                        operationType="EXECUTE">
  <field id="followRedirects" type="string" value="NONE"/>
  <field id="path" type="string" value="/users/{userId}"/>
  <field id="queryParameters" type="customproperties">
    <customProperties>
      <properties key="limit" value="100"/>
      <properties key="status" value="active"/>
    </customProperties>
  </field>
  <field id="requestHeaders" type="customproperties">
    <customProperties/>
  </field>
  <Options/>
</GenericOperationConfig>
```

### POST Request with JSON Body
```xml
<GenericOperationConfig customOperationType="POST"
                        operationType="EXECUTE">
  <field id="followRedirects" type="string" value="NONE"/>
  <field id="path" type="string" value="/users"/>
  <field id="queryParameters" type="customproperties">
    <customProperties/>
  </field>
  <field id="requestHeaders" type="customproperties">
    <customProperties>
      <properties key="Content-Type" value="application/json"/>
    </customProperties>
  </field>
  <Options/>
</GenericOperationConfig>
```

### PUT Request
```xml
<GenericOperationConfig customOperationType="PUT"
                        operationType="EXECUTE">
  <field id="path" type="string" value="/users/{userId}"/>
  <!-- Other fields similar to POST -->
</GenericOperationConfig>
```

### DELETE Request
```xml
<GenericOperationConfig customOperationType="DELETE"
                        operationType="EXECUTE">
  <field id="path" type="string" value="/users/{userId}"/>
  <!-- Minimal configuration needed -->
</GenericOperationConfig>
```

## Response Handling

**IMPORTANT**: REST Connector Operations in the Boomi GUI do NOT support configuring request or response profiles. All responses are returned as raw text/binary data.

### Processing JSON Responses
To work with JSON API responses, use a separate approach after the connector step:

1. **Map Step with JSON Profile**: Create a Map step that references a JSON Profile component
2. **Set Properties Step**: Extract specific values using JSONPath or XPath expressions
3. **Message Step**: Transform the raw response using scripting

### Processing XML Responses
Similarly, XML responses require post-processing:

1. **Map Step with XML Profile**: Use XML Profile component with Map step
2. **Set Properties Step**: Extract values with XPath expressions

### Error Response Handling
Optionally - Set `returnApplicationErrors="true"` to convert HTTP errors (4xx/5xx) into documents instead of process failures:

```xml
<Operation returnApplicationErrors="true" trackResponse="false">
```

Enables viewing error response bodies via Notify steps - useful when API returns detailed error messages.

Use this for additional troubleshooting data, typically disable it for full production deployment so that we may rely on try/catch error handling.

## Authentication Headers

### Bearer Token
```xml
<field id="requestHeaders" type="customproperties">
  <customProperties>
    <properties key="Authorization" value="Bearer {token}"/>
  </customProperties>
</field>
```

### API Key Header
```xml
<field id="requestHeaders" type="customproperties">
  <customProperties>
    <properties key="X-API-Key" value="{api-key}"/>
  </customProperties>
</field>
```

### Authentication Headers

**New components** - use plain text values:
```xml
<properties key="Authorization" value="Bearer sk-proj-abc123..."/>
```

**Pulled components** with `encrypted="true"` - preserve exactly:
```xml
<properties encrypted="true" key="Authorization" value="HHSQwnktQ..."/>
```

Note: GUI encryption available for sensitive headers after component creation.

### Dynamic Headers - Same Override Pattern
**Best Practice**: When using dynamic properties for headers, leave operation header values blank:

```xml
<!-- Operation Component - Blank values for dynamic headers -->
<field id="requestHeaders" type="customproperties">
  <customProperties>
    <properties key="Authorization" value=""/>
    <properties key="X-Request-ID" value=""/>
    <!-- Static headers keep their values -->
    <properties key="Content-Type" value="application/json"/>
  </customProperties>
</field>
```

Dynamic headers are then set via process step `<dynamicProperties>` which will override the blank operation values.

## Path Configuration

### Static Path
```xml
<field id="path" type="string" value="/api/v2/users"/>
```

### Dynamic Path with Parameters
Use curly braces for dynamic values:
```xml
<field id="path" type="string" value="/api/v2/users/{userId}/orders/{orderId}"/>
```
These will be replaced at runtime with document properties or process properties.

### Empty Path
When using only the base URL from connection:
```xml
<field id="path" type="string" value=""/>
```

## Query Parameters

### Static Parameters
```xml
<field id="queryParameters" type="customproperties">
  <customProperties>
    <properties key="page" value="1"/>
    <properties key="limit" value="50"/>
    <properties key="sort" value="created_desc"/>
  </customProperties>
</field>
```

### **Dynamic Parameters - DUAL CONFIGURATION REQUIRED**
**CRITICAL**: Modern REST connector requires **BOTH** operation parameter definition AND process step dynamic property configuration.

#### The Two-Part Pattern:

**1. Operation Component - Parameter "Slots" (Leave Values Blank):**
```xml
<field id="queryParameters" type="customproperties">
  <customProperties>
    <!-- Define parameter names with blank values when using dynamic properties -->
    <properties key="lat" value=""/>
    <properties key="lon" value=""/>
    <properties key="appid" value=""/>
    <!-- Only set static values for truly static parameters -->
    <properties key="units" value="metric"/>
  </customProperties>
</field>
```

**2. Process Step - Dynamic Value Injection:**
```xml
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
</dynamicProperties>
```

#### **BEST PRACTICE - Clean Separation:**
- **Dynamic parameters**: Leave operation `value=""` blank, set via process step
- **Static parameters**: Set operation `value="actual-value"`, no process step needed
- **Name Matching**: Operation `key="lat"` ↔ Process Step `childKey="lat"`
- **Override behavior**: Process step **always overrides** operation values by name

#### **What Still Doesn't Work:**
```xml
<!-- This pattern from legacy HTTP client is NOT supported -->
<properties key="userId" value="{DDP_USER_ID}"/>
```

## Common Header Patterns

### Standard JSON API Headers
```xml
<field id="requestHeaders" type="customproperties">
  <customProperties>
    <properties key="Content-Type" value="application/json"/>
    <properties key="Accept" value="application/json"/>
  </customProperties>
</field>
```

### Custom Headers with Auth
```xml
<field id="requestHeaders" type="customproperties">
  <customProperties>
    <properties key="Authorization" value="Bearer {token}"/>
    <properties key="X-Request-ID" value="{requestId}"/>
    <properties key="X-Client-Version" value="1.0"/>
  </customProperties>
</field>
```

## Complete Examples

### GET with Query Parameters and Auth
```xml
<GenericOperationConfig customOperationType="GET"
                        operationType="EXECUTE">
  <field id="followRedirects" type="string" value="NONE"/>
  <field id="path" type="string" value="/api/v2/products"/>
  <field id="queryParameters" type="customproperties">
    <customProperties>
      <properties key="category" value="electronics"/>
      <properties key="inStock" value="true"/>
      <properties key="maxPrice" value="1000"/>
    </customProperties>
  </field>
  <field id="requestHeaders" type="customproperties">
    <customProperties>
      <properties key="Authorization" value="Bearer sk-proj-demo123..."/>
      <properties key="Accept" value="application/json"/>
    </customProperties>
  </field>
  <Options/>
</GenericOperationConfig>
```

### POST with JSON Body
```xml
<GenericOperationConfig customOperationType="POST"
                        operationType="EXECUTE">
  <field id="followRedirects" type="string" value="NONE"/>
  <field id="path" type="string" value="/api/v2/orders"/>
  <field id="queryParameters" type="customproperties">
    <customProperties/>
  </field>
  <field id="requestHeaders" type="customproperties">
    <customProperties>
      <properties key="Authorization" value="Bearer demo-token-abc123"/>
      <properties key="Content-Type" value="application/json"/>
      <properties key="X-Idempotency-Key" value="{idempotencyKey}"/>
    </customProperties>
  </field>
  <Options/>
</GenericOperationConfig>
```
**Note**: Authorization headers shown with demo values. User must encrypt sensitive headers via Boomi UI for production use.

## Redirect Configuration

- `NONE` - Don't follow redirects (default)
- `STRICT` - Follow redirects with strict RFC compliance (301/302 on GET/HEAD only)
- `LAX` - Follow redirects permissively (all HTTP methods)

## Operation Naming Conventions

Use descriptive names that indicate:
- Method: GET, POST, PUT, DELETE
- Resource: What's being accessed
- Action: Query, Create, Update, Delete

Examples:
- `GET Products List`
- `POST Create Order`
- `PUT Update Customer`
- `DELETE Remove Item`

## Working with Connection Components

The operation inherits from its connection:
- Base URL (operation path is appended)
- Default authentication (can be overridden with headers)
- Timeout settings
- Connection pooling configuration

Example relationship:
- Connection URL: `https://api.example.com/v2`
- Operation path: `/products/abc123`
- Final URL: `https://api.example.com/v2/products/abc123`

## Dynamic Value Replacement

**IMPORTANT**: `{value}` patterns does not work in the REST client:

**Legacy vs Modern**: This is a key difference from the deprecated HTTP client connector, which did support `{DDP_*}` in configuration fields.

- Dynamic query parameters, headers, and path would all need to follow the property reference format at the step level described elsewhere.

## Implementation Notes

1. **Response Processing**: REST connector operations return raw responses. Use Map steps or Set Properties steps to parse JSON/XML responses.

2. **Header Priority**: Headers in operation override connection-level auth

3. **Empty vs Missing**: Include empty `<customProperties/>` even when no values

4. **No API Encryption**: the agent should NOT attempt to encrypt headers itself, as this will yield broken credentials. All sensitive values should be populated as plain text, then will be encrypted via Boomi either programmatically via API or in the UI by the user

5. **Content-Type**: Boomi may auto-detect content type, but explicit header is better for clarity