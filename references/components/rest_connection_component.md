# REST Connection Component

## Contents
- Overview
- Component Structure
- Authentication Patterns
  - Preemptive Authentication
- Required Fields
- URL Configuration Notes
- Timeout Configuration
- Connection Pooling
- Common Patterns
- Implementation Strategy
- Relationship with Operation Component

## Overview
REST Connection components define the base URL and authentication settings for REST API endpoints. They work in tandem with REST Connector Operation components to execute API calls.

## Component Structure
```xml
<?xml version="1.0" encoding="UTF-8"?>
<bns:Component xmlns:bns="http://api.platform.boomi.com/" 
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               componentId="{generate-uuid}"
               name="{connection-name}"
               type="connector-settings"
               subType="officialboomi-X3979C-rest-prod"
               folderId="{folder-id}">
  <bns:encryptedValues>
    <!-- Password encryption entries if using basic auth -->
  </bns:encryptedValues>
  <bns:object>
    <GenericConnectionConfig>
      <!-- Configuration fields -->
    </GenericConnectionConfig>
  </bns:object>
</bns:Component>
```

## Authentication Patterns

### No Authentication
Most flexible pattern - allows operation component to set custom headers:

```xml
<GenericConnectionConfig>
  <field id="url" type="string" value="https://api.example.com/v2"/>
  <field id="auth" type="string" value="NONE"/>
  <field id="connectTimeout" type="integer" value="-1"/>
  <field id="readTimeout" type="integer" value="-1"/>
  <field id="cookieScope" type="string" value="GLOBAL"/>
  <field id="enableConnectionPooling" type="boolean" value="false"/>
</GenericConnectionConfig>
```

**Use Cases for No Auth:**
- API uses bearer tokens (set via Authorization header in operation)
- API uses custom header authentication (X-API-Key, etc.)
- Truly public endpoints with no authentication
- When auth method varies by operation

### Basic Authentication
Standard username/password authentication:

```xml
<GenericConnectionConfig>
  <field id="url" type="string" value="https://api.example.com/v2"/>
  <field id="auth" type="string" value="BASIC"/>
  <field id="username" type="string" value="{username}"/>
  <field id="password" type="password" value="{encrypted-password}"/>
  <field id="preemptive" type="boolean" value="false"/>
  <field id="connectTimeout" type="integer" value="-1"/>
  <field id="readTimeout" type="integer" value="-1"/>
  <field id="cookieScope" type="string" value="GLOBAL"/>
  <field id="enableConnectionPooling" type="boolean" value="false"/>
</GenericConnectionConfig>
```

**Password Encryption:**

**Pulled/Existing Connections**: Preserve `<bns:encryptedValues>` and password field values exactly as-is. Never modify encrypted values.

**New Connection Creation**: Boomi auto-encrypts `type="password"` fields when pushed via API. Pass plaintext value, leave encryption metadata empty:
```xml
<bns:encryptedValues/>
```

### Preemptive Authentication

The `preemptive` field controls when credentials are sent to the server:

```xml
<field id="preemptive" type="boolean" value="true"/>
```

**When enabled (`true`):** Sends credentials on the first request.
**When disabled (`false`):** Waits for server's 401 challenge before sending credentials.

**Use `true` when:**
- You trust the server (known API endpoints)
- You want to reduce request overhead (avoids extra round-trip)
- The API doesn't implement 401 challenge-response (Many don't e.g., Bitbucket Cloud)

**Use `false` when:**
- You want the server to explicitly request authentication first
- Security policy requires challenge-response pattern

**Practical guidance:** For integrations with known, trusted REST APIs, `preemptive="true"` is typically more reliable and faster.

**Troubleshooting tip:** If a REST API with Basic Auth is failing without clear error messages, try enabling `preemptive="true"`. Many authentication failures are caused by APIs that don't implement the 401 challenge-response pattern and simply reject requests that lack credentials on the first attempt.

**Note:** Preemptive authentication applies to Basic and OAuth 2.0 authentication types. It is ignored when Custom authentication is selected.

## Required Fields (Minimal Configuration)

### Always Required
```xml
<field id="url" type="string" value="{base-url}"/>
<field id="auth" type="string" value="{NONE|BASIC}"/>
<field id="connectTimeout" type="integer" value="-1"/>
<field id="readTimeout" type="integer" value="-1"/>
<field id="cookieScope" type="string" value="GLOBAL"/>
<field id="enableConnectionPooling" type="boolean" value="false"/>
```

### Additional for Basic Auth
```xml
<field id="username" type="string" value="{username}"/>
<field id="password" type="password" value="{encrypted-password}"/>
<field id="preemptive" type="boolean" value="false"/>
```

