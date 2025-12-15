# SwiftGraph: LangGraph-Style Framework for SwiftAgents

## Overview

**SwiftGraph** is a graph-based workflow orchestration module that brings LangGraph-style capabilities to SwiftAgents. It enables cyclic workflows, conditional routing, state checkpointing, and human-in-the-loop patterns for building sophisticated multi-agent applications.

### Motivation

While SwiftAgents provides powerful agent primitives (`ReActAgent`, `SupervisorAgent`, `SequentialChain`), it lacks support for:

- **Cyclic workflows**: Iterative refinement patterns (research → evaluate → if poor quality, research again)
- **State-based routing**: Route to different nodes based on accumulated state, not just input
- **Execution checkpointing**: Save and restore graph state for long-running workflows
- **Human-in-the-loop**: Interrupt execution for human review and resume

SwiftGraph fills these gaps while building on SwiftAgents' existing abstractions.

---

## Comparison: SwiftAgents vs SwiftGraph

| Feature | Current SwiftAgents | SwiftGraph Addition |
|---------|---------------------|---------------------|
| Cyclic workflows | Not supported | Full cycle support with termination conditions |
| Conditional routing | `AgentRouter` (input-based only) | State-based routing after node execution |
| State checkpointing | Memory persistence only | Full graph execution state save/restore |
| Human-in-the-loop | Manual implementation | Built-in interrupt/resume pattern |
| Subgraphs | Not available | Graphs as nodes in parent graphs |
| Typed state flow | `SendableValue` dictionary | Strongly typed `GraphState` structs |

---

## Architecture

```
SwiftAgents Framework
├── Core/
│   ├── Agent.swift              (existing)
│   ├── AgentResult.swift        (existing)
│   └── AgentConfiguration.swift (existing)
├── Orchestration/
│   ├── Pipeline.swift           (existing)
│   ├── SequentialChain.swift    (existing)
│   ├── SupervisorAgent.swift    (existing)
│   └── AgentContext.swift       (existing - will extend)
├── Memory/
│   └── ...                      (existing)
│
└── Graph/                       ◀── NEW MODULE
    ├── Core/
    │   ├── GraphState.swift
    │   ├── StateGraph.swift
    │   ├── GraphNode.swift
    │   ├── Edge.swift
    │   └── GraphError.swift
    ├── Execution/
    │   ├── CompiledGraph.swift
    │   ├── GraphRunner.swift
    │   ├── GraphEvent.swift
    │   └── CycleDetector.swift
    ├── Checkpoint/
    │   ├── GraphCheckpoint.swift
    │   ├── GraphCheckpointer.swift
    │   ├── MemoryCheckpointer.swift
    │   └── SwiftDataCheckpointer.swift
    ├── DSL/
    │   ├── GraphBuilder.swift
    │   ├── NodeBuilder.swift
    │   └── EdgeBuilder.swift
    └── Nodes/
        ├── FunctionNode.swift
        ├── AgentNode.swift
        └── SubgraphNode.swift
```

---

## Core Abstractions

### 1. GraphState Protocol

The foundation of typed state management:

```swift
/// Protocol for state that flows through a graph.
///
/// GraphState defines the data structure that is passed between nodes
/// and modified throughout graph execution. It must be:
/// - `Sendable`: Safe for concurrent access
/// - `Codable`: Serializable for checkpointing
/// - `Equatable`: Comparable for change detection
public protocol GraphState: Sendable, Codable, Equatable {
    /// The initial state for graph execution.
    static var initial: Self { get }
}
```

**Example:**

```swift
struct ResearchState: GraphState {
    var query: String = ""
    var searchResults: [String] = []
    var summary: String = ""
    var confidence: Double = 0.0
    var iterationCount: Int = 0

    static var initial: ResearchState { ResearchState() }
}
```

### 2. GraphNode Protocol

Nodes represent units of work in the graph:

```swift
/// A node in a state graph that transforms state.
public protocol GraphNode<State>: Sendable {
    associatedtype State: GraphState

    /// The unique name of this node.
    var name: String { get }

    /// Executes the node, transforming the state.
    ///
    /// - Parameters:
    ///   - state: The current graph state.
    ///   - context: Shared context for orchestration.
    /// - Returns: The transformed state.
    func execute(state: State, context: AgentContext) async throws -> State
}
```

### 3. Edge Types

Edges define transitions between nodes:

```swift
/// Edges connecting nodes in a state graph.
public enum Edge<State: GraphState>: Sendable {
    /// Always transitions to the target node.
    case unconditional(from: String, to: String)

    /// Transitions based on state evaluation.
    case conditional(from: String, router: @Sendable (State) -> String)

    /// Terminates graph execution.
    case end(from: String)
}
```

### 4. StateGraph Container

The main graph definition type:

```swift
/// A directed graph with typed state for workflow orchestration.
public struct StateGraph<State: GraphState>: Sendable {
    /// Registered nodes by name.
    public private(set) var nodes: [String: any GraphNode<State>]

    /// Edges defining transitions.
    public private(set) var edges: [Edge<State>]

    /// The entry point node name.
    public var entryPoint: String

    /// Node names where execution terminates.
    public var finishPoints: Set<String>

    /// Compiles the graph for execution.
    public func compile() throws -> CompiledGraph<State>
}
```

### 5. CompiledGraph (Actor)

The execution engine:

```swift
/// Compiled graph ready for execution.
///
/// CompiledGraph is an actor to ensure thread-safe state management
/// during concurrent execution. It provides multiple execution modes:
/// - `run()`: Execute to completion
/// - `stream()`: Stream events during execution
/// - `runUntil()`: Execute until a breakpoint for human-in-the-loop
/// - `resume()`: Resume from a checkpoint
public actor CompiledGraph<State: GraphState> {
    /// Executes the graph to completion.
    public func run(initialState: State) async throws -> State

    /// Streams events during execution.
    public func stream(initialState: State) -> AsyncThrowingStream<GraphEvent<State>, Error>

    /// Executes until reaching a breakpoint node.
    public func runUntil(state: State, breakpoint: String) async throws -> GraphCheckpoint<State>

    /// Resumes execution from a checkpoint.
    public func resume(from checkpoint: GraphCheckpoint<State>) async throws -> State
}
```

### 6. GraphCheckpoint

Serializable execution state:

```swift
/// A snapshot of graph execution state that can be saved and restored.
public struct GraphCheckpoint<State: GraphState>: Codable, Sendable {
    /// Unique identifier for this checkpoint.
    public let checkpointId: UUID

    /// The state at checkpoint time.
    public let state: State

    /// The current node when checkpointed.
    public let currentNode: String

    /// Nodes executed before checkpoint.
    public let executionPath: [String]

    /// When the checkpoint was created.
    public let timestamp: Date

    /// Additional metadata.
    public let metadata: [String: String]
}
```

---

## DSL Design

### Result Builder Syntax (Primary)

SwiftUI-inspired declarative graph definition:

```swift
let graph = StateGraph<ChatState> {
    // Define nodes
    Node("classifier") { state, context in
        var newState = state
        newState.intent = await classifyIntent(state.input)
        return newState
    }

    AgentNode("responder", agent: chatAgent)

    Node("validator") { state, _ in
        var newState = state
        newState.isValid = validate(state.response)
        return newState
    }

    // Define edges
    Edge(from: .start, to: "classifier")

    ConditionalEdge(from: "classifier") { state in
        switch state.intent {
        case .question: return "responder"
        case .command: return "executor"
        default: return .end
        }
    }

    Edge(from: "responder", to: "validator")

    // Cycle back if validation fails
    ConditionalEdge(from: "validator") { state in
        state.isValid ? .end : "responder"
    }
}
```

### Fluent Builder (Secondary)

Chainable method API:

```swift
let graph = StateGraph<ChatState>()
    .addNode("classifier", node: classifierNode)
    .addNode("responder", agent: chatAgent)
    .addEdge(from: .start, to: "classifier")
    .addConditionalEdge(from: "classifier") { state in
        state.intent == .question ? "responder" : .end
    }
    .setFinishPoint("responder")
```

---

## Execution Model

### Basic Execution

```swift
// Compile and run
let compiled = try graph.compile()

var state = ResearchState.initial
state.query = "Swift concurrency best practices"

let result = try await compiled.run(initialState: state)
print(result.summary)
```

### Streaming Execution

```swift
for try await event in compiled.stream(initialState: state) {
    switch event {
    case .nodeStarted(let nodeName, let currentState):
        print("Starting: \(nodeName)")
    case .nodeCompleted(let nodeName, let newState):
        print("Completed: \(nodeName)")
    case .stateUpdated(let state):
        print("State changed: \(state)")
    case .completed(let finalState):
        print("Done: \(finalState)")
    case .failed(let error):
        print("Error: \(error)")
    }
}
```

### Human-in-the-Loop

