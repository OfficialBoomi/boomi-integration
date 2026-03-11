# Event Streams Steps

## Contents
- Purpose
- Event Streams Listener Step
- Event Streams Producer Step
- Event Streams Consumer Step
- Component Dependencies
- Common Patterns
- Testing Considerations

## Purpose
Event Streams steps enable publish/subscribe messaging between processes and external systems. Listen operations provide event-driven processing, Consume operations provide on-demand message retrieval, and Produce operations publish messages to topics. Boomi event streams runs in the cloud external to a runtime/atom.

**Use when:**
- Building event-driven architectures (Listen)
- Asynchronous communication between processes
- Decoupling systems via pub/sub patterns
- Processing messages in real-time or on-demand batches
- Publishing events for downstream consumers

**Architectural choice:** Listen (continuous, event-driven) vs Consume (on-demand, scheduled) affects entire process design.

## Event Streams Listener Step (Start Shape)

Used as a Start step to listen for messages from an Event Streams subscription.

### XML Structure

```xml
<shape shapetype="start" x="96" y="94">
  <configuration>
    <connectoraction actionType="Listen" 
                     allowDynamicCredentials="NONE" 
                     connectionId="[connection_guid]" 
                     connectorType="officialboomi-X3979C-events-prod" 
                     hideSettings="false" 
                     operationId="[listen_operation_guid]">
      <parameters/>
      <dynamicProperties/>
    </connectoraction>
  </configuration>
  <dragpoints>
    <dragpoint name="shape1.dragpoint1" toShape="shape2"/>
  </dragpoints>
</shape>
```

### Key Attributes

| Attribute | Value | Notes |
|-----------|-------|-------|
| shapetype | "start" | Listener is always a Start step |
| actionType | "Listen" | |
| connectorType | "officialboomi-X3979C-events-prod" | Identifies Event Streams connector |

### Process-Level Configuration for Event Streams Listener

When using Event Streams Listen as a start step, the process element should include:
```xml
<process allowSimultaneous="true" enableUserLog="false" processLogOnErrorOnly="false" purgeDataImmediately="false" updateRunDates="false" workload="general">
```
- **allowSimultaneous="true"**: Allows multiple concurrent event deliveries to be processed.
- **updateRunDates="false"**: Event-driven processes should not track run dates (performance cost per execution).

See `components/process_component.md` for the full decision table of recommended process options by start step type.

## Event Streams Producer Step

Used to publish messages to an Event Streams topic.

### XML Structure

```xml
<shape shapetype="connectoraction" x="416" y="96">
  <configuration>
    <connectoraction actionType="Produce" 
                     allowDynamicCredentials="NONE" 
                     connectionId="[connection_guid]" 
                     connectorType="officialboomi-X3979C-events-prod" 
                     hideSettings="false" 
                     operationId="[produce_operation_guid]">
      <parameters/>
      <dynamicProperties/>
    </connectoraction>
  </configuration>
  <dragpoints>
    <dragpoint name="shape3.dragpoint1" toShape="[next_shape]"/>
  </dragpoints>
</shape>
```

### Key Attributes

| Attribute | Value | Notes |
|-----------|-------|-------|
| shapetype | "connectoraction" | Standard connector step |
| actionType | "Produce" | |
| connectorType | "officialboomi-X3979C-events-prod" | Identifies Event Streams connector |

## Event Streams Consumer Step

Used to pull messages from an Event Streams subscription on demand. Can be used as either a Start step or mid-process connector step.

### XML Structure (as Connector Step)

```xml
<shape shapetype="connectoraction" x="384" y="304">
  <configuration>
    <connectoraction actionType="Consume" 
                     allowDynamicCredentials="NONE" 
                     connectionId="[connection_guid]" 
                     connectorType="officialboomi-X3979C-events-prod" 
                     hideSettings="false" 
                     operationId="[consume_operation_guid]">
      <parameters/>
      <dynamicProperties/>
    </connectoraction>
  </configuration>
  <dragpoints>
    <dragpoint name="shape4.dragpoint1" toShape="[next_shape]"/>
  </dragpoints>
</shape>
```

### Key Attributes

| Attribute | Value | Notes |
|-----------|-------|-------|
| shapetype | "connectoraction" or "start" | Can be either type |
| actionType | "Consume" | |
| connectorType | "officialboomi-X3979C-events-prod" | Identifies Event Streams connector |

## Operation Type Comparison

| Operation | Step Type | Behavior | Key Use Case |
|-----------|-----------|----------|--------------|
| Listen | Start only | Continuous listening | Event-driven processes |
| Consume | Start or Connector | On-demand pull | Batch processing, controlled polling |
| Produce | Connector only | Send messages | Publishing events |

## Notes

- All operations reference the same connection component type
- Listener must be configured as Start step
- Consumer can be either Start or mid-process step
- Producer can be placed anywhere in process flow (except Start)
- Topic names are statically configured (no dynamic override observed)
- All use `<parameters/>` and `<dynamicProperties/>` elements (can be empty)