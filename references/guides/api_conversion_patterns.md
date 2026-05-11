# Web Services Listener Pattern Reference

## Contents
- Listener Pattern Decision
- API Conversion Pattern
- Wrapper + Subprocess Pattern
- Atom API Tier Compatibility
- Troubleshooting

## Listener Pattern Decision

Before authoring any listener, API, or HTTP endpoint, identify the target atom's API tier:

```bash
bash <skill-path>/scripts/boomi-shared-server-info.sh
```

Defaults to `$BOOMI_TEST_ATOM_ID` (the most common case); optionally - pass an atom ID literal as `$1` to override.

Route by `apiType`:

| `apiType` | Pattern | Reference |
|---|---|---|
| `basic`, `intermediate` | Bare WSS listener process deployed directly | `references/components/web_services_server_start_shape_operation.md` |
| `advanced` | API Service Component wrapping a WSS listener process | `references/components/api_service_component.md` |

"API," "listener," and "REST endpoint" are overloaded terms — users may mean either pattern regardless of which word they pick. The atom's `apiType` is the disambiguator, not the user's phrasing. If the user explicitly names a pattern that conflicts with the target atom's tier, raise the conflict before building — do not silently switch patterns.

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

## Atom API Tier Compatibility

Atom API tier is read from `SharedServerInformation/{atomId}.apiType` (values: `basic | intermediate | advanced`). This is a separate field from `Atom.type` (which returns `CLOUD | ATOM | MOLECULE | CLOUDMOLECULE` and describes runtime topology, not API tier). Agents checking listener eligibility must query `SharedServerInformation`, not `Atom`.

### RESTish Listeners (bare WSS)
- **Process structure**: WSS Start step with `actionType="Listen"`, no API Service Component wrapper.
- **Supported pattern on**: `apiType=basic | intermediate`. Responds at `/ws/simple/<operation><Object>`.
- **Advanced atoms**: bare WSS listener deploys successfully but returns HTTP 404 at `/ws/simple/...` — runtime routes are not registered on Advanced-tier shared web servers. Use an API Service Component instead.

### REST with API Service Component
- **Process structure**: WSS Start step with `actionType="Listen"`, referenced by a `<route processId="..."/>` inside an API Service Component (`type="webservice"`).
- **Runtime support**: `apiType=advanced` only.
- **Other tiers**: deploy **succeeds** (Deploy API returns `SUCCESS`, package attaches), but every route returns HTTP 404 "Unknown operation for the given URL path" at request time. The failure is silent at deploy time — verify `apiType=advanced` before relying on route reachability.
- **Reference**: `references/components/api_service_component.md` (REST-only; SOAP/OData deferred)

## Troubleshooting

**Issue**: API Service Component route returns HTTP 404 at runtime even though the component deployed with `active=true`.

Three distinct silent-failure modes share this symptom. Triage in order (cheapest first):

1. **apiType mismatch** — run `bash <skill-path>/scripts/boomi-shared-server-info.sh` (defaults to `$BOOMI_TEST_ATOM_ID`) and confirm `apiType=advanced`. A `basic` or `intermediate` atom deploys the component successfully but 404s every route.

2. **Missing listener deploy** — packaging/deploying an API Service Component does not cascade to the processes it references. Confirm every `<route processId="...">` target is itself deployed active on the same environment. Redeploy any missing Listen processes, then retry.

3. **Route collision** — query `DeployedPackage` for other `componentType="webservice"` deployments on the environment with the same effective URL. Only the first-deployed serves; later components silently shadow. See `references/components/api_service_component.md` → Path Collisions for the reclaim mechanics.

Deploy API returns `SUCCESS` in all three cases. There is no API-level signal that distinguishes them before runtime.

---

**Issue**: Listener returns HTTP 401 from the cloud URL even though the atom's `minAuth` is `none`.

**Cause**: When the atom is attached to an Atom Cloud, the cloud enforces its own perimeter authentication independently of the atom's `minAuth` setting. The perimeter user is the account-cloud-attachment user (e.g. `bc@<account>.<atom_token>`), which is distinct from the platform API user (`BOOMI_USERNAME` / `BOOMI_API_TOKEN`).

**Diagnosis**: Populate `SERVER_USERNAME` / `SERVER_TOKEN` with the cloud attachment credentials (Manage → Cloud Management → `<cloud>` → Users). A uniform 401 across all paths — including paths that don't exist — is a cloud-perimeter-auth signal, not a route-registration signal.