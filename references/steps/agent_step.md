# Agent Step Reference

## Contents
- Purpose
- Key Concepts
- GUI-Only Components
- Configuration Structure
- Required Components
- Component Dependencies
- Process Pattern
- Raw Output Format (SSE Event Stream)
- Response Modes
- Limitations
- Reference XML Examples

## Purpose
Agent steps integrate AI agents from the Boomi Agent Control Tower into integration process workflows. They send document content as a prompt to a configured agent and return the agent's response as the output document.

**Use when:**
- Incorporating AI agent reasoning into an integration workflow
- Sending structured or unstructured prompts to agents configured in Agent Designer
- Processing agent responses for downstream system consumption

## Key Concepts
- **Connector action pattern**: Agent steps use `shapetype="connectoraction"` with `connectorType="boomiai"` — the same dual-component pattern as REST, Database, etc.
- **GUI icon distinction**: The `image="aiagent_icon"` attribute is what renders the agent-specific icon in the GUI. The underlying shape type is a standard connector action.
- **Prompt = input document**: The agent receives whatever document content arrives at the step. Any upstream shape that produces a document works — a Message step is common but not required.
- **Single input/output**: One document in, one document out. No batching, no multi-turn within a single execution.
- **Connection/operation are one-time GUI setup**: The Agent connection and operation components cannot be created via the Component API — they require one-time configuration through the platform GUI. Once created, they are reusable by ID across any number of programmatically-built processes.

## One-Time GUI Setup (Reusable Components)
The Agent step depends on two components created once via GUI, then reused by ID:

1. **Connection** — Auto-generated when you first configure an Agent step. Contains the Platform API token and account binding. Stored in a root-level `Agents` folder.
2. **Operation** — Generated per agent configuration. Contains the agent selection and response mode. Stored in an `Agents` subfolder within the process's folder.

Once created, the `connectionId` and `operationId` are reusable indefinitely — reference them in any process XML built by this skill.

**Workflow when building a process with an agent step:**
1. Ask the user if they have existing agent connection/operation IDs
2. If yes — proceed, build the process referencing those IDs
3. If no — guide them through the one-time GUI setup: create an agent in Agent Designer, configure an agent step in any process via GUI, then pull that process to capture the generated connection and operation GUIDs

## Configuration Structure
```xml
<shape image="aiagent_icon" name="[shapeName]" shapetype="connectoraction" userlabel="[label]" x="[x]" y="[y]">
  <configuration>
    <connectoraction connectionId="[agent-connection-guid]" connectorType="boomiai" operationId="[agent-operation-guid]"/>
  </configuration>
  <dragpoints>
    <dragpoint name="[shapeName].dragpoint1" toShape="[nextShape]" x="[x]" y="[y]"/>
  </dragpoints>
</shape>
```

