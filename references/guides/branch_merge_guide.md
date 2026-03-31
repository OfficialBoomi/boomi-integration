## Branch and Merge

**Opt-in feature.** Branch and merge is not enabled on all accounts and not all users choose to use it. Do not use branch-related tools or suggest branching workflows unless the user has explicitly indicated they work with branches (via session instructions, CLAUDE.md configuration, or direct request).

On accounts without branch and merge enabled, branch and merge commands return access denied errors. All other tools (pull, push, create, package, deploy) work normally — they always operate on main.

This guide documents how branch & merge works — not when or how to apply it. Users define their own branching strategy, merge policies, and CI/CD integration via their project instructions.

**Always use the CLI tools** (`boomi-branch.sh`, `boomi-component-pull.sh`, etc.) for all branch operations. Do not construct raw API calls or curl commands. If you encounter an edge case not covered by the tools, `references/guides/branch_merge_api_behavior.md` documents the underlying API semantics as a last resort — but the first response should be to check whether an existing tool flag or helper function already handles the situation.

## Contents
- Branch Lifecycle
- Branch-Aware Component Operations
- Branch-Aware Deployment
- Merge Requests
- Safety Model

## Branch Lifecycle

All branch operations use `boomi-branch.sh`.

**Create** a branch from a parent (typically main):
```
bash scripts/boomi-branch.sh create --name my-feature --parent main
```

A newly created branch briefly shows `ready=false` / `stage=CREATING` before transitioning to `ready=true` / `stage=NORMAL` within seconds. Component operations succeed even during the CREATING state.

**Branch name sanitization:** The platform normalizes branch names — slashes and other special characters are replaced with hyphens (e.g. `feature/my-work` becomes `feature-my-work`). The name returned by the API is the canonical form.

**List** all branches:
```
bash scripts/boomi-branch.sh list
```

**Delete** a branch:
```
bash scripts/boomi-branch.sh delete --branch my-feature
```

All commands accept branch names or base64 branch IDs.

## Branch-Aware Component Operations

All component tools accept a `--branch` flag (name or ID). Without it, operations target main.

```
bash scripts/boomi-component-pull.sh --component-id {id} --branch my-feature
bash scripts/boomi-component-push.sh path/to/component.xml --branch my-feature
bash scripts/boomi-component-create.sh path/to/component.xml --branch my-feature
```

Operations on a branch do not affect the main branch version.

### Branch Resolution Priority

When multiple branch signals are present, tools resolve in this order:

`--branch` flag > `branchId` in XML > `BOOMI_DEFAULT_BRANCH_ID` env var > main

### Inherited Components and Branch Pull

When pulling a component that was inherited by a branch (existed on main before the branch was created, never modified on the branch), the platform returns main's version — including main's `branchId`. The pull tool automatically updates the local file's `branchId` to match the branch you requested, so that subsequent pushes target the correct branch. The push tool also verifies that the XML's `branchId` matches sync state and aborts if they disagree.

### Branch Component Visibility

A branch inherits the component catalog at creation time. Components created on main after the branch exists are invisible to that branch.

| Operation | Component inherited by branch? | Result |
|-----------|-------------------------------|--------|
| Push (update) | Yes (existed before branch creation) | Success |
| Push (update) | No (created on main after branch) | Fails — "ComponentId invalid" |
| Create | N/A (net-new component) | Success — creates a branch-only component |

A branch's component namespace is extensible: new components can be added via create, but components created elsewhere after the branch point cannot be updated on the branch. Branch-only components do not exist on main.

## Branch-Aware Deployment

The deploy tool uses a two-step pattern internally: it creates a PackagedComponent first (with `branchName` from sync state if present), then deploys by `packageId`. This ensures the correct branch version is deployed.

```
bash scripts/boomi-deploy.sh path/to/component.xml
```

To deploy main specifically (even if a branch has a newer version), ensure the component was pulled from main (no branch in sync state).

