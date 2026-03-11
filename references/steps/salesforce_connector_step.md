# Salesforce Connector Step

## Contents
- Purpose
- Critical Prerequisite
- Action Types
- Critical Parameter-to-Filter Linking
- Step Structure
- Specific Parameter Patterns
- Component Dependencies
- Common Patterns
- Important Notes

## Purpose
Salesforce connector steps query and manipulate Salesforce objects using SOQL queries and API operations. Unlike technology connectors, Salesforce connectors require GUI setup for OAuth and metadata discovery. The user should provide you existing Salesforce connections and operations to work with.

**Use when:**
- Querying Salesforce objects (Accounts, Opportunities, Contacts, custom objects)
- Creating, updating, or deleting Salesforce records
- Working with CRM data in integrations
- Synchronizing data between Salesforce and other systems

## Critical Prerequisite
**Salesforce connectors require GUI import first**. The user must:
1. Create Salesforce connection in Boomi GUI
2. Import operations via GUI (discovers schemas from live Salesforce)
3. Provide component IDs to the agent (typically as a URL that may include one or multiple component IDs)

**Important**: Boomi Salesforce connector operations will always import XML profiles. If you are provided an existing operation, it should contain an XML profile and you should use that in any processes that need to access or populate Salesforce data.

## Action Types
**CRITICAL**: Salesforce connectors only support two actionType values:
- `actionType="Get"` - For query/retrieve operations (SELECT, Query, Retrieve)
- `actionType="Send"` - For write operations (Create, Update, Delete, Upsert)

These are Boomi-specific values, NOT Salesforce API methods. The actual SOQL/API operation is determined by the imported operation configuration, not the actionType.

## Critical: Parameter-to-Filter Linking

**MANDATORY**: When passing parameters to Salesforce operations, you MUST include both `elementToSetId` AND `elementToSetName` to properly link parameters to operation filters:

```xml
<!-- WRONG: Missing elementToSetName - parameter won't display in GUI -->
<parametervalue elementToSetId="1" key="0" valueType="track">
  <trackparameter propertyId="dynamicdocument.DDP_ACCOUNT_ID"/>
</parametervalue>

<!-- CORRECT: Both linking attributes present -->
<parametervalue elementToSetId="1" elementToSetName="AccountID=" key="0" usesEncryption="false" valueType="track">
  <trackparameter propertyId="dynamicdocument.DDP_ACCOUNT_ID"/>
</parametervalue>
```

**Required linking attributes:**
- `elementToSetId` - Must match the operation filter's `key` value (operation has `<Input key="1".../>`)
- `elementToSetName` - Must match the operation input's `name` value exactly (operation has `<Input name="AccountID=".../>`)
- `usesEncryption` - Set to "false" for standard parameters
- `key` - 0-based parameter position (differs from Message step's 1-based keys)

**Critical**: Without `elementToSetName`, parameters will not display correctly in the Boomi GUI parameter selector and may cause silent configuration failures.

**The linking mechanism:**
- Operation defines: `<Input key="1" name="AccountID="/>`
- Step parameter must match both: `elementToSetId="1"` and `elementToSetName="AccountID="`
- The `elementToSetName` value must match the Input's `name` attribute character-for-character (including trailing `=` if present)
- Without proper linking, the parameter is silently ignored or displays incorrectly in GUI

**Example: Query with multiple filters**
```xml
<!-- Operation has: <Input key="1" name="OpportunityID="/> and <Input key="2" name="StageName="/> -->
<parameters>
  <parametervalue elementToSetId="1" elementToSetName="OpportunityID=" key="0" usesEncryption="false" valueType="track">
    <trackparameter propertyId="dynamicdocument.DDP_RECORD_ID"/>
  </parametervalue>
  <parametervalue elementToSetId="2" elementToSetName="StageName=" key="1" usesEncryption="false" valueType="static">
    <staticparameter staticproperty="Closed Won"/>
  </parametervalue>
</parameters>
```

## Step Structure
```xml
<shape shapetype="connectoraction" name="shape2" x="288.0" y="96.0">
  <configuration>
    <connectoraction connectionId="[existing-connection-guid]"
                     operationId="[existing-operation-guid]"
                     connectorType="salesforce"
                     actionType="Get" <!-- ONLY "Get" or "Send" are valid -->
                     parameter-profile="EMBEDDED|salesforceparameterchooser|[operation-id]">
      <parameters>
        <!-- Operation has: <Input key="1" name="LastModifiedDate="/> -->
        <parametervalue elementToSetId="1" elementToSetName="LastModifiedDate=" key="0" usesEncryption="false" valueType="static">
          <staticparameter staticproperty="LAST_N_DAYS:30"/>
        </parametervalue>
      </parameters>
      <dynamicProperties/>
    </connectoraction>
  </configuration>
  <dragpoints>
    <dragpoint name="shape2.dragpoint1" toShape="shape3" x="464.0" y="104.0"/>
  </dragpoints>
</shape>
```

*CRITICAL*: Remember that a connector step with parameters (as in the above sample) will clear ALL documents and dynamic properties. The above sample would lose DDPs from earlier in the process. Those would need to be re-set post query, or an alternate design using DPPs would be valid. See references/guides/boomi_error_reference.md Issue #4 for detailed patterns and workarounds.

## Specific Parameter Patterns

### Date Filters
```xml
<staticparameter staticproperty="LAST_N_DAYS:30"/>
<staticparameter staticproperty="TODAY"/>
<staticparameter staticproperty="YESTERDAY"/>
<staticparameter staticproperty="THIS_MONTH"/>
<staticparameter staticproperty="LAST_MONTH"/>
```

### Dynamic Parameters
```xml
<!-- From document property - operation has: <Input key="1" name="LastModifiedDate="/> -->
<parametervalue elementToSetId="1" elementToSetName="LastModifiedDate=" key="0" usesEncryption="false" valueType="track">
  <trackparameter propertyId="dynamicdocument.DDP_DAYS_BACK"/>
</parametervalue>
```

## Mock Pattern (Before GUI Import)

When components don't exist yet:
```xml
<!-- Disconnected placeholder -->
<shape shapetype="connectoraction" userlabel="[PLACEHOLDER: Query Opportunities]" x="288.0" y="96.0">
  <configuration>
    <connectoraction connectorType="salesforce"/>
  </configuration>
  <!-- NO dragpoints -->
</shape>

<!-- Mock data -->
<shape shapetype="message" userlabel="Mock SF Response" x="480.0" y="96.0">
  <configuration>
    <message combined="false">
      <msgTxt>'[{"Id":"006XX000","Name":"Acme Deal","Amount":50000,"StageName":"Negotiation"}]'</msgTxt>
    </message>
  </configuration>
  <dragpoints>
    <dragpoint name="shape3.dragpoint1" toShape="shape4" x="608.0" y="104.0"/>
  </dragpoints>
</shape>
```

## What the Agent Can/Cannot Do

**CAN**:
- Reference existing connections/operations by ID
- Set actionType to "Get" (for queries) or "Send" (for writes)
- Modify filter parameters (dates, stages, amounts)
- Switch static to dynamic parameters
- Create placeholder steps with mock data

**CANNOT**:
- Import Salesforce objects (requires GUI)
- Create connections (requires OAuth via GUI)
- Generate operation schemas (requires GUI metadata discovery)