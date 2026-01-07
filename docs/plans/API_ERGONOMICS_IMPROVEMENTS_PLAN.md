# API Ergonomics Improvements Plan

**Status**: Proposed  
**Created**: January 07, 2026  
**Priority**: Medium  
**Branch**: `feature/api-ergonomics-improvements`

---

## Executive Summary

This document outlines ergonomic improvements to the SwiftAgents public API, focusing on enhancing type safety, improving developer experience, and aligning with Swift 6 concurrency model. The audit identified 7 key areas where modern Swift techniques (generics, result builders, DSL-style APIs) can meaningfully improve the system without over-engineering.

**Goals**:
- Improve developer experience through better type safety
- Enhance readability and expressiveness
- Increase type safety without sacrificing clarity
- Maintain backward compatibility where feasible

**Optimization Principles**:
- Clarity over cleverness
- Discoverability
- Long-term maintainability
- Avoid over-engineering or magic abstractions

---

## Recommendations Overview

| # | Recommendation | Impact | Complexity | Priority |
|---|---------------|---------|-------------|----------|
| 1 | Typed Tool Arguments | High | High | Medium |
| 2 | Preserve Handoff Generic Target Type | Medium | Low | **High** |
| 3 | Actor-based AgentResult Builder | Medium | Low | Medium |
| 4 | Parameter Type Factory Functions | Medium | Low | **High** |
| 5 | Memory Typed Message Retrieval | High | Medium | Medium |
| 6 | Route Condition Builder DSL | Low | Medium | Low |
| 7 | Type-Safe Tool Registry Methods | Medium | Low | **High** |

---

## 1. Typed Tool Arguments via Enhanced @Tool Macro

### Problem Statement

`SendableValue` is a type-erased enum used throughout for tool parameters and metadata. This loses compile-time type safety and forces runtime type checking.

**Current Usage** (`Sources/SwiftAgents/Tools/Tool.swift:25`):
```swift
func execute(arguments: [String: SendableValue]) async throws -> SendableValue
```

**Current Tool Implementation Pattern**:
```swift
struct WeatherTool: Tool {
    let name = "weather"
    let description = "Gets weather for a location"
    let parameters: [ToolParameter] = [
        ToolParameter(name: "location", description: "City name", type: .string)
    ]

    func execute(arguments: [String: SendableValue]) async throws -> SendableValue {
        guard let location = arguments["location"]?.stringValue else {
            throw AgentError.invalidToolArguments(toolName: name, reason: "Missing location")
        }
        return .string("72°F in \(location)")
    }
}
```

### Proposed Solution

Enhance the `@Tool` macro to generate both generic and type-safe versions of the `execute` method.

**Alternative Implementation**:
```swift
@Tool("Calculates mathematical expressions")
struct CalculatorTool {
    @Parameter("The expression to evaluate")
    var expression: String

    // Macro generates both:
    // 1. Generic execute() for backward compatibility
    func execute(arguments: [String: SendableValue]) async throws -> SendableValue {
        // Generated wrapper that extracts parameters
    }

    // 2. Type-safe execute() for direct use
    func execute(expression: String) async throws -> Double {
        let result = try evaluate(expression)
        return result
    }
}
```

### Implementation Plan

1. **Macro Enhancement** (`SwiftAgentsMacros/ToolMacro.swift`)
   - Modify macro to detect `@Parameter`-annotated properties
   - Generate typed `execute()` method with parameter names as arguments
   - Maintain existing generic `execute(arguments:)` for backward compatibility

2. **Update Tool Protocol** (`Sources/SwiftAgents/Tools/Tool.swift`)
   - Keep existing `execute(arguments:)` method
   - Add documentation recommending typed `execute()` implementations

3. **Examples Update**
   - Update tool examples in documentation
   - Provide both generic and typed usage examples

### Pros
- Compile-time type safety for tool implementations
- Eliminates runtime string-key lookups and type casting
- Better IDE autocomplete and refactoring support
- Reduces boilerplate parameter extraction code

### Cons
- Increases macro complexity significantly
- May not cover all dynamic use cases (e.g., tools from MCP servers)
- Breaking change for existing tool implementations (if enforcing typed version)
- Compile-time cost for macro expansion

### Justification

Improves ergonomics for the 90% use case (statically-typed tools) without sacrificing dynamic capabilities. Most tools in production iOS apps have known parameter types at compile time.

### Migration Path

1. Phase 1: Macro generates both methods (backward compatible)
2. Phase 2: New tools default to typed implementations
3. Phase 3: Document deprecation timeline for generic-only tools (optional)

---

## 2. Preserve Handoff Generic Target Type

### Problem Statement

`HandoffBuilder<Target: Agent>` creates type-safe handoffs, but `AnyHandoffConfiguration` erases the target agent type. This makes debugging harder and loses type information in collections.

**Current Usage** (`Sources/SwiftAgents/Orchestration/HandoffBuilder.swift:290`):
```swift
public struct AnyHandoffConfiguration: Sendable {
    public let targetAgent: any Agent  // Type erased
}
```

**Current Creation Pattern**:
```swift
let handoff = handoff(to: executorAgent)  // Returns AnyHandoffConfiguration
// Type information lost - targetAgent is `any Agent`
```

