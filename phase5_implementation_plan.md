# Phase 5 Implementation Plan: Polish Features

## Overview

This phase implements polish features that enhance the developer and user experience of SwiftAgents. These features focus on performance optimization (parallel tool execution) and conversation state management (response ID tracking).

## Goals

1. **Parallel Tool Calls**: Enable concurrent execution of multiple tool calls for improved performance
2. **Response ID Tracking**: Implement conversation continuation with previous response IDs
3. **Auto-populate Response IDs**: Automatically track and populate response IDs for seamless conversations
4. **Performance Optimization**: Reduce latency when agents make multiple tool calls

## Prerequisites

- Phase 1 (Guardrails) completed and tested
- Phase 2 (Streaming Events & RunHooks) completed and tested
- Phase 3 (Session & TraceContext) completed and tested
- Phase 4 (Enhanced Handoffs & MultiProvider) completed and tested
- Existing tool execution system is stable

## OpenAI SDK Reference

```python
# OpenAI's parallel tool execution
class Agent:
    parallel_tool_calls: bool = False  # Enable parallel execution
    
# OpenAI's response ID tracking
class Agent:
    previous_response_id: str | None = None
    auto_previous_response_id: bool = False

# In practice:
agent = Agent(
    name="DataAnalyst",
    parallel_tool_calls=True,  # Execute tools concurrently
    auto_previous_response_id=True  # Auto-track conversation
)
```

## Implementation Steps

### Step 1: Extend AgentConfiguration (Estimated: 1-2 hours)

#### Files to Modify
1. **`Sources/SwiftAgents/Core/AgentConfiguration.swift`**
   - Add `parallelToolCalls` property
   - Add `previousResponseId` property
   - Add `autoPreviousResponseId` property
   - Add documentation explaining each feature

#### Implementation Details

```swift
public struct AgentConfiguration: Sendable {
    // ... existing properties ...
    
    /// Whether to execute multiple tool calls in parallel
    /// 
    /// When enabled, if the agent requests multiple tool calls in a single turn,
    /// they will be executed concurrently using structured concurrency.
    /// This can significantly improve performance but may increase resource usage.
    ///
    /// Default: `false`
    public var parallelToolCalls: Bool
    
    /// Previous response ID for conversation continuation
    ///
    /// Set this to continue a conversation from a specific response.
    /// This allows the agent to maintain context across sessions.
    ///
    /// - Note: This is typically set automatically when `autoPreviousResponseId` is enabled
    public var previousResponseId: String?
    
    /// Whether to automatically populate previous response ID
    ///
    /// When enabled, the agent will automatically track response IDs
    /// and use them for conversation continuation.
    ///
    /// Default: `false`
    public var autoPreviousResponseId: Bool
    
    public init(
        // ... existing parameters ...
        parallelToolCalls: Bool = false,
        previousResponseId: String? = nil,
        autoPreviousResponseId: Bool = false
    ) {
        // ... existing assignments ...
        self.parallelToolCalls = parallelToolCalls
        self.previousResponseId = previousResponseId
        self.autoPreviousResponseId = autoPreviousResponseId
    }
}
```

#### Validation Criteria
- [ ] Properties compile without errors
- [ ] Default values are appropriate
- [ ] Documentation is comprehensive
- [ ] Backward compatibility maintained

---

### Step 2: Implement AgentResponse Model (Estimated: 1 hour)

#### Files to Create
1. **`Sources/SwiftAgents/Core/AgentResponse.swift`**
   - Define response structure with ID
   - Add metadata support
   - Ensure Sendable conformance

#### Implementation Details

```swift
import Foundation

/// Response from an agent execution with metadata
public struct AgentResponse: Sendable {
    /// Unique identifier for this response
    public let responseId: String
    
    /// The agent's output text
    public let output: String
    
    /// Agent that produced this response
    public let agentName: String
    
    /// Timestamp when the response was created
    public let timestamp: Date
    
    /// Additional metadata about the response
    public let metadata: [String: SendableValue]
    
    /// Tool calls made during this response (if any)
    public let toolCalls: [ToolCallRecord]
    
    /// Token usage information (if available)
    public let usage: TokenUsage?
    
    public init(
        responseId: String = UUID().uuidString,
        output: String,
        agentName: String,
        timestamp: Date = Date(),
        metadata: [String: SendableValue] = [:],
        toolCalls: [ToolCallRecord] = [],
        usage: TokenUsage? = nil
    ) {
        self.responseId = responseId
        self.output = output
        self.agentName = agentName
        self.timestamp = timestamp
        self.metadata = metadata
        self.toolCalls = toolCalls
        self.usage = usage
    }
    
    /// Convert to legacy AgentResult
    public var asResult: AgentResult {
        AgentResult(
            output: output,
            metadata: metadata
        )
    }
}

/// Record of a tool call execution
public struct ToolCallRecord: Sendable {
    public let toolName: String
    public let arguments: [String: SendableValue]
    public let result: SendableValue
    public let duration: TimeInterval
    public let timestamp: Date
    
    public init(
        toolName: String,
        arguments: [String: SendableValue],
        result: SendableValue,
        duration: TimeInterval,
        timestamp: Date = Date()
    ) {
        self.toolName = toolName
        self.arguments = arguments
        self.result = result
        self.duration = duration
        self.timestamp = timestamp
    }
}
```

