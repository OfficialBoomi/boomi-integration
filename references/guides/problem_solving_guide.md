# Problem Solving Guide

When you hit a situation not covered by reference docs, work through these tiers in order. Move on once you've confirmed a tier can't resolve it — not after checking one file.

## Tier 1: Check What We Already Know

The most common failure mode is concluding "we don't have docs for this" without actually checking.

- Re-read the SKILL.md file index — "Use when" annotations cover more than you'd expect
- Search `references/` by keyword — connector names, step types, error messages
- Check `boomi_error_reference.md` — many "mysterious" failures are documented known issues
- Check `boomi_platform_reference.md` scope boundaries — it may be covered, just in a different file

## Tier 2: Apply Analogous Patterns

Boomi's architecture is highly consistent. Most "unknown" things are variations of documented things.

- **Unknown connector**: All connectors share Connection + Operation + Step architecture (see BOOMI_THINKING.md), but connector-specific configuration varies significantly. Ask the user to point you to a working example on the platform — pulling it is the fastest path.
- **Unknown step type**: All steps follow the same process XML shape structure (see `process_component.md`), but configuration elements differ per step type. Ask the user to point you to a process that uses the step so you can pull and study the XML.
- **Unfamiliar API response**: Read the response body, not just the status code. Common codes: 400 = malformed XML, 409 = version conflict (re-pull), 404 = wrong component ID.
- **Unexpected runtime behavior**: Apply the Notify step debugging pattern from `boomi_patterns.md`. Isolate by testing the subprocess alone with hardcoded input via Message step.

## Tier 3: Consult External Sources

Offer to fetch from `developer.boomi.com` or `help.boomi.com` for connector guides, API schemas, or release notes. User-provided documentation, examples, or screenshots take priority over web sources.

## Tier 4: Structured Experimentation

- **If the user can provide a working example**: Pull and study the XML — almost always faster than building blind
- **If no example exists**: Create the simplest possible version, push it, iterate one attribute at a time
- Read error messages completely — they're usually specific
- Don't retry the same thing unchanged
- Limit to 3-4 rounds before moving to Tier 5

## Tier 5: Escalate to User

Include: what you tried, what you learned (concrete observations, not speculation), and what's specifically blocking you. If suggesting the user do something in the GUI, be specific about what to look for and what to bring back.

Don't say "I can't do this" without context. Don't present a wall of failed attempts without synthesis.

## Anti-Patterns

- **Blind retry loop** — pushing the same XML repeatedly hoping the API will accept it
- **Scope creep into experimentation** — spending many API calls exploring when the user could answer in seconds
- **Skipping Tier 1** — the answer was in the docs
