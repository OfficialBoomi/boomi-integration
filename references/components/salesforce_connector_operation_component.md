# Salesforce Connector Operation Component

## Contents
- Type
- GUI Import — Strongly Preferred But Not Absolute
- Structure
- What the agent Can Modify
- Input Elements and Step Parameter Linking
- Operation Types
- Filter Operators
- Sort Configuration
- Usage with the agent
- Troubleshooting: INVALID_FIELD Errors
- Response Profile Tip
- What the agent Cannot Do

## Type
- **Type**: `connector-action`
- **SubType**: `salesforce`

## GUI Import — Strongly Preferred But Not Absolute
**Operations are best initially imported via Boomi GUI** using an active Salesforce connection. The import discovers complete field schemas, parent/child relationships, custom fields, and internal metadata.

**Programmatic creation is possible** when field names and types are already known (e.g., from an existing operation on the same object). Custom fields within a salsforce org will present friction to net new creation efforts so net new creation should only be used as a last resort, after specific discussion with the human operator. Prefer asking the user to provide existing GUI-imported operations.

## Structure (Simplified)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<bns:Component xmlns:bns="http://api.platform.boomi.com/"
           componentId="313c06f1-ee94-459b-95ed-df18639b8c02"
           name="Query Opportunities"
           subType="salesforce"
           type="connector-action">
  <bns:object>
    <Operation>
      <Configuration>
        <SalesforceGetAction objectAction="query"
                             objectName="Opportunity">
          <Options>
            <QueryOptions>
              <Fields>
                <SalesforceObject name="Opportunity">
                  <FieldList>
                    <SalesforceField dataType="character" name="Id"/>
                    <SalesforceField dataType="number" name="Amount"/>
                    <SalesforceField dataType="character" name="StageName"/>
                    <!-- Hundreds more fields imported from Salesforce -->
                  </FieldList>
                  <Filter>
                    <SalesforceFilterLogical logicalOperator="and">
                      <SalesforceFilterExpression
                        expressionField="LastModifiedDate"
                        expressionOperator="equal"
                        key="1"/>
                    </SalesforceFilterLogical>
                  </Filter>
                  <Sorts/>  <!-- Required: GUI white-screens without this, even when empty -->
                </SalesforceObject>
              </Fields>
              <Inputs>
                <Input key="1" name="LastModifiedDate="/>
              </Inputs>
            </QueryOptions>
          </Options>
        </SalesforceGetAction>
      </Configuration>
    </Operation>
  </bns:object>
</bns:Component>
```

**Required element:** `<Sorts/>` must be present inside `<SalesforceObject>` on query operations (after `</Filter>`, before child `<SalesforceObject>` elements). Without it, the Boomi GUI operation editor white-screens with a JavaScript NPE. Runtime execution is unaffected. See `references/guides/boomi_error_reference.md` Issue #28.

## What the agent Can Modify

### Filter Parameters
```xml
<!-- Add new filter -->
<SalesforceFilterExpression dataType="character"
                           expressionField="StageName"
                           expressionOperator="equal"
                           key="2"/>

<!-- Update operator -->
<SalesforceFilterExpression expressionOperator="greaterthan"/>
```

### Field Selection
```xml
<!-- Enable/disable fields -->
<SalesforceField fEnabled="false" name="Description"/>
```

### Query Options
```xml
<QueryOptions batchResults="true" limitSize="200">
```

## Input Elements and Step Parameter Linking

**Critical for step configuration**: Each operation's `<Input>` elements define how process steps link parameters to filters:

```xml
<Inputs>
  <Input key="1" name="AccountID="/>
  <Input key="2" name="StageName="/>
</Inputs>
```

When creating Salesforce connector steps, you must reference these Input attributes:
- Step parameter's `elementToSetId` → matches Input's `key`
- Step parameter's `elementToSetName` → matches Input's `name` (exactly, including trailing `=`)

**Example linkage:**
```xml
<!-- Operation defines: <Input key="1" name="AccountID="/> -->

<!-- Step must include both attributes: -->
<parametervalue elementToSetId="1" elementToSetName="AccountID=" key="0" usesEncryption="false" valueType="track">
  <trackparameter propertyId="dynamicdocument.DDP_ACCOUNT_ID"/>
