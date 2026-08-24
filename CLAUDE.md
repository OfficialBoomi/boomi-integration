# boomi-integration Skill

## What This Is

The boomi-integration skill — a framework for AI coding agents to build Boomi integration processes programmatically. See `README.md` for full details.

## Development Notes

- The `SKILL.md` is the agent-facing entry point. The `README.md` is for humans.
- `references/` contains curated Boomi platform documentation — treat it as authoritative.
- `scripts/` contains CLI scripts the agent uses to interact with the Boomi platform API.
- Boomi platform API calls from scripts must go through the `boomi_api` helper in `scripts/boomi-common.sh` (non-platform HTTP — e.g. WSS endpoint testing — is exempt). It wraps `boomi_curl`, which adds the Boomi Companion User-Agent, applies the SSL-verify flag, sets the timeout, and handles basic auth. `boomi_api` also captures the response into the globals `RESPONSE_CODE` and `RESPONSE_BODY` so callers don't need to roll their own output parsing. If `boomi_api` is missing something you need for a platform call, extend the helper rather than bypassing it.
- Keep changes minimal and focused. This skill is consumed by multiple platforms.

## Credential handling

Credentials must not reach the command line, a child process environment, or a shell trace. Six guardrails enforce that:

- **Auth reaches curl in a config file on stdin** (`-K -`). Stdin is therefore reserved in `boomi_curl` and `boomi_api` — never `@-`, `-T -`, or piping into them (inline `-d` and `--data-binary @file` are fine).
- **`load_env` does not export `.env` values.** Do not re-add `set -a`, however idiomatic it looks for sourcing a `.env`.
- **`var_is_set` is the only place that expands a variable by name.** `${!name}` puts the value into a traced command, so the xtrace fence lives in that one helper; `require_env` and `boomi-env-check.sh` call it. Anything new needing a by-name lookup must go through it rather than adding another guard.
- **Four scripts disable xtrace for the whole file**, each handling credential material outside the library's per-call fence: `event-streams-setup.sh` (minted JWT, raw tokens), `boomi-wss-test.sh` (assembled auth config), `boomi-extensions.sh` (payloads carrying connector password overrides), `boomi-shared-server-info.sh` (`authToken` in the response). Heredoc and here-string content is not traced, so request bodies built that way are safe either way.
- **Response bodies are fenced at capture and at use.** `boomi_api` fences the `RESPONSE_BODY` capture; the fence restores on return, so a caller that expands `RESPONSE_BODY` fences its own use — `boomi-component-create.sh`, `boomi-component-push.sh`, and `boomi-component-diff.sh` do. A submitted connector password comes back in some 4xx bodies, and a diff reports changed values verbatim. Check a new endpoint's response for credential material before expanding `RESPONSE_BODY` from it.
- **Every script carries its own guard.** `set +x` strips xtrace from an inherited `SHELLOPTS`, but a child `bash` re-reads `BASH_ENV`.

## Skill VERSION files

Versioning is performed by Boomi CI/CD pipelines and is tracked in the VERSION file for each skill (e.g. `skills/boomi-integration/VERSION`). Agents MUST NOT modify `VERSION` files.
