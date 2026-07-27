# HTTP Client Component Reference (Awareness Only)

## Contents
- Scope
- Recognition
- Connection Structure
- Operation Structure
- Step Structure
- Runtime Behaviors

## Scope

Default: for new work, use the REST client (`rest_connection_component.md`, `rest_connector_operation_component.md`, `rest_connector_step.md`). Do not author a new HTTP Client component on agent judgment alone.

Two narrow exceptions where authoring a new HTTP Client asset is correct:

1. **The user explicitly asks for HTTP Client.** Honor the request.
2. **Extending an existing HTTP Client connection.** If the target endpoint is already reachable through an HTTP Client connection in the user's account, add new HTTP Client operations/steps against that connection rather than authoring a parallel REST connection — a duplicate connection to the same endpoint is not a good outcome for the customer.

Outside these two cases, use REST. HTTP Client is never chosen on stylistic or "feels simpler" grounds.

## Recognition

| Location | Marker |
|----------|--------|
| Connection metadata | `type="connector-settings" subType="http"` |
| Operation metadata | `type="connector-action" subType="http"` |
| Connection body root | `<HttpSettings xmlns="">` |
| Operation body action | `<HttpGetAction>` or `<HttpSendAction>` |
| Step in process XML | `<connectoraction ... connectorType="http" ...>` |
| Step attribute | `parameter-profile="EMBEDDED\|HttpParameterChooser\|<operationId>"` |

## Connection Structure

Root is `<HttpSettings>`. All five sub-blocks (`AuthSettings`, `OAuthSettings`, `OAuth2Settings`, `AwsSettings`, `SSLOptions`) are required on every create and update, with empty/default attributes on unused blocks — the API accepts their absence, but the Build UI hard-errors on the component and it cannot be edited, saved, or closed. Unset encrypted attributes (`password`, `consumerSecret`, `tokenSecret`, `clientSecret`) may be omitted.

```xml
<HttpSettings xmlns="" authenticationType="NONE|BASIC|PASSWORD_DIGEST|CUSTOM|OAUTH|OAUTH2|AWSV4|NETWORK_AUTHENTICATION"
              url="https://example.com">
  <AuthSettings user="" password=""/>
  <OAuthSettings requestTokenURL="" accessTokenURL="" authorizationURL=""
                 consumerKey="" consumerSecret="" accessToken="" tokenSecret=""
                 realm="" signatureMethod="SHA256|SHA1" suppressBlankAccessToken="false"/>
  <OAuth2Settings grantType="code|client_credentials|password"
                  refreshAuthScheme="req_body_params_auth|basic_auth">
    <credentials clientId="" clientSecret="" accessToken="" accessTokenKey=""/>
    <authorizationTokenEndpoint url=""><sslOptions/></authorizationTokenEndpoint>
    <authorizationParameters>
      <parameter name="..." value="..."/>
    </authorizationParameters>
    <accessTokenEndpoint url=""><sslOptions/></accessTokenEndpoint>
    <accessTokenParameters/>
    <scope/>
  </OAuth2Settings>
  <AwsSettings>
    <credentials>
      <accessKeyId/>
      <awsService>s3</awsService>
      <customService/>
      <awsRegion>ap-northeast-1</awsRegion>
      <customRegion/>
    </credentials>
  </AwsSettings>
  <SSLOptions clientauth="false" clientsslalias="" trustServerCert="false" trustedcertalias=""/>
</HttpSettings>
```

Optional `<HttpSettings>` attributes (omitted when unset): `connectTimeout`, `readTimeout` (milliseconds; `0` = infinite), `cookieScope` (`GLOBAL|CONNECTOR_SHAPE|IGNORED`; default `GLOBAL`).

| `authenticationType` | GUI label | Auth block |
|----------------------|-----------|------------|
| `NONE` | None | — |
| `BASIC` | Basic | `AuthSettings` |
| `PASSWORD_DIGEST` | Password Digest | `AuthSettings` |
| `CUSTOM` | Custom | `AuthSettings` (replaces `username`/`password` replacement variables in headers and resource path) |
| `OAUTH` | OAuth | `OAuthSettings` (1.0/1.0a) |
| `OAUTH2` | OAuth 2.0 | `OAuth2Settings` |
| `AWSV4` | AWS Signature | `AwsSettings` |
| `NETWORK_AUTHENTICATION` | NTLM Authentication | — (uses Windows OS credentials) |

`signatureMethod` default is `SHA256` on new connections, `SHA1` on pre-existing ones. `AwsSettings` emits `awsService`/`awsRegion` defaults even when the connection is not AWSV4.

Encrypted attributes are tracked in a sibling manifest on the component (`<bns:encryptedValues/>` self-closed when none):
```xml
<bns:encryptedValues>
  <bns:encryptedValue path="//HttpSettings/AuthSettings/@password" isSet="true"/>
</bns:encryptedValues>
```

## Operation Structure

