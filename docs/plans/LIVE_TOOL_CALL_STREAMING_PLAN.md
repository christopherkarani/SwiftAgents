# Live Tool Call Streaming Plan (Conduit Bridge)

## Context

Swarm currently supports:

- Streaming agent *lifecycle* via `agent.stream(...) -> AsyncThrowingStream<AgentEvent, Error>`
- Tool calling via `InferenceProvider.generateWithToolCalls(...)` (non-streaming)
- Conduit-backed providers via `ConduitInferenceProvider`, but only string streaming (`stream(prompt:options)`)

Conduit already supports streaming tool-call assembly (partial arguments + completed tool calls) via
`TextGenerator.streamWithMetadata(messages:model:config:) -> AsyncThrowingStream<GenerationChunk, Error>`.

This plan adds an end-to-end path for **live tool-call UI** in Swarm:

- surface "partial tool call" updates while arguments are being streamed
- execute tools as soon as tool calls are completed (same execution engine)
- keep backward compatibility for existing providers (non-streaming tool calling)

## Goals

- Emit a first-class Swarm event for partial tool call assembly suitable for UI progress.
- Enable `ToolCallingAgent.stream(...)` to deliver those events when using Conduit-backed providers.
- Preserve existing `run(...)` behavior and non-Conduit providers without regression.
- Maintain Swift 6.2 strict concurrency + `Sendable` guarantees.
- TDD with Swift Testing Framework.

## Non-Goals (initially)

- Full provider-agnostic “tool-call streaming” for every provider (only Conduit bridge in v1).
- Streaming typed/structured tool arguments into a strongly-typed Swift struct during assembly.
- Streaming `generateWithToolCalls` into a single unified API (we’ll introduce a separate streaming protocol).

## Proposed Public API Additions

- `AgentEvent.toolCallPartial(update: PartialToolCallUpdate)`
- `PartialToolCallUpdate` (value type)
  - `providerCallId: String` (Conduit tool call id)
  - `toolName: String`
  - `index: Int` (parallel tool call index)
  - `argumentsFragment: String` (accumulated JSON fragment)
- `RunHooks.onToolCallPartial(...)` (no-op default)
- `RunHooks.onOutputChunk(...)` and/or `RunHooks.onOutputToken(...)` (no-op default)
  - used to wire provider chunk streaming into `AgentEvent.outputChunk/outputToken`

Provider layer:

- Add a new protocol (name TBD) for streaming tool calls, e.g.:
  - `protocol ToolCallStreamingInferenceProvider: InferenceProvider { func streamWithToolCalls(...) -> AsyncThrowingStream<InferenceStreamUpdate, Error> }`
- `InferenceStreamUpdate` enum (Swarm-owned) to avoid leaking Conduit types:
  - `.outputChunk(String)`
  - `.toolCallPartial(PartialToolCallUpdate)`
  - `.toolCallsCompleted([InferenceResponse.ParsedToolCall])`
  - `.usage(InferenceResponse.TokenUsage)` (optional; can be emitted at stream end)

## Phases

### Phase 0 - Baseline + Safety Rails (Prep)

Deliverables:

- Confirm no existing `AgentEvent`/`RunHooks` semantics rely on the old tool-only model.
- Add focused tests around event emission plumbing (stream hooks) as needed.

Acceptance criteria:

- All existing tests pass unchanged prior to feature work.

### Phase 1 - Event Surface + Hook Plumbing

Files (expected):

- `Sources/Swarm/Core/AgentEvent.swift`
- `Sources/Swarm/Core/RunHooks.swift`
- `Sources/Swarm/Core/EventStreamHooks.swift`

Work:

- Add `PartialToolCallUpdate` and `AgentEvent.toolCallPartial(...)`.
- Extend `RunHooks` with `onToolCallPartial(...)` (+ optional output streaming callbacks).
- Update `EventStreamHooks` to yield new events.

Acceptance criteria:

- New API is additive (no breaking changes).
- Swift concurrency: all new types are `Sendable`.
- Unit tests validate event bridging from hooks to `AgentEvent`.