### Proposed Solution

Introduce `TypedHandoffConfiguration<T: Agent>` preserving type information while still allowing type-erased collections.

**Alternative Implementation**:
```swift
// Type-safe base protocol
public protocol AnyHandoffConfigurationProtocol: Sendable {
    var targetAgent: any Agent { get }
    var toolNameOverride: String? { get }
    var toolDescription: String? { get }
    var onHandoff: OnHandoffCallback? { get }
    var inputFilter: InputFilterCallback? { get }
    var isEnabled: IsEnabledCallback? { get }
    var nestHandoffHistory: Bool { get }
}

// Preserves generic type for direct use
public struct TypedHandoffConfiguration<T: Agent>: AnyHandoffConfigurationProtocol {
    public let targetAgent: T
    public let toolNameOverride: String?
    public let toolDescription: String?
    public let onHandoff: OnHandoffCallback?
    public let inputFilter: InputFilterCallback?
    public let isEnabled: IsEnabledCallback?
    public let nestHandoffHistory: Bool

    // Type-safe access
    public var typedTarget: T { targetAgent }
}

// Type-erased wrapper for collections (existing implementation)
public struct AnyHandoffConfiguration: AnyHandoffConfigurationProtocol {
    public let targetAgent: any Agent
    // ... existing fields preserved
}

// Updated handoff() function to return typed version
public func handoff<T: Agent>(
    to target: T,
    toolName: String? = nil,
    toolDescription: String? = nil,
    onHandoff: OnHandoffCallback? = nil,
    inputFilter: InputFilterCallback? = nil,
    isEnabled: IsEnabledCallback? = nil,
    nestHistory: Bool = false
) -> TypedHandoffConfiguration<T> {
    TypedHandoffConfiguration(
        targetAgent: target,
        toolNameOverride: toolName,
        toolDescription: toolDescription,
        onHandoff: onHandoff,
        inputFilter: inputFilter,
        isEnabled: isEnabled,
        nestHandoffHistory: nestHistory
    )
}

// Convenience function for type-erased collections
public func anyHandoff<T: Agent>(
    to target: T,
    toolName: String? = nil,
    // ...
) -> AnyHandoffConfiguration {
    AnyHandoffConfiguration(
        targetAgent: target,
        // ...
    )
}
```

**Usage Examples**:
```swift
// Type-safe usage
let typedHandoff = handoff(to: executorAgent)  // TypedHandoffConfiguration<ExecutorAgent>
let agent = typedHandoff.typedTarget  // ExecutorAgent type known at compile time

// Collection usage (type-erased)
let handoffs: [AnyHandoffConfiguration] = [
    anyHandoff(to: plannerAgent),
    anyHandoff(to: executorAgent)
]
```

### Implementation Plan

1. **Create Protocol** (`Sources/SwiftAgents/Orchestration/HandoffBuilder.swift`)
   - Add `AnyHandoffConfigurationProtocol` with shared properties

2. **Add Typed Configuration**
   - Create `TypedHandoffConfiguration<T: Agent>` struct
   - Implement `AnyHandoffConfigurationProtocol`

3. **Update Existing Types**
   - Make `AnyHandoffConfiguration` conform to `AnyHandoffConfigurationProtocol`
   - Keep all existing implementation unchanged

4. **Update handoff() Function**
   - Change return type to `TypedHandoffConfiguration<T>`
   - Add `anyHandoff()` convenience function for collections

5. **Update Agent Protocol**
   - Change `handoffs` property to use `AnyHandoffConfigurationProtocol`
   - Ensure backward compatibility

6. **Update Tests**
   - Add tests for typed handoffs
   - Ensure existing tests still pass

### Pros
- Preserves type information for direct handoff usage
- No breaking change: `AnyHandoffConfiguration` still available for heterogeneous collections
- Better autocomplete and compile-time safety when working with known target agents
- Improved error messages (compile-time vs runtime)

### Cons
- Slight API surface increase (two handoff configuration types)
- Potential confusion about when to use typed vs type-erased
- Requires documentation explaining distinction

### Justification

Most handoffs are between known agent types at compile time. Preserving this type information provides better ergonomics and safety while maintaining flexibility for heterogeneous collections.

### Migration Path

**Fully Backward Compatible**:
1. `AnyHandoffConfiguration` unchanged
2. Existing code continues to work
3. New code can use typed version for better type safety
4. Documentation recommends typed version when target type is known

---

## 3. Actor-Based AgentResult Builder

### Problem Statement

`AgentResult.Builder` uses a class with `@unchecked Sendable` and manual `NSLock` for thread safety. This is an imperative pattern in a codebase that favors value semantics.

**Current Usage** (`Sources/SwiftAgents/Core/AgentResult.swift:117`):
```swift
final class Builder: @unchecked Sendable {
    private var output: String = ""
    private var toolCalls: [ToolCall] = []
    private let lock = NSLock()

    @discardableResult
    public func setOutput(_ value: String) -> Builder {
        lock.lock()
        defer { lock.unlock() }
        output = value
        return self
    }
}
```