```xml
<Operation xmlns="">
  <Archiving directory="" enabled="false"/>
  <Configuration>
    <HttpGetAction dataContentType="application/json"
                   followRedirects="false"
                   methodType="GET|POST|PUT|DELETE"
                   requestProfileType="NONE|XML|JSON"
                   responseProfileType="NONE|XML|JSON"
                   requestProfile=""
                   responseProfile=""
                   returnErrors="true"
                   returnMimeResponse="false">
      <requestHeaders>
        <header headerName="..." headerValue="..." key="1000001"/>
      </requestHeaders>
      <pathElements>
        <element key="2000000" name="literal/segment"/>
        <element isVariable="true" key="2000001" name="DDP_NAME"/>
      </pathElements>
      <responseHeaderMapping/>
      <reflectHeaders/>
    </HttpGetAction>
  </Configuration>
  <Tracking><TrackedFields/></Tracking>
  <Caching/>
</Operation>
```

- `<HttpGetAction>` sends a request with no body; `methodType` can be any value (e.g., an endpoint that expects POST with parameters in the URL and no body uses `<HttpGetAction methodType="POST">`).
- `<HttpSendAction>` sends a request with a body and carries an additional `returnResponses="true|false"` attribute.
- `<Archiving>`, `<Tracking>`, `<Caching>` shell elements are always present on the operation.
- `<element>` entries concatenate literally — the connector does not insert `/` between them. Separators must be included in `name` attributes, typically as trailing slashes on static segments (e.g., `name="pet/"` rather than `name="pet"`). The connector **does** join the connection base URL to the path with a single `/`, so the **first** path element must **not** begin with `/` — a leading slash yields a double slash (`https://host//get…`), which typically returns an HTML 404 and surfaces downstream as `Unable to create JSON files from data … Unexpected character ('<' …)`.
- Within `<pathElements>`, `?` and `&` are literal characters inside `name` values; there is no separate querystring element. For a multi-param querystring, use `?key=` / `&key=` prefixes in static elements with the value element immediately after each (static `?foo=` + variable `FOO_VAL` + static `&bar=` + variable `BAR_VAL` → `?foo=X&bar=Y`).
- Variable values substituted into path elements or headers are inserted literally — the connector does not URL-encode them. Callers must pre-encode values containing reserved characters (space, `&`, `=`, `+`, `#`, `?`) upstream via Set Properties or Map functions.
- `isVariable="true"` on `<header>` or `<element>` marks the value as a replacement variable (GUI label: "Is replacement variable?"), resolved from a DDP of the same name at runtime.
- `<responseHeaderMapping>/<header headerFieldName="..." targetPropertyName="..." key="..."/>` captures named response headers into DDPs.

## Step Structure

```xml
<shape image="connectoraction_icon" name="shape5" shapetype="connectoraction" userlabel="..." x="..." y="...">
  <configuration>
    <connectoraction actionType="Get|Send"
                     allowDynamicCredentials="NONE"
                     connectionId="<connection-guid>"
                     connectorType="http"
                     hideSettings="false"
                     operationId="<operation-guid>"
                     parameter-profile="EMBEDDED|HttpParameterChooser|<operation-guid>">
      <parameters/>
      <dynamicProperties/>
    </connectoraction>
  </configuration>
</shape>
```

- `actionType` is `Get` or `Send`.
- The final segment of `parameter-profile` equals `operationId`.

Per-document parameter wiring. In practice, replacement-variable values are most commonly supplied by properties set upstream — DDPs are set by name (matching the replacement-variable names on the operation's elements) and the runtime picks them up automatically. In this pattern the step's `<parameters/>` stays empty.

The step's Parameters tab is an alternate authoring surface that wires values directly into operation elements from a variety of sources (DDPs, profile fields, process properties, static values, and more). Each source produces a `<parametervalue elementToSetId="<operation-element-key>">` entry inside `<parameters>`; the child element and attributes vary by source. Example with a DDP source:

```xml
<parameters>
  <parametervalue elementToSetId="2000001" elementToSetName="FolderId" key="0" valueType="track">
    <trackparameter defaultValue="" propertyId="dynamicdocument.FolderId" propertyName="Dynamic Document Property - FolderId"/>
  </parametervalue>
</parameters>
```

`elementToSetId` matches the `key` of the target element in the operation.

## Runtime Behaviors

- POST/PUT requests send a blank payload to the endpoint when replacement-variable values are supplied via the step's Parameters tab. Workaround: a Set Properties step upstream of the HTTP Client step setting DDPs whose names exactly (case-sensitive) match the replacement-variable names in the operation.
- `returnErrors="true"` allows the process to continue on 3xx/4xx/5xx; the response body becomes the document payload. No named Meta property captures the status code or message — branch on `connector.track.http.url` presence (populated only on 2xx) or on response-body content. With `returnErrors="false"`, non-2xx responses fail the document path; the HTTP status and message can be regex-parsed from `meta.base.catcherrorsmessage` (e.g., "Error message received from Http Server, Code 404: Not Found") in a Try/Catch branch.
- The connector is stateless and has no listener action — inbound HTTP uses the Web Services Server start step (`web_services_server_start_shape_operation.md`).
