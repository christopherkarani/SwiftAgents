# DSL & Operators

## Overview

SwiftAgents provides Swift operators and result builders for composing agents declaratively. This enables a SwiftUI-like DSL for defining complex multi-agent workflows with compile-time type safety.

The DSL consists of three main components:
1. **Pipeline Operators** - Infix operators for chaining agents
2. **Result Builders** - `@resultBuilder` structs for declarative workflow construction
3. **Type-Safe Pipelines** - Generic pipelines with explicit input/output types

---

## Pipeline Operators

SwiftAgents defines custom operators at different precedence levels for composing agents:

```swift
precedencegroup AgentConditionalPrecedence {
    higherThan: AdditionPrecedence
    associativity: left
}

precedencegroup AgentCompositionPrecedence {
    higherThan: AgentConditionalPrecedence
    associativity: left
}

precedencegroup AgentSequentialPrecedence {
    higherThan: AgentCompositionPrecedence
    associativity: left
}
```

### Sequential (`-->`)

Chain agents in sequence where each agent's output becomes the next agent's input.

```swift
// Basic chaining
let chain = researchAgent --> summaryAgent --> validatorAgent
let result = try await chain.run("Analyze quarterly results")

// With output transformers
let configured = chain
    .withTransformer(after: 0, .withMetadata)
    .withTransformer(after: 1, .passthrough)
```

The `-->` operator creates a `SequentialChain` that:
- Passes output from each agent as input to the next
- Accumulates all tool calls and results
- Sums iteration counts across all agents
- Records total execution duration

### Sequential (`~>`)

An alternative sequential operator with higher precedence:

```swift
let sequential = fetchAgent ~> analyzeAgent ~> summarizeAgent
let result = try await sequential.run("Analyze Q4 sales")
```

The `~>` operator creates an `AgentSequence` with similar behavior to `-->`, supporting output transformers between steps.

### Type-Safe Pipeline (`>>>`)

Chain type-safe pipelines with compile-time verification that output types match input types:

```swift
let parse = Pipeline<String, [String]> { $0.components(separatedBy: ",") }
let count = Pipeline<[String], Int> { $0.count }
let format = Pipeline<Int, String> { "Found \($0) items" }

let combined = parse >>> count >>> format
let result = try await combined.execute("a,b,c,d")
// Result: "Found 4 items"
```

The `>>>` operator provides:
- Compile-time type safety between pipeline stages
- Automatic type inference for complex chains
- Error propagation through the pipeline

### Parallel (`&+`)

Run agents concurrently with the same input:

```swift
let parallel = weatherAgent &+ newsAgent &+ stockAgent
let result = try await parallel.run("Get today's info")
```

Configure parallel execution:

```swift
let configured = parallel
    .withMergeStrategy(.concatenate(separator: "\n---\n"))
    .withErrorHandling(.continueOnPartialFailure)

let result = try await configured.run("What's happening today?")
```

The `&+` operator creates a `ParallelComposition` that:
- Executes all agents concurrently using structured concurrency
- Merges results according to the configured strategy
- Handles errors based on the error handling policy

### Conditional/Fallback (`|?`)

Create resilient agent chains with automatic fallback:

```swift
let resilient = primaryAgent |? fallbackAgent
let result = try await resilient.run("Handle request")
```

The `|?` operator creates a `ConditionalFallback` that:
- Attempts the primary agent first
- Falls back to the secondary agent on failure
- Adds metadata indicating whether fallback was used

---

## Result Builders

### OrchestrationBuilder

The primary result builder for constructing multi-agent workflows:

```swift
@resultBuilder
public struct OrchestrationBuilder {
    public static func buildBlock(_ components: OrchestrationStep...) -> [OrchestrationStep]
    public static func buildOptional(_ component: [OrchestrationStep]?) -> [OrchestrationStep]
    public static func buildEither(first component: [OrchestrationStep]) -> [OrchestrationStep]
    public static func buildEither(second component: [OrchestrationStep]) -> [OrchestrationStep]
    public static func buildArray(_ components: [[OrchestrationStep]]) -> [OrchestrationStep]
    public static func buildExpression(_ agent: any Agent) -> OrchestrationStep
    public static func buildExpression(_ step: OrchestrationStep) -> OrchestrationStep
}
```

Usage:

```swift
let workflow = Orchestration {
    Sequential {
        preprocessAgent
        mainAgent
    }

    Parallel(merge: .concatenate) {
        ("analysis", analysisAgent)
        ("summary", summaryAgent)
    }

    Router(fallback: defaultAgent) {
        routeWhen(.contains("weather"), to: weatherAgent)
        routeWhen(.contains("code"), to: codeAgent)
    }
}

let result = try await workflow.run("Process this data")
```

### ParallelBuilder

Constructs arrays of named agents for parallel execution:

```swift
@resultBuilder
public struct ParallelBuilder {
    public static func buildBlock(_ components: (String, any Agent)...) -> [(String, any Agent)]
    public static func buildExpression(_ tuple: (String, any Agent)) -> (String, any Agent)
}
```