### Proposed Solution

Introduce actor-based alternative with structured mutation API, keeping class builder for backwards compatibility.

**Alternative Implementation**:
```swift
// New actor-based builder (thread-safe by design)
public actor AgentResultBuilder {
    private var output: String = ""
    private var toolCalls: [ToolCall] = []
    private var toolResults: [ToolResult] = []
    private var iterationCount: Int = 0
    private var startTime: ContinuousClock.Instant?
    private var tokenUsage: TokenUsage?
    private var metadata: [String: SendableValue] = [:]

    public init() {}

    // Mutation methods (no lock needed)
    public func setOutput(_ value: String) {
        output = value
    }

    public func appendOutput(_ value: String) {
        output += value
    }

    public func addToolCall(_ call: ToolCall) {
        toolCalls.append(call)
    }

    public func addToolResult(_ result: ToolResult) {
        toolResults.append(result)
    }

    public func incrementIteration() {
        iterationCount += 1
    }

    public func start() {
        startTime = ContinuousClock.now
    }

    public func setTokenUsage(_ usage: TokenUsage) {
        tokenUsage = usage
    }

    public func setMetadata(_ key: String, _ value: SendableValue) {
        metadata[key] = value
    }

    // Query methods
    public func getOutput() -> String {
        output
    }

    public func getIterationCount() -> Int {
        iterationCount
    }

    // Build final result
    public func build() -> AgentResult {
        let duration: Duration = if let start = startTime {
            ContinuousClock.now - start
        } else {
            .zero
        }

        return AgentResult(
            output: output,
            toolCalls: toolCalls,
            toolResults: toolResults,
            iterationCount: iterationCount,
            duration: duration,
            tokenUsage: tokenUsage,
            metadata: metadata
        )
    }
}

// Convenience extension on AgentResult for creating new builder
public extension AgentResult {
    static func builder() -> AgentResultBuilder {
        AgentResultBuilder()
    }
}
```

**Usage Examples**:
```swift
// New actor-based builder
let builder = AgentResult.builder()
await builder.setOutput("Result")
await builder.addToolCall(call)
let result = await builder.build()

// Existing class builder still works
let classBuilder = AgentResult.Builder()
let result = classBuilder.setOutput("Result").build()
```

### Implementation Plan

1. **Create Actor Builder** (`Sources/SwiftAgents/Core/AgentResult.swift`)
   - Add `AgentResultBuilder` actor with all mutation methods
   - Remove manual locking (actor isolation provides safety)
   - Keep all existing class Builder unchanged

2. **Add Convenience Factory**
   - Add `AgentResult.builder()` static method
   - Returns new actor-based builder

3. **Update Agent Implementations** (Optional)
   - ReActAgent, ToolCallingAgent, PlanAndExecuteAgent can use actor builder
   - Keep class builder for backward compatibility

4. **Update Documentation**
   - Document both builder options
   - Recommend actor builder for new code
   - Explain trade-offs

### Pros
- Leverages Swift's actor isolation for thread safety (no manual locks)
- Aligns with codebase's actor-first design (Memory, ToolRegistry are actors)
- No `@unchecked Sendable` required
- Structured concurrency friendly

### Cons
- Requires `await` for all mutations (could be perceived as less ergonomic)
- Breaking change if existing code relies on class builder (but we keep it)
- Adds another API variant to maintain

### Justification

The actor approach eliminates manual locking and `@unchecked Sendable`, aligning with Swift 6 concurrency model. The ergonomics trade-off (requiring `await`) is justified by improved safety and consistency with the rest of the codebase.

### Migration Path

**Fully Backward Compatible**:
1. Keep existing `AgentResult.Builder` class unchanged
2. Add new `AgentResultBuilder` actor alongside it
3. Existing code continues to work
4. New code can choose either approach
5. Document actor builder as recommended for new implementations

---

## 4. Parameter Type Factory Functions

### Problem Statement

`ToolParameter.ParameterType` is an enum with associated values, but certain patterns (e.g., arrays, objects) are cumbersome to express.

**Current Usage** (`Sources/SwiftAgents/Tools/Tool.swift:115`):
```swift
public enum ParameterType: Sendable, Equatable {
    case array(elementType: ParameterType)  // Indirect
    case object(properties: [ToolParameter])
    case oneOf([String])
}

// Creating complex types is verbose
let arrayType = ToolParameter.ParameterType.array(elementType: .string)
let objectType = ToolParameter.ParameterType.object(properties: [
    ToolParameter(name: "name", description: "Name", type: .string)
])
```

### Proposed Solution

Introduce convenience initializers and factory functions for cleaner type definitions.

