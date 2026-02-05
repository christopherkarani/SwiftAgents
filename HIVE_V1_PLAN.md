# Hive v1 Plan (Swift port of LangGraph core runtime)

Hive is a Swift 6.2, Swift Concurrency–first, strongly typed **graph runtime** inspired by LangGraph’s “channels + reducers + supersteps” execution model. v1 targets **iOS + macOS**, runs **in-process**, and emphasizes:

- **Type safety** (compile-time safe reads/writes)
- **Deterministic execution** (reproducible results and traces)
- **Streaming** (first-class event stream for UI)
- **Checkpointing/memory** (via `Wax`)
- **Pluggable inference + tools** (via `Conduit` + `Swarm` adapters)

This document is intentionally verbose: it is a build-spec for coding agents that need clear semantics, interfaces, and testable milestones.

---

## Locked v1 decisions (do not revisit during implementation)

These are the decisions Hive v1 is built around. Coding agents must treat these as constraints.

### Platform + language

- Swift: **Swift 6.2**
- Deployment targets: **iOS 17.0**, **macOS 14.0**

Rationale: this keeps the concurrency and Foundation surface modern and eliminates conditional availability workarounds that slow down the port.

### Runtime semantics

- Execution model: **supersteps** (run frontier tasks concurrently → deterministically commit writes → compute next frontier).
- Determinism: **guaranteed** by stable task ordering and stable write application ordering (never depend on task completion timing).
- Routers: **synchronous only** in v1 (`(Store) -> Next`); async routers are out of scope.
- Fan-out / Send: **required** in v1; map-reduce patterns must work.

### Reliability + control flow

- Error policy: **retry if configured, otherwise fail-fast**.
- Interrupt/resume (human-in-the-loop): **included in v1** and checkpoint-backed.

### Streaming + observability

- Streaming API: **`AsyncThrowingStream<HiveEvent>` only** in v1.
- Event ordering: **deterministic** (buffer per step and emit in stable order).
- Redaction: **on by default** (values are hashed/summarized; full payload requires explicit debug mode).

### Checkpointing (Wax)

- Persistence model: **full snapshot** (global store + frontier + local overlays).
- Encoding rule: **checkpointing requires codecs** for all persisted channels; missing codecs are a runtime configuration error before execution starts.

### Swarm deliverables

- `HiveSwarm` ships `HiveAgents.makeToolUsingChatAgent(...)` and the façade runtime APIs (`sendUserMessage`, `resumeToolApproval`).
- The prebuilt agent graph is the default “works out of the box” path and is documented and fully covered by tests.

---

## 0) What “core runtime” means (v1 scope)

LangGraph’s implementation is Pregel-inspired: nodes read from channels, write to channels, and state updates merge with reducers across “supersteps”. Hive v1 ports that **core runtime shape**, but with a Swift-idiomatic design that uses:

- value types
- generics
- protocols
- explicit dependency injection
- strict concurrency (`Sendable`, cancellation)

### Included in v1

- Graph builder + compilation (`compile()` yields an immutable executable graph)
- Schema-defined **typed channels** with reducers and initial values
- Task + step (“superstep”) executor:
  - bounded parallel node execution
  - deterministic write application
  - deterministic event ordering
  - `maxSteps` safety
  - cancellation-aware
- “Send”/fan-out style dynamic task spawning (needed for map-reduce patterns)
- Streaming events (`AsyncThrowingStream`)
- Checkpoint store protocol + `Wax` implementation
- Adapter surface for model/tool integrations (without coupling core)

### Explicitly deferred (v1.1+)

- Server / distributed runtime
- Full parity with Python/JS public APIs
- Rich channel types like barriers/consumption semantics
- Graph visualization export (Mermaid), UI tooling
- Postgres/SQLite checkpointers

---

## 1) Principles and why they matter (deep review)

### 1.1 Type safety: embrace schema-defined channels

Python LangGraph can accept “state as dict” and reducers via runtime annotation. Hive does not replicate that dynamic style. Hive uses a **schema** that declares channels as typed keys. This yields:

- compile-time safe access (`HiveChannelKey<Value>`)
- discoverable APIs (autocomplete)
- better performance (avoid reflection and runtime key lookups)

### 1.2 Determinism is non-negotiable

If Hive can’t replay deterministically, debugging multi-step agent workflows becomes painful. Determinism must be enforced even when tasks finish out-of-order due to concurrency.

We accomplish this by splitting execution into:

- **compute phase**: run tasks concurrently, collect writes and events
- **commit phase**: apply writes in a deterministic order (stable sort), then emit events in a deterministic order (stable sort)

**Determinism boundary (v1)**  
Hive guarantees deterministic scheduling, commit order, and event ordering **given identical node outputs and identical external responses**.  
LLM/tool I/O is inherently non-deterministic; full replay determinism requires a record/replay layer (explicitly **deferred** beyond v1).

### 1.3 Explicit semantics beat implicit triggers

LangGraph internally uses channel “versions_seen” and triggers. That design is powerful, but also more dynamic and harder to make type-safe in Swift.

Hive v1 defines a clear, explicit model:

- the scheduler tracks an **active task frontier**
- edges/routers determine the next frontier
- tasks read a snapshot of global state + per-task local overrides (for `Send` fan-out)
- tasks return writes; reducers merge them into the next global snapshot

This keeps the mental model stable and testable, while still supporting the common LangGraph workflows (loops, conditional routing, map-reduce fan-out).

### 1.4 “Send” / fan-out is a core differentiator

LangGraph’s `Send(node, arg)` is essential for map-reduce (parallel calls into the same node with different task-local state). Without this, Hive would be “just a state machine”.

Therefore v1 must include a first-class task concept that supports **per-task local input**.

---

## 2) Glossary (shared language for implementers)

- **Schema**: A type that declares all channels the graph may read/write.
- **Channel**: A typed slot of state (value, reducer, initial value, and a codec used for checkpointing).
- **Reducer**: A merge function used when multiple writes target the same channel in a step.
- **Global store**: The persisted, checkpointed state snapshot for a run.
- **Local store**: Per-task overlay state used for `Send`/fan-out inputs.
- **Write**: A typed update to a channel produced by a task.
- **Task**: Execution unit = node + local store overlay + task ID.
- **Step / superstep**: One scheduler iteration; all tasks in the frontier execute, then writes commit.
- **Frontier**: The set of tasks scheduled for the next step.
- **Router**: A deterministic function that chooses next task(s) based on state.
- **Checkpoint**: Persisted snapshot (global store + frontier + metadata) used to resume.

