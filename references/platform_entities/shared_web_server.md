# Shared Web Server

## Contents
- Overview
- Authoritative Source: The User
- API Tier (`apiType`)
- Authentication Types
- Multi-Mode Authentication
- The `.env` Declaration Model
- What `SharedServerInformation` Actually Tells You
- Related References

## Overview

The shared web server is the embedded HTTP listener inside a Boomi runtime that exposes deployed listener processes (WSS, FSS, MCP Server) over the network. Its configuration is read from `SharedServerInformation/{atomId}` on the Platform API and surfaced via `bash <skill-path>/scripts/boomi-shared-server-info.sh`.

Two settings on the shared web server gate everything else: `apiType` (which tier of API publishing is enabled) and the per-port authentication type.

## Authoritative Source: The User

The Platform API does not expose enough detail about the shared web server's port configuration to determine listener auth automatically. **The user is the authoritative source for how their runtime is configured.** The agent's job is to:

1. Honor what the user declares in `.env` (`SERVER_AUTH_TYPE`, `SERVER_BASE_URL`, credentials).
2. Ask when uncertain — never default to Basic just because the test tool's most common path uses Basic.
3. Treat `SharedServerInformation` output as supplementary context, not as an authority on auth scheme.

## API Tier (`apiType`)

| `apiType` | Capabilities | Listener pattern |
|---|---|---|
| `basic` | User management disabled. No Client Certificate / Custom auth. No API Service or API Proxy components. | Bare WSS listener — see `references/components/web_services_server_start_shape_operation.md` |
| `intermediate` | User management enabled at the process level. No API Service / API Proxy components. | Bare WSS listener |
| `advanced` | API Service / API Proxy components enabled. User management at the API Service component level. | API Service Component — see `references/components/api_service_component.md` |

Pattern routing is detailed in `references/guides/api_conversion_patterns.md`. `apiType` is reliably reported by `SharedServerInformation` and is independent of port configuration.

## Authentication Types

Authentication is configured per port on the shared web server, not on the listener process. The set of authentication types available depends on the runtime context and the `apiType`.

| Runtime context | Auth types in practice |
|---|---|
| Boomi-managed public cloud (e.g. `*.integrate.boomi.com`) | **Basic only.** Perimeter-enforced. Even when an attached runtime reports `minAuth=none`, requests are challenged with Basic at the cloud edge. |
| Local Runtime / Runtime Cluster | None, Basic, Client Certificate, Client Certificate Header, Custom (JAAS LoginModule), External Provider, Gateway. Available subset depends on `apiType`: `basic` allows None / Basic only; `intermediate` adds the certificate variants and Custom; `advanced` adds External Provider and Gateway. |
| Customer-owned Private Runtime Cloud | None, Basic, Client Certificate, External Provider — configured per port by the cloud owner. |

**Auth-type summaries:**
- **None** — no sign-in required. Users can still be added to identify callers (cloud attachments must define at least one user; on local runtimes the password is ignored).
- **Basic** — HTTP Basic. On Boomi-managed clouds the credentials are the cloud-attachment user (Manage → Cloud Management → `<cloud>` → Users), not the platform-API user.
- **Client Certificate** — full mTLS. The runtime presents an SSL Certificate component and validates the client's cert against it.
- **Client Certificate Header** — the certificate is read from a named HTTP header (typical for fronting load balancers that terminate TLS).
- **Custom** — JAAS LoginModule plug-in for arbitrary auth schemes (e.g. bearer-token validation against an in-house IDP). Local Runtime / Cluster only.
- **External Provider** — delegates to an external identity provider. `apiType=advanced` only.
- **Gateway** — validates a token issued by Boomi API Gateway. `apiType=advanced` only, and only one port per runtime can run Gateway auth.

## Multi-Mode Authentication

A single runtime can serve multiple ports with different auth types simultaneously. A common pattern: one port on Basic for legacy clients, a second port on Custom or Gateway for new clients carrying bearer tokens. This is configured per-port in the runtime's Shared Web Server panel.

`SharedServerInformation` does **not** expose per-port detail — it describes the default port only. If multi-mode is in play, the user's knowledge is the only complete source of truth. Ask which port their listener is reached on and what auth that port uses.

## The `.env` Declaration Model

`boomi-wss-test.sh` is driven entirely by `.env` — no auth flags on the command line. This keeps tokens out of the agent's context (the bash subprocess expands `.env` values; the agent never sees them).

