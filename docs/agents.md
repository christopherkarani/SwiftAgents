# Agents

## Overview

Agents are the core building blocks of the SwiftAgents framework. An agent is an autonomous entity that can reason about tasks, use tools, and maintain context across interactions. Unlike simple LLM wrappers, agents can make decisions, execute multi-step workflows, and adapt their behavior based on observations.

SwiftAgents provides three primary agent types, each implementing a different reasoning paradigm:

- **ReActAgent**: Interleaved reasoning and acting (Thought-Action-Observation loop)
- **ToolCallingAgent**: Direct tool invocation using structured LLM APIs
- **PlanAndExecuteAgent**: Explicit planning before execution with replanning on failure

All agents implement the `Agent` protocol and share common configuration options for tools, memory, guardrails, and observability.

## Agent Protocol

The `Agent` protocol defines the fundamental contract that all agent implementations must satisfy:

```swift
public protocol Agent: Sendable {
    /// Tools available to this agent
    nonisolated var tools: [any Tool] { get }

    /// Instructions defining agent behavior and role
    nonisolated var instructions: String { get }

    /// Configuration settings
    nonisolated var configuration: AgentConfiguration { get }

    /// Optional memory system for context management
    nonisolated var memory: (any Memory)? { get }

    /// Optional custom inference provider
    nonisolated var inferenceProvider: (any InferenceProvider)? { get }

    /// Optional tracer for observability
    nonisolated var tracer: (any Tracer)? { get }

    /// Input guardrails for validation
    nonisolated var inputGuardrails: [any InputGuardrail] { get }

    /// Output guardrails for validation
    nonisolated var outputGuardrails: [any OutputGuardrail] { get }

    /// Handoff configurations for multi-agent orchestration
    nonisolated var handoffs: [AnyHandoffConfiguration] { get }

    /// Execute and return result
    func run(_ input: String, session: (any Session)?, hooks: (any RunHooks)?) async throws -> AgentResult

    /// Stream execution events
    nonisolated func stream(_ input: String, session: (any Session)?, hooks: (any RunHooks)?) -> AsyncThrowingStream<AgentEvent, Error>

    /// Cancel ongoing execution
    func cancel() async

    /// Execute with detailed response tracking
    func runWithResponse(_ input: String, session: (any Session)?, hooks: (any RunHooks)?) async throws -> AgentResponse
}
```

### Default Implementations

The protocol provides sensible defaults through extensions:

```swift
public extension Agent {
    nonisolated var memory: (any Memory)? { nil }
    nonisolated var inferenceProvider: (any InferenceProvider)? { nil }
    nonisolated var tracer: (any Tracer)? { nil }
    nonisolated var inputGuardrails: [any InputGuardrail] { [] }
    nonisolated var outputGuardrails: [any OutputGuardrail] { [] }
    nonisolated var handoffs: [AnyHandoffConfiguration] { [] }
}
```

Convenience methods allow calling `run()` and `stream()` without optional parameters:

```swift
// All of these are valid
let result = try await agent.run("Hello")
let result = try await agent.run("Hello", hooks: myHooks)
let result = try await agent.run("Hello", session: mySession, hooks: myHooks)
```

## Agent Types

### ReActAgent

The ReActAgent implements the ReAct (Reasoning + Acting) paradigm, which interleaves reasoning steps with actions in a loop:

1. **Thought**: The agent reasons about the current state and decides what to do
2. **Action**: The agent calls a tool or provides a final answer
3. **Observation**: The tool result is observed and added to context
4. Repeat until a final answer is reached or max iterations exceeded

#### When to Use ReActAgent

- Tasks requiring step-by-step reasoning with intermediate observations
- Scenarios where the agent needs to adapt strategy based on tool results
- Complex problem-solving that benefits from explicit reasoning traces
- Debugging scenarios where you want to see the agent's thought process

#### Configuration Options

