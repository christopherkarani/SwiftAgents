# Conduit Framework Enhancement Plan

## Overview

This document outlines potential enhancements to the Conduit framework that would improve its integration with SwiftAgents and general usability. **These changes are optional** — SwiftAgents can work with Conduit as-is, but these enhancements would provide a cleaner integration.

**Key Principle**: Conduit remains standalone and independently useful. These enhancements benefit all Conduit users, not just SwiftAgents.

---

## Enhancement Categories

### Category 1: Tool Calling Improvements (Priority: High)

#### 1.1 Unified Tool Call Response Type

**Current State**: Tool calls are returned differently by each provider (Anthropic, OpenAI, etc.), and parsing logic is scattered.

**Enhancement**: Create a unified `AIToolCall` type that all providers return consistently.

```swift
// Currently exists but may need standardization across providers
public struct AIToolCall: Sendable, Identifiable {
    public let id: String
    public let toolName: String
    public let arguments: Data  // JSON data

    /// Parsed arguments as StructuredContent
    public var parsedArguments: StructuredContent {
        try? JSONDecoder().decode(StructuredContent.self, from: arguments)
    }
}
```

**Location**: `Sources/Conduit/Tools/AIToolCall.swift`

**Status**: ⚠️ Verify current implementation consistency

---

#### 1.2 Tool Execution Helper

**Current State**: Users must manually execute tools and format responses.

**Enhancement**: Add a `ToolExecutor` helper that automates tool execution.

```swift
public protocol ToolExecutor: Sendable {
    /// Executes a tool call and returns the formatted output.
    func execute(
        _ toolCall: AIToolCall,
        using tools: [any AITool]
    ) async throws -> AIToolOutput

    /// Executes multiple tool calls in parallel.
    func executeAll(
        _ toolCalls: [AIToolCall],
        using tools: [any AITool]
    ) async throws -> [AIToolOutput]
}

public struct DefaultToolExecutor: ToolExecutor {
    public func execute(
        _ toolCall: AIToolCall,
        using tools: [any AITool]
    ) async throws -> AIToolOutput {
        guard let tool = tools.first(where: { $0.name == toolCall.toolName }) else {
            throw AIError.invalidInput("Unknown tool: \(toolCall.toolName)")
        }

        let result = try await tool.call(toolCall.arguments)
        return AIToolOutput(
            id: toolCall.id,
            toolName: toolCall.toolName,
            content: result.promptRepresentation
        )
    }
}
```

**Location**: `Sources/Conduit/Tools/ToolExecutor.swift`

**Benefit**: SwiftAgents (and all users) get automatic tool execution without reinventing the wheel.

---

### Category 2: Response Type Enhancements (Priority: Medium)

#### 2.1 Tool Calls in GenerationResult

**Current State**: Unclear if `GenerationResult` includes tool calls consistently.

**Enhancement**: Ensure `GenerationResult` has a clear, typed `toolCalls` property.

```swift
public struct GenerationResult: Sendable {
    public let text: String
    public let tokenCount: Int
    public let generationTime: TimeInterval
    public let tokensPerSecond: Double
    public let finishReason: FinishReason
    public let usage: UsageStats?

    /// Tool calls requested by the model (if any).
    public let toolCalls: [AIToolCall]?  // <-- Ensure this exists

    /// Whether the response contains tool calls.
    public var hasToolCalls: Bool {
        !(toolCalls ?? []).isEmpty
    }
}
```

**Location**: `Sources/Conduit/Core/GenerationResult.swift`

---

#### 2.2 Streaming Tool Call Support

**Current State**: Tool calls during streaming may not be well-handled.

**Enhancement**: Add tool call boundaries to streaming chunks.

```swift
public struct GenerationChunk: Sendable {
    // Existing properties...

    /// Tool call being constructed (for streaming tool calls).
    public let partialToolCall: PartialToolCall?

    /// Completed tool calls in this chunk.
    public let completedToolCalls: [AIToolCall]?
}

public struct PartialToolCall: Sendable {
    public let id: String
    public let toolName: String
    public let argumentsFragment: String  // Partial JSON
}
```

**Location**: `Sources/Conduit/Core/GenerationChunk.swift`

**Benefit**: Enables real-time tool call UI updates during streaming.

---

### Category 3: Provider Improvements (Priority: Medium)

#### 3.1 Foundation Models Provider Implementation

**Current State**: Configuration exists but implementation may be incomplete.

**Enhancement**: Complete the FoundationModelsProvider implementation.

```swift
@available(iOS 26.0, macOS 26.0, *)
public actor FoundationModelsProvider: AIProvider, TextGenerator {
    private let systemModel: SystemLanguageModel

    public init() {
        self.systemModel = SystemLanguageModel.default
    }

    public func generate(
        messages: [Message],
        model: ModelIdentifier,
        config: GenerateConfig
    ) async throws -> GenerationResult {
        // Implementation using Apple's Foundation Models API
    }

    public func stream(
        messages: [Message],
        model: ModelIdentifier,
        config: GenerateConfig
    ) -> AsyncThrowingStream<GenerationChunk, Error> {
        // Implementation
    }
}
```

