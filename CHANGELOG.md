# Changelog

## 1.0.45

- Documented converging outcomes on the canvas
- Documented the Notify step's log output, message level and attributes


## 1.0.44

- Pin the API User-Agent against install-directory and `.env` overrides


## 1.0.43

- Document Split Documents output shape: the split preserves the parent wrapper in JSON and XML


## 1.0.42

- Correct Mail Send `bodyContentType`: relevant only under `disposition="attachment"`, inert and optional under `inline`
- Correct Mail content-type values to lowercase


## 1.0.41

- Narrow the Disk V2 cloud runtime directory rule to `work`
- Add error reference Issue #33 for Disk V2 `FilePermission` denials


## 1.0.40

- REST Client connection passwords: set in the GUI; a pulled value is a token, not the password.
- Component create and push refuse a pulled REST Client secret token (`--allow-password-token` overrides).
- Documented Environment Extensions for editing a REST Client connection without the plaintext.
- Added `--help` to `boomi-component-create.sh`.


## 1.0.39

- Added `boomi-folder-list.sh` to list a folder's subfolders.
- `boomi-component-search.sh`: new `--recursive`; `--folder` takes a path.
- Folder queries exclude deleted folders; oversized subtrees are capped.
- Fixed an unbound-variable crash in `boomi-component-search.sh`.


## 1.0.38

- Added Business Rules step


## 1.0.37

- Skill folder now ships the changelog


## 1.0.36

- Document Agent step file uploads
- Correct Agent step error handling, output format, and connection/operation details
- Add error reference Issue #32 for Agent step in-band errors


## 1.0.35

- Note the execution-worker requirement for Event Streams Listen on cloud runtimes, with the Consume fallback


## 1.0.34

- Add `components/mail_component.md` — awareness-only reference for the legacy Mail connector (`connectorType="mail"`), routing new work to Mail (IMAP)


## 1.0.33

- Expanded and consolidated parameter value type knowledge into a single guide now referenced from Notify, Message, Set Properties, and Exception steps


## 1.0.32

- Fix `xml_attr` returning multiple values on XML with nested `componentId` attributes


## 1.0.31

- Corrected flat file profile textQualifier enum values


## 1.0.30

- Honor configured target folder unless the user directs otherwise


## 1.0.29

- Improve Message step escaping guidance: literal `{}` output and Database V2 empty-input GET pattern


## 1.0.28

- Document new map functions: String, Numeric, Connector Call, Properties
- Document User-Defined Functions (now preferred over scripting for multi-step map logic)
- Correct REST profile warning; REST operations support request/response profiles


## 1.0.27

- Documented Process Call return-path mismatch behind canvas detachment issue


## 1.0.26

- Corrected http_client_component.md: all five HttpSettings sub-blocks are required on create/update; omitting them breaks the component in the Build UI

## 1.0.25

- Document the OpenAPI connector connection and operation components


## 1.0.24

- Expand Map Function documentation; add coverage for all Lookup functions (Simple, Cross Reference, Document Cache, SQL)


## 1.0.23

- Add support for reusable Process Script Components


## 1.0.22

- Document Process Call return-path name matching, silent mismatches, and `returnLabel`
- Document child→parent DPP propagation across a `wait="true"` Process Call


## 1.0.21

- Add support for Process Route

## 1.0.20

- Fix component create/push corrupting XML when the `<?xml ?>` declaration shares a line with the `<bns:Component>` root element.

## 1.0.19

- Fix `boomi-deploy.sh --list-environments` to list environments via `POST /Environment/query`.


## 1.0.18

- Stamp the resolved component ID onto the root element before pushing component updates.



## 1.0.17

- Fix create/push/deploy failing for components with bracketed names (e.g. `[System] Order Sync`)


## 1.0.16

- Fix component create to stamp the assigned componentId onto the root whether its attribute was empty, stale, or absent.
- Warn instead of reporting success when the componentId cannot be stamped into the local file.

## 1.0.15

- Require xpath on every connection/operation override field; a missing xpath silently inerts the override.
- Emit the complete canonical ConnectionOverride block from a platform pull rather than a hand-picked subset.
- Add error-reference Issue #31 (silently-inert override) with a grep detector; fix the inert <field> examples.


## 1.0.14

- Component push reports the resulting version number on success.
- Clarify the no-change skip message: nothing is sent; use `--force` to push anyway.
- Correct API troubleshooting guide: HTTP 403 is an authorization failure, not deduplication.


## 1.0.13

- Stream component create/push bodies from a tempfile to avoid ARG_MAX overflow on large processes


## 1.0.12

- Document process options and their effects


## 1.0.11

- CLI scripts now exit non-zero on API/operation failures, so callers detect failed pushes, creates, and deploys.
- `xml_attr` returns empty on no-match instead of aborting under `set -euo pipefail`, so missing-field guards print their diagnostics.


## 1.0.10

- Fix REST connector dynamic-property key for custom request headers (`requestHeaders`)

## 1.0.9

- Document Event Streams dead-letter queue (DLQ)


