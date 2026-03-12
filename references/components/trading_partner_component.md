# Trading Partner Component Reference

## Contents
- Component Type
- Classification: tradingpartner vs mytradingpartner
- Component Structure
- ContactInfo
- PartnerInfo (X12)
- PartnerCommunication
  - Communication Methods
  - AS2 Configuration
- DocumentTypes and Tracked Fields
- Archiving
- API Enforcement Summary
- Common Patterns

## Component Type
`tradingpartner`

Boomi component type string: `type="tradingpartner"` in the `bns:Component` wrapper.

## Classification: tradingpartner vs mytradingpartner

Every Boomi account doing EDI needs exactly one `mytradingpartner` (your company) and one or more `tradingpartner` (external partners). Classification cannot be changed after creation.

| Classification | Purpose | Document Types Tab | Per Account |
|---|---|---|---|
| `mytradingpartner` | Your organization's identity and default settings | **Hidden in GUI** (data stored but tab not rendered) | Exactly one required |
| `tradingpartner` | External partner configuration | **Visible in GUI** | Multiple allowed |

**Critical:** Using `mytradingpartner` when you mean `tradingpartner` hides the Document Types tab in the Boomi GUI with no error. The XML data is stored on the platform, but users cannot see or edit it. Always use `classification="tradingpartner"` for external partners.

## Component Structure

```xml
<?xml version="1.0" encoding="UTF-8"?>
<bns:Component xmlns:bns="http://api.platform.boomi.com/"
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               componentId="" name="Partner Name"
               type="tradingpartner" folderId="{FOLDER_ID}">
  <bns:encryptedValues/>
  <bns:object>
    <TradingPartner classification="tradingpartner" standard="x12">
      <ContactInfo name="Partner Corp" contactname="John Doe"
                   email="john@partner.com" phone="555-0100"
                   address1="123 Main St" city="Anytown"
                   state="PA" postalcode="19000" country="US"/>
      <PartnerInfo>
        <!-- Standard-specific: X12PartnerInfo, EdifactPartnerInfo, etc. -->
      </PartnerInfo>
      <PartnerCommunication>
        <!-- Standard-specific communication config -->
      </PartnerCommunication>
      <DocumentTypes>
        <!-- Document type + tracking field associations -->
      </DocumentTypes>
      <Archiving enableArchiving="false"/>
    </TradingPartner>
  </bns:object>
</bns:Component>
```

### TradingPartner Root Attributes

| Attribute | Type | Required | Purpose |
|---|---|---|---|
| `classification` | enum | Yes | `tradingpartner` or `mytradingpartner` |
| `standard` | enum | Yes | EDI standard (cannot change after creation) |
| `identifier` | string | No | Partner identifier string |
| `organizationId` | string | No | Links to a TradingPartnerOrganization component |

### PartnerDocumentStandard Values

| Value | Description |
|---|---|
| `x12` | ANSI X12 (North America) |
| `edifact` | UN/EDIFACT (International) |
| `hl7` | Health Level 7 (Healthcare) |
| `odette` | ODETTE (European Automotive) |
| `tradacoms` | Tradacoms (UK Retail) |
| `rosettanet` | RosettaNet (Supply Chain) |
| `edicustom` | Custom/proprietary EDI format |
| `edimulti` | Multi-standard partner |

## ContactInfo

Company and contact details for the trading partner. The platform API requires this element to be present (rejects the component if omitted), but all attributes are optional — an empty `<ContactInfo/>` is accepted.

```xml
<ContactInfo name="Acme Corp" contactname="Jane Smith"
             email="jane@acme.com" phone="555-0200" fax="555-0201"
             address1="456 Oak Ave" address2="Suite 100"
             city="Chicago" state="IL" postalcode="60601" country="US"/>
```

