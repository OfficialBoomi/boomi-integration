## Component Type
**Type**: `connector-settings`
**SubType**: `invixoconsultinggroupas-OZI90V-boomia-prod`

## Overview
Boomi for SAP connections define connectivity to SAP systems with Boomi for SAP Core installed. These must be initially created through the GUI with proper SAP credentials.

## XML Structure
```xml
<GenericConnectionConfig>
  <field id="url" type="string" value="https://sap-system:44300"/>
  <field id="followredirects" type="boolean" value="false"/>
  <field id="sapclient" type="string" value="100"/>
  <field id="username" type="string" value="username"/>
  <field id="password" type="password" value="encrypted-value"/>
  <field id="clientprivatecert" type="privatecertificate"/>
  <field id="serverpubliccert" type="publiccertificate"/>
  <field id="preauth" type="boolean" value="false"/>
  <field id="connecttimeout" type="integer" value="30000"/>
  <field id="sockettimeout" type="integer" value="30000"/>
  <field id="urlparameters" type="customproperties">
    <customProperties/>
  </field>
</GenericConnectionConfig>
```

## Fields
- `url`: SAP system endpoint (typically port 44300 for HTTPS)
- `sapclient`: SAP client number
- `username`: SAP user
- `password`: Encrypted SAP password (preserve exact value when pulled)
- `connecttimeout`: Connection timeout in milliseconds
- `sockettimeout`: Socket timeout in milliseconds

## Usage Pattern
1. Pull existing connection to get component ID
2. Reference by ID in process steps
3. Preserve encrypted password values exactly when modifying