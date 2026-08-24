## Branch & Merge API Behavior Reference

API behaviors for Boomi branch and merge functionality that are not obvious from documentation or OpenAPI specs — the kind of detail that matters when debugging unexpected behavior.

### Contents
- Branch Creation
- Branch Deletion
- Account Default Branch
- Inherited Component Pull Behavior
- Branch Component Visibility
- Component API Branch Mechanics
- PackagedComponent Branch Mechanics
- DeployedPackage Branch Mechanics
- Cross-API Branch Identifier Inconsistency
- MergeRequest API
- Merge Stage Behavior
- OVERRIDE Merge Strategy
- CONFLICT_RESOLVE Merge Strategy
- Non-Branch-Enabled Account Behavior
- Known Spec-to-API Discrepancies

### Branch Creation

- `POST /Branch` accepts `parentId` (base64 branch ID) and `name`.
- Response includes a `ready` field. A newly created branch returns `ready=false` and `stage=CREATING`. The branch transitions to `ready=true` / `stage=NORMAL` within seconds. Component push operations succeed even while the branch is in CREATING state — the `ready` field is informational, not a gate.
- Branch objects include: `id`, `name`, `stage` (`CREATING` or `NORMAL`), `parentName`, `ready`, `deleted`, `createdBy`, `createdDate`.

### Branch Deletion

Deletion is a hybrid model: internally soft, externally hard.

- `DELETE /Branch/{branchId}` returns HTTP 200 with body `{true}`.
- After deletion, the branch is **completely absent** from `Branch/query` results — querying by name or ID returns zero results. The `deleted` field is never `true` in query results.
- `GET /Branch/{id}` for a deleted branch returns HTTP 400: `"Specified branch is already deleted."` — the platform retains knowledge of the branch internally.
- All operations on deleted branches fail with HTTP 400 and explicit error messages:
  - Push: `"Specified branch is already deleted."`
  - Pull (tilde syntax): `"ComponentId ... is invalid"`
  - Merge request (source=deleted): `"Source branch with id: {id} was deleted"`
- No silent failures — deletion is strictly enforced across all operation types.

### Account Default Branch

A branch can be marked as the account default branch, in the UI only. While one is set, **any request that omits a branch identifier resolves to that branch** — create, update, untilded `GET`, and `PackagedComponent` alike. Explicit identifiers always win, so an operation intended for main needs `--branch main`. When the default *is* main the two coincide; main is not otherwise special.

The setting has **no field in the API**: the Branch object defines no `default`, and neither `Branch/query` nor `GET /Branch/{id}` exposes it. It is still readable indirectly, two ways:

- **Any component create, update, or `GET` response reports the branch it resolved to**, in `branchName` and `branchId`. Trust that over the branch requested. `branchId` is the more robust key — branch names can be reused after a delete.
- **`bash <skill-path>/scripts/boomi-branch.sh default`** reports it read-only, by querying `ComponentMetadata` for `currentVersion=true` (see below) and reading the `branchName` those rows carry.

A component the default branch cannot see returns `HTTP 400: "ComponentId {id} is invalid"` — byte-for-byte the same response as a genuinely nonexistent ID, in both the tilde and unqualified forms. Nothing in status, headers, body, or wording separates them, and the message ("Provide a valid componentId") misleads, because the ID is correct and the branch is the problem. To tell the cases apart, run `bash <skill-path>/scripts/boomi-version-history.sh --component-id <id>`: its query is branch-agnostic, so rows returned mean the component exists and the BRANCH column names the branches that can see it; zero rows mean the ID is genuinely unknown. Pull and push run this diagnosis themselves and print a `DIAGNOSIS:` line.

#### `currentVersion` is surface-specific

| Surface | Meaning |
|---|---|
| `ComponentMetadata/query` (version history), and version-addressed reads (`GET` for a specific version) | The current version **on the account default branch**. Moves when the setting changes, with no write to the component. |
| `Component` GET addressed by branch — unqualified or `~{branchId}` | Always `true`. A branch-addressed read returns that branch's head by construction, so the flag carries no information, including on non-default branches. |

