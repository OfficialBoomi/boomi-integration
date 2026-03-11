## Contents
- CLI Tools
- XML Format Requirements for New Components
- Sync State Structure
- Error Recovery Strategies
- Component Type to Folder Mapping
- Configuration System
- Credential Management in Component XML

### CLI Tools

Specialized bash tools handle different aspects of the development lifecycle. All tools require `curl` and `jq`, and source credentials directly from `.env` — no Python dependencies or virtual environments needed.

**Folder Management**:
- **boomi-folder-create.sh**: Create new folders for project organization

**Component Management**:
- **boomi-component-create.sh**: Create new components on platform (generates component IDs)
- **boomi-component-push.sh**: Update existing components on platform
- **boomi-component-pull.sh**: Download components from platform to local

**Deployment & Testing**:
- **boomi-deploy.sh**: Deploy processes to runtime environments
- **boomi-undeploy.sh**: Remove deployments by ID or by component file (`--by-component`)
- **boomi-test-execute.sh**: Trigger process execution via API and return execution ID
- **boomi-execution-query.sh**: Query execution records and download logs for any process type (including WSS listeners, manually executed processes, scheduled processes)

**Profile Analysis**:
- **boomi-profile-inspect.py**: Extract field metadata from large profiles (XML, EDI, Flat File) — Python stdlib only, no pip deps

**Tool Selection Guide & Decision Tree**:

**Basic Decision Logic**:
- **No sync state file exists** → Use CREATE tools
- **Sync state file exists** → Use UPDATE (push/pull) tools
- **Building from scratch** → The agent orchestrates individual component creation
- **Modifying existing** → Use individual push/pull tools

**New Components (CREATE workflow)**:
```bash
# STEP 1: Create dedicated project folder (run from workspace)
bash scripts/boomi-folder-create.sh "WeatherAPI_Project"
# Returns: folder_abc123def

# STEP 2: Create components (XML must have folderId="folder_abc123def" attribute)
bash scripts/boomi-component-create.sh active-development/profiles/new-profile.xml
```

**Existing Components (UPDATE workflow)**:
```bash
# Push (design-time update)
bash scripts/boomi-component-push.sh active-development/processes/my-process.xml

# Pull from platform
bash scripts/boomi-component-pull.sh --component-id <guid>

# Deploy to runtime (REQUIRED before testing)
bash scripts/boomi-deploy.sh active-development/processes/my-process.xml --deployment-notes "Optional notes"

# Execute process tests (trigger execution)
bash scripts/boomi-test-execute.sh --process-id <guid>

# List environments
bash scripts/boomi-deploy.sh --list-environments

# Undeploy by component file
bash scripts/boomi-undeploy.sh --by-component active-development/processes/my-process.xml

# Undeploy by deployment ID
bash scripts/boomi-undeploy.sh <deploymentId>

# Query recent executions (last 3 by default, all filters optional)
bash scripts/boomi-execution-query.sh [--process-id <guid>] [--status STATUS] [--since ISO8601] [--limit N]

# Download logs for a specific execution
bash scripts/boomi-execution-query.sh --execution-id <execution-id> --logs
```

**Large Profile Analysis**:
```bash
# Generate searchable field inventory (always outputs to active-development/profiles/distilled_<name>.json)
python3 scripts/boomi-profile-inspect.py active-development/profiles/large-profile.xml
```

**When to use**: Run this tool immediately when attempting to Read a profile file and encountering a "file too large" error. The tool extracts element IDs with full hierarchical paths, enabling disambiguation of duplicate field names common in WSDL/SOAP-derived profiles (e.g., 60+ "First_Name" fields in different contexts).

**Supported profile types**: XML, EDI, and Flat File profiles. EDI output includes `purpose` field with semantic context.

**Workflow after running**:
1. Tool outputs pretty-printed JSON to `active-development/profiles/distilled_<ProfileName>.json`
2. Use Read or Grep to search the distilled file for field keys, paths, and types
3. If field comments are needed, grep the original profile by the field's `key` attribute

All tools use exception-based error handling and essential functionality only.

### XML Format Requirements for New Components

**Required Structure for CREATE operations**:
```xml
<bns:Component componentId=""
               name="Component_Name"
               type="component-type"
               folderId="{FOLDER_GUID}">
  <bns:encryptedValues/>
  <bns:object>
    <!-- Component-specific configuration -->
  </bns:object>
</bns:Component>
```

