# Best Practices Guide

This guide outlines recommended patterns and practices for building robust, maintainable applications with SwiftAgents.

## Table of Contents

- [Project Structure](#project-structure)
- [Tool Design](#tool-design)
- [Agent Configuration](#agent-configuration)
- [Error Handling](#error-handling)
- [Performance Optimization](#performance-optimization)
- [Testing](#testing)
- [Security](#security)

## Project Structure

### Recommended Directory Structure

```
Sources/
├── Tools/
│   ├── CalculatorTool.swift
│   ├── WeatherTool.swift
│   └── CustomTools/
│       ├── DatabaseTool.swift
│       └── APITool.swift
├── Agents/
│   ├── MathAgent.swift
│   ├── WeatherAgent.swift
│   └── CoordinatorAgent.swift
├── Configuration/
│   ├── AgentConfigs.swift
│   └── ToolRegistry.swift
└── Extensions/
    └── SwiftAgents+Extensions.swift

Tests/
├── Tools/
│   ├── CalculatorToolTests.swift
│   └── WeatherToolTests.swift
├── Agents/
│   ├── MathAgentTests.swift
│   └── CoordinatorAgentTests.swift
└── Integration/
    ├── EndToEndTests.swift
    └── PerformanceTests.swift
```

### Tool Organization

```swift
// Tools/CalculatorTool.swift
public struct CalculatorTool: Tool {
    public let name = "calculator"
    public let description = "Performs mathematical calculations"
    // Implementation...
}

// Tools/WeatherTool.swift
public struct WeatherTool: Tool {
    public let name = "weather"
    public let description = "Gets weather information"
    // Implementation...
}
```

### Agent Organization

```swift
// Agents/MathAgent.swift
public struct MathAgent: Agent {
    public let tools: [any Tool] = [CalculatorTool()]
    public let instructions = """
        You are a math assistant. Use the calculator tool to perform calculations.
        Always show your work and explain the steps.
        """
    public let configuration = AgentConfiguration(
        name: "MathAgent",
        maxIterations: 3,
        timeout: .seconds(10)
    )
    // Implementation...
}
```

## Tool Design

### 1. Single Responsibility Principle

**✅ Good: Each tool has one clear purpose**
```swift
struct CalculatorTool: Tool {
    let name = "calculator"
    let description = "Performs mathematical calculations"
    // Only handles calculations
}

struct FormatterTool: Tool {
    let name = "formatter"
    let description = "Formats numbers and text"
    // Only handles formatting
}
```

**❌ Bad: Tool tries to do too much**
```swift
struct MathTool: Tool {
    let name = "math"
    let description = "Does math and formatting"
    // Handles both calculation AND formatting
}
```

### 2. Descriptive Parameter Names

**✅ Good: Clear, descriptive parameters**
```swift
let parameters: [ToolParameter] = [
    ToolParameter(
        name: "expression",
        description: "The mathematical expression to evaluate (e.g., '2 + 2 * 3')",
        type: .string
    ),
    ToolParameter(
        name: "precision",
        description: "Number of decimal places to round to",
        type: .int,
        isRequired: false,
        defaultValue: .int(2)
    )
]
```

**❌ Bad: Unclear parameter names**
```swift
let parameters: [ToolParameter] = [
    ToolParameter(name: "expr", description: "Expression", type: .string),
    ToolParameter(name: "p", description: "Precision", type: .int)
]
```

### 3. Use Parameter Type Factories

**✅ Good: Type-safe parameter definitions**
```swift
let parameters: [ToolParameter] = [
    ToolParameter(
        name: "user",
        description: "User information",
        type: .object {
            ToolParameter(name: "name", description: "Full name", type: .string)
            ToolParameter(name: "age", description: "Age in years", type: .int)
            ToolParameter(name: "preferences", description: "User preferences", type: .object {
                ToolParameter(name: "theme", description: "UI theme", type: .oneOf("light", "dark"))
                ToolParameter(name: "notifications", description: "Enable notifications", type: .bool)
            })
        }
    ),
    ToolParameter(
        name: "tags",
        description: "List of tags",
        type: .array(String.self)
    )
]
```

### 4. Comprehensive Error Handling

**✅ Good: Specific error types**
```swift
func execute(arguments: [String: SendableValue]) async throws -> SendableValue {
    guard let expression = arguments["expression"]?.stringValue else {
        throw AgentError.invalidToolArguments(
            toolName: name,
            reason: "Missing required parameter 'expression'"
        )
    }

    do {
        let result = try evaluate(expression)
        return .double(result)
    } catch let error as CalculationError {
        throw AgentError.toolExecutionFailed(
            toolName: name,
            underlyingError: error.localizedDescription
        )
    }
}
```

### 5. Input Validation

**✅ Good: Validate inputs early**
```swift
func execute(arguments: [String: SendableValue]) async throws -> SendableValue {
    // Validate required parameters
    guard let expression = arguments["expression"]?.stringValue, !expression.isEmpty else {
        throw AgentError.invalidToolArguments(
            toolName: name,
            reason: "Parameter 'expression' is required and cannot be empty"
        )
    }

    // Validate parameter ranges
    let precision = arguments["precision"]?.intValue ?? 2
    guard (0...10).contains(precision) else {
        throw AgentError.invalidToolArguments(
            toolName: name,
            reason: "Parameter 'precision' must be between 0 and 10"
        )
    }

    // Proceed with validated inputs...
}
```

## Agent Configuration

### 1. Appropriate Timeouts and Limits

**✅ Good: Reasonable limits based on use case**
```swift
let configuration = AgentConfiguration(
    name: "ComplexReasoningAgent",
    maxIterations: 10,        // Allow complex reasoning
    timeout: .seconds(60),    // Allow time for thought
    verbose: true             // Debug complex flows
)

let configuration = AgentConfiguration(
    name: "QuickResponseAgent",
    maxIterations: 3,         // Simple responses
    timeout: .seconds(10),    // Fast responses
    verbose: false            // Production ready
)
```

### 2. Clear Instructions

**✅ Good: Specific, actionable instructions**
```swift
let instructions = """
You are a professional calculator assistant. Your role is to:

1. Parse mathematical expressions from user input
2. Use the calculator tool to compute results
3. Explain your calculations step by step
4. Format results clearly

Always show your work, even for simple calculations.
If you encounter an error, explain what went wrong and suggest fixes.
"""
```

**❌ Bad: Vague instructions**
```swift
let instructions = "You are a calculator. Do math."
```

### 3. Tool Selection

**✅ Good: Only include necessary tools**
```swift
struct MathAgent: Agent {
    // Only math-related tools
    let tools: [any Tool] = [
        CalculatorTool(),
        GraphingTool(),
        StatisticsTool()
    ]
    // No weather or database tools
}
```

## Error Handling

### 1. Use Recovery Suggestions

**✅ Good: Handle errors with recovery guidance**
```swift
do {
    let result = try await agent.run(input)
    print("Result: \(result.output)")
} catch let error as AgentError {
    print("Error: \(error.localizedDescription)")

    if let suggestion = error.recoverySuggestion {
        print("💡 \(suggestion)")
    }

    // Log for debugging
    Log.agents.error("Agent execution failed", error: error)
}
```

### 2. Structured Error Handling

**✅ Good: Different handling for different error types**
```swift
do {
    let result = try await agent.run(input)
} catch AgentError.toolNotFound(let name) {
    // Try to register the missing tool
    if let tool = availableTools[name] {
        registry.register(tool)
        // Retry...
    }
} catch AgentError.rateLimitExceeded(let retryAfter) {
    // Implement exponential backoff
    if let delay = retryAfter {
        try await Task.sleep(for: .seconds(delay))
        // Retry...
    }
} catch AgentError.contextWindowExceeded {
    // Summarize conversation and retry
    let summary = await summarizeConversation()
    // Retry with summary...
} catch {
    // Handle unexpected errors
    Log.agents.critical("Unexpected error", error: error)
}
```

### 3. Graceful Degradation

**✅ Good: Fall back to simpler behavior**
```swift
func getWeatherData(location: String) async -> WeatherData? {
    do {
        return try await weatherTool.execute(location: location)
    } catch AgentError.rateLimitExceeded {
        // Fall back to cached data
        return await getCachedWeatherData(location)
    } catch AgentError.modelNotAvailable {
        // Fall back to simple response
        return WeatherData(temperature: nil, condition: "unavailable")
    } catch {
        // Log and return nil
        Log.agents.error("Weather lookup failed", error: error)
        return nil
    }
}
```

## Performance Optimization

### 1. Tool Registry Optimization

**✅ Good: Register tools once at startup**
```swift
class AppDelegate {
    static let toolRegistry: ToolRegistry = {
        let registry = ToolRegistry()
        registry.register(CalculatorTool())
        registry.register(WeatherTool())
        // ... other tools
        return registry
    }()
}
```

**✅ Good: Use type-safe lookups for performance**
```swift
// For frequently used tools, cache the reference
class MyService {
    private let calculator: CalculatorTool

    init(registry: ToolRegistry) async throws {
        guard let calc = await registry.tool(ofType: CalculatorTool.self) else {
            throw AppError.toolNotAvailable("CalculatorTool")
        }
        self.calculator = calc
    }

    func calculate(_ expression: String) async throws -> Double {
        // Direct tool usage - no registry lookup
        let result = try await calculator.execute(arguments: ["expression": .string(expression)])
        return result.doubleValue!
    }
}
```

### 2. Agent Configuration Tuning

**✅ Good: Tune for your use case**
```swift
// For real-time chat
let chatConfig = AgentConfiguration(
    name: "ChatAgent",
    maxIterations: 2,      // Quick responses
    timeout: .seconds(5),  // Fast timeout
    verbose: false
)

// For complex reasoning
let reasoningConfig = AgentConfiguration(
    name: "ReasoningAgent",
    maxIterations: 10,     // Allow deep thinking
    timeout: .seconds(30), // Allow time to think
    verbose: true          // Debug complex flows
)
```

### 3. Memory Management

**✅ Good: Use appropriate memory systems**
```swift
// For short conversations
let memory = ConversationMemory(maxMessages: 50)

// For long-term knowledge
let memory = HybridMemory(
    conversationMemory: ConversationMemory(maxMessages: 20),
    vectorMemory: VectorMemory(embeddingProvider: myEmbeddings)
)
```

## Testing

### 1. Unit Test Structure

**✅ Good: Test all code paths**
```swift
class CalculatorToolTests: XCTestCase {
    var tool: CalculatorTool!

    override func setUp() {
        tool = CalculatorTool()
    }

    func testValidExpression() async throws {
        let result = try await tool.execute(arguments: ["expression": .string("2 + 2")])
        XCTAssertEqual(result.intValue, 4)
    }

    func testInvalidExpression() async {
        await XCTAssertThrowsError(
            try await tool.execute(arguments: ["expression": .string("invalid")])
        ) { error in
            XCTAssertTrue(error is AgentError)
        }
    }

    func testMissingExpression() async {
        await XCTAssertThrowsError(
            try await tool.execute(arguments: [:])
        ) { error in
            guard let agentError = error as? AgentError else {
                XCTFail("Expected AgentError")
                return
            }
            XCTAssertEqual(agentError, .invalidToolArguments(
                toolName: "calculator",
                reason: "Missing required parameter 'expression'"
            ))
        }
    }
}
```

### 2. Integration Testing

**✅ Good: Test complete workflows**
```swift
class MathAgentIntegrationTests: XCTestCase {
    var agent: MathAgent!
    var registry: ToolRegistry!

    override func setUp() async throws {
        registry = ToolRegistry(tools: [CalculatorTool()])
        agent = MathAgent()
        agent.inferenceProvider = MockInferenceProvider()
    }

    func testCompleteCalculationWorkflow() async throws {
        let result = try await agent.run("What is 15 * 7?")

        // Verify the agent used the calculator tool
        XCTAssertTrue(result.output.contains("105"))

        // Verify tool was actually called
        let mockProvider = agent.inferenceProvider as! MockInferenceProvider
        XCTAssertTrue(mockProvider.toolCalls.contains { $0.name == "calculator" })
    }
}
```

### 3. Performance Testing

**✅ Good: Test performance characteristics**
```swift
class PerformanceTests: XCTestCase {
    func testToolExecutionPerformance() async throws {
        let tool = CalculatorTool()
        let iterations = 1000

        let start = CFAbsoluteTimeGetCurrent()
        for _ in 0..<iterations {
            _ = try await tool.execute(arguments: ["expression": .string("2 + 2")])
        }
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        let averageTime = elapsed / Double(iterations)
        XCTAssertLessThan(averageTime, 0.001, "Tool execution should be fast")
    }

    func testAgentTimeoutBehavior() async throws {
        let slowAgent = SlowAgent() // Agent that takes time

        await XCTAssertThrowsError(
            try await slowAgent.run("slow task", timeout: .seconds(0.1))
        ) { error in
            XCTAssertEqual(error as? AgentError, .timeout(duration: .seconds(0.1)))
        }
    }
}
```

## Security

### 1. Input Validation

**✅ Good: Validate all inputs**
```swift
func execute(arguments: [String: SendableValue]) async throws -> SendableValue {
    // Validate string inputs for length and content
    guard let query = arguments["query"]?.stringValue else {
        throw AgentError.invalidToolArguments(toolName: name, reason: "Missing query")
    }

    guard query.count <= 1000 else {
        throw AgentError.invalidToolArguments(toolName: name, reason: "Query too long")
    }

    // Sanitize inputs
    let sanitizedQuery = query.replacingOccurrences(of: "<script>", with: "")
    // ... more validation
}
```

### 2. Guardrails

**✅ Good: Use appropriate guardrails**
```swift
struct DatabaseTool: Tool {
    let inputGuardrails: [any ToolInputGuardrail] = [
        InputSanitizationGuardrail(),  // Prevent SQL injection
        RateLimitGuardrail(requestsPerMinute: 60)
    ]

    let outputGuardrails: [any ToolOutputGuardrail] = [
        SensitiveDataGuardrail(),  // Remove PII
        ContentFilterGuardrail()   // Filter inappropriate content
    ]
}
```

### 3. Secure Configuration

**✅ Good: Don't log sensitive data**
```swift
func execute(arguments: [String: SendableValue]) async throws -> SendableValue {
    // DON'T log sensitive arguments
    // Log.agents.info("Executing with args: \(arguments)") // ❌

    // Log safe information only
    Log.agents.info("Executing tool '\(name)'") // ✅

    // Or sanitize logs
    let safeArgs = arguments.mapValues { value in
        switch value {
        case .string(let str): return .string(str.prefix(50) + "...")
        default: return value
        }
    }
    Log.agents.debug("Arguments: \(safeArgs)") // ✅
}
```

### 4. API Key Management

**✅ Good: Secure API key handling**
```swift
class SecureInferenceProvider: InferenceProvider {
    private let apiKey: String

    init(apiKey: String) {
        // Validate key format
        guard apiKey.hasPrefix("sk-") && apiKey.count > 20 else {
            fatalError("Invalid API key format")
        }
        self.apiKey = apiKey
    }

    // Never log the API key
    func generate(request: InferenceRequest) async throws -> InferenceResponse {
        Log.agents.debug("Making inference request to model: \(request.model)")
        // Don't log: Log.agents.debug("Using API key: \(apiKey)")
    }
}
```

## Summary

Following these best practices will result in:

- **Maintainable**: Clear structure and separation of concerns
- **Reliable**: Comprehensive error handling and testing
- **Performant**: Optimized for your use cases
- **Secure**: Proper input validation and guardrails
- **User-Friendly**: Helpful error messages and recovery suggestions

Remember: Start with the basics and incrementally adopt more advanced patterns as your application grows.