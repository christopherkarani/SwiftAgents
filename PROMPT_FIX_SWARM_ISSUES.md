# AI Coding Agent Prompt: Fix Critical Swarm Framework Issues

## Role & Objective

You are a **senior Swift 6.2 engineer** specializing in concurrency, distributed systems, and AI agent frameworks. Your task is to fix critical issues in the Swarm framework that are currently preventing builds and causing runtime problems.

**Primary Goal**: Fix all CRITICAL and MAJOR issues in priority order while maintaining backward compatibility where possible.

---

## Context

### Project Overview
Swarm is a Swift 6.2 AI agent framework ("LangChain for Apple platforms") with:
- ~114K lines of source code
- Actor-based concurrency
- Multiple agent runtimes (Agent, ReActAgent, PlanAndExecuteAgent)
- Multi-agent orchestration
- Memory systems (conversation, vector, summary)

### Current State
The project has **2 CRITICAL blocking issues**:
1. Build failure due to platform version mismatch
2. Incomplete Foundation Models support

Plus **5 MAJOR issues** affecting reliability and correctness.

### Full Issue Documentation
See `SWARM_ISSUES_AUDIT.md` and `SWARM_ISSUES_TRACKING.md` for complete details.

---

## Task Breakdown

### Phase 1: UNBLOCK (Critical Priority) ⏰

Fix these in order. Do not proceed to Phase 2 until complete.

#### Task 1.1: Fix Platform Version Mismatch (CRIT-001)

**Problem**: Package.swift declares macOS 14.0 / iOS 17.0, but dependencies (HiveCore, Wax) require macOS 26.0.

**Error**:
```
error: the library 'Swarm' requires macos 14.0, but depends on the product 
'HiveCore' which requires macos 26.0
```

**Files to Modify**:
- `Package.swift`

**Required Changes**:
```swift
// BEFORE (broken):
platforms: [
    .macOS(.v14),    // ❌
    .iOS(.v17),      // ❌
    .watchOS(.v10),
    .tvOS(.v17),
    .visionOS(.v1)
]

// AFTER (fixed):
platforms: [
    .macOS(.v26),    // ✅ Align with dependencies
    .iOS(.v26),      // ✅ Align with dependencies
    .watchOS(.v10),
    .tvOS(.v26),
    .visionOS(.v1)
]
```

**Constraints**:
- Update README.md to reflect new minimum requirements
- Check if any APIs need `@available` guards removed
- Ensure all tests still compile

**Verification**:
```bash
swift build 2>&1 | head -20
# Should show no platform mismatch errors
```

---

#### Task 1.2: Implement Foundation Models Tool Calling (CRIT-002)

**Problem**: `LanguageModelSession.generateWithToolCalls()` has an unimplemented TODO and always returns empty tool calls.

**Current Broken Code** (`Sources/Swarm/Providers/LanguageModelSession.swift`):
```swift
public func generateWithToolCalls(...) async throws -> InferenceResponse {
    // TODO: Implement native tool calling for FoundationModels
    let response = try await self.respond(to: prompt)
    return InferenceResponse(
        content: response.content,
        toolCalls: [],  // ❌ Always empty!
        finishReason: .completed
    )
}
```

**Research Required**:
1. Check if Apple Foundation Models (macOS 26.0+) support function calling
2. Look for `LanguageModelSession` API for tool/function calling
3. If not supported, implement fallback parsing

**Implementation Options**:

Option A: Native function calling (if available)
```swift
// Use Foundation Models native function calling API
let request = LanguageModelRequest(
    prompt: prompt,
    tools: tools.map { /* convert ToolSchema to FM Tool */ }
)
let response = try await self.respond(to: request)
// Extract tool calls from response.functionCalls
```

Option B: Prompt-based tool calling (fallback)
```swift
// Inject tool schemas into prompt
let toolPrompt = prompt + "\n\nAvailable tools: " + formatTools(tools)
let response = try await self.respond(to: toolPrompt)
// Parse tool calls from response.content using JSON parsing
let toolCalls = try parseToolCalls(from: response.content)
```

**Required Changes**:
1. Implement tool schema formatting for prompts
2. Add JSON response parsing for tool calls
3. Handle both structured and unstructured tool call formats
4. Add tests

**Files to Modify**:
- `Sources/Swarm/Providers/LanguageModelSession.swift`

**New Files to Create**:
- `Tests/SwarmTests/Providers/LanguageModelSessionTests.swift`

**Verification**:
```swift
// Test should pass:
let agent = Agent(
    tools: [CalculatorTool()],
    instructions: "You are a calculator assistant."
)
let result = try await agent.run("What is 2+2?")
// result should contain tool call and correct answer
```

---

### Phase 2: MAJOR Fixes (High Priority)

#### Task 2.1: Add Tool Name Collision Detection (MAJ-004)

**Problem**: `ToolRegistry.register()` silently overwrites tools with duplicate names.