**Common CREATE Mistakes**:
- Including non-empty `componentId` (causes validation errors - platform generates this)
- Missing `bns:encryptedValues` element (required but can be empty)
- WRONG: `folderId=""` (empty causes root folder placement)
- WRONG: `folderId="{FOLDER_GUID}"` (literal placeholder text fails)
- CORRECT: `folderId="folder_abc123def"` (actual resolved GUID)

**Common Schema Errors**:
- Message step: Using `combineDocuments`/`messageType` attributes (don't exist)
- Stop step: Using `<stopaction/>` instead of `<stop continue="true"/>`
- Connector step: Wrong `connectionId`/`operationId` format (must be GUIDs)
- Set Properties: Using `shapetype="setproperties"` instead of `shapetype="documentproperties"`

### Sync State Structure

Components track synchronization state in `.sync-state/{folder}__{component-name}.json`. The filename is derived from the component's path relative to `active-development/` (e.g., `processes/My Process.xml` → `.sync-state/processes__My Process.json`). This prevents name collisions when different component types share the same name (e.g., a process and its operation both named "WSS Fetch EOQ Opps").

```json
{
  "component_id": "generated-guid-from-platform",
  "file_path": "path/to/local/file.xml",
  "content_hash": "sha256-hash",
  "last_sync": "2025-09-24T12:00:00Z"
}
```

**Backward compatibility**: Tools check for the new path-based state file first, then fall back to legacy stem-only files (`{component-name}.json`). Existing projects continue to work without migration.

**Sync state presence drives tool selection**: No file → CREATE, file exists → UPDATE

### Error Recovery Strategies

**Push failures**:
- Read error message for specific XML validation issues
- Fix component XML structure
- Retry push operation

**Reference resolution failures**:
- Verify component ID exists in `.sync-state/` directory
- Check that referenced component was successfully created
- Confirm GUID matches between reference and sync state

**Schema validation failures**:
- Compare XML structure against examples in `references/components/` or `references/steps/`
- Check shapetype matches step type (common mismatch: Set Properties)
- Verify all required attributes present

**Folder placement issues**:
- Check GUI immediately after creation to confirm proper folder placement
- If component landed in root: Verify `BOOMI_TARGET_FOLDER` environment variable
- Delete and recreate component with correct folder ID if misplaced

### Component Type to Folder Mapping
Maps Boomi API component types to local folders. Used by `boomi-component-pull.sh` for automatic routing.

| Boomi API Component Type | Local Folder | Description |
|-------------------------|--------------|-------------|
| `process` | `active-development/processes/` | Integration processes |
| `transform.map` | `active-development/maps/` | Data transformation maps |
| `profile.*` | `active-development/profiles/` | Data structure profiles (profile.json, profile.xml, profile.db, etc.) |
| `connector-settings` | `active-development/connections/` | Connection definitions |
| `connector-action` | `active-development/operations/` | Connector operation definitions |
| `documentcache` | `active-development/document-caches/` | Document cache definitions |
| `script` | `active-development/scripts/` | Groovy/JavaScript scripts |

### Configuration System
**Streamlined Configuration**:
- All configuration is sourced directly from the `.env` file — no YAML config layer. Tools `source .env` natively in bash.

### Credential Management in Component XML
Boomi components may contain various credential types: API keys, basic auth passwords, OAuth tokens, database credentials, etc.

**Pulled Components**: If any field has `encrypted="true"` or `type="password"` with encrypted value, preserve the value exactly as-is. Never modify encrypted values.

**New Components**: Read credentials from `.env` and use actual plain text values. Inform user to encrypt via GUI for production. If `.env` lacks needed credentials, use demo values and inform the user.

**Best Practice**: It is generally preferable for users to pre-configure their sensitive keys within the platform, and we would simply reference them pre-encrypted via component pull. Most keys in .env would be demo or test. All the same - *important* do not recite any keys or sensitive data from .env in any plan or overview that you're presenting to the user, because in a demo or screen-sharing situation those could be inadvertently revealed to others.

**Never**: Attempt to encrypt values programmatically - this will produce broken credentials.

**Reference Context Quick Guide - Variable Substitution Support**:
- `{ComponentName}` → **Local XML ONLY** (resolved by agent orchestration during creation)
- **Actual credential values** → **XML components REQUIRED** (no substitution - sent as-is to platform)

**Critical Distinction**: CLI tools perform NO variable substitution on XML component files. Use real values.