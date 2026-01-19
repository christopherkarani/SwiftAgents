# Multi-Agent Orchestration

## Overview

SwiftAgents provides a comprehensive orchestration layer for coordinating multiple specialized agents. The framework supports four primary orchestration patterns:

- **SupervisorAgent**: Intelligent routing to specialized sub-agents
- **SequentialChain**: Pipeline execution with output passing between agents
- **ParallelGroup**: Concurrent execution with result aggregation
- **AgentRouter**: Deterministic condition-based routing

Each pattern implements the `Agent` protocol, enabling composition and nesting of orchestration strategies.

## Orchestration Patterns

### SupervisorAgent

`SupervisorAgent` implements the supervisor pattern for multi-agent orchestration. It maintains a registry of specialized agents and uses a configurable routing strategy to determine which agent should handle each request.

#### Key Components

**AgentDescription**: Metadata about an agent's capabilities for routing decisions.

```swift
let description = AgentDescription(
    name: "calculator",
    description: "Performs mathematical calculations",
    capabilities: ["arithmetic", "algebra", "trigonometry"],
    keywords: ["calculate", "math", "compute", "sum", "multiply"]
)
```

**RoutingStrategy**: Protocol for agent selection strategies.

```swift
public protocol RoutingStrategy: Sendable {
    func selectAgent(
        for input: String,
        from agents: [AgentDescription],
        context: AgentContext?
    ) async throws -> RoutingDecision
}
```

**RoutingDecision**: Result of routing containing the selected agent, confidence level, and reasoning.

```swift
let decision = RoutingDecision(
    selectedAgentName: "weather_agent",
    confidence: 0.95,
    reasoning: "Input requests weather information for a location"
)
```

#### Routing Strategies

**LLMRoutingStrategy**: Uses an LLM to intelligently analyze input and select the best agent.

```swift
let strategy = LLMRoutingStrategy(
    inferenceProvider: myProvider,
    shouldFallbackToKeyword: true,
    temperature: 0.3
)
```

Features:
- LLM-based intelligent routing
- Automatic fallback to keyword matching if LLM fails
- Configurable temperature for determinism
- Builds detailed prompts with agent descriptions

**KeywordRoutingStrategy**: Fast routing using keyword matching without LLM calls.

```swift
let strategy = KeywordRoutingStrategy(
    isCaseSensitive: false,
    minimumConfidence: 0.1
)
```

Features:
- No LLM required
- Scores based on keyword, capability, and name matches
- Configurable case sensitivity
- Minimum confidence threshold

#### Complete Example

```swift
// Define specialized agents
let calcAgent = CalculatorAgent()
let weatherAgent = WeatherAgent()
let generalAgent = GeneralAssistantAgent()

// Create agent descriptions
let calcDescription = AgentDescription(
    name: "calculator",
    description: "Performs mathematical calculations",
    capabilities: ["arithmetic", "algebra"],
    keywords: ["calculate", "math", "compute", "sum", "add", "multiply"]
)

let weatherDescription = AgentDescription(
    name: "weather",
    description: "Provides weather information and forecasts",
    capabilities: ["current_weather", "forecasts"],
    keywords: ["weather", "temperature", "forecast", "rain", "sunny"]
)

// Create supervisor with LLM routing
let supervisor = SupervisorAgent(
    agents: [
        (name: "calculator", agent: calcAgent, description: calcDescription),
        (name: "weather", agent: weatherAgent, description: weatherDescription)
    ],
    routingStrategy: LLMRoutingStrategy(inferenceProvider: myProvider),
    fallbackAgent: generalAgent,
    enableContextTracking: true
)

// Execute - supervisor routes to appropriate agent
let result = try await supervisor.run("What's 2 + 2?")
// Routes to calculator agent

let weatherResult = try await supervisor.run("What's the weather in Tokyo?")
// Routes to weather agent
```

#### Direct Agent Execution

Bypass routing to execute a specific agent:

```swift
let result = try await supervisor.executeAgent(
    named: "calculator",
    input: "Calculate 15 * 7",
    session: mySession
)
```

