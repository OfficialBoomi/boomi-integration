# Salesforce Connection Component

## Contents
- Type
- GUI Creation Required
- Structure
- URLs
- Usage with the agent
- What the agent Cannot Do

## Type
- **Type**: `connector-settings`
- **SubType**: `salesforce`

## GUI Creation Required
**Salesforce connections MUST be created through Boomi GUI** - OAuth flow and credential encryption require browser-based setup by the user.

## Structure (Reference)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<bns:Component xmlns:bns="http://api.platform.boomi.com/"
           componentId="e4d38332-6d6c-4f0c-ae5b-ec57df2ffdd4"
           name="DealAgent SF Connection"
           subType="salesforce"
           type="connector-settings">
  <bns:encryptedValues>
    <bns:encryptedValue isSet="true" path="//SalesforceSettings/AuthSettings/@password"/>
  </bns:encryptedValues>
  <bns:object>
    <SalesforceSettings maxActiveConnections="10"
                        url="https://login.salesforce.com/services/Soap/u/39.0"
                        version="vx">
      <AuthSettings password="[encrypted]"
                    user="username@company.com"/>
    </SalesforceSettings>
  </bns:object>
</bns:Component>
```

## URLs
- **Production**: `https://login.salesforce.com/services/Soap/u/39.0`
- **Sandbox**: `https://test.salesforce.com/services/Soap/u/39.0`

## Usage with the agent
```
User: "Use my Salesforce connection: <component-id>"
or
User: "Use my Salesforce connection and operation: https://platform.boomi.com/AtomSphere.html#build;accountId=<account-id>;branchName=main;components=<connection-component-id>,<operation-component-id>;componentIdOnFocus=<operation-component-id>"
the agent: References the ID(s) in connector steps
```

## What the agent Cannot Do
- Create new connections (requires GUI OAuth)
- Modify credentials (encrypted via platform)
- Import the connector operation (it is a GUI based wizard that isn't accessible via the API)