**Alternative Implementation**:
```swift
// Add factory functions to ParameterType
public extension ToolParameter.ParameterType {
    /// Creates an array type with element type
    static func array<T>(_ elementType: T) -> ParameterType 
        where T: ParameterTypeRepresentable 
    {
        .array(elementType: elementType.parameterType)
    }
    
    /// Creates an object type with named properties
    static func object(@ParameterBuilder _ properties: () -> [ToolParameter]) -> ParameterType {
        .object(properties: properties())
    }
    
    /// Creates an enum choice type
    static func oneOf(_ choices: String...) -> ParameterType {
        .oneOf(choices)
    }
}

// Protocol for Swift types that can represent parameter types
public protocol ParameterTypeRepresentable {
    var parameterType: ToolParameter.ParameterType { get }
}

// Conform common types
extension String: ParameterTypeRepresentable {
    public var parameterType: ToolParameter.ParameterType { .string }
}

extension Int: ParameterTypeRepresentable {
    public var parameterType: ToolParameter.ParameterType { .int }
}

extension Double: ParameterTypeRepresentable {
    public var parameterType: ToolParameter.ParameterType { .double }
}

extension Bool: ParameterTypeRepresentable {
    public var parameterType: ToolParameter.ParameterType { .bool }
}

// Usage
let params: [ToolParameter] = [
    Parameter("items", description: "List of items", type: .array(String.self)),
    Parameter("config", description: "Configuration", type: .object {
        Parameter("name", description: "Name", type: .string)
        Parameter("count", description: "Count", type: .int)
    }),
    Parameter("format", description: "Output format", type: .oneOf("json", "xml", "text"))
]
```

### Implementation Plan

1. **Create Protocol** (`Sources/SwiftAgents/Tools/Tool.swift`)
   - Add `ParameterTypeRepresentable` protocol
   - Conform common Swift types (String, Int, Double, Bool)

2. **Add Factory Extensions**
   - Add `.array(_:)` static method
   - Add `.object(_:)` static method using `@ParameterBuilder`
   - Add `.oneOf(_:)` static method with variadic arguments

3. **Update Documentation**
   - Provide examples using factory functions
   - Keep direct enum construction examples for reference

4. **Update Tests**
   - Add tests for factory function syntax
   - Ensure equivalence with direct enum construction

### Pros
- More readable type definitions (especially nested objects/arrays)
- Leverages Swift's type system for common cases
- Reduces boilerplate for standard types
- Composable for complex structures

### Cons
- Adds new protocol and extension surface
- Learning curve for factory function patterns
- Still maintains underlying enum structure (not full type system integration)

### Justification

Makes complex parameter definitions (nested objects, arrays) significantly more readable. The factory pattern is familiar to Swift developers from SwiftUI and Combine.

### Migration Path

**Fully Backward Compatible**:
1. All existing enum syntax continues to work
2. New factory functions are additive
3. Documentation can recommend factory syntax for new code
4. No breaking changes required

---

## 5. Memory Typed Message Retrieval

### Problem Statement

`Memory` protocol returns raw strings from `context(for:tokenLimit:)`, losing semantic information about retrieved messages.

**Current Usage** (`Sources/SwiftAgents/Memory/AgentMemory.swift:72`):
```swift
func context(for query: String, tokenLimit: Int) async -> String
```

**Current Pattern**:
```swift
// Only can get formatted string
let context = await memory.context(for: "greeting", tokenLimit: 1000)

// Cannot access individual messages, roles, timestamps, metadata
```

### Proposed Solution

Add typed retrieval methods that return structured message data alongside formatted strings.

**Alternative Implementation**:
```swift
// Extend Memory protocol with typed retrieval
public extension Memory {
    /// Retrieves structured messages within token limits
    /// - Parameters:
    ///   - query: Query for retrieval strategies
    ///   - tokenLimit: Maximum tokens to include
    /// - Returns: Array of messages that fit within token budget
    /// - Note: Default implementation retrieves all messages and truncates
    ///         Implementations can override for more efficient retrieval
    func retrieveMessages(
        for query: String,
        tokenLimit: Int
    ) async -> [MemoryMessage] {
        // Default implementation: get all messages, then format and parse
        let context = await context(for: query, tokenLimit: tokenLimit)
        // Note: This is lossy - better implementations override
        // This is a compromise for backward compatibility
        await allMessages().filter { message in
            // Simple filtering by query
            query.isEmpty || message.content.localizedCaseInsensitiveContains(query)
        }
    }
    
    /// Builds context from retrieved messages
    /// - Parameters:
    ///   - messages: Messages to format
    ///   - tokenLimit: Maximum tokens for context
    /// - Returns: Formatted context string
    func buildContext(
        from messages: [MemoryMessage],
        tokenLimit: Int
    ) async -> String {
        let estimator = CharacterBasedTokenEstimator.shared
        return formatMessagesForContext(
            messages,
            tokenLimit: tokenLimit,
            tokenEstimator: estimator
        )
    }
}

// Better: Add to Memory protocol directly (requires protocol change)
public protocol Memory: Actor, Sendable {
    var count: Int { get async }
    var isEmpty: Bool { get async }
    
    func add(_ message: MemoryMessage) async
    
    // New method with default implementation
    func retrieveMessages(for query: String, tokenLimit: Int) async -> [MemoryMessage] {
        // Default: return all messages (inefficient but functional)
        await allMessages()
    }
    
    // Existing method with new default implementation
    func context(for query: String, tokenLimit: Int) async -> String {
        let messages = await retrieveMessages(for: query, tokenLimit: tokenLimit)
        return await buildContext(from: messages, tokenLimit: tokenLimit)
    }
    
    func allMessages() async -> [MemoryMessage]
    func clear() async
}
```

