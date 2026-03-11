# Event Streams Connection Component

Component type: `connector-settings`
SubType: `officialboomi-X3979C-events-prod`

## Contents
- XML Structure
- Configuration Fields
- Environment Token Acquisition
- Notes

## XML Structure

```xml
<bns:Component componentId=""
               name="[Connection_Name]"
               type="connector-settings"
               subType="officialboomi-X3979C-events-prod"
               folderId="[folder_guid]">
  <bns:encryptedValues>
    <bns:encryptedValue isSet="true" path="//GenericConnectionConfig/field[@type='password']"/>
  </bns:encryptedValues>
  <bns:object>
    <GenericConnectionConfig>
      <field id="connectionType" type="string" value="Yes"/>
      <field id="environmentToken" type="password" value="[encrypted_token]"/>
    </GenericConnectionConfig>
  </bns:object>
</bns:Component>
```

## Configuration Fields

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| connectionType | string | Yes | Value: "Yes" |
| environmentToken | password | Yes | Encrypted environment-specific token from Event Streams |

## Environment Token Acquisition

**Using CLI Tool (Recommended):**
```bash
# Query existing tokens
bash scripts/event-streams-setup.sh query-tokens

# Create new token
bash scripts/event-streams-setup.sh create-token "MyToken"
```

The tool returns the token value in the `data` field. Use this value in the connection component's `environmentToken` field.

**Token Management:**
- Token permissions (`allowConsume`/`allowProduce`) control which operations can use the token
- Tokens expire after 365 days (default) and require recreation
- Same token can be shared across multiple connection components
- Platform encrypts token value automatically on push
- GraphQL API available for manual token creation and management (see references/platform_entities/event_streams.md)

## Notes

- The environmentToken is encrypted when pushed to platform
- Connection is shared between Listen, Consume, and Produce operations
- SubType `officialboomi-X3979C-events-prod` identifies this as Event Streams connector