---

## 3) LangGraph → Hive mapping (conceptual, not API parity)

| LangGraph concept | Hive concept (v1) | Why |
|---|---|---|
| `StateGraph` (builder) | `HiveGraphBuilder<Schema>` | Clear “build then compile” lifecycle |
| `Pregel` (executable) | `CompiledHiveGraph<Schema>` | Immutable graph for execution |
| state dict | `HiveGlobalStore<Schema>` | Typed channels, no dynamic dict |
| reducer annotations | `HiveReducer<Value>` on `HiveChannelSpec` | Type-safe reducer attachment |
| `Send(node, arg)` | `HiveTask<Schema>(node:, local:)` | Type-safe map-reduce fan-out |
| streaming modes | `HiveEvent` stream | One structured event model beats many modes |
| checkpointer | `HiveCheckpointStore` + `HiveCheckpointPolicy` | Pluggable + testable |

---

## 4) Repository + module layout (for a production-quality Swift port)

Create `libs/hive` as a SwiftPM workspace root.

### 4.1 Targets

- `HiveCore`
  - zero knowledge of Wax/Conduit/Swarm
  - contains runtime and public API surface
- `HiveCheckpointWax`
  - depends on `HiveCore` + `Wax`
  - provides `WaxCheckpointStore`
- `HiveConduit`
  - depends on `HiveCore` + `Conduit`
  - provides `ConduitModelClient` + Conduit → Hive events mapping
- `HiveSwarm`
  - depends on `HiveCore` + `Swarm`
  - provides tool registry and convenience nodes

### 4.2 File structure

Within `libs/hive/Sources/HiveCore/`:

- `Schema/`
  - `HiveSchema.swift`
  - `HiveChannelKey.swift`
  - `HiveChannelSpec.swift`
  - `HiveReducer.swift`
  - `HiveCodec.swift` (for checkpointing)
- `Graph/`
  - `HiveNodeID.swift`
  - `HiveTaskID.swift`
  - `HiveTask.swift`
  - `HiveGraphBuilder.swift`
  - `CompiledHiveGraph.swift`
- `Runtime/`
  - `HiveRuntime.swift`
  - `HiveRunOptions.swift`
  - `HiveRunResult.swift`
  - `HiveEnvironment.swift`
  - `HiveEvent.swift`
- `Checkpointing/`
  - `HiveCheckpoint.swift`
  - `HiveCheckpointStore.swift`
  - `HiveCheckpointPolicy.swift`
- `Errors/`
  - `HiveError.swift`
  - `HiveCompilationError.swift`
  - `HiveRuntimeError.swift`

Tests: `libs/hive/Tests/HiveCoreTests/` grouped similarly.

---

## 5) Core data model (type-safe channels + store)

### 5.1 Schema and channel keys

We want schema definitions that:

- are simple to write
- require minimal boilerplate
- maximize compile-time correctness

Define:

```swift
public protocol HiveSchema: Sendable {
  /// Immutable, run-scoped context exposed to every node.
  associatedtype Context: Sendable = Void

  /// Payload emitted when a node interrupts execution.
  /// Must be checkpointable.
  associatedtype InterruptPayload: Codable & Sendable = String

  /// Payload provided when resuming after an interrupt.
  /// Must be checkpointable.
  associatedtype ResumePayload: Codable & Sendable = String
op
  /// Central declaration list used for validation and checkpoint encoding.
  static var channelSpecs: [AnyHiveChannelSpec<Self>] { get }
}

public struct HiveChannelKey<Value: Sendable>: Hashable, Sendable {
  public let id: HiveChannelID
  public init(_ id: HiveChannelID) { self.id = id }
}

public struct HiveChannelID: Hashable, Sendable {
  public let rawValue: String
  public init(_ rawValue: String) { self.rawValue = rawValue }
}
```

**Why string IDs?**

- stable across process runs (required for checkpointing and debugging)
- human-readable in event streams
- deterministic ordering (lexicographic)

Standardize channel IDs via namespacing: `"messages"`, `"agent.plan"`, `"internal.tasks"`.

**Key integrity rule (v1)**  
Channel IDs must be **globally unique and type-consistent** across a schema.  
Hive will maintain a runtime type registry (ID → type witness) and treat mismatches as a **runtime configuration error** (debug trap in debug builds, typed error in release).  
Keys should be declared once (as static schema members) to avoid ad-hoc ID construction.

### 5.2 Channel spec (value + reducer + initial + codec + scope)

To support `Send`/fan-out, Hive uses **channel scope**:

- `.global`: persisted and reduced into the global store
- `.taskLocal`: per-task overlay only; persisted with the frontier

```swift
public enum HiveChannelScope: Sendable { case global, taskLocal }

public struct HiveChannelSpec<Schema: HiveSchema, Value: Sendable>: Sendable {
  public let key: HiveChannelKey<Value>
  public let scope: HiveChannelScope
  public let reducer: HiveReducer<Value>
  public let initial: @Sendable () -> Value
  public let codec: HiveAnyCodec<Value>?
}
```

**Why include codec at the channel level?**

Checkpointing requires serialization. In Swift, not every `Sendable` is `Codable`, especially when integrating with libraries.
By making encoding explicit and per-channel, we get:

- compile-time ergonomics: `HiveCodec.codable()` helper for `Codable` values
- flexibility: custom codecs for non-codable types
- predictable persistence failures (checkpoint-backed runs fail early when codecs are missing)

### 5.3 Store design (global + local overlay)

We need two store layers:

1) `HiveGlobalStore<Schema>`: persisted, reducer-merged, checkpointed
2) `HiveTaskLocalStore<Schema>`: per-task overlay used for `Send` inputs

HiveTaskLocalStore also exposes a deterministic `fingerprint`:

- The fingerprint is computed by encoding all `.taskLocal` channel values with their codecs, sorting by `HiveChannelID`, and concatenating into a canonical `Data` blob.
- The runtime uses this fingerprint as part of the task identity to deduplicate converging edges: `(nodeID, localFingerprint)`.

Nodes read from a composed view:

- read checks local first (if key scope is `.taskLocal`), otherwise reads global
- writes target either global or local depending on key scope (and/or explicit API)

Implementation detail (type erasure):

- internal storage will use a dictionary keyed by `HiveChannelID`
- values stored as type-erased boxes (`AnySendable`)
- typed API ensures casts are safe; still add debug traps for mismatches

