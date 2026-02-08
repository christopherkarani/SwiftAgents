# Streaming

## Overview

Swarm provides real-time event streaming for building responsive UIs. As agents execute, they emit `AgentEvent` values that allow your application to display thinking processes, tool executions, and results as they happen.

Streaming enables:
- **Responsive UIs**: Show progress immediately instead of waiting for completion
- **Transparency**: Display the agent's reasoning and decision-making process
- **Interactivity**: React to events in real-time (e.g., cancel long-running operations)
- **Debugging**: Observe the full execution flow during development

## AgentEvent Types

The `AgentEvent` enum represents all possible events emitted during agent execution. Events are grouped by category:

### Lifecycle Events

| Event | Description |
|-------|-------------|
| `.started(input:)` | Agent execution has begun with the given input |
| `.completed(result:)` | Agent execution completed successfully with `AgentResult` |
| `.failed(error:)` | Agent execution failed with an `AgentError` |
| `.cancelled` | Agent execution was cancelled by the caller |
| `.guardrailFailed(error:)` | A guardrail validation failed |

### Thinking Events

| Event | Description |
|-------|-------------|
| `.thinking(thought:)` | Agent's complete reasoning step (ReAct "Thought") |
| `.thinkingPartial(partialThought:)` | Partial thought during streaming (incremental) |

### Tool Events

| Event | Description |
|-------|-------------|
| `.toolCallStarted(call:)` | Agent is invoking a tool (ReAct "Action") |
| `.toolCallCompleted(call:result:)` | Tool execution finished (ReAct "Observation") |
| `.toolCallFailed(call:error:)` | Tool execution failed with error |

### Output Events

| Event | Description |
|-------|-------------|
| `.outputToken(token:)` | Single token of final output (fine-grained streaming) |
| `.outputChunk(chunk:)` | Chunk of final output (larger than single token) |

### Iteration Events

| Event | Description |
|-------|-------------|
| `.iterationStarted(number:)` | New iteration in the reasoning loop began |
| `.iterationCompleted(number:)` | Iteration completed |

### Decision Events

| Event | Description |
|-------|-------------|
| `.decision(decision:options:)` | Agent made a decision with optional alternatives |
| `.planUpdated(plan:stepCount:)` | Agent created or updated an execution plan |

### Handoff Events

| Event | Description |
|-------|-------------|
| `.handoffRequested(fromAgent:toAgent:reason:)` | Agent requested handoff to another agent |
| `.handoffCompleted(fromAgent:toAgent:)` | Handoff between agents completed |
| `.handoffStarted(from:to:input:)` | Handoff initiated with input data |
| `.handoffCompletedWithResult(from:to:result:)` | Handoff completed with result |
| `.handoffSkipped(from:to:reason:)` | Handoff was skipped (disabled or unavailable) |

### Guardrail Events

| Event | Description |
|-------|-------------|
| `.guardrailStarted(name:type:)` | Guardrail check began |
| `.guardrailPassed(name:type:)` | Guardrail check passed |
| `.guardrailTriggered(name:type:message:)` | Guardrail tripwire was triggered |

### Memory Events

| Event | Description |
|-------|-------------|
| `.memoryAccessed(operation:count:)` | Memory was read, written, searched, or cleared |

### LLM Events

| Event | Description |
|-------|-------------|
| `.llmStarted(model:promptTokens:)` | LLM inference call began |
| `.llmCompleted(model:promptTokens:completionTokens:duration:)` | LLM inference completed |

## Supporting Types

### ToolCall

Represents a tool invocation by the agent:

```swift
public struct ToolCall: Sendable, Equatable, Identifiable, Codable {
    public let id: UUID
    public let toolName: String
    public let arguments: [String: SendableValue]
    public let timestamp: Date
}
```

### ToolResult

Represents the outcome of a tool execution:

```swift
public struct ToolResult: Sendable, Equatable, Codable {
    public let callId: UUID
    public let isSuccess: Bool
    public let output: SendableValue
    public let duration: Duration
    public let errorMessage: String?
}
```

### GuardrailType

Types of guardrail checks:

```swift
public enum GuardrailType: String, Sendable, Codable {
    case input       // Validates agent input
    case output      // Validates agent output
    case toolInput   // Validates tool arguments
    case toolOutput  // Validates tool results
}
```

### MemoryOperation

Types of memory operations:

```swift
public enum MemoryOperation: String, Sendable, Codable {
    case read
    case write
    case search
    case clear
}
```

## Streaming API

### Basic Streaming

Stream events from an agent using `for await`:

```swift
for try await event in agent.stream("What's 2+2?") {
    switch event {
    case .started(let input):
        print("Started with: \(input)")
    case .thinking(let thought):
        print("Thinking: \(thought)")
    case .toolCallStarted(let call):
        print("Calling tool: \(call.toolName)")
    case .completed(let result):
        print("Result: \(result.output)")
    case .failed(let error):
        print("Error: \(error)")
    default:
        break
    }
}
```

### Event Handling

Handle specific event categories for different UI needs:

```swift
for try await event in agent.stream(prompt) {
    switch event {
    // Show reasoning process
    case .thinking(let thought):
        await updateThinkingUI(thought)

    case .thinkingPartial(let partial):
        await appendToThinkingUI(partial)

    // Show tool activity
    case .toolCallStarted(let call):
        await showToolSpinner(for: call.toolName)

    case .toolCallCompleted(let call, let result):
        await hideToolSpinner(for: call.toolName)
        await showToolResult(result)

    case .toolCallFailed(let call, let error):
        await hideToolSpinner(for: call.toolName)
        await showToolError(call.toolName, error)

    // Stream output tokens
    case .outputToken(let token):
        await appendToOutput(token)

    case .outputChunk(let chunk):
        await appendToOutput(chunk)

    // Final states
    case .completed(let result):
        await finalizeOutput(result)

    case .failed(let error):
        await showError(error)

    case .cancelled:
        await showCancelled()

    default:
        break
    }
}
```

### Filtering Events

Process only events you care about:

```swift
// Only handle output events for a simple streaming display
for try await event in agent.stream(prompt) {
    if case .outputChunk(let chunk) = event {
        print(chunk, terminator: "")
    }
}
print() // Final newline

// Collect all tool calls
var toolCalls: [ToolCall] = []
for try await event in agent.stream(prompt) {
    if case .toolCallStarted(let call) = event {
        toolCalls.append(call)
    }
}
```

## StreamHelper

`StreamHelper` provides safe stream creation utilities with bounded buffers and proper cancellation handling.

### Creating Streams

Basic bounded stream:

```swift
let (stream, continuation) = StreamHelper.makeStream()

// Use the continuation to yield events
continuation.yield(.started(input: "Hello"))
continuation.yield(.completed(result: result))
continuation.finish() // Always call finish!
```

### Tracked Streams

Create streams with automatic task tracking:

```swift
let stream = StreamHelper.makeTrackedStream { continuation in
    continuation.yield(.started(input: input))

    let result = try await performWork()

    continuation.yield(.completed(result: result))
    continuation.finish() // REQUIRED - consumers hang without this!
}
```

### Actor-Isolated Streams

Create streams from actor methods:

```swift
actor MyAgent {
    func stream(_ input: String) -> AsyncThrowingStream<AgentEvent, Error> {
        StreamHelper.makeTrackedStream(for: self) { agent, continuation in
            continuation.yield(.started(input: input))
            let result = try await agent.run(input)
            continuation.yield(.completed(result: result))
            continuation.finish()
        }
    }
}
```

### Buffer Configuration

Control memory usage with buffer size:

```swift
// Default buffer: 100 events
let (stream, continuation) = StreamHelper.makeStream()

// Custom buffer size
let (stream, continuation) = StreamHelper.makeStream(bufferSize: 50)

// Tracked stream with custom buffer
let stream = StreamHelper.makeTrackedStream(bufferSize: 200) { continuation in
    // ...
}
```

## SwiftUI Integration

### Observable Pattern

Use `@Observable` for SwiftUI state management:

```swift
import SwiftUI

@Observable
@MainActor
class ChatViewModel {
    var messages: [ChatMessage] = []
    var currentResponse: String = ""
    var isStreaming = false
    var error: Error?

    private let agent: Agent

    init(agent: Agent) {
        self.agent = agent
    }

    func send(_ prompt: String) async {
        // Add user message
        messages.append(ChatMessage(role: .user, content: prompt))
        currentResponse = ""
        isStreaming = true
        error = nil

        do {
            for try await event in agent.stream(prompt) {
                handleEvent(event)
            }
        } catch {
            self.error = error
        }

        isStreaming = false
    }

    private func handleEvent(_ event: AgentEvent) {
        switch event {
        case .outputChunk(let chunk):
            currentResponse += chunk

        case .outputToken(let token):
            currentResponse += token

        case .completed(let result):
            messages.append(ChatMessage(role: .assistant, content: result.output))
            currentResponse = ""

        case .toolCallStarted(let call):
            // Could show tool indicator in UI
            break

        default:
            break
        }
    }
}
```

### Chat View Implementation

```swift
struct ChatView: View {
    @State private var viewModel: ChatViewModel
    @State private var inputText = ""

    init(agent: Agent) {
        _viewModel = State(initialValue: ChatViewModel(agent: agent))
    }

    var body: some View {
        VStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message)
                    }

                    // Show streaming response
                    if !viewModel.currentResponse.isEmpty {
                        StreamingBubble(text: viewModel.currentResponse)
                    }
                }
                .padding()
            }

            // Input area
            HStack {
                TextField("Message", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .disabled(viewModel.isStreaming)

                Button("Send") {
                    let prompt = inputText
                    inputText = ""
                    Task {
                        await viewModel.send(prompt)
                    }
                }
                .disabled(inputText.isEmpty || viewModel.isStreaming)
            }
            .padding()
        }
    }
}

struct StreamingBubble: View {
    let text: String

    var body: some View {
        HStack {
            Text(text)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            Spacer()
        }
    }
}
```

