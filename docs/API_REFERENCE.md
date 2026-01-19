# SwiftAgents API Reference

## Overview

SwiftAgents is a framework for building autonomous AI agents in Swift. This reference covers all public APIs, organized by module.

## Table of Contents

- [Core Types](#core-types)
- [Tool System](#tool-system)
- [Agent System](#agent-system)
- [Orchestration](#orchestration)
- [Memory System](#memory-system)
- [Error Handling](#error-handling)

## Core Types

### AgentResult

Represents the result of an agent execution.

```swift
public struct AgentResult: Sendable, Equatable {
    /// The final output from the agent.
    public let output: String

    /// Additional metadata about the execution.
    public let metadata: [String: SendableValue]

    /// Creates a new agent result.
    public init(output: String, metadata: [String: SendableValue] = [:])
}
```

**Example:**
```swift
let result = AgentResult(
    output: "The calculation result is 42",
    metadata: ["confidence": .double(0.95)]
)
```

### SendableValue

A type-safe container for values that can be sent across concurrency boundaries.

```swift
public enum SendableValue: Sendable, Equatable, Hashable, Codable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([SendableValue])
    case dictionary([String: SendableValue])
}
```

**Example:**
```swift
let value = SendableValue.dictionary([
    "name": .string("John"),
    "age": .int(30),
    "active": .bool(true)
])

// Or using subscript access
if let name = value["name"]?.stringValue {
    print(name) // "John"
}
```

## Tool System

### Tool Protocol

The core protocol that all tools must implement.

```swift
public protocol Tool: Sendable {
    /// The unique name of this tool.
    var name: String { get }

    /// A description of what this tool does.
    var description: String { get }

    /// The parameters this tool accepts.
    var parameters: [ToolParameter] { get }

    /// Input guardrails for this tool.
    var inputGuardrails: [any ToolInputGuardrail] { get }

    /// Output guardrails for this tool.
    var outputGuardrails: [any ToolOutputGuardrail] { get }

    /// Executes the tool with the given arguments.
    func execute(arguments: [String: SendableValue]) async throws -> SendableValue
}
```

**Example:**
```swift
struct CalculatorTool: Tool {
    let name = "calculator"
    let description = "Performs mathematical calculations"
    let parameters: [ToolParameter] = [
        ToolParameter(name: "expression", description: "Math expression", type: .string)
    ]
    let inputGuardrails: [any ToolInputGuardrail] = []
    let outputGuardrails: [any ToolOutputGuardrail] = []

    func execute(arguments: [String: SendableValue]) async throws -> SendableValue {
        guard let expression = arguments["expression"]?.stringValue else {
            throw AgentError.invalidToolArguments(toolName: name, reason: "Missing expression")
        }
        return .string("Result of: \(expression)")
    }
}
```

### ToolRegistry

Manages tool registration and execution.

```swift
public actor ToolRegistry {
    /// Gets all registered tools.
    public var allTools: [any Tool] { get }

    /// Gets all tool names.
    public var toolNames: [String] { get }

    /// Gets all tool definitions.
    public var definitions: [ToolDefinition] { get }

    /// The number of registered tools.
    public var count: Int { get }

    /// Creates an empty tool registry.
    public init()

    /// Creates a tool registry with the given tools.
    public init(tools: [any Tool])

    /// Registers a tool.
    public func register(_ tool: any Tool)

    /// Registers multiple tools.
    public func register(_ newTools: [any Tool])

    /// Unregisters a tool by name.
    public func unregister(named name: String)

    /// Gets a tool by name.
    public func tool(named name: String) -> (any Tool)?

    /// Returns true if a tool with the given name is registered.
    public func contains(named name: String) -> Bool

    /// Executes a tool by name with the given arguments.
    public func execute(
        toolNamed name: String,
        arguments: [String: SendableValue],
        agent: (any Agent)? = nil,
        context: AgentContext? = nil,
        hooks: (any RunHooks)? = nil
    ) async throws -> SendableValue
}
```

**Type-Safe Extensions:**
```swift
extension ToolRegistry {
    /// Gets the first tool of the specified type.
    public func tool<T>(ofType type: T.Type) async -> T? where T: Tool

    /// Gets all tools of the specified type.
    public func tools<T>(ofType type: T.Type) async -> [T] where T: Tool

    /// Executes the first tool of the specified type.
    public func execute<T>(
        ofType type: T.Type,
        arguments: [String: SendableValue],
        agent: (any Agent)? = nil,
        context: AgentContext? = nil,
        hooks: (any RunHooks)? = nil
    ) async throws -> SendableValue where T: Tool

    /// Returns true if a tool of the specified type is registered.
    public func contains<T>(toolOfType type: T.Type) async -> Bool where T: Tool
}
```

**Example:**
```swift
let registry = ToolRegistry()
registry.register(CalculatorTool())

// Type-safe lookup
if let calculator = await registry.tool(ofType: CalculatorTool.self) {
    let result = try await calculator.execute(arguments: ["expression": .string("2+2")])
}

// Type-safe execution
let result = try await registry.execute(
    ofType: CalculatorTool.self,
    arguments: ["expression": .string("2+2")]
)
```

### ToolParameter

Describes a parameter that a tool accepts.

```swift
public struct ToolParameter: Sendable, Equatable {
    /// The name of the parameter.
    public let name: String

    /// A description of the parameter.
    public let description: String

    /// The type of the parameter.
    public let type: ParameterType

    /// Whether this parameter is required.
    public let isRequired: Bool

    /// The default value for this parameter, if any.
    public let defaultValue: SendableValue?

    /// Creates a new tool parameter.
    public init(
        name: String,
        description: String,
        type: ParameterType,
        isRequired: Bool = true,
        defaultValue: SendableValue? = nil
    )
}
```

### ParameterType

Defines the type of a tool parameter.

```swift
public enum ParameterType: Sendable, Equatable {
    case string
    case int
    case double
    case bool
    case array(elementType: ParameterType)
    case object(properties: [ToolParameter])
    case oneOf([String])
    case any
}
```

**Factory Methods:**
```swift
extension ParameterType {
    /// Creates an array parameter type with the specified element type.
    public static func array<T>(_ elementType: T.Type) -> ParameterType where T: ParameterTypeRepresentable

    /// Creates an object parameter type with the specified properties.
    public static func object(@ToolParameterBuilder _ properties: () -> [ToolParameter]) -> ParameterType

    /// Creates an enum parameter type with the specified choices.
    public static func oneOf(_ choices: String...) -> ParameterType
}
```

**Example:**
```swift
// Using factory methods
let param = ToolParameter(
    name: "data",
    description: "Complex data structure",
    type: .object {
        ToolParameter(name: "name", description: "Name", type: .string)
        ToolParameter(name: "tags", description: "Tags", type: .array(String.self))
        ToolParameter(name: "config", description: "Config", type: .object {
            ToolParameter(name: "enabled", description: "Enabled", type: .bool)
            ToolParameter(name: "mode", description: "Mode", type: .oneOf("auto", "manual"))
        })
    }
)
```

## Agent System

### Agent Protocol

The core protocol that all agents must implement.

```swift
public protocol Agent: Sendable {
    /// The tools available to this agent.
    var tools: [any Tool] { get }

    /// The instructions for this agent.
    var instructions: String { get }

    /// The configuration for this agent.
    var configuration: AgentConfiguration { get }

    /// The memory system for this agent.
    var memory: (any Memory)? { get }

    /// The inference provider for this agent.
    var inferenceProvider: (any InferenceProvider)? { get }

    /// Runs the agent with the given input.
    func run(
        _ input: String,
        session: (any Session)? = nil,
        hooks: (any RunHooks)? = nil
    ) async throws -> AgentResult

    /// Runs the agent as a streaming operation.
    func stream(
        _ input: String,
        session: (any Session)? = nil,
        hooks: (any RunHooks)? = nil
    ) -> AsyncThrowingStream<AgentEvent, Error>

    /// Cancels the agent's current operation.
    func cancel() async
}
```

**Example:**
```swift
struct MyAgent: Agent {
    let tools: [any Tool] = [CalculatorTool()]
    let instructions = "You are a helpful assistant that can perform calculations."
    let configuration = AgentConfiguration.default
    var memory: (any Memory)? = nil
    var inferenceProvider: (any InferenceProvider)? = nil

    func run(_ input: String, session: (any Session)? = nil, hooks: (any RunHooks)? = nil) async throws -> AgentResult {
        // Agent implementation
        return AgentResult(output: "Processed: \(input)")
    }

    func stream(_ input: String, session: (any Session)? = nil, hooks: (any RunHooks)? = nil) -> AsyncThrowingStream<AgentEvent, Error> {
        // Streaming implementation
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }

    func cancel() async {
        // Cancellation logic
    }
}
```

### AgentConfiguration

Configuration options for agents.

```swift
public struct AgentConfiguration: Sendable, Equatable {
    /// The name of the agent.
    public let name: String

    /// The maximum number of iterations for agent execution.
    public let maxIterations: Int

    /// The timeout duration for agent execution.
    public let timeout: Duration?

    /// Whether to enable verbose logging.
    public let verbose: Bool

    /// Additional metadata.
    public let metadata: [String: SendableValue]

    /// Creates a new agent configuration.
    public init(
        name: String,
        maxIterations: Int = 10,
        timeout: Duration? = nil,
        verbose: Bool = false,
        metadata: [String: SendableValue] = [:]
    )

    /// The default agent configuration.
    public static var `default`: AgentConfiguration
}
```

## Orchestration

### HandoffBuilder

Fluent builder for creating handoff configurations.

```swift
public struct HandoffBuilder<Target: Agent>: Sendable {
    /// Creates a new handoff builder targeting the specified agent.
    public init(to target: Target)

    /// Sets a custom tool name for this handoff.
    public func toolName(_ name: String) -> HandoffBuilder<Target>

    /// Sets the description for the handoff tool.
    public func toolDescription(_ description: String) -> HandoffBuilder<Target>

    /// Sets the callback invoked before handoff execution.
    public func onHandoff(_ callback: @escaping OnHandoffCallback) -> HandoffBuilder<Target>

    /// Sets the input filter for transforming handoff data.
    public func inputFilter(_ filter: @escaping InputFilterCallback) -> HandoffBuilder<Target>

    /// Sets the enablement check callback.
    public func isEnabled(_ check: @escaping IsEnabledCallback) -> HandoffBuilder<Target>

    /// Sets whether to nest handoff history.
    public func nestHistory(_ nest: Bool) -> HandoffBuilder<Target>

    /// Builds the handoff configuration.
    public func build() -> HandoffConfiguration<Target>
}
```

**Example:**
```swift
let config = HandoffBuilder(to: executorAgent)
    .toolName("execute_task")
    .toolDescription("Execute the planned task")
    .onHandoff { context, data in
        Log.agents.info("Handoff: \(data.sourceAgentName) -> \(data.targetAgentName)")
    }
    .inputFilter { data in
        var modified = data
        modified.metadata["timestamp"] = .double(Date().timeIntervalSince1970)
        return modified
    }
    .isEnabled { context, _ in
        await context.get("ready")?.boolValue ?? false
    }
    .nestHistory(true)
    .build()
```

### Convenience Functions

```swift
/// Creates a handoff configuration using the builder pattern.
public func handoff<T: Agent>(
    to target: T,
    toolName: String? = nil,
    toolDescription: String? = nil,
    onHandoff: OnHandoffCallback? = nil,
    inputFilter: InputFilterCallback? = nil,
    isEnabled: IsEnabledCallback? = nil,
    nestHistory: Bool = false
) -> HandoffConfiguration<T>

/// Creates a type-erased handoff configuration.
public func anyHandoff<T: Agent>(
    to target: T,
    toolName: String? = nil,
    toolDescription: String? = nil,
    onHandoff: OnHandoffCallback? = nil,
    inputFilter: InputFilterCallback? = nil,
    isEnabled: IsEnabledCallback? = nil,
    nestHistory: Bool = false
) -> AnyHandoffConfiguration
```

## Memory System

### Memory Protocol

```swift
public protocol Memory: Sendable {
    /// Stores a message in memory.
    func store(_ message: MemoryMessage) async throws

    /// Retrieves relevant messages from memory.
    func retrieve(query: String, limit: Int) async throws -> [MemoryMessage]

    /// Clears all messages from memory.
    func clear() async throws
}
```

### MemoryMessage

```swift
public struct MemoryMessage: Sendable, Equatable {
    /// The role of the message sender.
    public let role: MessageRole

    /// The content of the message.
    public let content: String

    /// Additional metadata.
    public let metadata: [String: SendableValue]

    /// When the message was created.
    public let timestamp: Date

    /// Creates a new memory message.
    public init(
        role: MessageRole,
        content: String,
        metadata: [String: SendableValue] = [:],
        timestamp: Date = Date()
    )
}
```

## Error Handling

### AgentError

Comprehensive error types for agent operations.

```swift
public enum AgentError: Error, Sendable, Equatable {
    // Input errors
    case invalidInput(reason: String)
    case cancelled
    case maxIterationsExceeded(iterations: Int)
    case timeout(duration: Duration)

    // Tool errors
    case toolNotFound(name: String)
    case toolExecutionFailed(toolName: String, underlyingError: String)
    case invalidToolArguments(toolName: String, reason: String)

    // Model errors
    case inferenceProviderUnavailable(reason: String)
    case contextWindowExceeded(tokenCount: Int, limit: Int)
    case guardrailViolation(reason: String)
    case contentFiltered(reason: String)
    case unsupportedLanguage(language: String)
    case generationFailed(reason: String)
    case modelNotAvailable(model: String)

    // Rate limiting
    case rateLimitExceeded(retryAfter: TimeInterval?)

    // Other errors
    case embeddingFailed(reason: String)
    case internalError(reason: String)
}
```

**Extensions:**
```swift
extension AgentError: LocalizedError {
    public var errorDescription: String?
    public var recoverySuggestion: String?
    public var helpAnchor: String?
}
```

**Example Error Handling:**
```swift
do {
    let result = try await agent.run("Calculate 2+2")
} catch let error as AgentError {
    print("Error: \(error.localizedDescription)")
    if let suggestion = error.recoverySuggestion {
        print("Suggestion: \(suggestion)")
    }
}
```

## Best Practices

### Tool Registration
```swift
// Register tools at application startup
let registry = ToolRegistry(tools: [
    CalculatorTool(),
    WeatherTool(),
    DateTimeTool()
])

// Use type-safe lookups when possible
if let calculator = await registry.tool(ofType: CalculatorTool.self) {
    // Type-safe usage
}
```

### Agent Configuration
```swift
let config = AgentConfiguration(
    name: "MathAssistant",
    maxIterations: 5,
    timeout: .seconds(30),
    verbose: true
)
```

### Error Handling
```swift
do {
    let result = try await agent.run(input)
    print("Result: \(result.output)")
} catch AgentError.toolNotFound(let name) {
    print("Tool '\(name)' not found. Available tools: \(registry.toolNames)")
} catch AgentError.rateLimitExceeded(let retryAfter) {
    if let retryAfter {
        try await Task.sleep(for: .seconds(retryAfter))
        // Retry...
    }
}
```

### Handoff Configuration
```swift
let handoffConfig = handoff(
    to: executorAgent,
    toolName: "execute_task",
    toolDescription: "Execute the planned task",
    onHandoff: { context, data in
        await context.set("task_started", value: .bool(true))
    },
    isEnabled: { context, _ in
        await context.get("planning_complete")?.boolValue ?? false
    }
)
```

## Migration Guide

### From SwiftAgents 1.0 to 1.1

**Breaking Changes:**
- `handoff(to:)` now returns `HandoffConfiguration<T>` instead of `AnyHandoffConfiguration`

**Migration:**
```swift
// Before
let configs: [AnyHandoffConfiguration] = [
    handoff(to: agent1),
    handoff(to: agent2)
]

// After
let configs: [AnyHandoffConfiguration] = [
    anyHandoff(to: agent1),  // Use anyHandoff for type-erased
    anyHandoff(to: agent2)
]

// Or use typed configurations
let config1: HandoffConfiguration<Agent1> = handoff(to: agent1)
let config2: HandoffConfiguration<Agent2> = handoff(to: agent2)
```

**New Features:**
- Type-safe tool registry methods
- Enhanced error messages with recovery suggestions
- Fluent handoff builder API
- Parameter type factory methods

For more detailed migration instructions, see the [Migration Guide](MIGRATION_GUIDE.md).