#### Validation Criteria
- [ ] AgentResponse struct is Sendable
- [ ] All properties are immutable
- [ ] Conversion to AgentResult works
- [ ] Documentation is clear

---

### Step 3: Implement Parallel Tool Execution (Estimated: 3-4 hours)

#### Files to Create
1. **`Sources/SwiftAgents/Tools/ParallelToolExecutor.swift`**
   - Implement parallel execution logic
   - Handle errors properly
   - Track execution metrics

#### Files to Modify
2. **`Sources/SwiftAgents/Tools/Tool.swift`** (ToolRegistry)
   - Add parallel execution method
   - Update existing execute to support parallel mode

#### Implementation Details

**ParallelToolExecutor.swift:**

```swift
import Foundation

/// Executes multiple tool calls in parallel
public actor ParallelToolExecutor {
    
    /// Execute multiple tool calls concurrently
    /// - Parameters:
    ///   - calls: Array of tool calls to execute
    ///   - registry: Tool registry to use for execution
    ///   - agent: The agent making the calls
    ///   - context: The execution context
    /// - Returns: Array of results in the same order as input calls
    public func executeInParallel(
        _ calls: [ToolCall],
        using registry: ToolRegistry,
        agent: any Agent,
        context: AgentContext
    ) async throws -> [ToolExecutionResult] {
        
        // Validate all tools exist before execution
        for call in calls {
            guard await registry.hasTool(named: call.name) else {
                throw ToolError.toolNotFound(name: call.name)
            }
        }
        
        // Execute all tools concurrently
        return try await withThrowingTaskGroup(of: (Int, ToolExecutionResult).self) { group in
            for (index, call) in calls.enumerated() {
                group.addTask {
                    let startTime = Date()
                    
                    do {
                        let result = try await registry.execute(
                            toolNamed: call.name,
                            arguments: call.arguments,
                            agent: agent,
                            context: context
                        )
                        
                        let duration = Date().timeIntervalSince(startTime)
                        
                        return (index, ToolExecutionResult(
                            toolName: call.name,
                            arguments: call.arguments,
                            result: .success(result),
                            duration: duration
                        ))
                    } catch {
                        let duration = Date().timeIntervalSince(startTime)
                        
                        return (index, ToolExecutionResult(
                            toolName: call.name,
                            arguments: call.arguments,
                            result: .failure(error),
                            duration: duration
                        ))
                    }
                }
            }
            
            // Collect results maintaining original order
            var results: [(Int, ToolExecutionResult)] = []
            for try await result in group {
                results.append(result)
            }
            
            // Sort by index to maintain call order
            results.sort { $0.0 < $1.0 }
            return results.map { $0.1 }
        }
    }
    
    /// Execute with error strategy
    public func executeInParallel(
        _ calls: [ToolCall],
        using registry: ToolRegistry,
        agent: any Agent,
        context: AgentContext,
        errorStrategy: ParallelExecutionErrorStrategy
    ) async throws -> [ToolExecutionResult] {
        
        let results = try await executeInParallel(
            calls,
            using: registry,
            agent: agent,
            context: context
        )
        
        // Handle errors based on strategy
        switch errorStrategy {
        case .failFast:
            // Throw on first error
            if let firstError = results.first(where: { 
                if case .failure = $0.result { return true }
                return false
            }) {
                if case .failure(let error) = firstError.result {
                    throw error
                }
            }
            
        case .collectErrors:
            // Collect all errors
            let errors = results.compactMap { result -> Error? in
                if case .failure(let error) = result.result {
                    return error
                }
                return nil
            }
            
            if !errors.isEmpty {
                throw ToolError.multipleToolsFailed(errors: errors)
            }
            
        case .continueOnError:
            // Return results with failures included
            break
        }
        
        return results
    }
}

// MARK: - Supporting Types

/// Represents a tool call to be executed
public struct ToolCall: Sendable {
    public let name: String
    public let arguments: [String: SendableValue]
    public let callId: String
    
    public init(
        name: String,
        arguments: [String: SendableValue],
        callId: String = UUID().uuidString
    ) {
        self.name = name
        self.arguments = arguments
        self.callId = callId
    }
}

/// Result of a tool execution
public struct ToolExecutionResult: Sendable {
    public let toolName: String
    public let arguments: [String: SendableValue]
    public let result: Result<SendableValue, Error>
    public let duration: TimeInterval
    public let timestamp: Date
    
    public init(
        toolName: String,
        arguments: [String: SendableValue],
        result: Result<SendableValue, Error>,
        duration: TimeInterval,
        timestamp: Date = Date()
    ) {
        self.toolName = toolName
        self.arguments = arguments
        self.result = result
        self.duration = duration
        self.timestamp = timestamp
    }
    
    /// Whether the execution was successful
    public var isSuccess: Bool {
        if case .success = result { return true }
        return false
    }
    
    /// Get the successful value if available
    public var value: SendableValue? {
        if case .success(let value) = result {
            return value
        }
        return nil
    }
    
    /// Get the error if execution failed
    public var error: Error? {
        if case .failure(let error) = result {
            return error
        }
        return nil
    }
}

/// Strategy for handling errors in parallel execution
public enum ParallelExecutionErrorStrategy: Sendable {
    /// Throw immediately on first error
    case failFast
    
    /// Collect all errors and throw composite error
    case collectErrors
    
    /// Continue execution, include failures in results
    case continueOnError
}

// MARK: - Error Extensions

public extension ToolError {
    static func multipleToolsFailed(errors: [Error]) -> ToolError {
        .executionFailed(
            name: "multiple_tools",
            reason: "Multiple tools failed: \(errors.map { $0.localizedDescription }.joined(separator: ", "))"
        )
    }
}
```

