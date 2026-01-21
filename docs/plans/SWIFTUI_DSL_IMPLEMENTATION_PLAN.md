# SwiftUI-Inspired Agent DSL — Implementation Plan

## Overview

This document outlines the implementation plan for a SwiftUI-inspired declarative API for building and composing AI agents in SwiftAgents. This is a **novel approach to declarative agent development** — no other language has done this before.

### Design Philosophy

1. **Reading Order = Execution Order**: Code reads top-to-bottom like the actual execution flow
2. **Agents Are Loops**: Embrace that agents are fundamentally while loops (think → act → observe)
3. **Structure for Flow, Modifiers for Config**: Use structure to show data flow, modifiers for behavior configuration
4. **Progressive Disclosure**: Simple agents are trivially simple; complexity scales naturally
5. **No Custom Operators**: Standard Swift syntax only for tooling compatibility
6. **Type Safety**: Leverage Swift's type system for compile-time guarantees

---

## Part 1: Naming Decisions

### 1.1 Protocol Naming

| Name | Purpose |
|------|---------|
| `Agent` | The user-facing DSL protocol (like SwiftUI's `View`) |
| `AgentCore` | The runtime execution protocol (renamed from existing `Agent`) |
| `AgentBehavior` | Protocol for executable behaviors in the DSL |

### 1.2 Behavior Type Naming

| DSL Name | Runtime Equivalent | Purpose |
|----------|-------------------|---------|
| `Agent(...)` | `ReActAgent` | Primary agent with ReAct-style reasoning (default) |
| `Chat(...)` | Simple inference | Chat without tools |
| `ToolCallingAgent(...)` | `ToolCallingAgent` | Native tool calling without ReAct |
| `Planner(...)` | `PlanAndExecuteAgent` | Plan-then-execute agent |

### 1.3 Flow Control Naming

| Name | Purpose |
|------|---------|
| `Guard(.input)` / `Guard(.output)` | Input/output validation (structural) |
| `Transform(.input)` / `Transform(.output)` | Input/output transformation (structural) |
| `Sequential { }` | Sequential agent pipeline |
| `Parallel { }` | Parallel agent execution |
| `Route(using:) { }` | Conditional routing with explicit strategy |

---

## Part 2: Core Protocols

### 2.1 Agent Protocol (DSL)

```swift
// File: Sources/SwiftAgents/DSL/Core/Agent.swift

/// The primary protocol for declaratively defining agents.
///
/// `Agent` is the user-facing protocol for the DSL, inspired by SwiftUI's View.
/// Developers define agents by implementing the `body` property.
///
/// Example:
/// ```swift
/// struct GreeterAgent: Agent {
///     var body: some AgentBehavior {
///         Chat("You are a friendly greeter.")
///     }
/// }
/// ```
public protocol Agent: Sendable {
    /// The type of behavior this agent produces.
    associatedtype Body: AgentBehavior
    
    /// The body defining this agent's behavior.
    @AgentBuilder
    var body: Body { get }
}

// MARK: - Execution Extensions

extension Agent {
    /// Executes the agent with the given input.
    public func run(_ input: String) async throws -> AgentResult {
        let context = ExecutionContext(input: input)
        return try await body.execute(input, context: context)
    }
    
    /// Executes with a session for conversation continuity.
    public func run(_ input: String, session: any Session) async throws -> AgentResult {
        let context = ExecutionContext(input: input, session: session)
        return try await body.execute(input, context: context)
    }
    
    /// Streams the agent's execution.
    public func stream(_ input: String) -> AsyncThrowingStream<AgentEvent, Error> {
        let context = ExecutionContext(input: input)
        return body.stream(input, context: context)
    }
    
    /// Generates an execution flow diagram for debugging/documentation.
    public var executionFlow: ExecutionFlowDiagram {
        body.buildFlowDiagram()
    }
}
```

### 2.2 AgentCore Protocol (Runtime)

```swift
// File: Sources/SwiftAgents/Core/AgentCore.swift

/// Internal protocol for executable agent implementations.
///
/// `AgentCore` is the runtime protocol that actual agent implementations
/// conform to. The DSL `Agent` protocol builds on top of this.
///
/// Note: This was previously named `Agent`. Renamed to avoid collision
/// with the DSL protocol.
public protocol AgentCore: Sendable {
    nonisolated var tools: [any AnyJSONTool] { get }
    nonisolated var instructions: String { get }
    nonisolated var configuration: AgentConfiguration { get }
    nonisolated var memory: (any Memory)? { get }
    nonisolated var inferenceProvider: (any InferenceProvider)? { get }
    nonisolated var tracer: (any Tracer)? { get }
    nonisolated var inputGuardrails: [any InputGuardrail] { get }
    nonisolated var outputGuardrails: [any OutputGuardrail] { get }
    nonisolated var handoffs: [AnyHandoffConfiguration] { get }
    
    func run(_ input: String, session: (any Session)?, hooks: (any RunHooks)?) async throws -> AgentResult
    nonisolated func stream(_ input: String, session: (any Session)?, hooks: (any RunHooks)?) -> AsyncThrowingStream<AgentEvent, Error>
    func cancel() async
}
```

### 2.3 AgentBehavior Protocol

```swift
// File: Sources/SwiftAgents/DSL/Core/AgentBehavior.swift

/// Protocol for agent behavior implementations.
///
/// `AgentBehavior` defines how an agent executes. Built-in implementations
/// include `Agent` (ReAct-style), `Chat`, `ToolCallingAgent`, and
/// workflow types like `Sequential`, `Router`, and `Parallel`.
public protocol AgentBehavior: Sendable {
    /// Executes the behavior with the given input.
    func execute(_ input: String, context: ExecutionContext) async throws -> AgentResult
    
    /// Streams the behavior's execution.
    func stream(_ input: String, context: ExecutionContext) -> AsyncThrowingStream<AgentEvent, Error>
    
    /// Builds a flow diagram for visualization.
    func buildFlowDiagram() -> ExecutionFlowDiagram
}

// MARK: - Default Implementations

extension AgentBehavior {
    public func stream(_ input: String, context: ExecutionContext) -> AsyncThrowingStream<AgentEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                continuation.yield(.started(input: input))
                do {
                    let result = try await execute(input, context: context)
                    continuation.yield(.completed(result: result))
                    continuation.finish()
                } catch {
                    let agentError = (error as? AgentError) ?? .internalError(reason: error.localizedDescription)
                    continuation.yield(.failed(error: agentError))
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    public func buildFlowDiagram() -> ExecutionFlowDiagram {
        ExecutionFlowDiagram(name: String(describing: Self.self), stages: [])
    }
}
```

### 2.4 ExecutionContext

```swift
// File: Sources/SwiftAgents/DSL/Core/ExecutionContext.swift

/// Type-safe context key protocol.
public protocol ContextKey {
    associatedtype Value: Sendable
    static var defaultValue: Value { get }
}

/// Runtime context for agent execution.
public actor ExecutionContext {
    public let input: String
    public let session: (any Session)?
    public let executionId: String
    public private(set) var environment: AgentEnvironment
    
    private var values: [ObjectIdentifier: any Sendable] = [:]
    private var executionPath: [String] = []
    
    public init(
        input: String,
        session: (any Session)? = nil,
        environment: AgentEnvironment = AgentEnvironment()
    ) {
        self.input = input
        self.session = session
        self.executionId = UUID().uuidString
        self.environment = environment
    }
    
    public func value<K: ContextKey>(for key: K.Type) -> K.Value {
        values[ObjectIdentifier(key)] as? K.Value ?? K.defaultValue
    }
    
    public func setValue<K: ContextKey>(_ value: K.Value, for key: K.Type) {
        values[ObjectIdentifier(key)] = value
    }
    
    public func recordExecution(agentName: String) {
        executionPath.append(agentName)
    }
    
    public var path: [String] { executionPath }
    
    public func childContext(input: String) -> ExecutionContext {
        ExecutionContext(input: input, session: session, environment: environment)
    }
    
    public func modifyEnvironment(_ modification: (inout AgentEnvironment) -> Void) {
        modification(&environment)
    }
}
```

### 2.5 AgentEnvironment

```swift
// File: Sources/SwiftAgents/DSL/Core/AgentEnvironment.swift

/// Protocol for environment keys.
public protocol AgentEnvironmentKey {
    associatedtype Value: Sendable
    static var defaultValue: Value { get }
}

/// Environment values container for configuration propagation.
public struct AgentEnvironment: Sendable {
    private var values: [ObjectIdentifier: any Sendable] = [:]
    
    public init() {}
    
    public subscript<K: AgentEnvironmentKey>(key: K.Type) -> K.Value {
        get { values[ObjectIdentifier(key)] as? K.Value ?? K.defaultValue }
        set { values[ObjectIdentifier(key)] = newValue }
    }
}

// MARK: - Standard Environment Keys

public struct InferenceProviderKey: AgentEnvironmentKey {
    public static var defaultValue: (any InferenceProvider)? { nil }
}

public struct TracerKey: AgentEnvironmentKey {
    public static var defaultValue: (any Tracer)? { nil }
}

// MARK: - Convenience Accessors

extension AgentEnvironment {
    public var inferenceProvider: (any InferenceProvider)? {
        get { self[InferenceProviderKey.self] }
        set { self[InferenceProviderKey.self] = newValue }
    }
    
    public var tracer: (any Tracer)? {
        get { self[TracerKey.self] }
        set { self[TracerKey.self] = newValue }
    }
}
```

---

## Part 3: Agent Behavior Types

### 3.1 Agent (Primary - ReAct Style)

```swift
// File: Sources/SwiftAgents/DSL/Behaviors/AgentBehavior.swift

/// The primary agent behavior using ReAct-style reasoning.
///
/// This is the default agent type that implements the think-act-observe loop.
///
/// Example:
/// ```swift
/// Agent("You are a helpful assistant.") {
///     CalculatorTool()
///     WeatherTool()
/// }
/// ```
public struct AgentBody: AgentBehavior {
    private let instructions: String
    private let tools: [any AnyJSONTool]
    
    /// Creates an agent with instructions only.
    public init(_ instructions: String) {
        self.instructions = instructions
        self.tools = []
    }
    
    /// Creates an agent with instructions and tools.
    public init(_ instructions: String, @ToolBuilder tools: () -> [any AnyJSONTool]) {
        self.instructions = instructions
        self.tools = tools()
    }
    
    public func execute(_ input: String, context: ExecutionContext) async throws -> AgentResult {
        let provider = await context.environment.inferenceProvider
        guard let provider else {
            throw AgentError.inferenceProviderUnavailable(
                reason: "No inference provider configured. Use .environment(\\.inferenceProvider, provider)"
            )
        }
        
        let agent = ReActAgent(
            tools: tools,
            instructions: instructions,
            inferenceProvider: provider,
            tracer: await context.environment.tracer
        )
        
        return try await agent.run(input, session: context.session, hooks: nil)
    }
    
    public func buildFlowDiagram() -> ExecutionFlowDiagram {
        ExecutionFlowDiagram(name: "Agent", stages: [
            .agent(name: "Agent", tools: tools.map(\.name))
        ])
    }
}

/// `Agent` is the primary behavior type - a typealias for clarity.
public typealias Agent = AgentBody
```

### 3.2 Chat Behavior

```swift
// File: Sources/SwiftAgents/DSL/Behaviors/ChatBehavior.swift

/// Simple chat behavior without tool calling.
///
/// Example:
/// ```swift
/// Chat("You are a friendly greeter.")
/// ```
public struct Chat: AgentBehavior {
    private let instructions: String
    
    public init(_ instructions: String) {
        self.instructions = instructions
    }
    
    public func execute(_ input: String, context: ExecutionContext) async throws -> AgentResult {
        let provider = await context.environment.inferenceProvider
        guard let provider else {
            throw AgentError.inferenceProviderUnavailable(reason: "No inference provider configured")
        }
        
        let prompt = """
        \(instructions)
        
        User: \(input)
        """
        
        let output = try await provider.generate(prompt: prompt, options: .default)
        return AgentResult(output: output)
    }
    
    public func buildFlowDiagram() -> ExecutionFlowDiagram {
        ExecutionFlowDiagram(name: "Chat", stages: [.chat(instructions: instructions)])
    }
}
```

### 3.3 ToolCallingAgent Behavior

```swift
// File: Sources/SwiftAgents/DSL/Behaviors/ToolCallingBehavior.swift

/// Tool-calling agent using native LLM tool calling (without ReAct reasoning).
public struct ToolCallingAgent: AgentBehavior {
    private let instructions: String
    private let tools: [any AnyJSONTool]
    
    public init(_ instructions: String, @ToolBuilder tools: () -> [any AnyJSONTool]) {
        self.instructions = instructions
        self.tools = tools()
    }
    
    public func execute(_ input: String, context: ExecutionContext) async throws -> AgentResult {
        let provider = await context.environment.inferenceProvider
        guard let provider else {
            throw AgentError.inferenceProviderUnavailable(reason: "No inference provider configured")
        }
        
        let agent = SwiftAgents.ToolCallingAgent(
            tools: tools,
            instructions: instructions,
            inferenceProvider: provider
        )
        
        return try await agent.run(input, session: context.session, hooks: nil)
    }
    
    public func buildFlowDiagram() -> ExecutionFlowDiagram {
        ExecutionFlowDiagram(name: "ToolCallingAgent", stages: [
            .agent(name: "ToolCallingAgent", tools: tools.map(\.name))
        ])
    }
}
```

### 3.4 Planner Behavior

```swift
// File: Sources/SwiftAgents/DSL/Behaviors/PlannerBehavior.swift

/// Plan-and-execute agent that creates a plan before execution.
public struct Planner: AgentBehavior {
    private let instructions: String
    private let tools: [any AnyJSONTool]
    
    public init(_ instructions: String, @ToolBuilder tools: () -> [any AnyJSONTool]) {
        self.instructions = instructions
        self.tools = tools()
    }
    
    public func execute(_ input: String, context: ExecutionContext) async throws -> AgentResult {
        let provider = await context.environment.inferenceProvider
        guard let provider else {
            throw AgentError.inferenceProviderUnavailable(reason: "No inference provider configured")
        }
        
        let agent = PlanAndExecuteAgent(
            tools: tools,
            instructions: instructions,
            inferenceProvider: provider
        )
        
        return try await agent.run(input, session: context.session, hooks: nil)
    }
    
    public func buildFlowDiagram() -> ExecutionFlowDiagram {
        ExecutionFlowDiagram(name: "Planner", stages: [.planning, .agent(name: "Executor", tools: tools.map(\.name))])
    }
}
```

---

## Part 4: Flow Control Structures

### 4.1 Guard (Input/Output Validation)

```swift
// File: Sources/SwiftAgents/DSL/Flow/Guard.swift

/// Specifies whether a guard applies to input or output.
public enum GuardPhase: Sendable {
    case input
    case output
}

/// Validates input or output with guardrails.
///
/// Guards are structural elements that show validation in the execution flow.
/// Reading order = execution order.
///
/// Example:
/// ```swift
/// Guard(.input) {
///     ContentFilter()
///     RateLimiter(rpm: 60)
/// }
/// ```
public struct Guard: AgentBehavior {
    public let phase: GuardPhase
    public let guardrails: [any Guardrail]
    
    public init(_ phase: GuardPhase, @GuardrailBuilder guardrails: () -> [any Guardrail]) {
        self.phase = phase
        self.guardrails = guardrails()
    }
    
    public func execute(_ input: String, context: ExecutionContext) async throws -> AgentResult {
        switch phase {
        case .input:
            for guardrail in guardrails {
                if let inputGuardrail = guardrail as? any InputGuardrail {
                    let result = try await inputGuardrail.validate(input: input)
                    if !result.passed {
                        throw GuardrailError.inputTripwireTriggered(
                            guardrail: String(describing: type(of: guardrail)),
                            message: result.message ?? "Input validation failed"
                        )
                    }
                }
            }
        case .output:
            // Output guards validate the input as "output from previous step"
            for guardrail in guardrails {
                if let outputGuardrail = guardrail as? any OutputGuardrail {
                    let result = try await outputGuardrail.validate(output: input, agent: DummyAgent())
                    if !result.passed {
                        throw GuardrailError.outputTripwireTriggered(
                            guardrail: String(describing: type(of: guardrail)),
                            message: result.message ?? "Output validation failed"
                        )
                    }
                }
            }
        }
        
        // Pass through unchanged
        return AgentResult(output: input)
    }
    
    public func buildFlowDiagram() -> ExecutionFlowDiagram {
        let names = guardrails.map { String(describing: type(of: $0)) }
        return ExecutionFlowDiagram(name: "Guard(\(phase))", stages: [
            .guard(phase: phase, guardrails: names)
        ])
    }
}

/// Base protocol for all guardrails.
public protocol Guardrail: Sendable {}

@resultBuilder
public struct GuardrailBuilder {
    public static func buildBlock(_ guardrails: any Guardrail...) -> [any Guardrail] {
        guardrails
    }
    
    public static func buildOptional(_ guardrail: (any Guardrail)?) -> [any Guardrail] {
        guardrail.map { [$0] } ?? []
    }
    
    public static func buildEither(first guardrail: any Guardrail) -> [any Guardrail] {
        [guardrail]
    }
    
    public static func buildEither(second guardrail: any Guardrail) -> [any Guardrail] {
        [guardrail]
    }
    
    public static func buildArray(_ guardrails: [[any Guardrail]]) -> [any Guardrail] {
        guardrails.flatMap { $0 }
    }
}
```

### 4.2 Transform (Input/Output Transformation)

```swift
// File: Sources/SwiftAgents/DSL/Flow/Transform.swift

/// Specifies whether a transform applies to input or output.
public enum TransformPhase: Sendable {
    case input
    case output
}

/// Transforms input or output data.
///
/// Example:
/// ```swift
/// Transform(.input) { input in
///     input.lowercased().trimmingCharacters(in: .whitespace)
/// }
/// ```
public struct Transform: AgentBehavior {
    private let phase: TransformPhase
    private let transform: @Sendable (String) async throws -> String
    
    public init(_ phase: TransformPhase, _ transform: @escaping @Sendable (String) async throws -> String) {
        self.phase = phase
        self.transform = transform
    }
    
    public func execute(_ input: String, context: ExecutionContext) async throws -> AgentResult {
        let output = try await transform(input)
        return AgentResult(output: output)
    }
    
    public func buildFlowDiagram() -> ExecutionFlowDiagram {
        ExecutionFlowDiagram(name: "Transform(\(phase))", stages: [.transform(phase: phase)])
    }
}
```

### 4.3 Sequential Workflow

```swift
// File: Sources/SwiftAgents/DSL/Flow/Sequential.swift

/// Sequential agent execution pipeline.
///
/// Executes agents in order, passing each output as input to the next.
///
/// Example:
/// ```swift
/// Sequential {
///     ClassifierAgent()
///     ProcessorAgent()
///     FormatterAgent()
/// }
/// ```
public struct Sequential: AgentBehavior {
    private let agents: [any Agent]
    
    public init(@AgentSequenceBuilder _ content: () -> [any Agent]) {
        self.agents = content()
    }
    
    public func execute(_ input: String, context: ExecutionContext) async throws -> AgentResult {
        var currentInput = input
        var allToolCalls: [ToolCall] = []
        var allToolResults: [ToolResult] = []
        var totalIterations = 0
        let startTime = ContinuousClock.now
        
        for agent in agents {
            let childContext = await context.childContext(input: currentInput)
            let result = try await agent.body.execute(currentInput, context: childContext)
            
            allToolCalls.append(contentsOf: result.toolCalls)
            allToolResults.append(contentsOf: result.toolResults)
            totalIterations += result.iterationCount
            currentInput = result.output
        }
        
        return AgentResult(
            output: currentInput,
            toolCalls: allToolCalls,
            toolResults: allToolResults,
            iterationCount: totalIterations,
            duration: ContinuousClock.now - startTime
        )
    }
    
    public func buildFlowDiagram() -> ExecutionFlowDiagram {
        let stages = agents.map { FlowStage.subAgent(name: String(describing: type(of: $0))) }
        return ExecutionFlowDiagram(name: "Sequential", stages: stages)
    }
}

@resultBuilder
public struct AgentSequenceBuilder {
    public static func buildBlock(_ agents: any Agent...) -> [any Agent] {
        agents
    }
    
    public static func buildOptional(_ agent: (any Agent)?) -> [any Agent] {
        agent.map { [$0] } ?? []
    }
    
    public static func buildEither(first agent: any Agent) -> [any Agent] {
        [agent]
    }
    
    public static func buildEither(second agent: any Agent) -> [any Agent] {
        [agent]
    }
    
    public static func buildArray(_ agents: [[any Agent]]) -> [any Agent] {
        agents.flatMap { $0 }
    }
}
```

### 4.4 Parallel Workflow

```swift
// File: Sources/SwiftAgents/DSL/Flow/Parallel.swift

/// Merge strategy for parallel execution results.
public enum MergeStrategy: Sendable {
    case concatenate
    case structured
    case first
    case longest
    case custom(@Sendable ([(String, AgentResult)]) -> String)
}

/// Parallel agent execution.
///
/// Example:
/// ```swift
/// Parallel(merge: .structured) {
///     SentimentAgent().as("sentiment")
///     SummaryAgent().as("summary")
/// }
/// ```
public struct Parallel: AgentBehavior {
    private let agents: [(String, any Agent)]
    private let strategy: MergeStrategy
    
    public init(merge strategy: MergeStrategy = .concatenate, @ParallelAgentBuilder _ content: () -> [(String, any Agent)]) {
        self.strategy = strategy
        self.agents = content()
    }
    
    public func execute(_ input: String, context: ExecutionContext) async throws -> AgentResult {
        let startTime = ContinuousClock.now
        
        let results = try await withThrowingTaskGroup(of: (String, AgentResult).self) { group in
            for (name, agent) in agents {
                group.addTask {
                    let childContext = await context.childContext(input: input)
                    let result = try await agent.body.execute(input, context: childContext)
                    return (name, result)
                }
            }
            
            var collected: [(String, AgentResult)] = []
            for try await result in group {
                collected.append(result)
            }
            return collected
        }
        
        let output = mergeResults(results)
        
        return AgentResult(
            output: output,
            toolCalls: results.flatMap { $0.1.toolCalls },
            toolResults: results.flatMap { $0.1.toolResults },
            iterationCount: results.map { $0.1.iterationCount }.reduce(0, +),
            duration: ContinuousClock.now - startTime
        )
    }
    
    private func mergeResults(_ results: [(String, AgentResult)]) -> String {
        switch strategy {
        case .concatenate:
            return results.map { "\($0.0): \($0.1.output)" }.joined(separator: "\n\n")
        case .structured:
            return results.map { "## \($0.0)\n\n\($0.1.output)" }.joined(separator: "\n\n")
        case .first:
            return results.first?.1.output ?? ""
        case .longest:
            return results.max { $0.1.output.count < $1.1.output.count }?.1.output ?? ""
        case .custom(let merger):
            return merger(results)
        }
    }
    
    public func buildFlowDiagram() -> ExecutionFlowDiagram {
        let branches = agents.map { ($0.0, $0.1.body.buildFlowDiagram()) }
        return ExecutionFlowDiagram(name: "Parallel", stages: [.parallel(branches: branches)])
    }
}

extension Agent {
    /// Names this agent for parallel execution result labeling.
    public func `as`(_ name: String) -> (String, any Agent) {
        (name, self)
    }
}

@resultBuilder
public struct ParallelAgentBuilder {
    public static func buildBlock(_ agents: (String, any Agent)...) -> [(String, any Agent)] {
        agents
    }
    
    public static func buildArray(_ agents: [[(String, any Agent)]]) -> [(String, any Agent)] {
        agents.flatMap { $0 }
    }
}
```

### 4.5 Route Workflow

```swift
// File: Sources/SwiftAgents/DSL/Flow/Route.swift

/// How routing decisions are made.
public enum RoutingStrategy<Key: Hashable & Sendable>: Sendable {
    /// Rule-based: Deterministic conditions evaluated in order.
    case rules
    
    /// LLM-based: Language model classifies intent.
    case llm(classifier: any IntentClassifier<Key>)
    
    /// Semantic: Embedding similarity matching.
    case semantic(embedder: any EmbeddingProvider, threshold: Double = 0.8)
    
    /// Custom: User-provided routing function.
    case custom(@Sendable (String, ExecutionContext) async throws -> Key)
}

/// Conditional routing to different agents.
///
/// Routes input to different agents based on a routing strategy.
/// The strategy is explicit so developers know HOW routing decisions are made.
///
/// Example:
/// ```swift
/// Route(using: .llm(IntentClassifier())) {
///     When(.billing, use: BillingAgent())
///     When(.technical, use: TechnicalAgent())
///     Otherwise(use: GeneralAgent())
/// }
/// ```
public struct Route<Key: Hashable & Sendable>: AgentBehavior {
    private let strategy: RoutingStrategy<Key>
    private let routes: [Key: any Agent]
    private let defaultAgent: (any Agent)?
    private let ruleConditions: [(Key, RouteCondition)]
    
    public init(
        using strategy: RoutingStrategy<Key>,
        @RouteBuilder<Key> _ content: () -> RouteContent<Key>
    ) {
        self.strategy = strategy
        let built = content()
        self.routes = built.routes
        self.defaultAgent = built.defaultAgent
        self.ruleConditions = built.ruleConditions
    }
    
    public func execute(_ input: String, context: ExecutionContext) async throws -> AgentResult {
        let key = try await resolveRoute(input: input, context: context)
        
        if let agent = routes[key] {
            await context.recordExecution(agentName: String(describing: key))
            let childContext = await context.childContext(input: input)
            return try await agent.body.execute(input, context: childContext)
        }
        
        if let defaultAgent {
            await context.recordExecution(agentName: "Default")
            let childContext = await context.childContext(input: input)
            return try await defaultAgent.body.execute(input, context: childContext)
        }
        
        throw OrchestrationError.routingFailed(reason: "No route matched for key: \(key)")
    }
    
    private func resolveRoute(input: String, context: ExecutionContext) async throws -> Key {
        switch strategy {
        case .rules:
            for (key, condition) in ruleConditions {
                if await condition.matches(input: input) {
                    return key
                }
            }
            throw OrchestrationError.routingFailed(reason: "No rule matched")
            
        case .llm(let classifier):
            return try await classifier.classify(input)
            
        case .semantic(_, _):
            throw OrchestrationError.routingFailed(reason: "Semantic routing not yet implemented")
            
        case .custom(let resolver):
            return try await resolver(input, context)
        }
    }
    
    public func buildFlowDiagram() -> ExecutionFlowDiagram {
        let routeNames = routes.map { (String(describing: $0.key), $0.value.body.buildFlowDiagram()) }
        let strategyName: String
        switch strategy {
        case .rules: strategyName = "Rules"
        case .llm: strategyName = "LLM"
        case .semantic: strategyName = "Semantic"
        case .custom: strategyName = "Custom"
        }
        return ExecutionFlowDiagram(name: "Route(\(strategyName))", stages: [
            .route(strategy: strategyName, branches: routeNames)
        ])
    }
}

// MARK: - Route Cases

/// Defines a route case.
public struct When<Key: Hashable & Sendable>: Sendable {
    public let key: Key
    public let agent: any Agent
    public let condition: RouteCondition?
    
    /// LLM-based routing case.
    public init(_ key: Key, use agent: any Agent) {
        self.key = key
        self.agent = agent
        self.condition = nil
    }
    
    /// Rule-based routing case with condition.
    public init(_ key: Key, matching condition: RouteCondition, use agent: any Agent) {
        self.key = key
        self.agent = agent
        self.condition = condition
    }
}

/// Defines the default route.
public struct Otherwise<Key: Hashable & Sendable>: Sendable {
    public let agent: any Agent
    
    public init(use agent: any Agent) {
        self.agent = agent
    }
}

/// Container for built route content.
public struct RouteContent<Key: Hashable & Sendable>: Sendable {
    public var routes: [Key: any Agent] = [:]
    public var defaultAgent: (any Agent)?
    public var ruleConditions: [(Key, RouteCondition)] = []
}

@resultBuilder
public struct RouteBuilder<Key: Hashable & Sendable> {
    public static func buildBlock(_ components: Any...) -> RouteContent<Key> {
        var content = RouteContent<Key>()
        for component in components {
            if let when = component as? When<Key> {
                content.routes[when.key] = when.agent
                if let condition = when.condition {
                    content.ruleConditions.append((when.key, condition))
                }
            } else if let otherwise = component as? Otherwise<Key> {
                content.defaultAgent = otherwise.agent
            }
        }
        return content
    }
}

/// Protocol for LLM-based intent classification.
public protocol IntentClassifier<Key>: Sendable {
    associatedtype Key: Hashable & Sendable
    func classify(_ input: String) async throws -> Key
}

/// Conditions for rule-based routing.
public struct RouteCondition: Sendable {
    private let matcher: @Sendable (String) async -> Bool
    
    public init(_ matcher: @escaping @Sendable (String) async -> Bool) {
        self.matcher = matcher
    }
    
    public static func contains(_ substring: String) -> RouteCondition {
        RouteCondition { $0.localizedCaseInsensitiveContains(substring) }
    }
    
    public static func matches(regex: String) -> RouteCondition {
        RouteCondition { input in
            (try? Regex(regex).firstMatch(in: input)) != nil
        }
    }
    
    public static func hasPrefix(_ prefix: String) -> RouteCondition {
        RouteCondition { $0.hasPrefix(prefix) }
    }
    
    public func matches(input: String) async -> Bool {
        await matcher(input)
    }
}
```

---

## Part 5: Modifiers

Modifiers are for **configuration**, not flow. They wrap behaviors to add cross-cutting concerns.

### 5.1 Memory Modifier

```swift
// File: Sources/SwiftAgents/DSL/Modifiers/MemoryModifier.swift

extension AgentBehavior {
    /// Adds memory to the agent.
    public func memory(_ configuration: MemoryConfiguration) -> MemoryModifiedBehavior<Self> {
        MemoryModifiedBehavior(base: self, memory: configuration)
    }
}

public struct MemoryModifiedBehavior<Base: AgentBehavior>: AgentBehavior {
    let base: Base
    let memoryConfig: MemoryConfiguration
    
    public func execute(_ input: String, context: ExecutionContext) async throws -> AgentResult {
        // Memory configuration is applied to the underlying agent
        try await base.execute(input, context: context)
    }
    
    public func buildFlowDiagram() -> ExecutionFlowDiagram {
        var diagram = base.buildFlowDiagram()
        diagram.modifiers.append("memory(\(memoryConfig))")
        return diagram
    }
}

public enum MemoryConfiguration: Sendable {
    case conversation(limit: Int = 100)
    case sliding(window: Int)
    case vector(provider: any EmbeddingProvider, limit: Int = 10)
    case summary(summarizer: any Summarizer)
    case hybrid([MemoryConfiguration])
    case custom(any Memory)
}
```

### 5.2 Retry Modifier

```swift
// File: Sources/SwiftAgents/DSL/Modifiers/RetryModifier.swift

extension AgentBehavior {
    /// Adds retry behavior.
    public func retry(_ policy: RetryPolicy) -> RetryModifiedBehavior<Self> {
        RetryModifiedBehavior(base: self, policy: policy)
    }
}

public struct RetryModifiedBehavior<Base: AgentBehavior>: AgentBehavior {
    let base: Base
    let policy: RetryPolicy
    
    public func execute(_ input: String, context: ExecutionContext) async throws -> AgentResult {
        try await policy.execute {
            try await base.execute(input, context: context)
        }
    }
    
    public func buildFlowDiagram() -> ExecutionFlowDiagram {
        var diagram = base.buildFlowDiagram()
        diagram.modifiers.append("retry(\(policy))")
        return diagram
    }
}
```

### 5.3 Timeout Modifier

```swift
// File: Sources/SwiftAgents/DSL/Modifiers/TimeoutModifier.swift

extension AgentBehavior {
    /// Adds timeout.
    public func timeout(_ duration: Duration) -> TimeoutModifiedBehavior<Self> {
        TimeoutModifiedBehavior(base: self, duration: duration)
    }
}

public struct TimeoutModifiedBehavior<Base: AgentBehavior>: AgentBehavior {
    let base: Base
    let duration: Duration
    
    public func execute(_ input: String, context: ExecutionContext) async throws -> AgentResult {
        try await withThrowingTaskGroup(of: AgentResult.self) { group in
            group.addTask {
                try await base.execute(input, context: context)
            }
            
            group.addTask {
                try await Task.sleep(for: duration)
                throw AgentError.timeout(duration: duration)
            }
            
            guard let result = try await group.next() else {
                throw AgentError.timeout(duration: duration)
            }
            
            group.cancelAll()
            return result
        }
    }
    
    public func buildFlowDiagram() -> ExecutionFlowDiagram {
        var diagram = base.buildFlowDiagram()
        diagram.modifiers.append("timeout(\(duration))")
        return diagram
    }
}
```

### 5.4 Environment Modifier

```swift
// File: Sources/SwiftAgents/DSL/Modifiers/EnvironmentModifier.swift

extension AgentBehavior {
    /// Sets an environment value.
    public func environment<V>(
        _ keyPath: WritableKeyPath<AgentEnvironment, V>,
        _ value: V
    ) -> EnvironmentModifiedBehavior<Self> {
        EnvironmentModifiedBehavior(base: self, keyPath: keyPath, value: value)
    }
}

public struct EnvironmentModifiedBehavior<Base: AgentBehavior>: AgentBehavior {
    let base: Base
    let modification: @Sendable (inout AgentEnvironment) -> Void
    
    init<V>(base: Base, keyPath: WritableKeyPath<AgentEnvironment, V>, value: V) {
        self.base = base
        self.modification = { env in
            env[keyPath: keyPath] = value
        }
    }
    
    public func execute(_ input: String, context: ExecutionContext) async throws -> AgentResult {
        await context.modifyEnvironment(modification)
        return try await base.execute(input, context: context)
    }
    
    public func buildFlowDiagram() -> ExecutionFlowDiagram {
        var diagram = base.buildFlowDiagram()
        diagram.modifiers.append("environment(...)")
        return diagram
    }
}
```

### 5.5 Tracing Modifier

```swift
// File: Sources/SwiftAgents/DSL/Modifiers/TracingModifier.swift

extension AgentBehavior {
    /// Enables tracing for this behavior.
    public func traced(_ operationName: String? = nil) -> TracingModifiedBehavior<Self> {
        TracingModifiedBehavior(base: self, operationName: operationName)
    }
}

public struct TracingModifiedBehavior<Base: AgentBehavior>: AgentBehavior {
    let base: Base
    let operationName: String?
    
    public func execute(_ input: String, context: ExecutionContext) async throws -> AgentResult {
        let tracer = await context.environment.tracer
        let name = operationName ?? String(describing: Base.self)
        
        await tracer?.traceAgentStart(name: name, input: input)
        
        do {
            let result = try await base.execute(input, context: context)
            await tracer?.traceAgentEnd(name: name, output: result.output)
            return result
        } catch {
            await tracer?.traceAgentError(name: name, error: error)
            throw error
        }
    }
    
    public func buildFlowDiagram() -> ExecutionFlowDiagram {
        var diagram = base.buildFlowDiagram()
        diagram.modifiers.append("traced")
        return diagram
    }
}
```

---

## Part 6: Result Builders

### 6.1 AgentBuilder

```swift
// File: Sources/SwiftAgents/DSL/Builders/AgentBuilder.swift

/// Result builder for agent body content.
@resultBuilder
public struct AgentBuilder {
    // Single behavior
    public static func buildBlock<B: AgentBehavior>(_ behavior: B) -> B {
        behavior
    }
    
    // Multiple behaviors become a sequential pipeline
    public static func buildBlock(_ behaviors: any AgentBehavior...) -> SequentialBehavior {
        SequentialBehavior(behaviors: behaviors)
    }
    
    // Optional behavior
    public static func buildOptional<B: AgentBehavior>(_ behavior: B?) -> OptionalBehavior<B> {
        OptionalBehavior(behavior: behavior)
    }
    
    // Conditional - first branch
    public static func buildEither<First: AgentBehavior, Second: AgentBehavior>(
        first behavior: First
    ) -> EitherBehavior<First, Second> {
        .first(behavior)
    }
    
    // Conditional - second branch
    public static func buildEither<First: AgentBehavior, Second: AgentBehavior>(
        second behavior: Second
    ) -> EitherBehavior<First, Second> {
        .second(behavior)
    }
}

/// Sequential behavior from multiple statements in body.
public struct SequentialBehavior: AgentBehavior {
    let behaviors: [any AgentBehavior]
    
    public func execute(_ input: String, context: ExecutionContext) async throws -> AgentResult {
        var currentInput = input
        var lastResult: AgentResult?
        
        for behavior in behaviors {
            let result = try await behavior.execute(currentInput, context: context)
            currentInput = result.output
            lastResult = result
        }
        
        return lastResult ?? AgentResult(output: input)
    }
    
    public func buildFlowDiagram() -> ExecutionFlowDiagram {
        let stages = behaviors.flatMap { $0.buildFlowDiagram().stages }
        return ExecutionFlowDiagram(name: "Sequential", stages: stages)
    }
}

public struct OptionalBehavior<Wrapped: AgentBehavior>: AgentBehavior {
    let behavior: Wrapped?
    
    public func execute(_ input: String, context: ExecutionContext) async throws -> AgentResult {
        if let behavior {
            return try await behavior.execute(input, context: context)
        }
        return AgentResult(output: input)
    }
    
    public func buildFlowDiagram() -> ExecutionFlowDiagram {
        behavior?.buildFlowDiagram() ?? ExecutionFlowDiagram(name: "Empty", stages: [])
    }
}

public enum EitherBehavior<First: AgentBehavior, Second: AgentBehavior>: AgentBehavior {
    case first(First)
    case second(Second)
    
    public func execute(_ input: String, context: ExecutionContext) async throws -> AgentResult {
        switch self {
        case .first(let behavior):
            return try await behavior.execute(input, context: context)
        case .second(let behavior):
            return try await behavior.execute(input, context: context)
        }
    }
    
    public func buildFlowDiagram() -> ExecutionFlowDiagram {
        switch self {
        case .first(let behavior): return behavior.buildFlowDiagram()
        case .second(let behavior): return behavior.buildFlowDiagram()
        }
    }
}
```

### 6.2 ToolBuilder

```swift
// File: Sources/SwiftAgents/DSL/Builders/ToolBuilder.swift

@resultBuilder
public struct ToolBuilder {
    public static func buildBlock(_ tools: any AnyJSONTool...) -> [any AnyJSONTool] {
        tools
    }
    
    public static func buildOptional(_ tool: (any AnyJSONTool)?) -> [any AnyJSONTool] {
        tool.map { [$0] } ?? []
    }
    
    public static func buildEither(first tool: any AnyJSONTool) -> [any AnyJSONTool] {
        [tool]
    }
    
    public static func buildEither(second tool: any AnyJSONTool) -> [any AnyJSONTool] {
        [tool]
    }
    
    public static func buildArray(_ tools: [[any AnyJSONTool]]) -> [any AnyJSONTool] {
        tools.flatMap { $0 }
    }
}
```

---

## Part 7: Usage Examples by Tier

### Tier 1: Simple Agents (80% of use cases)

```swift
// Simplest possible agent - just chat
struct GreeterAgent: Agent {
    var body: some AgentBehavior {
        Chat("You are a friendly greeter who welcomes users warmly.")
    }
}

// Agent with tools
struct CalculatorAgent: Agent {
    var body: some AgentBehavior {
        Agent("You help users with mathematical calculations.") {
            CalculatorTool()
            UnitConverterTool()
        }
    }
}

// Agent with memory (modifier for config)
struct ConversationalAgent: Agent {
    var body: some AgentBehavior {
        Agent("You are a helpful assistant who remembers context.") {
            SearchTool()
            CalendarTool()
        }
        .memory(.conversation(limit: 100))
    }
}
```

### Tier 2: Agents with Flow Control

```swift
// Agent with visible input/output validation
struct SafeAssistant: Agent {
    var body: some AgentBehavior {
        // Reading order = execution order
        Guard(.input) {
            ContentFilter()
            RateLimiter(rpm: 60)
        }
        
        Agent("You are a helpful and safe assistant.") {
            SearchTool()
        }
        
        Guard(.output) {
            ToxicityFilter()
            PIIRedactor()
        }
    }
}

// Agent with input transformation
struct NormalizedAgent: Agent {
    var body: some AgentBehavior {
        Transform(.input) { input in
            input.lowercased().trimmingCharacters(in: .whitespace)
        }
        
        Agent("You process normalized input.") {
            DataTool()
        }
    }
}
```

### Tier 3: Orchestrated Agents

```swift
// Sequential pipeline
struct AnalysisPipeline: Agent {
    var body: some AgentBehavior {
        Sequential {
            DataCleanerAgent()
            AnalyzerAgent()
            ReportGeneratorAgent()
        }
    }
}

// Parallel execution
struct MultiPerspectiveAnalysis: Agent {
    var body: some AgentBehavior {
        Parallel(merge: .structured) {
            SentimentAgent().as("sentiment")
            SummaryAgent().as("summary")
            KeywordAgent().as("keywords")
        }
    }
}

// Routing with explicit strategy
struct CustomerService: Agent {
    var body: some AgentBehavior {
        Guard(.input) {
            ContentFilter()
        }
        
        Route(using: .llm(CustomerIntentClassifier())) {
            When(.billing, use: BillingAgent())
            When(.technical, use: TechnicalAgent())
            When(.sales, use: SalesAgent())
            Otherwise(use: GeneralAgent())
        }
        
        Guard(.output) {
            ToxicityFilter()
        }
    }
}

// Rule-based routing
struct SimpleRouter: Agent {
    var body: some AgentBehavior {
        Route(using: .rules) {
            When(.urgent, matching: .contains("URGENT"), use: EscalationAgent())
            When(.order, matching: .matches(regex: "order #\\d+"), use: OrderLookupAgent())
            Otherwise(use: GeneralAgent())
        }
    }
}
```

### Tier 4: Production Configuration

```swift
// Full production setup with environment and resilience
@main
struct MyApp {
    static func main() async throws {
        let provider = OpenRouterProvider(
            apiKey: ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"]!
        )
        let tracer = ConsoleTracer()
        
        let result = try await CustomerService()
            .environment(\.inferenceProvider, provider)
            .environment(\.tracer, tracer)
            .retry(.exponential(maxAttempts: 3))
            .timeout(.seconds(60))
            .traced("customer-service")
            .run("I was charged twice for my subscription")
        
        print(result.output)
    }
}

// Complex orchestration with all features
struct EnterpriseAgent: Agent {
    var body: some AgentBehavior {
        Guard(.input) {
            AuthenticationGuardrail()
            RateLimiter(rpm: 100)
        }
        
        Transform(.input) { input in
            input.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        Route(using: .llm(EnterpriseIntentClassifier())) {
            When(.simple, use: FAQAgent())
            When(.complex, use: Sequential {
                PlannerAgent()
                ExecutorAgent()
                ValidatorAgent()
            })
            When(.analytics, use: Parallel(merge: .structured) {
                DataAgent().as("data")
                ChartAgent().as("charts")
                InsightAgent().as("insights")
            })
            Otherwise(use: GeneralAgent())
        }
        
        Guard(.output) {
            ComplianceGuardrail()
            BrandVoiceGuardrail()
        }
    }
}
```

---

## Part 8: Component Semantics

### Duplicate Component Behavior

| Component | Duplicate Behavior | Rationale |
|-----------|-------------------|-----------|
| Memory | **Error** | Agent has one memory system; use `.hybrid()` for multiple |
| Tools | **Merge** | Combining tool sets is valid |
| Guardrails | **Merge** | Multiple guardrails stack |
| Environment | **Last wins** | Override pattern (like CSS shadowing) |

### Validation Example

```swift
// This will error at runtime with a clear message:
Agent("...") {
    Memory(.conversation(limit: 100))
    Memory(.vector(provider: embedder))  // ❌ Error: Only one Memory allowed
}

// Correct pattern:
Agent("...") {
    Memory(.hybrid([
        .conversation(limit: 100),
        .vector(provider: embedder)
    ]))  // ✅ Single Memory with hybrid strategy
}
```

---

## Part 9: Execution Flow Visualization

```swift
// File: Sources/SwiftAgents/DSL/Diagnostics/ExecutionFlowDiagram.swift

/// Visual representation of agent execution flow.
public struct ExecutionFlowDiagram: Sendable, CustomStringConvertible {
    public let name: String
    public var stages: [FlowStage]
    public var modifiers: [String] = []
    
    public var description: String {
        var lines: [String] = []
        
        lines.append("┌─────────────────────────────────────────┐")
        lines.append("│  \(name.padding(toLength: 39, withPad: " ", startingAt: 0))│")
        lines.append("└─────────────────────────────────────────┘")
        
        for stage in stages {
            lines.append("                   │")
            lines.append("                   ▼")
            lines.append(contentsOf: stage.render())
        }
        
        if !modifiers.isEmpty {
            lines.append("")
            lines.append("Modifiers: \(modifiers.joined(separator: ", "))")
        }
        
        return lines.joined(separator: "\n")
    }
}

public enum FlowStage: Sendable {
    case agent(name: String, tools: [String])
    case chat(instructions: String)
    case `guard`(phase: GuardPhase, guardrails: [String])
    case transform(phase: TransformPhase)
    case route(strategy: String, branches: [(String, ExecutionFlowDiagram)])
    case parallel(branches: [(String, ExecutionFlowDiagram)])
    case subAgent(name: String)
    case planning
    
    func render() -> [String] {
        // Rendering implementation...
    }
}
```

---

## Part 10: Implementation Phases

### Phase 1: Core Infrastructure

**Files:**
- `Sources/SwiftAgents/DSL/Core/Agent.swift`
- `Sources/SwiftAgents/DSL/Core/AgentBehavior.swift`
- `Sources/SwiftAgents/DSL/Core/ExecutionContext.swift`
- `Sources/SwiftAgents/DSL/Core/AgentEnvironment.swift`
- Rename existing `Agent` protocol to `AgentCore`

**Tasks:**
1. Define `Agent` protocol (DSL)
2. Rename existing `Agent` to `AgentCore`
3. Define `AgentBehavior` protocol
4. Implement `ExecutionContext` with typed storage
5. Implement `AgentEnvironment` for configuration propagation

### Phase 2: Agent Behaviors

**Files:**
- `Sources/SwiftAgents/DSL/Behaviors/AgentBehavior.swift` (primary)
- `Sources/SwiftAgents/DSL/Behaviors/ChatBehavior.swift`
- `Sources/SwiftAgents/DSL/Behaviors/ToolCallingBehavior.swift`
- `Sources/SwiftAgents/DSL/Behaviors/PlannerBehavior.swift`

**Tasks:**
1. Implement `AgentBody` (ReAct-style primary agent)
2. Create `Agent` typealias
3. Implement `Chat`, `ToolCallingAgent`, `Planner`

### Phase 3: Flow Control Structures

**Files:**
- `Sources/SwiftAgents/DSL/Flow/Guard.swift`
- `Sources/SwiftAgents/DSL/Flow/Transform.swift`
- `Sources/SwiftAgents/DSL/Flow/Sequential.swift`
- `Sources/SwiftAgents/DSL/Flow/Parallel.swift`
- `Sources/SwiftAgents/DSL/Flow/Route.swift`

**Tasks:**
1. Implement `Guard` with input/output phases
2. Implement `Transform`
3. Implement `Sequential`, `Parallel`, `Route`
4. Implement routing strategies (rules, LLM, semantic)

### Phase 4: Modifiers

**Files:**
- `Sources/SwiftAgents/DSL/Modifiers/MemoryModifier.swift`
- `Sources/SwiftAgents/DSL/Modifiers/RetryModifier.swift`
- `Sources/SwiftAgents/DSL/Modifiers/TimeoutModifier.swift`
- `Sources/SwiftAgents/DSL/Modifiers/EnvironmentModifier.swift`
- `Sources/SwiftAgents/DSL/Modifiers/TracingModifier.swift`

### Phase 5: Result Builders

**Files:**
- `Sources/SwiftAgents/DSL/Builders/AgentBuilder.swift`
- `Sources/SwiftAgents/DSL/Builders/ToolBuilder.swift`
- `Sources/SwiftAgents/DSL/Builders/GuardrailBuilder.swift`
- `Sources/SwiftAgents/DSL/Builders/RouteBuilder.swift`

### Phase 6: Diagnostics

**Files:**
- `Sources/SwiftAgents/DSL/Diagnostics/ExecutionFlowDiagram.swift`

### Phase 7: Migration & Documentation

- Rename existing `Agent` protocol to `AgentCore`
- Update all internal usages
- Create migration guide
- Update README with new examples

---

## Part 11: Deferred Features

The following features are planned for future versions:

- **`@Tool` macro**: Zero-boilerplate tool definition
- **`@Generable` integration**: Structured output with Foundation Models
- **API namespacing**: `Agents.ReAct`, etc. (if needed later)
- **Graph-based workflows**: Loops, cycles, conditional edges (separate framework)
- **Visual agent builder**: Xcode integration

---

## Summary

This implementation plan provides a comprehensive roadmap for a SwiftUI-inspired agent DSL that:

1. **Uses structure for flow visibility**: `Guard`, `Transform`, `Sequential`, `Parallel`, `Route`
2. **Uses modifiers for configuration**: `.memory()`, `.retry()`, `.timeout()`, `.environment()`
3. **Renames for clarity**: `Agent` is the DSL protocol, `AgentCore` is the runtime
4. **Progressive disclosure**: Simple agents are trivially simple (Tier 1 → Tier 4)
5. **Explicit routing strategies**: `Route(using: .llm(...))` shows HOW decisions are made
6. **No custom operators**: Standard Swift syntax only
7. **Reading order = execution order**: The code reads like the actual flow