### Empty/Unused Fields
Include these as empty to prevent validation issues:
```xml
<field id="domain" type="string" value=""/>
<field id="workstation" type="string" value=""/>
<field id="customAuthCredentials" type="password" value=""/>
<field id="awsAccessKey" type="string" value=""/>
<field id="awsSecretKey" type="password" value=""/>
<field id="awsService" type="string" value=""/>
<field id="customAwsService" type="string" value=""/>
<field id="awsRegion" type="string" value=""/>
<field id="customAwsRegion" type="string" value=""/>
<field id="awsProfileArn" type="string" value=""/>
<field id="awsRoleArn" type="string" value=""/>
<field id="awsTrustAnchorArn" type="string" value=""/>
<field id="awsRolesAnywhereRegion" type="string" value=""/>
<field id="awsRolesAnywhereCustomRegion" type="string" value=""/>
<field id="awsSessionName" type="string" value=""/>
<field id="awsDuration" type="integer" value=""/>
<field id="awsPublicCertificate" type="publiccertificate" value=""/>
<field id="awsPrivateKey" type="privatecertificate" value=""/>
<field id="oauthContext" type="oauth">
  <OAuth2Config grantType="code">
    <credentials clientId=""/>
    <authorizationTokenEndpoint url="">
      <sslOptions/>
    </authorizationTokenEndpoint>
    <authorizationParameters/>
    <accessTokenEndpoint url="">
      <sslOptions/>
    </accessTokenEndpoint>
    <accessTokenParameters/>
    <scope/>
    <jwtParameters>
      <expiration>0</expiration>
    </jwtParameters>
  </OAuth2Config>
</field>
<field id="privateCertificate" type="privatecertificate"/>
<field id="publicCertificate" type="publiccertificate"/>
<field id="maxTotal" type="integer" value=""/>
<field id="idleTimeout" type="integer" value=""/>
```

## URL Configuration Notes

1. **Base URL Only**: Include only the base URL without specific endpoints
   - Good: `https://api.example.com/v2`
   - Bad: `https://api.example.com/v2/users/list`

2. **No Trailing Slash**: Omit trailing slashes from base URLs

3. **Include Version**: If API uses versioning in URL, include it in base URL

## Timeout Configuration

- **connectTimeout**: Connection establishment timeout (milliseconds)
  - `-1` = infinite (default)
  - `30000` = 30 seconds (recommended for production)

- **readTimeout**: Response read timeout (milliseconds)
  - `-1` = infinite (default)
  - `60000` = 60 seconds (recommended for most APIs)

## Connection Pooling

For high-volume integrations:
```xml
<field id="enableConnectionPooling" type="boolean" value="true"/>
<field id="maxTotal" type="integer" value="20"/>
<field id="idleTimeout" type="integer" value="60000"/>
```

## Common Patterns

### Public API (No Auth)
```xml
<GenericConnectionConfig>
  <field id="url" type="string" value="https://api.publicdata.org"/>
  <field id="auth" type="string" value="NONE"/>
  <!-- Standard timeout/pooling fields -->
</GenericConnectionConfig>
```

### API Key via Header (No Auth + Operation Header)
Connection:
```xml
<field id="auth" type="string" value="NONE"/>
```
Operation will include:
```
X-API-Key: {api-key-value}
```

### Bearer Token (No Auth + Operation Header)
Connection:
```xml
<field id="auth" type="string" value="NONE"/>
```
Operation will include:
```
Authorization: Bearer {token-value}
```

### Traditional Basic Auth
```xml
<field id="auth" type="string" value="BASIC"/>
<field id="username" type="string" value="api_user"/>
<field id="password" type="password" value="{encrypted}"/>
```

## Implementation Strategy

1. **Default to No Auth**: When in doubt, use `NONE` authentication. This provides maximum flexibility for the operation component to set headers.

2. **Use Basic Auth Only When**:
   - API explicitly requires HTTP Basic Authentication
   - Username/password are the primary credentials
   - Same credentials apply to all operations

3. **Password Handling**: **Pulled Components**: Preserve encrypted values exactly as-is when re-pushing. **New Connections**: Pass plaintext for `type="password"` fields - Boomi auto-encrypts on push.

4. **Component Naming**: Use descriptive names like:
   - `Salesforce REST Connection`
   - `Petstore API Connection (No Auth)`
   - `Internal System Basic Auth Connection`

## Relationship with Operation Component

The connection component provides:
- Base URL
- Default authentication
- Connection settings (timeouts, pooling)

The operation component adds:
- Specific endpoint path
- HTTP method
- Request/response profiles
- Custom headers (for auth or other purposes)
- Query parameters
- Request body configuration

This separation allows one connection to serve multiple operations while maintaining flexibility for operation-specific authentication needs.