**Usage Examples**:
```swift
// New typed retrieval
let messages = await memory.retrieveMessages(for: "greeting", tokenLimit: 1000)

// Access individual message properties
for message in messages {
    print("Role: \(message.role)")
    print("Timestamp: \(message.timestamp)")
    print("Metadata: \(message.metadata)")
}

// Build custom context
let customContext = await memory.buildContext(from: messages, tokenLimit: 500)

// Existing string-based API still works
let simpleContext = await memory.context(for: "greeting", tokenLimit: 1000)
```

### Implementation Plan

1. **Update Memory Protocol** (`Sources/SwiftAgents/Memory/AgentMemory.swift`)
   - Add `retrieveMessages(for:tokenLimit:)` method with default implementation
   - Update `context(for:tokenLimit:)` to use `retrieveMessages()` internally
   - Provide default implementations for backward compatibility

2. **Update Existing Implementations**
   - `ConversationMemory`: Override `retrieveMessages()` for efficiency (return recent messages)
   - `CompositeMemory`: Override to use its retrieval strategies
   - `SlidingWindowMemory`: Implement based on window logic

3. **Add Convenience Methods**
   - Add `buildContext(from:tokenLimit:)` method
   - Add `filterMessages(by:)` method for custom filtering

4. **Update Documentation**
   - Document both `context()` and `retrieveMessages()` approaches
   - Provide examples for advanced usage

5. **Update Tests**
   - Add tests for `retrieveMessages()`
   - Ensure `context()` still works with new implementation

### Pros
- Provides access to structured message data (roles, timestamps, metadata)
- Enables custom context formatting beyond simple string concatenation
- Backward compatible: existing `context(for:tokenLimit:)` still works
- Useful for advanced memory strategies (e.g., importance-based retrieval)

### Cons
- Protocol change (requires all conformers to implement new method, but provides default)
- May encourage users to bypass string formatting (loses consistent context format)
- Requires careful documentation about when to use `context()` vs `retrieveMessages()`

### Justification

Advanced memory implementations (vector search, importance scoring) need structured message access. Providing typed retrieval enables sophisticated context building while maintaining simple string-based API for common cases.

### Migration Path

**Fully Backward Compatible**:
1. Default implementation of `retrieveMessages()` calls `allMessages()`
2. Existing `context()` method implementation changes to use `retrieveMessages()`
3. All existing code using `context()` continues to work
4. New code can use `retrieveMessages()` for structured access
5. Memory implementations can override `retrieveMessages()` for efficiency

---

## 6. Route Condition Builder DSL

### Problem Statement

Complex route conditions require nested function calls, which can be hard to read.

**Current Usage** (`Sources/SwiftAgents/Orchestration/AgentRouter.swift:207`):
```swift
let condition = RouteCondition.contains("weather")
    .and(.lengthInRange(10...100))
    .or(.matches(pattern: #"\d{3}-\d{4}"#))
```

### Proposed Solution

Introduce a result builder DSL for declarative condition construction.

**Alternative Implementation**:
```swift
@resultBuilder
public struct ConditionBuilder {
    public static func buildBlock(_ conditions: RouteCondition...) -> RouteCondition {
        conditions.reduce(.never) { $0.or($1) }
    }
    
    public static func buildEither(first condition: RouteCondition) -> RouteCondition {
        condition
    }
    
    public static func buildEither(second condition: RouteCondition) -> RouteCondition {
        condition
    }
    
    public static func buildOptional(_ condition: RouteCondition?) -> RouteCondition {
        condition ?? .never
    }
    
    public static func buildExpression(_ expression: RouteCondition) -> RouteCondition {
        expression
    }
}

// New function to create conditions from builder
public func Condition(@ConditionBuilder builder: () -> RouteCondition) -> RouteCondition {
    builder()
}

// Additional syntax sugar for Router
extension AgentRouter {
    public init(
        fallbackAgent: (any Agent)? = nil,
        configuration: AgentConfiguration = .default,
        handoffs: [AnyHandoffConfiguration] = [],
        @RouterBuilder routes: () -> [Route]
    ) {
        // Existing implementation
    }
}

// Convenience functions for creating routes with conditions
public func when(
    contains substring: String,
    isCaseSensitive: Bool = false,
    to agent: @autoclosure () -> any Agent,
    name: String? = nil
) -> Route {
    Route(
        condition: .contains(substring, isCaseSensitive: isCaseSensitive),
        agent: agent(),
        name: name
    )
}

public func when(
    matches pattern: String,
    to agent: @autoclosure () -> any Agent,
    name: String? = nil
) -> Route {
    Route(
        condition: .matches(pattern: pattern),
        agent: agent(),
        name: name
    )
}

public func when(
    _ condition: RouteCondition,
    to agent: @autoclosure () -> any Agent,
    name: String? = nil
) -> Route {
    Route(
        condition: condition,
        agent: agent(),
        name: name
    )
}
```