---

### SequentialChain

`SequentialChain` executes agents in sequence, passing the output of each agent as input to the next. This enables pipeline-style orchestration where each agent builds on the previous agent's work.

#### Custom Operator

The `-->` operator provides a fluent syntax for chaining agents:

```swift
let chain = researchAgent --> summaryAgent --> validatorAgent
let result = try await chain.run("Analyze quarterly results")
```

#### Output Transformers

Control how results flow between agents using `OutputTransformer`:

```swift
public struct OutputTransformer: Sendable {
    // Predefined transformers
    static let passthrough: OutputTransformer  // Uses output directly
    static let withMetadata: OutputTransformer // Includes tool calls and iteration count

    // Custom transformer
    init(_ transform: @escaping @Sendable (AgentResult) -> String)
}
```

#### Configuration

```swift
let chain = SequentialChain(
    agents: [agentA, agentB, agentC],
    configuration: .default,
    transformers: [:],  // Optional: customize output between agents
    handoffs: []        // Optional: handoff configurations
)

// Apply transformers after specific agents
let configuredChain = chain
    .withTransformer(after: 0, .withMetadata)
    .withTransformer(after: 1, .passthrough)
```

#### Complete Example

```swift
// Create specialized agents for a document processing pipeline
let extractorAgent = DataExtractorAgent()
let analyzerAgent = AnalysisAgent()
let reporterAgent = ReportGeneratorAgent()

// Build the chain using the --> operator
let pipeline = extractorAgent --> analyzerAgent --> reporterAgent

// Or use the initializer for more control
let configuredPipeline = SequentialChain(
    agents: [extractorAgent, analyzerAgent, reporterAgent],
    transformers: [
        0: .withMetadata,  // Include metadata after extraction
        1: OutputTransformer { result in
            // Custom transformation: add analysis summary
            "Analysis complete.\n\(result.output)"
        }
    ]
)

// Execute the pipeline
let result = try await pipeline.run("Process this document: ...")

// Stream events from the pipeline
for try await event in pipeline.stream("Process document") {
    switch event {
    case .started(let input):
        print("Pipeline started with: \(input)")
    case .completed(let result):
        print("Pipeline complete: \(result.output)")
    case .failed(let error):
        print("Pipeline failed: \(error)")
    default:
        break
    }
}
```

#### Cancellation

```swift
// Propagates cancellation to all agents in the chain
await pipeline.cancel()
```

---

### ParallelGroup

`ParallelGroup` executes multiple agents concurrently on the same input and merges their results using a configurable strategy.

#### Features

- Concurrent execution using structured concurrency
- Configurable concurrency limits
- Multiple merge strategies
- Error handling with continue-on-error support
- Cancellation support

#### Merge Strategies

**Concatenate**: Joins outputs from all agents.

```swift
let strategy = MergeStrategies.Concatenate(
    separator: "\n\n",
    shouldIncludeAgentNames: true
)
// Result:
// Agent1:
// Output from agent1
//
// Agent2:
// Output from agent2
```

**First**: Returns the first result (alphabetically by agent name).

```swift
let strategy = MergeStrategies.First()
```

**Longest**: Returns the result with the longest output.

```swift
let strategy = MergeStrategies.Longest()
```

**Structured**: Returns a JSON object with all agent outputs.

```swift
let strategy = MergeStrategies.Structured()
// Result:
// {
//   "agent1": "Output from agent1",
//   "agent2": "Output from agent2"
// }
```

**Custom**: User-provided merge function.

```swift
let strategy = MergeStrategies.Custom { results in
    let output = results.values.map(\.output).joined(separator: " | ")
    return AgentResult(output: output)
}
```

#### Complete Example