#### Validation Criteria
- [ ] Parallel execution works correctly
- [ ] Results maintain order
- [ ] Errors are handled properly
- [ ] Performance improvement is measurable
- [ ] Thread safety is maintained

---

### Step 4: Implement Response ID Tracking (Estimated: 2-3 hours)

#### Files to Create
1. **`Sources/SwiftAgents/Core/ResponseTracker.swift`**
   - Track response IDs per session
   - Auto-populate functionality
   - Thread-safe storage

#### Implementation Details

```swift
import Foundation

/// Tracks agent responses for conversation continuation
public actor ResponseTracker {
    
    /// Storage for response history by session
    private var responseHistory: [String: [AgentResponse]] = [:]
    
    /// Maximum responses to track per session
    private let maxHistorySize: Int
    
    public init(maxHistorySize: Int = 100) {
        self.maxHistorySize = maxHistorySize
    }
    
    /// Record a new response
    public func recordResponse(_ response: AgentResponse, sessionId: String) {
        var history = responseHistory[sessionId] ?? []
        history.append(response)
        
        // Trim history if needed
        if history.count > maxHistorySize {
            history = Array(history.suffix(maxHistorySize))
        }
        
        responseHistory[sessionId] = history
    }
    
    /// Get the most recent response ID for a session
    public func getLatestResponseId(for sessionId: String) -> String? {
        responseHistory[sessionId]?.last?.responseId
    }
    
    /// Get a specific response by ID
    public func getResponse(
        responseId: String,
        sessionId: String
    ) -> AgentResponse? {
        responseHistory[sessionId]?.first { $0.responseId == responseId }
    }
    
    /// Get response history for a session
    public func getHistory(
        for sessionId: String,
        limit: Int? = nil
    ) -> [AgentResponse] {
        guard let history = responseHistory[sessionId] else { return [] }
        
        if let limit = limit {
            return Array(history.suffix(limit))
        }
        return history
    }
    
    /// Clear history for a session
    public func clearHistory(for sessionId: String) {
        responseHistory.removeValue(forKey: sessionId)
    }
    
    /// Clear all history
    public func clearAllHistory() {
        responseHistory.removeAll()
    }
}

// MARK: - Context Extensions

public extension AgentContext {
    
    /// Session ID for response tracking
    var sessionId: String {
        get {
            (metadata["session_id"] as? String) ?? "default"
        }
        set {
            metadata["session_id"] = newValue
        }
    }
    
    /// Get or create response tracker
    func getResponseTracker() -> ResponseTracker {
        if let tracker = metadata["response_tracker"] as? ResponseTracker {
            return tracker
        }
        
        let tracker = ResponseTracker()
        metadata["response_tracker"] = tracker
        return tracker
    }
}
```