| Attribute | Type | Purpose |
|---|---|---|
| `name` | string | Company/organization name |
| `address1` | string | Street address line 1 |
| `address2` | string | Street address line 2 |
| `city` | string | City |
| `state` | string | State/province |
| `postalcode` | string | Postal/ZIP code |
| `country` | string | Country |
| `contactname` | string | Primary contact name |
| `email` | string | Contact email |
| `phone` | string | Contact phone |
| `fax` | string | Contact fax |

## PartnerInfo (X12)

Standard-specific partner settings. The child element depends on the `standard` attribute. This section documents X12 (the most common); other standards follow the same pattern with standard-specific options.

```xml
<PartnerInfo>
  <X12PartnerInfo>
    <X12Options acknowledgementoption="acktranitem"
                filteracknowledgements="true"
                envelopeoption="groupall"
                fileDelimiter="stardelimited"
                segmentchar="tilde"
                rejectDuplicateInterchange="false"
                outboundInterchangeValidation="false"/>
    <X12ControlInfo>
      <ISAControlInfo name="987654321"
                      interchangeid="987654321"
                      interchangeidqual="12"
                      version="00401"
                      standardident="U"
                      securityinfoqual="00"
                      authorinfoqual="00"
                      componentelementseparator=">"
                      testindicator="T"/>
      <GSControlInfo name="PARTNERGS"
                     applicationcode="PARTNERGS"
                     respagencycode="X"
                     gscontrol=""
                     gsVersion="004010"/>
    </X12ControlInfo>
  </X12PartnerInfo>
</PartnerInfo>
```

### X12Options Attributes

| Attribute | Type | Default | Values | Purpose |
|---|---|---|---|---|
| `acknowledgementoption` | enum | - | `donotackitem`, `ackfuncitem`, `acktranitem` | Acknowledgment generation level |
| `filteracknowledgements` | boolean | - | - | Filter inbound 997/TA1 from document flow |
| `envelopeoption` | enum | - | `groupall`, `groupfg`, `groupst` | Outbound envelope grouping |
| `fileDelimiter` | string | - | `stardelimited`, etc. | Element delimiter |
| `fileDelimiterSpecial` | string | - | - | Custom delimiter character |
| `segmentchar` | string | - | `newline`, `tilde`, etc. | Segment terminator |
| `segmentcharSpecial` | string | - | - | Custom segment terminator |
| `allowduplicates` | boolean | - | - | Allow duplicate documents |
| `rejectDuplicateInterchange` | boolean | false | - | Reject duplicate ISA control numbers |
| `outboundInterchangeValidation` | boolean | false | - | Validate outbound interchanges |
| `outboundValidationOption` | enum | - | `filterError`, `failAll` | How to handle outbound validation failures |

### AcknowledgementOption Values

| Value | Description |
|---|---|
| `donotackitem` | Do not generate acknowledgments |
| `ackfuncitem` | Acknowledge functional groups (997 at group level) |
| `acktranitem` | Acknowledge transaction sets (997/999 at transaction level) |

### EnvelopeOption Values

| Value | Description |
|---|---|
| `groupall` | All documents in a single interchange |
| `groupfg` | Group by functional group |
| `groupst` | Each transaction set in its own group |

### ISAControlInfo Attributes

| Attribute | Type | Purpose |
|---|---|---|
| `name` | string | Display name (often matches `interchangeid`) |
| `interchangeid` | string | ISA06/ISA08 Interchange ID |
| `interchangeidqual` | string | ISA05/ISA07 ID Qualifier (e.g., `ZZ`, `12`, `01`) |
| `version` | string | ISA12 Control Version (e.g., `00401`, `00501`) |
| `standardident` | string | ISA11 Standards Identifier (e.g., `U`) |
| `securityinfoqual` | string | ISA03 Security Info Qualifier (e.g., `00`) |
| `securityinfo` | string | ISA04 Security Information |
| `authorinfoqual` | string | ISA01 Authorization Info Qualifier (e.g., `00`) |
| `authorinfo` | string | ISA02 Authorization Information |
| `componentelementseparator` | string | ISA16 Component Element Separator (e.g., `>`) |
| `ackrequested` | string | ISA14 Acknowledgment Requested |
| `testindicator` | string | ISA15 Test/Production Indicator (`T` or `P`) |
| `interchangecontrol` | string | ISA13 Interchange Control Number |

