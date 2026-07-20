# OpenAPI Connection Component

## Contents
- Overview
- Component Structure
- Required Fields
- The `spec` Field
- Authentication
  - No Authentication
  - API Key
  - Basic
- Connection Pooling
- Whole-Skeleton Serialization
- Password / Encryption Handling
- Relationship with Operation Component

## Overview
OpenAPI Connection components define the OpenAPI specification location, the base server URL, and authentication for a REST API described by an OpenAPI (3.0+) document. They pair with OpenAPI Connector Operation components, which are authored from (or imported from) the same specification.

The connector is a Boomi-published connector under the `officialboomi-X3979C` publisher — the same publisher as the REST connector — so the component shares the REST connector's `GenericConnectionConfig` shape. It is **not** a fixed-native `openapi` subType.

## Component Structure
```xml
<?xml version="1.0" encoding="UTF-8"?>
<bns:Component xmlns:bns="http://api.platform.boomi.com/"
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               componentId=""
               name="{connection-name}"
               type="connector-settings"
               subType="officialboomi-X3979C-opena2-prod"
               folderId="{folder-id}">
  <bns:encryptedValues/>
  <bns:object>
    <GenericConnectionConfig>
      <!-- Configuration fields -->
    </GenericConnectionConfig>
  </bns:object>
</bns:Component>
```

