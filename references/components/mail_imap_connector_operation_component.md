# Mail (IMAP) Connector Operation Component

## Contents
- Overview
- Operation Types
- Component Structure
- RECEIVE Operation
- SEND Operation
- MOVE Operation
- Document Properties

## Overview

Mail (IMAP) operation components define how a process interacts with email — retrieve from IMAP, send via SMTP, or move messages between folders. Operations use `GenericOperationConfig` with `objectTypeId="Mail"` and `objectTypeName="Mail"` on every action.

**Connector Type**: `mailsdk`

## Operation Types

| Action | customOperationType | operationType | requestProfileType | responseProfileType | trackResponse |
|--------|---------------------|---------------|--------------------|---------------------|---------------|
| Receive | `RECEIVE` | `QUERY` | `xml` (no profile) | `binary` | `true` |
| Send | `SEND` | `CREATE` | `binary` | `none` | `false` |
| Move | `MOVE` | `DELETE` | `xml` (with `requestProfile`) | `xml` | `false` |

Receive returns email body as a binary document and routes attachments through a Document Cache. Send consumes one input document as the email body. Move uses an XML request profile that holds Message ID(s).

## Component Structure

```xml
<?xml version="1.0" encoding="UTF-8"?>
<bns:Component xmlns:bns="http://api.platform.boomi.com/"
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               componentId=""
               name="{operation-name}"
               type="connector-action"
               subType="mailsdk"
               folderId="{folder-id}">
  <bns:encryptedValues/>
  <bns:object>
    <Operation returnApplicationErrors="false" trackResponse="{see matrix}">
      <Archiving directory="" enabled="false"/>
      <Configuration>
        <GenericOperationConfig customOperationType="{RECEIVE|SEND|MOVE}"
            objectTypeId="Mail" objectTypeName="Mail"
            operationType="{QUERY|CREATE|DELETE}"
            requestProfileType="{xml|binary}"
            responseProfileType="{binary|none|xml}">
          <!-- Action-specific fields and Options -->
        </GenericOperationConfig>
      </Configuration>
      <Tracking><TrackedFields/></Tracking>
      <Caching/>
    </Operation>
  </bns:object>
</bns:Component>
```

## RECEIVE Operation

Retrieves email from the IMAP mailbox. Works as a query — filters apply to the IMAP `SEARCH` command. By default (no filter) only unread mail in the inbox is returned.

```xml
<GenericOperationConfig customOperationType="RECEIVE" objectTypeId="Mail" objectTypeName="Mail"
    operationType="QUERY" requestProfileType="xml" responseProfileType="binary">
  <field id="deleteFromServer" type="boolean" value="false"/>
  <field id="attachmentCache" type="component" value="{document-cache-id}"/>
  <field id="indexName" type="string" value="MAIL_ROOT_DOCUMENT_ID"/>
  <field id="aliasName" type="string" value="Mail (IMAP) - Message ID"/>
  <Options>
    <QueryOptions>
      <Fields>
        <ConnectorObject name="Mail">
          <FieldList>
            <ConnectorField filterable="true" name="subject" selected="false"/>
            <ConnectorField filterable="true" name="fromAddress" selected="false"/>
            <ConnectorField filterable="true" name="fromFolder" selected="false"/>
            <ConnectorField filterable="true" name="read" selected="false"/>
            <ConnectorField filterable="true" name="receivedDate" selected="false"/>
          </FieldList>
          <Filter>
            <ConnectorBaseFilter>
              <ConnectorFilterLogical logicalOperator="and">
                <ConnectorFilterExpression expressionField="fromFolder"
                    expressionOperator="EQUAL_TO" key="1" name="fromFolder"/>
                <ConnectorFilterExpression expressionField="subject"
                    expressionOperator="CONTAINS" key="2" name="subject"/>
              </ConnectorFilterLogical>
            </ConnectorBaseFilter>
          </Filter>
          <Sorts/>
        </ConnectorObject>
      </Fields>
      <Inputs>
        <Input key="1" name="fromFolder"/>
        <Input key="2" name="subject"/>
      </Inputs>
    </QueryOptions>
  </Options>
</GenericOperationConfig>
```

### RECEIVE Fields

| Field | Type | Description |
|-------|------|-------------|
| `deleteFromServer` | boolean | Delete each message from the IMAP server after read. Leave `false` when followed by a Move step. Exact removal semantics depend on the IMAP server's MOVE/EXPUNGE/label-handling implementation: some hard-delete or move to Trash, others strip the queried folder's label while retaining the underlying message elsewhere. Verify against the target mailbox before relying on `="true"` for true purge. |
| `attachmentCache` | component | Document Cache component ID. Required when retrieving attachments. |
| `indexName` | string | Cache index name. The key on this index must be the Message ID document property. |
| `aliasName` | string | Alias label for the Document Property Key (display only). |