```swift
let agent = ReActAgent(
    tools: [CalculatorTool(), DateTimeTool()],
    instructions: "You are a helpful math assistant.",
    configuration: AgentConfiguration.default
        .maxIterations(10)
        .timeout(.seconds(60))
        .temperature(0.7),
    memory: ConversationMemory(),
    inferenceProvider: myProvider,
    inputGuardrails: [ContentFilterGuardrail()],
    outputGuardrails: [SafetyGuardrail()]
)
```

#### Code Example

```swift
// Create a ReActAgent with tools
let agent = ReActAgent(
    tools: [CalculatorTool(), DateTimeTool()],
    instructions: "You are a helpful assistant that can perform calculations and check dates."
)

// Execute the agent
let result = try await agent.run("What's 15% of 200, and what day is it today?")
print(result.output)

// Example reasoning trace:
// Thought: I need to calculate 15% of 200 and get today's date
// Action: calculator(expression: "0.15 * 200")
// Observation: 30
// Thought: Now I need to get today's date
// Action: datetime()
// Observation: 2024-01-15
// Final Answer: 15% of 200 is 30, and today is January 15, 2024.
```

### ToolCallingAgent

The ToolCallingAgent leverages the LLM's native tool calling capabilities via structured APIs (`generateWithToolCalls()`), providing more reliable and type-safe tool invocation compared to text parsing.

#### Execution Pattern

1. Build prompt with system instructions and conversation history
2. Call provider with tool definitions
3. If tool calls requested, execute each tool and add results to history
4. If no tool calls, return content as final answer
5. Repeat until done or max iterations reached

#### When to Use ToolCallingAgent

- When using models with native function calling support (OpenAI, Claude, etc.)
- For reliable tool invocation without text parsing
- When tool arguments need strict type validation
- Production scenarios requiring consistent tool execution

#### Code Example

```swift
// Create a ToolCallingAgent
let agent = ToolCallingAgent(
    tools: [WeatherTool(), CalculatorTool()],
    instructions: "You are a helpful assistant with access to tools."
)

// Execute the agent
let result = try await agent.run("What's the weather in Tokyo?")
print(result.output)
```

#### Using the Builder Pattern

```swift
let agent = ToolCallingAgent.Builder()
    .tools([WeatherTool(), CalculatorTool()])
    .instructions("You are a helpful assistant.")
    .configuration(.default.maxIterations(5))
    .inferenceProvider(OpenRouterProvider(apiKey: "..."))
    .build()
```

#### Using the DSL Syntax

```swift
let agent = ToolCallingAgent {
    Instructions("You are a helpful assistant.")

    Tools {
        WeatherTool()
        CalculatorTool()
    }

    Configuration(.default.maxIterations(5))
}
```

### PlanAndExecuteAgent

The PlanAndExecuteAgent separates planning from execution, creating an explicit multi-step plan before taking action. This approach excels at complex tasks that benefit from upfront planning and error recovery.

#### Three-Phase Paradigm

1. **Plan**: Generate a structured multi-step plan to achieve the goal
2. **Execute**: Execute each step in order, using tools as needed
3. **Replan**: If a step fails, generate a revised plan and continue

#### When to Use PlanAndExecuteAgent

- Complex multi-step tasks requiring coordination
- Tasks where upfront planning improves success rate
- Scenarios requiring error recovery and replanning
- Research or analysis tasks with multiple information sources
- Tasks with step dependencies (step 2 needs result from step 1)

#### Plan Structure

The agent creates structured execution plans:

```swift
public struct PlanStep: Sendable, Identifiable {
    public let id: UUID
    public let stepNumber: Int
    public let stepDescription: String
    public let toolName: String?
    public let toolArguments: [String: SendableValue]
    public let dependsOn: [UUID]
    public var status: StepStatus
    public var result: String?
    public var error: String?
}

public struct ExecutionPlan: Sendable {
    public var steps: [PlanStep]
    public let goal: String
    public let createdAt: Date
    public var revisionCount: Int

    public var isComplete: Bool
    public var hasFailed: Bool
    public var nextExecutableStep: PlanStep?
}
```

#### Code Example