```swift
// Execute until reaching the "review" node
let checkpoint = try await compiled.runUntil(
    state: initialState,
    breakpoint: "review"
)

// Present to human for review
print("Review needed: \(checkpoint.state.summary)")
let humanApproved = await getUserApproval()

// Modify state if needed
var modifiedState = checkpoint.state
modifiedState.humanApproved = humanApproved

// Resume execution
let checkpoint2 = GraphCheckpoint(
    checkpointId: UUID(),
    state: modifiedState,
    currentNode: checkpoint.currentNode,
    executionPath: checkpoint.executionPath,
    timestamp: Date(),
    metadata: [:]
)

let finalState = try await compiled.resume(from: checkpoint2)
```

### Checkpointing with Persistence

```swift
// Create persistent checkpointer
let checkpointer = try SwiftDataCheckpointer<ResearchState>()

// Execute with automatic checkpointing
let result = try await compiled.run(
    initialState: state,
    checkpointer: checkpointer,
    checkpointInterval: .afterEachNode
)

// Later: restore from checkpoint
let savedCheckpoint = try await checkpointer.load(id: checkpointId)
let resumed = try await compiled.resume(from: savedCheckpoint)
```

---

## Cycle Detection & Termination

Cycles are allowed but must terminate:

```swift
/// Configuration for cycle handling.
public struct CycleConfiguration: Sendable {
    /// Maximum iterations before forced termination.
    public var maxIterations: Int = 100

    /// Maximum time before timeout.
    public var timeout: Duration = .seconds(300)

    /// Whether to throw on max iterations (vs. return last state).
    public var throwOnMaxIterations: Bool = true
}
```

**Example with termination condition:**

```swift
ConditionalEdge(from: "evaluator") { state in
    // Terminate after 5 iterations regardless of quality
    if state.iterationCount >= 5 {
        return .end
    }
    // Otherwise, decide based on confidence
    return state.confidence > 0.8 ? .end : "researcher"
}
```

---

## Integration with Existing SwiftAgents

### Agents as Nodes

```swift
// Any Agent can become a graph node
let searchAgent = ReActAgent { /* ... */ }
let summaryAgent = ReActAgent { /* ... */ }

let graph = StateGraph<ResearchState> {
    AgentNode("searcher", agent: searchAgent)
    AgentNode("summarizer", agent: summaryAgent)
    // ...
}
```

### Multi-Provider Support

Each node can use a different inference provider:

```swift
AgentNode("local-classifier", agent: classifierAgent)
    .inferenceProvider(FoundationModelsProvider())

AgentNode("cloud-generator", agent: generatorAgent)
    .inferenceProvider(OpenAIProvider(apiKey: key))
```

### AgentContext Integration

```swift
Node("contextual") { state, context in
    // Access shared context
    let userId = await context.get("user_id")?.stringValue

    // Record execution
    await context.recordExecution(agentName: "contextual")

    // Access memory if configured
    if let memory = context.memory {
        let history = await memory.getContext(for: state.query, tokenLimit: 2000)
    }

    return state
}
```

### Subgraph Composition

```swift
// Define a reusable subgraph
let researchSubgraph = StateGraph<ResearchState> { /* ... */ }

// Use as a node in parent graph
let parentGraph = StateGraph<AppState> {
    SubgraphNode("research", subgraph: researchSubgraph) { appState in
        // Map AppState -> ResearchState
        ResearchState(query: appState.userQuery)
    } mapBack: { researchState, appState in
        // Map result back to AppState
        var newAppState = appState
        newAppState.researchResults = researchState.summary
        return newAppState
    }
}
```

---

## Event Types

```swift
/// Events emitted during graph execution.
public enum GraphEvent<State: GraphState>: Sendable {
    /// Graph execution started.
    case started(initialState: State)

    /// A node began executing.
    case nodeStarted(nodeName: String, state: State)

    /// A node completed execution.
    case nodeCompleted(nodeName: String, newState: State, duration: Duration)

    /// State was updated (may be emitted multiple times per node).
    case stateUpdated(state: State)

    /// An edge was traversed.
    case edgeTraversed(from: String, to: String)

    /// A checkpoint was created.
    case checkpointCreated(checkpoint: GraphCheckpoint<State>)

    /// Graph execution completed.
    case completed(finalState: State, totalDuration: Duration)

    /// Graph execution failed.
    case failed(error: GraphError, lastState: State)
}
```

---

## Error Handling

