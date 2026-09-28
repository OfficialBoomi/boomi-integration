# Boomi Managed File Transfer Connection Component

Component type: `connector-settings`
SubType: `officialboomi-X3979C-manage-prod`

## Contents
- Overview
- XML Structure
- Configuration Fields
- Credential Sources
- Password Handling

## Overview

Connection for the Boomi Managed File Transfer connector, the SDK-based connector that calls the MFT Content API. Authenticates with OAuth 2.0 client credentials.

Not the legacy connector (`thru-8SHH0W-thrumf-technology`, "Boomi Managed File Transfer (Legacy)") — see `mft_connection_component.md` for that one. The two use different MFT endpoint types and are not interchangeable.

## XML Structure

```xml
<bns:Component xmlns:bns="http://api.platform.boomi.com/"
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               componentId=""
               name="{connection-name}"
               type="connector-settings"
               subType="officialboomi-X3979C-manage-prod"
               folderId="{folder-id}">
  <bns:encryptedValues/>
  <bns:object>
    <GenericConnectionConfig>
      <field id="oauthContext" type="oauth">
        <OAuth2Config grantType="client_credentials">
          <credentials clientId="{client-id}" clientSecret="{client-secret}"/>
          <authorizationTokenEndpoint url="">
            <sslOptions/>
          </authorizationTokenEndpoint>
          <authorizationParameters/>
          <accessTokenEndpoint url="https://{region}-api.mft.boomi.com/oauth/token">
            <sslOptions/>
          </accessTokenEndpoint>
          <accessTokenParameters/>
          <scope>publicAPI-read</scope>
          <jwtParameters>
            <expiration>0</expiration>
          </jwtParameters>
          <credentialsAssertionType>client_secret</credentialsAssertionType>
        </OAuth2Config>
      </field>
    </GenericConnectionConfig>
  </bns:object>
</bns:Component>
```

`oauthContext` is the only field. The connection has no separate base URL field.

## Configuration Fields

| Element / Attribute | Value | Notes |
|---------------------|-------|-------|
| `OAuth2Config/@grantType` | `client_credentials` | |
| `credentials/@clientId` | Client ID | From the Boomi MFT Connector endpoint |
| `credentials/@clientSecret` | Client Secret | Encrypted on push |
| `accessTokenEndpoint/@url` | Full token URL including `/oauth/token` | Copy from the OAuth Access Token URL field on the organization's endpoint page |
| `scope` | `publicAPI-read` | Not shown in the GUI; written by the connector. Permits List, Get, and Create |
| `credentialsAssertionType` | `client_secret` | |
| `authorizationTokenEndpoint/@url` | empty | Not used by client credentials, but the element is present |

The GUI connection form shows only Client ID, Client Secret, and Access Token URL. A GUI save resets `scope` to `publicAPI-read`, even if a push changed it.

`credentials/@accessTokenKey` (a GUID) is platform-generated: omit it on new connections and the platform adds it on push. Every GUI save regenerates it.

The token URL host varies by MFT environment. Production region hosts follow `https://{region}-api.mft.boomi.com` (`us`, `eu`, `uk`, `au`); copy the exact URL from the endpoint page.

## Credential Sources

In the MFT portal, create an endpoint of type **Boomi MFT Connector** (Organizations → Endpoints → Add Endpoint). The endpoint page shows the Client ID, Client Secret, and OAuth Access Token URL. The Client Secret is shown only once, when the endpoint is created.

The endpoint must then be added to a flow: as a **Source** for Create (upload into MFT), as a **Target** for List/Get (download from MFT). Operations reference the resulting flow endpoint by its numeric ID.

## Password Handling

Prefer an existing connection: reuse one from `preferred_connections.md` or pull one the user points to (see BOOMI_THINKING.md § Connection Discovery).

**New connections**: Have the user enter the Client Secret in the Boomi GUI. Push the connection with a placeholder `clientSecret` and `<bns:encryptedValues/>` empty, then have the user open it, enter the secret, and save. Do not ask the user for the plaintext secret to get past this. If the user provides the secret directly, a plaintext `clientSecret` is encrypted on push.

**Pulled connections**: Do not edit and re-push a pulled connection. The push re-encrypts the stored `clientSecret` ciphertext as if it were plaintext; the push reports success, but the next execution fails with `OAuth 2.0 token mint failed ... invalid_client`. Re-entering the secret in the GUI restores it.

The encrypted path is:

```xml
<bns:encryptedValue isSet="true" path="//GenericConnectionConfig/field/OAuth2Config/credentials/@clientSecret"/>
```
