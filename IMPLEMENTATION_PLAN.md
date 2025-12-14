# SwiftAgents API Enhancement Implementation Plan

This document outlines the implementation plan for enhancing the SwiftAgents framework API through improved generics and DSL patterns.

## Overview

The enhancements are organized into 10 features, prioritized by impact and dependency order. Each feature includes TDD tests located in `Tests/SwiftAgentsTests/DSL/`.

## Implementation Phases

### Phase 1: Foundation (Week 1-2)
Core types and protocols that other features depend on.

### Phase 2: DSL Builders (Week 2-3)
Result builders and fluent APIs for declarative construction.

### Phase 3: Composition (Week 3-4)
Operators and patterns for combining agents.

### Phase 4: Streaming & Resilience (Week 4-5)
Stream operations and fault tolerance patterns.

---

## Feature 1: TypedTool Protocol

**Priority:** High
**Tests:** `TypedToolTests.swift`
**Location:** `Sources/SwiftAgents/Tools/TypedTool.swift`

### Implementation Steps

1. **Define TypedTool protocol with associated Output type**
   ```swift
   public protocol TypedTool<Output>: Tool {
       associatedtype Output: Sendable & Codable
       func executeTyped(arguments: [String: SendableValue]) async throws -> Output
   }
   ```

2. **Add default Tool.execute implementation via protocol extension**
   - Encode Output to SendableValue using Codable
   - Handle encoding errors gracefully

3. **Add SendableValue encoding/decoding for Codable types**
   ```swift
   extension SendableValue {
       init<T: Encodable>(encoding value: T) throws
       func decode<T: Decodable>() throws -> T
   }
   ```

4. **Update ToolRegistry to work with TypedTool**
   - Add generic execute method that returns typed output
   - Maintain backward compatibility with existing Tool protocol

### Files to Create/Modify
- `Sources/SwiftAgents/Tools/TypedTool.swift` (new)
- `Sources/SwiftAgents/Core/SendableValue.swift` (modify)
- `Sources/SwiftAgents/Tools/Tool.swift` (modify)

---

## Feature 2: ToolParameterBuilder DSL

**Priority:** High
**Tests:** `ToolParameterBuilderTests.swift`
**Location:** `Sources/SwiftAgents/Tools/ToolParameterBuilder.swift`

### Implementation Steps

1. **Create ToolParameterBuilder result builder**
   ```swift
   @resultBuilder
   public struct ToolParameterBuilder {
       public static func buildBlock(_ params: ToolParameter...) -> [ToolParameter]
       public static func buildOptional(_ param: ToolParameter?) -> [ToolParameter]
       public static func buildEither(first: ToolParameter) -> [ToolParameter]
       public static func buildEither(second: ToolParameter) -> [ToolParameter]
       public static func buildArray(_ arrays: [[ToolParameter]]) -> [ToolParameter]
   }
   ```

2. **Create Parameter factory function**
   ```swift
   public func Parameter(
       _ name: String,
       description: String,
       type: ToolParameter.ParameterType,
       required: Bool = true,
       default: SendableValue? = nil
   ) -> ToolParameter
   ```

3. **Add convenience overloads for common default types**
   - Integer defaults
   - String defaults
   - Boolean defaults

4. **Update Tool protocol to support builder syntax**
   - Add `@ToolParameterBuilder` attribute support

### Files to Create/Modify
- `Sources/SwiftAgents/Tools/ToolParameterBuilder.swift` (new)
- `Sources/SwiftAgents/Tools/Tool.swift` (modify)

---

## Feature 3: AgentBuilder DSL

**Priority:** Medium
**Tests:** `AgentBuilderTests.swift`
**Location:** `Sources/SwiftAgents/Core/AgentBuilder.swift`

### Implementation Steps

1. **Define AgentComponent protocol and implementations**
   ```swift
   public protocol AgentComponent {}

   public struct Instructions: AgentComponent { ... }
   public struct Tools: AgentComponent { ... }
   public struct Memory: AgentComponent { ... }
   public struct Configuration: AgentComponent { ... }
   ```

2. **Create AgentBuilder result builder**
   ```swift
   @resultBuilder
   public struct AgentBuilder {
       public static func buildBlock(_ components: AgentComponent...) -> [AgentComponent]
   }
   ```