```swift
// Create agents for parallel analysis
let summarizerAgent = SummarizerAgent()
let translatorAgent = TranslatorAgent()
let sentimentAgent = SentimentAnalyzerAgent()

// Create parallel group with named agents
let analysisGroup = ParallelGroup(
    agents: [
        ("summarizer", summarizerAgent),
        ("translator", translatorAgent),
        ("sentiment", sentimentAgent)
    ],
    mergeStrategy: MergeStrategies.Concatenate(shouldIncludeAgentNames: true),
    shouldContinueOnError: true,  // Continue if some agents fail
    maxConcurrency: 2             // Limit concurrent executions
)

// Or use unnamed agents (auto-named as "agent_0", "agent_1", etc.)
let simpleGroup = ParallelGroup(
    agents: [summarizerAgent, translatorAgent],
    mergeStrategy: MergeStrategies.Longest()
)

// Execute parallel analysis
let result = try await analysisGroup.run("Analyze this text content...")

// Access merged metadata
if case .int(let count) = result.metadata["agent_count"] {
    print("Results from \(count) agents")
}
```

#### Error Handling

```swift
// With shouldContinueOnError: false (default)
// First agent error stops execution and throws

// With shouldContinueOnError: true
// Continues execution, only throws if ALL agents fail
let group = ParallelGroup(
    agents: agents,
    shouldContinueOnError: true
)

do {
    let result = try await group.run(input)
} catch let error as OrchestrationError {
    switch error {
    case .allAgentsFailed(let errors):
        print("All agents failed: \(errors)")
    default:
        break
    }
}
```

---

### AgentRouter

`AgentRouter` implements deterministic, condition-based routing without requiring LLM calls. Routes are evaluated in order and the first matching route handles the request.

#### Route Conditions

Built-in conditions:

```swift
// Always/never match
RouteCondition.always
RouteCondition.never

// String matching
RouteCondition.contains("weather", isCaseSensitive: false)
RouteCondition.startsWith("calculate")
RouteCondition.endsWith("?")
RouteCondition.matches(pattern: #"\d{3}-\d{4}"#)

// Length constraints
RouteCondition.lengthInRange(10...100)

// Context-based
RouteCondition.contextHas(key: "user_id")
```

#### Condition Combinators

Combine conditions using logical operators:

```swift
// AND: both must match
let condition = RouteCondition.contains("weather")
    .and(.lengthInRange(5...100))

// OR: either can match
let condition = RouteCondition.contains("help")
    .or(.contains("support"))

// NOT: negation
let condition = RouteCondition.contains("admin").not
```

#### Route Definition

```swift
let route = Route(
    condition: .contains("weather").and(.lengthInRange(5...100)),
    agent: weatherAgent,
    name: "WeatherRoute"  // Optional, for debugging
)
```

#### Result Builder Syntax

Use the `@RouteBuilder` DSL for declarative route definitions:

```swift
let router = AgentRouter {
    Route(
        condition: .contains("weather"),
        agent: weatherAgent,
        name: "WeatherRoute"
    )
    Route(
        condition: .contains("news"),
        agent: newsAgent,
        name: "NewsRoute"
    )
    Route(
        condition: .matches(pattern: #"^\d+\s*[+\-*/]\s*\d+"#),
        agent: calculatorAgent,
        name: "CalculatorRoute"
    )
} fallbackAgent: generalAgent
```

#### Complete Example

```swift
// Define specialized agents
let weatherAgent = WeatherAgent()
let newsAgent = NewsAgent()
let calculatorAgent = CalculatorAgent()
let fallbackAgent = GeneralAssistantAgent()

// Create router with condition-based routing
let router = AgentRouter(
    routes: [
        Route(
            condition: .contains("weather")
                .or(.contains("temperature"))
                .or(.contains("forecast")),
            agent: weatherAgent,
            name: "WeatherRoute"
        ),
        Route(
            condition: .contains("news")
                .or(.contains("headlines")),
            agent: newsAgent,
            name: "NewsRoute"
        ),
        Route(
            condition: .matches(pattern: #"\d+\s*[+\-*/]\s*\d+"#)
                .or(.startsWith("calculate")),
            agent: calculatorAgent,
            name: "CalculatorRoute"
        )
    ],
    fallbackAgent: fallbackAgent
)

// Execute - router evaluates conditions in order
let result = try await router.run("What's the weather today?")
// Matches WeatherRoute, executes weatherAgent

// Routing metadata is included in the result
if case .string(let route) = result.metadata["router.matched_route"] {
    print("Matched route: \(route)")
}
```