### GSControlInfo Attributes

| Attribute | Type | Purpose |
|---|---|---|
| `name` | string | Display name |
| `applicationcode` | string | GS02/GS03 Application Code |
| `respagencycode` | string | GS07 Responsible Agency Code (e.g., `X`) |
| `gscontrol` | string | GS06 Group Control Number |
| `gsVersion` | string | GS08 Version (e.g., `004010`) |

## PartnerCommunication

Communication configuration varies by method. The structure wraps a `CommunicationOption` per method with nested `CommunicationSettings` (connection) and `ActionObjects` (send/receive actions).

```xml
<PartnerCommunication>
  <X12PartnerCommunication>
    <CommunicationOptions>
      <CommunicationOption method="as2" commOption="custom">
        <CommunicationSettings docType="default">
          <SettingsObject useMyTradingPartnerSettings="true">
            <!-- Connection settings: AS2SendSettings, AS2ServerSettings, FTPSettings, etc. -->
          </SettingsObject>
          <ActionObjects>
            <ActionObject useMyTradingPartnerOptions="false">
              <!-- Action config: AS2PartnerObject, etc. -->
              <DataProcessing sequence="pre"><dataprocess/></DataProcessing>
              <DataProcessing sequence="post"><dataprocess/></DataProcessing>
            </ActionObject>
          </ActionObjects>
        </CommunicationSettings>
      </CommunicationOption>
    </CommunicationOptions>
  </X12PartnerCommunication>
</PartnerCommunication>
```

### Communication Methods

| `method` Value | Protocol | Typical Use |
|---|---|---|
| `as2` | Applicability Statement 2 | Secure B2B with MDN receipts |
| `ftp` | File Transfer Protocol | File-based exchange |
| `sftp` | SSH File Transfer Protocol | Secure file exchange |
| `http` | HTTP/HTTPS | Web-based exchange |
| `disk` | Local/network filesystem | Directory-based exchange |
| `mllp` | Minimum Lower Layer Protocol | Healthcare (HL7) |
| `oftp` | ODETTE File Transfer Protocol 2 | European automotive |

### EdiCommunicationOptionType (`commOption`)

| Value | Description |
|---|---|
| `default` | Use default settings (typical for `mytradingpartner`) |
| `custom` | Custom per-partner settings (typical for `tradingpartner`) |
| `component` | Reference an external component for settings |

### Settings Inheritance

| Attribute | On | Purpose |
|---|---|---|
| `useMyTradingPartnerSettings` | `SettingsObject` | Inherit connection settings from My Company TP |
| `useDefaultPartnerSettings` | `SettingsObject` | Use platform defaults |
| `useMyTradingPartnerOptions` | `ActionObject` | Inherit action options (crypto, etc.) from My Company TP |
| `useDefaultPartnerOptions` | `ActionObject` | Use platform defaults for action options |

When `useMyTradingPartnerSettings="true"`, the SettingsObject can be empty — runtime pulls connection config from the My Company component. Partner-side encryption/signing attributes may show `false` because they are overridden by My Company settings at runtime.

## AS2 Configuration

AS2 is a common B2B communication method. Configuration differs between My Company and partner components.

### My Company (mytradingpartner) — AS2 Server

