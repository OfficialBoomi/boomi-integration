# Flow Control Step

## Contents
- Purpose
- Key Concepts
- Configuration Structure
- Operational Modes
- Building Instructions
- Important Notes
- XML Reference

## Purpose
The Flow Control step controls how documents passing through it are dispatched downstream: one at a time, in batches, or in parallel across multiple threads or runtime processes. It does not transform documents or affect routing — it changes the *cadence* and *concurrency* of the path immediately after it.

Its effect is **point-in-process**, not global. See "Scope of Effect" below.

**Use when:**
- Downstream steps must complete one document (or batch of N documents) before the next begins (e.g., serializing writes to an external system that can't handle interleaved calls)
- Speeding up a slow downstream segment (Map + Connector calls) by spreading documents across parallel threads
- Splitting a large document set into parallel chunks that execute concurrently as fiber executions

## Key Concepts

### Two Independent Knobs
Flow Control combines two independent settings:
1. **Batching** (`forEachCount`) — how the document set is grouped before downstream execution
2. **Parallelism** (`chunks` + `chunkStyle`) — how many parallel workers process the groups

Either can be used alone, or they can be combined. With no settings (defaults), the step is a pass-through.

### Scope of Effect
A Flow Control step controls only the documents passing through *it* at that point in the process. It does not establish a global execution mode for everything downstream.

If a later step emits new documents from a single input — a connector that returns multiple records, a Document Cache lookup that expands one doc into many, a Data Process splitter — those newly-emitted documents are **not** subject to this Flow Control's batching or parallelism. To control the cadence of those new documents, add a second Flow Control step *after* the multiplying step.

### Performance Cost — Use Sparingly
Flow Control adds runtime memory and execution overhead. Don't add one unless its specific batching or parallelism behavior is required for the work downstream. Per-document mode (`forEachCount="1"`) is the most expensive setting and slows any process significantly. Parallel fibers add JVM coordination overhead and isolate state in ways that can complicate subsequent steps (see Document Cache note below). Reach for Flow Control to solve a concrete problem — not preemptively.

### Batching Semantics (`forEachCount`)
- `0` — No document batching. The full document set passes downstream and **each downstream step is invoked exactly once with all documents at once** (default). Per-document operations like Notify message substitution or Map iteration happen inside that single shape invocation.
- `1` — Run each document individually. **The full downstream pipeline runs once per input document** — each downstream step is invoked separately for each document, with a single-document payload each time.
- `N` (≥2) — Run as batches of N documents (N is the value typed into the GUI's "Run as batches of [_] documents" field). The input document set is divided into batches of N documents — the last batch may be smaller if the total isn't evenly divisible. Each downstream step is invoked once per batch, and the full pipeline runs once per batch.

### Parallelism Semantics (`chunks` + `chunkStyle`)
- `chunks="0"` or `chunks="1"` — No parallel processing (default).
- `chunks="N"` (≥2) — Spawn N parallel "fibers" (see Fiber Executions below). The document set is divided across the N fibers, and each fiber executes the downstream path concurrently.
- `chunkStyle="threadOnly"` — Fibers run as threads within the same runtime JVM (default).
- `chunkStyle="multiProcess"` — Fibers run as separate JVM processes. Requires a Runtime Cluster; falls back to threads when the runtime can't fork a process.

### Fiber Executions
When `chunks` ≥ 2, downstream steps run inside "fiber executions" — sub-executions launched at the Flow Control step. Each fiber receives its share of the document set (roughly `ceil(N_docs / chunks)` documents) and runs the downstream path independently. The controlling execution pauses at the Flow Control step and only completes after every fiber has finished.

**How fibers surface in the execution log:**
- **Distinct execution IDs.** Each fiber gets its own `execution-<uuid>` identifier, recorded in the parent's process log as `Launching Flow Control Shape fiber f_N as <executionId> with N document(s).`
- **Inline log integration.** Fibers do NOT appear as separate `ExecutionRecord` entries in the platform's execution-query API. Their entire log output is embedded within the parent's process log, delineated by `Executing Process X (Continuation f_N)` headers and matching `cleanup...` footers.
- **No separate log download.** The standard log-download API does not return a separate archive for a fiber's execution ID — fiber output lives inside the parent's log file. To inspect what a fiber did, download the parent execution's log and read the `Continuation f_N` sections corresponding to that fiber.
- **Deferred parent FC step completion.** The parent's Flow Control step logs `Launching fiber...` once per fiber up-front, then the fiber Continuations execute, and the parent's FC step's `Shape executed successfully` line only appears once *all* fibers finish — a visible confirmation that the controlling execution waited.

### Document Order and Fiber Assignment
When `chunks` ≥ 2:

- **Assignment is deterministic by input position.** With N input documents and `chunks=C`, fiber `f_i` receives documents `i·⌈N/C⌉ + 1` through `(i+1)·⌈N/C⌉` (with the last fiber receiving fewer if N isn't evenly divisible). Run the same configuration twice and the same documents land in the same fibers.
- **Within each fiber, document order is preserved.** Downstream steps inside a fiber see that fiber's documents in input-index order.
- **Across fibers, completion order is not guaranteed.** Fibers run concurrently — if your downstream path has side effects (REST calls, DB writes, file I/O), those effects from `f_1` may interleave with or complete before those from `f_0`. Do not rely on cross-fiber sequencing for side effects.
- **Continuation log sections appear in fiber-launch order in the parent log**, regardless of actual completion timing. Log appearance order is therefore not a reliable proxy for completion order.

**Practical guidance:** if downstream order matters across the full document set, do not use `chunks`. Use `forEachCount` (sequential batches) or rely on a single Connector's batched send semantics.

## Configuration Structure
```xml
<shape image="flowcontrol_icon" name="[shapeName]" shapetype="flowcontrol" userlabel="[display label]" x="[x]" y="[y]">
  <configuration>
    <flowcontrol chunkStyle="[threadOnly|multiProcess]" chunks="[N]" forEachCount="[N]"/>
  </configuration>
  <dragpoints>
    <dragpoint name="[shapeName].dragpoint1" toShape="[target]" x="[x]" y="[y]"/>
  </dragpoints>
</shape>
```

Single outgoing connection. The Flow Control step has exactly one dragpoint regardless of mode.

## Operational Modes

Each mode below shows the relevant attribute combination. `chunkStyle="threadOnly"` is always present in platform-emitted XML.

### Pass-through (default)
```xml
<flowcontrol chunkStyle="threadOnly" chunks="0" forEachCount="0"/>
```
No batching, no parallelism. **Behaves identically to omitting the Flow Control step entirely** — every downstream shape is invoked exactly once with the full document set whether the FC step is present or not. The only effect of an FC step at defaults is two extra log entries (its own `Executing Flow Control Shape` and `executed successfully` lines) and a few milliseconds of execution time. There's no functional reason to use this configuration.

### Run each document individually
```xml
<flowcontrol chunkStyle="threadOnly" forEachCount="1"/>
```
The full downstream pipeline runs once per document. Each downstream step is invoked separately for every document, with a single-document payload each time. Slows the process down — use only when downstream steps require strict per-document serialization.

When this mode is set via the GUI, the platform may omit the `chunks` attribute entirely (rather than emitting `chunks="0"`). Both forms are equivalent — `chunks` defaults to 0.

### Run as batches of N documents
```xml
<flowcontrol chunkStyle="threadOnly" chunks="0" forEachCount="2"/>
```
The document set is divided into batches of `forEachCount` documents (the last batch may be smaller if the total isn't evenly divisible). Each downstream step is invoked once per batch with that batch's documents — the full pipeline runs once per batch.

### Parallel processing (N threads)
```xml
<flowcontrol chunkStyle="threadOnly" chunks="4" forEachCount="0"/>
```
The document set is divided across `chunks` parallel threads; each thread runs the downstream path concurrently as a fiber execution.

### Parallel processing (N processes)
```xml
<flowcontrol chunkStyle="multiProcess" chunks="4" forEachCount="0"/>
```
Same as parallel threads, but each fiber runs as a separate JVM process. Requires a Runtime Cluster — falls back to threads on runtimes that can't fork.

### Combined batching + parallel
Batching and parallelism can both be set. Each fiber receives a portion of the document set and applies the batching rule within its own fiber.

## Building Instructions

### Step 1: Decide Which Knobs Matter
Pick a single mode from Operational Modes above. If you only need batching, leave `chunks="0"`. If you only need parallelism, leave `forEachCount="0"`. Don't enable parallelism unless the downstream segment is genuinely slow per-document — fibers add overhead.

### Step 2: Set chunkStyle Explicitly
Always emit `chunkStyle="threadOnly"` (or `multiProcess`) even when chunks is 0. Platform-emitted XML always carries this attribute.

### Step 3: Match Connection
Single outgoing dragpoint to the next step. No additional wiring required.

## Important Notes

- **Number of Threads ≤ 1 means no parallel processing.** Setting `chunks="1"` is equivalent to `chunks="0"` — neither produces parallel fibers.
- **Boomi Cloud runtime thread cap:** When running on a Boomi Cloud runtime, the maximum value for `chunks` is 10.
- **State propagates back to parent in threadOnly fibers.** With `chunkStyle="threadOnly"` (the default), both DPP writes and Document Cache writes performed inside fibers are visible to the controlling execution after all fibers complete. When multiple concurrent fibers write to the same DPP key or cache key, write order is determined by fiber completion timing — design for this when conflicting writes are possible.
- **Display name:** Set `userlabel` on the `<shape>` element. The `<flowcontrol>` element itself has no `name` attribute.

## XML Reference

### Per-document execution
```xml
<shape image="flowcontrol_icon" name="shape7" shapetype="flowcontrol" userlabel="Run each document individually" x="656.0" y="208.0">
  <configuration>
    <flowcontrol chunkStyle="threadOnly" forEachCount="1"/>
  </configuration>
  <dragpoints>
    <dragpoint name="shape7.dragpoint1" toShape="shape8" x="832.0" y="216.0"/>
  </dragpoints>
</shape>
```

### Batches of N
```xml
<shape image="flowcontrol_icon" name="shape10" shapetype="flowcontrol" userlabel="Run as batches of 2 documents" x="656.0" y="368.0">
  <configuration>
    <flowcontrol chunkStyle="threadOnly" chunks="0" forEachCount="2"/>
  </configuration>
  <dragpoints>
    <dragpoint name="shape10.dragpoint1" toShape="shape11" x="832.0" y="376.0"/>
  </dragpoints>
</shape>
```

### Parallel threads
```xml
<shape image="flowcontrol_icon" name="shape13" shapetype="flowcontrol" userlabel="Parallel processing with 4 threads" x="656.0" y="528.0">
  <configuration>
    <flowcontrol chunkStyle="threadOnly" chunks="4" forEachCount="0"/>
  </configuration>
  <dragpoints>
    <dragpoint name="shape13.dragpoint1" toShape="shape14" x="832.0" y="536.0"/>
  </dragpoints>
</shape>
```