### Phase 2 - Provider Streaming Abstraction (Swarm-owned)

Files (expected):

- `Sources/Swarm/Core/Agent.swift` (protocol additions only if needed)
- `Sources/Swarm/Providers/...` (new protocol + update types)

Work:

- Introduce `InferenceStreamUpdate` and a streaming protocol for tool-call streaming.
- Keep existing `InferenceProvider` unchanged for compatibility; detect streaming capability via protocol cast.

Acceptance criteria:

- Compiles without importing Conduit outside the Conduit provider directory.
- No behavior changes for non-streaming providers.

### Phase 3 - Conduit Bridge: Stream With Tool Calls

Files (expected):

- `Sources/Swarm/Providers/Conduit/ConduitInferenceProvider.swift`

Work:

- Implement `streamWithToolCalls(...)` using Conduit `streamWithMetadata(messages:model:config:)`.
- Map Conduit `GenerationChunk` to Swarm `InferenceStreamUpdate`:
  - `chunk.text` -> `.outputChunk(...)` (optional; useful for UI)
  - `chunk.partialToolCall` -> `.toolCallPartial(...)`
  - `chunk.completedToolCalls` -> `.toolCallsCompleted([...ParsedToolCall...])`
  - `chunk.usage` -> `.usage(...)` (if available)
- Ensure Conduit tool-call ids are carried through to `ToolCall.providerCallId` once executed.

Acceptance criteria:

- Streaming works with bounded buffers and cancellation.
- Tool-call argument fragments are emitted incrementally (at least once per streamed update).

### Phase 4 - ToolCallingAgent: Live Tool Call Loop

Files (expected):

- `Sources/Swarm/Agents/ToolCallingAgent.swift`

Work:

- In the tool-calling loop, prefer streaming path when available:
  - `if let provider = provider as? ToolCallStreamingInferenceProvider { ... }`
- Consume updates:
  - forward `.toolCallPartial` to hooks/events
  - forward `.outputChunk` to hooks/events (optional)
  - on `.toolCallsCompleted`, execute tool calls with existing `ToolExecutionEngine`
  - append tool results to conversation history and continue loop
- Preserve existing non-streaming path as fallback.

Acceptance criteria:

- End-to-end: UI can render partial tool-call JSON fragments *before* tool execution starts.
- No regressions in non-streaming providers and `run(...)` path.

### Phase 5 - Tests (Swift Testing) + Documentation

Files (expected):

- `Tests/SwarmTests/Providers/...`
- `Tests/SwarmTests/Agents/...`
- `docs/` (optional usage guide snippet)

Work:

- Provider mapping tests:
  - Given a synthetic sequence of Conduit `GenerationChunk`s, verify emitted Swarm updates/events.
- Agent end-to-end tests:
  - Use a mock streaming provider implementing `ToolCallStreamingInferenceProvider`.
  - Assert `ToolCallingAgent.stream(...)` yields `.toolCallPartial` events before `.toolCallStarted`.
  - Assert tools are executed on completion and final result is correct.
- Add minimal docs on how to build UI:
  - subscribe to `AgentEvent.toolCallPartial` to show "arguments assembling..."
  - subscribe to `.toolCallStarted/.toolCallCompleted` for execution lifecycle

Acceptance criteria:

- `swift test` passes.
- Coverage includes the streaming loop + event surface.

## Risks / Open Questions

- Event volume: partial argument fragments can be frequent; we may want throttling/deduplication in Swarm.
- Buffer growth: ensure streams are bounded and cancellation is respected.
- Tool argument validity: partial JSON is not parseable until complete; UI should treat `argumentsFragment` as "best effort".
- Provider differences: not every Conduit provider may emit `partialToolCall` consistently.

## Rollout Strategy

- Land phases 1-3 behind additive APIs.
- Phase 4 enables streaming behavior automatically when the provider supports it.
- Keep fallback to existing non-streaming `generateWithToolCalls` to preserve current behavior.