### RECEIVE Filter Fields

All filter fields are `filterable="true"`. Selectability is not used (Receive returns the raw email body — column selection does not apply).

| Field | Notes |
|-------|-------|
| `subject` | Email subject string. |
| `fromAddress` | Sender's email address. |
| `fromFolder` | Mailbox folder to search. Default folder is the inbox. |
| `read` | `true` = read messages, `false` = unread. The connector applies an implicit `read=false` constraint when no explicit `read` filter is in the parameters — that implicit constraint ANDs with any other filters (subject, fromFolder, etc.), so a query with only a `subject` filter still returns unread-only. Add an explicit `read=true` filter parameter to query already-seen messages; supply both `read=true` and `read=false` to cover both states. |
| `receivedDate` | IMAP search filters on **date only** (no time component). Filter values use `dd MMM yyyy`.  Numeric months and 2-digit years are rejected with `[ERROR] Unable to parse the date: <value>`. |

### RECEIVE Filter Operators

| Filter Field | Operators |
|---|---|
| `subject`, `fromAddress`, `fromFolder` | `EQUAL_TO`, `CONTAINS` |
| `read` | `EQUAL_TO` |
| `receivedDate` | `GREATER_THAN`, `LESS_THAN`, `EQUAL_TO` |

`receivedDate` operator semantics (date-only, whole-day resolution):

| Operator | Semantics | Example |
|---|---|---|
| `GREATER_THAN <date>` | Strictly after `<date>` — `<date>` itself is **excluded** | `GT 14 May 2026` matches emails received on 15 May 2026 or later |
| `LESS_THAN <date>` | Strictly before `<date>` — `<date>` itself is **excluded** | `LT 14 May 2026` matches emails received on 13 May 2026 or earlier |
| `EQUAL_TO <date>` | Received on `<date>`, any time of day | `EQ 14 May 2026` matches emails received between 00:00:00 and 23:59:59 on 14 May 2026 |

There is no inclusive (`>=` / `<=`) operator. For "on or after today," use `GREATER_THAN yesterday`; for "on or before today," use `LESS_THAN tomorrow`.

Multiple filters combine with `<ConnectorFilterLogical logicalOperator="and">`. Filter values are passed as step parameters (`<parametervalue key="N">`) where `key` matches the corresponding `<Input key="N">`.

### RECEIVE Response and Attachments

- Returns one document per email; document body is the raw email body bytes (binary).
- The Message ID is set on the tracked property `connector.mailsdk.messageId`.
- Each attachment is stored separately in the configured `attachmentCache`, keyed by the Message ID. Retrieve attachments downstream with a Document Cache Retrieve step using `connector.mailsdk.messageId` as the lookup key.
- Attachment Content-Type common values: `text/plain`, `text/html`, `text/xml`, `application/binary`, `application/EDIFACT`, `application/EDI-X12`, `application/xml`.
- Receive auto-populates the following connector-tracked properties on each body document: `connector.mailsdk.messageId`, `connector.mailsdk.subject`, `connector.mailsdk.toAddress`, `connector.mailsdk.fromAddress`, `connector.mailsdk.attachmentsCount`, `connector.mailsdk.receivedDate`. Downstream steps can read any of these via a `track` source value or `{trackedproperty}` substitution.
- **CC and BCC headers are NOT exposed.** `connector.mailsdk.ccAddress` and `connector.mailsdk.bccAddress` are write-only on the Send side; Receive does not populate them, and the MIME-header properties (`mime.Cc`, `mime.Bcc`) are also not set. Downstream Boomi steps cannot read the CC/BCC recipient list of a received email through tracked properties.
- To read body-level properties downstream, `track` the `connector.mailsdk.*` properties on the body document. To read per-attachment properties, retrieve attachments from the cache using `connector.mailsdk.messageId` as the key — each attachment document carries its own `connector.mailsdk.fileName` and `connector.mailsdk.contentType` populated from the MIME parts.

## SEND Operation

Sends a single email per input document. The document body becomes the email body. To, From, CC, BCC, Subject, and attachments can be configured statically here or overridden per-document via the `connector.mailsdk.*` properties listed in the Document Properties table.