**Critical Attributes:**
- `type="connector-settings"`
- `subType="officialboomi-X3979C-opena2-prod"` (the OpenAPI connector's `connectorType`)

## Required Fields

The two fields unique to OpenAPI (beyond the shared connection fields) are `spec` and `url`:

```xml
<field id="spec" type="string" value="https://example.com/openapi.yaml"/>
<field id="url" type="string" value="https://api.example.com/v1"/>
<field id="auth" type="string" value="NONE"/>
```

| field id | Maps to GUI | Notes |
|---|---|---|
| `spec` | OpenAPI Specification | URL (http/https) or local file path to a JSON or YAML OpenAPI 3.0+ document |
| `url` | Server | Base server URL the connector calls (same field id as the REST connection) |
| `auth` | Authentication Type | See Authentication below |

## The `spec` Field

`spec` points at the OpenAPI document the connector reads to discover endpoints and schemas. It accepts either a remote URL or a local file path, in JSON or YAML. The specification drives operation import — operations reference endpoints defined here.

**`spec` is design-time only — not consulted at request time.** At request time the connector builds the URL from the connection `url` + the operation `objectTypeId` and never dereferences `spec`. It exists so the GUI import wizard can read endpoints/schemas; a hand-authored connection + operation pair executes correctly even with an empty or stale `spec`. Keep it accurate for GUI users, but it has no request-time effect.

## Authentication

`auth` selects the authentication mode. Enum values: `NONE`, `API_KEY`, `BASIC`. The skeleton also carries dedicated fields for Custom, AWS Signature, AWS IAM Roles Anywhere, and OAuth 2.0 authentication (see Whole-Skeleton Serialization).

### No Authentication
```xml
<field id="spec" type="string" value="https://example.com/openapi.yaml"/>
<field id="url" type="string" value="https://api.example.com/v1"/>
<field id="auth" type="string" value="NONE"/>
```
With `NONE`, the credential-bearing fields stay empty and `apiKeyLocation` serializes as empty (`value=""`).

### API Key
API key authentication stores the key's header/parameter **name** and its **value** in `apiKeyCustomProperties`, gated by `apiKeyLocation`:

```xml
<field id="auth" type="string" value="API_KEY"/>
<field id="apiKeyLocation" type="string" value="REQUEST_HEADER"/>
<field id="apiKeyCustomProperties" type="customproperties">
  <customProperties>
    <properties encrypted="true" key="Authorization" value="{encrypted-key}"/>
  </customProperties>
</field>
```

- `apiKeyLocation` selects where the key is sent; `REQUEST_HEADER` places it in a request header.
- The `key` attribute is the parameter name to send (e.g. `Authorization`, `X-API-Key`); the `value` carries the secret.
- The secret is stored as an **encrypted custom property**, not a `password` field. When present, the component's top-level `<bns:encryptedValues>` declares the path:
  ```xml
  <bns:encryptedValues>
    <bns:encryptedValue path="//GenericConnectionConfig/field[@type='customproperties']/customProperties/properties[@encrypted='true']/@value" isSet="true"/>
  </bns:encryptedValues>
  ```

### Basic
Basic authentication stores the username in plain `username` and the secret in a `password`-type field (encrypted on push):

```xml
<field id="auth" type="string" value="BASIC"/>
<field id="username" type="string" value="my-user"/>
<field id="password" type="password" value="{encrypted-secret}"/>
<field id="domain" type="string" value=""/>
<field id="workstation" type="string" value=""/>
<field id="preemptive" type="boolean" value="false"/>
```

- The secret lives in a `password`-type field, so the component's `<bns:encryptedValues>` path points at `field[@type='password']` (contrast API_KEY, which encrypts a custom property):
  ```xml
  <bns:encryptedValue path="//GenericConnectionConfig/field[@type='password']" isSet="true"/>
  ```
- `domain` and `workstation` are NTLM fields, empty for plain Basic.
- `preemptive` toggles sending the credentials without waiting for a 401 challenge.

## Connection Pooling

```xml
<field id="enableConnectionPooling" type="boolean" value="false"/>
<field id="maxTotal" type="integer" value=""/>
<field id="idleTimeout" type="integer" value=""/>
```

When pooling is disabled, `maxTotal` and `idleTimeout` serialize as empty strings rather than defaults.

`cookieScope` serializes as `GLOBAL` by default.

## Whole-Skeleton Serialization

Every field serializes regardless of the selected `auth` — a single connection therefore contains the complete field inventory (OAuth, AWS Signature, AWS IAM Roles Anywhere, API-key, certificate blocks), with unused fields empty. The full field id set:

```
spec, url, auth, username, password, domain, workstation, customAuthCredentials, preemptive,
awsAccessKey, awsSecretKey, awsService, customAwsService, awsRegion, customAwsRegion,
awsProfileArn, awsRoleArn, awsTrustAnchorArn, awsRolesAnywhereRegion, awsRolesAnywhereCustomRegion,
awsSessionName, awsDuration, awsPublicCertificate, awsPrivateKey,
oauthContext, privateCertificate, publicCertificate,
cookieScope, enableConnectionPooling, maxTotal, idleTimeout, apiKeyLocation, apiKeyCustomProperties
```

Two consequences:

1. **Field order is not stable across connector versions.** The AWS block can appear either immediately after `preemptive` or after `apiKeyCustomProperties`; order is consistent within a connector version but shifts across versions. Treat the field set as authoritative, not the order.
2. **Unset numerics/booleans serialize as empty string** (`preemptive=""`, `maxTotal=""`, `idleTimeout=""`, `awsDuration=""`), not their GUI defaults.

The `oauthContext` field always emits an `<OAuth2Config grantType="code">` skeleton even when OAuth is not the selected auth:
```xml
<field id="oauthContext" type="oauth">
  <OAuth2Config grantType="code">
    <credentials clientId=""/>
    <authorizationTokenEndpoint url=""><sslOptions/></authorizationTokenEndpoint>
    <authorizationParameters/>
    <accessTokenEndpoint url=""><sslOptions/></accessTokenEndpoint>
    <accessTokenParameters/>
    <scope/>
    <jwtParameters><expiration>0</expiration></jwtParameters>
  </OAuth2Config>
</field>
```

## Password / Encryption Handling

- **Pulled / existing connections:** preserve `<bns:encryptedValues>` and any encrypted `value` attributes exactly as-is. Never modify encrypted values.
- **New connections:** pass secrets as plain text and leave encryption metadata empty (`<bns:encryptedValues/>`). Boomi encrypts on push. The agent must NOT pre-encrypt values itself.

## Relationship with Operation Component

The connection provides the spec location, base server URL, authentication, and connection settings. The operation (authored from, or imported from, the same spec) adds the specific endpoint, HTTP method, request/response profiles, and parameter definitions. See `openapi_connector_operation_component.md`.
