// Playground.swift
// SwiftAgents Framework
//
// A comprehensive playground for exploring and learning the SwiftAgents framework.
// This file demonstrates core concepts and provides examples for open source developers.
//
// To run: Build the library and import SwiftAgents in your project.

import Foundation

// MARK: - 1. Custom Tool Creation

/// Example: A custom weather tool that demonstrates the Tool protocol.
///
/// This shows how to create your own tools that agents can use.
/// Tools must conform to `Tool` and `Sendable` for thread safety.
///
/// Usage:
/// ```swift
/// let weatherTool = WeatherLookupTool()
/// let agent = ReActAgent.Builder()
///     .addTool(weatherTool)
///     .build()
/// ```
public struct WeatherLookupTool: Tool, Sendable {
    public let name = "weather_lookup"
    public let description = """
    Looks up the current weather for a given city. \
    Returns temperature, conditions, and humidity.
    """

    public let parameters: [ToolParameter] = [
        ToolParameter(
            name: "city",
            description: "The name of the city to look up weather for (e.g., 'San Francisco', 'Tokyo')",
            type: .string,
            isRequired: true
        ),
        ToolParameter(
            name: "units",
            description: "Temperature units: 'celsius' or 'fahrenheit'. Defaults to 'celsius'.",
            type: .oneOf(["celsius", "fahrenheit"]),
            isRequired: false,
            defaultValue: .string("celsius")
        )
    ]

    public init() {}

    public mutating func execute(arguments: [String: SendableValue]) async throws -> SendableValue {
        // Extract and validate arguments
        let city = try requiredString("city", from: arguments)
        let units = optionalString("units", from: arguments, default: "celsius") ?? "celsius"

        // Simulate weather lookup (in reality, this would call a weather API)
        // For demo purposes, we generate mock data
        let temperature = units == "celsius" ? 22 : 72
        let unitSymbol = units == "celsius" ? "°C" : "°F"

        let conditions = ["sunny", "cloudy", "partly cloudy", "rainy"].randomElement() ?? "clear"
        let humidity = Int.random(in: 40...80)

        return .dictionary([
            "city": .string(city),
            "temperature": .int(temperature),
            "units": .string(unitSymbol),
            "conditions": .string(conditions),
            "humidity": .int(humidity),
            "description": .string("Currently \(conditions) in \(city) at \(temperature)\(unitSymbol) with \(humidity)% humidity")
        ])
    }
}

// MARK: - 2. Custom Memory Implementation

/// Example: A simple memory implementation that stores recent messages.
///
/// This demonstrates how to create custom memory backends for agents.
/// Use memory to maintain conversation context across turns.
///
/// Usage:
/// ```swift
/// let memory = PlaygroundMemory(maxMessages: 10)
/// let agent = ReActAgent.Builder()
///     .memory(memory)
///     .build()
/// ```
public actor PlaygroundMemory: Memory {
    private var messages: [MemoryMessage] = []
    private let maxMessages: Int

    public init(maxMessages: Int = 50) {
        self.maxMessages = maxMessages
    }

    public var count: Int {
        messages.count
    }

    public var isEmpty: Bool {
        messages.isEmpty
    }

    public func add(_ message: MemoryMessage) async {
        messages.append(message)

        // Trim oldest messages if we exceed the limit
        if messages.count > maxMessages {
            messages.removeFirst(messages.count - maxMessages)
        }
    }

    public func context(for query: String, tokenLimit: Int) async -> String {
        formatMessagesForContext(messages, tokenLimit: tokenLimit)
    }

    public func allMessages() async -> [MemoryMessage] {
        messages
    }

    public func clear() async {
        messages.removeAll()
    }
}

// MARK: - 3. Run Hooks for Observability

/// Example: Custom hooks for observing agent execution.
///
/// RunHooks let you monitor agent behavior, log events,
/// and implement custom observability patterns.
///
/// Usage:
/// ```swift
/// let hooks = PlaygroundRunHooks()
/// let result = try await agent.run("Hello", hooks: hooks)
/// ```
public actor PlaygroundRunHooks: RunHooks {
    private var logs: [String] = []

    public init() {}

    public func onAgentStart(context: AgentContext?, agent: any Agent, input: String) async {
        let log = "[START] Agent received input: \(input.prefix(50))..."
        logs.append(log)
        print(log)
    }

    public func onAgentEnd(context: AgentContext?, agent: any Agent, result: AgentResult) async {
        let durationSeconds = Double(result.duration.components.seconds)
        let log = "[END] Agent completed in \(String(format: "%.2f", durationSeconds))s with output: \(result.output.prefix(50))..."
        logs.append(log)
        print(log)
    }

    public func onToolStart(context: AgentContext?, agent: any Agent, tool: String, input: [String: SendableValue]) async {
        let log = "[TOOL] Calling tool: \(tool)"
        logs.append(log)
        print(log)
    }

    public func onToolEnd(context: AgentContext?, agent: any Agent, tool: String, result: SendableValue) async {
        let log = "[TOOL] Tool \(tool) returned result"
        logs.append(log)
        print(log)
    }

    public func onThinking(context: AgentContext?, agent: any Agent, thought: String) async {
        let log = "[THINK] \(thought.prefix(80))..."
        logs.append(log)
        print(log)
    }

    public func onError(context: AgentContext?, agent: any Agent, error: Error) async {
        let log = "[ERROR] \(error.localizedDescription)"
        logs.append(log)
        print(log)
    }

    /// Get all collected logs
    public func getLogs() -> [String] {
        logs
    }

    /// Clear all logs
    public func clearLogs() {
        logs.removeAll()
    }
}