**Usage Examples**:
```swift
// Using Condition builder for complex conditions
let complexCondition = Condition {
    RouteCondition.contains("weather")
        .and(.lengthInRange(10...100))
    
    RouteCondition.matches(pattern: #"\d{3}-\d{4}"#)
}

// Using syntactic sugar in Router
let router = AgentRouter(fallback: defaultAgent) {
    when(contains: "weather", to: weatherAgent, name: "Weather")
    when(matches: #"^\d+$"#, to: calculatorAgent, name: "Calculator")
    when(.lengthInRange(10...100), to: shortAgent, name: "Short")
}

// Original Router syntax still works
let router2 = AgentRouter {
    Route(condition: .contains("weather"), agent: weatherAgent)
    Route(condition: .lengthInRange(5...50), agent: newsAgent)
}
```

### Implementation Plan

1. **Create ConditionBuilder** (`Sources/SwiftAgents/Orchestration/AgentRouter.swift`)
   - Implement `@resultBuilder` struct
   - Support all result builder methods

2. **Add Condition() Function**
   - Global function to create conditions from builder
   - Document usage patterns

3. **Add Syntactic Sugar for Routes**
   - Add `when(contains:to:name:)` function
   - Add `when(matches:to:name:)` function
   - Add `when(_:to:name:)` generic function

4. **Update Documentation**
   - Provide examples of all syntax options
   - Recommend builder syntax for complex conditions

5. **Update Tests**
   - Add tests for Condition builder
   - Test all `when()` convenience functions
   - Ensure backward compatibility

### Pros
- More readable for complex nested conditions
- Enables if/else logic within condition definitions
- Familiar SwiftUI-like syntax
- Reduces parenthesis nesting

### Cons
- Adds new result builder to maintain
- Learning curve for when to use `Condition {}` vs direct chaining
- May be overkill for simple conditions

### Justification

For routes with 5+ conditions or nested logic, builder syntax significantly improves readability. Simple conditions can still use direct chaining.

### Migration Path

**Fully Backward Compatible**:
1. All existing `Route` creation syntax works unchanged
2. New `Condition` builder is additive
3. New `when()` convenience functions are additive
4. No breaking changes required

---

## 7. Type-Safe Tool Registry Methods

### Problem Statement

`ToolRegistry` only provides string-based lookup and execution, requiring runtime type checks.

**Current Usage** (`Sources/SwiftAgents/Tools/Tool.swift:284`):
```swift
public func tool(named name: String) -> (any Tool)?
```

**Current Pattern**:
```swift
// String-based lookup (error-prone)
if let tool = registry.tool(named: "calculator") {
    // Type erased - must cast
    if let calculator = tool as? CalculatorTool {
        // ...
    }
}
```

### Proposed Solution

Add type-safe query methods using Swift's type system.

**Alternative Implementation**:
```swift
public extension ToolRegistry {
    /// Returns first tool matching specified type
    /// - Parameter type: The tool type to find
    /// - Returns: Tool of specified type, or nil if not found
    func tool<T: Tool>(ofType type: T.Type) -> T? {
        for tool in tools.values {
            if let typedTool = tool as? T {
                return typedTool
            }
        }
        return nil
    }
    
    /// Returns all tools matching specified type
    /// - Parameter type: The tool type to find
    /// - Returns: Array of tools of specified type
    func tools<T: Tool>(ofType type: T.Type) -> [T] {
        tools.values.compactMap { $0 as? T }
    }
    
    /// Executes a tool by type with type-safe arguments
    /// - Parameters:
    ///   - type: The tool type to execute
    ///   - arguments: Arguments for tool execution
    ///   - agent: Optional agent executing the tool
    ///   - context: Optional agent context
    ///   - hooks: Optional hooks for lifecycle callbacks
    /// - Returns: The result of tool execution
    /// - Throws: AgentError if tool not found or execution fails
    func execute<T: Tool>(
        ofType type: T.Type,
        arguments: [String: SendableValue],
        agent: (any Agent)? = nil,
        context: AgentContext? = nil,
        hooks: (any RunHooks)? = nil
    ) async throws -> SendableValue {
        guard let tool = tool(ofType: type) else {
            throw AgentError.toolNotFound(name: String(describing: type))
        }
        return try await execute(
            toolNamed: tool.name,
            arguments: arguments,
            agent: agent,
            context: context,
            hooks: hooks
        )
    }
    
    /// Checks if a tool of specified type is registered
    /// - Parameter type: The tool type to check
    /// - Returns: True if tool exists
    func contains<T: Tool>(toolOfType type: T.Type) -> Bool {
        tool(ofType: type) != nil
    }
}
```

**Usage Examples**:
```swift
// Type-safe lookup
let calculator = registry.tool(ofType: CalculatorTool.self)
if let calc = calculator {
    // CalculatorTool type known at compile time
    print(calc.description)
}

// Get all tools of a type
let allCalculators = registry.tools(ofType: CalculatorTool.self)

// Type-safe execution
let result = try await registry.execute(
    ofType: CalculatorTool.self,
    arguments: ["expression": .string("2+2")]
)

// Type check
if registry.contains(toolOfType: CalculatorTool.self) {
    // Tool exists
}
```

### Implementation Plan