```xml
<GenericOperationConfig customOperationType="SEND"
    operationType="CREATE" requestProfileType="binary" responseProfileType="none">
  <field id="fromAddress" type="string" value="{connection-outbound-username}"/>
  <field id="toAddress" type="string" value="{default-to}"/>
  <field id="ccAddress" type="string" value=""/>
  <field id="bccAddress" type="string" value=""/>
  <field id="subject" type="string" value=""/>
  <field id="attachmentCache" type="component" value="{document-cache-id}"/>
  <field id="indexName" type="string" value="MAIL_ROOT_DOCUMENT_ID"/>
  <field id="aliasName" type="string" value="Dynamic Document Property - DOCUMENT_ID"/>
  <Options/>
</GenericOperationConfig>
```

### SEND Fields

| Field | Type | Description |
|-------|------|-------------|
| `fromAddress` | string | Required. Set to a valid email address — typically the same as the connection's outbound username. An empty string (`value=""`) is rejected at execution with `"" address has wrong format.`. Many providers also reject mismatched From addresses, so a value different from the connection user may bounce or be silently rewritten by the provider. |
| `toAddress` | string | Recipient(s). Multiple addresses separated by `;`. |
| `ccAddress` | string | CC recipient(s), semicolon-separated. |
| `bccAddress` | string | BCC recipient(s), semicolon-separated. |
| `subject` | string | Default subject. |
| `attachmentCache` | component | Document Cache for attachments. Optional — omit when sending without attachments. |
| `indexName` | string | Cache index used to look up attachments at send time. |
| `aliasName` | string | Display label for the cache key DDP. |

SEND does not have `objectTypeId="Mail"` on its `GenericOperationConfig` (the `objectTypeId`/`objectTypeName` attributes are absent on SEND). RECEIVE and MOVE always include them.

SEND has no QueryOptions block, no input parameters, and no response profile (`responseProfileType="none"`). Send produces zero output documents.

### SEND Email Body Format
The input document body must be one of: `text/plain`, `text/html`, `text/xml`. Set `connector.mailsdk.contentType` to advertise the format (defaults to `application/binary` when unset).

The MIME layer normalizes `connector.mailsdk.contentType` on the wire: the media type is uppercased and the underlying JavaMail library appends parameters such as `charset=us-ascii` and `name=<filename>` for attachments. A value sent as `text/plain` arrives at the receive side as `TEXT/PLAIN; charset=us-ascii; name=<filename>`. Downstream consumers should split on `;`, take the leading media-type token, and lowercase for comparison rather than exact-matching the full string.

### SEND with Attachments