// MARK: - 4. Input Guardrail Example

/// Example: A content filter guardrail that validates input.
///
/// Guardrails protect your agents from harmful or invalid inputs.
///
/// Usage:
/// ```swift
/// let guardrail = ContentFilterGuardrail()
/// let agent = ReActAgent.Builder()
///     .inputGuardrails([guardrail])
///     .build()
/// ```
public struct ContentFilterGuardrail: InputGuardrail {
    public let name = "content_filter"

    // Words or patterns to block
    private let blockedPatterns: [String]

    public init(blockedPatterns: [String] = ["spam", "malicious"]) {
        self.blockedPatterns = blockedPatterns
    }

    public func validate(_ input: String, context: AgentContext?) async throws -> GuardrailResult {
        let lowercasedInput = input.lowercased()

        for pattern in blockedPatterns {
            if lowercasedInput.contains(pattern.lowercased()) {
                return .tripwire(message: "Input contains blocked content: '\(pattern)'")
            }
        }

        // Input validation checks
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .tripwire(message: "Input cannot be empty")
        }

        guard input.count <= 10000 else {
            return .tripwire(message: "Input exceeds maximum length of 10,000 characters")
        }

        return .passed(metadata: ["validated": .bool(true)])
    }
}

// MARK: - 5. Output Guardrail Example

/// Example: A PII redaction guardrail that sanitizes output.
///
/// Output guardrails can modify or validate agent responses
/// before they reach the user.
///
/// Usage:
/// ```swift
/// let guardrail = PIIRedactionGuardrail()
/// let agent = ReActAgent.Builder()
///     .outputGuardrails([guardrail])
///     .build()
/// ```
public struct PIIRedactionGuardrail: OutputGuardrail {
    public let name = "pii_redactor"

    public init() {}

    public func validate(_ output: String, agent: any Agent, context: AgentContext?) async throws -> GuardrailResult {
        var redactedOutput = output

        // Simple patterns for demonstration (use proper regex in production)
        // Redact email patterns
        let emailPattern = "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}"
        if let regex = try? NSRegularExpression(pattern: emailPattern, options: []) {
            let range = NSRange(redactedOutput.startIndex..., in: redactedOutput)
            redactedOutput = regex.stringByReplacingMatches(
                in: redactedOutput,
                options: [],
                range: range,
                withTemplate: "[EMAIL REDACTED]"
            )
        }

        // Redact phone patterns (simple US format)
        let phonePattern = "\\b\\d{3}[-.]?\\d{3}[-.]?\\d{4}\\b"
        if let regex = try? NSRegularExpression(pattern: phonePattern, options: []) {
            let range = NSRange(redactedOutput.startIndex..., in: redactedOutput)
            redactedOutput = regex.stringByReplacingMatches(
                in: redactedOutput,
                options: [],
                range: range,
                withTemplate: "[PHONE REDACTED]"
            )
        }

        let wasRedacted = redactedOutput != output

        return .passed(metadata: [
            "redacted": .bool(wasRedacted),
            "redactedOutput": .string(redactedOutput)
        ])
    }
}

// MARK: - 6. Agent Configuration Examples

/// Example: Different agent configurations for various use cases.
///
/// AgentConfiguration allows you to tune agent behavior:
/// - maxIterations: Limit reasoning loops
/// - timeout: Prevent runaway execution
/// - modelSettings: Control LLM behavior
public enum AgentConfigurationExamples {
    /// Fast configuration for simple queries
    public static var fast: AgentConfiguration {
        AgentConfiguration(
            maxIterations: 3,
            timeout: .seconds(15)
        )
    }

    /// Thorough configuration for complex reasoning
    public static var thorough: AgentConfiguration {
        AgentConfiguration(
            maxIterations: 10,
            timeout: .seconds(120)
        )
    }

