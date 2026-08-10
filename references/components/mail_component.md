# Mail Connector Reference (Awareness Only)

## Contents
- Scope
- Recognition
- Connection Structure
- Operation Structure
- Step Structure
- Document Properties
- Runtime Behaviors

## Scope

For new work use the Mail (IMAP) connector (`references/components/mail_imap_connection_component.md`, `references/components/mail_imap_connector_operation_component.md`, `references/steps/mail_imap_connector_step.md`). Boomi no longer actively maintains the Mail connector. Do not author a new Mail component on agent judgment alone.

Author a new Mail asset only when:

1. The user explicitly asks for the Mail connector.
2. Extending an existing Mail connection — add operations/steps against it rather than authoring a parallel Mail (IMAP) connection.

Mail (IMAP) additionally supports IMAP receive (Mail's Get is POP3 only), OAuth 2.0, folder Move, CC/BCC, and an attachment cache.

## Recognition

The following markers will indicate the Mail connector:
| Location | Marker |
|----------|--------|
| Connection metadata | `type="connector-settings" subType="mail"` |
| Operation metadata | `type="connector-action" subType="mail"` |
| Connection body root | `<MailSettings>` |
| Operation body action | `<MailGetAction>` or `<MailSendAction>` |
| Step in process XML | `<connectoraction ... connectorType="mail" ...>` |

By contrast, the new recommended IMAP connector will show as `mailsdk`. Neither `<MailSettings>` nor `<Operation>` carries an `xmlns=""` declaration in the Mail (IMAP) connector.

## Connection Structure

```xml
<MailSettings host="smtp.example.com" port="587"
              usesmtpauth="true" usessl="false" usetls="true">
  <AuthSettings user="user@example.com" password="{password}"/>
</MailSettings>
```

- `<AuthSettings>` is a required child. Omitting it fails create **and** update with HTTP 400 (`cvc-complex-type.2.4.b: The content of element 'MailSettings' is not complete. One of '{AuthSettings}' is expected.`). Emit it even when `usesmtpauth="false"`, with empty `user`/`password`.
- Defaults: `port="25"`, `usesmtpauth="false"`, `usessl="false"`. Pulled XML emits every attribute explicitly.
- One host/port pair per connection, shared by both actions. A Send (SMTP) and a Get (POP3) require **separate connection components**. Default ports: 25 send, 110 receive.
- Boomi public runtime clouds throttle port 25 — use 587 or 465 for SMTP.
- The password is tracked at `//MailSettings/AuthSettings/@password` in the component's `<bns:encryptedValues>` manifest (self-closed when unset).

## Operation Structure

```xml
<Operation>
  <Archiving directory="" enabled="false"/>
  <Configuration>
    <!-- exactly one of MailSendAction / MailGetAction -->
  </Configuration>
  <Tracking><TrackedFields/></Tracking>
  <Caching/>
</Operation>
```

The `<Archiving>`, `<Tracking>`, `<Caching>` shells are always present.

### Send

```xml
<MailSendAction bodyContentType="text/plain"
                dataContentType="text/plain"
                disposition="inline|attachment"
                from="sender@example.com"
                subject="Weekly extract"
                to="recipient@example.com"/>
```

| Attribute | Notes |
|-----------|-------|
| `from` | Overridden per document by `connector.mail.fromAddress`. |
| `to` | Semicolon-separated for multiple recipients. Overridden by `connector.mail.toAddress`. |
| `subject` | Overridden by `connector.mail.subject`. |
| `disposition` | `inline` or `attachment`. |
| `dataContentType` | Format of the attachment (`attachment`) or of the body (`inline`). |
| `bodyContentType` | Format of the body supplied via `connector.mail.body` — applies only under `disposition="attachment"`. Under `inline` it is inert (`dataContentType` governs the body) and optional. |

### Get

```xml
<MailGetAction deleteFromPopServer="false"
               disposition="inline|attachment"
               fromAddress=""/>
```

| Attribute | Notes |
|-----------|-------|
| `fromAddress` | Blank takes mail from all senders; set to restrict to one. |
| `disposition` | `attachment` reads data from email attachments; `inline` reads it from the body. |
| `deleteFromPopServer` | Deletes each message after reading. |

The sender attribute is `from` on Send but `fromAddress` on Get.

### Content type values

Author these exactly as shown — the tokens are case-sensitive. A mis-cased value (e.g. `text/HTML`) is not rejected; it is silently sent as `text/plain`. These lowercase forms are what the GUI dropdowns store.

`dataContentType`: `text/plain`, `text/html`, `text/xml`, `application/binary`, `application/edifact`, `application/edi-x12`, `application/xml`.

`bodyContentType`: `text/plain`, `text/html`, `text/xml`.

## Step Structure

```xml
<shape image="connectoraction_icon" name="shape2" shapetype="connectoraction" userlabel="..." x="..." y="...">
  <configuration>
    <connectoraction actionType="Get|Send"
                     allowDynamicCredentials="NONE"
                     connectionId="<connection-guid>"
                     connectorType="mail"
                     hideSettings="false"
                     operationId="<operation-guid>">
      <parameters/>
      <dynamicProperties/>
    </connectoraction>
  </configuration>
</shape>
```

- `actionType` is title-case `Get`/`Send` (Mail (IMAP) uses uppercase `RECEIVE`/`SEND`/`MOVE`).
- No `parameter-profile` attribute — the step has no parameter surface. Per-document values come from document properties set upstream.
- `<parameters/>` and `<dynamicProperties/>` are present and empty.

## Document Properties

Set upstream with a Set Properties step (`documentproperty/@propertyId`); these override the matching operation fields per document. See `references/steps/set_properties_step.md` for the Set Properties shape structure and `references/guides/parameter_value_types.md` for source-value types.

| `propertyId` | Display name | Notes |
|--------------|--------------|-------|
| `connector.mail.body` | Mail - Body | Body text. Read only when `disposition="attachment"`. |
| `connector.mail.subject` | Mail - Subject | Overrides `subject`. |
| `connector.mail.fromAddress` | Mail - From Address | Overrides `from`. |
| `connector.mail.toAddress` | Mail - To Address | Overrides `to`. |
| `connector.mail.filename` | Mail - File Name | Attachment file name. |

Casing is not uniform — `filename` is lowercase, `fromAddress`/`toAddress` are camelCase. Copy each literally.

From Groovy/JavaScript the connector uses a separate namespace:

- Tracked inbound (read-only): `connector.track.mail.` + `filename`, `fromaddress`, `host`, `messageId`, `subject`, `toaddress`, `user`
- Dynamic outbound (writable): `connector.dynamic.mail.` + `filename`, `fromaddress`, `subject`, `toaddress`

## Runtime Behaviors

- `disposition` decides which input becomes the body. `inline` — the document payload is the body and `connector.mail.body` is ignored entirely. `attachment` — the payload becomes the attachment and `connector.mail.body` supplies the body.
- With `disposition="attachment"` and `connector.mail.filename` unset, the send succeeds and the connector generates a name itself (a numeric timestamp with a `.dat` extension). Set the property to get a meaningful one.
- Multiple recipients require a **semicolon** separator, in `to` or `connector.mail.toAddress`; the delivered `To:` header is rewritten as an RFC 5322 comma-separated list. A comma-separated input fails with `Invalid Addresses; Caused by: 501 Error: Bad recipient address syntax`.
- Outbound `connector.mail.*` properties are write-only. A `track` read of one returns empty even when the value is applied to the sent mail — an empty read is not evidence the property failed to set.
- Building a body for an attachment send needs a Branch: a Message step replaces the current document, destroying the document to be attached. One branch builds the body, the other retains the attachment document.
  - **Single document** — park the body in a dynamic process property, read it back into `connector.mail.body`.
  - **Multiple documents** — a process property is overwritten per document; wrap the body in an XML element, load it into a Document Cache indexed by a document key, and look each one up. Add to Cache consumes documents, so it must be last in its branch.
