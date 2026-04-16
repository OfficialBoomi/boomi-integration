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

**Environment & Setup**:
- **boomi-env-check.sh**: Check which `.env` variables are set without revealing values
- **boomi-folder-create.sh**: Create new folders for project organization. Falls back to account root if `BOOMI_TARGET_FOLDER` is invalid or missing — do not attempt to manually search or resolve parent folders if absent.

**Component Management** (all support `--branch <name_or_id>` for Branch & Merge accounts):
- **boomi-component-create.sh**: Create new components on platform (generates component IDs)
- **boomi-component-push.sh**: Update existing components on platform
- **boomi-component-pull.sh**: Download components from platform to local
- **boomi-component-diff.sh**: Compare two versions of a component (structured JSON diff)
- **boomi-version-history.sh**: List component version history

**Deployment & Testing**:
- **boomi-deploy.sh**: Deploy processes to runtime environments
- **boomi-undeploy.sh**: Remove deployments by ID or by component file (`--by-component`)
- **boomi-test-execute.sh**: Trigger process execution via platform API and return execution ID
- **boomi-wss-test.sh**: Test WSS listener endpoints directly via the shared web server
- **boomi-execution-query.sh**: Query execution records and download logs for any process type (including WSS listeners, manually executed processes, scheduled processes)

**Branch & Merge** (only for accounts with Branch & Merge enabled):
- **boomi-branch.sh**: Branch lifecycle and merge request operations (subcommand-based)

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
bash <skill-path>/scripts/boomi-folder-create.sh "WeatherAPI_Project"
# Returns: folder_abc123def

# STEP 2: Create components (XML must have folderId="folder_abc123def" attribute)
bash <skill-path>/scripts/boomi-component-create.sh active-development/profiles/new-profile.xml
```

**Existing Components (UPDATE workflow)**:
```bash
# Push (design-time update)
bash <skill-path>/scripts/boomi-component-push.sh active-development/processes/my-process.xml

# Pull from platform
bash <skill-path>/scripts/boomi-component-pull.sh --component-id <guid>

# Deploy to runtime (REQUIRED before testing)
bash <skill-path>/scripts/boomi-deploy.sh active-development/processes/my-process.xml --deployment-notes "Optional notes"

# Execute process tests via platform API
bash <skill-path>/scripts/boomi-test-execute.sh --process-id <guid>

# Test WSS listener endpoint via shared web server
bash <skill-path>/scripts/boomi-wss-test.sh --path /ws/simple/createOrder --method POST --data '{"key":"value"}'

# List environments
bash <skill-path>/scripts/boomi-deploy.sh --list-environments

# Undeploy by component file
bash <skill-path>/scripts/boomi-undeploy.sh --by-component active-development/processes/my-process.xml

# Undeploy by deployment ID
bash <skill-path>/scripts/boomi-undeploy.sh <deploymentId>

# Query recent executions (last 3 by default, all filters optional)
bash <skill-path>/scripts/boomi-execution-query.sh [--process-id <guid>] [--status STATUS] [--since ISO8601] [--limit N]

# Download logs for a specific execution
bash <skill-path>/scripts/boomi-execution-query.sh --execution-id <execution-id> --logs
```

**Branch Workflows** (only when user has explicitly opted into Branch & Merge):
```bash
# Branch lifecycle
bash <skill-path>/scripts/boomi-branch.sh list
bash <skill-path>/scripts/boomi-branch.sh create --name feature-x --parent main
bash <skill-path>/scripts/boomi-branch.sh delete --branch feature-x

# Component operations on a branch
bash <skill-path>/scripts/boomi-component-pull.sh --component-id <guid> --branch feature-x
bash <skill-path>/scripts/boomi-component-create.sh active-development/processes/new-process.xml --branch feature-x
bash <skill-path>/scripts/boomi-component-push.sh active-development/processes/my-process.xml  # branch is sticky from XML

# Merge operations
bash <skill-path>/scripts/boomi-branch.sh merge --source feature-x --dest <target-branch>
bash <skill-path>/scripts/boomi-branch.sh merge-status --id <mergeRequestId>   # poll until stage=REVIEWING
bash <skill-path>/scripts/boomi-branch.sh merge-execute --id <mergeRequestId>  # execute the merge

# Deploy warns automatically if component is from a non-main branch
bash <skill-path>/scripts/boomi-deploy.sh active-development/processes/my-process.xml
```

**Branch resolution priority for component tools:** `--branch` flag > `branchId` already in XML > `BOOMI_DEFAULT_BRANCH_ID` env var > main.

**Safety:** Push aborts if sync state records a branch but the XML has no `branchId` (prevents accidental writes to main). Deploy warns when deploying from a non-main branch. All operations echo the target branch.

See `references/guides/branch_merge_guide.md` for full Branch & Merge API reference.

**Version Management Workflows**:
```bash
# List all versions of a component
bash <skill-path>/scripts/boomi-version-history.sh --component-id <guid>

# Pull a specific historical version (saves as MyProcess_v2.xml)
bash <skill-path>/scripts/boomi-component-pull.sh --component-id <guid> --version 2

# Compare two versions
bash <skill-path>/scripts/boomi-component-diff.sh --component-id <guid> --source 1 --target 3
```

See `references/guides/version_management_guide.md` for full version management reference.

**Large Profile Analysis**:
```bash
# Generate searchable field inventory (always outputs to active-development/profiles/distilled_<name>.json)
python3 <skill-path>/scripts/boomi-profile-inspect.py active-development/profiles/large-profile.xml
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
| `processproperty` | `active-development/process-properties/` | Process Property components |

### Configuration System
**Streamlined Configuration**:
- All configuration is sourced directly from the `.env` file — no YAML config layer. Tools `source .env` natively in bash.

### Credential Management in Component XML

**Connection Re-use (Recommended):** Before creating a new connection, consider the discovery workflow: check `preferred_connections.md` → ask user if they have a link or component ID → pull existing connection. This keeps credentials out of the conversation entirely. If no existing connection fits, the user can create one in the Boomi GUI, or provide credentials directly for the agent to create one.

**Preferred pattern — pull from platform**: The user shares a component URL or ID, you pull it down, and use the pre-encrypted credential values as-is.

**User-provided credentials**: If the user provides a credential value directly (e.g., "here's the API key, build this"), use it in component XML. If it appears to be a production secret, remind them of the pull-from-platform option — but respect their choice.

**Pulled components — encryption behavior**:
- If any field has `encrypted="true"` or `type="password"` with encrypted value, preserve the value exactly as-is
- Encrypted hex values may change across pull cycles due to platform-side re-encryption — this is expected, not corruption
- Some connectors (e.g., MCP Server) use `encrypted="true"` on `<properties>` elements within `customproperties` fields instead of `type="password"` — see the relevant connection component reference
- Do not attempt to encrypt or re-encrypt values programmatically — this will produce broken credentials

**Process property passwords**: Prefer leaving `defaultValue` empty for `type="password"` fields and supplying real values via Environment Extensions. If a pulled component has a non-empty password `defaultValue`, let the user know — they may want to migrate to Environment Extensions.

**Avoid reciting credentials** in plans, summaries, or overviews — they could be visible during screen sharing. The user can always ask you to surface them if needed.

**Variable substitution**:
- `{ComponentName}` → **Local XML ONLY** (resolved by agent orchestration during creation)
- CLI tools perform NO variable substitution on XML component files