```swift
// Create a PlanAndExecuteAgent
let agent = PlanAndExecuteAgent(
    tools: [WebSearchTool(), CalculatorTool()],
    instructions: "You are a research assistant.",
    maxReplanAttempts: 3
)

// Execute with a complex task
let result = try await agent.run(
    "Find the population of Tokyo and calculate what 10% of it would be"
)

// The agent will:
// 1. Create a plan: [Search for Tokyo population] -> [Calculate 10%]
// 2. Execute step 1: Search and get 13.96 million
// 3. Execute step 2: Calculate 10% = 1.396 million
// 4. Synthesize final answer
```

#### Builder Pattern

```swift
let agent = PlanAndExecuteAgent.Builder()
    .tools([CalculatorTool(), DateTimeTool()])
    .instructions("You are a research assistant.")
    .maxReplanAttempts(5)
    .configuration(.default.maxIterations(15))
    .build()
```

## Building Agents

### Using Builders

All agent types provide a fluent Builder pattern for construction:

```swift
let agent = ReActAgent.Builder()
    .tools([CalculatorTool()])
    .addTool(DateTimeTool())           // Add individual tools
    .withBuiltInTools()                 // Add all built-in tools
    .instructions("You are a math assistant.")
    .configuration(.default.maxIterations(5))
    .memory(ConversationMemory())
    .inferenceProvider(myProvider)
    .tracer(OSLogTracer())
    .inputGuardrails([ContentFilterGuardrail()])
    .addInputGuardrail(LengthGuardrail())
    .outputGuardrails([SafetyGuardrail()])
    .addOutputGuardrail(FormatGuardrail())
    .guardrailRunnerConfiguration(.default)
    .handoffs([handoffToSpecialist])
    .build()
```

Builder methods return new instances (value semantics) for Swift 6 concurrency safety:

```swift
// Each method returns a new Builder instance
let baseBuilder = ReActAgent.Builder()
    .instructions("Base instructions")

let mathAgent = baseBuilder
    .tools([CalculatorTool()])
    .build()

let dateAgent = baseBuilder
    .tools([DateTimeTool()])
    .build()
```

### Using DSL Syntax

ToolCallingAgent and PlanAndExecuteAgent support declarative DSL syntax:

```swift
let agent = ToolCallingAgent {
    Instructions("You are a helpful assistant.")

    Tools {
        WeatherTool()
        CalculatorTool()
        DateTimeTool()
    }

    Configuration(.default
        .maxIterations(10)
        .temperature(0.7))

    Memory(ConversationMemory())

    InferenceProvider(myProvider)
}
```

### Direct Initialization

For simple cases, use direct initialization:

```swift
let agent = ReActAgent(
    tools: [CalculatorTool()],
    instructions: "You are a calculator."
)
```

## Agent Configuration

### AgentConfiguration

The `AgentConfiguration` struct controls agent behavior:

```swift
let config = AgentConfiguration.default
    .name("MathAssistant")           // Agent name for identification
    .maxIterations(10)                // Maximum reasoning/tool loops
    .timeout(.seconds(60))            // Execution timeout
    .temperature(0.7)                 // LLM temperature (0.0-2.0)
    .maxTokens(2000)                  // Maximum response tokens
    .stopOnToolError(false)           // Continue on tool failure?
    .sessionHistoryLimit(50)          // Max session messages to load
```

### Instructions

Instructions define the agent's persona and behavior:

```swift
let agent = ReActAgent(
    tools: tools,
    instructions: """
    You are a helpful research assistant specializing in data analysis.

    Guidelines:
    - Always verify information from multiple sources
    - Provide citations when possible
    - If uncertain, acknowledge limitations
    - Format responses clearly with headers and lists
    """
)
```

### Tools

Tools extend agent capabilities. See the Tools documentation for details:

```swift
let agent = ToolCallingAgent(
    tools: [
        CalculatorTool(),
        DateTimeTool(),
        WebSearchTool(),
        CustomTool()
    ],
    instructions: "You have access to calculation, date, and search tools."
)
```

### Memory

Memory systems provide context persistence:

