# API Cleanup: v2 Surface Reduction

**Date**: 2026-03-04
**Branch**: `api-cleanup-v2`
**Result**: ~42% reduction in public types (251 → ~146)

---

## Overview

A semver-major API cleanup that removes implementation details from the public surface of the Swarm framework. Users interact with `Agent`, `Workflow`, and the memory/tool protocols — not with Conduit wrappers, HiveCore DAG primitives, or internal builder types.

This is a **breaking change** coordinated as a single major-version bump: `0.1.0 → 2.0.0`.

---

## Batch 1 — Remove OpenRouter + Fix Conduit Leaks

### What was removed
- Entire `Sources/Swarm/Providers/OpenRouter/` directory (7 files, ~1,500 lines)
- `MultiProvider.withOpenRouter()` factory method
- `Tests/SwarmTests/Providers/OpenRouterTypesTests.swift`

### Rationale
The standalone OpenRouter implementation duplicated Conduit's built-in support. `LLM.openRouter(apiKey:model:)` via Conduit is the correct path. The deleted code tested wire format parsing that Conduit handles internally.

### Conduit leak fixes
- `ConduitInferenceProvider<Provider: Conduit.TextGenerator>` → **internal**. The generic constraint was visible in the public API.
- `LLM.AdvancedOptions.baseConfig: Conduit.GenerateConfig` → **internal**. Users can call `.advanced { }` but cannot reference a Conduit type.
- `SendableValue.fromJSONValue(_:)` → **package** (used by `SwarmHive` module).

---

## Batch 2 — HiveSwarm Bridge Internals

### What was changed
All types in `Sources/Swarm/HiveSwarm/` are now **internal** to the `SwarmHive` module:

- `ChatGraph` nested types: `PreModelHook`, `MessageIDFactory`, `ToolResultTransformer`, `MembraneCheckpointAdapter`, `HiveTokenizer`, `Interrupt`, `Resume`, `ToolApprovalDecision`, `ToolApprovalPolicy`, `HiveCompactionPolicy`, `RuntimeContext`, `GraphRuntimeAdapter`, `RunStartRequest`, `RunResumeRequest`, `ExternalWriteRequest`, `NoopPreModelHook`, `DefaultMessageIDFactory`, `NoopToolResultTransformer`, `GraphRunController`, `ToolProvider`
- `GraphAgent` struct
- `RetryPolicyBridge`
- `ToolRegistryAdapter` and `ToolRegistryAdapterError`
- `HiveCodableJSONCodec<V>`
- All types in `RuntimeHardening.swift`

### Workflow types internalized
- `WorkflowResultSnapshot` → internal
- `WorkflowInMemoryCheckpointStore` → internal (use `WorkflowCheckpointing.inMemory()`)
- `WorkflowFileCheckpointStore` → internal (use `WorkflowCheckpointing.fileSystem()`)

### Rationale
Users compose orchestrations using `Workflow` and `Agent`. The Hive DAG compilation, checkpoint stores, and runtime adapters are implementation details of the execution engine.

---

## Batch 3 — Design Quality

### 3a: Unified TokenUsage
`InferenceResponse.TokenUsage` (nested, non-Codable) was a duplicate of the module-level `TokenUsage` (in `AgentResult.swift`, Codable).

- Created `Sources/Swarm/Core/TokenUsage.swift` as single source of truth
- Removed the nested `InferenceResponse.TokenUsage`
- All call sites updated to use the module-level type
- `ToolCallStreamingInferenceProvider.InferenceStreamUpdate.usage(TokenUsage)` uses the module-level type

### 3b: Builder types demoted
These were implementation details of agent construction, not user-facing API:

- `InputGuardrailBuilder`, `OutputGuardrailBuilder` → **internal**
- `ToolInputGuardrailBuilder`, `ToolOutputGuardrailBuilder` → **internal**
- `VectorMemoryBuilder` → **internal**
- `AgentResult.Builder` → **package** (needs to be visible to `SwarmHive`)
- `ToolExecutionEngine`, `ToolCallGoal` → **internal**

### 3c: Misplaced types demoted
- `MockEmbeddingProvider` → moved from `Sources/Swarm/Memory/EmbeddingProvider.swift` to `Tests/SwarmTests/Mocks/`
- `PersistedMessage` (SwiftData `@Model`) → **internal** (storage implementation detail)
- `HandoffCoordinator` → **internal**
- `SwarmHiveRunOptionsOverride` → **internal**

---

## Batch 4 — Naming Polish

### 4a: AgentBuilder DSL renames (with deprecated typealiases)

| Old Name | New Name | Notes |
|---|---|---|
| `AgentMemoryComponent` | `AgentMemory` | Deprecated typealias preserved |
| `TracerComponent` | `TracerConfig` | `Tracer` protocol already exists |
| `InputGuardrailsComponent` | `InputGuardrails` | Deprecated typealias preserved |
| `OutputGuardrailsComponent` | `OutputGuardrails` | Deprecated typealias preserved |
| `HandoffsComponent` | `Handoffs` | Deprecated typealias preserved |
| `MCPClientComponent` | `MCPClientConfig` | `MCPClient` actor already exists |
| `InferenceProviderComponent` | *skipped* | `InferenceProvider` is a protocol |
| `ModelSettingsComponent` | *skipped* | `ModelSettings` struct already exists |

### 4b: Free functions → static methods
`formatMessagesForContext(_:tokenLimit:)` and `formatMessagesForContext(_:tokenLimit:separator:)` moved to `MemoryMessage.formatContext(_:tokenLimit:)` static methods. All 6 internal call sites updated.

### 4c: Dead code deleted
- `RelayAgent.swift` deleted (`typealias RelayAgent = Agent` — unused)
- `JSONValue` typealias removed from `ToolSchema.swift`
- `SwarmRuntimeMode` enum deleted from `AgentConfiguration.swift`

---

## Migration Guide (Breaking Changes)

### OpenRouter
```swift
// Before (deleted)
let provider = try OpenRouterProvider(apiKey: key, model: .gpt4o)

// After
let provider = LLM.openRouter(apiKey: key, model: "openai/gpt-4o")
```

### TokenUsage
```swift
// Before
let usage = InferenceResponse.TokenUsage(inputTokens: 100, outputTokens: 50)

// After
let usage = TokenUsage(inputTokens: 100, outputTokens: 50)
```

### Checkpoint stores
```swift
// Before (deleted direct instantiation)
let store = WorkflowInMemoryCheckpointStore()

// After (use factory)
let store = WorkflowCheckpointing.inMemory()
```

### AgentBuilder components
```swift
// Before
AgentMemoryComponent(myMemory)

// After
AgentMemory(myMemory)  // deprecated typealias bridges the gap for one version
```

### formatMessagesForContext
```swift
// Before (deleted free function)
let context = formatMessagesForContext(messages, tokenLimit: 4096)

// After
let context = MemoryMessage.formatContext(messages, tokenLimit: 4096)
```

---

## Version Bump

`Swarm.version`: `"0.1.0"` → `"2.0.0"`
