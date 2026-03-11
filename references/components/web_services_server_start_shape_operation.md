# Web Services Server Operation Component

## Contents
- Critical Requirements
- API Conversion Pattern
- Overview
- Key Concepts
- Component Structure
- Configuration Parameters
- URL Path Examples
- Dependencies
- Common Patterns
- Important Notes
- Testing Considerations

## Critical Requirements

**operationType MUST be one of these exact values (case-sensitive):**
- GET
- QUERY
- CREATE
- UPDATE
- UPSERT
- DELETE
- EXECUTE

Custom operationType values are not supported and will cause endpoint failures.

**Start step referencing this operation MUST use:**
- `actionType="Listen"` (ONLY valid value for WSS listeners)

## **API Conversion Pattern (When Converting Existing Processes)**

**CRITICAL**: When asked to "convert to API", "wrap in API", or "expose as API" - **REUSE existing process, don't recreate**:

1. **Keep existing process** - rename to indicate subprocess role (e.g., `Query Weather` → `[SUB] Query Weather`)
2. **Minimal modification** - change final `<stop continue="true"/>` to `<returndocuments/>`
3. **Create lightweight WSS wrapper** - just WSS Start → Process Call → Return Documents
4. **Reuse existing profiles** - don't duplicate working components

**Benefits**: Fewer components, tested logic intact, MVP compliance through maximum reuse.

## Overview
A Web Services Server (WSS) operation component defines an endpoint that can receive HTTP requests through Boomi's shared web server. This component is used with a Web Services Server Start step to create REST API endpoints that trigger process execution.

## Key Concepts
- **Purpose**: Creates callable HTTP endpoints that can trigger Boomi processes
- **HTTP Method**: Determined by input type (GET for no input, POST for data input)
- **URL Pattern**: `/ws/simple/{operationType}{objectName}` (operationType lowercased, objectName sentence cased)
- **Base URL**: Provided by Atom's shared web server (configured separately)

## Component Structure

### Minimal Configuration (GET endpoint, no input/output)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<bns:Component xmlns:bns="http://api.platform.boomi.com/"
           type="connector-action"
           subType="wss">
  <bns:encryptedValues/>
  <bns:description/>
  <bns:object>
    <Operation>
      <Archiving directory="" enabled="false"/>
      <Configuration>
        <WebServicesServerListenAction
          inputType="none"
          objectName="myendpoint"
          operationType="GET"
          outputType="none"/>
      </Configuration>
      <Tracking>
        <TrackedFields/>
      </Tracking>
      <Caching/>
    </Operation>
  </bns:object>
</bns:Component>
```

### JSON Input/Output Configuration (POST endpoint)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<bns:Component xmlns:bns="http://api.platform.boomi.com/"
           type="connector-action"
           subType="wss">
  <bns:encryptedValues/>
  <bns:description/>
  <bns:object>
    <Operation>
      <Archiving directory="" enabled="false"/>
      <Configuration>
        <WebServicesServerListenAction
          inputType="singlejson"
          objectName="petdata"
          operationType="CREATE"
          outputType="singlejson"
          requestProfile="{request-profile-guid}"
          responseProfile="{response-profile-guid}"
          responseContentType="application/json"/>
      </Configuration>
      <Tracking>
        <TrackedFields/>
      </Tracking>
      <Caching/>
    </Operation>
  </bns:object>
</bns:Component>
```

## Configuration Parameters

### Required Attributes
- **inputType**: Determines HTTP method and expected input
  - `none` - No input expected (triggers GET)
  - `singledata` - Single raw data input (triggers POST)
  - `singlejson` - Single JSON document (triggers POST)
  - `multijson` - Multiple JSON documents (triggers POST)
  - `singlexml` - Single XML document (triggers POST)
  - `multixml` - Multiple XML documents (triggers POST)

- **objectName**: Open text string that becomes part of the URL path
  - Example: "petstore" → `/ws/simple/getPetstore`
  - Lowercased operationType concatenated directly with sentence-cased objectName

- **operationType**: Defines the action verb in the URL path
  - Available values: GET, QUERY, CREATE, UPDATE, UPSERT, DELETE, EXECUTE
  - Lowercased and prepended to objectName in URL
  - Not tied to HTTP methods - purely for URL generation