```xml
<CommunicationOption commOption="default" method="as2">
  <CommunicationSettings docType="default">
    <SettingsObject useMyTradingPartnerSettings="false">
      <AS2ServerSettings useSharedServer="true">
        <defaultPartnerSettings authenticationType="NONE">
          <AuthSettings/>
        </defaultPartnerSettings>
      </AS2ServerSettings>
    </SettingsObject>
    <ActionObjects>
      <ActionObject useMyTradingPartnerOptions="false">
        <AS2PartnerObject>
          <partnerInfo as2Id="Boomi1"
                       signAlias="cert-component-id"
                       encryptAlias="cert-component-id"
                       mdnAlias="cert-component-id"
                       numberOfMessagesToCheckForDuplicates="100000"
                       rejectDuplicateMessageId="false">
            <ListenAuthSettings/>
            <ListenAttachmentSettings/>
          </partnerInfo>
          <defaultPartnerInfo numberOfMessagesToCheckForDuplicates="100000"
                              rejectDuplicateMessageId="false">
            <ListenAuthSettings/>
            <ListenAttachmentSettings/>
          </defaultPartnerInfo>
          <AS2MessageOptions signed="true" encrypted="true"
                             compressed="false" multipleAttachments="false"
                             encryptionAlgorithm="tripledes"
                             signingDigestAlg="SHA256"
                             dataContentType="edix12"
                             attachmentOption="BATCH" maxDocumentCount="1"
                             subject="EDI"/>
          <AS2MDNOptions requestMDN="true" synchronous="sync"
                         signed="true" mdnDigestAlg="SHA256"
                         useSSL="false" useExternalURL="false"/>
        </AS2PartnerObject>
        <DataProcessing sequence="pre"><dataprocess/></DataProcessing>
        <DataProcessing sequence="post"><dataprocess/></DataProcessing>
      </ActionObject>
    </ActionObjects>
  </CommunicationSettings>
</CommunicationOption>
```

**Key patterns:**
- `commOption="default"` — My Company uses default settings
- `AS2ServerSettings` with `useSharedServer="true"` — uses Boomi's managed AS2 infrastructure
- Single certificate component ID wired to `signAlias`, `encryptAlias`, `mdnAlias`
- `defaultPartnerSettings` and `defaultPartnerInfo` provide fallback config for partners
- `DataProcessing` elements with `sequence="pre"` and `sequence="post"` (empty `<dataprocess/>` when unused). The platform API may not require these

### Partner (tradingpartner) — AS2 Send

```xml
<CommunicationOption commOption="custom" method="as2">
  <CommunicationSettings docType="default">
    <SettingsObject useMyTradingPartnerSettings="true">
      <AS2SendSettings authenticationType="NONE"
                       url="https://partner-as2-endpoint.example.com/as2">
        <AuthSettings/>
      </AS2SendSettings>
    </SettingsObject>
    <ActionObjects>
      <ActionObject useMyTradingPartnerOptions="true">
        <AS2PartnerObject>
          <partnerInfo as2Id="PartnerAS2ID"
                       numberOfMessagesToCheckForDuplicates="100000"
                       rejectDuplicateMessageId="false">
            <ListenAuthSettings/>
          </partnerInfo>
          <AS2MessageOptions compressed="false" encrypted="false"
                             encryptionAlgorithm="tripledes"
                             signed="false" signingDigestAlg="SHA1"
                             dataContentType="edix12" subject="EDI"/>
          <AS2MDNOptions requestMDN="true" synchronous="sync"
                         signed="false" mdnDigestAlg="SHA1"
                         useSSL="false"/>
        </AS2PartnerObject>
        <DataProcessing sequence="pre"><dataprocess/></DataProcessing>
        <DataProcessing sequence="post"><dataprocess/></DataProcessing>
      </ActionObject>
    </ActionObjects>
  </CommunicationSettings>
</CommunicationOption>
```

**Key patterns:**
- `commOption="custom"` — partner has its own send settings
- `useMyTradingPartnerSettings="true"` on SettingsObject — inherits server config from My Company, but `AS2SendSettings` provides the partner's endpoint URL
- `useMyTradingPartnerOptions="true"` on ActionObject — inherits crypto options from My Company at runtime
- Partner-side `encrypted="false"` / `signed="false"` when My Company's settings override at runtime
- Certificate aliases omitted on partner side when inheriting from My Company
- No `defaultPartnerInfo` on partner side (present only on My Company component)