**Current Code** (`Sources/Swarm/Tools/Tool.swift`, ~line 544):
```swift
public func register(_ tool: any AnyJSONTool) {
    tools[tool.name] = tool  // ❌ Silent overwrite
}
```

**Required Changes**:
```swift
public enum ToolRegistryError: Error {
    case duplicateToolName(name: String)
}

public func register(_ tool: any AnyJSONTool) throws {
    guard tools[tool.name] == nil else {
        throw ToolRegistryError.duplicateToolName(name: tool.name)
    }
    tools[tool.name] = tool
}
```

**Impact Analysis**:
- This changes the API signature (adds `throws`)
- Update all call sites:
  - `Agent.init()` 
  - `ReActAgent.init()`
  - `ToolRegistry.init(tools:)`
  - Direct registrations in tests

**Files to Modify**:
- `Sources/Swarm/Tools/Tool.swift`
- `Sources/Swarm/Agents/Agent.swift`
- `Sources/Swarm/Agents/ReActAgent.swift`
- Any test files that call `register()`

**Verification**:
```swift
let registry = ToolRegistry()
try registry.register(CalculatorTool())
XCTAssertThrowsError(try registry.register(CalculatorTool())) { error in
    guard case ToolRegistryError.duplicateToolName = error else {
        XCTFail("Wrong error type")
        return
    }
}
```

---

#### Task 2.2: Fix SupervisorAgent Handoff Lookup (MAJ-005)

**Problem**: `findHandoffConfiguration` compares types, not identities.

**Current Code** (`Sources/Swarm/Orchestration/SupervisorAgent.swift`, ~lines 26-31):
```swift
func findHandoffConfiguration(for targetAgent: any AgentRuntime) -> AnyHandoffConfiguration? {
    handoffs.first { config in
        let configTargetType = type(of: config.targetAgent)
        let currentType = type(of: targetAgent)
        return configTargetType == currentType  // ❌ Wrong!
    }
}
```

**Required Changes**:
```swift
func findHandoffConfiguration(for targetAgent: any AgentRuntime) -> AnyHandoffConfiguration? {
    handoffs.first { config in
        config.targetAgent === targetAgent  // ✅ Identity comparison
    }
}
```

**Note**: `===` works for class instances. If `AgentRuntime` can be structs, use:
```swift
func findHandoffConfiguration(for targetAgent: any AgentRuntime) -> AnyHandoffConfiguration? {
    handoffs.first { config in
        // Compare by object identity if class, or by custom ID if struct
        if let configAgent = config.targetAgent as? AnyObject,
           let target = targetAgent as? AnyObject {
            return configAgent === target
        }
        // Fallback: compare by name and configuration
        return config.targetAgent.name == targetAgent.name
    }
}
```

**Verification**:
```swift
let agent1 = Agent(name: "Billing", instructions: "...")
let agent2 = Agent(name: "Billing", instructions: "...")  // Same config, different instance
let handoff1 = AnyHandoffConfiguration(targetAgent: agent1, ...)
supervisor = SupervisorAgent(handoffs: [handoff1], ...)

// Should find handoff for agent1
XCTAssertNotNil(supervisor.findHandoffConfiguration(for: agent1))

// Should NOT find handoff for agent2 (different instance)
XCTAssertNil(supervisor.findHandoffConfiguration(for: agent2))
```

---

#### Task 2.3: Fix Retry Policy Off-By-One (MED-005)

**Problem**: Misleading attempt count when `maxAttempts = 0`.

**Current Code** (`Sources/Swarm/Resilience/RetryPolicy.swift`, ~lines 204-241):
```swift
var attempt = 0
while attempt <= maxAttempts {
    // ...
    attempt += 1  // Now 1
    guard attempt <= maxAttempts else { break }  // 1 <= 0, breaks
}
throw ResilienceError.retriesExhausted(attempts: attempt, ...)  // Reports 1, should be 0
```

**Required Changes**:
```swift
public func execute<T: Sendable>(
    _ operation: @Sendable () async throws -> T
) async throws -> T {
    var attempt = 1
    var retryCount = 0
    var lastError: Error?

    while true {
        do {
            return try await operation()
        } catch {
            lastError = error
            
            // Check if we should retry
            guard retryCount < maxAttempts else {
                break
            }
            
            guard shouldRetry(error) else {
                throw error
            }
            
            retryCount += 1
            attempt = retryCount + 1
            
            // Invoke retry callback
            await onRetry?(retryCount, error)
            
            // Calculate and apply backoff delay
            let delay = backoff.delay(forAttempt: retryCount)
            if delay > 0 {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }

    // All retries exhausted
    throw ResilienceError.retriesExhausted(
        attempts: attempt - 1,  // Number of retries actually performed
        lastError: lastError?.localizedDescription ?? "Unknown error"
    )
}
```

**Verification**:
```swift
let noRetry = RetryPolicy(maxAttempts: 0)
XCTAssertThrowsError(try await noRetry.execute { throw TestError() }) { error in
    guard case ResilienceError.retriesExhausted(let attempts, _) = error else {
        return XCTFail("Wrong error")
    }
    XCTAssertEqual(attempts, 0)  // Should report 0 retries, not 1
}
```