This is a classic “type-safe facade over type-erased storage” approach.

---

## 6) Reducers: merge semantics + determinism

### 6.1 Reducer protocol and type erasure

```swift
public struct HiveReducer<Value: Sendable>: Sendable {
  private let _reduce: @Sendable (Value, Value) -> Value
  public init(_ reduce: @escaping @Sendable (Value, Value) -> Value) { self._reduce = reduce }
  public func reduce(current: Value, update: Value) -> Value { _reduce(current, update) }
}
```

### 6.2 Standard reducers (v1 set)

- `lastWriteWins(order:)` (order is deterministic by runtime)
- `append()` for arrays
- `appendNonNil()` for optionals
- `setUnion()`
- `dictionaryMerge(valueReducer:)`

### 6.3 Deterministic commit order (spec)

Within a step:

- tasks execute concurrently and produce writes
- the runtime commits writes by:
  1) stable sort tasks by `(step, nodeID, taskIndex)` **not by completion time**
  2) within each task, preserve write emission order
  3) group writes by channel, apply reducer sequentially in that deterministic order

This provides deterministic outputs even when task execution is concurrent.

---

## 7) Tasks, nodes, edges, routers (this is the key missing piece from the earlier draft)

### 7.1 Task = node + local input overlay

`Send(node, arg)` in LangGraph is best modeled as a task with local overlay values.

```swift
public struct HiveTask<Schema: HiveSchema>: Sendable {
  public let id: HiveTaskID
  public let node: HiveNodeID
  public let local: HiveTaskLocalStore<Schema>
}
```

The scheduler frontier is `[HiveTask<Schema>]`, not just `[HiveNodeID]`.

### 7.2 Node signature and output

Nodes are pure with respect to Hive state: they receive an immutable snapshot view and return explicit outputs (writes + spawned tasks + routing).

```swift
public typealias HiveNode<Schema: HiveSchema> =
  @Sendable (HiveNodeInput<Schema>) async throws -> HiveNodeOutput<Schema>
```

`HiveNodeInput` contains:

- `store`: composed view of (global + local)
- `run`: run/task metadata and resume input
- `context`: run-scoped immutable context (`Schema.Context`)
- `emit`: event sink for custom events (captured deterministically)
- injected dependencies (model client, tool registry, clock, logger)

HiveCore defines a concrete run context type:

```swift
public struct HiveRunID: Hashable, Codable, Sendable {
  public let rawValue: UUID
  public init(_ rawValue: UUID) { self.rawValue = rawValue }
}

public struct HiveThreadID: Hashable, Codable, Sendable {
  public let rawValue: String
  public init(_ rawValue: String) { self.rawValue = rawValue }
}

public struct HiveRunContext<Schema: HiveSchema>: Sendable {
  public let runID: HiveRunID
  public let threadID: HiveThreadID
  public let stepIndex: Int
  public let taskID: HiveTaskID
  public let resume: HiveResume<Schema>?
}
```

`HiveNodeOutput` contains:

- `writes`: `[AnyHiveWrite<Schema>]`
- `spawn`: `[HiveTask<Schema>]` (for fan-out / Send)
- `next`: `HiveNext` (routing override; defaults to “use graph edges”)
- `interrupt`: `HiveInterrupt<Schema>?` (halts the run and requires resume input)

**Why both `spawn` and `next`?**

- `spawn` is the `Send` mechanism (dynamic tasks)
- `next` is a routing override for state-machine style flows
- both are needed to cover common LangGraph patterns cleanly

### 7.3 Graph edges and routers

Graph definition supports:

- static edges: from node → node
- conditional routing: from node → router(store) → next node(s)

Routers are:

- synchronous pure functions of store (no side effects)
- deterministic

Routers do not perform async work in v1. Async routing is deferred to a later release.

---

## 8) Runtime semantics (the “superstep” spec)

This section is critical: it tells implementers exactly how Hive runs.

### 8.0 Runtime configuration (`HiveEnvironment` + `HiveRunOptions`)

Hive runtime configuration is split into:

- `HiveEnvironment`: injected dependencies and run-scoped context
- `HiveRunOptions`: execution controls (limits, checkpoint policy, debugging)

**Thread concurrency rule (v1)**  
Operations are **single-writer per `threadID`**. `run`, `resume`, and `applyExternalWrites` are serialized to prevent checkpoint races and “latest checkpoint” corruption.

Define these as stable public API in `HiveCore`.

#### HiveEnvironment

`HiveEnvironment` is passed to `HiveRuntime` and threaded into every `HiveNodeInput`.

- `context`: `Schema.Context`
- `clock`: deterministic clock/sleeper used for retries and timestamps
- `logger`: structured logger used for diagnostics
- `model`: optional model client (used by LLM nodes in adapter modules)
- `tools`: optional tool registry (used by tool nodes in adapter modules)
- `checkpointStore`: optional checkpoint store (Wax-backed in `HiveCheckpointWax`)

HiveCore ships type-erased wrappers so the environment can hold these as values:

- `AnyHiveModelClient`
- `AnyHiveToolRegistry`
- `AnyHiveCheckpointStore<Schema>`

This keeps node APIs non-generic while preserving testability.

#### HiveRunOptions

HiveRunOptions are immutable for a single run and are included in `runStarted` events.

- `maxSteps`: hard cap to prevent infinite loops (default for v1: **100**)
- `maxConcurrentTasks`: bounded concurrency for the frontier (default for v1: **8**)
- `checkpointPolicy`: when to save checkpoints (**`.everyStep`** for prebuilt Swarm graphs)
- `debugPayloads`: when `true`, include full channel payloads in events (default: **false**)

Checkpoint saving is synchronous in v1 (the runtime awaits checkpoint writes before continuing).

Concrete types defined in HiveCore:

```swift
public enum HiveCheckpointPolicy: Sendable {
  case disabled
  case everyStep
  case every(steps: Int)
  case onInterrupt
}

public struct HiveRunOptions: Sendable {
  public let maxSteps: Int
  public let maxConcurrentTasks: Int
  public let checkpointPolicy: HiveCheckpointPolicy
  public let debugPayloads: Bool
}

public protocol HiveClock: Sendable {
  /// Monotonic time source used for backoff and durations.
  func now() -> UInt64
  func sleep(nanoseconds: UInt64) async throws
}

public protocol HiveLogger: Sendable {
  func debug(_ message: String, metadata: [String: String])
  func info(_ message: String, metadata: [String: String])
  func error(_ message: String, metadata: [String: String])
}

public struct HiveEnvironment<Schema: HiveSchema>: Sendable {
  public let context: Schema.Context
  public let clock: any HiveClock
  public let logger: any HiveLogger
  public let model: AnyHiveModelClient?
  public let tools: AnyHiveToolRegistry?
  public let checkpointStore: AnyHiveCheckpointStore<Schema>?
}
```