On the metadata surface it is neither the highest version nor the most recent write: a higher-numbered, later write on a non-default branch still reports `false`.

- **Zero rows can be current.** When the account default is a branch that cannot see the component, *no* row in its unfiltered history carries `true`, while `numberOfResults` is still non-zero. "Exactly one version is current" is not a safe assumption.
- **`currentVersion=true AND branchName=<X>` is not "branch X's current version."** It returns zero rows for *any* branch that is not the account default, including one that plainly has a current version of its own. To get a branch's latest, filter by `branchName` alone and take the highest `version`.

#### Component responses report; PackagedComponent echoes

- A **component create or update response** reports the branch the write actually landed on.
- A **`PackagedComponent` response** merely echoes the requested `branchName`, even when the named branch cannot see the component. Read `componentVersion` for what was actually packaged.

### Inherited Component Pull Behavior

When pulling a component from a branch via tilde syntax (`GET /Component/{id}~{branchId}`), if the component was inherited (existed on main before the branch, never modified on the branch), the API returns main's version with main's `branchId` — not the requested branch's ID. This is because the branch version IS main's version for inherited components. The local tooling corrects this by updating the `branchId` in the saved file to match the requested branch.

### Branch Component Visibility

Branches inherit the component catalog at creation time. The inheritance model is:

| Operation | Component existed before branch? | Result |
|-----------|----------------------------------|--------|
| UPDATE (push) | Yes | Success — modifies branch copy |
| UPDATE (push) | No (created on main after branch) | HTTP 400: "ComponentId is invalid" |
| CREATE | N/A (net-new) | Success — creates branch-only component |

Key implications:
- A branch's component namespace is **extensible but not retroactively inclusive**. New components can be created directly on a branch, but components created elsewhere after the branch point are invisible.
- Branch-only components (created with `branchId`) do not exist on main. `GET /Component/{id}` (no tilde) returns HTTP 400 when the account default branch cannot see the component.
- For merge conflict detection, the component must exist on BOTH branches with a shared ancestor — meaning the component must exist before the branch is created.

### Component API Branch Mechanics

- `GET /Component/{id}` returns the version on the account default branch (main unless the account sets another).
- `GET /Component/{id}~{branchId}` returns the branch-specific version. The tilde syntax uses the base64 branch ID.
- `POST /Component/{id}` (update) uses `branchId` as an XML attribute on the `<Component>` element. The URL uses the regular component ID (no tilde).
- `POST /Component` (create) also uses `branchId` as an XML attribute.
- The API returns `branchId` and `branchName` on ALL component responses, even on main (`branchName="main"`), even on accounts without branch & merge enabled.

### PackagedComponent Branch Mechanics

- PackagedComponent CREATE uses `branchName` (human-readable name like `my-feature`), **NOT** `branchId` (base64 ID like `Qjo1NjIzNjc`).
- Passing a base64 branch ID in the `branchName` field returns: `"Branch '{id}' is not valid"`.
- Omitting `branchName` targets the account default branch (main unless the account sets another).
- The response always includes `branchName`, but it echoes the request rather than confirming what was packaged — read `componentVersion` (see § Account Default Branch).
- Works identically on non-branch accounts — `branchName: "main"` is accepted or auto-populated.

### DeployedPackage Branch Mechanics

- The `branchName` field on DeployedPackage CREATE is **accepted by the API but silently ignored**. It has no effect on which version is deployed.
- Deploying by `componentId` alone (without a `packageId`) deploys the **globally latest version** across all branches — whichever branch was pushed to most recently (highest version number). It does NOT default to main.
- Safe deployment requires a two-step pattern: create a PackagedComponent (with `branchName` to target the branch), get the `packageId` from the response, then create a DeployedPackage using that `packageId` (not `componentId`).

### Cross-API Branch Identifier Inconsistency

| API | Branch field | Value type |
|-----|-------------|------------|
| Component GET (tilde) | URL `~{branchId}` | Base64 ID |
| Component CREATE/UPDATE | `branchId` attribute | Base64 ID |
| PackagedComponent CREATE | `branchName` | Human-readable name |
| MergeRequest CREATE | `sourceBranchId`, `destinationBranchId` | Base64 ID |
| DeployedPackage CREATE | `branchName` | Ignored |

