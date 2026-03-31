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

## Event Streams Infrastructure Setup

The CLI tool manages Event Streams infrastructure (topics, subscriptions, tokens) — these are platform entities, not connection credentials.

**Infrastructure setup via CLI (safe — no credentials):**
```bash
bash scripts/event-streams-setup.sh create-topic "MyTopic"
bash scripts/event-streams-setup.sh create-subscription "MyTopic" "MySubscription"
bash scripts/event-streams-setup.sh query-topic "MyTopic"
```

**Token provisioning via CLI:** `create-token` provisions a new token. The script omits the token value from the response — only id, name, and permissions are returned. After provisioning, instruct the user to retrieve the token from the Boomi GUI and configure the connection there.
```bash
bash scripts/event-streams-setup.sh create-token "MyToken"
```

**Token queries:** `query-tokens` returns token metadata (id, name, permissions, expiration) without token values.
```bash
bash scripts/event-streams-setup.sh query-tokens
```

**Token Management:**
- Token permissions (`allowConsume`/`allowProduce`) control which operations can use the token
- Tokens expire after 365 days (default) and require recreation
- Same token can be shared across multiple connection components
- Platform encrypts token value automatically on push
- See `references/platform_entities/event_streams.md` for GraphQL API details

## Notes

- The environmentToken is encrypted when pushed to platform
- Connection is shared between Listen, Consume, and Produce operations
- SubType `officialboomi-X3979C-events-prod` identifies this as Event Streams connector