```swift
/// Errors that can occur during graph execution.
public enum GraphError: Error, Sendable {
    /// A referenced node does not exist.
    case nodeNotFound(name: String)

    /// No entry point defined.
    case noEntryPoint

    /// Conditional edge returned unknown node.
    case invalidEdgeTarget(from: String, target: String)

    /// Maximum iterations exceeded.
    case maxIterationsExceeded(count: Int)

    /// Execution timed out.
    case timeout(duration: Duration)

    /// Graph has no valid path to finish.
    case noPathToFinish

    /// Checkpoint not found.
    case checkpointNotFound(id: UUID)

    /// Node execution failed.
    case nodeExecutionFailed(nodeName: String, underlyingError: Error)

    /// State serialization failed.
    case serializationFailed(reason: String)
}
```

---

## File Structure

```
Sources/SwiftAgents/Graph/
├── Core/
│   ├── GraphState.swift           # GraphState protocol
│   ├── StateGraph.swift           # StateGraph<State> container
│   ├── GraphNode.swift            # GraphNode protocol + FunctionNode
│   ├── Edge.swift                 # Edge types
│   └── GraphError.swift           # Error types
├── Execution/
│   ├── CompiledGraph.swift        # Actor-based execution engine
│   ├── GraphRunner.swift          # High-level runner with config
│   ├── GraphEvent.swift           # Streaming events
│   └── CycleDetector.swift        # Cycle detection + termination
├── Checkpoint/
│   ├── GraphCheckpoint.swift      # Checkpoint structure
│   ├── GraphCheckpointer.swift    # Checkpointer protocol
│   ├── MemoryCheckpointer.swift   # In-memory (testing)
│   └── SwiftDataCheckpointer.swift # Persistent (production)
├── DSL/
│   ├── GraphBuilder.swift         # @resultBuilder for graphs
│   ├── NodeBuilder.swift          # Node definition helpers
│   └── EdgeBuilder.swift          # Edge definition helpers
├── Nodes/
│   ├── FunctionNode.swift         # Wrap closures as nodes
│   ├── AgentNode.swift            # Wrap Agent protocol
│   └── SubgraphNode.swift         # Nested graph composition
└── Integration/
    ├── AgentContext+Graph.swift   # Context extensions
    └── Graph+Pipeline.swift       # Pipeline interop
```

---

## Implementation Phases

### Phase 1: MVP (Core + Checkpointing + DSL)

**Goal**: Working graph framework with full feature set

**Core Abstractions:**
- `GraphState` protocol with `Codable`, `Sendable`, `Equatable`
- `GraphNode` protocol + `FunctionNode` implementation
- `Edge` enum (unconditional, conditional, end)
- `StateGraph<State>` container
- `GraphError` enum

**Execution Engine:**
- `CompiledGraph` actor with `run()` and `stream()`
- `GraphEvent` for streaming
- Cycle detection with max iterations termination
- Execution path tracking

**Checkpointing:**
- `GraphCheckpoint<State>` structure
- `GraphCheckpointer` protocol
- `MemoryCheckpointer` (in-memory, for testing)
- `runUntil()` and `resume()` methods

**DSL:**
- `@GraphBuilder` result builder
- `@NodeBuilder` for node definitions
- `@EdgeBuilder` for edge definitions
- `.start` and `.end` special identifiers

### Phase 2: Node Types

- `AgentNode` with per-node `InferenceProvider`
- `SubgraphNode` for composition
- Node decorators (timeout, retry)

### Phase 3: Persistence & Integration

- `SwiftDataCheckpointer` for persistent checkpoints
- `AgentContext` graph state integration
- Pipeline interoperability

### Phase 4: Testing & Polish

- Unit tests for all components
- Integration tests with mock agents
- Cycle termination tests
- Checkpoint save/restore tests
- Multi-provider tests

---

## Design Decisions

### 1. Typed State over Dynamic Dictionaries

**Decision**: Use `GraphState` protocol requiring `Codable` conformance.

**Rationale**: Unlike Python's LangGraph which uses dynamic dictionaries, Swift's type system provides compile-time safety. The state schema becomes a contract enforced by the compiler.

**Trade-off**: Less dynamic than Python, but catches errors at compile time.

### 2. Actor-Based Execution

**Decision**: `CompiledGraph` is an actor.

**Rationale**: Ensures thread-safe state management during concurrent operations, following Swift 6 concurrency patterns used throughout SwiftAgents.

### 3. Result Builder DSL (Primary)

**Decision**: SwiftUI-style declarative syntax as the primary API.