</parametervalue>
```

Without both attributes, parameters won't display correctly in the Boomi GUI.

## Operation Types

Two XML configuration elements cover all Salesforce operations:

| objectAction | XML Element | Step actionType | Profile Attribute |
|---|---|---|---|
| `query` | `SalesforceGetAction` | `Get` | `responseProfile` |
| `queryAll` | `SalesforceGetAction` + `useQueryAll="true"` on `<QueryOptions>` | `Get` | `responseProfile` |
| `create` | `SalesforceSendAction` | `Send` | `requestProfile` |
| `update` | `SalesforceSendAction` | `Send` | `requestProfile` |
| `delete` | `SalesforceSendAction` | `Send` | `requestProfile` |
| `upsert` | `SalesforceSendAction` | `Send` | `requestProfile` |

`queryAll` is not a separate `objectAction` — it uses `objectAction="query"` with the flag `useQueryAll="true"`.

**Send-type structural differences from Get:**
- Fields wrap inside `<Options><Fields>` (no `<QueryOptions>` wrapper)
- `batchCount` attribute (default `"200"`) controls Salesforce API batch size
- `returnApplicationErrors` attribute controls error handling
- No `<Inputs>` element — parameters come from the document payload
- Upsert operations include `externalIdField` attribute on `<SalesforceObject>`

## Filter Operators

Valid `expressionOperator` values (as stored by the platform):

| `expressionOperator` | SOQL Equivalent |
|---|---|
| `equal` | `=` |
| `notequal` | `!=` / `<>` |
| `greaterthan` | `>` |
| `greaterthanequal` | `>=` |
| `lessthan` | `<` |
| `lessthanequal` | `<=` |
| `like` | `LIKE` |
| `in` | `IN` |
| `notin` | `NOT IN` |
| `includes` | `INCLUDES` |
| `excludes` | `EXCLUDES` |

These are the concatenated camelCase values, not space-separated display names. Using display-name strings (e.g., `"greater than"` instead of `"greaterthan"`) will cause a `NullPointerException` at runtime.

## Usage with the agent
```
User: "Use my Query Opportunities operation (313c06f1-ee94-459b-95ed-df18639b8c02) 
       but filter for deals over $100k"
or
User: "Use my Salesforce connection and operation: https://platform.boomi.com/AtomSphere.html#build;accountId=<account-id>;branchName=main;components=<connection-component-id>,<operation-component-id>;componentIdOnFocus=<operation-component-id> and modify X"

the agent:
1. Pulls operation component
2. Adds Amount > 100000 filter
3. Updates Input parameters
4. Pushes modified operation
```

## Troubleshooting: INVALID_FIELD Errors

When a Salesforce query returns `INVALID_FIELD` (e.g., a custom field was deleted from the Salesforce org), the fix is likely in the **operation**, not the profile:

- **`fEnabled="false"`** on a `SalesforceField` removes that field from the generated SOQL query
- The profile likely does not need to be modified — the operation controls what fields appear in the query
- Re-importing the profile is a heavier fix that can involve some re-work and might **break downstream maps and Set Properties references**

**Preferred fix** — disable the stale field in the operation:
```xml
<!-- Before: field included in SOQL query -->
<SalesforceField dataType="character" name="Alyce_Gift_Status__c"/>

<!-- After: field excluded from SOQL query, no profile changes needed -->
<SalesforceField dataType="character" fEnabled="false" name="Alyce_Gift_Status__c"/>
```

**Key distinction**: The operation's `fEnabled` attribute controls the SOQL query. The profile defines the schema shape. Toggling `fEnabled="false"` is sufficient to resolve INVALID_FIELD errors without touching profiles or maps.

## Sort Configuration

Sort results by adding `<SalesforceSortField>` elements to the `<Sorts>` block inside `<QueryOptions>`:

```xml
<Sorts>
  <SalesforceSortField fieldName="CreatedDate" sortOrder="DESC" sortNulls="LAST"/>
</Sorts>
```

- `fieldName` — Salesforce field name
- `sortOrder` — `ASC` or `DESC`
- `sortNulls` — `FIRST` or `LAST`

## Response Profile Tip

When understanding and manipulating XML profiles for Salesforce query responses, the profile root element must be the SF object name (e.g., `OpportunityHistory`), not a wrapper like `queryResult`. Each document output by the connector IS the object — using a wrapper root will cause all element references to resolve as null.

## What the agent Cannot Do
- Change object type (Opportunity → Account)
- Access Salesforce metadata API directly