1. **Add Type-Safe Extensions** (`Sources/SwiftAgents/Tools/Tool.swift`)
   - Add `tool(ofType:)` method
   - Add `tools(ofType:)` method
   - Add `execute(ofType:arguments:...)` method
   - Add `contains(toolOfType:)` method

2. **Update Documentation**
   - Provide examples comparing string vs type-safe lookup
   - Recommend type-safe methods when tool type is known

3. **Update Tests**
   - Add tests for all type-safe methods
   - Ensure existing string-based tests still pass

### Pros
- Compile-time type safety when tool type is known
- Eliminates string literal tool names
- Better autocomplete and refactoring support
- Enables tool interface discovery via type checking

### Cons
- Only works when tool types are known at compile time
- Doesn't help with dynamically-registered tools (e.g., from MCP)
- Adds API surface without replacing string-based methods

### Justification

Many tool usages are with known tool types (especially with `@Tool` macro). Type-safe lookup provides better ergonomics for the common case while maintaining string-based methods for dynamic scenarios.

### Migration Path

**Fully Backward Compatible**:
1. All existing string-based methods unchanged
2. New type-safe methods are additive extensions
3. Existing code continues to work
4. No breaking changes required

---

## Implementation Phasing

### Phase 1: Quick Wins (Low Complexity, High Priority)

**Estimated Time**: 1-2 weeks