```swift
// Conversation memory (short-term)
let agent = ReActAgent(
    tools: tools,
    instructions: instructions,
    memory: ConversationMemory(maxTokens: 4000)
)

// Vector memory (long-term semantic)
let agent = ReActAgent(
    tools: tools,
    instructions: instructions,
    memory: VectorMemory(embeddingProvider: myEmbedder)
)
```

### Guardrails

Guardrails validate inputs and outputs:

```swift
let agent = ToolCallingAgent(
    tools: tools,
    instructions: instructions,
    inputGuardrails: [
        ContentFilterGuardrail(),    // Filter inappropriate input
        LengthGuardrail(max: 1000)   // Limit input length
    ],
    outputGuardrails: [
        SafetyGuardrail(),           // Ensure safe output
        FormatGuardrail()            // Validate output format
    ],
    guardrailRunnerConfiguration: GuardrailRunnerConfiguration.default
)
```

If a guardrail triggers its tripwire, execution throws `GuardrailError`:

```swift
do {
    let result = try await agent.run(input)
} catch let error as GuardrailError {
    switch error {
    case .inputTripwireTriggered(let result):
        print("Input rejected: \(result.message)")
    case .outputTripwireTriggered(let result):
        print("Output rejected: \(result.message)")
    }
}
```

## Agent Execution

### run() vs stream()

Agents support both synchronous and streaming execution:

#### run() - Complete Execution

```swift
// Wait for complete result
let result = try await agent.run("What's 2+2?")
print(result.output)           // "4"
print(result.toolCalls)        // Tool calls made
print(result.toolResults)      // Results from tools
print(result.iterationCount)   // Number of reasoning loops
print(result.tokenUsage)       // Token statistics
```

#### stream() - Event Streaming

```swift
// Stream events as they occur
for try await event in agent.stream("What's 2+2?") {
    switch event {
    case .started(let input):
        print("Started with: \(input)")
    case .thinking(let thought):
        print("Thinking: \(thought)")
    case .toolCall(let name, let args):
        print("Calling tool: \(name)")
    case .toolResult(let result):
        print("Tool result: \(result)")
    case .token(let text):
        print(text, terminator: "")
    case .completed(let result):
        print("Completed: \(result.output)")
    case .failed(let error):
        print("Failed: \(error)")
    }
}
```

### runWithResponse() - Detailed Response

For detailed tracking with unique response IDs:

```swift
let response = try await agent.runWithResponse("What's 2+2?")
print(response.responseId)      // Unique ID for this response
print(response.output)          // The answer
print(response.agentName)       // Which agent responded
print(response.timestamp)       // When it completed
print(response.toolCalls)       // Detailed tool call records
print(response.usage)           // Token usage statistics
print(response.iterationCount)  // Reasoning iterations
```

### Result Handling

#### AgentResult

```swift
let result = try await agent.run(input)

// Core output
let answer = result.output

// Tool execution details
for call in result.toolCalls {
    print("Called: \(call.toolName)")
    print("Args: \(call.arguments)")
    print("At: \(call.timestamp)")
}

for toolResult in result.toolResults {
    print("Result: \(toolResult.output)")
    print("Success: \(toolResult.isSuccess)")
    print("Duration: \(toolResult.duration)")
}

// Execution metadata
print("Iterations: \(result.iterationCount)")
print("Duration: \(result.duration)")
print("Tokens: \(result.tokenUsage)")
```

#### Error Handling

```swift
do {
    let result = try await agent.run(input)
} catch AgentError.invalidInput(let reason) {
    print("Invalid input: \(reason)")
} catch AgentError.maxIterationsExceeded(let count) {
    print("Exceeded \(count) iterations")
} catch AgentError.timeout(let duration) {
    print("Timed out after \(duration)")
} catch AgentError.toolExecutionFailed(let tool, let error) {
    print("Tool \(tool) failed: \(error)")
} catch AgentError.inferenceProviderUnavailable(let reason) {
    print("No inference provider: \(reason)")
} catch AgentError.cancelled {
    print("Execution was cancelled")
} catch {
    print("Unexpected error: \(error)")
}
```