### AS2PartnerInfo Attributes (on `partnerInfo` element)

| Attribute | Type | Default | Purpose |
|---|---|---|---|
| `as2Id` | string | - | AS2 identifier for this partner |
| `signAlias` | string | - | Certificate component ID for message signing |
| `encryptAlias` | string | - | Certificate component ID for encryption |
| `mdnAlias` | string | - | Certificate component ID for MDN verification |
| `clientSSLAlias` | string | - | Client SSL certificate ID |
| `basicAuthEnabled` | boolean | false | Enable HTTP basic auth for AS2 |
| `useAllowedIpAddresses` | boolean | false | Restrict by IP address |
| `rejectDuplicateMessageId` | boolean | false | Reject duplicate AS2 message IDs |
| `numberOfMessagesToCheckForDuplicates` | int | 100000 | Duplicate check window size |
| `verifyHostname` | boolean | false | Verify SSL hostname |
| `enabledLegacySMIME` | boolean | - | Legacy S/MIME compatibility |
| `enabledFoldedHeaders` | boolean | - | Enable folded headers |

**Certificate wiring:** A single certificate component can serve all three alias fields (`signAlias`, `encryptAlias`, `mdnAlias`). Upload the partner's `.cer` file as a Boomi certificate component first, then reference its component ID in these attributes.

### AS2MessageOptions Attributes

| Attribute | Type | Default | Purpose |
|---|---|---|---|
| `signed` | boolean | - | Sign outbound messages |
| `encrypted` | boolean | - | Encrypt outbound messages |
| `compressed` | boolean | - | Compress outbound messages |
| `encryptionAlgorithm` | enum | `tripledes` | Encryption algorithm |
| `signingDigestAlg` | string | `SHA1` | Signing digest algorithm |
| `subject` | string | - | AS2 message subject line |
| `dataContentType` | enum | `textplain` | MIME content type |
| `multipleAttachments` | boolean | false | Send multiple attachments |
| `attachmentOption` | enum | `BATCH` | `BATCH` or `DOCUMENT_CACHE` |
| `maxDocumentCount` | int | 1 | Max documents per AS2 message |

### EncryptionAlgorithm Values

| Value | Description |
|---|---|
| `tripledes` | 3DES (168-bit) — most common |
| `des` | DES (56-bit, legacy) |
| `rc2-128` | RC2 128-bit |
| `rc2-64` | RC2 64-bit |
| `rc2-40` | RC2 40-bit |
| `aes-128` | AES 128-bit |
| `aes-192` | AES 192-bit |
| `aes-256` | AES 256-bit |

### AS2DataContentType Values

| Value | MIME Type |
|---|---|
| `textplain` | text/plain |
| `binary` | application/octet-stream (binary) |
| `edifact` | application/edifact |
| `edix12` | application/edi-x12 |
| `applicationxml` | application/xml |
| `textxml` | text/xml |
| `octetstream` | application/octet-stream |

### AS2MDNOptions Attributes

| Attribute | Type | Default | Purpose |
|---|---|---|---|
| `requestMDN` | boolean | false | Request MDN receipt |
| `synchronous` | enum | `sync` | `sync` or `async` MDN delivery |
| `signed` | boolean | false | Request signed MDN |
| `useSSL` | boolean | false | Use SSL for async MDN |
| `useExternalURL` | boolean | false | Use external URL for async MDN |
| `externalURL` | string | - | External MDN URL |
| `failOnNegativeMDN` | boolean | false | Fail process on negative MDN |
| `mdnDigestAlg` | string | `SHA1` | MDN signing digest algorithm |
| `mdnSSLCert` | string | - | SSL cert for MDN |
| `mdnClientSSLCert` | string | - | Client SSL cert for MDN |
| `mdnAuthenticationType` | enum | `NONE` | `NONE` or `BASIC` |

### AS2ServerSettings Attributes (My Company only)