HiveCore includes:

- `SystemClock` backed by `ContinuousClock`/`Task.sleep`
- `TestClock`/`ManualClock` for deterministic retry/backoff tests
- `NoopLogger` and `PrintLogger` implementations

### 8.1 Inputs and identifiers

Each run has:

- `HiveRunID` (UUID) — **stable across resumes**
- `HiveRunAttemptID` (UUID) — new ID per execution attempt (initial run + each resume)
- `HiveThreadID` (string/UUID) — “conversation/session”
- `stepIndex` (Int)

Each task has:

- `HiveTaskID` derived deterministically from `(runID, stepIndex, nodeID, ordinal)`
  - “ordinal” is stable by ordering in the frontier

### 8.2 Step algorithm (pseudocode)

1. Emit `runStarted` (once)
2. Initialize `globalStore` (from provided initial values or checkpoint)
3. Initialize `frontier` with `start` tasks (usually one task targeting the entry node)
4. For `stepIndex` in `0..<maxSteps`:
   - Emit `stepStarted(stepIndex, frontierSummary)`
   - Execute all tasks in `frontier` with bounded concurrency
     - for each task:
       - emit `taskStarted`
       - run node function
       - capture output (writes, spawn, next override, custom events)
       - emit `taskFinished` / `taskFailed`
   - Commit phase (deterministic):
     - stable sort task outputs by task ordering
     - apply global writes with reducers → new `globalStore`
     - build `nextFrontier` in deterministic order:
       - **spawn tasks** (`Send`) in node emission order (nodes must sort any unordered inputs)
       - **routing overrides** (`next`) in router-returned order
       - **static edges** in builder-defined edge order
     - deduplicate **only static-edge convergence** by `(nodeID, localFingerprint)`; do **not** deduplicate explicit `spawn` tasks (unless a node opts in)
     - validate that every computed task references a known node ID
   - Checkpoint (if enabled by policy)
   - Emit `stepFinished(stepIndex, storeSummary, nextFrontierSummary)`
   - If `nextFrontier` is empty or only `.end`, finish run
5. If `maxSteps` reached, return `.outOfSteps` with snapshot + trace pointer

### 8.3 Cancellation semantics

- If the parent task is cancelled:
  - cancel all running node tasks
  - emit `runCancelled`
  - return `.cancelled(lastCheckpointOrSnapshot)`

### 8.4 Error semantics

Hive v1 error semantics:

- Each node has a `HiveRetryPolicy` (default: `.none`).
- On failure, Hive retries that node according to its policy using a deterministic schedule.
- If retries are exhausted, the run fails immediately (fail-fast).

HiveCore defines:

```swift
public enum HiveRetryPolicy: Sendable {
  case none
  case exponentialBackoff(
    initialNanoseconds: UInt64,
    factor: Double,
    maxAttempts: Int,
    maxNanoseconds: UInt64
  )
}
```

Rules:

- No jitter in v1 (jitter is non-deterministic and is deferred).
- Retries are safe only for nodes that are idempotent or otherwise retry-tolerant.
- Prebuilt Swarm graph nodes set retry policies on model/tool execution nodes; pure routing/state nodes use `.none`.

Retry determinism requirements:

- retries must not break determinism (retry scheduling and backoff should be deterministic in tests using an injected clock/sleeper)

### 8.5 Interrupt + resume semantics (human-in-the-loop)

Hive v1 includes interrupt/resume as a first-class control-flow mechanism and persists interruptions in checkpoints.

#### Core types

HiveCore defines interruption types that are checkpointable and schema-typed:

```swift
public struct HiveInterruptID: Hashable, Codable, Sendable {
  public let rawValue: String
  public init(_ rawValue: String) { self.rawValue = rawValue }
}

public struct HiveInterrupt<Schema: HiveSchema>: Codable, Sendable {
  public let id: HiveInterruptID
  public let payload: Schema.InterruptPayload
}

public struct HiveResume<Schema: HiveSchema>: Codable, Sendable {
  public let interruptID: HiveInterruptID
  public let payload: Schema.ResumePayload
}

public struct HiveInterruption<Schema: HiveSchema>: Codable, Sendable {
  public let interrupt: HiveInterrupt<Schema>
  public let checkpointID: String
}
```

**How a node interrupts**

- A node sets `output.interrupt = HiveInterrupt(id:payload:)`.
- The interrupt payload is `Schema.InterruptPayload` (`Codable & Sendable`) and is always persisted.

**What the runtime does on interrupt**

- Hive completes the current step’s **commit phase** deterministically (writes produced by tasks earlier in deterministic task order are committed).
- Hive emits:
  - `runInterrupted` (includes interrupt id + payload summary)
  - `checkpointSaved` (checkpointing is enabled for the prebuilt Swarm graphs and can be enabled for any graph)
- Hive saves a checkpoint snapshot immediately after commit.
- Hive returns `.interrupted(HiveInterruption)` containing the interrupt and the checkpoint reference.

**How a run resumes**

- Resume input is `Schema.ResumePayload` (`Codable & Sendable`).
- The runtime API provides `resume(threadID:interruptID:payload:)` that:
  - loads the latest checkpoint for `threadID`
  - validates that the stored interruption id matches `interruptID`
  - sets `HiveRunContext.resume = HiveResume(interruptID:payload:)` for the resumed run
  - continues execution from the persisted frontier

Resume is visible to nodes via `HiveRunContext` and is consumed by graph logic (for Swarm prebuilt graphs, the resume payload is converted into a user message and appended to the `messages` channel).

**Deterministic rule**

- If multiple tasks attempt to interrupt in the same step, Hive selects the interrupt from the earliest task in deterministic task order and ignores later interrupts (while still committing deterministic writes).
- Interrupt selection occurs **after all tasks in the step complete**; v1 does not early-abort a step to preserve determinism.

---

## 9) Streaming events (structured observability)

### 9.1 Single event model over “stream modes”

LangGraph has multiple “stream modes”. In Swift, a single strongly typed event stream is clearer.