#### Validation Criteria
- [ ] Response tracking works correctly
- [ ] History is limited properly
- [ ] Thread-safe under concurrent access
- [ ] Memory usage is bounded

---

### Step 5: Integrate Features with Agent (Estimated: 2-3 hours)

#### Files to Modify
1. **`Sources/SwiftAgents/Agents/ReActAgent.swift`** (and other agent implementations)
   - Add parallel tool execution support
   - Add response ID tracking
   - Update run method signature

2. **`Sources/SwiftAgents/Core/Agent.swift`**
   - Add runWithResponse method
   - Update protocol if needed

#### Implementation Details

**Update Agent Protocol:**

```swift
public protocol Agent: Sendable {
    // ... existing methods ...
    
    /// Run the agent and return detailed response with ID
    func runWithResponse(
        _ input: String,
        context: AgentContext?,
        hooks: (any RunHooks)?
    ) async throws -> AgentResponse
}

// Default implementation using existing run
public extension Agent {
    func runWithResponse(
        _ input: String,
        context: AgentContext? = nil,
        hooks: (any RunHooks)? = nil
    ) async throws -> AgentResponse {
        let result = try await run(input, context: context, hooks: hooks)
        
        return AgentResponse(
            output: result.output,
            agentName: configuration.name ?? "Unknown",
            metadata: result.metadata
        )
    }
}
```

**Update ReActAgent:**

```swift
// In ReActAgent.run() method:

private func executeToolCalls(
    _ toolCalls: [ToolCall],
    context: AgentContext
) async throws -> [ToolExecutionResult] {
    
    if configuration.parallelToolCalls {
        // Execute in parallel
        let executor = ParallelToolExecutor()
        return try await executor.executeInParallel(
            toolCalls,
            using: toolRegistry,
            agent: self,
            context: context,
            errorStrategy: .continueOnError
        )
    } else {
        // Execute sequentially (existing behavior)
        var results: [ToolExecutionResult] = []
        
        for call in toolCalls {
            let startTime = Date()
            
            do {
                let result = try await toolRegistry.execute(
                    toolNamed: call.name,
                    arguments: call.arguments,
                    agent: self,
                    context: context
                )
                
                results.append(ToolExecutionResult(
                    toolName: call.name,
                    arguments: call.arguments,
                    result: .success(result),
                    duration: Date().timeIntervalSince(startTime)
                ))
            } catch {
                results.append(ToolExecutionResult(
                    toolName: call.name,
                    arguments: call.arguments,
                    result: .failure(error),
                    duration: Date().timeIntervalSince(startTime)
                ))
                throw error
            }
        }
        
        return results
    }
}

public func runWithResponse(
    _ input: String,
    context: AgentContext? = nil,
    hooks: (any RunHooks)? = nil
) async throws -> AgentResponse {
    let ctx = context ?? AgentContext()
    
    // Handle auto previous response ID
    if configuration.autoPreviousResponseId {
        let tracker = ctx.getResponseTracker()
        if let latestResponseId = await tracker.getLatestResponseId(for: ctx.sessionId) {
            // Use latest response ID for context
            ctx.metadata["previous_response_id"] = latestResponseId
        }
    } else if let previousId = configuration.previousResponseId {
        ctx.metadata["previous_response_id"] = previousId
    }
    
    // Execute agent
    let result = try await run(input, context: ctx, hooks: hooks)
    
    // Create response
    let response = AgentResponse(
        output: result.output,
        agentName: configuration.name ?? "Unknown",
        metadata: result.metadata,
        toolCalls: ctx.toolCallRecords
    )
    
    // Track response if auto-tracking enabled
    if configuration.autoPreviousResponseId {
        let tracker = ctx.getResponseTracker()
        await tracker.recordResponse(response, sessionId: ctx.sessionId)
    }
    
    return response
}
```

#### Validation Criteria
- [ ] Parallel execution integrates correctly
- [ ] Response tracking works end-to-end
- [ ] Auto-population functions properly
- [ ] Backward compatibility maintained

---

### Step 6: Update AgentBuilder (Estimated: 1 hour)

