# Swarm Tools Documentation

Tools are the fundamental building blocks that enable agents to perform actions in Swarm. They encapsulate functionality that agents can invoke during execution, from simple calculations to complex API integrations.

## Table of Contents

1. [Overview](#overview)
2. [Tool Protocol](#tool-protocol)
3. [Creating Tools with @Tool Macro](#creating-tools-with-tool-macro)
4. [Parameter Types](#parameter-types)
5. [Built-in Tools](#built-in-tools)
6. [ToolRegistry](#toolregistry)
7. [Adding Tools to Agents](#adding-tools-to-agents)
8. [Parallel Tool Execution](#parallel-tool-execution)
9. [Error Handling](#error-handling)
10. [Advanced Patterns](#advanced-patterns)

---

## Overview

Swarm provides three ways to create tools:

1. **Typed Tools (recommended)**: Implement the typed `Tool` protocol with `Codable` input and typed output
2. **@Tool Macro (recommended for speed)**: Use `@Tool` + `@Parameter` to generate an `AnyJSONTool`
3. **AnyJSONTool (advanced)**: Implement the dynamic `AnyJSONTool` ABI directly when you need full control

All approaches are compatible and can be mixed in the same application.

---

## Tool Protocol

Swarm has two tool protocols:

- `Tool` (typed): the primary developer-facing API
- `AnyJSONTool` (dynamic): the runtime ABI used at the model boundary

### Typed Tool

The typed `Tool` protocol is the recommended way to build tools:

```swift
public protocol Tool: Sendable {
    associatedtype Input: Codable & Sendable
    associatedtype Output: Encodable & Sendable

    var name: String { get }
    var description: String { get }
    var parameters: [ToolParameter] { get }
    var inputGuardrails: [any ToolInputGuardrail] { get }
    var outputGuardrails: [any ToolOutputGuardrail] { get }

    func execute(_ input: Input) async throws -> Output
}
```

### AnyJSONTool

`AnyJSONTool` is the dynamic tool ABI used for provider tool calling:

```swift
public protocol AnyJSONTool: Sendable {
    var name: String { get }
    var description: String { get }
    var parameters: [ToolParameter] { get }
    var inputGuardrails: [any ToolInputGuardrail] { get }
    var outputGuardrails: [any ToolOutputGuardrail] { get }

    func execute(arguments: [String: SendableValue]) async throws -> SendableValue
}
```

### ToolSchema

`ToolSchema` is the public, provider-facing description of a tool. It captures the
tool name, description, and parameters in a stable format that can be shipped to
model APIs or stored for inspection.

```swift
public struct ToolSchema: Sendable, Equatable {
    public let name: String
    public let description: String
    public let parameters: [ToolParameter]
}
```

### Manual Tool Implementation

**Example** (typed `Tool`):

```swift
struct WeatherTool: Tool, Sendable {
    struct Input: Codable, Sendable {
        let location: String
    }

    struct Output: Codable, Sendable {
        let temperatureF: Double
        let conditions: String
    }

    let name = "weather"
    let description = "Gets the current weather for a location"
    let parameters: [ToolParameter] = [
        ToolParameter(name: "location", description: "City name", type: .string)
    ]

    func execute(_ input: Input) async throws -> Output {
        // Fetch weather data...
        Output(temperatureF: 72.0, conditions: "Sunny")
    }
}
```

This manual approach requires:
- Defining a provider-facing parameter schema (`parameters`)
- Codable input/output types for safety and maintainability

---

## Creating Tools with @Tool Macro

The `@Tool` macro dramatically simplifies tool creation by generating all the boilerplate automatically.

**After** (with @Tool macro):

```swift
@Tool("Gets the current weather for a location")
struct WeatherTool {
    @Parameter("City name to get weather for")
    var location: String

    func execute() async throws -> String {
        // location is automatically available as a typed property
        let temperature = 72.0
        return "\(temperature)°F and sunny in \(location)"
    }
}
```

### What the Macro Generates

The `@Tool` macro automatically creates:

1. **`name` property** - Derived from type name (lowercased, "Tool" suffix removed)
   - `WeatherTool` → `"weather"`
   - `CalculatorTool` → `"calculator"`

2. **`description` property** - From the macro argument

3. **`parameters` array** - From `@Parameter` annotated properties

4. **`execute(arguments:)` wrapper** - Extracts typed parameters and calls your execute()

5. **Tool and Sendable conformance**

6. **Default initializer** (if not already present)

### @Parameter Attribute

The `@Parameter` macro marks properties as tool parameters and captures their metadata:

```swift
@Parameter("Description of the parameter")
var paramName: String
```

#### With Default Values

```swift
@Parameter("Temperature units to use", default: "celsius")
var units: String = "celsius"
```

#### With Enum Constraints

```swift
@Parameter("Output format", oneOf: ["json", "xml", "text"])
var format: String
```

### Complete Example

```swift
@Tool("Gets weather information with optional units")
struct AdvancedWeatherTool {
    @Parameter("City name to get weather for")
    var location: String

    @Parameter("Temperature units", default: "celsius")
    var units: String = "celsius"

    @Parameter("Include 5-day forecast", default: false)
    var includeForecast: Bool = false

    func execute() async throws -> String {
        // All parameters are available as typed properties
        let temp = units == "celsius" ? "22°C" : "72°F"
        var result = "\(temp) in \(location)"

        if includeForecast {
            result += "\nForecast: Sunny week ahead"
        }

        return result
    }
}
```

---

## Parameter Types

Swarm supports comprehensive parameter type mapping:

### Basic Types

| Swift Type | ParameterType | Description |
|------------|---------------|-------------|
| `String` | `.string` | Text values |
| `Int` | `.int` | Integer numbers |
| `Double` | `.double` | Floating-point numbers |
| `Bool` | `.bool` | Boolean values |

### Complex Types

```swift
// Array type
@Parameter("List of cities")
var cities: [String]  // Maps to .array(elementType: .string)

// Optional parameters (marked as not required)
@Parameter("Optional description")
var notes: String?  // isRequired = false

// Enum constraints
@Parameter("Priority level", oneOf: ["low", "medium", "high"])
var priority: String  // Maps to .oneOf(["low", "medium", "high"])
```

### ToolParameter Structure

When implementing tools manually, you create parameters like this:

```swift
let parameters: [ToolParameter] = [
    ToolParameter(
        name: "expression",
        description: "The mathematical expression to evaluate",
        type: .string,
        isRequired: true
    ),
    ToolParameter(
        name: "precision",
        description: "Decimal places for result",
        type: .int,
        isRequired: false,
        defaultValue: .int(2)
    )
]
```

---

## Built-in Tools

Swarm includes several built-in tools for common operations:

### CalculatorTool

**Platform**: Apple platforms only (macOS, iOS, watchOS, tvOS, visionOS)
**Note**: Uses a safe arithmetic parser (not available on Linux due to NSExpression dependency)

```swift
let calc = CalculatorTool()
let result = try await calc.execute(arguments: [
    "expression": .string("(10 + 5) * 2")
])
// result == .double(30.0)
```

Supports:
- Basic arithmetic: `+`, `-`, `*`, `/`
- Parentheses for grouping
- Decimal numbers
- Safe evaluation (no code injection risk)

### DateTimeTool

**Platform**: All platforms

```swift
let dt = DateTimeTool()

// Current date/time in default format
let result = try await dt.execute(arguments: [:])

// ISO8601 format
let iso = try await dt.execute(arguments: [
    "format": .string("iso8601")
])

// Custom timezone
let ny = try await dt.execute(arguments: [
    "format": .string("full"),
    "timezone": .string("America/New_York")
])
```

Supported formats:
- `"full"` - Full date and time (default)
- `"date"` - Date only
- `"time"` - Time only
- `"short"` - Short format
- `"iso8601"` - ISO8601 UTC format
- `"unix"` - Unix timestamp
- Custom format strings (e.g., `"yyyy-MM-dd"`)

### StringTool

**Platform**: All platforms

```swift
let str = StringTool()

// Uppercase
let upper = try await str.execute(arguments: [
    "operation": .string("uppercase"),
    "input": .string("hello")
])
// result == .string("HELLO")

// Replace
let replaced = try await str.execute(arguments: [
    "operation": .string("replace"),
    "input": .string("hello world"),
    "pattern": .string("world"),
    "replacement": .string("Swift")
])
// result == .string("hello Swift")

// Substring
let sub = try await str.execute(arguments: [
    "operation": .string("substring"),
    "input": .string("hello"),
    "start": .int(0),
    "end": .int(4)
])
// result == .string("hell")
```

Supported operations:
- `length` - Get string length
- `uppercase` - Convert to uppercase
- `lowercase` - Convert to lowercase
- `trim` - Remove whitespace
- `split` - Split by delimiter
- `replace` - Replace pattern
- `contains` - Check if contains pattern
- `reverse` - Reverse string
- `substring` - Extract substring

### Using All Built-in Tools

```swift
// Platform-specific: includes CalculatorTool on Apple platforms
let agent = Agent(
    tools: BuiltInTools.all,
    instructions: "You are a helpful assistant with access to tools."
)

// Apple platforms: [CalculatorTool, DateTimeTool, StringTool]
// Linux: [DateTimeTool, StringTool]
```

---

## ToolRegistry

`ToolRegistry` is an actor that provides thread-safe tool registration and execution.

### Creating a Registry

```swift
// Empty registry
let registry = ToolRegistry()

// With initial tools
let registry = ToolRegistry(tools: [
    DateTimeTool(),
    StringTool(),
    WeatherTool()
])
```

### Managing Tools

```swift
// Register a single tool
await registry.register(WeatherTool())

// Register multiple tools
await registry.register([
    CalculatorTool(),
    DateTimeTool()
])

// Check if tool exists
let hasWeather = await registry.contains(named: "weather")

// Get tool by name
if let tool = await registry.tool(named: "weather") {
    print("Found tool: \(tool.name)")
}

// Get all tool names
let names = await registry.toolNames
print("Available tools: \(names)")

// Get all tool schemas (for LLM prompts)
let schemas = await registry.schemas

// Unregister a tool
await registry.unregister(named: "weather")

// Count of registered tools
let count = await registry.count
```

### Executing Tools

```swift
let result = try await registry.execute(
    toolNamed: "weather",
    arguments: ["location": .string("San Francisco")],
    agent: myAgent,
    context: nil,
    hooks: myHooks
)

switch result {
case .string(let text):
    print("Weather: \(text)")
case .double(let number):
    print("Temperature: \(number)")
default:
    print("Unexpected result type")
}
```

### Tool Execution Features

- **Guardrail Support**: Automatically runs input and output guardrails
- **Error Handling**: Throws `AgentError.toolNotFound` or `AgentError.toolExecutionFailed`
- **Cancellation**: Respects task cancellation
- **Hooks**: Notifies hooks of errors for observability

---

## Adding Tools to Agents

### Direct Initialization

```swift
let agent = Agent(
    tools: [
        WeatherTool(),
        CalculatorTool(),
        DateTimeTool()
    ],
    instructions: "You are a helpful assistant with access to weather, math, and time tools."
)

let result = try await agent.run("What's the weather in Tokyo?")
```

Typed `Tool` instances can be passed directly; Swarm bridges them to the
runtime `AnyJSONTool` ABI automatically.

### Using Builder Pattern

```swift
let agent = Agent.Builder()
    .tools([WeatherTool(), CalculatorTool()])
    .instructions("You are a helpful math and weather assistant")
    .configuration(.default)
    .build()
```

### ReActAgent Example

ReActAgent uses a text-based reasoning loop to decide when to use tools:

```swift
let reactAgent = ReActAgent(
    tools: BuiltInTools.all,
    instructions: """
    You are a helpful assistant. Use the available tools to answer questions.
    Think step-by-step and show your reasoning.
    """
)

let result = try await reactAgent.run("Calculate 15% tip on $45.50")
// Agent will reason about using calculator tool, then execute it
```

### Agent Example

Agent uses the LLM's native tool calling API for more reliable execution:

```swift
let toolAgent = Agent(
    tools: [WeatherTool(), StocksTool()],
    instructions: "You are a financial and weather assistant.",
    configuration: AgentConfiguration(
        maxIterations: 10,
        temperature: 0.7
    )
)

let result = try await toolAgent.run(
    "What's the weather in New York and the current AAPL stock price?"
)
// Agent may call both tools in parallel or sequence
```

---

## Parallel Tool Execution

Swarm includes `ParallelToolExecutor` for executing multiple tools concurrently with structured concurrency.

### Features

- **Order Preservation**: Results always match input order, regardless of completion order
- **Thread Safety**: Actor-based execution
- **Error Strategies**: Configurable error handling
- **Cancellation Support**: Properly propagates task cancellation

### Basic Parallel Execution

```swift
let executor = ParallelToolExecutor()

let calls = [
    ToolCall(toolName: "weather", arguments: ["city": .string("NYC")]),
    ToolCall(toolName: "stocks", arguments: ["symbol": .string("AAPL")]),
    ToolCall(toolName: "news", arguments: ["topic": .string("tech")])
]

let results = try await executor.executeInParallel(
    calls,
    using: registry,
    agent: agent,
    context: nil
)

// Results[0] is weather (guaranteed order)
// Results[1] is stocks
// Results[2] is news

for result in results {
    if result.isSuccess {
        print("\(result.toolName): \(result.value!)")
    } else {
        print("\(result.toolName) failed: \(result.error!)")
    }
}
```

### Error Strategies

```swift
public enum ParallelExecutionErrorStrategy {
    case failFast        // Throw on first error, cancel remaining
    case collectErrors   // Throw composite error if any failed
    case continueOnError // Return all results with failures
}
```

#### Fail Fast Strategy

```swift
let results = try await executor.executeInParallel(
    calls,
    using: registry,
    agent: agent,
    context: nil,
    errorStrategy: .failFast
)
// Throws immediately on first failure, cancels remaining tasks
```

#### Collect Errors Strategy

```swift
let results = try await executor.executeInParallel(
    calls,
    using: registry,
    agent: agent,
    context: nil,
    errorStrategy: .collectErrors
)
// All tools execute, then throws if any failed
```

#### Continue on Error Strategy

```swift
let results = try await executor.executeInParallel(
    calls,
    using: registry,
    agent: agent,
    context: nil,
    errorStrategy: .continueOnError
)

// Handle failures individually
for result in results {
    if !result.isSuccess {
        print("Tool \(result.toolName) failed: \(result.error!)")
    }
}
```

### Convenience Methods

```swift
// Continue on errors (same as .continueOnError)
let results = try await executor.executeAllCapturingErrors(
    calls,
    using: registry,
    agent: agent
)

// Fail immediately on any error (same as .failFast)
let results = try await executor.executeAllOrFail(
    calls,
    using: registry,
    agent: agent
)
```

### ToolExecutionResult

Each result includes timing and error information:

```swift
public struct ToolExecutionResult {
    public let toolName: String
    public let arguments: [String: SendableValue]
    public let value: SendableValue?
    public let error: Error?
    public let duration: Duration

    public var isSuccess: Bool { error == nil }
}
```

---

## Error Handling

### Tool-Specific Errors

Tools should throw descriptive errors using `AgentError`:

```swift
@Tool("Divides two numbers")
struct DivisionTool {
    @Parameter("First number")
    var numerator: Double

    @Parameter("Second number")
    var denominator: Double

    func execute() async throws -> Double {
        guard denominator != 0 else {
            throw AgentError.toolExecutionFailed(
                toolName: "division",
                underlyingError: "Cannot divide by zero"
            )
        }
        return numerator / denominator
    }
}
```

### Common Error Cases

```swift
// Missing required parameter
throw AgentError.invalidToolArguments(
    toolName: name,
    reason: "Missing required parameter '\(paramName)'"
)

// Invalid parameter value
throw AgentError.invalidToolArguments(
    toolName: name,
    reason: "Invalid timezone identifier: \(tzId)"
)

// Tool execution failed
throw AgentError.toolExecutionFailed(
    toolName: name,
    underlyingError: error.localizedDescription
)

// Tool not found
throw AgentError.toolNotFound(name: toolName)
```

### Helper Methods

The `Tool` protocol extension provides validation helpers:

```swift
// Validate all required parameters are present
try validateArguments(arguments)

// Get required string parameter
let location = try requiredString("location", from: arguments)

// Get optional string parameter with default
let units = optionalString("units", from: arguments, default: "celsius")
```

### Return Type Encoding

The `@Tool` macro automatically handles return type conversion:

- **Primitive types** (String, Int, Double, Bool) are encoded directly
- **SendableValue** returns are passed through unchanged
- **Void/()** returns become `.null`
- **Complex types** (custom structs, enums) are handled via `Codable`

```swift
@Tool("Returns custom data")
struct DataTool {
    struct CustomResult: Codable, Sendable {
        let value: Int
        let metadata: String
    }

    func execute() async throws -> CustomResult {
        // Automatically encoded via Codable
        return CustomResult(value: 42, metadata: "success")
    }
}
```

**Important**: If your custom type doesn't conform to `Codable`, the macro will throw an error rather than silently converting to a string (which could expose sensitive data).

---

## Advanced Patterns

### Tool Guardrails

Add validation to tool inputs and outputs:

```swift
struct RateLimitGuard: ToolInputGuardrail {
    func validate(data: ToolGuardrailData) async throws -> GuardrailDecision {
        // Check rate limit before execution
        if isRateLimited(data.tool.name) {
            return .deny(reason: "Rate limit exceeded")
        }
        return .allow
    }
}

struct SensitiveOutputFilter: ToolOutputGuardrail {
    func validate(data: ToolGuardrailData, output: SendableValue) async throws -> GuardrailDecision {
        // Redact sensitive information
        if containsSensitiveData(output) {
            return .deny(reason: "Output contains sensitive data")
        }
        return .allow
    }
}

struct SecureWeatherTool: AnyJSONTool, Sendable {
    let name = "weather"
    let description = "Gets weather"
    let parameters: [ToolParameter] = [...]

    let inputGuardrails: [any ToolInputGuardrail] = [RateLimitGuard()]
    let outputGuardrails: [any ToolOutputGuardrail] = [SensitiveOutputFilter()]

    func execute(arguments: [String: SendableValue]) async throws -> SendableValue {
        // Tool implementation
    }
}
```

### Dynamic Tool Registration

Build tools at runtime based on configuration:

```swift
func createToolsFromConfig(_ config: ToolConfiguration) async -> [any AnyJSONTool] {
    var tools: [any AnyJSONTool] = []

    if config.enableWeather {
        tools.append(WeatherTool())
    }

    if config.enableCalculator {
        #if canImport(Darwin)
        tools.append(CalculatorTool())
        #endif
    }

    // Add custom tools from plugins
    for plugin in config.plugins {
        if let tool = await plugin.createTool() {
            tools.append(tool)
        }
    }

    return tools
}

let agent = Agent(
    tools: await createToolsFromConfig(config),
    instructions: "You are a configurable assistant"
)
```

### Type-Erased Tool Collections

Use `AnyTool` to store heterogeneous tools:

```swift
let tools: [AnyTool] = [
    AnyTool(CalculatorTool()),
    AnyTool(WeatherTool()),
    AnyTool(DateTimeTool())
]

for tool in tools {
    print("Tool: \(tool.name) - \(tool.description)")
}

let registry = ToolRegistry(tools: tools)
```

### Tool Composition

Create higher-level tools from simpler ones:

```swift
@Tool("Gets weather and suggests activities")
struct WeatherActivityTool {
    @Parameter("City name")
    var location: String

    private let weatherTool = WeatherTool()

    func execute() async throws -> String {
        // Use another tool internally
        let weather = try await weatherTool.execute(arguments: [
            "location": .string(location)
        ])

        guard let weatherStr = weather.stringValue else {
            return "Unable to get weather"
        }

        // Add activity suggestions based on weather
        if weatherStr.contains("sunny") {
            return "\(weatherStr)\nSuggested activity: Visit a park!"
        } else {
            return "\(weatherStr)\nSuggested activity: Visit a museum!"
        }
    }
}
```

### Async Tool Initialization

For tools that require async setup:

```swift
@Tool("Accesses external API")
struct APITool {
    @Parameter("Query string")
    var query: String

    // Lazy async initialization
    private var client: APIClient {
        get async {
            await APIClient.shared
        }
    }

    func execute() async throws -> String {
        let apiClient = await client
        return try await apiClient.query(query)
    }
}
```

### Tool Metrics and Observability

Track tool usage with custom metrics:

```swift
struct MetricsWeatherTool: AnyJSONTool, Sendable {
    let name = "weather"
    let description = "Gets weather with metrics"
    let parameters: [ToolParameter] = [...]

    func execute(arguments: [String: SendableValue]) async throws -> SendableValue {
        let startTime = ContinuousClock.now

        defer {
            let duration = ContinuousClock.now - startTime
            MetricsCollector.record(
                tool: name,
                duration: duration,
                success: true
            )
        }

        // Tool implementation
        return .string("Weather data")
    }
}
```

---

## Best Practices

### Tool Design

1. **Single Responsibility**: Each tool should do one thing well
2. **Clear Descriptions**: Write descriptions that help the LLM understand when to use the tool
3. **Validate Inputs**: Always validate parameters before execution
4. **Descriptive Errors**: Provide clear error messages for debugging
5. **Sendable Safety**: Ensure tools are thread-safe (use `Sendable` types)

### Parameter Design

1. **Required vs Optional**: Make parameters optional only when truly optional
2. **Default Values**: Provide sensible defaults to reduce cognitive load
3. **Constraints**: Use `oneOf` for enum-like parameters
4. **Type Safety**: Use appropriate Swift types (Int, Double, Bool) instead of strings

### Performance

1. **Async Operations**: Use async/await for I/O operations
2. **Cancellation**: Respect task cancellation with `Task.checkCancellation()`
3. **Resource Cleanup**: Use `defer` for cleanup in error paths
4. **Parallel Execution**: Use `ParallelToolExecutor` for independent tools

### Testing

1. **Unit Tests**: Test tools in isolation with mock data
2. **Edge Cases**: Test with empty strings, nil values, boundary conditions
3. **Error Paths**: Verify error handling behavior
4. **Integration Tests**: Test tools with real agents

```swift
final class WeatherToolTests: XCTestCase {
    func testWeatherToolWithValidLocation() async throws {
        let tool = WeatherTool()
        let result = try await tool.execute(arguments: [
            "location": .string("Tokyo")
        ])

        XCTAssertNotNil(result.stringValue)
        XCTAssertTrue(result.stringValue!.contains("Tokyo"))
    }

    func testWeatherToolWithMissingLocation() async throws {
        let tool = WeatherTool()

        do {
            _ = try await tool.execute(arguments: [:])
            XCTFail("Should throw missing parameter error")
        } catch let error as AgentError {
            if case .invalidToolArguments = error {
                // Expected
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }
}
```

---

## Summary

Swarm provides a comprehensive tools system with:

- **@Tool Macro**: Eliminates boilerplate for rapid development
- **Type Safety**: Compile-time checking with `Tool` and `Codable` inputs
- **Built-in Tools**: Ready-to-use tools for common operations
- **ToolRegistry**: Thread-safe tool management
- **Parallel Execution**: Concurrent tool execution with structured concurrency
- **Guardrails**: Input/output validation for safety
- **Error Handling**: Comprehensive error types and validation helpers

Start with the `@Tool` macro for quick development, and use manual implementation when you need full control over tool behavior. Both approaches integrate seamlessly with all Swarm agent types.
