## Pulling Components with Dependencies

## Contents
- XML Modification Philosophy
- Pull Component Workflow

When user provides a component ID or platform URL to work on, follow this workflow.

### XML Modification Philosophy

- **Pulled XML**: Leave as-is (if platform accepted it, it's valid)
- **New components**: Use minimal format from templates
- **Don't normalize**: Don't waste effort reformatting existing verbose XML

### Pull Component Workflow

Copy this checklist and track your progress:

```
Pull Progress:
- [ ] Step 1: Extract component ID(s) from URL
- [ ] Step 2: Pull root component(s)
- [ ] Step 3: Scan for dependencies
- [ ] Step 4: Check existing local components
- [ ] Step 5: Pull missing dependencies (depth 1)
- [ ] Step 6: Pull transitive dependencies (depth 2-7)
- [ ] Step 7: Verify reference components
```

**Step 1: Extract component ID from URL**

If URL provided, extract the GUID:
- Primary: Look for `componentIdOnFocus=` parameter
- Note: User may provide multiple component IDs in a single URL as `components=` parameters

**Step 2: Pull root component(s)**

Run: `bash scripts/boomi-component-pull.sh --component-id <guid>`

Verify the component was pulled successfully to `active-development/`.

**Step 3: Scan for dependencies**

Read the pulled XML and identify all GUID-like attributes:

Common dependency patterns:
- **Maps**: `fromProfile`, `toProfile`, `docCache`
- **Processes**: `connectionId`, `operationId`, `mapId`, `calledProcess`
- **Operations**: `connectionId`, `requestProfileId`, `responseProfileId`

**Step 4: Check existing local components**

Check `active-development/.sync-state/` to identify which dependencies are already local.

Create a list of missing component IDs.

**Step 5: Pull missing dependencies (depth 1)**

For each missing dependency:
```bash
bash scripts/boomi-component-pull.sh --component-id <dependency-guid>
```

**Step 6: Pull transitive dependencies (depth 2-7)**

Repeat Steps 3-5 for newly pulled components.

Stop at depth 7. Boomi designs should not generally go this deep, so this is merely a check and balance. If you feel there is more to correctly pull, discuss with the user.

**Step 7: Verify reference components**

For subprocesses that seem intended for re-use, check for in-process reference notes or un-wired step configurations:

1. Look for un-wired shapes with detailed annotations (outside any path reachable from start step of the subprocess)
2. Identify labels like "TEST/REFERENCE/EXAMPLE" or descriptive user labels
3. Note documented requirements:
   - Property names with test values
   - Map structures
   - Required profiles

**Critical**: Intelligently replicate these configurations in your parent/calling process to populate the input data the subprocess expects.

**Step 8: Report results**

Summarize what was pulled:
- Root component: [name and ID]
- Direct dependencies: [count] components
- Transitive dependencies: [count] components
- Reference patterns identified: [list any found]

