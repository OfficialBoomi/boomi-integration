# Mail (IMAP) Connection Component

## Contents
- Overview
- Component Structure
- Authentication Patterns
- Required Fields
- Connection Fields
- OAuth 2.0 Notes

## Overview

Mail (IMAP) connection components define a single connection that carries both outbound SMTP and inbound IMAP settings. One connection per mail account; the Receive, Send, and Move operations all reuse it.

**Connector Type**: `mailsdk` (distinct from the legacy `mail` connector — `mailsdk` adds IMAP receive, OAuth 2.0, attachment cache, and Move).

OAuth 2.0 token generation requires the Boomi GUI (browser-driven authorization code grant). Connections that use OAuth must be created/refreshed in the platform and pulled to local — do not construct OAuth credentials programmatically.

## Component Structure

```xml
<?xml version="1.0" encoding="UTF-8"?>
<bns:Component xmlns:bns="http://api.platform.boomi.com/"
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               componentId=""
               name="{connection-name}"
               type="connector-settings"
               subType="mailsdk"
               folderId="{folder-id}">
  <bns:encryptedValues/>
  <bns:object>
    <GenericConnectionConfig>
      <!-- Configuration fields -->
    </GenericConnectionConfig>
  </bns:object>
</bns:Component>
```

## Authentication Patterns

### Basic Authentication

Username/password for both directions:

```xml
<GenericConnectionConfig>
  <field id="outboundHost" type="string" value="smtp.example.com"/>
  <field id="outboundPort" type="integer" value="587"/>
  <field id="outboundUseAuthentication" type="boolean" value="true"/>
  <field id="outboundAuthType" type="string" value="BASIC"/>
  <field id="outboundConnectionSecurity" type="string" value="STARTTLS"/>
  <field id="outboundUsername" type="string" value="user@example.com"/>
  <field id="outboundPassword" type="password" value="{password}"/>
  <field id="inboundHost" type="string" value="imap.example.com"/>
  <field id="inboundPort" type="integer" value="993"/>
  <field id="inboundConnectionSecurity" type="string" value="SSL_TLS"/>
  <field id="inboundAuthType" type="string" value="BASIC"/>
  <field id="inboundUsername" type="string" value="user@example.com"/>
  <field id="inboundPassword" type="password" value="{password}"/>
</GenericConnectionConfig>
```

### OAuth 2.0

Each direction has its own `OAuth2Config` block, or inbound can reuse the outbound token via `inboundAuthType="OAUTH2_SAME_AS_OUTBOUND"` (omit the `inboundOAuth2Options` field block in that case).

```xml
<GenericConnectionConfig>
  <field id="outboundHost" type="string" value="smtp.example.com"/>
  <field id="outboundPort" type="integer" value="465"/>
  <field id="outboundUseAuthentication" type="boolean" value="true"/>
  <field id="outboundAuthType" type="string" value="OAUTH2_OUTBOUND"/>
  <field id="outboundConnectionSecurity" type="string" value="STARTTLS"/>
  <field id="outboundUsername" type="string" value="user@example.com"/>
  <field id="outboundPassword" type="password" value=""/>
  <field id="inboundHost" type="string" value="imap.example.com"/>
  <field id="inboundPort" type="integer" value="993"/>
  <field id="inboundConnectionSecurity" type="string" value="STARTTLS"/>
  <field id="inboundAuthType" type="string" value="OAUTH2_INBOUND"/>
  <field id="inboundUsername" type="string" value="user@example.com"/>
  <field id="inboundPassword" type="password" value=""/>
  <field id="outboundOAuth2Options" type="oauth">
    <OAuth2Config grantType="code">
      <credentials accessToken="{json-token-blob}"
                   accessTokenKey="{guid}"
                   clientId="{oauth-client-id}"
                   clientSecret="{encrypted-secret}"/>
      <authorizationTokenEndpoint url="{authorize-url}">
        <sslOptions/>
      </authorizationTokenEndpoint>
      <authorizationParameters>
        <parameter name="access_type" value="offline"/>
        <parameter name="prompt" value="consent"/>
      </authorizationParameters>
      <accessTokenEndpoint url="{token-url}">
        <sslOptions/>
      </accessTokenEndpoint>
      <accessTokenParameters/>
      <scope>{space-separated-scopes}</scope>
      <jwtParameters>
        <expiration>0</expiration>
      </jwtParameters>
    </OAuth2Config>
  </field>
  <field id="inboundOAuth2Options" type="oauth">
    <!-- Same OAuth2Config shape as outbound. Omit entirely when inboundAuthType="OAUTH2_SAME_AS_OUTBOUND". -->
  </field>
</GenericConnectionConfig>
```