| Attribute | Type | Default | Purpose |
|---|---|---|---|
| `useSharedServer` | boolean | false | Use Boomi's shared AS2 server |
| `host` | string | - | Custom AS2 server hostname |
| `port` | int | 0 | HTTP port |
| `sslPort` | int | 0 | HTTPS port |
| `sslAlias` | string | - | Server SSL certificate ID |
| `externalHost` | string | - | External-facing hostname |
| `logMessages` | boolean | - | Enable message logging |

### AS2SendSettings Attributes (Partner send config)

| Attribute | Type | Default | Purpose |
|---|---|---|---|
| `url` | string | - | Partner's AS2 endpoint URL |
| `sslAlias` | string | - | SSL certificate for connection |
| `clientsslAlias` | string | - | Client SSL certificate |
| `authenticationType` | enum | `NONE` | `NONE` or `BASIC` |
| `verifyHostname` | boolean | false | Verify SSL hostname |

## DocumentTypes and Tracked Fields

Document types associate EDI profiles with the trading partner and configure per-document acknowledgment and tracking options. Only visible in the GUI for `classification="tradingpartner"`.

```xml
<DocumentTypes>
  <DocumentType profileId="edi-profile-component-id" type="850">
    <PartnerDocumentOptions>
      <X12DocumentOptions expectAckForOutbound="true"
                          outboundTSValidation="false"
                          qualifierValidation="true"
                          use999Ack="false"
                          useTA1Ack="false"/>
    </PartnerDocumentOptions>
    <Tracking>
      <TrackedFields>
        <TrackedField fieldId="9993" fieldName="PO Number">
          <sourcevalues>
            <parametervalue key="0" valueType="profile">
              <profileelement elementId="11"
                              elementName="BEG03 (Header/BEG/BEG03)"
                              profileId="edi-profile-component-id"
                              profileType="profile.edi"/>
            </parametervalue>
          </sourcevalues>
        </TrackedField>
      </TrackedFields>
    </Tracking>
  </DocumentType>
</DocumentTypes>
```

### DocumentType Attributes

| Attribute | Type | Purpose |
|---|---|---|
| `profileId` | string | EDI profile component ID — platform validates this references a real component |
| `type` | string | Transaction type code (e.g., `850`, `856`, `810`, `997`) |
| `displayName` | string | Optional display name |

Each `DocumentType` must contain a `<Tracking>` child element (even if just `<Tracking><TrackedFields/></Tracking>`) — the API rejects the component without it.

### X12DocumentOptions Attributes

| Attribute | Type | Default | Purpose |
|---|---|---|---|
| `expectAckForOutbound` | boolean | true | Expect 997 back for outbound documents |
| `outboundTSValidation` | boolean | false | Validate outbound transaction sets |
| `qualifierValidation` | boolean | true | Validate qualifier values |
| `use999Ack` | boolean | false | Use 999 instead of 997 |
| `useTA1Ack` | boolean | false | Use TA1 interchange acknowledgment |

### TrackedField Structure

Tracked fields extract values from EDI documents for B2B visibility in the Boomi dashboard.

| Element/Attribute | Purpose |
|---|---|
| `TrackedField/@fieldId` | Account-scoped field identifier (see note below) |
| `TrackedField/@fieldName` | Display name for the tracked field |
| `parametervalue/@key` | Unique key per tracked field (0, 1, 2...) |
| `parametervalue/@valueType` | Always `profile` for EDI profile extraction |
| `profileelement/@elementId` | Key of the data element in the EDI profile |
| `profileelement/@elementName` | Display name (e.g., `BEG03 (Header/BEG/BEG03)`) |
| `profileelement/@profileId` | Must match the DocumentType's `profileId` |
| `profileelement/@profileType` | Profile type (e.g., `profile.edi`) |

### Tracked Field IDs — Account-Scoped

`fieldId` values are **not universal platform constants**. They are assigned per-account when custom tracked fields are created on the account's **Document Tracking** tab (Setup > Account > Document Tracking). Each account can have up to 20 custom tracked fields.