#### Files to Modify
1. **`Sources/SwiftAgents/Agents/AgentBuilder.swift`**
   - Add fluent methods for new configuration options

#### Implementation Details

```swift
public struct AgentBuilder {
    // ... existing properties ...
    private var parallelToolCalls: Bool = false
    private var previousResponseId: String?
    private var autoPreviousResponseId: Bool = false
    
    /// Enable parallel tool call execution
    public func parallelToolCalls(_ enabled: Bool = true) -> AgentBuilder {
        var copy = self
        copy.parallelToolCalls = enabled
        return copy
    }
    
    /// Set previous response ID for conversation continuation
    public func previousResponseId(_ id: String?) -> AgentBuilder {
        var copy = self
        copy.previousResponseId = id
        return copy
    }
    
    /// Enable automatic previous response ID tracking
    public func autoPreviousResponseId(_ enabled: Bool = true) -> AgentBuilder {
        var copy = self
        copy.autoPreviousResponseId = enabled
        return copy
    }
    
    public func build() -> some Agent {
        let config = AgentConfiguration(
            // ... existing parameters ...
            parallelToolCalls: parallelToolCalls,
            previousResponseId: previousResponseId,
            autoPreviousResponseId: autoPreviousResponseId
        )
        
        // ... rest of build logic ...
    }
}
```

#### Validation Criteria
- [ ] Builder methods work with fluent API
- [ ] Options are passed to configuration correctly
- [ ] Documentation is clear

---

### Step 7: Add Performance Metrics (Estimated: 1-2 hours)

#### Files to Create
1. **`Sources/SwiftAgents/Observability/PerformanceMetrics.swift`**
   - Track parallel execution metrics
   - Measure speedup
   - Export metrics

#### Implementation Details

```swift
import Foundation

/// Performance metrics for agent execution
public struct PerformanceMetrics: Sendable {
    /// Total execution time
    public let totalDuration: TimeInterval
    
    /// Time spent in LLM calls
    public let llmDuration: TimeInterval
    
    /// Time spent in tool execution
    public let toolDuration: TimeInterval
    
    /// Number of tools executed
    public let toolCount: Int
    
    /// Whether tools were executed in parallel
    public let usedParallelExecution: Bool
    
    /// Estimated sequential duration (if parallel was used)
    public let estimatedSequentialDuration: TimeInterval?
    
    /// Speedup factor from parallel execution
    public var parallelSpeedup: Double? {
        guard let sequential = estimatedSequentialDuration,
              usedParallelExecution,
              toolDuration > 0 else {
            return nil
        }
        return sequential / toolDuration
    }
    
    public init(
        totalDuration: TimeInterval,
        llmDuration: TimeInterval,
        toolDuration: TimeInterval,
        toolCount: Int,
        usedParallelExecution: Bool,
        estimatedSequentialDuration: TimeInterval? = nil
    ) {
        self.totalDuration = totalDuration
        self.llmDuration = llmDuration
        self.toolDuration = toolDuration
        self.toolCount = toolCount
        self.usedParallelExecution = usedParallelExecution
        self.estimatedSequentialDuration = estimatedSequentialDuration
    }
}

/// Tracks performance metrics during execution
public actor PerformanceTracker {
    private var startTime: Date?
    private var llmTime: TimeInterval = 0
    private var toolTime: TimeInterval = 0
    private var toolCount: Int = 0
    private var usedParallel: Bool = false
    private var sequentialEstimate: TimeInterval = 0
    
    public init() {}
    
    public func start() {
        startTime = Date()
    }
    
    public func recordLLMCall(duration: TimeInterval) {
        llmTime += duration
    }
    
    public func recordToolExecution(
        duration: TimeInterval,
        wasParallel: Bool
    ) {
        toolTime += duration
        toolCount += 1
        usedParallel = usedParallel || wasParallel
    }
    
    public func recordSequentialEstimate(_ duration: TimeInterval) {
        sequentialEstimate = duration
    }
    
    public func finish() -> PerformanceMetrics {
        let total = startTime.map { Date().timeIntervalSince($0) } ?? 0
        
        return PerformanceMetrics(
            totalDuration: total,
            llmDuration: llmTime,
            toolDuration: toolTime,
            toolCount: toolCount,
            usedParallelExecution: usedParallel,
            estimatedSequentialDuration: usedParallel ? sequentialEstimate : nil
        )
    }
}
```

#### Validation Criteria
- [ ] Metrics are collected accurately
- [ ] Speedup calculation is correct
- [ ] No performance overhead from tracking