**Location**: `Sources/Conduit/Providers/FoundationModels/FoundationModelsProvider.swift`

---

#### 3.2 Provider Protocol Refinement

**Current State**: `AIProvider` has associated types that may complicate generic usage.

**Enhancement**: Add a type-erased wrapper for easier composition.

```swift
/// Type-erased wrapper for any AIProvider.
public struct AnyAIProvider: AIProvider {
    private let _generate: (
        [Message],
        ModelIdentifier,
        GenerateConfig
    ) async throws -> GenerationResult

    private let _stream: (
        [Message],
        ModelIdentifier,
        GenerateConfig
    ) -> AsyncThrowingStream<GenerationChunk, Error>

    public init<P: AIProvider>(_ provider: P) where P.Response == GenerationResult {
        self._generate = provider.generate
        self._stream = { messages, model, config in
            // Map P.StreamChunk to GenerationChunk
        }
    }
}
```

**Location**: `Sources/Conduit/Core/AnyAIProvider.swift`

**Benefit**: Enables storing heterogeneous providers, switching at runtime.

---

### Category 4: Error Handling (Priority: Low)

#### 4.1 Error Context Enhancement

**Current State**: Some error cases lack detailed context.

**Enhancement**: Add request context to errors for debugging.

```swift
public enum AIError: Error, Sendable {
    // Existing cases...

    /// The original request that caused the error (for debugging).
    public var requestContext: RequestContext? {
        // Computed property extracting context
    }
}

public struct RequestContext: Sendable {
    public let modelIdentifier: ModelIdentifier
    public let messageCount: Int
    public let toolCount: Int
    public let timestamp: Date
}
```

---

#### 4.2 Retry-After Standardization

**Current State**: Rate limit errors may inconsistently include retry timing.

**Enhancement**: Ensure all providers populate `retryAfter` correctly.

```swift
case rateLimited(retryAfter: TimeInterval?, context: RateLimitContext?)

public struct RateLimitContext: Sendable {
    public let requestsRemaining: Int?
    public let resetTime: Date?
    public let limitType: LimitType  // .requests, .tokens, .daily
}
```

---

### Category 5: Testing Support (Priority: Low)

#### 5.1 Mock Provider for Testing

**Current State**: No official mock provider for testing.

**Enhancement**: Add a `MockAIProvider` for testing.

```swift
/// Mock provider for testing without network calls.
public actor MockAIProvider: AIProvider, TextGenerator {
    public var responses: [GenerationResult] = []
    public var streamChunks: [[GenerationChunk]] = []
    public var errorToThrow: AIError?

    private var responseIndex = 0

    public func generate(
        messages: [Message],
        model: ModelIdentifier,
        config: GenerateConfig
    ) async throws -> GenerationResult {
        if let error = errorToThrow { throw error }
        defer { responseIndex += 1 }
        return responses[responseIndex % responses.count]
    }

    // Record calls for assertions
    public private(set) var generateCalls: [(messages: [Message], model: ModelIdentifier, config: GenerateConfig)] = []
}
```

**Location**: `Sources/Conduit/Testing/MockAIProvider.swift`

**Benefit**: Both Conduit and SwiftAgents users can test without live API calls.

---

## Implementation Priority

| Enhancement | Priority | Effort | Benefit |
|-------------|----------|--------|---------|
| 1.2 Tool Executor | High | Medium | Reduces boilerplate for all users |
| 2.1 Tool Calls in GenerationResult | High | Low | API consistency |
| 3.1 Foundation Models Provider | Medium | High | Platform completeness |
| 5.1 Mock Provider | Medium | Low | Testing support |
| 2.2 Streaming Tool Calls | Medium | Medium | Real-time UI support |
| 3.2 AnyAIProvider | Low | Medium | Flexibility |
| 4.1 Error Context | Low | Low | Debugging |

---

## Recommendation

### For Immediate SwiftAgents Integration

**No Conduit changes required.** SwiftAgents can implement:
- Tool execution logic in SwiftAgents (already exists)
- Tool call parsing in the adapter layer
- Mock providers in SwiftAgents test target

### For Long-Term Improvement

Consider adding these to Conduit over time:
1. **Tool Executor** - Benefits all Conduit users
2. **Mock Provider** - Essential for testing
3. **Foundation Models** - Platform completeness

---

## Notes

- All enhancements should maintain Conduit's standalone nature
- Changes should benefit Conduit users generally, not just SwiftAgents
- API additions should follow Conduit's existing patterns
- Breaking changes should be avoided; use additive API design
