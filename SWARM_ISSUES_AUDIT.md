# Swarm Framework Issues Audit

**Date**: 2026-02-13  
**Auditor**: AI Code Review  
**Scope**: Full codebase analysis (Sources: ~114K lines, Tests: ~5.6K lines)

---

## Executive Summary

This audit identified **14 critical and major issues** in the Swarm framework, ranging from build failures to architectural flaws. The most severe issues prevent the project from compiling and break core functionality for Apple Foundation Models.

### Issue Distribution
| Severity | Count | Status |
|----------|-------|--------|
| 🔴 Critical | 2 | Must fix before release |
| 🟠 Major | 5 | Should fix before release |
| 🟡 Medium | 6 | Fix in next iteration |
| 🟢 Low | 1 | Nice to have |

---

## 🔴 Critical Issues

### CRIT-001: Build Failure - Platform Version Mismatch

**Status**: 🔴 **BLOCKING**  
**File**: `Package.swift`  
**Impact**: Complete build failure

#### Description
The Package.swift declares platform requirements of macOS 14.0 / iOS 17.0, but dependencies require macOS 26.0:

```swift
// Package.swift declares:
platforms: [
    .macOS(.v14),    // ❌ 14.0
    .iOS(.v17),      // ❌ 17.0
    ...
]

// Dependencies require:
HiveCore: macOS 26.0  // ❌ Conflict
Wax: macOS 26.0       // ❌ Conflict
```

#### Build Error
```
error: the library 'Swarm' requires macos 14.0, but depends on the product 
'HiveCore' which requires macos 26.0
```

#### Recommended Fix
Option A: Upgrade Swarm platform requirements to macOS 26.0 / iOS 26.0
Option B: Downgrade Hive and Wax dependencies to compatible versions

#### Effort: Small

---

### CRIT-002: Incomplete Foundation Models Support

**Status**: 🔴 **FEATURE GAP**  
**File**: `Sources/Swarm/Providers/LanguageModelSession.swift`  
**Impact**: Core agent functionality broken for on-device AI

#### Description
The Foundation Models integration has an unimplemented TODO for tool calling:

```swift
@available(macOS 26.0, iOS 26.0, *)
extension LanguageModelSession: InferenceProvider {
    public func generateWithToolCalls(
        prompt: String,
        tools: [ToolSchema],
        options: InferenceOptions
    ) async throws -> InferenceResponse {
        // TODO: Implement native tool calling for FoundationModels
        // Foundation Models on-device may support function calling in future releases.
        // For now, fall back to text generation without tool calls.
        let response = try await self.respond(to: prompt)
        
        return InferenceResponse(
            content: response.content,
            toolCalls: [],  // ❌ Always empty!
            finishReason: .completed
        )
    }
}
```

#### Impact
- Agents using Foundation Models cannot use tools
- Breaks "works out of the box" promise for on-device AI
- Silent failure — agents run but ignore tool schemas

#### Recommended Fix
1. Implement tool calling via Foundation Models function calling API
2. OR remove Foundation Models claims from documentation
3. OR add runtime warning when tools are provided but unsupported

#### Effort: Medium (requires API research)

---

## 🟠 Major Issues

### MAJ-001: Deprecated DSL Still Present and Incomplete

**Status**: 🟠 **TECHNICAL DEBT**  
**Files**: 
- `Sources/Swarm/DSL/AgentLoop.swift`
- `Sources/Swarm/DSL/AgentLoopBuilder.swift`
- `Sources/Swarm/DSL/AgentLoopStep.swift`

#### Description
The legacy `AgentLoopDefinition` + `Relay()`/`Generate()` DSL is deprecated but still compiled:

```swift
@available(*, deprecated, message: "Use AgentBlueprint with orchestration steps instead")
public struct LoopAgent: AgentLoopDefinition { ... }
```

Meanwhile, the new `AgentBlueprint` DSL references a missing file:
```swift
// Referenced but doesn't exist:
Sources/Swarm/DSL/OrchestrationBuilder.swift
```

#### Impact
- Confusing API surface with two DSLs
- Dead code increases maintenance burden
- Missing core file suggests incomplete migration

#### Recommended Fix
1. Complete the `OrchestrationBuilder.swift` implementation
2. Remove deprecated DSL files
3. Add migration guide for users

#### Effort: Medium

---