---

### Step 8: Testing (Estimated: 3-4 hours)

#### Test Files to Create
1. **`Tests/SwiftAgentsTests/Tools/ParallelToolExecutorTests.swift`**
2. **`Tests/SwiftAgentsTests/Core/ResponseTrackerTests.swift`**
3. **`Tests/SwiftAgentsTests/Integration/ParallelExecutionIntegrationTests.swift`**
4. **`Tests/SwiftAgentsTests/Integration/ResponseTrackingIntegrationTests.swift`**

#### Test Coverage Requirements

**ParallelToolExecutor Tests:**
- [ ] Basic parallel execution
- [ ] Result ordering preservation
- [ ] Error handling (fail fast)
- [ ] Error handling (collect errors)
- [ ] Error handling (continue on error)
- [ ] Performance improvement measurement
- [ ] Concurrent access safety

**ResponseTracker Tests:**
- [ ] Record and retrieve responses
- [ ] History limiting
- [ ] Session isolation
- [ ] Auto-population
- [ ] Memory bounds
- [ ] Clear operations

**Integration Tests:**
- [ ] Agent with parallel tools enabled
- [ ] Agent with response tracking
- [ ] End-to-end conversation continuation
- [ ] Performance comparison (parallel vs sequential)
- [ ] Error scenarios

#### Example Test

```swift
import XCTest
@testable import SwiftAgents

final class ParallelToolExecutorTests: XCTestCase {
    
    func testParallelExecutionMaintainsOrder() async throws {
        let registry = ToolRegistry()
        
        // Register mock tools with delays
        await registry.register(MockTool(
            name: "slow_tool",
            execution: { _ in
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                return .string("slow")
            }
        ))
        
        await registry.register(MockTool(
            name: "fast_tool",
            execution: { _ in
                return .string("fast")
            }
        ))
        
        let calls = [
            ToolCall(name: "slow_tool", arguments: [:]),
            ToolCall(name: "fast_tool", arguments: [:]),
            ToolCall(name: "slow_tool", arguments: [:])
        ]
        
        let executor = ParallelToolExecutor()
        let agent = MockAgent()
        let context = AgentContext()
        
        let startTime = Date()
        let results = try await executor.executeInParallel(
            calls,
            using: registry,
            agent: agent,
            context: context
        )
        let duration = Date().timeIntervalSince(startTime)
        
        // Results should maintain order
        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results[0].toolName, "slow_tool")
        XCTAssertEqual(results[1].toolName, "fast_tool")
        XCTAssertEqual(results[2].toolName, "slow_tool")
        
        // Parallel execution should be faster than sequential
        // Sequential would be ~200ms, parallel should be ~100ms
        XCTAssertLessThan(duration, 0.15) // Allow some overhead
    }
    
    func testParallelExecutionHandlesErrorsWithStrategy() async throws {
        let registry = ToolRegistry()
        
        await registry.register(MockTool(
            name: "success_tool",
            execution: { _ in .string("success") }
        ))
        
        await registry.register(MockTool(
            name: "error_tool",
            execution: { _ in
                throw ToolError.executionFailed(
                    name: "error_tool",
                    reason: "Intentional error"
                )
            }
        ))
        
        let calls = [
            ToolCall(name: "success_tool", arguments: [:]),
            ToolCall(name: "error_tool", arguments: [:]),
            ToolCall(name: "success_tool", arguments: [:])
        ]
        
        let executor = ParallelToolExecutor()
        let agent = MockAgent()
        let context = AgentContext()
        
        // Test continueOnError strategy
        let results = try await executor.executeInParallel(
            calls,
            using: registry,
            agent: agent,
            context: context,
            errorStrategy: .continueOnError
        )
        
        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results[0].isSuccess)
        XCTAssertFalse(results[1].isSuccess)
        XCTAssertTrue(results[2].isSuccess)
        
        // Test failFast strategy
        do {
            _ = try await executor.executeInParallel(
                calls,
                using: registry,
                agent: agent,
                context: context,
                errorStrategy: .failFast
            )
            XCTFail("Should have thrown")
        } catch {
            // Expected
        }
    }
}
```

---

### Step 9: Documentation (Estimated: 2 hours)

#### Documentation to Create/Update

1. **`Docs/ParallelExecution.md`**
   - Parallel tool execution guide
   - Performance considerations
   - Error handling strategies
   - Best practices

2. **`Docs/ConversationContinuation.md`**
   - Response ID tracking guide
   - Auto-population usage
   - Session management
   - Examples