Define `HiveEvent` with stable IDs and payloads that are safe for UI:

- run lifecycle
- step lifecycle
- task/node lifecycle
- write application (channel + metadata)
- checkpoint saved/loaded
- adapter events (model tokens, tool calls)

HiveCore defines an event model that is stable and deterministic:

```swift
public struct HiveEventID: Hashable, Codable, Sendable {
  public let runID: HiveRunID
  public let attemptID: HiveRunAttemptID
  public let stepIndex: Int
  public let taskOrdinal: Int?   // nil for run/step events
  public let sequence: Int       // monotonic within (stepIndex, taskOrdinal)
}

public struct HiveRunOptionsSummary: Codable, Sendable {
  public let maxSteps: Int
  public let maxConcurrentTasks: Int
  public let checkpointPolicy: String
  public let debugPayloads: Bool
}

public struct HiveRunResultSummary: Codable, Sendable {
  public let outcome: String
  public let stepsExecuted: Int
}

public enum HiveEventKind: Sendable {
  case runStarted(threadID: HiveThreadID, options: HiveRunOptionsSummary)
  case runFinished(result: HiveRunResultSummary)
  case runInterrupted(interruptID: HiveInterruptID)
  case runResumed(interruptID: HiveInterruptID)
  case runCancelled

  case stepStarted
  case stepFinished(nextTaskCount: Int)

  case taskStarted(node: HiveNodeID, taskID: HiveTaskID)
  case taskFinished(node: HiveNodeID, taskID: HiveTaskID)
  case taskFailed(node: HiveNodeID, taskID: HiveTaskID, errorDescription: String)

  case writeApplied(channelID: HiveChannelID, payloadHash: String)
  case checkpointSaved(checkpointID: String)
  case checkpointLoaded(checkpointID: String)

  // Adapter-facing events (emitted by HiveConduit / HiveSwarm nodes).
  case modelInvocationStarted(model: String)
  case modelToken(text: String)
  case modelInvocationFinished

  case toolInvocationStarted(name: String)
  case toolInvocationFinished(name: String, success: Bool)
}

public struct HiveEvent: Sendable {
  public let id: HiveEventID
  public let kind: HiveEventKind
  public let metadata: [String: String]
}
```

Rules:

- The runtime assigns `taskOrdinal` based on deterministic task ordering within the step.
- Nodes emit custom events via `input.emit(...)`; the runtime buffers these and assigns `sequence` values deterministically.
- `errorDescription` is a redacted description suitable for logs/UI. Full error details are included only when debug mode is enabled.

### 9.2 Deterministic event ordering

Events that originate from concurrent task execution must be buffered and emitted in a stable order:

- primary key: `(stepIndex, taskOrder, eventSequence)`
- where `eventSequence` is the order within a task

This avoids UI flakiness and test instability.

### 9.3 Redaction and hashing

Do not dump full channel values by default.

Hive emits:

- channel ID + stable hash (when encodable) + lightweight previews
- full values only when `HiveRunOptions.debugPayloads == true`

### 9.4 Streaming backpressure (v1)

`AsyncThrowingStream` must be created with **bounded buffering** (e.g., `.bufferingNewest(N)`).  
If the buffer overflows, Hive **coalesces or drops** events deterministically and emits a `streamBackpressure` diagnostic event (debug-only in v1).

---

## 10) Checkpointing and Wax integration (deepened)

### 10.1 What to persist (v1)

Persist a full snapshot:

- `threadID`, `runID`, `stepIndex`
- `graphVersion`, `schemaVersion` (fail-fast on mismatch in v1)
- `globalStore` values (encoded per channel via codec)
- `frontier` tasks (node IDs + local overlays for task-local channels, encoded per codec)
- last emitted event cursor or trace ID (stored to support UI resume)

HiveCore defines checkpoint types and a store protocol:

```swift
public struct HiveCheckpointID: Hashable, Codable, Sendable {
  public let rawValue: String
  public init(_ rawValue: String) { self.rawValue = rawValue }
}

public struct HiveCheckpointTask: Codable, Sendable {
  public let nodeID: HiveNodeID
  public let localFingerprint: Data
  public let localDataByChannelID: [String: Data]
}

public struct HiveCheckpoint<Schema: HiveSchema>: Codable, Sendable {
  public let id: HiveCheckpointID
  public let threadID: HiveThreadID
  public let runID: HiveRunID
  public let stepIndex: Int

  /// Encoded values for all `.global` channels (keyed by channel id string).
  public let globalDataByChannelID: [String: Data]

  /// The persisted frontier.
  public let frontier: [HiveCheckpointTask]

  /// Present only when the run is paused.
  public let interruption: HiveInterrupt<Schema>?
}

public protocol HiveCheckpointStore: Sendable {
  associatedtype Schema: HiveSchema
  func save(_ checkpoint: HiveCheckpoint<Schema>) async throws
  func loadLatest(threadID: HiveThreadID) async throws -> HiveCheckpoint<Schema>?
}

public struct AnyHiveCheckpointStore<Schema: HiveSchema>: Sendable {
  private let _save: @Sendable (HiveCheckpoint<Schema>) async throws -> Void
  private let _loadLatest: @Sendable (HiveThreadID) async throws -> HiveCheckpoint<Schema>?

  public init<S: HiveCheckpointStore>(_ store: S) where S.Schema == Schema {
    self._save = store.save
    self._loadLatest = store.loadLatest
  }

  public func save(_ checkpoint: HiveCheckpoint<Schema>) async throws { try await _save(checkpoint) }
  public func loadLatest(threadID: HiveThreadID) async throws -> HiveCheckpoint<Schema>? { try await _loadLatest(threadID) }
}
```

**Why snapshot over delta log?**

- simplest to implement and test
- fastest resume path (no replay)
- best fit for mobile where you want reliability over minimal storage

Delta logs/time-travel are deferred until after v1 ships.

### 10.2 Codec strategy

Define:

- `HiveCodec<Value>` for `Codable` values
- `HiveAnyCodec<Value>` type-erased wrapper stored in channel specs

Encoding rules (v1):

- If checkpointing is enabled, all `.global` channels have a codec.
- All `.taskLocal` channels have a codec (task locals are persisted in the frontier).

If codecs are missing and checkpointing is enabled:

- Graph compilation succeeds (the graph is still valid for in-memory runs).
- The runtime fails before the first step with a clear configuration error that lists missing codec channel IDs.

### 10.3 Wax storage layout (conceptual)

