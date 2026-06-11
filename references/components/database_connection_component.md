# Database (Legacy) Connection Component

## Contents
- Component Type
- Connector Context
- XML Structure
- Connection Attributes
- Driver Types
- Write Options
- Connection Pooling
- Credential Management

## Component Type
- **Type**: `connector-settings`
- **SubType**: `database`
- **Root element**: `<DatabaseConnectionSettings>`

## Connector Context
Settings for the **Database (Legacy) connector**, paired with Database (Legacy) operations (`connector-action`, subType `database`) and Database Profiles (`profile.db` — see `database_profile_component.md`).

This is **not** Database V2. Database V2 (`databasev2_connection_component.md`) uses a `GenericConnectionConfig` with a single JDBC `url` field. The legacy connector instead assembles the URL from discrete `host` / `port` / `dbname` attributes via a driver-specific `urlFormat` template.

## XML Structure

```xml
<?xml version="1.0" encoding="UTF-8"?>
<bns:Component xmlns:bns="http://api.platform.boomi.com/"
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               componentId=""
               name="Connection_Name"
               type="connector-settings"
               subType="database"
               folderId="{FOLDER_GUID}">
  <bns:encryptedValues>
    <bns:encryptedValue isSet="true" path="//DatabaseConnectionSettings/@password"/>
  </bns:encryptedValues>
  <bns:object>
    <DatabaseConnectionSettings
        driverId="sqlserver"
        className="com.microsoft.sqlserver.jdbc.SQLServerDriver"
        host="db.example.com" port="1433" dbname="AdventureWorks2019" additional=""
        username="admin" password="{plaintext_or_encrypted_hex}"
        urlFormat="jdbc:sqlserver://{0}:{1};database={2}{3}"
        isPoolEnabled="false">
      <WriteOptions sqlFilePath="" writeSQLToFile="false"/>
      <AdapterPoolInfo maxActive="-1" maxIdle="-1" minIdle="0" exhaustedAction="1"
                       maxWait="0" maxIdleTime="0" testOnBorrow="false" testOnReturn="false"
                       testIdle="false" timeBetweenRuns="0" numberOfTests="0" validationQuery=""/>
    </DatabaseConnectionSettings>
  </bns:object>
</bns:Component>
```

`WriteOptions` and `AdapterPoolInfo` are both required child elements.

## Connection Attributes
On `<DatabaseConnectionSettings>`:

| Attribute | Notes |
|-----------|-------|
| `driverId` | Selects the packaged driver and its URL template; database-specific (see Driver Types) |
| `className` | Fully-qualified JDBC driver class for the selected database (from the JDBC vendor) |
| `host` | Database server host name or IP |
| `port` | Database port (SQL Server `1433`, Oracle `1521`, Sybase `5000`, Derby `1527`, DB2`50000`, MySQL `3306`) |
| `dbname` | Database name |
| `additional` | Extra URL options as semicolon-delimited name/value pairs (e.g. `;instance=DB01`). Fills the `{3}` slot of `urlFormat` |
| `username` | Database user name |
| `password` | Plain text for new connections; encrypted hex for pulled connections |
| `urlFormat` | Driver-specific JDBC URL template. Placeholders: `{0}`=host, `{1}`=port, `{2}`=dbname, `{3}`=additional. The GUI's read-only "Database URL" is rendered from this template |
| `isPoolEnabled` | Enable connection pooling (boolean, default `false`) |

## Driver Types
The connector ships with a set of JDBC driver types selectable in the GUI: **SQL Server (jTDS)**, **Oracle**, **MySQL** (driver downloaded separately), **SQL Server (Microsoft)**, **SAP HANA**, and **Custom**. Each driver type maps to its own `className` and `urlFormat`; supply the `className` from the JDBC vendor's documentation. Choosing **Custom** lets you specify the Connection URL directly (any JDBC/ODBC-compliant database). Additional JDBC drivers are added via a Custom Library component deployed to the runtime. 

Mapping for SQL Server (Microsoft): `driverId="sqlserver"` → `className="com.microsoft.sqlserver.jdbc.SQLServerDriver"`, `urlFormat="jdbc:sqlserver://{0}:{1};database={2}{3}"`.

## Write Options
`<WriteOptions>` controls SQL-to-file debugging for **Send** actions (ignored by Get):

| Attribute | Notes |
|-----------|-------|
| `writeSQLToFile` | Boolean (default `false`). When `true`, Send-action SQL is **written to a file instead of executed** against the database |
| `sqlFilePath` | Full path and file name for the output (e.g. `C:/Test/sqlout.txt`) |

## Connection Pooling
`<AdapterPoolInfo>` is honored when `isPoolEnabled="true"`. Most integrations do not require pooling.

| Attribute | Default | GUI field |
|-----------|---------|-----------|
| `maxActive` | `-1` | Maximum Connections (`-1` or `0` = unlimited) |
| `maxIdle` | `-1` | — |
| `minIdle` | `0` | Minimum Connections |
| `exhaustedAction` | `1` | When Exhausted Action (wait vs. fail) |
| `maxWait` | `0` | Maximum Wait Time (seconds) |
| `maxIdleTime` | `0` | Maximum Idle Time (seconds; `0` = unlimited) |
| `testOnBorrow` | `false` | Test Connection When Borrowing From Pool |
| `testOnReturn` | `false` | Test Connection When Returning From Pool |
| `testIdle` | `false` | Test Idle Connections |
| `timeBetweenRuns` | `0` | — |
| `numberOfTests` | `0` | — |
| `validationQuery` | (empty) | Validation Query — SQL returning a single row to validate the connection |


