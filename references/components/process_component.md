# Process Component Reference

## Contents
- Critical Requirements
- Shape Positioning & Connections
- Reference Process XML

## Critical Requirements

**Always include these required attributes to prevent GUI rendering errors and runtime failures:**

| Shape Type | Required Attribute | Example | Consequence if Missing |
|------------|-------------------|---------|------------------------|
| Stop | `continue="true"` | `<stop continue="true"/>` | GUI stack overflow error |
| Branch | `numBranches="N"` | `<branch numBranches="2"/>` | GUI blank canvas error |
| Data Process (Groovy) | `language="groovy2"` `useCache="true"` | `<dataprocessscript language="groovy2" useCache="true">` | Runtime null script engine error |
| WSS Start | `actionType="Listen"` | `<connectoraction actionType="Listen"...>` | Listener doesn't activate |

## Process Options

Process options are attributes on the `<process>` XML element that control execution behavior, logging, and performance. They must be set correctly based on the start step configuration.

### Decision Table: Recommended Process Options by Start Step Type

| Start Step Config | `allowSimultaneous` | `updateRunDates` | `enableUserLog` |
|---|---|---|---|
| No Data (`<noaction/>`) | `false` | `true` | `false` |
| Data Passthrough (`<passthroughaction/>`) | `false` | `false` | `false` |
| WSS Listener (`connectorType="wss"`) | `true` | `false` | `false` |
| FSS Listener (`connectorType="fss"`) | `true` | `false` | `false` |
| MCP Server (`connectorType="officialboomi-X3979C-mcp-prod"`) | `true` | `false` | `true` |
| Event Streams Listen (`connectorType="officialboomi-X3979C-events-prod"`) | `true` | `false` | `false` |

**All types**: `workload="general"`, `processLogOnErrorOnly="false"`, `purgeDataImmediately="false"`

#### Override Guidance

When a user requests values that differ from the table above: state the recommended value, explain the implication of deviation, then proceed with the requested values. Example: if a user wants `allowSimultaneous="false"` on a WSS listener, explain that concurrent HTTP requests will receive HTTP 500 when one execution is already in progress, then set the value as requested.

### Option Details

#### `allowSimultaneous`
Controls whether multiple instances of the process can run concurrently.
- `true`: Multiple instances execute in parallel. **Required for all listener types** — without it, concurrent requests queue or fail (WSS returns HTTP 500).
- `false`: Only one instance runs at a time. Appropriate for scheduled/batch processes.

Not recommended for processes using persisted process properties.

#### `updateRunDates` (Capture Run Dates)
Records last run date and last successful run date. These dates can be referenced in connector operations (e.g., "get records modified since last run").
- `true`: Useful for scheduled processes that need incremental pulls.
- `false`: Recommended for listeners and subprocesses — run date tracking has a performance cost per execution.

#### `enableUserLog`
Enables user-defined logging within the process.
- `true`: Recommended for MCP Server processes (debugging AI tool invocations).
- `false`: Default for most process types.

#### `processLogOnErrorOnly`
When `true`, process logs are only generated for executions that encounter errors. Only meaningful in Low Latency mode. Set to `false` for General workload.

#### `purgeDataImmediately`
Purges processed documents and temporary data immediately after each execution. Does not purge process or document logs.
- `false`: Default. Retains data for troubleshooting.
- `true`: Use when processing high volumes of sensitive data that should not persist.

Runtime-level Purge Data Immediately overrides this setting when enabled.

#### `workload` (Process Mode)
- `general`: Default. Full execution history, logs, and document payloads captured. Works with any start step type.
- `bridge`: Improved performance. Captures execution history and logs but not document payloads. Only works with listener connectors.
- `low_latency`: Maximum performance. Minimal logging — only Real-Time Dashboard summaries. Only works with listener connectors.

When a subprocess is called, the **parent's** workload mode is used for the entire execution chain.

### Subprocess Behavior

When a process calls a subprocess:
- **`workload`**: Parent's mode applies to the entire execution chain. Child's mode is ignored.
- **`allowSimultaneous`**: Subprocess executes immediately regardless of this setting on either process.
- **`purgeDataImmediately`**: Parent's setting takes precedence.
- **`updateRunDates`**: Each process tracks independently.

### XML Examples

#### Scheduled / No Data Process
```xml
<process allowSimultaneous="false" enableUserLog="false" processLogOnErrorOnly="false" purgeDataImmediately="false" updateRunDates="true" workload="general">
```

#### Subprocess (Data Passthrough)
```xml
<process allowSimultaneous="false" enableUserLog="false" processLogOnErrorOnly="false" purgeDataImmediately="false" updateRunDates="false" workload="general">
```