    /// Creative configuration with higher temperature
    public static var creative: AgentConfiguration {
        AgentConfiguration(
            maxIterations: 5,
            timeout: .seconds(60),
            modelSettings: ModelSettings(temperature: 0.9)
        )
    }

    /// Precise configuration with low temperature
    public static var precise: AgentConfiguration {
        AgentConfiguration(
            maxIterations: 5,
            timeout: .seconds(60),
            modelSettings: ModelSettings(temperature: 0.1)
        )
    }
}

// MARK: - 7. Complete Agent Setup Example

/// Example: How to set up a complete agent with all features.
///
/// This demonstrates combining tools, memory, guardrails,
/// and configuration into a production-ready agent.
public enum PlaygroundExamples {
    /// Creates a fully-featured example agent.
    ///
    /// - Parameter provider: The inference provider to use
    /// - Returns: A configured ReActAgent ready to use
    ///
    /// Usage:
    /// ```swift
    /// let provider = OpenRouterProvider(apiKey: "your-key", model: .claude35Sonnet)
    /// let agent = PlaygroundExamples.createFullFeaturedAgent(provider: provider)
    /// let result = try await agent.run("What's the weather in Tokyo?")
    /// ```
    @MainActor
    public static func createFullFeaturedAgent(provider: any InferenceProvider) -> ReActAgent {
        ReActAgent.Builder()
            // Core configuration
            .inferenceProvider(provider)
            .instructions("""
            You are a helpful assistant with access to various tools.
            Always be polite, accurate, and concise in your responses.
            Use tools when necessary to provide accurate information.
            """)
            .configuration(AgentConfigurationExamples.thorough)

            // Add tools
            .addTool(WeatherLookupTool())
            .addTool(DateTimeTool())
            .addTool(StringTool())
            #if canImport(Darwin)
            .addTool(CalculatorTool())
            #endif

            // Add memory for conversation context
            .memory(ConversationMemory(maxMessages: 100))

            // Add guardrails for safety
            .inputGuardrails([ContentFilterGuardrail()])
            .outputGuardrails([PIIRedactionGuardrail()])

            // Build the agent
            .build()
    }

    /// Creates a minimal agent for simple tasks.
    ///
    /// - Parameter provider: The inference provider to use
    /// - Returns: A minimal ReActAgent
    @MainActor
    public static func createMinimalAgent(provider: any InferenceProvider) -> ReActAgent {
        ReActAgent.Builder()
            .inferenceProvider(provider)
            .instructions("You are a helpful assistant.")
            .build()
    }

    /// Demonstrates streaming agent responses.
    ///
    /// - Parameters:
    ///   - agent: The agent to use
    ///   - input: The user input
    ///
    /// Usage:
    /// ```swift
    /// try await PlaygroundExamples.demonstrateStreaming(
    ///     agent: agent,
    ///     input: "Explain quantum computing"
    /// )
    /// ```
    public static func demonstrateStreaming(agent: ReActAgent, input: String) async throws {
        print("Starting streaming for: \"\(input)\"")
        print(String(repeating: "-", count: 50))

        for try await event in agent.stream(input) {
            switch event {
            case .thinking(let thought):
                print("💭 Thinking: \(thought.prefix(80))...")

            case .toolCallStarted(let call):
                print("🔧 Using tool: \(call.toolName)")

            case .toolCallCompleted(_, let result):
                print("✅ Tool result: \(result.isSuccess ? "success" : "failed")")

            case .outputChunk(let text):
                print(text, terminator: "")

            case .completed(let result):
                let durationSeconds = Double(result.duration.components.seconds)
                print("\n" + String(repeating: "-", count: 50))
                print("✨ Completed in \(String(format: "%.2f", durationSeconds))s")

            case .failed(let error):
                print("\n❌ Error: \(error.localizedDescription)")

            default:
                break
            }
        }
    }

    /// Demonstrates multi-turn conversation with memory.
    ///
    /// - Parameters:
    ///   - agent: The agent to use
    ///   - messages: Array of user messages to process in sequence
    ///
    /// Usage:
    /// ```swift
    /// try await PlaygroundExamples.demonstrateConversation(
    ///     agent: agent,
    ///     messages: [
    ///         "My name is Alice",
    ///         "What's my name?",
    ///         "What time is it?"
    ///     ]
    /// )
    /// ```
    public static func demonstrateConversation(agent: ReActAgent, messages: [String]) async throws {
        print("Starting multi-turn conversation...")
        print(String(repeating: "=", count: 60))

        for (index, message) in messages.enumerated() {
            print("\n[\(index + 1)] User: \(message)")
            print(String(repeating: "-", count: 40))

            let result = try await agent.run(message)
            let durationSeconds = Double(result.duration.components.seconds)

            print("Agent: \(result.output)")
            print("(Duration: \(String(format: "%.2f", durationSeconds))s, Iterations: \(result.iterationCount))")
        }

        print("\n" + String(repeating: "=", count: 60))
        print("Conversation complete!")
    }
}