| `.env` variable | Purpose |
|---|---|
| `SERVER_BASE_URL` | The URL of the listener port being tested (may differ from the default port). |
| `SERVER_AUTH_TYPE` | Declares the scheme: `basic`, `bearer`, or `none`. Unset is allowed — see "Inference fallback" below. |
| `SERVER_USERNAME` + `SERVER_TOKEN` | Used when `SERVER_AUTH_TYPE=basic`. Both must be set. |
| `SERVER_BEARER_TOKEN` | Used when `SERVER_AUTH_TYPE=bearer`. Sent as `Authorization: Bearer …`. |
| `SERVER_VERIFY_SSL` | Set to `false` to skip cert verification (self-signed local runtimes). |

**Validation rules** (script aborts before sending any HTTP if violated):

- `SERVER_AUTH_TYPE=basic` requires both `SERVER_USERNAME` and `SERVER_TOKEN`.
- `SERVER_AUTH_TYPE=bearer` requires `SERVER_BEARER_TOKEN`.
- `SERVER_AUTH_TYPE=none` ignores any credentials that happen to be set — useful for "test what an unauthenticated caller sees" without clearing the file.

**Inference fallback** (when `SERVER_AUTH_TYPE` is unset): the script picks the mode by which credentials are populated.

| Populated in `.env` | Inferred mode |
|---|---|
| `SERVER_USERNAME` + `SERVER_TOKEN` only | `basic` |
| `SERVER_BEARER_TOKEN` only | `bearer` |
| Nothing | `none` |
| Both Basic vars and Bearer token | **Hard error** — declare `SERVER_AUTH_TYPE` to disambiguate. |
| Only one of `SERVER_USERNAME` / `SERVER_TOKEN` | **Hard error** — set both or neither. |

The banner printed at test time always reports which mode was used and whether it was inferred (e.g. `auth=basic (inferred — set SERVER_AUTH_TYPE in .env to declare explicitly)`).

**Out of scope for `boomi-wss-test.sh`:** Client Certificate / mTLS testing. Fall back to manual `curl --cert <file> --key <file> ...` for those cases — the script doesn't orchestrate cert files.

## What `SharedServerInformation` Actually Tells You

The response shape is identical across all `apiType` tiers.

| Field | What it reflects |
|---|---|
| `apiType` | Runtime-wide tier (`basic | intermediate | advanced`). Reliable. Use for listener pattern routing. |
| `url` | The default port's URL (protocol + port number). Other ports configured on the same runtime are **not** represented anywhere in the response. |
| `httpPort` / `httpsPort` | Static port numbers — what's configured, not what's currently default. |
| `auth` | Default port's auth, **only when its value is `none` or `basic`**. The field is **omitted entirely** when the default port uses Client Cert, Client Cert Header, Custom, External Provider, or Gateway. The OpenAPI enum (`none | basic`) is structurally incomplete; the API can't represent the other types. |
| `minAuth` | The floor across all configured ports. If any port is `none`, this stays `none` regardless of other ports. Always reported. |

Practical implications for the agent:

- **Use `apiType`** to route the listener pattern decision (bare WSS vs. API Service Component).
- **Read the URL** to know which port is the default — and whether the user's `SERVER_BASE_URL` matches it.
- **Treat `auth` as informational, not authoritative.** It describes the default port. If the user is testing a different port, this value is unrelated to their test.
- **Treat `auth` absence as a soft signal** that the default port uses one of the non-enumerable types — useful diagnostic, but doesn't tell you which.
- **Do not infer auth scheme from `SharedServerInformation`.** When the user hasn't declared `SERVER_AUTH_TYPE`, ask them. Multi-mode runtimes and non-default ports make any inference unreliable.

A 401 response on a `*.integrate.boomi.com` URL where the runtime reports `minAuth=none` is the cloud-perimeter signature, not a route-registration problem. See `references/guides/api_conversion_patterns.md` → Troubleshooting.

## Related References

- `references/guides/api_conversion_patterns.md` — listener pattern decision (bare WSS vs. API Service Component) and cloud-perimeter troubleshooting.
- `references/components/web_services_server_start_shape_operation.md` — WSS operation component XML.
- `references/components/api_service_component.md` — Advanced-tier API publishing.
- `scripts/boomi-shared-server-info.sh` — supplementary inspection of a runtime's apiType, default-port URL, and (when reportable) default-port auth.
- `scripts/boomi-wss-test.sh` — test a listener endpoint; auth is configured via `.env` only.