3. **README.md Updates**
   - Add Phase 5 to features
   - Include performance benefits
   - Add usage examples

4. **Code Documentation**
   - DocC comments on all public APIs
   - Performance characteristics
   - Thread safety guarantees

#### Example Documentation

**Parallel Execution:**

```swift
/// Execute multiple tools concurrently for improved performance
///
/// When enabled, the agent will execute multiple tool calls in parallel
/// using Swift's structured concurrency. This can significantly reduce
/// execution time when multiple independent tools need to be called.
///
/// ## Performance Impact
///
/// With 3 tools taking 100ms each:
/// - Sequential: ~300ms total
/// - Parallel: ~100ms total (3x speedup)
///
/// ## Example Usage
///
/// ```swift
/// let agent = AgentBuilder()
///     .name("DataAnalyst")
///     .parallelToolCalls(true)  // Enable parallel execution
///     .tools([weatherTool, stockTool, newsTool])
///     .build()
/// ```
///
/// - Important: Tools must be independent (no shared mutable state)
/// - Note: Increases resource usage during execution
/// - SeeAlso: `ParallelToolExecutor`, `ParallelExecutionErrorStrategy`
```

**Response Tracking:**

```swift
/// Automatically track and continue conversations
///
/// When enabled, the agent will automatically maintain conversation
/// context across multiple interactions by tracking response IDs.
///
/// ## Example Usage
///
/// ```swift
/// let agent = AgentBuilder()
///     .name("Assistant")
///     .autoPreviousResponseId(true)
///     .build()
///
/// let context = AgentContext()
/// context.sessionId = "user_123"
///
/// // First interaction
/// let response1 = try await agent.runWithResponse(
///     "What's the weather?",
///     context: context
/// )
///
/// // Second interaction - automatically continues from previous
/// let response2 = try await agent.runWithResponse(
///     "What about tomorrow?",
///     context: context
/// )
/// ```
///
/// - Note: Response history is bounded (default: 100 responses)
/// - SeeAlso: `ResponseTracker`, `AgentResponse`
```

---

### Step 10: Example Applications (Estimated: 2 hours)

#### Examples to Create

1. **`Examples/ParallelExecutionExample/`**
   - Data aggregation agent using parallel tools
   - Performance comparison demo
   - Error handling showcase

2. **`Examples/ConversationContinuationExample/`**
   - Multi-turn conversation with context
   - Session management demo
   - Response history exploration

#### Example Code

```swift
// Examples/ParallelExecutionExample/DataAggregator.swift

import SwiftAgents

@main
struct DataAggregatorExample {
    static func main() async throws {
        // Create tools that fetch data from different sources
        let weatherTool = MockWeatherTool()
        let stockTool = MockStockTool()
        let newsTool = MockNewsTool()
        
        // Create agent with parallel execution
        let parallelAgent = AgentBuilder()
            .name("ParallelAggregator")
            .instructions("""
                You are a data aggregator. When asked for a morning briefing,
                use all three tools to gather weather, stock, and news information.
                """)
            .parallelToolCalls(true)  // Enable parallel execution
            .tools([weatherTool, stockTool, newsTool])
            .build()
        
        // Create agent without parallel execution for comparison
        let sequentialAgent = AgentBuilder()
            .name("SequentialAggregator")
            .instructions("""
                You are a data aggregator. When asked for a morning briefing,
                use all three tools to gather weather, stock, and news information.
                """)
            .parallelToolCalls(false)  // Sequential execution
            .tools([weatherTool, stockTool, newsTool])
            .build()
        
        // Test parallel execution
        print("🚀 Testing parallel execution...")
        let parallelStart = Date()
        let parallelResponse = try await parallelAgent.runWithResponse(
            "Give me my morning briefing"
        )
        let parallelDuration = Date().timeIntervalSince(parallelStart)
        
        // Test sequential execution
        print("🐌 Testing sequential execution...")
        let sequentialStart = Date()
        let sequentialResponse = try await sequentialAgent.runWithResponse(
            "Give me my morning briefing"
        )
        let sequentialDuration = Date().timeIntervalSince(sequentialStart)
        
        // Compare results
        print("""
            
            📊 Performance Comparison:
            ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            Parallel:    \(String(format: "%.2f", parallelDuration))s
            Sequential:  \(String(format: "%.2f", sequentialDuration))s
            Speedup:     \(String(format: "%.2f", sequentialDuration / parallelDuration))x
            ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            
            ✨ Parallel execution was \(String(format: "%.1f%%", (1 - parallelDuration / sequentialDuration) * 100)) faster!
            """)
    }
}
```

---

## Testing Checklist

### Unit Tests
- [ ] AgentConfiguration properties
- [ ] AgentResponse creation
- [ ] ParallelToolExecutor execution
- [ ] Result ordering
- [ ] Error strategies
- [ ] ResponseTracker recording
- [ ] ResponseTracker retrieval
- [ ] History limiting

### Integration Tests
- [ ] End-to-end parallel execution
- [ ] Performance improvement verification
- [ ] Response tracking workflow
- [ ] Auto-population
- [ ] Session isolation
- [ ] Error propagation

### Performance Tests
- [ ] Parallel vs sequential benchmark
- [ ] Speedup measurement
- [ ] Memory usage with tracking
- [ ] Concurrent access performance

---

## Migration Guide

### Enabling Parallel Tool Execution

**Before:**
```swift
let agent = AgentBuilder()
    .name("Agent")
    .tools([tool1, tool2, tool3])
    .build()