Translation between ID and name requires `Branch/query` — query by `name` property to get the ID, or by `id` property to get the name.

### MergeRequest API

- CREATE accepts: `sourceBranchId`, `destinationBranchId`, `strategy`, `priorityBranch`. All branch fields are base64 IDs.
- Execute endpoint: `POST /MergeRequest/execute/{id}` with body `{"id": "{id}", "mergeRequestAction": "MERGE"}`.
- Revert uses the same execute endpoint with `"mergeRequestAction": "REVERT"`.
- GET response includes `sourceBranchName` and `destinationBranchName` (human-readable) in addition to the IDs.

### Merge Stage Behavior

- Stage progression: DRAFTING → DRAFTED → REVIEWING → MERGING → MERGED.
- DRAFTED auto-transitions to REVIEWING for OVERRIDE strategy.
- REVERTED is reachable (via merge-revert after MERGED) and persistent — the merge request remains queryable.
- Deleting a merge request removes it entirely — subsequent GETs return HTTP 400, not a `DELETED` stage value.
- FAILED_TO_DRAFT and FAILED_TO_MERGE are observable failure states.

### OVERRIDE Merge Strategy

- Default strategy. Auto-resolves conflicts using `priorityBranch` (default: SOURCE).
- Still progresses through the full DRAFTING → MERGED stage workflow — it's not instant.

### CONFLICT_RESOLVE Merge Strategy

Three-step process: create → resolve → execute.

1. **Create** with `strategy=CONFLICT_RESOLVE`. Progresses through DRAFTING → DRAFTED → REVIEWING (same as OVERRIDE).
2. **Resolve** via `POST /MergeRequest/{id}` (the update endpoint, NOT the execute endpoint). Per-component resolution:
   - `OVERRIDE` — source branch wins
   - `KEEP_DESTINATION` — destination branch preserved, source changes discarded
   - The `@type` field is NOT required in the resolution payload
   - `MergeRequestDetail` must be an array in the payload
3. **Execute** with `POST /MergeRequest/execute/{id}`. Attempting without resolving all conflicts returns HTTP 400: `"Found miss conflict resolution components in MR id ...: [<component GUIDs>]"`.

MergeRequestDetail response fields per component: `componentGuid`, `sourceRevision`, `destinationRevision`, `changeType` (MODIFIED, ADDED, DELETED), `conflict` (boolean), `resolution` (absent until set), `stage`, `modifiedBy`, `modifiedDate`, `createdBy`, `createdDate`.

When no conflicts are detected (e.g., branch created before component existed), CONFLICT_RESOLVE behaves like OVERRIDE — no details are populated, and execute fails with "Select at least one component".

### Non-Branch-Enabled Account Behavior

On accounts without branch & merge enabled:

| Behavior | Result |
|----------|--------|
| Component GET returns branchId/branchName | Yes — always `main` |
| Component UPDATE with branchId | Silently ignored, update applies to main |
| PackagedComponent with branchName | Works (defaults to "main") |
| PackagedComponent without branchName | Works (auto-populates "main") |
| Branch/query | HTTP 400: access denied |
| Branch create | HTTP 400: access denied |
| MergeRequest create | HTTP 400: access denied |

The feature toggle is narrow: it only gates the Branch and MergeRequest endpoints. All other component and packaging operations work identically — they just always operate on main.

### Known Spec-to-API Discrepancies

- **GET /Branch/{id}** — Works via REST API but marked as unsupported in SOAP API documentation. Returns the same Branch object as `Branch/query`. Returns HTTP 400 for invalid or deleted branch IDs.
- **SUBSET merge strategy** — Present in OpenAPI spec enum but rejected by the API: `"Unsupported strategy: SUBSET via API call"`.
- **DELETED merge stage** — Present in OpenAPI spec enum but not an observable API state.
- **REDRAFTING / FAILED_TO_REDRAFT stages** — Present in OpenAPI spec enum but not an observable API state. May require specific conditions.
