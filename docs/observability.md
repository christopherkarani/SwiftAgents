# Observability

## Overview

SwiftAgents provides comprehensive observability capabilities for monitoring and debugging agent execution. The observability system includes distributed tracing, performance metrics, and structured logging to help you understand agent behavior, identify bottlenecks, and diagnose issues in production.

Key components:
- **TraceContext**: Distributed tracing with task-local propagation
- **TraceSpan**: Individual operation tracking within traces
- **PerformanceMetrics**: Token usage, latency, and tool execution measurement
- **Tracer**: Pluggable tracing backends for event collection

## Tracing

### TraceContext

`TraceContext` provides distributed tracing capabilities by maintaining a context that propagates automatically through async call chains via Swift's `@TaskLocal` storage. All operations within a trace share the same `traceId`, enabling correlation of related events.

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `name` | `String` | Human-readable name for the trace |
| `traceId` | `UUID` | Unique identifier shared by all spans |
| `groupId` | `String?` | Optional identifier for linking related traces (e.g., session ID) |
| `metadata` | `[String: SendableValue]` | Additional context attached to the trace |
| `startTime` | `Date` | When the trace started |
| `duration` | `TimeInterval` | Elapsed time since start |

#### Creating a Trace Context

Use `withTrace` to establish a new trace context:

```swift
let result = await TraceContext.withTrace(
    "agent-execution",
    groupId: "session-123",
    metadata: ["userId": .string("user-456")]
) {
    // TraceContext.current is available throughout this scope
    guard let context = TraceContext.current else { return }

    // Start tracking an operation
    let span = await context.startSpan("tool-call")

    // ... perform operation ...

    await context.endSpan(span, status: .ok)

    return await performOperation()
}
```

#### Accessing Current Context

The current context is accessible via the static `current` property:

```swift
if let context = TraceContext.current {
    // Access nonisolated properties directly
    let traceId = context.traceId
    let name = context.name

    // Access actor-isolated methods with await
    let spans = await context.getSpans()
}
```

#### Automatic Span Management

Use `withSpan` for automatic span lifecycle management:

```swift
let result = try await context.withSpan("database-query") {
    // Span automatically ends with .ok on success
    try await database.query("SELECT * FROM users")
}
// If an error is thrown, span ends with .error status
```

### TraceSpan

`TraceSpan` represents a single unit of work within a distributed trace. Spans can be nested to form a tree structure representing the call hierarchy.

#### SpanStatus

```swift
public enum SpanStatus: String, Sendable, Codable {
    case active     // Span is in-progress
    case ok         // Completed successfully
    case error      // Completed with an error
    case cancelled  // Cancelled before completion
}
```

#### Span Properties

| Property | Type | Description |
|----------|------|-------------|
| `id` | `UUID` | Unique identifier for this span |
| `parentSpanId` | `UUID?` | Parent span ID for hierarchy |
| `name` | `String` | Human-readable operation name |
| `startTime` | `Date` | When the span started |
| `endTime` | `Date?` | When the span ended (nil if active) |
| `status` | `SpanStatus` | Current status |
| `duration` | `TimeInterval?` | Elapsed time (nil if active) |
| `metadata` | `[String: SendableValue]` | Additional context |

#### Creating and Managing Spans

```swift
// Create a span manually
let span = TraceSpan(
    name: "http-request",
    metadata: ["url": .string("https://api.example.com")]
)

// Create a completed copy
let completedSpan = span.completed(status: .ok)

// Create with explicit parent
let childSpan = TraceSpan(
    parentSpanId: parentSpan.id,
    name: "parse-response"
)
```

#### Within a TraceContext

```swift
await TraceContext.withTrace("request-handling") {
    guard let context = TraceContext.current else { return }

    // Start a span (automatically tracks parent)
    let httpSpan = await context.startSpan(
        "http-request",
        metadata: ["method": .string("POST")]
    )

    // Nested span - httpSpan becomes its parent
    let parseSpan = await context.startSpan("parse-json")
    // ... parse response ...
    await context.endSpan(parseSpan, status: .ok)

    await context.endSpan(httpSpan, status: .ok)

    // Retrieve all spans
    let allSpans = await context.getSpans()
}
```

## Metrics

### PerformanceMetrics

`PerformanceMetrics` captures timing information and parallel execution statistics to measure performance improvements from concurrent tool execution.