#### Listener Process (WSS, FSS, Event Streams)
```xml
<process allowSimultaneous="true" enableUserLog="false" processLogOnErrorOnly="false" purgeDataImmediately="false" updateRunDates="false" workload="general">
```

#### MCP Server Process
```xml
<process allowSimultaneous="true" enableUserLog="true" processLogOnErrorOnly="false" purgeDataImmediately="false" updateRunDates="false" workload="general">
```

## Shape Positioning & Connections

### Coordinate System
Each shape has an `x` and `y` attribute defining its position on the canvas. The canvas uses a standard coordinate system with (0,0) at the top-left.

**Recommended X-Axis Spacing**: Use 225-unit spacing between shapes on the same horizontal line to prevent label overlap and ensure clean visual layout.

### Shape Connections
Shapes connect through `<dragpoint>` elements within their `<dragpoints>` container:
- Each dragpoint specifies a `toShape` attribute with the target shape's name
- The dragpoint's own `x` and `y` coordinates appear to define the connection point location
- Sequential shapes typically have one dragpoint leading to the next shape

### Branch Shapes
Branch shapes support multiple execution paths:
- Each dragpoint has an `identifier` attribute (1, 2, etc.) 
- Each branch path has a `text` label matching the identifier
- The `numBranches` configuration must match the number of dragpoints

### Shape Naming
Shapes follow a sequential naming pattern: `shape1`, `shape2`, etc. The name is used as the reference in dragpoint `toShape` attributes.

## Reference Process XML


<?xml version="1.0" encoding="UTF-8"?><bns:Component xmlns:bns="http://api.platform.boomi.com/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" componentId="2235e474-05df-4641-a5d2-8dac2e54f7f6" folderId="Rjo3OTk2NjEx" name="Reference Process" type="process" version="23">
  <bns:encryptedValues/>
  <bns:description/>
  <bns:object>
    <process allowSimultaneous="false" enableUserLog="false" processLogOnErrorOnly="false" purgeDataImmediately="false" updateRunDates="false" workload="general">
      <shapes>
        <shape image="start" name="shape1" shapetype="start" userlabel="" x="48.0" y="46.0">
          <configuration>
            <passthroughaction/>
          </configuration>
          <dragpoints>
            <dragpoint name="shape1.dragpoint1" toShape="shape2" x="224.0" y="56.0"/>
          </dragpoints>
        </shape>
        <shape image="branch_icon" name="shape2" shapetype="branch" x="240.0" y="48.0">
          <configuration>
            <branch numBranches="2"/>
          </configuration>
          <dragpoints>
            <dragpoint identifier="1" name="shape2.dragpoint1" text="1" toShape="shape4" x="416.0" y="56.0"/>
            <dragpoint identifier="2" name="shape2.dragpoint2" text="2" toShape="shape10" x="416.0" y="376.0"/>
          </dragpoints>
        </shape>
        <shape image="message_icon" name="shape3" shapetype="message" userlabel="This step populates whatever arbitrary content we specify as the downstream document" x="1584.0" y="48.0">
          <configuration>
            <message combined="false">
              <msgTxt>We can populate arbitrary content into the body of this message shape and can populate variables with a format of {1}.

Furthermore we can shift in and out of "variable recognition mode" with a single quote (e.g. if we want to populate arbitrary json in here)