The Send operation pulls attachments from `attachmentCache` at execution using a cache **query value** taken from `connector.mailsdk.attachmentCacheKey`. The cache itself is keyed by some other DDP (typically `dynamicdocument.DOCUMENT_ID` by convention, named by the Send operation's `aliasName` field). The cache-key DDP and the `attachmentCacheKey` connector property are distinct but hold the same value at execution — the Send operation resolves attachments by matching `attachmentCacheKey`'s value against the cache index defined by the cache's `DocumentPropertyKeyConfig`.

Pattern:

1. Build each attachment document, set `connector.mailsdk.contentType` and `connector.mailsdk.fileName`, and set the cache-key DDP (e.g. `dynamicdocument.DOCUMENT_ID`) to identify which email the attachment belongs to.
2. Add the attachment document to the Document Cache (Document Cache Add step) — the cache stores it keyed by the property named in its `DocumentPropertyKeyConfig`.
3. On the body document, set `connector.mailsdk.subject` and `connector.mailsdk.attachmentCacheKey` (matching the same value used for the cache-key DDP).
4. Run Send — it pulls every cache entry whose key matches `connector.mailsdk.attachmentCacheKey`.

`connector.mailsdk.attachmentCacheKey` may also be used directly as the cache's key property (eliminating the intermediate `DOCUMENT_ID` DDP) — both work. The split-property pattern is conventional and useful when the same cache is shared across multiple connectors.

There is no hard cap on To/CC/BCC count — for large recipient lists, use a mail-server distribution list and reference it as a single address.

## MOVE Operation

Moves one or more messages between mailbox folders. Folder names default from the operation fields but are typically overridden per-document via the `connector.mailsdk.fromFolder` and `connector.mailsdk.toFolder` connector properties.

```xml
<GenericOperationConfig customOperationType="MOVE" objectTypeId="Mail" objectTypeName="Mail"
    operationType="DELETE"
    requestProfile="{xml-profile-component-id}"
    requestProfileType="xml" responseProfileType="xml">
  <field id="fromFolder" type="string" value=""/>
  <field id="toFolder" type="string" value=""/>
  <field id="folderSizeLimits" type="integer"/>
  <Options>
    <QueryOptions>
      <Fields><ConnectorObject name="Mail"/></Fields>
      <Inputs/>
    </QueryOptions>
  </Options>
</GenericOperationConfig>
```

### MOVE Fields

| Field | Type | Description |
|-------|------|-------------|
| `fromFolder` | string | Source folder. Overridden by the `connector.mailsdk.fromFolder` connector property when set. |
| `toFolder` | string | Destination folder. Overridden by the `connector.mailsdk.toFolder` connector property when set. |
| `folderSizeLimits` | integer | When the move set exceeds this count, the connector batches messages and moves them in chunks. |

### MOVE Server-Side Folder Prerequisite

The destination folder/label must exist on the IMAP server before the Move executes. The connector does not issue an IMAP `CREATE` before `MOVE`. Targeting a missing folder produces a runtime error of the form `[ERROR] <toFolder> does not exist`. Pre-create folders through the mailbox provider's admin interface or a one-time IMAP client. Folder path conventions in `fromFolder`/`toFolder` values vary by IMAP server — consult the server's documentation.

### MOVE Output

The Move shape produces **zero output documents** — the input document is consumed and no flowing document is emitted downstream. Capture any data you need from the email (body, tracked properties) in steps *before* the Move, not after.

### MOVE Request Profile

MOVE requires an XML request profile with this structure:

```xml
<DeleteProfileConfig>
  <id>{message-id}</id>
  <id>{message-id}</id>
  <!-- repeat as needed -->
</DeleteProfileConfig>
```

- Root element: `DeleteProfileConfig` (min/max occurs = 1)
- Child: `id` (minOccurs=0, maxOccurs=unbounded)
- Message IDs come from the upstream Receive operation's tracked property `connector.mailsdk.messageId`.

When the step parameter binds `connector.mailsdk.messageId` to the `id (DeleteProfileConfig/id)` element, the XML profile reference appears as `parameter-profile="{profile-id}"` on the step instead of the `EMBEDDED|genericparameterchooser|` form.

## Document Properties

Set via Set Properties step before the connector step to override operation-level fields or supply per-attachment metadata.

| Property ID | Display Name | Direction | Behavior |
|---|---|---|---|
| `connector.mailsdk.messageId` | Mail (IMAP) - Message ID | Tracked (Receive sets it) | Used by Move to identify messages and by Document Cache lookups. |
| `connector.mailsdk.subject` | Mail (IMAP) - Subject | Set → Send; tracked by Receive | On Send: Set Properties value overrides the operation's `subject` field. On Receive: connector auto-populates this property on each retrieved document with the email's actual subject. |
| `connector.mailsdk.fromAddress` | Mail (IMAP) - From Address | Set → Send; tracked by Receive | On Send: overrides operation's `fromAddress`. On Receive: auto-populated from the email's From header. |
| `connector.mailsdk.toAddress` | Mail (IMAP) - To Address | Set → Send; tracked by Receive | On Send: overrides operation's `toAddress`. On Receive: auto-populated from the email's To header. |
| `connector.mailsdk.ccAddress` | Mail (IMAP) - CC Address | Set → Send | Overrides operation's `ccAddress`. **Not auto-tracked on Receive** — CC headers from received emails are not exposed via this property (a `track` lookup returns no value). |
| `connector.mailsdk.bccAddress` | Mail (IMAP) - BCC Address | Set → Send | Overrides operation's `bccAddress`. **Not auto-tracked on Receive** — BCC headers from received emails are not exposed via this property. |
| `connector.mailsdk.contentType` | Mail (IMAP) - Content-Type | Set per attachment / body | Set before Document Cache Add for each attachment; defaults to `application/binary` when unset. |
| `connector.mailsdk.fileName` | Mail (IMAP) - File Name | Set per attachment | Filename for each attachment; auto-generated random name when unset. |
| `connector.mailsdk.attachmentCacheKey` | Mail (IMAP) - Attachment Cache Key | Set → Send | Cache key identifying which attachments to pull from `attachmentCache`. |
| `connector.mailsdk.fromFolder` | Mail (IMAP) - From Folder | Set → Move | Overrides operation's `fromFolder`. |
| `connector.mailsdk.toFolder` | Mail (IMAP) - To Folder | Set → Move | Overrides operation's `toFolder`. |
| `connector.mailsdk.attachmentsCount` | Mail (IMAP) - Attachments Count | Tracked (Receive only) | Number of attachments on the received email. |
| `connector.mailsdk.receivedDate` | Mail (IMAP) - Received Date | Tracked (Receive only) | Format `dd MMM yyyy HH:mm:ss Z` with title-case month (e.g. `13 May 2026 18:57:39 +0000`). |