**Notable differences from other connector steps:**
- No `actionType` attribute (agents don't use HTTP methods)
- No `parameters` or `dynamicProperties` elements
- No `hideSettings` or `allowDynamicCredentials` attributes
- Minimal `connectoraction` element — just `connectionId`, `connectorType`, and `operationId`

## Required Components
Before adding an Agent step, ensure:
1. **Agent exists in Agent Control Tower** — Created via Agent Designer, synced to the account
2. **Agent step configured once via GUI** — This generates the connection and operation components
3. **Connection and Operation IDs captured** — Pull the process XML to obtain the GUIDs for programmatic reuse

## Component Dependencies
```
Agent Step (in process)
  ├── references → Agent Connection (by connectionId)
  │                  └── contains → Platform API Token, account binding
  └── references → Agent Operation (by operationId)
                     └── contains → Agent selection, response mode config
```

## Process Pattern
The standard pattern for agent steps in a process:

```
Start → Message (build prompt) → Agent Step → [optional Data Process cleanup] → next step
```

1. **Message step**: Constructs the prompt document. Can use parameter substitution to inject dynamic data.
2. **Agent step**: Sends the document to the configured agent, returns the response.
3. **Data Process step** (optional): Extracts the agent's text response from the SSE event stream output. See "Extracting the response text" below for the Groovy script.

## Raw Output Format (SSE Event Stream)
The agent step output is a Server-Sent Events (SSE) stream, not plain text. The full stream includes metadata about the agent's reasoning process before the actual response.

**Event types in order:**

| Event | Purpose | Key Fields |
|-------|---------|------------|
| `start` | Session initialization | `session_id`, `agent_id`, `user_id`, `created_at`, `invoked_from` |
| `progress_notification` | Agent thinking/action status | `type` (THINKING, GENERATING_TITLE, ACTION), `content` |
| `message` | Final agent response | `id`, `session_id`, `role`, `content`, `timestamp` |
| `[DONE]` | Stream termination | `null` |

**Example raw output structure:**
```
event: start
data: {"session_id": "...", "agent_id": "...", "invoked_from": "Integration"}

event: progress_notification
data: {"type": "THINKING", "content": "Thinking"}

event: progress_notification
data: {"type": "ACTION", "content": "Calling Tool: check_vehicle_errorcode"}

event: message
data: {"id": "...", "role": "agent", "content": "The actual agent response text...", "timestamp": "1773864266.698809"}

event: [DONE]
data: null
```

**Extracting the response text:** Add a Data Process step (Custom Scripting, Groovy 2.4) after the agent step. Use regex to isolate the `event: message` data line, then `JsonSlurper` to parse the JSON — this handles escaped quotes, newlines, and special characters without custom unescape logic.

```groovy
import groovy.json.JsonSlurper

for (int i = 0; i < dataContext.getDataCount(); i++) {
    InputStream is = dataContext.getStream(i)
    Properties props = dataContext.getProperties(i)

    String content = is.getText("UTF-8")
    def matcher = content =~ /(?m)^event: message\s*\ndata: (.+)$/
    String result = ""

    if (matcher.find()) {
        def parsed = new JsonSlurper().parseText(matcher.group(1))
        result = parsed.content ?: ""
    }

    dataContext.storeStream(
        new ByteArrayInputStream(result.getBytes("UTF-8")), props
    )
}
```

## Response Modes
Agents configured in Agent Designer have two response modes:

- **Conversational** (default): Agent responds in natural language text. Suitable for human-readable outputs.
- **Structured**: Agent responds in a consistent JSON format. Suitable for downstream system consumption. Generates request/response JSON profiles in the operation component.

The response mode is configured in Agent Designer, not in the process step.

## Limitations
- Agent connections/operations cannot be created via Component API — GUI configuration required
- Single input document, single output document — no batch processing
- Context window: user prompt + agent goals + tasks + instructions combined cannot exceed 200K input tokens
- Tool responses > 100K tokens are truncated by the platform
- Agents must be synced from Control Tower before use (sync is not immediate)
- Agent connections are account-bound — copying them to another account will fail
- Requires a Boomi public cloud instance

## Reference XML Examples

### Agent Step with Step Notes
```xml
<shape image="aiagent_icon" name="shape3" shapetype="connectoraction" userlabel="Send Error Codes to Kenji" x="480.0" y="96.0">
  <configuration>
    <connectoraction connectionId="39bdb269-55be-4b6f-a96a-eddc0931e883" connectorType="boomiai" operationId="33c5d21b-e4f5-4022-9d1f-7a076bc946d8"/>
  </configuration>
  <dragpoints>
    <dragpoint name="shape3.dragpoint1" toShape="shape4" x="736.0" y="104.0"/>
  </dragpoints>
  <stepnotes>
    <note title="Kenji: Automotive Mechanic / Diagnostics Agent">&lt;p&gt;Agent description and context visible in the GUI canvas&lt;/p&gt;</note>
  </stepnotes>
</shape>
```

### Minimal Agent Step
```xml
<shape image="aiagent_icon" name="shape2" shapetype="connectoraction" userlabel="Ask Agent" x="480.0" y="96.0">
  <configuration>
    <connectoraction connectionId="[agent-connection-guid]" connectorType="boomiai" operationId="[agent-operation-guid]"/>
  </configuration>
  <dragpoints>
    <dragpoint name="shape2.dragpoint1" toShape="shape3" x="656.0" y="104.0"/>
  </dragpoints>
</shape>
```

### Complete Process: Message → Agent → Log Output
```xml
<!-- 1. Message step builds the prompt -->
<shape image="message_icon" name="shape2" shapetype="message" userlabel="Build Agent Prompt" x="272.0" y="96.0">
  <configuration>
    <message combined="false">
      <msgTxt>[prompt text with optional {1} parameter substitution]</msgTxt>
      <msgParameters/>
    </message>
  </configuration>
  <dragpoints>
    <dragpoint name="shape2.dragpoint1" toShape="shape3" x="464.0" y="104.0"/>
  </dragpoints>
</shape>

<!-- 2. Agent step sends prompt and receives response -->
<shape image="aiagent_icon" name="shape3" shapetype="connectoraction" userlabel="Agent Name" x="480.0" y="96.0">
  <configuration>
    <connectoraction connectionId="[agent-connection-guid]" connectorType="boomiai" operationId="[agent-operation-guid]"/>
  </configuration>
  <dragpoints>
    <dragpoint name="shape3.dragpoint1" toShape="shape4" x="736.0" y="104.0"/>
  </dragpoints>
</shape>

<!-- 3. Notify step logs the agent response -->
<shape image="notify_icon" name="shape4" shapetype="notify" userlabel="Log Agent Output" x="752.0" y="96.0">
  <configuration>
    <notify disableEvent="true" enableUserLog="false" perExecution="false" title="Agent Response">
      <notifyMessage>{1}</notifyMessage>
      <notifyMessageLevel>INFO</notifyMessageLevel>
      <notifyParameters>
        <parametervalue key="0" usesEncryption="false" valueType="current"/>
      </notifyParameters>
    </notify>
  </configuration>
  <dragpoints>
    <dragpoint name="shape4.dragpoint1" toShape="shape5" x="960.0" y="104.0"/>
  </dragpoints>
</shape>
```