Wax implementation details depend on Wax APIs; implementers map the layout below to Wax collections/keys.

- Keyspace: `hive/checkpoints/<threadID>/latest`
- Store:
  - metadata record (JSON)
  - per-channel blobs (Data)
  - frontier tasks list (JSON + per-task local blobs)

Add a version number (`schemaVersion`) to allow migrations.

### 10.4 State inspection + external updates (v1)

Hive v1 includes state inspection and external state mutation APIs because they are required for real apps (debugging, UI rendering, and “inject user message then continue” flows).

HiveRuntime exposes:

- `getLatestCheckpoint(threadID:)` → returns the latest checkpoint (or nil)
- `getLatestStore(threadID:)` → returns a decoded `HiveGlobalStore<Schema>` snapshot
- `applyExternalWrites(threadID:writes:)` → applies a set of global writes, saves a new checkpoint, and returns the new snapshot

Rules:

- External writes use the same reducer semantics as normal node writes.
- External writes are committed as their own “synthetic step” and emit events (so the UI can stay consistent).
- External writes are persisted immediately when checkpointing is enabled for the thread.

---

## 11) Conduit + Swarm integration (adapter boundaries)

### 11.1 Keep HiveCore independent

HiveCore stays independent of Conduit/Wax/Swarm. All third-party integrations live in adapter modules.

HiveCore defines minimal, stable protocols and value types used by adapters and convenience nodes:

#### Canonical chat + tool types (HiveCore)

```swift
public enum HiveChatRole: String, Codable, Sendable { case system, user, assistant, tool }

public struct HiveChatMessage: Codable, Sendable {
  public let role: HiveChatRole
  public let content: String
  public let name: String?
  public let toolCallID: String?
  public let toolCalls: [HiveToolCall]
}

public struct HiveToolDefinition: Codable, Sendable {
  public let name: String
  public let description: String
  public let parametersJSONSchema: String
}

public struct HiveToolCall: Codable, Sendable {
  public let id: String
  public let name: String
  public let argumentsJSON: String
}

public struct HiveToolResult: Codable, Sendable {
  public let toolCallID: String
  public let content: String
}
```

#### Model client (HiveCore)

```swift
public struct HiveChatRequest: Codable, Sendable {
  public let model: String
  public let messages: [HiveChatMessage]
  public let tools: [HiveToolDefinition]
}

public struct HiveChatResponse: Codable, Sendable {
  public let message: HiveChatMessage
}

public enum HiveChatStreamChunk: Sendable {
  case token(String)
}

public protocol HiveModelClient: Sendable {
  func complete(_ request: HiveChatRequest) async throws -> HiveChatResponse
  func stream(_ request: HiveChatRequest) -> AsyncThrowingStream<HiveChatStreamChunk, Error>
}

public struct AnyHiveModelClient: HiveModelClient, Sendable {
  private let _complete: @Sendable (HiveChatRequest) async throws -> HiveChatResponse
  private let _stream: @Sendable (HiveChatRequest) -> AsyncThrowingStream<HiveChatStreamChunk, Error>

  public init<M: HiveModelClient>(_ model: M) {
    self._complete = model.complete
    self._stream = model.stream
  }

  public func complete(_ request: HiveChatRequest) async throws -> HiveChatResponse { try await _complete(request) }
  public func stream(_ request: HiveChatRequest) -> AsyncThrowingStream<HiveChatStreamChunk, Error> { _stream(request) }
}
```

#### Tool registry (HiveCore)

```swift
public protocol HiveToolRegistry: Sendable {
  func invoke(_ call: HiveToolCall) async throws -> HiveToolResult
}

public struct AnyHiveToolRegistry: HiveToolRegistry, Sendable {
  private let _invoke: @Sendable (HiveToolCall) async throws -> HiveToolResult
  public init<T: HiveToolRegistry>(_ tools: T) { self._invoke = tools.invoke }
  public func invoke(_ call: HiveToolCall) async throws -> HiveToolResult { try await _invoke(call) }
}
```

Adapters convert provider-specific message/tool representations into these canonical Hive types.

### 11.2 Conduit adapter (HiveConduit)

Responsibilities:

- implement `ConduitModelClient: HiveModelClient`
- map Conduit streaming chunks into `HiveChatStreamChunk` and emit `HiveEvent.modelToken(...)`
- emit model invocation start/finish events (including model name and usage metadata)
- keep prompt templates and provider-specific request knobs inside `HiveConduit`

### 11.3 Swarm adapter (HiveSwarm)

Responsibilities:

- adapt Swarm tool definitions into `HiveToolRegistry` (tool name, args JSON, result content)
- expose a typed `HiveAgents` façade that produces ready-to-run graphs and safe defaults
- emit tool invocation events (`toolInvocationStarted` / `toolInvocationFinished`) with tool name + call id metadata

#### Prebuilt Swarm graph (v1 deliverable)

HiveSwarm ships a prebuilt graph that is the default entry point for apps:

`HiveAgents.makeToolUsingChatAgent(...) -> CompiledHiveGraph<HiveAgents.Schema>`

HiveSwarm also ships a façade API that makes the prebuilt graph easy to use in apps (no manual wiring):

```swift
public struct HiveAgentsRuntime: Sendable {
  public let threadID: HiveThreadID
  public let graph: CompiledHiveGraph<HiveAgents.Schema>
  public let environment: HiveEnvironment<HiveAgents.Schema>
  public let options: HiveRunOptions

  public func sendUserMessage(_ text: String) -> AsyncThrowingStream<HiveEvent, Error>
  public func resumeToolApproval(_ decision: HiveAgents.ToolApprovalDecision) -> AsyncThrowingStream<HiveEvent, Error>
}

public enum HiveAgentsToolApprovalPolicy: Sendable {
  case never
  case always
  case allowList(Set<String>) // tool names
}
```

Rules:

- `sendUserMessage` uses `applyExternalWrites` to append a `.user` message, then runs the graph to completion or interruption.
- `resumeToolApproval` calls `HiveRuntime.resume(...)` with `HiveAgents.Resume.toolApproval(...)`.
- The façade uses Wax checkpointing by default and saves every step.

##### HiveAgents.Schema (channels)

All values are persisted and checkpointed (global scope), except where noted.

- `messages: [HiveChatMessage]` — reducer: append
- `pendingToolCalls: [HiveToolCall]` — reducer: last-write-wins
- `finalAnswer: String?` — reducer: last-write-wins
- `currentToolCall: HiveToolCall?` — **taskLocal scope** (used when spawning tool tasks)