### Cancellation

Agents support cooperative cancellation:

```swift
let agent = ReActAgent(tools: tools, instructions: instructions)

// Start execution
let task = Task {
    try await agent.run("Complex long-running task...")
}

// Cancel if needed
await agent.cancel()

// Or cancel the task
task.cancel()
```

### Session Management

Sessions persist conversation history across multiple interactions:

```swift
let session = InMemorySession()

// First interaction
let result1 = try await agent.run("My name is Alice", session: session)

// Second interaction - agent remembers context
let result2 = try await agent.run("What's my name?", session: session)
// result2.output will reference "Alice"
```

### Run Hooks

Hooks provide lifecycle callbacks for monitoring:

```swift
class MyHooks: RunHooks {
    func onAgentStart(context: Any?, agent: any Agent, input: String) async {
        print("Agent starting with: \(input)")
    }

    func onAgentEnd(context: Any?, agent: any Agent, result: AgentResult) async {
        print("Agent completed: \(result.output)")
    }

    func onLLMStart(context: Any?, agent: any Agent, systemPrompt: String, inputMessages: [MemoryMessage]) async {
        print("LLM call starting")
    }

    func onLLMEnd(context: Any?, agent: any Agent, response: String, usage: InferenceResponse.TokenUsage?) async {
        print("LLM responded")
    }

    func onToolStart(context: Any?, agent: any Agent, tool: any Tool, arguments: [String: SendableValue]) async {
        print("Calling tool: \(tool.name)")
    }

    func onToolEnd(context: Any?, agent: any Agent, tool: any Tool, result: SendableValue) async {
        print("Tool result: \(result)")
    }

    func onError(context: Any?, agent: any Agent, error: Error) async {
        print("Error: \(error)")
    }
}

let result = try await agent.run(input, hooks: MyHooks())
```

## Best Practices

### Choosing the Right Agent Type

| Scenario | Recommended Agent |
|----------|------------------|
| Simple tool calls | ToolCallingAgent |
| Step-by-step reasoning | ReActAgent |
| Complex multi-step tasks | PlanAndExecuteAgent |
| Debugging/tracing needed | ReActAgent |
| Production reliability | ToolCallingAgent |
| Error recovery important | PlanAndExecuteAgent |

### Configuration Guidelines

1. **Set appropriate timeouts**: Prevent runaway executions
   ```swift
   .timeout(.seconds(30))
   ```

2. **Limit iterations**: Prevent infinite loops
   ```swift
   .maxIterations(10)
   ```

3. **Use guardrails**: Validate inputs and outputs
   ```swift
   inputGuardrails: [ContentFilterGuardrail()]
   ```

4. **Configure memory appropriately**: Balance context vs token limits
   ```swift
   memory: ConversationMemory(maxTokens: 4000)
   ```

### Performance Tips

1. **Reuse agent instances**: Agents are thread-safe actors
   ```swift
   let agent = ReActAgent(...)  // Create once
   // Reuse for multiple calls
   ```

2. **Use streaming for long tasks**: Get incremental feedback
   ```swift
   for try await event in agent.stream(input) { ... }
   ```

3. **Set stopOnToolError appropriately**:
   - `true`: Fail fast on tool errors
   - `false`: Continue and let agent adapt

### Error Handling

1. **Handle specific errors**:
   ```swift
   do {
       let result = try await agent.run(input)
   } catch AgentError.maxIterationsExceeded {
       // Simplify the task or increase limit
   } catch AgentError.timeout {
       // Task too complex or provider slow
   }
   ```

2. **Use guardrails for validation**: Catch issues early
3. **Implement retry logic for transient failures**
4. **Log errors with context for debugging**

### Testing Agents

1. **Use mock inference providers**: Avoid real API calls in tests
2. **Test with deterministic temperature**: `temperature: 0.0`
3. **Verify tool calls and results**: Check execution flow
4. **Test error conditions**: Ensure graceful handling
5. **Test cancellation**: Verify cleanup occurs