3. **Create ToolArrayBuilder for Tools component**
   ```swift
   @resultBuilder
   public struct ToolArrayBuilder {
       public static func buildBlock(_ tools: any Tool...) -> [any Tool]
   }
   ```

4. **Add initializer to ReActAgent using builder**
   ```swift
   public init(@AgentBuilder _ content: () -> [AgentComponent])
   ```

### Files to Create/Modify
- `Sources/SwiftAgents/Core/AgentBuilder.swift` (new)
- `Sources/SwiftAgents/Agents/ReActAgent.swift` (modify)

---

## Feature 4: Typed Pipeline Operators

**Priority:** Medium
**Tests:** `TypedPipelineTests.swift`
**Location:** `Sources/SwiftAgents/Orchestration/Pipeline.swift`

### Implementation Steps

1. **Define generic Pipeline struct**
   ```swift
   public struct Pipeline<Input: Sendable, Output: Sendable>: Sendable {
       public let execute: @Sendable (Input) async throws -> Output
   }
   ```

2. **Implement map and flatMap methods**
   ```swift
   extension Pipeline {
       func map<NewOutput>(_ transform: @escaping (Output) -> NewOutput) -> Pipeline<Input, NewOutput>
       func flatMap<NewOutput>(_ transform: @escaping (Output) -> Pipeline<Output, NewOutput>) -> Pipeline<Input, NewOutput>
   }
   ```

3. **Create >>> operator for pipeline chaining**
   ```swift
   public func >>> <A, B, C>(lhs: Pipeline<A, B>, rhs: Pipeline<B, C>) -> Pipeline<A, C>
   ```

4. **Add Agent.asPipeline() extension**
   ```swift
   extension Agent {
       func asPipeline() -> Pipeline<String, AgentResult>
   }
   ```

### Files to Create/Modify
- `Sources/SwiftAgents/Orchestration/Pipeline.swift` (new)

---

## Feature 5: Typed ContextKey

**Priority:** Medium
**Tests:** `TypedContextKeyTests.swift`
**Location:** `Sources/SwiftAgents/Orchestration/ContextKey.swift`

### Implementation Steps

1. **Define generic ContextKey struct**
   ```swift
   public struct ContextKey<Value: Sendable>: Hashable, Sendable {
       public let name: String
   }
   ```

2. **Add typed accessors to AgentContext**
   ```swift
   extension AgentContext {
       func setTyped<T: Sendable & Codable>(_ key: ContextKey<T>, value: T) async
       func getTyped<T: Sendable & Codable>(_ key: ContextKey<T>) async -> T?
       func getTyped<T: Sendable & Codable>(_ key: ContextKey<T>, default: T) async -> T
   }
   ```

3. **Define standard context keys**
   ```swift
   extension ContextKey where Value == String {
       static let userID = ContextKey("user_id")
       static let sessionID = ContextKey("session_id")
   }
   ```

4. **Add typed route condition**
   ```swift
   extension RouteCondition {
       static func contextHasTyped<T: Equatable>(_ key: ContextKey<T>, equalTo: T) -> RouteCondition
   }
   ```

### Files to Create/Modify
- `Sources/SwiftAgents/Orchestration/ContextKey.swift` (new)
- `Sources/SwiftAgents/Orchestration/AgentContext.swift` (modify)
- `Sources/SwiftAgents/Orchestration/AgentRouter.swift` (modify)

---

## Feature 6: Fluent Resilience Integration

**Priority:** High
**Tests:** `FluentResilienceTests.swift`
**Location:** `Sources/SwiftAgents/Resilience/ResilientAgent.swift`

### Implementation Steps

1. **Create ResilientAgent wrapper**
   ```swift
   public actor ResilientAgent: Agent {
       private let base: any Agent
       private let retry: RetryPolicy?
       private let circuitBreaker: CircuitBreaker?
       private let fallback: (any Agent)?
       private let timeout: Duration?
   }
   ```

2. **Add fluent extension methods to Agent protocol**
   ```swift
   extension Agent {
       func withRetry(_ policy: RetryPolicy) -> ResilientAgent
       func withCircuitBreaker(threshold: Int, resetTimeout: Duration) -> ResilientAgent
       func withFallback(_ fallback: any Agent) -> ResilientAgent
       func withTimeout(_ timeout: Duration) -> ResilientAgent
   }
   ```

3. **Extend RetryPolicy with factory methods**
   ```swift
   extension RetryPolicy {
       static func fixed(maxAttempts: Int, delay: Duration) -> RetryPolicy
       static func exponentialBackoff(maxAttempts: Int, ...) -> RetryPolicy
   }
   ```