Example:
'
{"first":"hello world",
"second":"'{2}'"}</msgTxt>
              <msgParameters>
                <parametervalue key="0" valueType="track">
                  <trackparameter defaultValue="" propertyId="dynamicdocument.DDP_USERNAME" propertyName="Dynamic Document Property - DDP_USERNAME"/>
                </parametervalue>
                <parametervalue key="1" valueType="profile">
                  <profileelement elementId="9" elementName="phone (Root/Object/phone)" profileId="75c5b9ff-7e48-40f5-91e7-a4703caa86df" profileType="profile.json"/>
                </parametervalue>
              </msgParameters>
            </message>
          </configuration>
          <dragpoints>
            <dragpoint name="shape3.dragpoint1" toShape="shape6" x="1760.0" y="56.0"/>
          </dragpoints>
        </shape>
        <shape image="documentproperties_icon" name="shape4" shapetype="documentproperties" userlabel="Sets example DDPs and DPPs" x="432.0" y="48.0">
          <configuration>
            <documentproperties>
              <documentproperty defaultValue="" isDynamicCredential="false" isTradingPartner="false" name="Dynamic Document Property - DDP_USERNAME" persist="false" propertyId="dynamicdocument.DDP_USERNAME" shouldEncrypt="false">
                <sourcevalues>
                  <parametervalue key="5" valueType="static">
                    <staticparameter staticproperty="ccapp"/>
                  </parametervalue>
                </sourcevalues>
              </documentproperty>
              <documentproperty defaultValue="" isDynamicCredential="false" isTradingPartner="false" name="Dynamic Document Property - DDP_EXAMPLE_DATETIME_PROP" persist="false" propertyId="dynamicdocument.DDP_EXAMPLE_DATETIME_PROP" shouldEncrypt="false">
                <sourcevalues>
                  <parametervalue key="6" valueType="date">
                    <dateparameter dateparametertype="current" datetimemask="yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"/>
                  </parametervalue>
                </sourcevalues>
              </documentproperty>
            </documentproperties>
          </configuration>
          <dragpoints>
            <dragpoint name="shape4.dragpoint1" toShape="shape7" x="608.0" y="56.0"/>
          </dragpoints>
        </shape>
        <shape image="connectoraction_icon" name="shape5" shapetype="connectoraction" userlabel="" x="816.0" y="48.0">
          <configuration>
            <connectoraction actionType="GET" allowDynamicCredentials="NONE" connectionId="9ec1815c-98ea-49d2-a0eb-627906e0f593" connectorType="officialboomi-X3979C-rest-prod" hideSettings="false" operationId="41e9dc91-ebdb-4dd4-9c4b-2344a3e183be">
              <parameters/>
              <dynamicProperties>
                <propertyvalue childKey="" key="path" name="Path" valueType="track">
                  <trackparameter defaultValue="" propertyId="dynamicdocument.DDP_PATH" propertyName="Dynamic Document Property - DDP_PATH"/>
                </propertyvalue>
              </dynamicProperties>
            </connectoraction>
          </configuration>
          <dragpoints>
            <dragpoint name="shape5.dragpoint1" toShape="shape8" x="992.0" y="56.0"/>
          </dragpoints>
        </shape>
        <shape image="message_icon" name="shape6" shapetype="message" userlabel="An empty message shape will clear the content and carry on with an empty docuemtn" x="1776.0" y="48.0">
          <configuration>
            <message combined="false">
              <msgTxt/>
              <msgParameters/>
            </message>
          </configuration>
          <dragpoints>
            <dragpoint name="shape6.dragpoint1" toShape="shape9" x="1952.0" y="56.0"/>
          </dragpoints>
        </shape>
        <shape image="documentproperties_icon" name="shape7" shapetype="documentproperties" userlabel="Prepares DDP_PATH for rest client" x="624.0" y="48.0">
          <configuration>
            <documentproperties>
              <documentproperty defaultValue="" isDynamicCredential="false" isTradingPartner="false" name="Dynamic Document Property - DDP_PATH" persist="false" propertyId="dynamicdocument.DDP_PATH" shouldEncrypt="false">
                <sourcevalues>
                  <parametervalue key="1" valueType="static">
                    <staticparameter staticproperty="/user/"/>
                  </parametervalue>
                  <parametervalue key="2" valueType="track">
                    <trackparameter defaultValue="" propertyId="dynamicdocument.DDP_USERNAME" propertyName="Dynamic Document Property - DDP_USERNAME"/>
                  </parametervalue>
                </sourcevalues>
              </documentproperty>
            </documentproperties>
          </configuration>
          <dragpoints>
            <dragpoint name="shape7.dragpoint1" toShape="shape5" x="800.0" y="56.0"/>
          </dragpoints>
        </shape>
        <shape image="notify_icon" name="shape8" shapetype="notify" userlabel="Notify shapes can show useful info about the data in a process" x="1008.0" y="48.0">
          <configuration>
            <notify disableEvent="true" enableUserLog="false" perExecution="false" title="">
              <notifyMessage>Response from GET: {1}</notifyMessage>
              <notifyMessageLevel>INFO</notifyMessageLevel>
              <notifyParameters>
                <parametervalue key="0" valueType="current"/>
              </notifyParameters>
            </notify>
          </configuration>
          <dragpoints>
            <dragpoint name="shape8.dragpoint1" toShape="shape14" x="1184.0" y="56.0"/>
          </dragpoints>
        </shape>
        <shape image="stop_icon" name="shape9" shapetype="stop" x="1968.0" y="48.0">
          <configuration>
            <stop continue="true"/>
          </configuration>
          <dragpoints/>
        </shape>
        <shape image="notify_icon" name="shape10" shapetype="notify" userlabel="" x="432.0" y="368.0">
          <configuration>
            <notify disableEvent="true" enableUserLog="false" perExecution="false" title="">
              <notifyMessage>The data that reaches the branch shape is passed into all branches. Manipulations of document, and document properties are not carried from branch 1 into branch 2.