**Items**:
1. ✅ **Preserve Handoff Generic Target Type** (#2)
   - Add `TypedHandoffConfiguration<T>`
   - Update `handoff()` function return type
   - Add `anyHandoff()` convenience function
   - Update tests

2. ✅ **Parameter Type Factory Functions** (#4)
   - Add `ParameterTypeRepresentable` protocol
   - Conform common types
   - Add factory methods (`.array()`, `.object()`, `.oneOf()`)
   - Update documentation

3. ✅ **Type-Safe Tool Registry Methods** (#7)
   - Add `tool(ofType:)`, `tools(ofType:)` methods
   - Add `execute(ofType:arguments:)` method
   - Add `contains(toolOfType:)` method
   - Update tests

**Success Criteria**:
- All tests pass
- Documentation updated
- No breaking changes
- Examples provided for all new APIs

### Phase 2: Strategic Investments (Medium Complexity)

**Estimated Time**: 2-3 weeks

**Items**:
1. ⚠️ **Actor-Based AgentResult Builder** (#3)
   - Create `AgentResultBuilder` actor
   - Add `AgentResult.builder()` convenience
   - Update documentation
   - Optionally update agent implementations
   - Ensure backward compatibility

2. ⚠️ **Memory Typed Message Retrieval** (#5)
   - Update `Memory` protocol
   - Add `retrieveMessages(for:tokenLimit:)` method
   - Update `context(for:tokenLimit:)` implementation
   - Update existing memory implementations
   - Add tests

**Success Criteria**:
- All tests pass
- Backward compatibility maintained
- Performance impact measured
- Documentation comprehensive

### Phase 3: Long-Term Considerations (High Complexity)

**Estimated Time**: 3-4 weeks

**Items**:
1. 🔮 **Typed Tool Arguments via Enhanced @Tool Macro** (#1)
   - Design macro enhancement
   - Implement typed `execute()` generation
   - Maintain generic `execute(arguments:)`
   - Update examples and documentation
   - Extensive testing

2. 🔮 **Route Condition Builder DSL** (#6)
   - Create `ConditionBuilder` result builder
   - Add `Condition()` function
   - Add `when()` convenience functions
   - Update documentation
   - Add tests

**Success Criteria**:
- All tests pass
- Macro works as expected
- Documentation comprehensive
- No breaking changes
- Performance impact acceptable

### Phase 4: Documentation and Migration Guide

**Estimated Time**: 1 week

**Items**:
1. Update public API documentation
2. Create migration guide for existing users
3. Add examples to documentation
4. Update README with new features
5. Create blog post or article highlighting improvements

---

## Testing Strategy

### Unit Tests

For each recommendation:

1. **Type Safety Tests**
   - Verify compile-time type checking catches errors
   - Test type-safe methods return correct types
   - Test type erasure still works when needed

2. **Backward Compatibility Tests**
   - Ensure existing APIs still work
   - Test old and new code can coexist
   - Verify no breaking changes

3. **Ergonomics Tests**
   - Write example code using new APIs
   - Compare readability of old vs new syntax
   - Test autocomplete and IDE integration

### Integration Tests

1. **Tool Registry**
   - Test type-safe lookup alongside string-based lookup
   - Test mixed tool types in same registry
   - Test type-safe execution

2. **Handoff Configuration**
   - Test typed handoffs in Agent
   - Test type-erased collections
   - Test conversion between types

3. **Memory**
   - Test `retrieveMessages()` returns structured data
   - Test `context()` still returns formatted strings
   - Test custom context building

4. **Agent Result Builder**
   - Test actor builder from multiple concurrent tasks
   - Test class builder still works
   - Compare performance

### Performance Tests

1. **Type Erasure Overhead**
   - Measure performance impact of typed methods
   - Compare to existing string-based methods
   - Ensure no significant regression

2. **Actor Builder Performance**
   - Compare actor vs class builder performance
   - Measure structured concurrency overhead
   - Test with high concurrent access

3. **Macro Expansion**
   - Measure compile-time impact of macro enhancements
   - Test with large numbers of tools
   - Ensure acceptable build times

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-------------|---------|-------------|
| Breaking changes in typed APIs | Low | High | Maintain backward compatibility, extensive testing |
| Performance regression | Low | Medium | Benchmark critical paths, optimize if needed |
| Macro complexity | Medium | Medium | Incremental implementation, clear documentation |
| API confusion (too many options) | Medium | Low | Clear naming, comprehensive documentation |
| Actor isolation overhead | Low | Low | Benchmark, document trade-offs |

---

## Success Metrics

### Developer Experience
- Reduced boilerplate code (measurable lines of code reduction)
- Fewer runtime type errors (measured in production)
- Improved autocomplete suggestions (qualitative)

### Type Safety
- Increased compile-time error catching (measured in test suites)
- Reduced `as?` casting operations (code analysis)
- Better IDE integration (autocomplete accuracy)

### Maintainability
- Consistent API patterns across the codebase (code review)
- Clear documentation (documentation coverage)
- Low technical debt (code quality metrics)

### Performance
- No regression in critical paths (benchmarking)
- Acceptable compile-time impact (build time measurement)
- Memory efficiency unchanged (profiling)

---

## Open Questions

1. **Typed Tool Arguments (#1)**
   - Should typed `execute()` be required or optional?
   - How to handle tools with optional parameters?
   - What about tools with complex parameter validation?

2. **Route Condition Builder (#6)**
   - Is builder syntax overkill for simple conditions?
   - Should we deprecate direct chaining in favor of builder?
   - How to document when to use which approach?

3. **Memory Retrieval (#5)**
   - Should `retrieveMessages()` be part of protocol or extension?
   - How to handle memory types that can't efficiently implement it?
   - Should we deprecate `context(for:tokenLimit:)` in favor of `retrieveMessages()` + `buildContext()`?

4. **Actor Result Builder (#3)**
   - Should we deprecate class builder or keep both?
   - How to handle existing code relying on fluent chaining?
   - What about non-async contexts where actor builder can't be used?

---

## Conclusion

This plan proposes ergonomic improvements to the SwiftAgents API while maintaining backward compatibility and avoiding over-engineering. The recommendations prioritize:

1. **Quick Wins**: Low complexity, high impact improvements
2. **Type Safety**: Leveraging Swift's type system for better ergonomics
3. **Backward Compatibility**: Ensuring existing code continues to work
4. **Incremental Adoption**: Allowing users to adopt improvements at their own pace

The phased implementation approach allows for early feedback and course correction before tackling more complex changes. Each recommendation includes clear justifications, pros/cons, and migration paths to ensure informed decision-making.

**Next Steps**:
1. Review and approve this plan
2. Begin Phase 1 implementation
3. Gather feedback on early changes
4. Adjust timeline and scope based on learnings
5. Proceed to subsequent phases

---

## Appendix: Code Examples Comparison

### Before and After Examples

#### Recommendation #2: Handoff Type Safety

**Before**:
```swift
let handoff = handoff(to: executorAgent)
// Type: AnyHandoffConfiguration
// targetAgent is `any Agent` - type lost
```

**After**:
```swift
let typedHandoff = handoff(to: executorAgent)
// Type: TypedHandoffConfiguration<ExecutorAgent>
// typedHandoff.typedTarget is ExecutorAgent

let agent = typedHandoff.typedTarget  // Compile-time type!
```

#### Recommendation #4: Parameter Type Factories

**Before**:
```swift
let arrayParam = ToolParameter(
    name: "items",
    description: "List of items",
    type: .array(elementType: .string)
)

let objectParam = ToolParameter(
    name: "config",
    description: "Configuration",
    type: .object(properties: [
        ToolParameter(name: "name", description: "Name", type: .string),
        ToolParameter(name: "count", description: "Count", type: .int)
    ])
)
```

**After**:
```swift
let arrayParam = Parameter(
    "items",
    description: "List of items",
    type: .array(String.self)
)

let objectParam = Parameter(
    "config",
    description: "Configuration",
    type: .object {
        Parameter("name", description: "Name", type: .string)
        Parameter("count", description: "Count", type: .int)
    }
)
```

#### Recommendation #7: Type-Safe Tool Registry

**Before**:
```swift
guard let tool = registry.tool(named: "CalculatorTool") else {
    throw AgentError.toolNotFound(name: "CalculatorTool")
}
guard let calculator = tool as? CalculatorTool else {
    throw AgentError.invalidToolArguments(toolName: tool.name, reason: "Wrong type")
}
// Use calculator...
```

**After**:
```swift
guard let calculator = registry.tool(ofType: CalculatorTool.self) else {
    throw AgentError.toolNotFound(name: "CalculatorTool")
}
// Use calculator (type known at compile time)...

let result = try await registry.execute(
    ofType: CalculatorTool.self,
    arguments: ["expression": .string("2+2")]
)
```

---

**Document Version**: 1.0  
**Last Updated**: January 07, 2026  
**Maintainer**: SwiftAgents Team
