# Disk V2 Connection Component

## Contents
- Overview
- Component Structure
- Connection Fields
- Directory Configuration

## Overview

Disk V2 connection components configure file system access for the Disk V2 connector. Connections use the `GenericConnectionConfig` pattern.

**Connector Type**: `disk-sdk`

## Component Structure

```xml
<?xml version="1.0" encoding="UTF-8"?>
<bns:Component xmlns:bns="http://api.platform.boomi.com/"
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               componentId=""
               name="{connection-name}"
               type="connector-settings"
               subType="disk-sdk"
               folderId="{folder-id}">
  <bns:encryptedValues/>
  <bns:object>
    <GenericConnectionConfig>
      <field id="directory" type="string" value="{directory-path}"/>
      <field id="pollingInterval" type="integer" value="10000"/>
    </GenericConnectionConfig>
  </bns:object>
</bns:Component>
```

## Connection Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `directory` | string | Conditional | Base directory for file operations. Required unless overridden per-document via `connector.disk-sdk.directory` document property. |
| `pollingInterval` | integer | No | Milliseconds between polls for the Listen operation. Default: `10000` (10 seconds). |

## Directory Configuration

Runtimes (referred to as "atoms" in the platform API and installation paths) have different directory access depending on type:

**Cloud runtimes**: Only `work` and `temp` directories are writable. Subdirectories within these are allowed.

**Local runtimes**: Any directory accessible to the runtime's OS user.

**Path formats**: Local paths (`/tmp`, `C:\TEMP`), UNC paths (`\\server\share`), or NFS paths. Can be absolute or relative to the runtime installation directory.

**Override behavior**: The connection `directory` serves as the default. It can be overridden per-document using the `connector.disk-sdk.directory` document property (set via Set Properties step). When no document property override is set, the connection value is used. If both are empty, the connector returns error `[6]`:
```
[6] the directory cannot be empty. Verify that a directory is specified in the connection or set as a document property.
```
