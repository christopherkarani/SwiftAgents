# Why Swarm

Most agent frameworks are Python-first, stringly-typed, and assume every workflow completes in one shot. Swarm makes different bets.

## Data Races Are Compile Errors

Swift 6.2's `StrictConcurrency` is enabled across every Swarm target — agents, memory, workflows, macros, and tests. Non-`Sendable` types crossing actor boundaries is a **build failure**, not a runtime crash.

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

Advanced workflows can use [Hive](https://github.com/christopherkarani/Hive) checkpointing. You can persist state, then resume from a checkpoint ID without restarting from the beginning.

```swift
let result = try await Workflow()
    .step(fetchAgent)
    .step(analyzeAgent)
    .advanced
    .checkpoint(id: "weekly-report", policy: .everyStep)
    .advanced
    .checkpointStore(.fileSystem(directory: checkpointsURL))
    .advanced
    .run("Create this week report")
```

## Workflow Is Fluent

Compose sequential, parallel, and routed flows with a small default API:

```swift
let result = try await Workflow()
    .step(fetchAgent)
    .parallel([bullAgent, bearAgent])
    .route { input in input.contains("risk") ? riskAgent : summaryAgent }
    .run("Analyze this quarter")
```

## On-Device and Cloud — Same API

Foundation Models, Anthropic, OpenAI, Ollama, Gemini, MLX. Swap providers with one line. Your agent code doesn't change.

## Built for Apple Platforms

Native `AsyncThrowingStream` streaming, SwiftData persistence, Accelerate-backed vector memory, OSLog tracing. Swarm is Swift-native, not a Python port.