Usage:

```swift
Parallel(merge: .structured, maxConcurrency: 2) {
    ("analysis", analysisAgent)
    ("summary", summaryAgent)
    ("critique", critiqueAgent)
}
```

### RouterBuilder

Constructs route arrays for conditional agent routing:

```swift
@resultBuilder
public struct RouterBuilder {
    public static func buildBlock(_ routes: RouteDefinition...) -> [RouteDefinition]
    public static func buildOptional(_ route: RouteDefinition?) -> [RouteDefinition]
    public static func buildEither(first route: RouteDefinition) -> [RouteDefinition]
    public static func buildEither(second route: RouteDefinition) -> [RouteDefinition]
    public static func buildArray(_ routes: [[RouteDefinition]]) -> [RouteDefinition]
    public static func buildExpression(_ route: RouteDefinition) -> RouteDefinition
}
```

Usage:

```swift
Router(fallback: defaultAgent) {
    routeWhen(.contains("weather"), to: weatherAgent)
    routeWhen(.contains("code"), to: codeAgent)
    routeWhen(.startsWith("calculate"), to: calculatorAgent)
}
```

### RouteBuilder

Alternative route builder for `AgentRouter`:

```swift
@resultBuilder
public struct RouteBuilder {
    public static func buildBlock(_ routes: Route...) -> [Route]
    public static func buildOptional(_ route: Route?) -> [Route]
    public static func buildEither(first route: Route) -> [Route]
    public static func buildEither(second route: Route) -> [Route]
    public static func buildArray(_ routes: [[Route]]) -> [Route]
}
```

Usage with conditionals:

```swift
AgentRouter {
    Route(condition: .contains("weather"), agent: weatherAgent)
    Route(condition: .contains("news"), agent: newsAgent)
    if includeDebug {
        Route(condition: .contains("debug"), agent: debugAgent)
    }
}
```

---

## Orchestration Steps

### AgentStep

Wraps an agent for use in orchestration:

```swift
Orchestration {
    myAgent  // Automatically wrapped in AgentStep
    AgentStep(myAgent, name: "CustomName")  // Explicit with name
}
```

### Sequential

Execute steps in sequence with output passing:

```swift
Sequential {
    preprocessAgent
    analysisAgent
    summaryAgent
}

// With transformation between steps
Sequential(transformer: .withMetadata) {
    agentA
    agentB
}
```

Output transformers:
- `.passthrough` - Pass output text directly (default)
- `.withMetadata` - Include metadata in output
- `.custom { result in ... }` - Custom transformation

### Parallel

Run agents concurrently and merge results:

```swift
Parallel(merge: .concatenate) {
    ("analysis", analysisAgent)
    ("summary", summaryAgent)
}

// With concurrency limit
Parallel(merge: .structured, maxConcurrency: 2) {
    ("task1", agent1)
    ("task2", agent2)
    ("task3", agent3)
}
```

Merge strategies:
- `.concatenate` - Join outputs with newlines
- `.first` - Return first completed result
- `.longest` - Return longest output
- `.structured` - Create labeled sections
- `.custom { results in ... }` - Custom merge function

### Router

Route input to different agents based on conditions:

```swift
Router(fallback: defaultAgent) {
    routeWhen(.contains("weather"), to: weatherAgent)
    routeWhen(.contains("code"), to: codeAgent)
    routeWhen(.startsWith("calculate"), to: calculatorAgent)
}
```

### Transform

Apply custom transformations within a workflow:

```swift
Transform { input in
    "Processed: \(input.uppercased())"
}
```

---

## Route Conditions

Built-in conditions for routing:

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

Combine conditions with logical operators:

```swift
let condition = RouteCondition.contains("weather")
    .and(.lengthInRange(5...100))
    .or(.contextHas(key: "location"))
    .not
```

---

## Combining Patterns

### Sequential with Parallel Fan-Out

```swift
let workflow = Orchestration {
    // Pre-process
    preprocessAgent

    // Fan-out to multiple analyzers
    Parallel(merge: .structured) {
        ("sentiment", sentimentAgent)
        ("entities", entityAgent)
        ("topics", topicAgent)
    }

    // Merge and summarize
    summaryAgent
}
```

### Conditional Pipeline

```swift
let workflow = Orchestration {
    Router(fallback: generalAgent) {
        routeWhen(.contains("urgent").and(.lengthInRange(0...50)), to: quickResponseAgent)
        routeWhen(.contains("technical"), to: technicalAgent)
        routeWhen(.contains("billing"), to: billingAgent)
    }

    // Post-process all results
    formatterAgent
}
```

### Agent Pipeline with Type Safety

```swift
// Convert agents to pipelines for type-safe composition
let pipeline = researchAgent.asOutputPipeline()
    >>> transform { $0.uppercased() }
    >>> summaryAgent.asOutputPipeline()

let result = try await pipeline.execute("Research topic")
```