### Cancellation Support

Allow users to cancel streaming operations:

```swift
@Observable
@MainActor
class ChatViewModel {
    var isStreaming = false
    private var streamTask: Task<Void, Never>?

    func send(_ prompt: String) {
        streamTask = Task {
            isStreaming = true
            defer { isStreaming = false }

            do {
                for try await event in agent.stream(prompt) {
                    // Check for cancellation
                    try Task.checkCancellation()
                    handleEvent(event)
                }
            } catch is CancellationError {
                // User cancelled - handle gracefully
            } catch {
                self.error = error
            }
        }
    }

    func cancel() {
        streamTask?.cancel()
        streamTask = nil
    }
}
```

## Error Handling

### Stream Failures

Handle errors during streaming:

```swift
do {
    for try await event in agent.stream(prompt) {
        switch event {
        case .failed(let error):
            // Agent-level failure
            handleAgentError(error)

        case .toolCallFailed(let call, let error):
            // Tool-level failure (agent may continue)
            handleToolError(call, error)

        case .guardrailFailed(let error):
            // Guardrail blocked the request
            handleGuardrailError(error)

        default:
            handleEvent(event)
        }
    }
} catch {
    // Stream-level failure (network, etc.)
    handleStreamError(error)
}
```

### Error Recovery

Implement retry logic for transient failures:

```swift
func streamWithRetry(_ prompt: String, maxRetries: Int = 3) async throws -> AgentResult {
    var lastError: Error?

    for attempt in 1...maxRetries {
        do {
            var result: AgentResult?

            for try await event in agent.stream(prompt) {
                if case .completed(let r) = event {
                    result = r
                }
            }

            if let result = result {
                return result
            }
        } catch {
            lastError = error

            // Exponential backoff
            if attempt < maxRetries {
                try await Task.sleep(for: .seconds(pow(2, Double(attempt - 1))))
            }
        }
    }

    throw lastError ?? AgentError.unknown
}
```

## Best Practices

### 1. Always Call finish()

When creating streams with `StreamHelper`, always call `continuation.finish()`:

```swift
// Correct
StreamHelper.makeTrackedStream { continuation in
    continuation.yield(.started(input: input))
    let result = try await work()
    continuation.yield(.completed(result: result))
    continuation.finish() // Required!
}

// Wrong - consumers will hang forever
StreamHelper.makeTrackedStream { continuation in
    continuation.yield(.started(input: input))
    let result = try await work()
    continuation.yield(.completed(result: result))
    // Missing finish() - deadlock!
}
```

### 2. Use Bounded Buffers

Always use `StreamHelper` instead of creating unbounded streams:

```swift
// Good - bounded buffer prevents memory exhaustion
let (stream, continuation) = StreamHelper.makeStream()

// Avoid - unbounded buffer can exhaust memory
let (stream, continuation) = AsyncThrowingStream.makeStream()
```

### 3. Handle All Event Types

Use a default case but log unknown events for debugging:

```swift
for try await event in agent.stream(prompt) {
    switch event {
    case .started: handleStarted()
    case .completed: handleCompleted()
    case .failed: handleFailed()
    // ... other cases
    default:
        // Log for debugging, don't crash
        logger.debug("Unhandled event: \(event)")
    }
}
```

### 4. Update UI on Main Actor

Ensure UI updates happen on the main thread:

```swift
@MainActor
class ViewModel {
    var output = ""

    func stream(_ prompt: String) async {
        for try await event in agent.stream(prompt) {
            // Already on MainActor - safe to update UI
            if case .outputChunk(let chunk) = event {
                output += chunk
            }
        }
    }
}
```

### 5. Support Cancellation

Always check for cancellation in long-running streams:

```swift
for try await event in agent.stream(prompt) {
    try Task.checkCancellation()
    // Process event...
}
```

### 6. Clean Up Resources

Use defer for cleanup when streaming:

```swift
func processStream() async throws {
    isStreaming = true
    defer { isStreaming = false }

    for try await event in agent.stream(prompt) {
        // Process events...
    }
}
```

### 7. Provide Visual Feedback

Show users what's happening during long operations:

```swift
for try await event in agent.stream(prompt) {
    switch event {
    case .thinking:
        statusMessage = "Thinking..."
    case .toolCallStarted(let call):
        statusMessage = "Using \(call.toolName)..."
    case .outputChunk:
        statusMessage = "Generating response..."
    default:
        break
    }
}
```

### 8. Batch UI Updates

For high-frequency token streams, consider batching updates:

```swift
var buffer = ""
var lastUpdate = Date()

for try await event in agent.stream(prompt) {
    if case .outputToken(let token) = event {
        buffer += token

        // Update UI at most 30 times per second
        if Date().timeIntervalSince(lastUpdate) > 0.033 {
            await updateUI(buffer)
            buffer = ""
            lastUpdate = Date()
        }
    }
}

// Flush remaining buffer
if !buffer.isEmpty {
    await updateUI(buffer)
}
```