---

## Handoffs

Handoffs enable explicit agent-to-agent transfers with context propagation. The handoff system provides fine-grained control over how execution transfers between agents.

### HandoffRequest

Encapsulates all information needed for a handoff:

```swift
let request = HandoffRequest(
    sourceAgentName: "planner",
    targetAgentName: "executor",
    input: "Execute step 1: Fetch data from API",
    reason: "Planning complete, ready to execute",
    context: [
        "plan_id": .string("plan-123"),
        "step": .int(1),
        "total_steps": .int(5)
    ]
)
```

### HandoffResult

Captures the outcome of a handoff:

```swift
let result = try await coordinator.executeHandoff(request, context: context)
print("Target: \(result.targetAgentName)")
print("Output: \(result.result.output)")
print("Context transferred: \(result.transferredContext)")
print("Timestamp: \(result.timestamp)")
```

### HandoffReceiver Protocol

Agents can implement `HandoffReceiver` for specialized handoff handling:

```swift
struct ExecutorAgent: Agent, HandoffReceiver {
    let tools: [any AnyJSONTool] = []
    let instructions = "Execute planned tasks"
    let configuration = AgentConfiguration.default

    func run(_ input: String, session: (any Session)?, hooks: (any RunHooks)?) async throws -> AgentResult {
        // Standard execution
        return AgentResult(output: "Executed: \(input)")
    }

    func stream(_ input: String, session: (any Session)?, hooks: (any RunHooks)?) -> AsyncThrowingStream<AgentEvent, Error> {
        StreamHelper.makeStream { continuation in
            continuation.finish()
        }
    }

    func cancel() async {}

    // Custom handoff handling (optional - default implementation exists)
    func handleHandoff(
        _ request: HandoffRequest,
        context: AgentContext
    ) async throws -> AgentResult {
        // Access handoff-specific context
        let planId = request.context["plan_id"]?.stringValue ?? "unknown"

        // Merge handoff context
        for (key, value) in request.context {
            await context.set(key, value: value)
        }

        // Execute with awareness of handoff source
        return try await run("Plan \(planId): \(request.input)")
    }
}
```

### HandoffCoordinator

Manages agent registration and handoff execution:

```swift
let coordinator = HandoffCoordinator()

// Register agents
await coordinator.register(plannerAgent, as: "planner")
await coordinator.register(executorAgent, as: "executor")
await coordinator.register(validatorAgent, as: "validator")

// Check registered agents
let agents = await coordinator.registeredAgents
// ["planner", "executor", "validator"]

// Execute handoff
let request = HandoffRequest(
    sourceAgentName: "planner",
    targetAgentName: "executor",
    input: "Execute the plan",
    context: ["plan_id": .string("123")]
)

let context = AgentContext(input: "Initial input")
let result = try await coordinator.executeHandoff(request, context: context)
```

### Handoff Configuration

Configure handoffs with callbacks for advanced control:

```swift
// Create handoff configuration
let config = HandoffConfiguration(
    targetAgent: executorAgent,
    onHandoff: { context, data in
        Log.orchestration.info(
            "Handoff: \(data.sourceAgentName) -> \(data.targetAgentName)"
        )
    },
    inputFilter: { data in
        // Transform input before handoff
        var modified = data
        modified.input = "PRIORITY: \(data.input)"
        return modified
    },
    isEnabled: { context, agent in
        // Conditionally enable/disable handoff
        await context.get("ready")?.boolValue ?? false
    }
)

// Execute with configuration
let result = try await coordinator.executeHandoff(
    request,
    context: context,
    configuration: AnyHandoffConfiguration(config),
    hooks: myHooks
)
```

---

## Building Orchestrations

### Using Builders and DSL Operators