## 1.0.8

- Add Database (Legacy) profile (`profile.db`) coverage to the Document Cache component reference.


## 1.0.7

- Add Database (Legacy) connector references: connection, operation, database profile, and step


## 1.0.6

- Added support for reusable Map Script components that a map can reference instead of an inline script, and when to use each.
- Fixed a defect in the component-creation script that could blank a component's reference to another component on create.


## 1.0.5

- Strengthen instructions to avoid mapping the output of one function into the input of another
- Add componentId to map component sample snippets


## 1.0.4

- Add Flow Control step reference (`flow_control_step.md`) to the `boomi-integration` skill, covering batching, parallel fiber execution, scope-of-effect, document ordering across fibers, and state sharing between fibers and the controlling execution.
- SKILL.md inventory updated to include `flow_control_step.md`.
- BOOMI_THINKING.md gains a "Flow Control Steps" subsection under Step Design Principles with point-in-process scope guidance.


## 1.0.3

- Add `boomi-extensions.sh` for Environment Extensions value management: partial-by-default writes, pre-write snapshots, and more clear requirements for the model.
- Sharpen the Process Extensions reference.

## 1.0.2

- Boomi Companion now identifies the originating skill in its Boomi Platform API requests and local activity log entries.
- Document VERSION-file ownership in the plugin and skill `CLAUDE.md`.


## 1.0.1

- Add Mail (IMAP) connector reference to the `boomi-integration` skill: `mail_imap_connection_component.md` (SMTP outbound + IMAP inbound, Basic Auth and OAuth 2.0 with optional `OAUTH2_SAME_AS_OUTBOUND` inbound reuse), `mail_imap_connector_operation_component.md` (Receive / Send / Move with Document Cache attachment routing, XML request profile for Move, full `connector.mailsdk.*` property catalog), and `mail_imap_connector_step.md` (canvas XML for all three actions plus the Receive-as-start-step listener pattern). All behavioral claims runtime-validated against the Boomi platform.
- `document_cache_component.md` clarifies that the `DocumentPropertyKeyConfig.propertyId` field accepts connector-namespace properties (e.g. `connector.mailsdk.messageId`), useful for keying attachment caches off auto-tracked connector properties.
- SKILL.md inventory and common-workflow combinations updated to include the three new Mail (IMAP) reference files.


## 1.0.0

- **1.0.0** Boomi Companion debuts at Boomi World 2026.  Huzzah and rejoice!


## 0.6.7

- Final pre-release pass on the boomi-integration BOOMI_THINKING.md for accuracy and readability.


## 0.6.6

- Final pre-release pass on the boomi-integration SKILL.md for accuracy and readability.


## 0.6.5

- Emphasize in the boomi-integration CLI reference that `boomi-component-search.sh --related-to` cannot be combined with `--folder`, `--name`, or `--type`.


## 0.6.4

- `/freshies` no longer initializes a git repo automatically — the generated workspace is just the copied files, and users may add `.git` to their workspace as desired. Note: existing `/freshies` commands are unaltered; re-run `/bc-integration:configure-template-workspace` to apply the updates.
- Tightened `/bc-integration:configure-template-workspace` setup: Step 2 now uses a clear checklist (load the `boomi-integration` skill, derive the plugin root from its base directory, append `/template`, verify with `ls`) instead of a multi-tier filesystem fallback. More deterministic, easier to follow.


## 0.6.3

- Tighten template CLAUDE.md instructions prior to Boomi World full launch. Note: These template updates are not applied automatically to existing template workspaces. Re-run /bc-integration:configure-template-workspace to merge these updates into an existing template workspace if desired.

## 0.6.2

- Reformatted `template/preferred_connections.md` markdown and expanded the example registry entries to demonstrate three distinct usage shapes. Note: existing User Template workspaces will not be auto-updated by this change. Re-run `/bc-integration:configure-template-workspace` to merge the updated `preferred_connections.md` into your User Template.

## 0.6.1

- Add Documentation section to plugin and skill READMEs linking to the Boomi Companion overview on the Boomi Developer Portal
- Add Related Plugins & Skills section to plugin and skill READMEs to surface sibling plugins and standalone skills in the Boomi Companion ecosystem


## 0.6.0

- Minor release: the `active-development/` workspace now uses Boomi component-type identifier folders (`process/`, `profile.json/`, `connector-action/`, etc.) instead of generic plural names. New component types are discovered automatically, but the convention shift affects where the assistant writes new components and how it treats legacy workspaces — significant enough to surface beyond a patch bump.
- Components now land in `active-development/<component-type>/` folders matching Boomi's platform identifier (e.g. `process/`, `profile.json/`, `connector-action/`). New component types are picked up automatically. The CLI reference adds a UI-label-to-identifier table for the non-obvious cases (Connection → `connector-settings`, Operation → `connector-action`, Map → `transform.map`).
- Document cache `profileType` enum corrected from the invalid `profile.database` to `profile.db`.
- SKILL.md notes the `mkdir -p active-development/<component-type>/` step needed before writing a new component from scratch (the pull path handles this automatically).
- Existing workspaces with the legacy plural folder names (`processes/`, `profiles/`, etc.) keep working as-is. When the assistant sees them, it raises the inconsistency and offers to migrate, rather than either silently extending the legacy layout or unilaterally renaming.


