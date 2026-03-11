# Web Services Listener Pattern Reference

## Contents
- API Conversion Pattern
- Wrapper + Subprocess Pattern
- Atom Type Compatibility
- Troubleshooting

## API Conversion Pattern (Converting Existing Processes)
**When asked to "convert to API", "wrap in API", or "expose as API":**

1. **REUSE existing process** - don't recreate the logic
2. **Minimal changes** - change `<stop continue="true"/>` to `<returndocuments/>`
3. **Create lightweight wrapper** - WSS Start → Process Call (existing process) → Return Documents
4. **Preserve existing profiles** - reuse working components

This maintains tested logic while adding API capability with minimal new components. Additionally it maintains the ability for the user to test the core business logic via the subprocess in the GUI.

## Wrapper + Subprocess Pattern (Best Practice)
```
WSS Listener Process (Wrapper):
├── WSS Start step with 'listen' action
├── Process Call step → Main Business Logic Subprocess
└── Return Documents step (uses WSS response profile)

Main Business Logic Subprocess:
├── Start step (passthroughaction)
├── [Business logic steps: transforms, connectors, etc.]
└── Return Documents step
```

**Benefits**: WSS wrapper tested via HTTP, subprocess tested via boomi-test-execute.sh. Enables independent testing and debugging.

**Profile Reuse**: Same structure = reuse profile. WSS wrapper and subprocess should share profiles when data structure matches.

## Atom Type Compatibility
Different runtime types support different Web Services Server listener patterns:

### RESTish Listeners (Simple WSS)
- **Process structure**: WSS Start step with 'listen' action, no API Service component wrapper
- **Supported runtimes**: Intermediate atoms, Basic atoms
- **Cannot deploy to**: Advanced atoms

### REST with API Service
- **Process structure**: WSS Start step with 'listen' action, wrapped in API Service component
- **Supported runtimes**: Advanced atoms only
- **Cannot deploy to**: Intermediate atoms, Basic atoms

## Troubleshooting
**Issue**: Deployed listener process isn't accessible via HTTP

**Diagnosis**: Verify the atom type matches the listener pattern

**Details**: Mismatched atom/listener types may deploy successfully but fail to respond to requests

**Note**: API Service component reference documentation not yet in scope for this skill.