4. **Implement chaining support**
   - ResilientAgent should return ResilientAgent from fluent methods
   - Support arbitrary chaining order

### Files to Create/Modify
- `Sources/SwiftAgents/Resilience/ResilientAgent.swift` (new)
- `Sources/SwiftAgents/Resilience/RetryPolicy.swift` (modify)
- `Sources/SwiftAgents/Core/Agent.swift` (modify)

---

## Feature 7: MemoryBuilder DSL

**Priority:** Medium
**Tests:** `MemoryBuilderTests.swift`
**Location:** `Sources/SwiftAgents/Memory/MemoryBuilder.swift`

### Implementation Steps

1. **Create MemoryBuilder result builder**
   ```swift
   @resultBuilder
   public struct MemoryBuilder {
       public static func buildBlock(_ components: any AgentMemory...) -> [any AgentMemory]
   }
   ```

2. **Create CompositeMemory actor**
   ```swift
   public actor CompositeMemory: AgentMemory {
       private var components: [any AgentMemory]

       public init(@MemoryBuilder _ content: () -> [any AgentMemory])
   }
   ```

3. **Add fluent configuration methods to memory types**
   ```swift
   extension ConversationMemory {
       func withSummarization(after: Int) -> ConversationMemory
       func withTokenLimit(_ limit: Int) -> ConversationMemory
       func priority(_ priority: MemoryPriority) -> ConversationMemory
   }
   ```

4. **Define retrieval and merge strategies**
   ```swift
   public enum RetrievalStrategy { case recency, relevance, hybrid }
   public enum MergeStrategy { case concatenate, interleave, deduplicate }
   ```

### Files to Create/Modify
- `Sources/SwiftAgents/Memory/MemoryBuilder.swift` (new)
- `Sources/SwiftAgents/Memory/CompositeMemory.swift` (new)
- `Sources/SwiftAgents/Memory/ConversationMemory.swift` (modify)
- `Sources/SwiftAgents/Memory/SlidingWindowMemory.swift` (modify)

---

## Feature 8: Agent Composition Operators

**Priority:** Medium
**Tests:** `AgentCompositionTests.swift`
**Location:** `Sources/SwiftAgents/Orchestration/AgentOperators.swift`

### Implementation Steps

1. **Define + operator for parallel composition**
   ```swift
   public func + (lhs: any Agent, rhs: any Agent) -> ParallelComposition
   ```

2. **Define >>> operator for sequential composition**
   ```swift
   public func >>> (lhs: any Agent, rhs: any Agent) -> SequentialComposition
   ```

3. **Define | operator for conditional routing**
   ```swift
   public func | (lhs: any Agent, rhs: any Agent) -> ConditionalRouter
   ```

4. **Create composition types**
   ```swift
   public actor ParallelComposition: Agent { ... }
   public actor SequentialComposition: Agent { ... }
   public actor ConditionalRouter: Agent { ... }
   ```

5. **Add merge strategies and error handling**
   ```swift
   public enum ParallelMergeStrategy { ... }
   public enum ErrorHandlingStrategy { ... }
   ```

### Files to Create/Modify
- `Sources/SwiftAgents/Orchestration/AgentOperators.swift` (new)
- `Sources/SwiftAgents/Orchestration/ParallelComposition.swift` (new)
- `Sources/SwiftAgents/Orchestration/SequentialComposition.swift` (new)
- `Sources/SwiftAgents/Orchestration/ConditionalRouter.swift` (new)

---

## Feature 9: InferenceOptions Builder

**Priority:** Low
**Tests:** `InferenceOptionsBuilderTests.swift`
**Location:** `Sources/SwiftAgents/Core/Agent.swift`

### Implementation Steps

1. **Add fluent setter methods to InferenceOptions**
   ```swift
   extension InferenceOptions {
       func temperature(_ value: Double) -> InferenceOptions
       func maxTokens(_ value: Int) -> InferenceOptions
       func stopSequences(_ sequences: String...) -> InferenceOptions
       func topP(_ value: Double) -> InferenceOptions
       func topK(_ value: Int) -> InferenceOptions
   }
   ```