## 0.5.52

- Strengthen `<skill-path>` resolution guidance in SKILL.md with an explicit checklist (anchor → verify → reuse the same path on every call) to prevent path-segment drift between script invocations.
- Apply `<skill-path>` prefix to remaining bare `scripts/` references in `boomi_error_reference.md` and `platform_entities/shared_web_server.md`.


## 0.5.51

- Pipeline now supports explicit minor/major version bumps via reserved `changes/_minor.md` and `changes/_major.md` fragments; default behavior remains a patch bump


## 0.5.50

- Slim default `template/.claude/settings.json` to a minimum-viable allow-list. Fixes `tools/*` → `scripts/*`, scopes plugin reads to `bc-**`, hoists `outputStyle` to top level.
- Skill snippets now show `boomi-shared-server-info.sh` without `$BOOMI_TEST_ATOM_ID` (the preferred baseline behavior)— the script already defaults to that var, and the bare form avoids a `simple_expansion` approval prompt in Claude Code.
- Normalize `componentId=""` for CREATE in five component references (REST + custom-connector connection/operation, MCP connection/operation) so the agent stops reaching for `uuidgen` — the platform mints the GUID on POST.

## 0.5.49

- Document how Web Services Server listeners expose URL query parameters as `query_*` DPPs, including the read pattern (`valueType="process"` + `<processparameter>`).
- Call out the silent-failure anti-pattern of reading DPPs via `valueType="track"` (with `mime.X` or `process.X` propertyIds), which returns empty without error.


## 0.5.48

- Add `references/platform_entities/shared_web_server.md` documenting the full set of shared-web-server auth types (None, Basic, Client Certificate, Client Certificate Header, Custom, External Provider, Gateway), the per-port multi-mode model, and an empirically-validated description of what `SharedServerInformation` can and can't tell you about a runtime's listener auth (default port only; `auth` is omitted when the value falls outside the `none|basic` enum). Reframes prior assumption that Basic is universally required — Boomi public cloud is Basic-only, but local Runtimes and customer-owned Private Runtime Clouds are not. Establishes the user's `.env` declarations as authoritative; the API surface is supplementary.
- Replace `boomi-wss-test.sh`'s hard-coded Basic auth with an explicit `.env`-driven model: `SERVER_AUTH_TYPE` (`basic | bearer | none`) declares the scheme, with `SERVER_USERNAME` + `SERVER_TOKEN` for Basic and the new `SERVER_BEARER_TOKEN` for Bearer. Tokens stay in `.env` (and out of the agent's conversation context). Unset `SERVER_AUTH_TYPE` falls back to inference from populated credentials, with hard-fail on ambiguity (both schemes set, or only one of the two Basic vars).
- `boomi-shared-server-info.sh` now reports `auth` informatively (with an explicit "default port uses cert/custom/gateway/external-provider" line when the field is omitted by the API), annotates `url` and `minAuth` to clarify they describe the default port and the runtime-wide floor respectively, and no longer attempts a `SERVER_AUTH_TYPE`-vs-API cross-check (the API surface is structurally too thin to support reliable validation).
- Reframe `SERVER_*` references in `SKILL.md`, `README.md`, `template/.env.example`, and `references/guides/user_onboarding_guide.md` around the new auth-type-declaring model.


## 0.5.47

- Update README feedback address from solutions@boomi.com to developer-offerings@boomi.com (plugin and boomi-integration skill)


## 0.5.46

- Activity logging is now opt-in: the boomi-integration CLI no longer writes `.activity-log/activity.jsonl` unless `BOOMI_COMPANION_LOG_ACTIVITY=1` is set in `.env`.
- `activity.jsonl` schema: rename `plugin_version` → `skill_version`.
- `boomi_api` accepts an optional `--out-file <path>` argument so callers can stream the response straight to a file. `boomi-component-pull.sh` and `boomi-execution-query.sh` now route through `boomi_api` instead of calling `boomi_curl` directly.


## 0.5.45

- Add HTTP Client awareness reference (`boomi-integration/references/components/http_client_component.md`) so the agent can safely work with existing HTTP Client connections, operations, and steps it encounters in customer environments
- `BOOMI_THINKING.md` continues to direct new work to the modern REST client; edits to existing `connectorType="http"` components now route through the new reference


## 0.5.44

