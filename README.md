# boomi-integration Skill

The official Boomi Companion skill for building Boomi integration processes programmatically with AI coding agents. The intended audience of this README.md document is humans seeking to understand the skill.

> **Important:** Boomi Companion is a publicly available developer offering, not an officially supported Boomi product. It is provided as-is and is not covered by Boomi support agreements or SLAs. Boomi curates and maintains this tool on a best-effort basis — treat it as a self-service resource. Boomi reserves the right to modify or discontinue it at any time without notice.

This project is licensed under the [BSD-2-Clause License](LICENSE). If you fork or modify this code, you should not use the name "Boomi" for your version.

## Documentation

For a full overview of Boomi Companion, including concepts, usage guidance, and additional resources, see the [Boomi Companion overview](https://developer.boomi.com/docs/BoomiCompanion/Boomi_companion_overview) on the Boomi Developer Portal.

## Related Plugins & Skills

This skill is also part of [Boomi Companion](https://github.com/OfficialBoomi/boomi-companion), which includes the following Claude Code plugins:

| Plugin | Description |
|--------|-------------|
| [bc-integration](https://github.com/OfficialBoomi/bc-integration) | Skills, commands, and agents for building Boomi integrations |
| [bc-marketplace](https://github.com/OfficialBoomi/bc-marketplace) | Skill for searching and installing Boomi Marketplace recipes |

Other skills available as standalone packages for use with other AI agents:

| Skill | Description |
|--------|-------------|
| [boomi-marketplace](https://github.com/OfficialBoomi/boomi-marketplace) | Skill for searching and installing Boomi Marketplace recipes |

## Feedback & Issues

Found a bug or have a feature idea? Email developer-offerings@boomi.com with a clear description, steps to reproduce, and any relevant error messages.

## What is this?

This is a distributable skill that provides AI coding agents with knowledge and tooling for working with Boomi Enterprise platform. It enables:

- Programmatic creation and modification of Boomi components (processes, profiles, connections, operations, topics, subscriptions)
- Bi-directional component push/pull with the Boomi platform API
- Reference documentation for Boomi componentry and development patterns
- CLI tools for deployment, testing, and component management

## Prerequisites

- `curl` (universally available)
- `jq` (install via `brew install jq` on macOS or `apt install jq` on Linux)
- Python 3 (only for `boomi-profile-inspect.py` — stdlib only, no pip deps)

## Installation

### Claude Code (via the bc-integration plugin)

Install through the Claude Code plugin system — the skill is included automatically:

1. Add the Boomi marketplace: `/plugin marketplace add OfficialBoomi/boomi-companion`
2. Install the plugin: `/plugin install bc-integration@boomi-companion`

Alternatively, navigate the `/plugin` menu interactively within Claude Code to add the marketplace and install.

### Manual configuration

Clone or copy this skill directory into the location your platform uses for agent skills. Consult your platform's documentation for the correct skill directory path.

## Project Setup

Once the skill is installed it works in an individual project folder as follows:

### 1. Directory Structure

```
your-project/
├── .env                    # Your credentials (created during setup)
└── active-development/     # All working files (auto-created as needed)
    ├── <component-type>/   # Component-type folders are created on demand using the platform's lowercase component-type identifier — e.g. process/, transform.map/, profile.json/, profile.xml/, connector-settings/, connector-action/, documentcache/.
    ├── .sync-state/        # Component sync state tracking
    └── feedback/           # Test execution results (created on demand)
```

If using the skill via the bc-integration plugin, there is a series of quality of life setup steps that help template and spin up project workspaces rapidly. See the README.md file for the plugin for more details, or ask your AI agent for help. 

### 2. Environment Variables

A Boomi development project (i.e. the folder in which you are working, not this skill directory itself) will require a `.env` file in your project root with:

```
# Platform API Credentials (required)
BOOMI_API_URL=https://your-platform.boomi.com
BOOMI_USERNAME=your_username
BOOMI_API_TOKEN=your_api_token
BOOMI_ACCOUNT_ID=your_account_id
BOOMI_VERIFY_SSL=true

# Default Folder (if no folder is specified, the agent will put projects here - optional).
BOOMI_TARGET_FOLDER=your_default_folder_guid

# Environment and Runtime Details (lets the agent deploy processes - optional)
BOOMI_ENVIRONMENT_ID=your_environment_id
BOOMI_TEST_ATOM_ID=your_test_atom_id

# Shared Web Server Credentials
# SERVER_AUTH_TYPE: basic | bearer | none.
# See references/platform_entities/shared_web_server.md for runtime-by-runtime guidance.
SERVER_BASE_URL=https://your-atom.integrate.boomi.com
SERVER_AUTH_TYPE=basic
SERVER_USERNAME=your_runtime_username
SERVER_TOKEN=your_runtime_token
SERVER_BEARER_TOKEN=
SERVER_VERIFY_SSL=false
```

**Where to find these:**
- API credentials: Boomi platform → Account settings → API Management
- Folder GUIDs: Create folders via GUI or use `boomi-folder-create.sh`
- Environment/Atom IDs: Boomi platform → Environment management

Your AI agent has more info about the necessary pieces of data and can talk you through them one by one - just ask!

## Usage

Once the skill is installed, you can work with your AI coding agent to build Boomi processes:

1. **Start a conversation**: Describe what you want to build
2. **The agent loads the skill**: References comprehensive Boomi documentation
3. **Programmatic development**: The agent creates/modifies XML components
4. **Platform sync**: The agent uses custom CLI tools to push/pull components to/from Boomi
5. **Deploy and test**: The agent can also use its tools to deploy to a runtime and test your processes

### Example Workflow

```
You: "Create a REST API endpoint that fetches weather data and returns JSON"

Agent: [Loads BOOMI_THINKING.md and relevant references]
       [Creates project folder]
       [Creates JSON profiles for request/response]
       [Pushes profile components to platform]
       [Creates REST connection and operation]
       [Pushes connection and operation components to platform]
       [Creates WSS operation for endpoint]
       [Creates process with all steps]
       [Pushes all components to platform]

You: "Deploy and test it"

Agent: [Deploys process to runtime]
       [Runs a curl command to test, or provides you the details to test yourself]
```

## Tools Overview

The skill makes the following CLI tools available to the agent:

- `boomi-env-check.sh` - Checks which .env variables are set without revealing values
- `boomi-folder-create.sh` - Creates project folders
- `boomi-component-create.sh` - Creates new components
- `boomi-component-push.sh` - Updates existing components
- `boomi-component-pull.sh` - Downloads components from platform
- `boomi-deploy.sh` - Packages and deploys processes to runtime
- `boomi-undeploy.sh` - Undeploys processes from runtime
- `boomi-test-execute.sh` - Executes and tests processes via platform API
- `boomi-wss-test.sh` - Tests WSS listener endpoints via the shared web server
- `boomi-profile-inspect.py` - Extracts field metadata from large profiles (Python stdlib)
- `event-streams-setup.sh` - Configures Event Streams

## Documentation Structure

The skill includes the following Boomi-centric reference documentation:

### Core Guides
- `BOOMI_THINKING.md` - Essential mental models (always read first)
- `references/guides/boomi_error_reference.md` - Error patterns, silent failures, and troubleshooting
- `references/guides/boomi_platform_reference.md` - Platform services and boundaries

### Component References
- `components/` - Detailed specs for all component types
  - Profiles (JSON, XML, Flat File)
  - Connections (REST, Salesforce, Event Streams)
  - Operations (Connectors, WSS)
  - Maps, Processes, Scripts

### Step References
- `steps/` - Process step documentation with examples
  - REST Connector, Map, Message, Set Properties
  - Branch, Decision, Try-Catch
  - Process Call, Return Documents
  - Event Streams, Salesforce

## Support and Issues

This skill is designed originally for Claude Code, but Agent Skills are an open standard accessible to other models and platforms. 

More info about agent skills can be found here: https://agentskills.io/home
and here: https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview

If you encounter issues:

1. This course provides an excellent intro to Claude Code: https://anthropic.skilljar.com/claude-code-in-action
2. We would love your feedback and input via developer-offerings@boomi.com
3. Your AI agent can often help troubleshoot and explain issues