**Rationale**: Familiar to Swift developers, provides clean declarative syntax, enables compile-time validation.

### 4. Multi-Provider Support

**Decision**: Each `AgentNode` can have its own `InferenceProvider`.

**Rationale**: Enables hybrid graphs where different nodes use different models (e.g., fast local model for classification, powerful cloud model for generation).

### 5. Full MVP Approach

**Decision**: Implement core execution + checkpointing together.

**Rationale**: Checkpointing is integral to the value proposition; human-in-the-loop patterns require it from day one.

### 6. Integration over Replacement

**Decision**: Build on existing SwiftAgents abstractions.

**Rationale**: Leverage existing `Agent`, `AgentContext`, `Memory` systems rather than creating parallel implementations.

---

## Example: Research Assistant Graph

Complete example demonstrating all features:

```swift
// 1. Define State
struct ResearchState: GraphState {
    var query: String = ""
    var searchResults: [SearchResult] = []
    var summary: String = ""
    var confidence: Double = 0.0
    var needsHumanReview: Bool = false
    var humanApproved: Bool = false
    var iterationCount: Int = 0

    static var initial: ResearchState { ResearchState() }
}

// 2. Define Agents
let searchAgent = ReActAgent {
    Instructions("Search for information on the given query.")
    Tools { WebSearchTool() }
}

let summaryAgent = ReActAgent {
    Instructions("Summarize the search results concisely.")
}

// 3. Build Graph
let researchGraph = StateGraph<ResearchState> {
    // Nodes
    AgentNode("searcher", agent: searchAgent)
        .inferenceProvider(FoundationModelsProvider())

    AgentNode("summarizer", agent: summaryAgent)
        .inferenceProvider(OpenAIProvider(apiKey: apiKey))

    Node("evaluator") { state, _ in
        var newState = state
        newState.confidence = evaluateQuality(state.summary)
        newState.iterationCount += 1
        newState.needsHumanReview = newState.confidence < 0.6
        return newState
    }

    Node("human_review") { state, _ in
        // This node is a breakpoint - execution pauses here
        state
    }

    // Edges
    Edge(from: .start, to: "searcher")
    Edge(from: "searcher", to: "summarizer")
    Edge(from: "summarizer", to: "evaluator")

    ConditionalEdge(from: "evaluator") { state in
        if state.iterationCount >= 3 {
            return state.needsHumanReview ? "human_review" : .end
        }
        if state.confidence > 0.8 {
            return .end
        }
        return "searcher"  // Cycle back for more research
    }

    ConditionalEdge(from: "human_review") { state in
        state.humanApproved ? .end : "searcher"
    }
}

// 4. Execute with Human-in-the-Loop
let compiled = try researchGraph.compile()
let checkpointer = try SwiftDataCheckpointer<ResearchState>()

var state = ResearchState.initial
state.query = "Latest developments in Swift concurrency"

// Run until human review needed
let checkpoint = try await compiled.runUntil(
    state: state,
    breakpoint: "human_review"
)

// Present to user
print("Summary: \(checkpoint.state.summary)")
print("Confidence: \(checkpoint.state.confidence)")

// Get human decision
let approved = await presentForReview(checkpoint.state)

// Resume with human input
var modifiedState = checkpoint.state
modifiedState.humanApproved = approved

let finalCheckpoint = GraphCheckpoint(
    checkpointId: UUID(),
    state: modifiedState,
    currentNode: "human_review",
    executionPath: checkpoint.executionPath,
    timestamp: Date(),
    metadata: [:]
)

let result = try await compiled.resume(from: finalCheckpoint)
print("Final summary: \(result.summary)")
```

---

## Success Criteria

1. **Cycles work correctly**: Graphs with cycles execute and terminate properly
2. **Conditional edges route correctly**: State-based routing works as expected
3. **Checkpoints round-trip**: Save and restore produces identical execution
4. **Human-in-the-loop works**: Interrupt and resume pattern functions correctly
5. **Agents integrate seamlessly**: Existing agents work as graph nodes
6. **Tests pass**: All tests pass with mock agents (Foundation Models unavailable in simulators)
7. **Type safety maintained**: Compile-time errors for type mismatches

---

## References

- [LangGraph Documentation](https://langchain-ai.github.io/langgraph/)
- [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- [Result Builders](https://docs.swift.org/swift-book/LanguageGuide/AdvancedOperators.html#ID630)
- SwiftAgents existing patterns: `Pipeline.swift`, `AgentContext.swift`, `Agent.swift`