- Add API Service Component (REST) reference covering component structure, per-route override inheritance, URL path construction, profile-override key correlation, and required placeholder elements for unused API shapes — the Integration-native deployable that wraps WSS Listen processes for Advanced-runtime deployment
- Add `boomi-shared-server-info.sh` preflight script that reports a runtime's `apiType`, `url`, and `minAuth` — run before authoring any listener to route `basic`/`intermediate` → bare WSS vs. `advanced` → API Service Component
- Document the silent-404 failure mode when listener pattern does not match runtime API tier: deployment succeeds but every route returns HTTP 404 at request time. Deploy API does not surface the mismatch
- Document that packaging/deploying an API Service Component does not cascade to the processes it references — both the component and each linked Listen process must be independently deployed to the target runtime, or routes 404 at request time
- Document URL path collision behavior: two API Service Components with the same effective URL on the same runtime both deploy `active=true`, but only the first-deployed serves. Shadowed routes are not registered at runtime; reclaiming the slot requires a fresh redeploy of the loser after undeploying the winner
- Clarify URL case-sensitivity split: bare `/ws/simple/` URLs sentence-case `objectName`; API Service Component routes are case-sensitive and verbatim
- Correct API management scope: the API Service Component itself is in-scope for this skill; gateway-level policies (rate limiting, subscription plans, developer portal, API Proxy) remain out-of-scope


## 0.5.43

- Remove incorrect `//` comment rule from Data Process Groovy step reference; clarify CDATA is a push-side convenience, not canonical storage
- Add Issue #30 to error reference: Groovy syntax errors deploy cleanly, surface only at runtime


## 0.5.42

- Add EDIFACT support across EDI reference docs: profile options, delimiter defaults, composite element patterns, tagList examples, trading partner PartnerInfo (UNB/UNG/UNH control info), envelope comparison, and connector record API fields
- Fold EDI config-critical facts into existing Boomi-mechanics docs — Transaction Set ID → GS-01 table and HIPAA GS-08 Implementation Convention reference in `edi_profile_component.md`; full UNOA–UNOY syntax identifier list and HIPAA compliance constraints in `trading_partner_component.md`; transaction pair dependencies and X12↔EDIFACT transaction-level equivalence in `platform_entities/edi_b2b.md` (reduces IP exposure vs. reproducing standards content standalone while keeping Boomi-configuration knowledge in place)
- Add Schema Validation Rules section to `edi_profile_component.md` covering HTTP 400 forbidden attributes (on EdiDelimitedOptions, EdiX12Options, EdiDataElement, EdiLoop, EdiSegment, DataFormat), DataFormat child element requirements, single-segment loop wrapping, HL hierarchy auto-generation pattern, and tagLists universal decision rule
- Add `references/guides/edi_sap_patterns.md` covering IDoc structure basics, EDI_DC40 control record fields, segment hierarchy and cardinality, Z-segment extension pattern, NAD party qualifier to SAP partner function (standard SD module codes: BY/AG, SE/LF, DP/WE, IV/RE), qualifier-driven routing and composite decomposition patterns, cross-reference table design categories, and validation patterns
- Reshuffle BOOMI_THINKING.md to move EDI Profile Design mental models (X12 and EDIFACT) out of top-level Core Mental Models into a dedicated section near the end of the file
- Update SKILL.md tree with `guides/edi_sap_patterns.md` entry and expanded `platform_entities/edi_b2b.md` description covering the new transaction pair and equivalence content


## 0.5.41

- Clarify that Disk V2 CREATE and UPSERT both require `connector.disk-sdk.fileName` to be set via a Set Properties step before the connector executes; point readers to `set_properties_step.md` for the shape structure and source-value types


## 0.5.40

- Add developer-offering disclaimer to `skills/boomi-integration/README.md` to match the plugin README


## 0.5.39

- Add disclaimer to README clarifying Boomi Companion is a publicly available developer offering, not an officially supported Boomi product


## 0.5.38

- Add `boomi-component-search.sh` — query components by folder, name, type, or reference relationship via `ComponentMetadata/query` and `ComponentReference/query`. Results land in `active-development/inventories/component_search_<timestamp>.json` (ephemeral alongside other working files). Folder scoping is flat; implicit filters `currentVersion=true` and `deleted=false` apply to component queries. Type filter accepts Boomi API-level types (e.g. `connector-settings` for a connection, `connector-action` for an operation) — runtime-validated against a real account.
- `boomi-component-search.sh --folder` now accepts id, exact name, or a LIKE pattern with `%` wildcards (e.g. `--folder 'Acme-%'`). Folder resolution paginates via `queryMore` so broad patterns aren't silently capped at the 100-result page size. Multiple matches are unioned via OR on `folderId`, and the resolved id list is surfaced in the output file's `metadata.filters.resolvedFolders`. Non-wildcard input preserves the previous behavior: id → exact-name → error on zero or ambiguous matches.
- `boomi-component-search.sh --related-to` now resolves the target component's current version up front and pins both `parentComponentId` and `parentVersion` on the `references` side of the query (components the target references). The `ComponentReference/query` endpoint rejects `parentComponentId` without its `parentVersion` companion, which made the previous flag DOA. Resolved version is surfaced in the output file's `metadata.filters.resolvedVersion`. Each output record carries a `relation` field of `"references"` or `"referenced-by"` to make direction explicit.
- `boomi-component-search.sh` pagination and final output assembly both stream through tempfiles and read back via `jq --slurpfile` instead of passing JSON via `jq --argjson`. Removes two separate `ARG_MAX` ceilings that previously truncated result sets past ~1-2k records with `jq: Argument list too long`; stress-tested at 5,000 records (2.6 MB output file).
- `boomi-component-search.sh` writes results atomically (`.tmp` + `mv`), with trap-based tempfile cleanup. Prevents the 0-byte orphan files that could appear in `active-development/inventories/` when the output-assembly `jq` failed mid-write.
- `boomi-component-search.sh` now emits `log_activity` entries on all failure paths (folder resolve, version resolve, query failure) with the failing stage tagged — previously only success paths were logged, which was asymmetric with sibling scripts like `boomi-undeploy.sh`.