#### Metric Properties

| Property | Type | Description |
|----------|------|-------------|
| `totalDuration` | `Duration` | Wall-clock time for entire operation |
| `llmDuration` | `Duration` | Time spent in LLM inference calls |
| `toolDuration` | `Duration` | Time spent in tool executions |
| `toolCount` | `Int` | Number of tools executed |
| `usedParallelExecution` | `Bool` | Whether parallel execution was used |
| `estimatedSequentialDuration` | `Duration?` | Estimated time if tools ran sequentially |
| `parallelSpeedup` | `Double?` | Speedup ratio from parallel execution |

#### Using PerformanceTracker

`PerformanceTracker` is an actor that collects metrics during agent execution:

```swift
let tracker = PerformanceTracker()

// Start tracking
await tracker.start()

// Record an LLM call
let llmStart = ContinuousClock.now
let response = try await llm.generate(prompt)
await tracker.recordLLMCall(duration: ContinuousClock.now - llmStart)

// Record tool execution
let toolStart = ContinuousClock.now
let result = try await tool.execute(input)
await tracker.recordToolExecution(
    duration: ContinuousClock.now - toolStart,
    wasParallel: false
)

// Get final metrics
let metrics = await tracker.finish()

print("Total duration: \(metrics.totalDuration)")
print("LLM time: \(metrics.llmDuration)")
print("Tool time: \(metrics.toolDuration)")
print("Tools executed: \(metrics.toolCount)")
```

#### Tracking Parallel Execution

```swift
// Record parallel tool batch
let parallelStart = ContinuousClock.now
let results = try await executor.executeInParallel(tools)
let parallelDuration = ContinuousClock.now - parallelStart

// Sum individual tool durations for speedup calculation
let sequentialEstimate = results.reduce(.zero) { $0 + $1.duration }

await tracker.recordToolExecution(
    duration: parallelDuration,
    wasParallel: true,
    count: tools.count
)
await tracker.recordSequentialEstimate(sequentialEstimate)

let metrics = await tracker.finish()

if let speedup = metrics.parallelSpeedup {
    print("Parallel execution was \(String(format: "%.2f", speedup))x faster")
}
```

#### Reusing the Tracker

```swift
// Reset for a new operation
await tracker.reset()
await tracker.start()
// ... track new execution ...
```

## Logging

SwiftAgents uses `swift-log` for cross-platform logging compatibility. Category-specific loggers are available for different subsystems.

### Log Categories

| Logger | Usage |
|--------|-------|
| `Log.agents` | Agent lifecycle and execution |
| `Log.memory` | Memory system operations |
| `Log.tracing` | Observability and tracing events |
| `Log.metrics` | Performance and usage metrics |
| `Log.orchestration` | Multi-agent coordination |

### Log Levels

- `.trace` - Detailed debugging information
- `.debug` - Debug information
- `.info` - General information
- `.notice` - Notable events
- `.warning` - Warning conditions
- `.error` - Error conditions
- `.critical` - Critical failures

### Usage Example

```swift
import Logging

// Bootstrap logging once at startup
Log.bootstrap()

// Use category-specific loggers
Log.agents.info("Agent started", metadata: ["name": "\(agentName)"])
Log.memory.debug("Retrieved \(count) memories")
Log.tracing.trace("Span completed", metadata: ["spanId": "\(spanId)"])
Log.metrics.info("Request completed", metadata: ["duration": "\(duration)"])

// Error logging
Log.agents.error("Agent execution failed: \(error.localizedDescription)")
```

### Privacy Considerations

Unlike `os.Logger`, swift-log does not support `privacy:` parameter annotations. Follow these guidelines:

- Do not log sensitive user data, credentials, or PII in production
- Configure log handlers to redact sensitive information at runtime
- Default behavior logs all interpolated values as-is

## AgentTracer

The `Tracer` protocol defines the contract for tracing agent execution events. SwiftAgents provides several implementations for different use cases.

### Tracer Protocol

```swift
public protocol Tracer: Actor, Sendable {
    func trace(_ event: TraceEvent) async
    func flush() async
}
```

### Built-in Tracers

#### NoOpTracer

Discards all events. Useful for testing or disabling tracing:

```swift
let tracer: Tracer = NoOpTracer()
await tracer.trace(event) // Event is silently discarded
```

#### CompositeTracer

