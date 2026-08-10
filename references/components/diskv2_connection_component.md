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

> **CRITICAL — default to `work/{purpose}`** (e.g. `work/output`). On cloud runtimes, writes are permitted under `work` and its subdirectories; a path outside it, such as `/tmp`, is denied at execution with a `java.io.FilePermission` error. Local runtimes are bounded only by the runtime's OS user.
>
> Do not read the runtime's type from its name — a runtime named "Atom" can be type `CLOUD`. The type is the `Atom.type` field, values `CLOUD | ATOM | MOLECULE | CLOUDMOLECULE`. When the target type is unknown, use `work/{purpose}`.

**Path formats**: Relative paths resolve against the runtime installation directory. `work` alone and nested subdirectories (`work/a/b/c`) are both valid, and missing subdirectories are created when the operation sets `createDir=true`. On local runtimes, absolute paths (`/data/inbound`, `C:\TEMP`), UNC paths (`\\server\share`), and NFS paths additionally require an OS user that can reach them; on cloud runtimes all three fall outside `work` and are denied.

**Override behavior**: The connection `directory` serves as the default. It can be overridden per-document using the `connector.disk-sdk.directory` document property (set via Set Properties step). When no document property override is set, the connection value is used. If both are empty, the connector returns error `[6]`:
```
[6] the directory cannot be empty. Verify that a directory is specified in the connection or set as a document property.
```