## 0.5.37

- Add date subtypes (relative, last, lastsuccessful) to Set Properties reference with runtime-validated XML and behavioral notes
- Add legacy database connection requirement to sql and sp value types
- Add connector input filter attributes (elementToSetId, elementToSetName) and enforceSingleResult zero-result behavior


## 0.5.36

- feat: add VERSION file to skill directory; include version in user-agent header (`boomi-companion/<version>`)
- fix: prevent skill sync step from using stale commit after version bump


## 0.5.35

- fix: folder creation now falls back to account root when parent folder ID is invalid or missing, preventing auth lockouts from manual API retries


## 0.5.34

- Refine template CLAUDE.md: add guidance for custom curl and auth errors, fix Boomi capitalization, remove connector SDK peripheral skill reference

## 0.5.33

- Add Explanatory output style as default for new template projects


## 0.5.32

- Strengthen WSS path collision warning in deploy script and testing guide — clearer STOP directive for new-process deployments to prevent AI from ignoring the warning

## 0.5.31

- Add "Boomi Companion" user-agent header to all outbound HTTP requests

## 0.5.30

- Expand Set Properties step reference with complete valueType coverage (15 source value types) and all 5 settable property types (DDP, DPP, MIME, Connector Document Property, Process Property Component).

## 0.5.29

- Fix SIGPIPE (exit 141) on large component pulls — replace `grep|head` pipes with single-process `awk` extraction across `boomi-component-pull.sh`, `boomi-deploy.sh`, and `event-streams-setup.sh`

## 0.5.28

- Update skill README feedback channels to solutions@boomi.com (not accepting public issues yet)
- Remove premature contribution infrastructure promise and internal CI pipeline detail from public-facing doc

## 0.5.27

- Add component version management: `boomi-version-history.sh` for listing version history, `boomi-component-diff.sh` for structured version comparison, `--version N` on pull for retrieving historical versions, `--force` on push for rollback workflows
- Add `version_management_guide.md` — versioning model, history, retrieval, comparison, deletion behavior, branch interactions
- Add HTTP 403 (identical content) to problem solving guide

## 0.5.26

- Introduce `<skill-path>` convention for script paths — all documentation now uses `<skill-path>/scripts/` instead of bare `scripts/` to ensure correct path resolution when the skill is loaded as a plugin

## 0.5.25

- Update all installation references from `boomi-marketplace` to `boomi-companion`

## 0.5.24

- Fix `create-token` — correct GraphQL type and add required `expirationTime`
- Add `provision-connection`, `list-topics`, and `rest-produce` commands to Event Streams CLI
- Add optional `[token-name]` argument to `rest-produce` for explicit token selection
- Add `event_streams_rest_api.md` — REST produce reference (auth, payloads, limits)
- Enrich `query-topic` with REST produce URLs and subscription detail
- Event Streams doc corrections: remove non-functional `partitions` field, clarify `actionType` values, add Consume-as-start to process options table

## 0.5.23

- Add `stop_step.md` reference — documents Stop step `continue` attribute (`true`/`false`) with validated runtime behavior
- Correct error reference Issue #15 — bare `<stop/>` causes runtime `NullPointerException` in addition to GUI stack overflow (previously documented as GUI-only)

## 0.5.22

- Add error reference Issue #29 (Component Locking) — documents that GUI-held locks block all API writes and cannot be queried or released via API

## 0.5.21

- Add `boomi-wss-test.sh` — wrapper for testing WSS listener endpoints (handles auth, SSL, content-type internally)
- Add WSS listener path collision probe to `boomi-deploy.sh` — warns when an endpoint is already occupied before deploying
- Streamline WSS testing docs in `process_testing_guide.md` — replace raw curl examples with script usage
- Update template `CLAUDE.md` with structural headings, CLI tools pointer, and curl exit-code-35 guidance

## 0.5.20

- Add `.env` credential steering via deny rules in template workspace settings
- Add `boomi-env-check.sh` — checks which `.env` variables are set without revealing values
- Update env-setup-guide to use connection test and direct users to paste credentials themselves
- Simplify configure-template-workspace plugin discovery (derive path from skill base directory)
- Add descending sort by executionTime to `boomi-execution-query.sh`

## 0.5.19