Forwards events to multiple child tracers (fan-out pattern):

```swift
let tracer = CompositeTracer(
    tracers: [consoleTracer, fileTracer, telemetryTracer],
    minimumLevel: .info,
    shouldExecuteInParallel: true
)

// Event forwarded to all three tracers in parallel
await tracer.trace(event)
```

#### BufferedTracer

Buffers events and flushes in batches for high-throughput scenarios:

```swift
let buffered = BufferedTracer(
    destination: remoteTracer,
    maxBufferSize: 100,
    flushInterval: .seconds(5)
)

// Start periodic flushing
await buffered.start()

// Events buffered until 100 events or 5 seconds
await buffered.trace(event1)
await buffered.trace(event2)

// Manual flush if needed
await buffered.flush()
```

### TraceEvent

`TraceEvent` represents a detailed trace event with rich metadata:

#### Event Kinds

| Kind | Description |
|------|-------------|
| `.agentStart` | Agent execution started |
| `.agentComplete` | Agent completed successfully |
| `.agentError` | Agent encountered an error |
| `.agentCancelled` | Agent was cancelled |
| `.toolCall` | Tool invocation started |
| `.toolResult` | Tool returned a result |
| `.toolError` | Tool execution failed |
| `.thought` | Agent reasoning step |
| `.decision` | Agent made a decision |
| `.plan` | Agent created/updated a plan |
| `.memoryRead` | Memory read operation |
| `.memoryWrite` | Memory write operation |
| `.checkpoint` | Execution checkpoint |
| `.metric` | Performance metric |
| `.custom` | Custom event |

#### Creating Events

Using convenience constructors:

```swift
let traceId = UUID()

// Agent lifecycle events
let startEvent = TraceEvent.agentStart(
    traceId: traceId,
    agentName: "AssistantAgent"
)

let completeEvent = TraceEvent.agentComplete(
    traceId: traceId,
    spanId: startEvent.spanId,
    agentName: "AssistantAgent",
    duration: 2.5
)

// Tool events
let toolEvent = TraceEvent.toolCall(
    traceId: traceId,
    parentSpanId: startEvent.spanId,
    toolName: "calculator",
    metadata: ["expression": .string("2 + 2")]
)

// Custom events
let customEvent = TraceEvent.custom(
    traceId: traceId,
    message: "Custom checkpoint reached",
    level: .info,
    metadata: ["checkpoint": .string("validation-complete")]
)
```

Using the fluent builder:

```swift
let event = TraceEvent.Builder(
    traceId: traceId,
    kind: .toolResult,
    message: "Calculator returned result"
)
.tool("calculator")
.duration(0.05)
.metadata(key: "result", value: .int(4))
.level(.debug)
.source()
.build()
```

### Custom Tracer Implementation

```swift
public actor TelemetryTracer: Tracer {
    private let endpoint: URL
    private var buffer: [TraceEvent] = []

    public init(endpoint: URL) {
        self.endpoint = endpoint
    }

    public func trace(_ event: TraceEvent) async {
        buffer.append(event)

        if buffer.count >= 50 {
            await flush()
        }
    }

    public func flush() async {
        guard !buffer.isEmpty else { return }

        let events = buffer
        buffer.removeAll()

        // Send to telemetry backend
        do {
            try await sendToBackend(events)
        } catch {
            Log.tracing.error("Failed to send telemetry: \(error)")
        }
    }

    private func sendToBackend(_ events: [TraceEvent]) async throws {
        // Implement HTTP POST to telemetry service
    }
}
```

## Exporting Traces

### Integration with Observability Backends

SwiftAgents traces can be exported to various observability platforms.

#### OpenTelemetry Export

```swift
public actor OpenTelemetryTracer: Tracer {
    private let exporter: SpanExporter

    public init(exporter: SpanExporter) {
        self.exporter = exporter
    }

    public func trace(_ event: TraceEvent) async {
        // Convert TraceEvent to OpenTelemetry span
        let span = convertToOTelSpan(event)
        try? await exporter.export(spans: [span])
    }

    private func convertToOTelSpan(_ event: TraceEvent) -> OTelSpan {
        // Map TraceEvent fields to OpenTelemetry span format
        OTelSpan(
            traceId: event.traceId.uuidString,
            spanId: event.spanId.uuidString,
            parentSpanId: event.parentSpanId?.uuidString,
            name: event.kind.rawValue,
            startTime: event.timestamp,
            endTime: event.duration.map { event.timestamp.addingTimeInterval($0) },
            attributes: convertMetadata(event.metadata)
        )
    }
}
```

