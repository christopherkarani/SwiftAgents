# Phase 1 Implementation Prompt: SwarmConfiguration + Error Improvement

## Role

You are a senior Swift 6.2 framework engineer implementing Phase 1 of the Swarm API redesign. You specialize in Apple platform frameworks, actor isolation, and TDD. You are working inside the Swarm repository at `/Users/chriskarani/CodingProjects/AIStack/Swarm/`.

Your goal: Create the `Swarm.configure(provider:)` global entry point and the `toolCallingRequiresCloudProvider` error case, following strict TDD (write failing tests first, then make them pass).

## Context

### What is Swarm?

Swarm is a Swift 6.2 multi-agent orchestration framework for Apple platforms (macOS 26+, iOS 26+). It provides agent reasoning, memory, tool execution, and multi-agent coordination on top of pluggable inference providers.

### Why Phase 1 Matters

Today, developers must pass an `InferenceProvider` to every `Agent(...)` init call or use `.environment()`. Phase 1 introduces a one-line global setup:

```swift
await Swarm.configure(provider: AnthropicProvider(apiKey: "sk-..."))
```

After this, ALL agents resolve the global provider automatically. This is the foundation every subsequent phase builds on.

### Target API (Source of Truth)

After Phase 1, this code must compile and work:

```swift
// Scenario 2: Cloud Provider Setup
await Swarm.configure(provider: AnthropicProvider(apiKey: "sk-..."))
let result = try await MathAssistant().run("What is 137 * 42?")

// Scenario 10: Agent escape hatch (already works, verify not broken)
let agent = try Agent(
    tools: [CustomerLookupTool()],
    instructions: "You are a professional customer service agent.",
    inputGuardrails: [NoPIIGuardrail()],
    outputGuardrails: [ProfessionalToneGuardrail()]
)
let result = try await agent.run("Look up account for John")
```

### Locked Decisions

| Decision | Choice |
|----------|--------|
| Global config type | `enum Swarm` (no instances) with static async methods |
| Internal storage | Nested `actor Configuration` (thread-safe singleton) |
| Two provider slots | `configure(provider:)` for general, `configure(cloudProvider:)` for tool-calling |
| New error case | `AgentError.toolCallingRequiresCloudProvider` (no associated values) |
| Recovery suggestion | `recoverySuggestion` computed property on `AgentError` |
| Provider resolution | 6-step chain (see instructions) |
| Test reset | `Swarm.reset()` clears both providers (test-only) |

### Current Source Files

#### File: `Sources/Swarm/Core/AgentError.swift`

```swift
public enum AgentError: Error, Sendable, Equatable {
    case invalidInput(reason: String)
    case cancelled
    case maxIterationsExceeded(iterations: Int)
    case timeout(duration: Duration)
    case invalidLoop(reason: String)
    case toolNotFound(name: String)
    case toolExecutionFailed(toolName: String, underlyingError: String)
    case invalidToolArguments(toolName: String, reason: String)
    case inferenceProviderUnavailable(reason: String)
    case contextWindowExceeded(tokenCount: Int, limit: Int)
    case guardrailViolation(reason: String)
    case contentFiltered(reason: String)
    case unsupportedLanguage(language: String)
    case generationFailed(reason: String)
    case modelNotAvailable(model: String)
    case rateLimitExceeded(retryAfter: TimeInterval?)
    case embeddingFailed(reason: String)
    case agentNotFound(name: String)
    case internalError(reason: String)
}

// Has extensions: LocalizedError (errorDescription), CustomDebugStringConvertible (debugDescription)
// Does NOT currently have recoverySuggestion
```

#### File: `Sources/Swarm/Providers/LanguageModelSession.swift`

```swift
#if canImport(FoundationModels)
import FoundationModels

@available(macOS 26.0, iOS 26.0, *)
extension LanguageModelSession: InferenceProvider {
    public func generateWithToolCalls(
        prompt: String,
        tools: [ToolSchema],
        options: InferenceOptions
    ) async throws -> InferenceResponse {
        if !tools.isEmpty {
            // THIS LINE MUST CHANGE:
            throw AgentError.generationFailed(
                reason: "Foundation Models tool calling is not supported by Swarm's LanguageModelSession provider."
            )
        }
        let content = try await generate(prompt: prompt, options: options)
        return InferenceResponse(content: content, toolCalls: [], finishReason: .completed)
    }
}
#endif
```

#### File: `Sources/Swarm/Agents/Agent.swift` — Provider Resolution (lines 440-461)