**Why the two-step pattern matters:** The `branchName` field on the DeployedPackage endpoint is silently ignored. Deploying by component ID alone picks the globally latest version across all branches — not main. The two-step pattern (package with branch, deploy by package ID) is the only way to get deterministic branch control.

## Merge Requests

All merge operations use `boomi-branch.sh`.

**Create** a merge request:
```
bash scripts/boomi-branch.sh merge --source my-feature --dest main
```

Options: `--strategy OVERRIDE|CONFLICT_RESOLVE` (default: OVERRIDE), `--priority SOURCE|DESTINATION` (default: SOURCE).

**Check status:**
```
bash scripts/boomi-branch.sh merge-status --id {mergeRequestId}
```

**Execute:**
```
bash scripts/boomi-branch.sh merge-execute --id {mergeRequestId}
```

**Revert** a completed merge:
```
bash scripts/boomi-branch.sh merge-revert --id {mergeRequestId}
```

**Delete** a pending merge request:
```
bash scripts/boomi-branch.sh merge-delete --id {mergeRequestId}
```

### Stage State Machine

Merge requests progress through stages asynchronously. Poll `merge-status` to track progress.

```
CREATE → DRAFTING → DRAFTED → REVIEWING → MERGING → MERGED → REVERTED
                 ↘                     ↘
            FAILED_TO_DRAFT       FAILED_TO_MERGE

At any pre-MERGED stage: merge-delete removes the request entirely.
```

| Stage | Meaning | Next action |
|---|---|---|
| DRAFTING | Platform analyzing branch differences | Poll `merge-status` until DRAFTED |
| DRAFTED | Analysis complete, ready for review | Auto-transitions to REVIEWING for OVERRIDE strategy |
| REVIEWING | Ready to execute | Run `merge-execute` |
| MERGING | Merge in progress | Poll `merge-status` until MERGED |
| MERGED | Complete | Optionally `merge-revert` |
| REVERTED | Merge undone, merge request remains queryable | Terminal state |
| FAILED_TO_DRAFT | Analysis failed | Retry with `merge-delete` then new `merge` |
| FAILED_TO_MERGE | Merge failed | Retry with new merge request |

### Merge Strategies

- **OVERRIDE** (default) — auto-resolves conflicts using `priorityBranch` (default: SOURCE). Still progresses through the full stage workflow.
- **CONFLICT_RESOLVE** — requires per-component conflict resolution before merge can execute. See workflow below.

### CONFLICT_RESOLVE Workflow

A three-step process: create → resolve → execute.

**Step 1: Create** with `--strategy CONFLICT_RESOLVE`. Progresses through DRAFTING → DRAFTED → REVIEWING (same as OVERRIDE).

**Step 2: Check status and resolve conflicts.** Run `merge-status` — the output shows per-component details including `changeType`, `conflict` status, and `resolution` (pending until set).

Resolution values: `OVERRIDE` (source branch wins) or `KEEP_DESTINATION` (destination preserved, source changes discarded).

**Step 3: Execute** with `merge-execute`. Attempting to execute without resolving all conflicts returns an error listing the unresolved component GUIDs.

**Note:** Setting per-component resolutions is not yet exposed as a CLI command. See `references/guides/branch_merge_api_behavior.md` for the API-level resolution pattern.

## Safety Model

All CLI tools echo their branch target on every operation. See `references/guides/cli_tool_reference.md` for full branch workflow examples and safety checks.

Key protections:
- **Push** aborts if sync state records a branch but the XML lost its `branchId` — prevents accidental main writes
- **Deploy** uses the two-step package-then-deploy pattern for deterministic branch control
- **Sync state** tracks `branch_id` so branch context is preserved across pull/push cycles
- **Branch resolution priority:** `--branch` flag > `branchId` in XML > `BOOMI_DEFAULT_BRANCH_ID` env var > main