### Resilient Parallel Execution

```swift
let resilientParallel = (primaryAPI &+ secondaryAPI)
    .withMergeStrategy(.firstSuccess)
    .withErrorHandling(.continueOnPartialFailure)

// Or with explicit fallback
let withFallback = (primaryAgent |? cachedAgent) &+ liveAgent
```

---

## Type Safety

Swift's type system ensures correctness at compile time:

### Pipeline Type Matching

```swift
let parse = Pipeline<String, [String]> { ... }
let count = Pipeline<[String], Int> { ... }
let format = Pipeline<Int, String> { ... }

// Compiles - types match
let valid = parse >>> count >>> format

// Does not compile - Int cannot connect to [String]
// let invalid = count >>> parse
```

### Sendable Conformance

All orchestration types conform to `Sendable` for safe concurrent use:

```swift
public struct Sequential: OrchestrationStep, Sendable { ... }
public struct Parallel: OrchestrationStep, Sendable { ... }
public struct RouteCondition: Sendable { ... }
```

### Actor Isolation

Composition types use actors for thread-safe mutable state:

```swift
public actor ParallelComposition: Agent { ... }
public actor AgentSequence: Agent { ... }
public actor ConditionalFallback: Agent { ... }
```

---

## Merge Strategies

### Built-in Strategies

```swift
// Concatenate outputs with separator
MergeStrategies.Concatenate(separator: "\n\n", shouldIncludeAgentNames: true)

// Return first result (alphabetically)
MergeStrategies.First()

// Return longest output
MergeStrategies.Longest()

// JSON structure with all outputs
MergeStrategies.Structured()

// Custom merge function
MergeStrategies.Custom { results in
    let output = results.values.map(\.output).joined(separator: " | ")
    return AgentResult(output: output)
}
```

### Operator-Based Merge Strategies

```swift
public enum ParallelMergeStrategy: Sendable {
    case firstSuccess
    case lastSuccess
    case all
    case concatenate(separator: String)
    case custom(@Sendable ([AgentResult]) -> String)
}
```

---

## Error Handling

### Parallel Error Handling

```swift
public enum ParallelErrorHandling: Sendable {
    case failFast              // Fail immediately on first error
    case continueOnPartialFailure  // Continue, fail only if all fail
    case collectErrors         // Collect all errors, continue execution
}
```

Usage:

```swift
let parallel = (agent1 &+ agent2 &+ agent3)
    .withErrorHandling(.continueOnPartialFailure)
```

### Pipeline Error Handling

```swift
let safePipeline = riskyPipeline
    .catchError("default") { error in
        print("Pipeline failed: \(error)")
    }

// Or with transformation
let recovered = pipeline.catchError { error in
    try await fallbackPipeline.execute(error.localizedDescription)
}
```

### Retry and Timeout

```swift
let resilient = pipeline
    .retry(attempts: 3, delay: .seconds(1))
    .timeout(.seconds(30))
```

---

## Best Practices

### 1. Prefer Declarative Composition

```swift
// Preferred - declarative
let workflow = Orchestration {
    Sequential {
        agentA
        agentB
    }
}

// Avoid - imperative
var result = try await agentA.run(input)
result = try await agentB.run(result.output)
```

### 2. Use Type-Safe Pipelines for Data Transformation

```swift
// Type-safe transformations
let pipeline = parseAgent.asPipeline()
    >>> transform { result in result.output.uppercased() }
    >>> extractOutput()
```

### 3. Keep Chains Manageable

```swift
// Good - short, focused chains
let pipeline = parseJSON >>> extractField("data") >>> validateSchema

// Avoid - very long chains (50+ steps)
// Consider refactoring into multiple pipelines
```

### 4. Use Named Agents in Parallel Execution

```swift
// Preferred - named agents for debugging
Parallel {
    ("analyzer", analyzerAgent)
    ("summarizer", summarizerAgent)
}

// Less useful - auto-generated names
ParallelGroup(agents: [agent1, agent2, agent3])
```

### 5. Configure Error Handling Appropriately

```swift
// Critical path - fail fast
let critical = (agent1 &+ agent2)
    .withErrorHandling(.failFast)

// Best-effort - continue on partial failure
let bestEffort = (optional1 &+ optional2)
    .withErrorHandling(.continueOnPartialFailure)
```

### 6. Use Output Transformers for Clean Data Flow

```swift
let chain = researchAgent --> summaryAgent
    .withTransformer(after: 0, OutputTransformer { result in
        // Extract only relevant data for next step
        result.output.components(separatedBy: "\n").first ?? ""
    })
```

---

## Memory Considerations

Pipeline composition creates nested closures. For long chains:

- **Short chains (<=10 steps)**: Negligible overhead
- **Medium chains (10-50 steps)**: Acceptable, monitor if transforms capture large contexts
- **Long chains (50+ steps)**: Consider refactoring into batched operations

The capture chain is deallocated after pipeline execution completes.
