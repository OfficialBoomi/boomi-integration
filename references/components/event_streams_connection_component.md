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
bash <skill-path>/scripts/event-streams-setup.sh create-topic "MyTopic"
bash <skill-path>/scripts/event-streams-setup.sh create-subscription "MyTopic" "MySubscription"
bash <skill-path>/scripts/event-streams-setup.sh query-topic "MyTopic"
```

**Token provisioning via CLI:** `create-token` provisions a new token. The response returns only metadata (id, name, permissions) — not the token value.
```bash
bash <skill-path>/scripts/event-streams-setup.sh create-token "MyToken"
```

**Token queries:** `query-tokens` returns token metadata (id, name, permissions, expiration) without token values.
```bash
bash <skill-path>/scripts/event-streams-setup.sh query-tokens
```

**Provisioning a connection:** `provision-connection` creates a complete ES connection on the platform and pulls back the encrypted version. The token value is never printed or written to the workspace.
```bash
bash <skill-path>/scripts/event-streams-setup.sh provision-connection "MyESConnection" "MyToken" "MyFolder"
```
The command builds the connection XML internally, pushes it to the platform (which encrypts the token), then pulls the encrypted component into `active-development/connector-settings/`. Standard workflow: `query-tokens` or `create-token` → `provision-connection` → use the pulled connection in your process.

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