# MFT Connection Component

## Contents
- Overview
- Component Structure
- Connection Fields
- Credential Sources
- Password Handling

## Overview

MFT (Managed File Transfer) connection components store credentials for Boomi's Thru-powered MFT platform. Connections use the partner connector pattern with `GenericConnectionConfig`.

**Connector Type**: `thru-8SHH0W-thrumf-technology`

## Component Structure

```xml
<?xml version="1.0" encoding="UTF-8"?>
<bns:Component xmlns:bns="http://api.platform.boomi.com/"
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               componentId=""
               name="{connection-name}"
               type="connector-settings"
               subType="thru-8SHH0W-thrumf-technology"
               folderId="{folder-id}">
  <bns:encryptedValues/>
  <bns:object>
    <GenericConnectionConfig>
      <field id="publicTransCode" type="string" value="{transport-code}"/>
      <field id="apiUrl" type="string" value="{api-url}"/>
      <field id="siteUrl" type="string" value="{site-url}"/>
      <field id="siteKey" type="string" value="{site-key}"/>
      <field id="flowSecret" type="password" value="{flow-secret}"/>
    </GenericConnectionConfig>
  </bns:object>
</bns:Component>
```

## Connection Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `publicTransCode` | string | No | Transport code identifier (can be left empty) |
| `apiUrl` | string | Yes | MFT API URL with protocol (e.g., "https://us-api.thruinc.com") |
| `siteUrl` | string | No | Site URL without protocol (can be left empty) |
| `siteKey` | string | Yes | Site key identifier |
| `flowSecret` | password | No | Connection-level flowSecret is ignored; set flowSecret in each operation instead |

## Credential Sources

Obtain connection credentials from the MFT portal:
1. Navigate to Flow Studio in your MFT instance
2. Create or select a Flow Endpoint of type "Integration Connector"
3. View the connection details in the Connections tab
4. Copy the API URL, Site URL, Site Key, and Flow Secret

## Password Handling

**New connections**: Pass plaintext for `flowSecret`. Boomi auto-encrypts on push.

**Pulled connections**: Preserve `<bns:encryptedValues>` and encrypted field values exactly as-is.