// Tools execute sequentially
```

**After:**
```swift
let agent = AgentBuilder()
    .name("Agent")
    .tools([tool1, tool2, tool3])
    .parallelToolCalls(true)  // Enable parallel execution
    .build()
// Tools execute concurrently when possible
```

### Enabling Response Tracking

**Before:**
```swift
let result = try await agent.run("Hello")
// No automatic conversation continuation
```

**After:**
```swift
let agent = AgentBuilder()
    .name("Agent")
    .autoPreviousResponseId(true)
    .build()

let context = AgentContext()
context.sessionId = "session_123"

let response = try await agent.runWithResponse("Hello", context: context)
// Automatic conversation tracking
```

---

## Rollout Plan

### Phase 5.1: Core Implementation (Week 1)
- Day 1: AgentConfiguration updates and AgentResponse model
- Day 2-3: Parallel tool execution implementation
- Day 4-5: Response tracking implementation

### Phase 5.2: Integration & Testing (Week 2)
- Day 1-2: Agent integration (ReActAgent, etc.)
- Day 3-4: Comprehensive testing
- Day 5: Performance benchmarking

### Phase 5.3: Polish & Release (Week 3)
- Day 1-2: Documentation and examples
- Day 3: Community testing
- Day 4-5: Bug fixes and release prep

---

## Success Criteria

### Functionality
- [ ] Parallel tool execution works correctly
- [ ] Results maintain order
- [ ] All error strategies work
- [ ] Response tracking functions properly
- [ ] Auto-population works
- [ ] Session isolation maintained

### Performance
- [ ] Parallel execution shows measurable speedup
- [ ] Overhead < 5ms for tracking
- [ ] Memory usage is bounded
- [ ] No performance regression for sequential mode

### Quality
- [ ] Test coverage > 85%
- [ ] No memory leaks
- [ ] Thread-safe under concurrent access
- [ ] Zero compiler warnings

### Documentation
- [ ] All public APIs documented
- [ ] Usage examples provided
- [ ] Performance characteristics documented
- [ ] Migration guide complete

---

## Risk Assessment

### High Risk
- **Parallel execution bugs**: Race conditions or ordering issues
  - *Mitigation*: Extensive concurrent testing, use structured concurrency

### Medium Risk
- **Performance overhead**: Tracking adds latency
  - *Mitigation*: Benchmarks, optional features, efficient implementation

### Low Risk
- **API complexity**: More configuration options
  - *Mitigation*: Good defaults, clear documentation

---

## Dependencies

### Internal
- Phase 1-4 features (for integration)
- Existing tool system
- Agent infrastructure

### External
- Swift 6.0+ (for structured concurrency)
- Foundation framework

---

## Deliverables

1. ✅ Enhanced AgentConfiguration
2. ✅ AgentResponse model
3. ✅ ParallelToolExecutor
4. ✅ ResponseTracker
5. ✅ Agent integration
6. ✅ Comprehensive tests (>85% coverage)
7. ✅ Documentation and examples
8. ✅ Performance benchmarks

---

## Timeline Summary

- **Total Estimated Time**: 14-20 hours
- **Recommended Sprint**: 2-3 weeks
- **Team Size**: 1-2 engineers
- **Review Points**: After Steps 3, 7, and 9

---

## Notes

- Maintain backward compatibility
- Use structured concurrency (no DispatchQueue)
- Make features opt-in
- Document performance characteristics
- Provide good defaults