// MARK: - 8. Mock Provider Example

/// A mock inference provider for testing without external API calls.
///
/// Use this provider during development and testing.
///
/// Usage:
/// ```swift
/// let provider = PlaygroundMockProvider()
/// let agent = ReActAgent.Builder()
///     .inferenceProvider(provider)
///     .build()
/// ```
public struct PlaygroundMockProvider: InferenceProvider {
    private let responses: [String]

    public init(responses: [String] = ["This is a mock response from the AI."]) {
        self.responses = responses
    }

    public func generate(prompt: String, options: InferenceOptions) async throws -> String {
        // Simulate network delay
        try await Task.sleep(for: .milliseconds(100))

        return responses.randomElement() ?? "Mock response"
    }

    public func stream(prompt: String, options: InferenceOptions) -> AsyncThrowingStream<String, Error> {
        let response = responses.randomElement() ?? "Mock response"

        return AsyncThrowingStream { continuation in
            Task {
                // Stream character by character
                for char in response {
                    try await Task.sleep(for: .milliseconds(10))
                    continuation.yield(String(char))
                }
                continuation.finish()
            }
        }
    }

    public func generateWithToolCalls(
        prompt: String,
        tools: [ToolDefinition],
        options: InferenceOptions
    ) async throws -> InferenceResponse {
        // Simulate network delay
        try await Task.sleep(for: .milliseconds(100))

        let response = responses.randomElement() ?? "Mock response"
        return InferenceResponse(
            content: response,
            toolCalls: [],
            finishReason: .completed
        )
    }
}

// MARK: - Documentation

/*
 ============================================================================
 SwiftAgents Playground - Getting Started Guide
 ============================================================================

 Welcome to the SwiftAgents Playground! This file contains working examples
 of the framework's key features. Here's how to use them:

 ## 1. Setting Up an Agent

 First, create an inference provider. You can use OpenRouter or your own:

 ```swift
 // Option A: OpenRouter (requires API key)
 let provider = OpenRouterProvider(
     configuration: .init(apiKey: "your-key", model: .claude35Sonnet)
 )

 // Option B: Mock provider for testing
 let provider = PlaygroundMockProvider()
 ```

 ## 2. Creating Custom Tools

 Tools extend your agent's capabilities:

 ```swift
 // Use the pre-built WeatherLookupTool from this file
 let weatherTool = WeatherLookupTool()

 // Or create your own by conforming to the Tool protocol
 struct MyCustomTool: Tool {
     let name = "my_tool"
     let description = "Does something useful"
     let parameters: [ToolParameter] = [
         ToolParameter(name: "input", description: "The input", type: .string)
     ]

     mutating func execute(arguments: [String: SendableValue]) async throws -> SendableValue {
         // Your tool logic here
         return .string("Result")
     }
 }
 ```

 ## 3. Running an Agent

 ```swift
 let agent = PlaygroundExamples.createFullFeaturedAgent(provider: provider)

 // Single query
 let result = try await agent.run("What's 25 * 4?")
 print(result.output)

 // With streaming
 try await PlaygroundExamples.demonstrateStreaming(agent: agent, input: "Tell me a story")

 // Multi-turn conversation
 try await PlaygroundExamples.demonstrateConversation(agent: agent, messages: [
     "Hello, I'm learning SwiftAgents",
     "What can you help me with?",
     "Thanks!"
 ])
 ```

 ## 4. Adding Observability

 ```swift
 let hooks = PlaygroundRunHooks()
 let result = try await agent.run("Hello", hooks: hooks)

 // Review what happened
 for log in await hooks.getLogs() {
     print(log)
 }
 ```

 ## 5. Using Guardrails

 ```swift
 // Input guardrails run BEFORE the agent processes input
 let inputGuardrail = ContentFilterGuardrail(blockedPatterns: ["spam"])

 // Output guardrails run AFTER the agent generates a response
 let outputGuardrail = PIIRedactionGuardrail()

 let agent = ReActAgent.Builder()
     .inferenceProvider(provider)
     .inputGuardrails([inputGuardrail])
     .outputGuardrails([outputGuardrail])
     .build()
 ```

 ## 6. Configuration Options

 ```swift
 // Use preset configurations
 let fastConfig = AgentConfigurationExamples.fast
 let creativeConfig = AgentConfigurationExamples.creative

 // Or create custom
 let customConfig = AgentConfiguration(
     maxIterations: 8,
     timeout: .seconds(90),
     modelSettings: ModelSettings(temperature: 0.7)
 )
 ```

 ============================================================================
 For more examples, see the /docs folder and the test suite.
 ============================================================================
 */