### MAJ-002: Race Condition in Agent Cancellation

**Status**: 🟠 **CONCURRENCY BUG**  
**Files**: 
- `Sources/Swarm/Agents/Agent.swift`
- `Sources/Swarm/Agents/ReActAgent.swift`

#### Description
The cancellation mechanism has potential race conditions:

```swift
public actor Agent: AgentRuntime {
    private var isCancelled: Bool = false
    private var currentTask: Task<Void, Never>?
    
    public func cancel() async {
        isCancelled = true              // ❌ State mutation
        currentTask?.cancel()           // ❌ Non-isolated access
        currentTask = nil               // ❌ State mutation
    }
}
```

The `currentTask` is accessed from `cancel()` but also modified from the execution loop. While actors provide isolation, the pattern of checking `isCancelled` separately from `Task.checkCancellation()` creates a window for race conditions.

#### Impact
- Cancellation may not work reliably under high contention
- Potential for use-after-free on `currentTask`

#### Recommended Fix
```swift
public func cancel() async {
    await MainActor.run {  // Or proper isolated context
        isCancelled = true
        currentTask?.cancel()
        currentTask = nil
    }
}
```

Or better, use `withTaskCancellationHandler` pattern.

#### Effort: Small

---

### MAJ-003: Memory Duplication in Session/Agent Integration

**Status**: 🟠 **LOGIC ERROR**  
**Files**: 
- `Sources/Swarm/Agents/Agent.swift` (lines 307-316)
- `Sources/Swarm/Agents/ReActAgent.swift` (similar pattern)

#### Description
Messages are stored in BOTH session AND memory, causing duplication:

```swift
// Store turn in session (user + assistant messages)
if let session {
    let assistantMessage = MemoryMessage.assistant(output)
    try await session.addItems([userMessage, assistantMessage])
}

// Only store output in memory if validation passed
if let mem = activeMemory {
    await mem.add(.assistant(output))  // ❌ Duplicated!
}
```

#### Impact
- 2x memory usage for conversation history
- Potential inconsistency if one write fails
- No clear ownership of data

#### Recommended Fix
Clarify the separation of concerns:
- **Session**: Conversation persistence across runs
- **Memory**: Context retrieval for LLM prompts

Consider making them mutually exclusive or clearly hierarchical.

#### Effort: Medium (requires API design)

---

### MAJ-004: Tool Name Collision - Silent Overwrite

**Status**: 🟠 **DESIGN FLAW**  
**File**: `Sources/Swarm/Tools/Tool.swift`

#### Description
The ToolRegistry silently overwrites tools with duplicate names:

```swift
public actor ToolRegistry {
    private var tools: [String: any AnyJSONTool] = [:]
    
    public func register(_ tool: any AnyJSONTool) {
        tools[tool.name] = tool  // ❌ Silent overwrite!
    }
}
```

#### Impact
- Tools can disappear at runtime without warning
- Hard to debug why a tool isn't available
- No validation during agent construction

#### Recommended Fix
```swift
public func register(_ tool: any AnyJSONTool) throws {
    if tools[tool.name] != nil {
        throw ToolError.duplicateName(tool.name)
    }
    tools[tool.name] = tool
}
```

Or at minimum, log a warning.

#### Effort: Small

---

### MAJ-005: SupervisorAgent Handoff Configuration Bug

**Status**: 🟠 **LOGIC ERROR**  
**File**: `Sources/Swarm/Orchestration/SupervisorAgent.swift` (lines 26-31)

#### Description
The handoff lookup compares types, not instances:

```swift
private func findHandoffConfiguration(for targetAgent: any AgentRuntime) -> AnyHandoffConfiguration? {
    handoffs.first { config in
        let configTargetType = type(of: config.targetAgent)
        let currentType = type(of: targetAgent)
        return configTargetType == currentType  // ❌ Type comparison!
    }
}
```

If you have two `Agent` instances with different configurations, the wrong handoff config may be used.

#### Impact
- Wrong handoff configuration applied
- Potential security/policy bypass

#### Recommended Fix
```swift
private func findHandoffConfiguration(for targetAgent: any AgentRuntime) -> AnyHandoffConfiguration? {
    handoffs.first { config in
        config.targetAgent === targetAgent  // Identity comparison
    }
}
```

#### Effort: Small

---

## 🟡 Medium Issues