- Add BSD-2-Clause license at repo root and skill directory
- Remove CONTRIBUTING.md per open-source counsel guidance (issue/feedback guidance moved to READMEs)
- Update READMEs with official "Boomi Companion" name, license reference, and feedback section

## 0.5.18

- Fix `notify_step.md` and `route_step.md`: correct docs that claimed `valueType="track"` works for DPPs — it only reads DDPs. DPPs require `valueType="process"` with `<processparameter>` (ref: error reference Issue #24, BIG-981)

## 0.5.17

- Add Document Cache component reference (`document_cache_component.md`) — component structure, attributes, CacheIndex/key type polymorphism (ProfileElementKeyConfig, DocumentPropertyKeyConfig, UserDefKeyConfig unsupported), non-zero ID requirements, profileType enforcement, map lookup constraints (DocumentCacheLookup vs DocumentCacheJoins)
- Add Document Cache steps reference (`document_cache_steps.md`) — Add to Cache (document sink behavior), Retrieve From Cache (all-documents and by-index modes, emptyCacheBehavior), Remove From Cache (all-documents and by-key modes), cache lookup as parameter source, common patterns (branch-based, multi-source join, temporary collection), scope/lifecycle, Molecule/Cloud node considerations
- Register Document Cache component and steps in SKILL.md file index

## 0.5.16

- Add Branch & Merge support: `boomi-branch.sh` CLI tool, `--branch` flag on pull/push/create scripts, branch-aware sync state, `resolve_branch_id`/`resolve_branch_name` helpers
- Add `branch_merge_guide.md` (tool-oriented) and `branch_merge_api_behavior.md` (runtime-verified API semantics)
- Fix `boomi-deploy.sh`: rewrite to safe two-step pattern (PackagedComponent → DeployedPackage by packageId). Previous version silently ignored branch context and deployed the globally latest version across all branches.
- Fix `boomi-component-pull.sh`: handle `--target-path` when value is a directory (auto-generate filename instead of shasum error)

## 0.5.15

- Add `<XMLFlavor><CustomStandardFlavor/></XMLFlavor>` to XML profile minimum configuration template and Critical Notes — GUI-created profiles return an empty `<XMLFlavor/>` on GET that fails schema validation on PUT/POST

## 0.5.14

- Add `valueType="current"` Notify tip to BOOMI_THINKING debugging section
- Fix SIGPIPE in component-pull: replace `grep -m 1` with `grep | head -1` for large payloads
- Expand template CLAUDE.md peripheral skill guidance: add marketplace skill reference, guard each with "If available"

## 0.5.13

- Add Agent step reference (`agent_step.md`) — AI Agent shape configuration, model selection, instruction authoring, tool definitions, and guardrails
- Register Agent step in SKILL.md file index

## 0.5.12

- Add Process Property component reference (`process_property_component.md`) — runtime-validated: component structure, all 5 data types (string/number/boolean/date/password), allowed values enforcement, persistence scoping (per-process, not shared across processes referencing the same component), Set Properties wiring (`valueType="definedparameter"` / `<definedprocessparameter>`), Groovy API, environment extensions pointer
- Fix `boomi-component-create.sh` silent bug: narrowed componentId sed replacement to empty-string placeholder only, preventing clobber of nested `componentId` references (e.g. `<definedprocessparameter>`) with the newly-created component's ID
- Add `definedparameter` valueType pointer to `set_properties_step.md` Source Value Types
- Add `processproperty` → `active-development/process-properties/` to CLI folder mapping table
- Register process property component in SKILL.md file index

## 0.5.11

- Fix SIGPIPE and shell variable size issues in component-pull — write API response to temp file instead of shell variable, use `grep -m 1` to avoid broken pipes on large payloads
- Add `stamp_origin_file` fallback to inject `<bns:description>` before `<bns:object>` when no description element exists
- Replace `grep | head -1` with `grep -m 1` in `xml_attr` utility

## 0.5.10

- Add Cross Reference Table component reference (`cross_reference_table_component.md`) — component structure, match types (exact/wildcard/regex), column indexing, lookup behavior (case-insensitive, first-row-wins, empty-string on no-match, skipLookupIfNoInputs), parameter value source usage, multi-input lookups
- Add Cross Reference Lookup (§8) to `map_component_functions.md` with minimal example and pointer to full doc
- Register cross reference table in SKILL.md file index

## 0.5.9

- Add Disk V2 connector reference — connection component (`diskv2_connection_component.md`), operation component (`diskv2_connector_operation_component.md`) with all 7 action types (CREATE, UPSERT, GET, QUERY, LIST, DELETE, LISTEN), and connector step (`diskv2_connector_step.md`)
- Add Disk V2 LISTEN start configuration to start_step.md
- Register Disk V2 connector in SKILL.md file index and capability listing
- Add `connectorType` identifiers to all connector entries in SKILL.md file index for direct string-match discovery from downloaded process XML

## 0.5.8

- Refine instance identifier semantics across JSON, XML, and EDI profile docs — document `identifierKey="-1"` and `identifierName="occurrence"` conventions for occurrence type, add combined value+occurrence expression examples, add `"0"` invalid value warning
- Add Qualifiers section to JSON profile component — required for GUI visibility of instance identifiers
- Add occurrence (positional) selection section to JSON profile component with standalone and combined examples
- Remove XSD references from exception_step.md and provenance language from edi_profile_component.md

## 0.5.7

- Add Trading Partner component reference (`trading_partner_component.md`) — classification, X12 partner info, AS2 configuration, DocumentTypes, tracked fields, API enforcement summary from runtime-validated experiments
- Add Trading Partner steps reference (`trading_partner_steps.md`) — TP Start/Send shapes, output paths with all 4 validated configurations, path execution order, inbound validation and error routing by standard, populated TradingPartners/MyCompanies structure
- Add Dragpoints and Output Path Wiring section to BOOMI_THINKING.md — `<dragpoints>` required on every shape, `toShape="unset"` convention, partial wiring support (all runtime-validated)
- Add Document Tracking section to BOOMI_THINKING.md — account-level custom tracked fields, CustomTrackedField API
- Add Trading Partner Start to process component decision table (`allowSimultaneous="true"`)
- Add cross-reference from start_step.md to trading_partner_steps.md
- Fix stale Contents entries in trading_partner_component.md

## 0.5.6

- Add Route step reference (`route_step.md`) — runtime-validated via toggle tests covering default path routing, first-match-wins evaluation (XML element order, not key attribute), case-sensitive equals, and per-document batch evaluation

## 0.5.5

- Add Exception step reference (`exception_step.md`) — runtime-validated via toggle tests covering `stopsingledoc` behavior and Try/Catch interaction

## 0.5.4

- Add `boomi-execution-query.sh` for querying execution records and downloading logs (supports all process types including WSS listeners)
- Decouple log download from `boomi-test-execute.sh` — now returns execution ID and status only
- Fix INPROCESS polling bug in `boomi-test-execute.sh` — script now re-polls on HTTP 200 with INPROCESS/STARTED status instead of treating any 200 as complete
- Add `valueType="current"` to Set Properties source value types (validated via runtime toggle test)
- Add subprocess execution visibility guidance to testing guide (parent logs contain subprocess output, no independent ExecutionRecord for parent-invoked subprocesses)
- Strengthen Groovy scripting guidance — scripting is a last resort, native Boomi components always preferred for UI maintainability
- Update cli_tool_reference.md and process_testing_guide.md with execution query workflow

## 0.5.3

- Fix CLAUDE.md skill repos section to accurately describe single-repo architecture (plugin is source of truth, CI mirrors skills out)
- Track skill-level .gitignore so it mirrors to standalone skill repo

## 0.5.2

- Add problem solving guide with tiered escalation framework for unknown/undocumented scenarios
- Add SKILL.md pointers from file index, development philosophy, and validation errors sections

## 0.5.1

- Consolidate boomi_gotchas.md into boomi_error_reference.md as a unified troubleshooting reference
- Update all cross-references across SKILL.md, README.md, and component/step docs

## 0.5.0

- Restructure skill directory layout: `boomi-reference/` → `references/`, `tools/` → `scripts/`
- Consolidate standalone guide files into `references/guides/`
- Normalize filenames to underscores for consistency
- Update SKILL.md and README.md to reflect new structure

## 0.4.3

- Add repeated segments/loops instance identifier guidance to EDI profile docs (use loopRepeat + tagLists, not separate definitions)

## 0.4.2

- Add nested skill repo safety instructions to CLAUDE.md (check skill repos before stash/checkout/reset)
- Fix stale implementing-boomi reference in dual-repo docs

## 0.4.1

- Gitignore skill-level .gitignore from plugin repo (dual-repo support)

## 0.4.0

- Rename plugin from boomi-core to bc-integration, skill from implementing-boomi to boomi-integration
- Generalize Claude-specific language throughout skill content for cross-platform compatibility (Cursor, Codex, etc.)
- Replace Flow MCP server references with generic Flow tooling guidance
- Add dual-repo architecture documentation and gitignore support for standalone skill repo
- Add CONTRIBUTING.md files for both plugin and skill
- Add boomi-undeploy.sh to README tools list
- Update template settings to reference connector-gen skill
- Fix typo in README

## 0.3.11

- Fix component origin stamp to persist in local XML files (previously only applied in-flight during create, lost on first push)
- Add Groovy sandbox note: scripts cannot make external network calls, use connector steps instead
- Add recursion depth guard guidance to process call step docs
- Add invalid valueType warning to notify step docs
- Expand REST connector step actionType to full valid set: GET, HEAD, POST, DELETE, PUT, PATCH, OPTIONS, TRACE

## 0.3.10

- Expand document splitting guidance: three prevention mechanisms (nested targets, tagLists, additionalElementValue) and combined EDI pattern for 1 doc per transaction set

## 0.3.9

- Fix incorrect autoGenOption guidance: hierarc1/hierarc2 DO auto-generate HL01/HL02 (do not map these fields)
- Add HL Loop Pattern example for 856 S/O/P/I nested structure with autoGenOption and additionalCriteria
- Add EDI dataType enum strictness warning with common invalid values
- Add isMappable="false" silent data loss warning to JSON profile docs

## 0.3.8

- Add standardized activity logging — `log_activity` in `boomi-common.sh` writes JSONL entries to `.activity-log/activity.jsonl` at project root
- All 8 platform scripts log operation results (success/fail) with context details
- Add `.activity-log/` to template `.gitignore`

## 0.3.7

- Add `boomi-undeploy.sh` for deployment removal (by ID or by component file)
- Fix `xml_attr()` in boomi-common.sh to handle multi-line XML correctly

## 0.3.6

- Add CHANGELOG.md with full version history
- Update CLAUDE.md guideline to include changelog reminder on version bumps

## 0.3.5

- Remove Python/uv instruction block from template CLAUDE.md
- Fix missing newline at end of template file

## 0.3.4

- Fix sed delimiter collision in `stamp_origin` description append — pipe delimiter conflicted with the separator being inserted before the origin tag, causing "bad flag" errors on components with non-empty descriptions

## 0.3.3

- Add python3 tool permission to template settings

## 0.3.2

- Fix invalid `local` keyword used outside a function in component-pull script

## 0.3.1

- Fix `${var,,}` bashism in component-pull causing shell errors
- Normalize API-error exit codes from 1 to 0 so platform responses flow to the AI (matching Python-era behavior)
- Exclude hook-logs from freshies/template rsync
- Update template settings for bash tools, fix SKILL.md path reference

## 0.3.0

- **Breaking:** Rewrite all CLI tools from Python to bash using curl + jq directly
- Eliminate requests, PyYAML, python-dotenv, and lxml dependencies
- Remove YAML config layer — tools source `.env` natively
- Profile-inspect remains Python (stdlib only)
- All docs updated to match new invocations

## 0.2.15

- Fix HTTP 204 treated as failure in log download — now retries like 202 while waiting for log ZIP generation

## 0.2.14

- Salesforce operation reference overhaul from experiment findings
- Add correct camelCase filter operator values and all 6 operation types
- Add Sorts element requirement (GUI white-screens without it — Gotcha #28)
- Mark developer.boomi.com and help.boomi.com as fetchable fallbacks

## 0.2.13

- Add collision-safe sync state naming using path-based filenames (`folder__name.json`)
- Add backward compatibility fallback to legacy stem-only state files
- Document standalone subprocess deployment requirement for isolated testing
- Add Salesforce INVALID_FIELD troubleshooting guide (fEnabled fix)
- Add Bitbucket Pipelines CI configuration

## 0.2.12

- Add centralized process options reference with start-step-aware defaults
- Add Gotcha #27 for listener processes with default options pitfall
- Cross-reference process options from all relevant step/component files

## 0.2.11

- Add experimentally-verified EDI profile structure guidance
- Replace generic Transaction example with canonical Header/Detail/Summary three-container skeleton
- Document N2 implied decimal shifting behavior (verified via platform experiments)
- Add sibling loop data corruption warning for flat peer loops

## 0.2.10

- Sanitize plugin for external sharing — replace dev account IDs, environment GUIDs, names, and project names with generic placeholders
- Soften unvalidated disclaimer and incomplete product status language

## 0.2.9

- Add flat file identity field Gotchas #25 and #26
- Gotcha #25: `mandatory="true"` on identity fields causes MANDATORY_ELEMENT_MISSING on map output
- Gotcha #26: Identity value trimming in data positioned profiles causes silent record loss
- Fix templates in flat_file_profile_component.md to use `mandatory="false"` on identity fields

## 0.2.8

- Add fallback discovery for plugin template directory
- `configure-template-workspace` now searches standard cache, common local folders, and WSL paths before prompting the user

## 0.2.7

- Auto-tag component descriptions with plugin origin on creation
- Add `_get_origin_tag()` and `_stamp_description()` helpers
- Tags both platform-bound XML and local file on create; idempotent

## 0.2.6

- Update guidelines wording with bold emphasis and commit-push-pr reference
- Remove nested validate-claim command from implementing-boomi skill (now a top-level command)

## 0.2.5

- Fix incorrect Decision step comparison types — remove invalid isempty/isnotempty/contains from decision_step.md
- Add correct empty-check pattern using equals with empty static value
- Correct JsonSlurper availability claim: it IS available in Boomi's Groovy 2.4 runtime
- Replace fragile regex JSON examples with clean JsonSlurper usage

## 0.2.4

- Organize and tidy pass for broader rollout
- Migrate plugin prefix references (boomi: to boomi-core:)
- Trim onboarding guide bloat, fix typos and stale references
- Remove phantom Gotcha #18, consolidate duplicate auth section

## 0.2.3

- Remove skill-feedback command

## 0.2.2

- Update all references to officialboomi/boomi-marketplace

## 0.2.1

- Rename plugin to boomi-core

## 0.2.0

- Initial commit to new home in OfficialBoomi workspace