2. **Add extended properties to InferenceOptions**
   ```swift
   public struct InferenceOptions {
       // Existing
       public var temperature: Double
       public var maxTokens: Int?
       public var stopSequences: [String]

       // New
       public var topP: Double?
       public var topK: Int?
       public var presencePenalty: Double?
       public var frequencyPenalty: Double?
   }
   ```

3. **Create preset configurations**
   ```swift
   extension InferenceOptions {
       static var creative: InferenceOptions
       static var precise: InferenceOptions
       static var balanced: InferenceOptions
       static var codeGeneration: InferenceOptions
   }
   ```

4. **Add InferenceOptionsBuilder class for complex builds**
   ```swift
   public class InferenceOptionsBuilder {
       func setTemperature(_ value: Double) -> Self
       func build() -> InferenceOptions
   }
   ```

### Files to Create/Modify
- `Sources/SwiftAgents/Core/Agent.swift` (modify)

---

## Feature 10: Stream Operations DSL

**Priority:** Low
**Tests:** `StreamOperationsTests.swift`
**Location:** `Sources/SwiftAgents/Extensions/StreamOperations.swift`

### Implementation Steps

1. **Add filter operations**
   ```swift
   extension AsyncThrowingStream where Element == AgentEvent {
       func filter(_ predicate: @escaping (AgentEvent) -> Bool) -> AsyncThrowingStream
       func filterThinking() -> AsyncThrowingStream
   }
   ```

2. **Add map operations**
   ```swift
   extension AsyncThrowingStream where Element == AgentEvent {
       func map<T>(_ transform: @escaping (AgentEvent) -> T) -> AsyncThrowingStream<T, Error>
       var thoughts: AsyncThrowingStream<String, Error>
       var toolCalls: AsyncThrowingStream<ToolCallInfo, Error>
   }
   ```

3. **Add collection operations**
   ```swift
   extension AsyncThrowingStream where Element == AgentEvent {
       func collect() async throws -> [AgentEvent]
       func collect(maxCount: Int) async throws -> [AgentEvent]
       func first(where: (AgentEvent) -> Bool) async throws -> AgentEvent?
       func last() async throws -> AgentEvent?
   }
   ```

4. **Add flow control operations**
   ```swift
   extension AsyncThrowingStream where Element == AgentEvent {
       func take(_ count: Int) -> AsyncThrowingStream
       func drop(_ count: Int) -> AsyncThrowingStream
       func timeout(after: Duration) -> AsyncThrowingStream
   }
   ```

5. **Add side effect operations**
   ```swift
   extension AsyncThrowingStream where Element == AgentEvent {
       func onEach(_ action: @escaping (AgentEvent) -> Void) -> AsyncThrowingStream
       func onComplete(_ action: @escaping (AgentResult) -> Void) -> AsyncThrowingStream
   }
   ```

### Files to Create/Modify
- `Sources/SwiftAgents/Extensions/StreamOperations.swift` (new)

---

## Implementation Schedule

### Week 1: Foundation
- [ ] Feature 1: TypedTool Protocol
- [ ] Feature 2: ToolParameterBuilder DSL

### Week 2: Builders
- [ ] Feature 3: AgentBuilder DSL
- [ ] Feature 9: InferenceOptions Builder

### Week 3: Context & Memory
- [ ] Feature 5: Typed ContextKey
- [ ] Feature 7: MemoryBuilder DSL

### Week 4: Composition
- [ ] Feature 4: Typed Pipeline Operators
- [ ] Feature 8: Agent Composition Operators

### Week 5: Resilience & Streams
- [ ] Feature 6: Fluent Resilience Integration
- [ ] Feature 10: Stream Operations DSL

---

## Testing Strategy

1. **Run tests before implementation (TDD)**
   - Tests should initially fail
   - Implement until tests pass

2. **Run full test suite after each feature**
   ```bash
   swift test --filter DSL
   ```

3. **Run integration tests**
   ```bash
   swift test
   ```

4. **Verify backward compatibility**
   - Existing tests must continue passing
   - No breaking changes to public API

---

## Documentation Requirements

For each feature:
1. Update API documentation with examples
2. Add DocC comments to all public types
3. Update README.md with new capabilities
4. Add migration guide for any changes

---

## Verification Checklist

Before merging each feature:

- [ ] All new tests pass
- [ ] All existing tests pass
- [ ] No compiler warnings
- [ ] SwiftFormat applied
- [ ] Public types are `Sendable`
- [ ] DocC comments on public APIs
- [ ] No breaking changes to existing API
