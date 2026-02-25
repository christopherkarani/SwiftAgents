# Why Swarm

Most agent frameworks are Python-first, stringly-typed, and assume every workflow completes in one shot. Swarm makes different bets.

## Data Races Are Compile Errors

Swift 6.2's `StrictConcurrency` is enabled across every Swarm target — agents, memory, orchestrators, macros, and tests. Non-`Sendable` types crossing actor boundaries is a **build failure**, not a runtime crash.

```swift
// ❌ Compile error — caught before it ships
struct BrokenAgent: AgentRuntime {
    var cache: NSCache<NSString, NSString>
    // error: stored property 'cache' of 'Sendable'-conforming struct
    //        has non-Sendable type 'NSCache<NSString, NSString>'
}

// ✓ Actor isolation makes shared state safe
actor ResponseCache {
    private var store: [String: String] = [:]
    func set(_ value: String, for key: String) { store[key] = value }
    func get(_ key: String) -> String? { store[key] }
}
```

## Workflows Survive Crashes

Every orchestration compiles to a [Hive](https://github.com/christopherkarani/Hive) DAG with automatic checkpointing. A pipeline that crashes on step 7 of 10 resumes from step 7 — not from the beginning.

```swift
let store = FileSystemWorkflowCheckpointStore(
    directory: .applicationSupportDirectory.appending(path: "checkpoints")
)
```

## Orchestration Is a DSL

Eleven composable step types in a SwiftUI-style `@resultBuilder`:

```swift
// Sequential chain
fetchAgent --> analyzeAgent --> writerAgent

// Type-safe pipeline
Pipeline<String, [String]> { $0.components(separatedBy: "\n") }
    >>> Pipeline<[String], String> { $0.joined(separator: "• ") }

// Dependency DAG
DAGWorkflow(nodes: [
    DAGNode("fetch", agent: fetchAgent),
    DAGNode("refs", agent: refsAgent),
    DAGNode("analyze", agent: analyzeAgent).dependsOn("fetch", "refs"),
    DAGNode("write", agent: writerAgent).dependsOn("analyze"),
])
```

## On-Device and Cloud — Same API

Foundation Models, Anthropic, OpenAI, Ollama, Gemini, MLX. Swap providers with one line. Your agent code doesn't change.

## Built for Apple Platforms

Native `AsyncThrowingStream` streaming, SwiftData persistence, Accelerate-backed vector memory, OSLog tracing. Swarm is Swift-native, not a Python port.