#### Structured JSON Export

```swift
public actor JSONFileTracer: Tracer {
    private let fileHandle: FileHandle
    private let encoder = JSONEncoder()

    public init(filePath: String) throws {
        FileManager.default.createFile(atPath: filePath, contents: nil)
        self.fileHandle = try FileHandle(forWritingAtPath: filePath)!
    }

    public func trace(_ event: TraceEvent) async {
        do {
            var data = try encoder.encode(event)
            data.append(contentsOf: "\n".utf8)
            try fileHandle.write(contentsOf: data)
        } catch {
            Log.tracing.error("Failed to write trace: \(error)")
        }
    }

    public func flush() async {
        try? fileHandle.synchronize()
    }
}
```

#### Console Output

```swift
public actor ConsoleTracer: Tracer {
    private let minimumLevel: EventLevel

    public init(minimumLevel: EventLevel = .info) {
        self.minimumLevel = minimumLevel
    }

    public func trace(_ event: TraceEvent) async {
        guard event.level >= minimumLevel else { return }

        let timestamp = ISO8601DateFormatter().string(from: event.timestamp)
        print("[\(timestamp)] [\(event.level)] \(event.kind.rawValue): \(event.message)")

        if let duration = event.duration {
            print("  Duration: \(String(format: "%.2fms", duration * 1000))")
        }

        if !event.metadata.isEmpty {
            print("  Metadata: \(event.metadata)")
        }
    }
}
```

## Best Practices

### 1. Use Structured Trace IDs

Group related operations with consistent trace and group IDs:

```swift
// Use session ID as groupId for correlation
await TraceContext.withTrace(
    "user-request",
    groupId: session.id,
    metadata: ["requestId": .string(requestId)]
) {
    // All operations share the same traceId and groupId
}
```

### 2. Add Meaningful Metadata

Include context that aids debugging:

```swift
let span = await context.startSpan(
    "api-call",
    metadata: [
        "endpoint": .string("/users"),
        "method": .string("GET"),
        "retryCount": .int(attempt)
    ]
)
```

### 3. Use Appropriate Log Levels

- `.trace` - Detailed internal state (development only)
- `.debug` - Diagnostic information
- `.info` - Normal operation milestones
- `.warning` - Recoverable issues
- `.error` - Operation failures
- `.critical` - System-level failures

### 4. Leverage Composite Tracers

Separate concerns by destination:

```swift
let tracer = CompositeTracer(
    tracers: [
        ConsoleTracer(minimumLevel: .debug),      // Development
        JSONFileTracer(filePath: "traces.jsonl"),  // Persistence
        TelemetryTracer(endpoint: telemetryURL)    // Production monitoring
    ],
    minimumLevel: .info
)
```

### 5. Buffer for Performance

Use `BufferedTracer` for high-throughput scenarios:

```swift
let buffered = BufferedTracer(
    destination: remoteTracer,
    maxBufferSize: 100,
    flushInterval: .seconds(5)
)
await buffered.start()
```

### 6. Track Parallel Execution Benefits

Measure speedup from concurrent tool execution:

```swift
if let speedup = metrics.parallelSpeedup, speedup > 1.5 {
    Log.metrics.info("Parallel execution achieved \(speedup)x speedup")
}
```

### 7. Clean Up Resources

Always flush tracers before shutdown:

```swift
defer {
    Task {
        await tracer.flush()
    }
}
```

### 8. Use Type-Erased Tracers for Flexibility

Store heterogeneous tracers in collections:

```swift
let tracers: [AnyTracer] = [
    AnyTracer(consoleTracer),
    AnyTracer(fileTracer)
]
```

### 9. Handle Errors Gracefully

Tracing should not break main execution:

```swift
public func trace(_ event: TraceEvent) async {
    do {
        try await sendEvent(event)
    } catch {
        // Log but don't propagate - tracing failure shouldn't break the app
        Log.tracing.warning("Trace failed: \(error.localizedDescription)")
    }
}
```

### 10. Test with NoOpTracer

Disable tracing overhead in unit tests:

```swift
let agent = Agent(tracer: NoOpTracer())
// Tests run without tracing overhead
```