- **outputType**: What the endpoint returns
  - `none` - No response body
  - `singledata` - Single raw data response
  - `singlejson` - Single JSON document
  - `multijson` - Multiple JSON documents
  - `singlexml` - Single XML document
  - `multixml` - Multiple XML documents

### Optional Attributes
- **requestProfile**: Profile component ID for input validation/structure
  - Required when inputType is json/xml for proper parsing
  - References a JSON or XML profile component

- **responseProfile**: Profile component ID for response structure
  - Required when outputType is json/xml for proper formatting
  - References a JSON or XML profile component

- **responseContentType**: MIME type for response
  - `application/json` for JSON responses
  - `application/xml` for XML responses
  - `text/plain` for raw data
  - Defaults based on outputType if not specified

## URL Path Examples
Given base URL: `https://myatom.boomi.com`

**CRITICAL CAPITALIZATION GOTCHA**: Boomi automatically capitalizes the first letter of `objectName` (sentence case) in the final URL path.

### Basic Web Service Endpoint Naming Convention

Web service endpoints use **sentence case** for the object name:
- **Pattern**: `operationType` (lowercase) + `objectName` (first letter capitalized) = compound endpoint
- **Example**: `operationType="GET"` + `objectName="hello"` → **`getHello`**

This creates intuitive, RESTful-style endpoint names that follow standard API naming conventions.

| operationType | objectName | Expected Path | **Actual Runtime Path** |
|--------------|------------|---------------|-------------------------|
| GET | hello | /ws/simple/gethello | **/ws/simple/getHello** |
| GET | users | /ws/simple/getusers | **/ws/simple/getUsers** |
| CREATE | order | /ws/simple/createorder | **/ws/simple/createOrder** |
| CREATE | userdata | /ws/simple/createuserdata | **/ws/simple/createUserdata** |
| EXECUTE | webhook | /ws/simple/executewebhook | **/ws/simple/executeWebhook** |
| UPSERT | customer | /ws/simple/upsertcustomer | **/ws/simple/upsertCustomer** |

**Testing Impact**: When testing endpoints with tools like Postman or curl, use the **Actual Runtime Path** with the capitalized objectName.

## Dependencies
- **Profile Components**: When using json/xml input or output types
- **Web Services Server Start Step**: References this operation component
  - CRITICAL: Start step must use `actionType="Listen"`
- **Shared Web Server**: Must be configured on the Atom for base URL - defined in this project within the .env file 

## Common Patterns

### Simple GET Endpoint (no data)
```xml
<WebServicesServerListenAction 
  inputType="none"
  objectName="healthcheck"
  operationType="GET"
  outputType="singlejson"
  responseProfile="{status-profile-guid}"
  responseContentType="application/json"/>
```
Path: `/ws/simple/getHealthcheck`

### POST Endpoint with JSON I/O
```xml
<WebServicesServerListenAction 
  inputType="singlejson"
  objectName="processorder"
  operationType="CREATE"
  outputType="singlejson"
  requestProfile="{order-request-profile}"
  responseProfile="{order-response-profile}"
  responseContentType="application/json"/>
```
Path: `/ws/simple/createProcessorder`

### Fire-and-Forget POST (no response)
```xml
<WebServicesServerListenAction 
  inputType="singledata"
  objectName="event"
  operationType="EXECUTE"
  outputType="none"/>
```
Path: `/ws/simple/executeEvent`

## Important Notes
1. **HTTP Method**: Automatically determined - cannot be explicitly set
   - GET: When inputType="none"
   - POST: When inputType has data

2. **Path Construction**: Always follows pattern
   - Lowercase operationType + **sentence case** objectName (first letter uppercase)
   - No spaces or special characters in objectName
   - **CRITICAL**: Runtime URLs have sentence-cased objectName (first letter uppercase)

3. **Profile Requirements**: 
   - JSON/XML types need corresponding profile components
   - Profiles define the expected structure for validation

4. **Response Handling**:
   - Response data flows to next step in process
   - Empty response if outputType="none"

5. **Error Responses**: 
   - Platform handles standard HTTP errors
   - Custom error handling done in process logic


## Testing Considerations
- Full endpoint URL requires Atom's shared web server base URL
- Test with appropriate HTTP method based on inputType
- Ensure profiles exist before referencing them
- Consider authentication requirements (configured separately on the atom - referenced in .env within this project)