### MED-001: Excessive Type Erasure

**Status**: 🟡 **DESIGN CONCERN**  
**Files**: Multiple across codebase

#### Description
Excessive use of type erasure reduces type safety and adds indirection:

| Wrapper | Purpose |
|---------|---------|
| `AnyJSONToolAdapter` | Tool → AnyJSONTool |
| `AnyHandoffConfiguration` | Handoff config erasure |
| `AnyHiveCheckpointStore` | Checkpoint store erasure |
| `AnyHiveModelClient` | Model client erasure |
| `AnyHiveToolRegistry` | Tool registry erasure |

Each erasure:
- Loses compile-time type information
- Adds virtual dispatch overhead
- Makes debugging harder

#### Recommended Fix
Consider using generics with type constraints where possible, or protocol witness patterns.

#### Effort: Large (architectural change)

---

### MED-002: Runtime Mode Confusion

**Status**: 🟡 **API DESIGN**  
**File**: `Sources/Swarm/Core/AgentConfiguration.swift` (lines 11-22)

#### Description
Three enum cases for one behavior:

```swift
public enum SwarmRuntimeMode: Sendable, Equatable {
    case swift      // "Legacy mode... always uses Hive"
    case hive       // "Execute using Hive"
    case requireHive // "Alias for .hive"
}

/// Documentation:
/// This value is retained for source compatibility. Execution always uses Hive.
```

#### Impact
- Confusing API
- Source compatibility at cost of clarity
- Dead code paths

#### Recommended Fix
```swift
@available(*, deprecated, renamed: "hive")
case swift

@available(*, deprecated, renamed: "hive")
case requireHive

case hive
```

#### Effort: Small

---

### MED-003: Configuration Bloat (God Object)

**Status**: 🟡 **DESIGN CONCERN**  
**File**: `Sources/Swarm/Core/AgentConfiguration.swift`

#### Description
`AgentConfiguration` has 20+ properties mixing multiple concerns:

```swift
public init(
    name: String = "Agent",
    maxIterations: Int = 10,           // Execution control
    timeout: Duration = .seconds(60),  // Execution control
    temperature: Double = 1.0,         // Model params
    maxTokens: Int? = nil,             // Model params
    stopSequences: [String] = [],      // Model params
    modelSettings: ModelSettings? = nil,  // Model params
    contextProfile: ContextProfile = .platformDefault,  // Memory
    runtimeMode: SwarmRuntimeMode = .hive,  // Runtime
    hiveRunOptionsOverride: SwarmHiveRunOptionsOverride? = nil,  // Runtime
    inferencePolicy: InferencePolicy? = nil,  // Routing
    enableStreaming: Bool = true,      // Behavior
    includeToolCallDetails: Bool = true,  // Behavior
    stopOnToolError: Bool = false,     // Behavior
    includeReasoning: Bool = true,     // Behavior
    sessionHistoryLimit: Int? = 50,    // Session
    parallelToolCalls: Bool = false,   // Execution
    previousResponseId: String? = nil, // Session
    autoPreviousResponseId: Bool = false,  // Session
    defaultTracingEnabled: Bool = true  // Observability
)
```

#### Impact
- Hard to understand all options
- Mixing unrelated concerns
- Difficult to validate combinations

#### Recommended Fix
Split into focused configuration structs:
```swift
struct AgentConfiguration {
    var identity: IdentityConfig
    var execution: ExecutionConfig
    var model: ModelConfig
    var observability: ObservabilityConfig
}
```

#### Effort: Medium (requires API deprecation cycle)

---

### MED-004: Global Environment Access (Hidden Dependencies)

**Status**: 🟡 **DESIGN CONCERN**  
**Files**: Multiple across codebase

#### Description
Global mutable state via `AgentEnvironmentValues.current`:

```swift
// Throughout the codebase:
let activeMemory = memory ?? AgentEnvironmentValues.current.memory
let provider = inferenceProvider ?? AgentEnvironmentValues.current.inferenceProvider
let tracer = self.tracer ?? AgentEnvironmentValues.current.tracer
```

#### Impact
- Hidden dependencies make testing harder
- Unexpected behavior when environment changes
- Hard to reason about code