**Encrypted values**: When OAuth is configured, the platform marks `clientSecret` paths in `<bns:encryptedValues>`. For pulled/existing connections, preserve those entries and the encrypted values exactly as-is. For new connections, Boomi auto-encrypts on push.

## Required Fields

Always required (both auth modes):

```xml
<field id="outboundHost" type="string" value="{smtp-host}"/>
<field id="outboundPort" type="integer" value="{smtp-port}"/>
<field id="outboundUseAuthentication" type="boolean" value="true"/>
<field id="outboundAuthType" type="string" value="{BASIC|OAUTH2_OUTBOUND}"/>
<field id="outboundConnectionSecurity" type="string" value="{NONE|SSL_TLS|STARTTLS}"/>
<field id="outboundUsername" type="string" value="{username}"/>
<field id="outboundPassword" type="password" value=""/>
<field id="inboundHost" type="string" value="{imap-host}"/>
<field id="inboundPort" type="integer" value="{imap-port}"/>
<field id="inboundConnectionSecurity" type="string" value="{NONE|SSL_TLS|STARTTLS}"/>
<field id="inboundAuthType" type="string" value="{BASIC|OAUTH2_INBOUND|OAUTH2_SAME_AS_OUTBOUND}"/>
<field id="inboundUsername" type="string" value="{username}"/>
<field id="inboundPassword" type="password" value=""/>
```

Additional for OAuth 2.0:
- `outboundOAuth2Options` when `outboundAuthType="OAUTH2_OUTBOUND"`
- `inboundOAuth2Options` when `inboundAuthType="OAUTH2_INBOUND"` (omit when `OAUTH2_SAME_AS_OUTBOUND`)

## Connection Fields

### Outbound (SMTP)

| Field | Type | Description |
|-------|------|-------------|
| `outboundHost` | string | SMTP hostname. |
| `outboundPort` | integer | SMTP port. GUI default `25`. Common alternatives: `587` (StartTLS submission), `465` (SSL/TLS). Boomi public clouds throttle port 25. |
| `outboundUseAuthentication` | boolean | Whether outbound requires credentials. |
| `outboundAuthType` | string | `BASIC` or `OAUTH2_OUTBOUND`. |
| `outboundConnectionSecurity` | string | `NONE`, `SSL_TLS`, or `STARTTLS`. |
| `outboundUsername` | string | SMTP user (typically the sending email address). |
| `outboundPassword` | password | SMTP password. Empty when using OAuth 2.0. |

### Inbound (IMAP)

| Field | Type | Description |
|-------|------|-------------|
| `inboundHost` | string | IMAP hostname. |
| `inboundPort` | integer | IMAP port. GUI default `143`. Common alternative: `993` (SSL/TLS). |
| `inboundConnectionSecurity` | string | `NONE`, `SSL_TLS`, or `STARTTLS`. |
| `inboundAuthType` | string | `BASIC`, `OAUTH2_INBOUND`, or `OAUTH2_SAME_AS_OUTBOUND`. Inbound has no `useAuthentication` toggle — IMAP always authenticates. |
| `inboundUsername` | string | IMAP user. |
| `inboundPassword` | password | IMAP password. Ignored when `inboundAuthType` is an OAuth value. |

## OAuth 2.0 Notes

- `grantType="code"` is the only supported flow (Authorization Code with browser redirect).
- `credentials/@accessToken` carries a JSON-encoded token blob (`{access_token, refresh_token, scope, token_type, expires_in}`); auto-refreshed by the connector.
- `authorizationParameters` carries provider-specific extras. Some providers require additional parameters (e.g. `access_type=offline` + `prompt=consent`) on the authorization request to issue a refresh token — consult the mail provider's OAuth documentation.
- `inboundAuthType="OAUTH2_SAME_AS_OUTBOUND"`: omit the `inboundOAuth2Options` field block; the connector reuses the outbound token for IMAP.