```swift
private func resolvedInferenceProvider() throws -> any InferenceProvider {
    // Step 1: Explicit provider on Agent
    if let inferenceProvider {
        return inferenceProvider
    }
    // Step 2: TaskLocal via .environment()
    if let environmentProvider = AgentEnvironmentValues.current.inferenceProvider {
        return environmentProvider
    }
    // Step 3: Foundation Models (current — needs to become steps 3-5)
    if let foundationModelsProvider = DefaultInferenceProviderFactory.makeFoundationModelsProviderIfAvailable() {
        return foundationModelsProvider
    }
    // Step 4: Throw (current — becomes step 6)
    throw AgentError.inferenceProviderUnavailable(reason: "...")
}
```

#### File: `Sources/Swarm/Providers/DefaultInferenceProviderFactory.swift`

```swift
enum DefaultInferenceProviderFactory {
    static func makeFoundationModelsProviderIfAvailable() -> (any InferenceProvider)? {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, visionOS 26.0, *) {
            let model = SystemLanguageModel.default
            guard model.availability == .available else { return nil }
            return FoundationModelsInferenceProvider()
        }
        #endif
        return nil
    }
}
```

#### File: `Tests/SwarmTests/Mocks/MockInferenceProvider.swift`

```swift
public actor MockInferenceProvider: InferenceProvider {
    public var responses: [String] = []
    public var defaultResponse = "Final Answer: Mock response"
    public var errorToThrow: Error?
    // ... (full actor with generate, stream, generateWithToolCalls)
    public init() {}
    public init(responses: [String]) { self.responses = responses }
}
```

#### File: `Tests/SwarmTests/Mocks/MockTool.swift`

```swift
public struct MockTool: AnyJSONTool, Sendable {
    public let name: String
    public let description: String
    public let parameters: [ToolParameter]
    public init(name: String = "mock_tool", ..., result: SendableValue = .string("mock result"), ...)
    public func execute(arguments: [String: SendableValue]) async throws -> SendableValue
}
```

### Project Conventions

- **Testing**: Swift Testing (`import Testing`, `@Suite`, `@Test`) — NOT XCTest
- **Concurrency**: `StrictConcurrency` enabled on ALL targets. All public types must be `Sendable`
- **Logging**: `swift-log` category loggers (`Log.agents`, etc.) — never `print()`
- **Formatting**: Run `swift package plugin --allow-writing-to-package-directory swiftformat` after changes
- **Imports**: Use `@testable import Swarm` in tests
- **Mocks**: Live in `Tests/SwarmTests/Mocks/`
- **File structure**: Tests mirror source: `Tests/SwarmTests/Core/`, `Tests/SwarmTests/Agents/`, etc.

## Instructions

Execute in this exact order. Do NOT skip steps or combine them.

### Step 1: Write Failing Tests (TDD Red Phase)

Create the test file first. All tests should fail to compile or fail at runtime — that's correct.

**Create file**: `Tests/SwarmTests/Core/SwarmConfigurationTests.swift`

Write these tests:

```swift
import Testing
@testable import Swarm

@Suite("SwarmConfiguration")
struct SwarmConfigurationTests {

    // --- Test 1: configure(provider:) stores and retrieves ---
    @Test("configure sets global provider")
    func configureProvider() async throws {
        let mock = MockInferenceProvider()
        await Swarm.configure(provider: mock)
        let resolved = await Swarm.defaultProvider
        #expect(resolved != nil)
        await Swarm.reset()
    }

    // --- Test 2: configure(cloudProvider:) stores separately ---
    @Test("configure with cloud provider")
    func configureCloudProvider() async throws {
        let mock = MockInferenceProvider()
        await Swarm.configure(cloudProvider: mock)
        let resolved = await Swarm.cloudProvider
        #expect(resolved != nil)
        await Swarm.reset()
    }

    // --- Test 3: reset() clears both ---
    @Test("reset clears all providers")
    func resetConfiguration() async throws {
        let mock = MockInferenceProvider()
        await Swarm.configure(provider: mock)
        await Swarm.configure(cloudProvider: mock)
        await Swarm.reset()
        let p = await Swarm.defaultProvider
        let c = await Swarm.cloudProvider
        #expect(p == nil)
        #expect(c == nil)
    }

    // --- Test 4: Agent resolves global provider ---
    @Test("Agent resolves Swarm.defaultProvider when no explicit provider")
    func agentResolvesGlobalProvider() async throws {
        let mock = MockInferenceProvider(responses: ["from global"])
        await Swarm.configure(provider: mock)
        let agent = try Agent(instructions: "test")
        let result = try await agent.run("hello")
        #expect(result.output == "from global")
        await Swarm.reset()
    }

    // --- Test 5: Explicit provider takes priority over global ---
    @Test("Explicit provider on Agent takes priority over global")
    func explicitProviderPriority() async throws {
        let globalMock = MockInferenceProvider(responses: ["from global"])
        let explicitMock = MockInferenceProvider(responses: ["from explicit"])
        await Swarm.configure(provider: globalMock)
        let agent = try Agent(instructions: "test", inferenceProvider: explicitMock)
        let result = try await agent.run("hello")
        #expect(result.output == "from explicit")
        await Swarm.reset()
    }

    // --- Test 6: cloudProvider resolves for agents with tools ---
    @Test("Agent with tools resolves Swarm.cloudProvider")
    func cloudProviderForToolAgents() async throws {
        let cloudMock = MockInferenceProvider(responses: ["from cloud"])
        await Swarm.configure(cloudProvider: cloudMock)
        let tool = MockTool(name: "test_tool")
        let agent = try Agent(tools: [tool], instructions: "test")
        let result = try await agent.run("use tool")
        #expect(result.output == "from cloud")
        await Swarm.reset()
    }

    // --- Test 7: defaultProvider preferred over cloudProvider ---
    @Test("defaultProvider preferred over cloudProvider for toolless agents")
    func defaultPreferredOverCloud() async throws {
        let defaultMock = MockInferenceProvider(responses: ["from default"])
        let cloudMock = MockInferenceProvider(responses: ["from cloud"])
        await Swarm.configure(provider: defaultMock)
        await Swarm.configure(cloudProvider: cloudMock)
        let agent = try Agent(instructions: "test")
        let result = try await agent.run("hello")
        #expect(result.output == "from default")
        await Swarm.reset()
    }
}
```