---

#### Task 2.4: Fix Agent Cancellation Race Condition (MAJ-002)

**Problem**: Potential race condition in `isCancelled`/`currentTask` access.

**Current Code** (in `Agent.swift`, `ReActAgent.swift`):
```swift
private var isCancelled: Bool = false
private var currentTask: Task<Void, Never>?

public func cancel() async {
    isCancelled = true              // State mutation
    currentTask?.cancel()           // Non-isolated access
    currentTask = nil               // State mutation
}

// In execution loop:
if isCancelled { throw AgentError.cancelled }  // Separate check from Task.checkCancellation()
```

**Required Changes**:
```swift
// Simplify - rely on Task cancellation exclusively
public func cancel() async {
    currentTask?.cancel()
}

// In execution loop - remove isCancelled flag:
try Task.checkCancellation()  // Only check needed
```

**OR** if `isCancelled` is needed for non-task contexts:
```swift
private let cancellationState = ManagedAtomic<Bool>(false)

public func cancel() async {
    cancellationState.store(true, ordering: .sequentiallyConsistent)
    currentTask?.cancel()
}

// In execution loop:
if cancellationState.load(ordering: .sequentiallyConsistent) {
    throw AgentError.cancelled
}
try Task.checkCancellation()
```

**Files to Modify**:
- `Sources/Swarm/Agents/Agent.swift`
- `Sources/Swarm/Agents/ReActAgent.swift`

**Verification**:
```swift
let agent = Agent(...)
let task = Task {
    try await agent.run("Long running task")
}
await Task.sleep(100_000_000)  // 100ms
task.cancel()
await task.value  // Should throw CancellationError
```

---

### Phase 3: MEDIUM Priority Fixes

#### Task 3.1: Deprecate Redundant Runtime Modes (MED-002)

**Problem**: Three enum cases for one behavior.

**Current Code** (`Sources/Swarm/Core/AgentConfiguration.swift`):
```swift
public enum SwarmRuntimeMode: Sendable, Equatable {
    case swift      // "Legacy mode... always uses Hive"
    case hive       // "Execute using Hive"
    case requireHive // "Alias for .hive"
}
```

**Required Changes**:
```swift
public enum SwarmRuntimeMode: Sendable, Equatable {
    /// Execute using the Hive runtime.
    case hive
    
    /// Deprecated: Previously legacy mode, now same as `.hive`.
    @available(*, deprecated, renamed: "hive")
    case swift
    
    /// Deprecated: Previously alias, now same as `.hive`.
    @available(*, deprecated, renamed: "hive")
    case requireHive
}
```

**Files to Modify**:
- `Sources/Swarm/Core/AgentConfiguration.swift`

---

## Output Format

For each task, provide:

1. **Summary**: What was changed and why
2. **Files Modified**: List of files with line ranges
3. **Breaking Changes**: Any API changes that affect users
4. **Tests Added**: New test coverage
5. **Verification**: Commands or code to verify the fix

---

## Constraints & Guidelines

### Code Quality
- Follow Swift 6.2 strict concurrency rules
- All public types must be `Sendable`
- Use `async/await` and structured concurrency
- Avoid `Any` and unnecessary type erasure
- Keep functions under 50 lines when possible

### Testing
- Write tests BEFORE or WITH implementation (TDD)
- Use Swift Testing framework
- All fixes must have test coverage
- Include edge cases and error conditions

### Backward Compatibility
- Prefer deprecation over removal
- Use `@available` annotations for API changes
- Maintain source compatibility where possible
- Document breaking changes in commit messages

### Documentation
- Update inline documentation for changed APIs
- Update README.md for platform requirement changes
- Add migration notes for breaking changes

---

## Success Criteria

- [ ] `swift build` completes without errors
- [ ] `swift test` passes (existing + new tests)
- [ ] Foundation Models can use tools (demo works)
- [ ] No compiler warnings for deprecated usages
- [ ] Code coverage for new fixes > 80%

---

## Example: Expected Output for Task 1.1

```markdown
## Task 1.1 Complete: Platform Version Fix

### Summary
Updated Package.swift to require macOS 26.0 / iOS 26.0 to align with 
dependencies (HiveCore, Wax). Updated README.md minimum requirements.

### Files Modified
- Package.swift (lines 176-184)
- README.md (lines 594-597)

### Breaking Changes
- Minimum macOS increased from 14.0 to 26.0
- Minimum iOS increased from 17.0 to 26.0

### Tests Added
None (configuration change)

### Verification
```bash
swift build
# Build succeeded with no errors
```
```

---

## Questions?

If any task is unclear:
1. Check `SWARM_ISSUES_AUDIT.md` for full details
2. Search codebase for related code patterns
3. Ask for clarification with specific file/line references

---

**Begin with Phase 1, Task 1.1. Do not proceed to Task 1.2 until build succeeds.**