HiveAgents.Schema locks its interrupt/resume payloads to support tool approval:

- `InterruptPayload = HiveAgents.Interrupt` (Codable enum)
- `ResumePayload = HiveAgents.Resume` (Codable enum)

HiveSwarm defines:

```swift
public enum HiveAgents {
  public enum ToolApprovalDecision: String, Codable, Sendable { case approved, rejected }

  public enum Interrupt: Codable, Sendable {
    case toolApprovalRequired(toolCalls: [HiveToolCall])
  }

  public enum Resume: Codable, Sendable {
    case toolApproval(decision: ToolApprovalDecision)
  }
}
```

HiveAgents also defines a run-scoped context that the prebuilt graph reads:

```swift
public struct HiveAgentsContext: Sendable {
  public let modelName: String
  public let tools: [HiveToolDefinition]
  public let toolApprovalPolicy: HiveAgentsToolApprovalPolicy
}
```

HiveAgents.Schema sets `Context = HiveAgentsContext`.

##### Node set (fixed)

- `model`: calls `HiveModelClient` with `messages` + `context.tools`; writes:
  - append assistant message to `messages`
  - set `pendingToolCalls` from parsed tool calls
  - set `finalAnswer` when no tool calls exist and assistant message is final
- `routeAfterModel`: synchronous router:
  - if `pendingToolCalls` is empty → `.end`
  - else → `tools`
- `tools`: spawns one `toolExecute` task per `pendingToolCalls` item:
  - sort tool calls by `(name, id)` before spawning (deterministic)
  - enforce `context.toolApprovalPolicy`:
    - when approval is required and no approval resume payload is present, interrupt with `HiveAgents.Interrupt.toolApprovalRequired(toolCalls:)`
    - when resumed with `.toolApproval(decision: .approved)`, proceed with spawning tool tasks
    - when resumed with `.toolApproval(decision: .rejected)`, clear `pendingToolCalls`, append a system message noting the rejection, and route back to `model`
  - each spawned task sets taskLocal `currentToolCall`
  - clear `pendingToolCalls` in global store (set to `[]`)
- `toolExecute`: runs a single tool call using `HiveToolRegistry`:
  - emits tool invocation start/finish events
  - appends a `HiveChatMessage(role: .tool, toolCallID: currentToolCall.id, content: result.content, toolCalls: [])` to `messages`
  - static edge to `model`

##### Graph wiring

- `.start -> model`
- `model -> routeAfterModel`
- `routeAfterModel -> tools` (when tool calls exist)
- `tools` spawns `toolExecute` tasks
- `toolExecute -> model` (converges and deduplicates to a single `model` task in the next step because it has an empty local overlay)

##### Interrupt/resume integration

HiveAgents uses interrupts to implement human-in-the-loop workflows:

- tool approval: `tools` interrupts before executing tools when an approval policy is enabled. The interrupt payload includes the tool calls that are about to run. Resume payload provides the approval decision.

Checkpointing is enabled and saved every step so the UI can resume instantly after an interrupt.

HiveAgents handles user chat turns via external writes:

- `HiveAgents.sendUserMessage(threadID:text:)` appends a `.user` message to the `messages` channel using `applyExternalWrites(...)`, then runs the graph until completion or interruption.

---

## 12) TDD plan (Swift Testing Framework) — expanded

We build Hive by writing tests first. The runtime is stateful, concurrent, and event-driven; tests must pin down semantics.

### 12.1 Test suite structure

- `ReducerTests`
- `StoreTests`
- `GraphCompilationTests`
- `RuntimeStepTests`
- `RuntimeDeterminismTests`
- `SendAndFanOutTests`
- `CheckpointTests`
- `AdapterContractTests` (protocol-level, no network)

### 12.2 Canonical v1 tests (must-have)

**Reducers**

- last-write-wins respects task ordering, not completion time
- append reducer merges arrays deterministically
- dictionary merge reducer composes correctly

**Store**

- reading any declared channel returns a value (store eagerly initializes all channels to their initial values)
- local overlay shadows global for task-local keys
- typed writes can’t target wrong key type (compile-time)

**Compilation**

- duplicate node IDs rejected
- edge to unknown node rejected
- missing entry (`start` edge) rejected
- router returns unknown node rejected at runtime with clear error (compile-time can’t always catch)

**Runtime**

- linear flow: start → A → end
- conditional routing: A → (B or end)
- loop with maxSteps: A → A
- task failures: fail-fast returns error + emits correct events
- cancellation: cancel mid-step cancels node tasks and returns cancelled result
- interrupt: node interrupts, run returns `.interrupted`, checkpoint is saved
- resume: resuming with payload continues deterministically and reaches expected final state

**Send / fan-out**

- router spawns N tasks with distinct local inputs
- all tasks run concurrently
- global aggregator channel reduces N results deterministically

**Checkpoint**

- checkpoint after each step restores global store + frontier exactly
- resume continues deterministically to same final store
- missing codec causes clear error when checkpointing enabled
- external writes: `applyExternalWrites` commits reducer-correct updates and persists a checkpoint

**HiveAgents (Swarm prebuilt)**

- `sendUserMessage` appends a user message then runs to completion
- tool call loop: model produces tool calls → tools execute → model continues → final answer
- tool approval: tools node interrupts → resume with approved executes tools → resume with rejected routes back to model
- streaming emits token + tool invocation events in deterministic order

### 12.3 Golden traces

For a small set of graphs, store a **codable** “golden” event trace (serialized form) and final store summary, and compare in tests.  
Either make `HiveEventKind` codable or map events to a stable, codable trace record. Normalize `attemptID` if present.

---

## 13) Implementation roadmap (phased, but more granular than the initial draft)

### Phase 0 — Scaffold (1–2 days)

- [ ] Add `libs/hive` SwiftPM package with targets described above
- [ ] Add Swift Testing test targets
- [ ] Add minimal docs: `README.md` for Hive and module READMEs
- [ ] Set deployment targets to iOS 17.0 and macOS 14.0 in `Package.swift`

### Phase 1 — Schema + reducers + codecs (core foundations)

- [ ] Implement `HiveChannelID`, `HiveChannelKey<Value>`
- [ ] Implement `HiveReducer<Value>` + standard reducers
- [ ] Implement `HiveCodec` and type-erased `HiveAnyCodec`
- [ ] Implement `HiveChannelSpec` + `AnyHiveChannelSpec` type erasure
- [ ] Implement schema validation:
  - [ ] unique channel IDs
  - [ ] channel scope sanity (e.g., reserved internal IDs)
