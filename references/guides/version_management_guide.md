## Component Version Management

Component versioning is managed server-side by the Boomi platform. Every push (update) to a component auto-increments a global version counter. Historical versions are fully accessible via API — you can list, retrieve, compare, and restore any prior version.

## Contents
- Component Versioning Model
- Viewing Version History
- Retrieving Historical Versions
- Comparing Versions
- Deletion Behavior
- Branch Interactions

## Component Versioning Model

Every push (update) increments the component's `version` attribute by 1 — even when the pushed content is identical (the platform does not deduplicate). The platform controls this; the `version` value in pushed XML is ignored.

| Attribute | Behavior |
|-----------|----------|
| `version` | Integer, auto-incremented on every push. Server-controlled — client value ignored. |
| `currentVersion` | `true` on the latest version, `false` on all prior versions. Server-controlled. |
| `createdDate` / `createdBy` | Immutable. Set once at component creation, never changes. |
| `modifiedDate` / `modifiedBy` | Updated on every push to reflect who pushed and when. |

Version numbers are **globally sequential across all branches** for a given component. If main has versions 1-4 and a branch push occurs, it becomes version 5 — not a separate per-branch sequence. A version number alone uniquely identifies a component revision regardless of which branch it was created on.

## Viewing Version History

```bash
bash <skill-path>/scripts/boomi-version-history.sh --component-id <guid>
```

Optional flags: `--branch <name>` (filter by branch), `--current` (current version only).

Output shows version number, branch, modification date, modifier, and whether it's the current version.

## Retrieving Historical Versions

```bash
bash <skill-path>/scripts/boomi-component-pull.sh --component-id <guid> --version 2
```

Saves with a version-aware filename (e.g., `MyProcess_v2.xml`). Use `--target-path` to override.

A version number alone retrieves any revision from any branch. Invalid version numbers (0, negative, or beyond the current count) return an error.

## Comparing Versions

```bash
bash <skill-path>/scripts/boomi-component-diff.sh --component-id <guid> --source 1 --target 3
```

Returns structured JSON with `addition`, `deletion`, and `modification` arrays. Each change includes an XPath, old/new values, and element key.

**Key behaviors:**
- Non-adjacent versions produce aggregate (net) diffs — intermediate changes that cancel out are excluded.
- Direction matters — reversing source and target inverts additions/deletions.
- Cross-branch diffs work — version numbers are globally sequential.
- Same-version comparison is rejected (HTTP 400).

## Deletion Behavior

Deleting a component creates a **new version** with `deleted=true`. It does not destroy prior versions.

| Version | deleted | currentVersion |
|---------|---------|----------------|
| 1 | false | false |
| 2 | false | false |
| 3 (deletion) | **true** | **true** |

Prior version XML is fully recoverable by pulling the version number before deletion (e.g., `--version 2`).

Deleted components appear in version history with `deleted=true` on the deletion version. The version history tool with `--current` shows only the latest state, which reveals whether a component has been deleted.

## Branch Interactions

**Global version counter:** Version numbers are shared across all branches for a given component. Main 1-4, then a branch push creates version 5. No per-branch version sequences.

**`currentVersion` is main-only.** Branch versions are never marked `currentVersion=true`. To find the latest version on a branch, use `--branch` on the version history tool and take the highest version number.

**Unfiltered queries return all branches.** Version history without `--branch` returns versions from all branches interleaved. Use `--branch` to isolate a specific branch.

**Version retrieval ignores branches.** Pulling version 5 returns version 5 regardless of which branch it was created on. The version number alone is a globally unique identifier.
