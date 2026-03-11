# Database V2 Connection Component

## Contents
- Component Type
- XML Structure
- Required Fields
- Optional Fields
- Credential Management

## Component Type
- **Type**: `connector-settings`
- **SubType**: `officialboomi-X3979C-dbv2da-prod`

## XML Structure

```xml
<Component componentId="" name="Connection_Name"
           type="connector-settings"
           subType="officialboomi-X3979C-dbv2da-prod"
           folderId="{FOLDER_GUID}">
  <bns:encryptedValues>
    <bns:encryptedValue isSet="true" path="//GenericConnectionConfig/field[@type='password']"/>
    <bns:encryptedValue isSet="true" path="//GenericConnectionConfig/field[@type='customproperties']/customProperties/properties[@encrypted='true']/@value"/>
  </bns:encryptedValues>
  <bns:object>
    <GenericConnectionConfig>
      <field id="url" type="string" value="jdbc:mysql://host:port/database"/>
      <field id="className" type="string" value="com.mysql.jdbc.Driver"/>
      <field id="username" type="string" value="username"/>
      <field id="password" type="password" value="plaintext_or_encrypted"/>
      <field id="CustomProperties" type="customproperties">
        <customProperties>
          <properties encrypted="false" key="propertyName" value="propertyValue"/>
        </customProperties>
      </field>
      <field id="schemaName" type="string" value=""/>
      <field id="connectTimeOut" type="integer"/>
      <field id="readTimeOut" type="integer"/>
      <field id="enablePooling" type="boolean" value="false"/>
      <field id="maximumConnections" type="integer" value=""/>
      <field id="minimumConnections" type="integer" value=""/>
      <field id="maximumIdleTime" type="integer" value=""/>
      <field id="whenExhaustedAction" type="string" value=""/>
      <field id="maximumWaitTime" type="integer" value=""/>
      <field id="testOnBorrow" type="boolean" value=""/>
      <field id="testOnReturn" type="boolean" value=""/>
      <field id="testWhileIdle" type="boolean" value=""/>
      <field id="validationQuery" type="string" value=""/>
    </GenericConnectionConfig>
  </bns:object>
</Component>
```

## Required Fields

### Core Connection
- `url`: Full JDBC connection string (`jdbc:protocol://host:port/database`)
- `className`: JDBC driver class name (database-specific)
- `username`: Database username
- `password`: Plain text for new connections, encrypted hex for pulled components

### Common JDBC Driver Classes
- MySQL: `com.mysql.jdbc.Driver`
- PostgreSQL: `org.postgresql.Driver`
- SQL Server: `com.microsoft.sqlserver.jdbc.SQLServerDriver`
- Oracle: `oracle.jdbc.driver.OracleDriver`

## Optional Fields

### Custom Properties
JDBC-specific connection parameters as key-value pairs:
```xml
<field id="CustomProperties" type="customproperties">
  <customProperties>
    <properties encrypted="true" key="useSSL" value="[encrypted_value]"/>
    <properties encrypted="false" key="serverTimezone" value="UTC"/>
    <properties key="useLegacyDatetimeCode" value="false"/>
  </customProperties>
</field>
```

Properties can be individually encrypted via `encrypted="true"` attribute.

### Connection Pooling
All pooling fields optional, empty values disable:
- `enablePooling`: Enable connection pooling (boolean)
- `maximumConnections`: Pool size limit
- `minimumConnections`: Minimum idle connections
- `maximumIdleTime`: Idle timeout (seconds)
- `whenExhaustedAction`: Behavior when pool exhausted
- `maximumWaitTime`: Wait timeout (milliseconds)
- `testOnBorrow`: Validate connection before use
- `testOnReturn`: Validate connection after use
- `testWhileIdle`: Validate idle connections
- `validationQuery`: SQL query for connection validation

### Timeouts
- `connectTimeOut`: Connection establishment timeout
- `readTimeOut`: Query execution timeout

### Schema
- `schemaName`: Default schema (empty = use database default)

## Credential Management

**New Connections**: Use plain text credentials, inform user to encrypt via GUI for production.

**Pulled Connections**: Preserve encrypted password values exactly as-is (`encrypted="true"` in encryptedValues wrapper).