SwiftAgents provides multiple ways to construct orchestrations:

#### Sequential Chain Operator

```swift
// Simple chaining
let pipeline = agentA --> agentB --> agentC

// With transformers
let configured = (agentA --> agentB --> agentC)
    .withTransformer(after: 0, .withMetadata)
    .withTransformer(after: 1, .passthrough)
```

#### Router Result Builder

```swift
let router = AgentRouter {
    Route(condition: .contains("weather"), agent: weatherAgent)
    Route(condition: .contains("news"), agent: newsAgent)

    // Conditional routes
    if includeDebugRoute {
        Route(condition: .contains("debug"), agent: debugAgent)
    }
} fallbackAgent: fallbackAgent
```

#### Composing Orchestrations

Orchestrators implement `Agent`, enabling composition:

```swift
// Parallel group within a sequential chain
let analysisGroup = ParallelGroup(
    agents: [sentimentAgent, summaryAgent],
    mergeStrategy: MergeStrategies.Concatenate()
)

let fullPipeline = extractorAgent --> analysisGroup --> reporterAgent

// Router with nested chains
let complexRouter = AgentRouter {
    Route(
        condition: .contains("analyze"),
        agent: analysisGroup
    )
    Route(
        condition: .contains("process"),
        agent: extractorAgent --> transformerAgent
    )
}
```

---

## Error Handling

### OrchestrationError

Orchestration-specific errors:

```swift
public enum OrchestrationError: Error {
    case noAgentsConfigured
    case agentNotFound(name: String)
    case routingFailed(reason: String)
    case allAgentsFailed(errors: [String])
    case mergeStrategyFailed(reason: String)
    case handoffSkipped(from: String, to: String, reason: String)
}
```

### Handling Errors

```swift
do {
    let result = try await supervisor.run(input)
} catch let error as OrchestrationError {
    switch error {
    case .routingFailed(let reason):
        print("Routing failed: \(reason)")
        // Use fallback or retry with different input

    case .agentNotFound(let name):
        print("Agent '\(name)' not registered")

    case .allAgentsFailed(let errors):
        print("All parallel agents failed:")
        for error in errors {
            print("  - \(error)")
        }

    case .mergeStrategyFailed(let reason):
        print("Failed to merge results: \(reason)")

    case .handoffSkipped(let from, let to, let reason):
        print("Handoff \(from) -> \(to) skipped: \(reason)")

    case .noAgentsConfigured:
        print("No agents configured in orchestrator")
    }
} catch let error as AgentError {
    // Handle agent-level errors
    switch error {
    case .cancelled:
        print("Operation was cancelled")
    case .invalidInput(let reason):
        print("Invalid input: \(reason)")
    default:
        print("Agent error: \(error)")
    }
}
```

### Fallback Strategies

```swift
// SupervisorAgent with fallback
let supervisor = SupervisorAgent(
    agents: specializedAgents,
    routingStrategy: LLMRoutingStrategy(
        inferenceProvider: provider,
        shouldFallbackToKeyword: true  // Falls back if LLM fails
    ),
    fallbackAgent: generalAgent  // Used if routing fails completely
)

// AgentRouter with fallback
let router = AgentRouter(
    routes: routes,
    fallbackAgent: generalAgent  // Used if no route matches
)

// ParallelGroup with continue-on-error
let group = ParallelGroup(
    agents: agents,
    shouldContinueOnError: true  // Continues even if some agents fail
)
```

---

## Best Practices

### 1. Choose the Right Pattern

| Pattern | Use When |
|---------|----------|
| SupervisorAgent | Need intelligent routing based on input semantics |
| SequentialChain | Processing requires multiple steps in order |
| ParallelGroup | Tasks can be performed independently |
| AgentRouter | Routing rules are deterministic and known |

### 2. Design Agent Descriptions Carefully

For `SupervisorAgent`, well-crafted descriptions improve routing accuracy:

```swift
// Good: Specific, with relevant keywords
let description = AgentDescription(
    name: "financial_analyst",
    description: "Analyzes financial data, calculates metrics, and generates reports",
    capabilities: ["revenue_analysis", "cost_breakdown", "trend_forecasting"],
    keywords: ["revenue", "profit", "margin", "quarterly", "fiscal", "budget"]
)

// Avoid: Vague descriptions
let description = AgentDescription(
    name: "analyst",
    description: "Analyzes things",
    capabilities: [],
    keywords: []
)
```

### 3. Use Output Transformers Wisely

Keep transformations simple and focused:

```swift
// Good: Clear, focused transformation
let summaryTransformer = OutputTransformer { result in
    "Summary: \(result.output.prefix(200))..."
}

// Good: Add context for next agent
let contextTransformer = OutputTransformer { result in
    """
    Previous analysis:
    \(result.output)

    Please continue with the next step.
    """
}
```

### 4. Handle Partial Failures in Parallel Execution

```swift
let group = ParallelGroup(
    agents: agents,
    mergeStrategy: MergeStrategies.Concatenate(shouldIncludeAgentNames: true),
    shouldContinueOnError: true
)

let result = try await group.run(input)

// Check which agents succeeded via metadata
for (key, value) in result.metadata {
    if key.hasSuffix(".output") {
        print("Agent result: \(key) = \(value)")
    }
}
```

### 5. Limit Concurrency for Resource-Intensive Agents

```swift
// Limit concurrent LLM calls
let group = ParallelGroup(
    agents: llmAgents,
    maxConcurrency: 3  // Prevent rate limiting
)
```

### 6. Use Handoff Context for State Transfer

```swift
let request = HandoffRequest(
    sourceAgentName: "planner",
    targetAgentName: "executor",
    input: "Execute task",
    context: [
        "session_id": .string(sessionId),
        "user_preferences": .dictionary(preferences),
        "previous_results": .array(results.map { .string($0) })
    ]
)
```

### 7. Implement Cancellation Support

All orchestrators support cancellation:

```swift
let task = Task {
    try await supervisor.run(input)
}

// Cancel if needed
await supervisor.cancel()
task.cancel()
```

### 8. Monitor Routing Decisions

Access routing metadata for debugging and analytics:

```swift
let result = try await supervisor.run(input)

if case .string(let agent) = result.metadata["selected_agent"] {
    print("Routed to: \(agent)")
}

if case .double(let confidence) = result.metadata["routing_confidence"] {
    print("Confidence: \(confidence)")
}

if case .string(let reasoning) = result.metadata["routing_reasoning"] {
    print("Reasoning: \(reasoning)")
}
```

### 9. Compose for Complex Workflows

```swift
// Build modular orchestrations
let dataPrep = extractorAgent --> cleanerAgent --> validatorAgent
let analysis = ParallelGroup(agents: [statisticsAgent, mlAgent, heuristicsAgent])
let reporting = summaryAgent --> formatterAgent

// Compose into full workflow
let workflow = dataPrep --> analysis --> reporting
```

### 10. Test Orchestrations Thoroughly

```swift
// Test routing decisions
func testSupervisorRouting() async throws {
    let result = try await supervisor.run("Calculate 2 + 2")

    // Verify correct agent was selected
    if case .string(let agent) = result.metadata["selected_agent"] {
        XCTAssertEqual(agent, "calculator")
    }
}

// Test sequential chains
func testChainExecution() async throws {
    let chain = mockAgentA --> mockAgentB
    let result = try await chain.run("input")

    // Verify output includes both agent contributions
    XCTAssertTrue(result.output.contains("AgentA"))
    XCTAssertTrue(result.output.contains("AgentB"))
}

// Test parallel groups
func testParallelExecution() async throws {
    let group = ParallelGroup(
        agents: [("a", mockAgentA), ("b", mockAgentB)],
        shouldContinueOnError: true
    )
    let result = try await group.run("input")

    // Verify all agents executed
    if case .int(let count) = result.metadata["agent_count"] {
        XCTAssertEqual(count, 2)
    }
}
```