#### Recommended Fix
Use explicit dependency injection:
```swift
public func run(
    _ input: String,
    session: (any Session)? = nil,
    hooks: (any RunHooks)? = nil,
    environment: AgentEnvironmentValues = .current  // Explicit but with default
) async throws -> AgentResult
```

#### Effort: Medium

---

### MED-005: Retry Policy Off-By-One Logic

**Status**: 🟡 **LOGIC ERROR**  
**File**: `Sources/Swarm/Resilience/RetryPolicy.swift` (lines 204-241)

#### Description
When `maxAttempts = 0` (noRetry), the error message is misleading:

```swift
public func execute<T: Sendable>(
    _ operation: @Sendable () async throws -> T
) async throws -> T {
    var attempt = 0
    while attempt <= maxAttempts {  // 0 <= 0 is true
        do {
            return try await operation()
        } catch {
            lastError = error
            attempt += 1  // attempt = 1
            guard attempt <= maxAttempts else { break }  // 1 <= 0, break
            // ...
        }
    }
    // Reports attempts: 1, but 0 retries were configured
    throw ResilienceError.retriesExhausted(attempts: attempt, ...)
}
```

#### Impact
- Misleading error messages
- Confusing telemetry/metrics

#### Recommended Fix
Track attempts vs retries separately:
```swift
var attempt = 1
var retryCount = 0
```

#### Effort: Small

---

### MED-006: Hive Coupling in Core Module

**Status**: 🟡 **ARCHITECTURAL**  
**File**: `Package.swift`

#### Description
The core `Swarm` module depends on `HiveCore`, yet `HiveSwarm` is a separate module:

```swift
// Swarm target depends on:
.product(name: "HiveCore", package: "Hive")

// Separate module for Hive integration:
.target(name: "HiveSwarm", dependencies: ["Swarm", "HiveCore"])
```

This creates circular conceptual dependency:
- Swarm → HiveCore (core depends on Hive)
- HiveSwarm → Swarm + HiveCore (integration depends on both)

#### Impact
- Unclear module boundaries
- Swarm cannot be used without Hive
- `HiveSwarm` has limited purpose

#### Recommended Fix
Either:
1. Remove HiveCore from Swarm dependencies, make it optional
2. Merge HiveSwarm into Swarm if coupling is required
3. Create proper layering: HiveCore → Swarm → HiveSwarm

#### Effort: Large

---

## 🟢 Low Issues

### LOW-001: Massive File Sizes

**Status**: 🟢 **CODE QUALITY**  
**Files**: 
- `Sources/Swarm/Agents/ReActAgent.swift`: 968 lines
- `Sources/Swarm/Agents/Agent.swift`: 1000+ lines
- `Sources/Swarm/Orchestration/SupervisorAgent.swift`: 1000+ lines

#### Description
Files violate single responsibility principle:
- Agent protocol conformance
- Execution logic
- Builder pattern implementation
- Streaming support
- Handoff handling

All mixed in one file.

#### Impact
- Hard to navigate
- Merge conflicts
- Cognitive load

#### Recommended Fix
Split into:
```
Agent/
  Agent.swift           // Main actor
  Agent+Execution.swift // Run/stream logic
  Agent+Builder.swift   // Builder pattern
```

#### Effort: Small (refactoring only)

---

## Appendix A: Missing Test Coverage

Based on file analysis, the following areas appear under-tested:

| Area | Risk | Recommendation |
|------|------|----------------|
| Determinism tests | High | Add tests for concurrent execution ordering |
| Checkpoint resume | High | Add save/restore roundtrip tests |
| Memory pressure | Medium | Add large memory load tests |
| Provider failover | Medium | Add cascading failure tests |
| Cancellation races | High | Add stress tests for cancellation |
| Tool name collisions | Medium | Add registration conflict tests |

---

## Appendix B: Quick Fixes (Can be done immediately)

1. **Fix platform versions** in Package.swift
2. **Add tool name validation** in ToolRegistry
3. **Fix handoff type comparison** in SupervisorAgent
4. **Fix retry attempt counting** in RetryPolicy
5. **Deprecate redundant runtime modes**

---

## Appendix C: Long-term Improvements

1. **Refactor configuration** into focused structs
2. **Remove deprecated DSL** after migration period
3. **Reduce type erasure** with better generics
4. **Clarify Hive integration** architecture
5. **Implement Foundation Models** tool calling
6. **Split massive files** into focused modules

---

*End of Audit*