To discover the tracked field IDs for a given account, query the `CustomTrackedField` API:
```
POST https://api.boomi.com/api/rest/v1/{accountId}/CustomTrackedField/query
```

The API returns objects with `position` (int), `type` (`character`, `datetime`, or `number`), and `label` (display name). No filters are needed — the query returns all fields since the list is capped at 20. The CustomTrackedField API is **query-only** — CREATE, UPDATE, and DELETE are not supported. Fields must be managed in the GUI (Setup > Document Tracking).

Tracked fields configured on Trading Partner DocumentTypes and tracked fields configured on connector operations both draw from the same account-level pool of up to 20 fields.

**Example field IDs:**

| fieldId | fieldName (in that account) | Source (in that account) |
|---|---|---|
| `9993` | PO Number | BEG03 |
| `9994` | Customer | N102 |

These values are account-specific. Other accounts will have different fieldId assignments depending on how their tracked fields were configured.

## Archiving

Optional file-based archiving of inbound/outbound documents.

```xml
<Archiving enableArchiving="true"
           inboundDirectory="/path/to/inbound/archive"
           outboundDirectory="/path/to/outbound/archive"/>
```

| Attribute | Type | Default | Purpose |
|---|---|---|---|
| `enableArchiving` | boolean | false | Enable document archiving |
| `inboundDirectory` | string | - | Directory for inbound document copies |
| `outboundDirectory` | string | - | Directory for outbound document copies |

## API Enforcement Summary

### Required Elements

The API rejects the component if any of these are omitted. They can be empty but must be present, and element ordering is enforced.

| Element | Can Be Empty? | Notes |
|---|---|---|
| `ContactInfo` | Yes | All attributes optional |
| `PartnerInfo` | No | Must contain a standard-specific child (e.g., `X12PartnerInfo`) |
| `PartnerCommunication` | Yes | Completely empty `<PartnerCommunication/>` is accepted |
| `DocumentTypes` | Yes | Empty `<DocumentTypes/>` is accepted |

For X12, the required structural chain within PartnerInfo is:
`X12PartnerInfo` → `X12Options` (can be empty) + `X12ControlInfo` → `ISAControlInfo` (can be empty) + `GSControlInfo` (can be empty)

### Optional Elements

| Element | Notes |
|---|---|
| `Archiving` | Can be omitted entirely |
| `DataProcessing` (within ActionObject) | Can be omitted entirely |

### Attributes

All tested attributes are optional at the API level — the platform accepts a component with zero attributes on `TradingPartner`, `X12Options`, `ISAControlInfo`, `GSControlInfo`, and `CommunicationOption`. The bare minimum X12 trading partner to be accepted by the platform is just empty element shells (but more detail would be required for a usable component).

### Bare Minimum X12 Trading Partner

```xml
<TradingPartner xmlns="">
  <ContactInfo/>
  <PartnerInfo>
    <X12PartnerInfo>
      <X12Options/>
      <X12ControlInfo>
        <ISAControlInfo/>
        <GSControlInfo/>
      </X12ControlInfo>
    </X12PartnerInfo>
  </PartnerInfo>
  <PartnerCommunication/>
  <DocumentTypes/>
</TradingPartner>
```

## Common Patterns

### Pattern: My Company with Shared AS2 Server
Use `useSharedServer="true"` on `AS2ServerSettings` to leverage Boomi's managed AS2 infrastructure. This is the simplest setup — no need to configure host/port.

### Pattern: Partner Inheriting from My Company
Set `useMyTradingPartnerSettings="true"` on the partner's `SettingsObject` to inherit server config. Add `AS2SendSettings` with just the partner's endpoint URL. Set `useMyTradingPartnerOptions="true"` on `ActionObject` for listen actions to inherit crypto settings.

### Pattern: CSV-Driven Partner Provisioning
Trading partners can be created programmatically from CSV/spreadsheet data mapping columns to API attributes. See the PartnerInfo and X12Options sections for the field-to-attribute mapping.