- [ ] Tests: reducers + codec roundtrips

### Phase 2 — Stores (global + local)

- [ ] Implement type-erased storage backend
- [ ] Implement `HiveGlobalStore<Schema>`
- [ ] Implement `HiveTaskLocalStore<Schema>`
- [ ] Implement composed read view used by nodes
- [ ] Implement `AnyHiveWrite<Schema>` + typed factory helpers
- [ ] Tests: overlay behavior + typed access

### Phase 3 — Graph builder + compilation

- [ ] Implement `HiveNodeID`, `HiveTaskID`
- [ ] Implement `HiveGraphBuilder<Schema>`
  - [ ] add nodes
  - [ ] add edges
  - [ ] add routers
  - [ ] define entry/finish semantics (`start`/`end`)
- [ ] Implement `compile()` returning `CompiledHiveGraph`
- [ ] Tests: compile errors and diagnostics

### Phase 4 — Runtime engine + events (vertical slice)

- [ ] Define `HiveEvent` model + stable ordering rules
- [ ] Define runtime configuration types: `HiveRunOptions`, `HiveCheckpointPolicy`, `HiveRetryPolicy`, `HiveEnvironment`
- [ ] Define run lifecycle types: `HiveRunResult`, `HiveInterruption`, `HiveResume`, runtime error types
- [ ] Implement `HiveRuntime` actor:
  - [ ] run loop with frontier + steps + commit
  - [ ] bounded concurrency for tasks
  - [ ] deterministic commit + event emission
  - [ ] interrupt handling + resume entry point
  - [ ] retry execution using `HiveRetryPolicy` + `HiveClock`
- [ ] Tests: linear run + determinism under randomized task completion

### Phase 5 — Send / fan-out (map-reduce)

- [ ] Implement `HiveTask` frontier model and `spawn` outputs
- [ ] Implement router APIs that can return:
  - [ ] a single next node
  - [ ] multiple tasks with local overlays
- [ ] Tests: map-reduce example (classic “subjects → jokes” pattern)

### Phase 6 — Checkpointing integration + Wax implementation

- [ ] Define `HiveCheckpoint` encoding format
- [ ] Implement checkpoint policies (`disabled`, `everyStep`, `every(n)`, `onInterrupt`)
- [ ] Implement `WaxCheckpointStore` in `HiveCheckpointWax`
- [ ] Integrate runtime save/load/resume + interruption persistence
- [ ] Implement state inspection + external writes (`getLatestCheckpoint`, `getLatestStore`, `applyExternalWrites`)
- [ ] Tests: save/load + resume determinism

### Phase 7 — Adapters (Conduit + Swarm)

- [ ] Implement `HiveModelClient` + `AnyHiveModelClient` in `HiveCore`
- [ ] Implement `HiveToolRegistry` + `AnyHiveToolRegistry` in `HiveCore`
- [ ] Implement `ConduitModelClient` in `HiveConduit`
- [ ] Implement `SwarmToolRegistry` adapter in `HiveSwarm`
- [ ] Build prebuilt Swarm graph (`HiveAgents.makeToolUsingChatAgent`)
- [ ] Build façade runtime API (`HiveAgentsRuntime.sendUserMessage`, `resumeToolApproval`)
- [ ] Add tool approval interrupt/resume coverage tests
- [ ] Add end-to-end example app snippet/docs
- [ ] Tests: adapter contract tests with mocks

### Phase 8 — Docs + examples + hardening

- [ ] “Getting Started” + “Design rationale” docs
- [ ] Example graphs:
  - [ ] workflow graph
  - [ ] agent loop graph with tools
  - [ ] checkpoint resume demo
- [ ] Performance profiling + optimizations where needed
- [ ] API review for v1 stability

---

## 14) Definition of Done (v1)

Hive v1 is “done” when:

- `HiveCore` supports:
  - typed channels + reducers + initial values
  - graph compile + validation
  - runtime with deterministic steps + streaming events
  - Send/fan-out tasks with local overlays
- `HiveCheckpointWax`:
  - saves/loads checkpoints
  - resume produces identical results to uninterrupted run
- `HiveConduit` + `HiveSwarm`:
  - at least one working, documented “agent loop” example
- Tests cover the core semantics and determinism

---

## 15) Agent checklist (must pass before calling v1 “done”)

Use this checklist as the final review gate. If any item fails, v1 is not shippable.

### Determinism + correctness

- [ ] Running the same graph twice with the same inputs produces identical final stores and identical event traces (golden-trace tests).
- [ ] Task ordering never depends on task completion timing (add a test that randomizes task completion order).
- [ ] Reducer merge order is stable and documented; multi-writer conflicts resolve deterministically.
- [ ] Frontier deduplication by `(nodeID, localFingerprint)` works and is covered by tests (converging edges schedule the node once).

### Concurrency + safety

- [ ] All public types are `Sendable` (or explicitly `@unchecked Sendable` with justification).
- [ ] Runtime cancellation cleanly cancels in-flight node tasks and returns a `.cancelled` result with a usable snapshot.
- [ ] No shared mutable state is accessible to node code (nodes receive immutable snapshots + produce explicit writes).

### Checkpointing + resume

- [ ] Checkpointing persists and restores: global store + frontier + interruption state.
- [ ] Missing codecs fail before step 0 with a clear error listing missing channel IDs.
- [ ] Interrupt/resume persists interruption state and resumes from the correct frontier.
- [ ] External state updates (`applyExternalWrites`) produce correct reducer results and emit consistent events.

### Swarm “batteries included” UX

- [ ] `HiveAgents.makeToolUsingChatAgent` exists, compiles, and is documented with a minimal working example.
- [ ] `HiveAgents.sendUserMessage(threadID:text:)` exists and uses `applyExternalWrites` + graph run to produce an assistant response.
- [ ] Tool approval interrupt/resume path works end-to-end:
  - interrupt lists tool calls
  - resume with approval decision continues execution deterministically
- [ ] Streaming emits:
  - model token events
  - tool invocation start/finish events
  - step/task lifecycle events for UI

### Build + tests

- [ ] `swift test` passes for `HiveCore`, `HiveCheckpointWax`, `HiveConduit`, `HiveSwarm`.
- [ ] Public API is reviewed for ergonomics (naming, defaults, minimal footguns).