Dynamic Process Properties from a previous branch are carried into subsequent branches. E.g. {1}</notifyMessage>
              <notifyMessageLevel>INFO</notifyMessageLevel>
              <notifyParameters>
                <parametervalue key="0" valueType="process">
                  <processparameter processproperty="DPP_SAMPLE_PROCESS_PROP" processpropertydefaultvalue=""/>
                </parametervalue>
              </notifyParameters>
            </notify>
          </configuration>
          <dragpoints>
            <dragpoint name="shape10.dragpoint1" toShape="shape11" x="608.0" y="376.0"/>
          </dragpoints>
        </shape>
        <shape image="dataprocess_icon" name="shape11" shapetype="dataprocess" userlabel="Example groovy script" x="624.0" y="368.0">
          <configuration>
            <dataprocess>
              <step index="1" key="1" name="Custom Scripting" processtype="12">
                <dataprocessscript language="groovy2" useCache="true">
                  <script>import java.util.Properties;
import java.io.InputStream;

for( int i = 0; i &lt; dataContext.getDataCount(); i++ ) {
    InputStream is = dataContext.getStream(i);
    Properties props = dataContext.getProperties(i);

    dataContext.storeStream(is, props);
}</script>
                </dataprocessscript>
              </step>
            </dataprocess>
          </configuration>
          <dragpoints>
            <dragpoint name="shape11.dragpoint1" toShape="shape12" x="800.0" y="376.0"/>
          </dragpoints>
        </shape>
        <shape image="stop_icon" name="shape12" shapetype="stop" x="816.0" y="368.0">
          <configuration>
            <stop continue="true"/>
          </configuration>
          <dragpoints/>
        </shape>
        <shape image="documentproperties_icon" name="shape14" shapetype="documentproperties" userlabel="Sets example DPPs" x="1200.0" y="48.0">
          <configuration>
            <documentproperties>
              <documentproperty defaultValue="" isDynamicCredential="false" isTradingPartner="false" name="Dynamic Process Property - DPP_SAMPLE_PROCESS_PROP" persist="false" propertyId="process.DPP_SAMPLE_PROCESS_PROP" shouldEncrypt="false">
                <sourcevalues>
                  <parametervalue key="7" valueType="profile">
                    <profileelement elementId="6" elementName="lastName (Root/Object/lastName)" profileId="75c5b9ff-7e48-40f5-91e7-a4703caa86df" profileType="profile.json"/>
                  </parametervalue>
                  <parametervalue key="8" valueType="static">
                    <staticparameter staticproperty=", "/>
                  </parametervalue>
                  <parametervalue key="6" valueType="profile">
                    <profileelement elementId="5" elementName="firstName (Root/Object/firstName)" profileId="75c5b9ff-7e48-40f5-91e7-a4703caa86df" profileType="profile.json"/>
                  </parametervalue>
                </sourcevalues>
              </documentproperty>
            </documentproperties>
          </configuration>
          <dragpoints>
            <dragpoint name="shape14.dragpoint1" toShape="shape15" x="1376.0" y="56.0"/>
          </dragpoints>
        </shape>
        <shape image="branch_icon" name="shape15" shapetype="branch" x="1392.0" y="48.0">
          <configuration>
            <branch numBranches="2"/>
          </configuration>
          <dragpoints>
            <dragpoint identifier="1" name="shape15.dragpoint1" text="1" toShape="shape3" x="1568.0" y="56.0"/>
            <dragpoint identifier="2" name="shape15.dragpoint2" text="2" toShape="shape16" x="1568.0" y="216.0"/>
          </dragpoints>
        </shape>
        <shape image="map_icon" name="shape16" shapetype="map" userlabel="" x="1584.0" y="208.0">
          <configuration>
            <map mapId="b54f4cd0-9b04-41e0-8fce-66a03aa2ce86"/>
          </configuration>
          <dragpoints>
            <dragpoint name="shape16.dragpoint1" toShape="shape17" x="1760.0" y="216.0"/>
          </dragpoints>
        </shape>
        <shape image="stop_icon" name="shape17" shapetype="stop" x="1776.0" y="208.0">
          <configuration>
            <stop continue="true"/>
          </configuration>
          <dragpoints/>
        </shape>
      </shapes>
    </process>
  </bns:object>
  <bns:processOverrides/>
</bns:Component>