**Add to existing file**: `Tests/SwarmTests/Core/AgentErrorTests.swift` (create if it doesn't exist)

```swift
import Testing
@testable import Swarm

@Suite("AgentError — toolCallingRequiresCloudProvider")
struct ToolCallingErrorTests {

    @Test("toolCallingRequiresCloudProvider has correct error description")
    func errorDescription() {
        let error = AgentError.toolCallingRequiresCloudProvider
        #expect(error.errorDescription?.contains("Foundation Models") == true)
        #expect(error.errorDescription?.contains("tool calling") == true)
    }

    @Test("toolCallingRequiresCloudProvider has recovery suggestion mentioning Swarm.configure")
    func recoverySuggestion() {
        let error = AgentError.toolCallingRequiresCloudProvider
        #expect(error.recoverySuggestion != nil)
        #expect(error.recoverySuggestion!.contains("Swarm.configure") == true)
    }

    @Test("toolCallingRequiresCloudProvider has debug description")
    func debugDescription() {
        let error = AgentError.toolCallingRequiresCloudProvider
        #expect(error.debugDescription.contains("toolCallingRequiresCloudProvider"))
    }

    @Test("existing error cases still have nil recoverySuggestion")
    func existingErrorsNoRecovery() {
        let error = AgentError.cancelled
        #expect(error.recoverySuggestion == nil)
    }
}
```

### Step 2: Create SwarmConfiguration.swift (TDD Green Phase — Part 1)

**Create file**: `Sources/Swarm/Core/SwarmConfiguration.swift`

```swift
// SwarmConfiguration.swift
// Swarm Framework
//
// Global configuration entry point for the Swarm framework.

import Foundation

/// Global configuration for the Swarm framework.
///
/// Call `Swarm.configure(provider:)` once at app launch to set the default
/// inference provider for all agents:
///
/// ```swift
/// await Swarm.configure(provider: AnthropicProvider(apiKey: key))
/// ```
///
/// For hybrid setups where Foundation Models handle chat but a cloud provider
/// handles tool calling:
///
/// ```swift
/// await Swarm.configure(cloudProvider: AnthropicProvider(apiKey: key))
/// ```
public enum Swarm {

    // MARK: - Public API

    /// Sets the default inference provider for all agents.
    ///
    /// Agents resolve providers in this order:
    /// 1. Explicit provider on the agent
    /// 2. TaskLocal via `.environment(\.inferenceProvider, ...)`
    /// 3. `Swarm.defaultProvider` (set here)
    /// 4. `Swarm.cloudProvider` (if agent has tools)
    /// 5. Foundation Models (if no tools, on Apple platform)
    /// 6. Throw `AgentError.inferenceProviderUnavailable`
    public static func configure(provider: some InferenceProvider) async {
        await Configuration.shared.setProvider(provider)
    }

    /// Sets a cloud provider for tool-calling agents.
    ///
    /// Foundation Models do not support tool calling. Use this to configure
    /// a cloud provider (Anthropic, OpenAI, Ollama) specifically for agents
    /// that use tools, while letting Foundation Models handle plain chat.
    public static func configure(cloudProvider: some InferenceProvider) async {
        await Configuration.shared.setCloudProvider(cloudProvider)
    }

    /// The currently configured default provider, if any.
    public static var defaultProvider: (any InferenceProvider)? {
        get async { await Configuration.shared.provider }
    }

    /// The currently configured cloud provider for tool calling, if any.
    public static var cloudProvider: (any InferenceProvider)? {
        get async { await Configuration.shared.cloud }
    }

    /// Resets all configuration. Intended for testing only.
    public static func reset() async {
        await Configuration.shared.reset()
    }

    // MARK: - Internal Storage

    actor Configuration {
        static let shared = Configuration()
        private(set) var provider: (any InferenceProvider)?
        private(set) var cloud: (any InferenceProvider)?

        func setProvider(_ p: some InferenceProvider) {
            provider = p
        }

        func setCloudProvider(_ p: some InferenceProvider) {
            cloud = p
        }

        func reset() {
            provider = nil
            cloud = nil
        }
    }
}
```

### Step 3: Update AgentError.swift (TDD Green Phase — Part 2)

Add the new error case and `recoverySuggestion` property.

**In `Sources/Swarm/Core/AgentError.swift`:**

1. Add new case after `internalError`:

```swift
    /// Tool calling was requested but Foundation Models do not support it.
    case toolCallingRequiresCloudProvider
```

2. Add to `errorDescription` switch in `LocalizedError` extension:

```swift
        case .toolCallingRequiresCloudProvider:
            "Foundation Models do not support tool calling. A cloud provider is required."
```

3. Add new `recoverySuggestion` computed property in `LocalizedError` extension:

```swift
    public var recoverySuggestion: String? {
        switch self {
        case .toolCallingRequiresCloudProvider:
            "Call Swarm.configure(cloudProvider:) with an Anthropic, OpenAI, or Ollama provider."
        default:
            nil
        }
    }
```

4. Add to `debugDescription` switch in `CustomDebugStringConvertible` extension:

```swift
        case .toolCallingRequiresCloudProvider:
            return "AgentError.toolCallingRequiresCloudProvider"
```

### Step 4: Update LanguageModelSession.swift (TDD Green Phase — Part 3)

**In `Sources/Swarm/Providers/LanguageModelSession.swift`:**

Replace the error in `generateWithToolCalls`:

```swift
// BEFORE:
throw AgentError.generationFailed(
    reason: "Foundation Models tool calling is not supported by Swarm's LanguageModelSession provider."
)

// AFTER:
throw AgentError.toolCallingRequiresCloudProvider
```

### Step 5: Update Agent.swift Provider Resolution (TDD Green Phase — Part 4)

**In `Sources/Swarm/Agents/Agent.swift`:**

Replace the `resolvedInferenceProvider()` method (around line 440) with this 6-step resolution:

```swift
private func resolvedInferenceProvider() async throws -> any InferenceProvider {
    // 1. Explicit provider on Agent
    if let inferenceProvider {
        return inferenceProvider
    }

    // 2. TaskLocal via .environment()
    if let environmentProvider = AgentEnvironmentValues.current.inferenceProvider {
        return environmentProvider
    }

    // 3. Swarm.defaultProvider (global)
    if let globalProvider = await Swarm.defaultProvider {
        return globalProvider
    }

    // 4. Swarm.cloudProvider (if agent has tools)
    if !tools.isEmpty, let cloudProvider = await Swarm.cloudProvider {
        return cloudProvider
    }

    // 5. Foundation Models (if available, on Apple platform)
    if let foundationModelsProvider = DefaultInferenceProviderFactory.makeFoundationModelsProviderIfAvailable() {
        return foundationModelsProvider
    }

    // 6. No provider available
    throw AgentError.inferenceProviderUnavailable(
        reason: """
        No inference provider configured and Apple Foundation Models are unavailable.

        Configure a provider globally via `await Swarm.configure(provider: ...)` \
        or pass one explicitly to Agent(...).
        """
    )
}
```

**CRITICAL**: The method signature changes from `throws` to `async throws` because it now calls `await Swarm.defaultProvider` and `await Swarm.cloudProvider`. You must update ALL call sites of `resolvedInferenceProvider()` within `Agent.swift` to add `await`. Search for every call to `resolvedInferenceProvider()` and add `await` before it.

Also update the doc comment at the top of `Agent.swift` to reflect the new 6-step resolution order:

```swift
/// Provider resolution order is:
/// 1. An explicit provider passed to `Agent(...)`
/// 2. A provider set via `.environment(\.inferenceProvider, ...)`
/// 3. `Swarm.defaultProvider` (set via `Swarm.configure(provider:)`)
/// 4. `Swarm.cloudProvider` (set via `Swarm.configure(cloudProvider:)`, if agent has tools)
/// 5. Apple Foundation Models (on-device), if available
/// 6. Otherwise, throw `AgentError.inferenceProviderUnavailable`
```

### Step 6: Build and Run Tests

```bash
swift build 2>&1 | head -50
swift test --filter SwarmConfigurationTests 2>&1
swift test --filter ToolCallingErrorTests 2>&1
swift test 2>&1 | tail -30
```

Fix any compilation errors. All existing tests must continue to pass. All new tests must pass.

### Step 7: Format Code

```bash
swift package plugin --allow-writing-to-package-directory swiftformat
```

## Success Criteria

All of the following must be true when you are done:

1. `swift build` succeeds with zero errors and zero warnings in changed files
2. `SwarmConfigurationTests` — all 7 tests pass
3. `ToolCallingErrorTests` — all 4 tests pass
4. `swift test` — ALL existing tests still pass (zero regressions)
5. `Swarm.configure(provider:)` and `Swarm.configure(cloudProvider:)` are public async methods
6. `Swarm.defaultProvider` and `Swarm.cloudProvider` are public async-get properties
7. `Swarm.reset()` clears both providers
8. `AgentError.toolCallingRequiresCloudProvider` exists with no associated values
9. `AgentError.recoverySuggestion` returns a non-nil string for `toolCallingRequiresCloudProvider` and nil for all other cases
10. `LanguageModelSession.generateWithToolCalls` throws `toolCallingRequiresCloudProvider` (not `generationFailed`)
11. `Agent.resolvedInferenceProvider()` follows the 6-step resolution chain
12. No `print()` statements in production code
13. All new types are `Sendable`

## Files Changed Summary

| File | Action | What Changes |
|------|--------|-------------|
| `Tests/SwarmTests/Core/SwarmConfigurationTests.swift` | CREATE | 7 tests for Swarm.configure + provider resolution |
| `Tests/SwarmTests/Core/AgentErrorTests.swift` | CREATE | 4 tests for new error case + recoverySuggestion |
| `Sources/Swarm/Core/SwarmConfiguration.swift` | CREATE | `enum Swarm` with configure/reset/providers |
| `Sources/Swarm/Core/AgentError.swift` | MODIFY | Add `toolCallingRequiresCloudProvider` case + `recoverySuggestion` |
| `Sources/Swarm/Providers/LanguageModelSession.swift` | MODIFY | Change thrown error type |
| `Sources/Swarm/Agents/Agent.swift` | MODIFY | 6-step provider resolution + async + doc update |

## Edge Cases to Watch

1. **`resolvedInferenceProvider()` becomes `async`**: Every call site in Agent.swift must add `await`. Search thoroughly — miss one and you get a compiler error.
2. **`Equatable` conformance**: `AgentError` conforms to `Equatable`. The new case has no associated values so this is automatic, but verify.
3. **Test isolation**: Every test must call `await Swarm.reset()` in cleanup to avoid cross-test pollution. The singleton actor persists across tests.
4. **`MockInferenceProvider` is an actor**: It's created with `MockInferenceProvider()` (no `await`), but setting responses requires `await`. The `init(responses:)` convenience initializer handles this.
5. **ChatAgent.swift also calls a provider**: Check if `ChatAgent` (in `Sources/Swarm/Agents/Chat.swift`) has its own `resolvedInferenceProvider` or uses the same pattern. If it resolves providers inline, it may also need the global fallback. Audit this.
6. **Namespace collision**: `Swarm` is both the module name and the new `enum Swarm`. Swift resolves this correctly in expression position (`Swarm.configure(...)` refers to the type). In import position (`import Swarm`) it refers to the module. This is a known Swift pattern. Do NOT rename.
