# Conduit Tool Calling Implementation Plan

## Overview

This document provides a complete implementation plan for adding tool call response parsing to Conduit. Once implemented, SwiftAgents can integrate seamlessly with Conduit for full agent capabilities.

**Goal**: Enable Conduit providers to return structured `AIToolCall` objects when the LLM requests tool execution.

---

## Current State Analysis

### What Exists

1. **Tool Definition Infrastructure** ✅
   - `AITool` protocol for defining tools
   - `@Generable` macro for type-safe arguments
   - `Schema` enum for JSON Schema generation
   - `ToolDefinition` struct for API serialization

2. **Tool Message Support** ✅
   - `AIToolCall` struct (id, toolName, arguments)
   - `AIToolOutput` struct (id, toolName, content)
   - `Message.toolOutput()` factory method
   - `Role.tool` case

3. **Config Support** ✅
   - `GenerateConfig.tools` property
   - `GenerateConfig.toolChoice` property
   - `ToolChoice` enum (auto, required, none, tool(name:))

4. **FinishReason** ✅
   - `.toolCall` case exists

### What's Missing

1. **GenerationResult lacks toolCalls** ❌
   ```swift
   // Current
   struct GenerationResult {
       let text: String
       let finishReason: FinishReason
       // ... no toolCalls property
   }
   ```

2. **AnthropicProvider filters out tool blocks** ❌
   ```swift
   // Current behavior in AnthropicProvider+Helpers.swift
   // Tool messages are "filtered out (tool support is planned for a future phase)"
   ```

3. **OpenAIProvider doesn't parse function_calls** ❌

---

## Implementation Plan

### Step 1: Update GenerationResult

**File**: `Sources/Conduit/Core/Types/GenerationResult.swift`

```swift
/// Result of a generation request.
public struct GenerationResult: Sendable, Hashable {
    /// The generated text content.
    public let text: String

    /// Number of tokens generated.
    public let tokenCount: Int

    /// Time taken for generation.
    public let generationTime: TimeInterval

    /// Tokens per second throughput.
    public let tokensPerSecond: Double

    /// Reason generation stopped.
    public let finishReason: FinishReason

    /// Log probabilities for tokens (if requested).
    public let logprobs: [TokenLogprob]?

    /// Token usage statistics.
    public let usage: UsageStats?

    /// Rate limit information (if available).
    public let rateLimitInfo: RateLimitInfo?

    // ═══════════════════════════════════════════════════════════
    // NEW: Tool calling support
    // ═══════════════════════════════════════════════════════════

    /// Tool calls requested by the model.
    /// When `finishReason == .toolCall`, this array contains the tools
    /// the model wants to invoke. Execute each tool and provide results
    /// via `Message.toolOutput()` in the next request.
    public let toolCalls: [AIToolCall]

    /// Whether the model requested tool calls.
    public var hasToolCalls: Bool {
        !toolCalls.isEmpty
    }

    // Updated initializer
    public init(
        text: String,
        tokenCount: Int = 0,
        generationTime: TimeInterval = 0,
        tokensPerSecond: Double = 0,
        finishReason: FinishReason = .stop,
        logprobs: [TokenLogprob]? = nil,
        usage: UsageStats? = nil,
        rateLimitInfo: RateLimitInfo? = nil,
        toolCalls: [AIToolCall] = []  // NEW
    ) {
        self.text = text
        self.tokenCount = tokenCount
        self.generationTime = generationTime
        self.tokensPerSecond = tokensPerSecond
        self.finishReason = finishReason
        self.logprobs = logprobs
        self.usage = usage
        self.rateLimitInfo = rateLimitInfo
        self.toolCalls = toolCalls
    }
}
```

---

### Step 2: Update AIToolCall if Needed

**File**: `Sources/Conduit/Core/Types/AIToolMessage.swift`

Verify the existing structure works:

```swift
/// Represents a tool call requested by the model.
public struct AIToolCall: Sendable, Hashable, Identifiable, Codable {
    /// Unique identifier for this tool call (required for multi-turn).
    public let id: String

    /// Name of the tool to invoke.
    public let toolName: String

    /// Arguments as JSON data.
    public let arguments: Data

    /// Decoded arguments as a dictionary.
    public var argumentsDictionary: [String: Any]? {
        try? JSONSerialization.jsonObject(with: arguments) as? [String: Any]
    }

    public init(id: String, toolName: String, arguments: Data) {
        self.id = id
        self.toolName = toolName
        self.arguments = arguments
    }

    /// Creates from JSON string arguments.
    public init(id: String, toolName: String, argumentsJSON: String) {
        self.id = id
        self.toolName = toolName
        self.arguments = argumentsJSON.data(using: .utf8) ?? Data()
    }
}
```

---

### Step 3: Implement Anthropic Tool Parsing

**File**: `Sources/Conduit/Providers/Anthropic/AnthropicProvider.swift`

#### 3a. Update Response Types

```swift
// In AnthropicTypes.swift or similar

/// Anthropic content block types
enum AnthropicContentBlock: Decodable {
    case text(String)
    case toolUse(ToolUseBlock)

    struct ToolUseBlock: Decodable {
        let id: String
        let name: String
        let input: [String: AnyCodable]  // Tool arguments
    }

    enum CodingKeys: String, CodingKey {
        case type, text, id, name, input
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "text":
            let text = try container.decode(String.self, forKey: .text)
            self = .text(text)
        case "tool_use":
            let id = try container.decode(String.self, forKey: .id)
            let name = try container.decode(String.self, forKey: .name)
            let input = try container.decode([String: AnyCodable].self, forKey: .input)
            self = .toolUse(ToolUseBlock(id: id, name: name, input: input))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown content block type: \(type)"
            )
        }
    }
}
```

#### 3b. Update Response Parsing

**File**: `Sources/Conduit/Providers/Anthropic/AnthropicProvider+Helpers.swift`

```swift
extension AnthropicProvider {

    /// Parses Anthropic API response into GenerationResult.
    func parseResponse(_ response: AnthropicResponse) -> GenerationResult {
        var textContent = ""
        var toolCalls: [AIToolCall] = []

        // Process all content blocks
        for block in response.content {
            switch block {
            case .text(let text):
                textContent += text

            case .toolUse(let toolBlock):
                // Convert input dict to JSON data
                let argumentsData: Data
                if let jsonData = try? JSONEncoder().encode(toolBlock.input) {
                    argumentsData = jsonData
                } else {
                    argumentsData = Data()
                }

                let toolCall = AIToolCall(
                    id: toolBlock.id,
                    name: toolBlock.name,
                    arguments: argumentsData
                )
                toolCalls.append(toolCall)
            }
        }

        // Map stop reason to FinishReason
        let finishReason: FinishReason
        switch response.stopReason {
        case "end_turn", "stop_sequence":
            finishReason = .stop
        case "max_tokens":
            finishReason = .maxTokens
        case "tool_use":
            finishReason = .toolCall
        default:
            finishReason = .stop
        }

        return GenerationResult(
            text: textContent,
            tokenCount: response.usage?.outputTokens ?? 0,
            generationTime: 0,  // Calculated elsewhere
            tokensPerSecond: 0,
            finishReason: finishReason,
            usage: UsageStats(
                inputTokens: response.usage?.inputTokens ?? 0,
                outputTokens: response.usage?.outputTokens ?? 0,
                totalTokens: (response.usage?.inputTokens ?? 0) + (response.usage?.outputTokens ?? 0)
            ),
            toolCalls: toolCalls  // NEW: Include parsed tool calls
        )
    }
}
```

---

### Step 4: Implement OpenAI Tool Parsing

**File**: `Sources/Conduit/Providers/OpenAI/OpenAIProvider.swift`

#### 4a. Update Response Types

```swift
// In OpenAITypes.swift

/// OpenAI chat completion choice
struct OpenAIChoice: Decodable {
    let index: Int
    let message: OpenAIMessage
    let finishReason: String?

    enum CodingKeys: String, CodingKey {
        case index, message
        case finishReason = "finish_reason"
    }
}

struct OpenAIMessage: Decodable {
    let role: String
    let content: String?
    let toolCalls: [OpenAIToolCall]?

    enum CodingKeys: String, CodingKey {
        case role, content
        case toolCalls = "tool_calls"
    }
}

struct OpenAIToolCall: Decodable {
    let id: String
    let type: String  // Always "function"
    let function: OpenAIFunctionCall
}

struct OpenAIFunctionCall: Decodable {
    let name: String
    let arguments: String  // JSON string
}
```

#### 4b. Update Response Parsing

```swift
extension OpenAIProvider {

    func parseResponse(_ response: OpenAIResponse) -> GenerationResult {
        guard let choice = response.choices.first else {
            return GenerationResult(text: "", finishReason: .stop)
        }

        let message = choice.message
        let textContent = message.content ?? ""

        // Parse tool calls
        var toolCalls: [AIToolCall] = []
        if let openAIToolCalls = message.toolCalls {
            for tc in openAIToolCalls {
                let toolCall = AIToolCall(
                    id: tc.id,
                    toolName: tc.function.name,
                    argumentsJSON: tc.function.arguments
                )
                toolCalls.append(toolCall)
            }
        }

        // Map finish reason
        let finishReason: FinishReason
        switch choice.finishReason {
        case "stop":
            finishReason = .stop
        case "length":
            finishReason = .maxTokens
        case "tool_calls":
            finishReason = .toolCall
        case "content_filter":
            finishReason = .contentFilter
        default:
            finishReason = .stop
        }

        return GenerationResult(
            text: textContent,
            tokenCount: response.usage?.completionTokens ?? 0,
            finishReason: finishReason,
            usage: UsageStats(
                inputTokens: response.usage?.promptTokens ?? 0,
                outputTokens: response.usage?.completionTokens ?? 0,
                totalTokens: response.usage?.totalTokens ?? 0
            ),
            toolCalls: toolCalls
        )
    }
}
```

---

### Step 5: Update Streaming for Tool Calls

**File**: `Sources/Conduit/Providers/Anthropic/AnthropicProvider+Streaming.swift`

Tool calls during streaming require accumulating partial data:

```swift
/// Accumulates streaming tool call data
actor ToolCallAccumulator {
    private var partialCalls: [String: PartialToolCall] = [:]

    struct PartialToolCall {
        var id: String
        var name: String
        var argumentsJSON: String = ""
    }

    func startToolCall(id: String, name: String) {
        partialCalls[id] = PartialToolCall(id: id, name: name)
    }

    func appendArguments(id: String, fragment: String) {
        partialCalls[id]?.argumentsJSON += fragment
    }

    func finalize() -> [AIToolCall] {
        partialCalls.values.map { partial in
            AIToolCall(
                id: partial.id,
                toolName: partial.name,
                argumentsJSON: partial.argumentsJSON
            )
        }
    }
}
```

---

### Step 6: Add Tool Executor Helper (Optional but Recommended)

**File**: `Sources/Conduit/Tools/ToolExecutor.swift`

```swift
/// Executes tool calls and returns formatted outputs.
public struct ToolExecutor: Sendable {

    /// Executes a single tool call.
    public static func execute(
        _ toolCall: AIToolCall,
        using tools: [any AITool]
    ) async throws -> AIToolOutput {
        guard let tool = tools.first(where: { $0.name == toolCall.toolName }) else {
            throw AIError.invalidInput("Unknown tool: \(toolCall.toolName)")
        }

        let result = try await tool.call(toolCall.arguments)

        return AIToolOutput(
            id: toolCall.id,
            toolName: toolCall.toolName,
            content: result.promptRepresentation
        )
    }

    /// Executes multiple tool calls in parallel.
    public static func executeAll(
        _ toolCalls: [AIToolCall],
        using tools: [any AITool]
    ) async throws -> [AIToolOutput] {
        try await withThrowingTaskGroup(of: AIToolOutput.self) { group in
            for call in toolCalls {
                group.addTask {
                    try await execute(call, using: tools)
                }
            }

            var outputs: [AIToolOutput] = []
            for try await output in group {
                outputs.append(output)
            }
            return outputs
        }
    }
}
```

---

### Step 7: Update GenerationChunk for Streaming Tools

**File**: `Sources/Conduit/Core/Types/GenerationChunk.swift`

```swift
public struct GenerationChunk: Sendable, Hashable {
    // Existing properties...
    public let text: String
    public let tokenCount: Int
    public let isComplete: Bool
    public let finishReason: FinishReason?
    public let usage: UsageStats?

    // NEW: Streaming tool call support
    /// Partial tool call being constructed.
    public let partialToolCall: PartialToolCall?

    /// Completed tool calls in this chunk.
    public let completedToolCalls: [AIToolCall]?

    public struct PartialToolCall: Sendable, Hashable {
        public let id: String
        public let toolName: String
        public let argumentsFragment: String
    }
}
```

---

### Step 8: Write Tests

**File**: `Tests/ConduitTests/ToolCallingTests.swift`

```swift
import XCTest
@testable import Conduit

final class ToolCallingTests: XCTestCase {

    func testAnthropicToolCallParsing() throws {
        // Given: Anthropic response with tool_use block
        let json = """
        {
            "content": [
                {"type": "text", "text": "I'll check the weather."},
                {"type": "tool_use", "id": "toolu_01", "name": "get_weather", "input": {"city": "SF"}}
            ],
            "stop_reason": "tool_use",
            "usage": {"input_tokens": 100, "output_tokens": 50}
        }
        """

        // When: Parse response
        let response = try JSONDecoder().decode(AnthropicResponse.self, from: json.data(using: .utf8)!)
        let result = AnthropicProvider.parseResponse(response)

        // Then: Tool calls are extracted
        XCTAssertEqual(result.finishReason, .toolCall)
        XCTAssertEqual(result.toolCalls.count, 1)
        XCTAssertEqual(result.toolCalls[0].toolName, "get_weather")
        XCTAssertEqual(result.toolCalls[0].id, "toolu_01")
        XCTAssertEqual(result.text, "I'll check the weather.")
    }

    func testOpenAIToolCallParsing() throws {
        // Given: OpenAI response with tool_calls
        let json = """
        {
            "choices": [{
                "message": {
                    "role": "assistant",
                    "content": null,
                    "tool_calls": [{
                        "id": "call_abc123",
                        "type": "function",
                        "function": {"name": "get_weather", "arguments": "{\\"city\\":\\"SF\\"}"}
                    }]
                },
                "finish_reason": "tool_calls"
            }]
        }
        """

        // When: Parse response
        let response = try JSONDecoder().decode(OpenAIResponse.self, from: json.data(using: .utf8)!)
        let result = OpenAIProvider.parseResponse(response)

        // Then: Tool calls are extracted
        XCTAssertEqual(result.finishReason, .toolCall)
        XCTAssertEqual(result.toolCalls.count, 1)
        XCTAssertEqual(result.toolCalls[0].toolName, "get_weather")
    }

    func testToolExecutor() async throws {
        // Given: A tool and a tool call
        let calculator = CalculatorTool()
        let toolCall = AIToolCall(
            id: "call_1",
            toolName: "calculator",
            argumentsJSON: "{\"expression\": \"2 + 2\"}"
        )

        // When: Execute
        let output = try await ToolExecutor.execute(toolCall, using: [calculator])

        // Then: Result is correct
        XCTAssertEqual(output.id, "call_1")
        XCTAssertEqual(output.toolName, "calculator")
        XCTAssertTrue(output.content.contains("4"))
    }
}
```

---

## Implementation Checklist

### Core Changes (Required)

- [ ] Add `toolCalls: [AIToolCall]` to `GenerationResult`
- [ ] Add `hasToolCalls` computed property
- [ ] Update all `GenerationResult` initializers

### Anthropic Provider

- [ ] Add `AnthropicContentBlock` enum with `.text` and `.toolUse` cases
- [ ] Update response parsing to extract tool_use blocks
- [ ] Map `stop_reason: "tool_use"` to `FinishReason.toolCall`
- [ ] Handle streaming tool calls (optional for MVP)

### OpenAI Provider

- [ ] Add `OpenAIToolCall` and `OpenAIFunctionCall` types
- [ ] Update response parsing to extract `tool_calls` array
- [ ] Map `finish_reason: "tool_calls"` to `FinishReason.toolCall`
- [ ] Handle streaming tool calls (optional for MVP)

### Utilities (Optional but Recommended)

- [ ] Add `ToolExecutor` helper for executing tool calls
- [ ] Add `PartialToolCall` for streaming support
- [ ] Update `GenerationChunk` with tool call fields

### Tests

- [ ] Anthropic tool call parsing tests
- [ ] OpenAI tool call parsing tests
- [ ] Tool executor tests
- [ ] Integration test with real API (manual/optional)

---

## API Usage After Implementation

```swift
// Define a tool
struct WeatherTool: AITool {
    var name: String { "get_weather" }
    var description: String { "Get current weather for a city" }

    @Generable
    struct Arguments {
        @Guide("City name")
        let city: String
    }

    func call(arguments: Arguments) async throws -> String {
        return "72°F and sunny in \(arguments.city)"
    }
}

// Use with provider
let provider = AnthropicProvider(apiKey: "...")
let config = GenerateConfig.default
    .tools([WeatherTool()])
    .toolChoice(.auto)

let result = try await provider.generate(
    messages: [.user("What's the weather in SF?")],
    model: .claudeSonnet45,
    config: config
)

// Handle tool calls
if result.hasToolCalls {
    let outputs = try await ToolExecutor.executeAll(
        result.toolCalls,
        using: [WeatherTool()]
    )

    // Continue conversation with tool results
    let followUp = try await provider.generate(
        messages: [
            .user("What's the weather in SF?"),
            .assistant(result.text),
            // Add tool outputs
            outputs.map { Message.toolOutput($0) }
        ].flatMap { $0 },
        model: .claudeSonnet45,
        config: config
    )
}
```

---

## Estimated Effort

| Task | Effort |
|------|--------|
| GenerationResult update | 30 min |
| Anthropic tool parsing | 2-3 hours |
| OpenAI tool parsing | 1-2 hours |
| ToolExecutor helper | 1 hour |
| Tests | 2 hours |
| **Total** | **6-8 hours** |

---

## Notes for SwiftAgents Integration

Once this is implemented in Conduit:

1. `GenerationResult.toolCalls` will be populated
2. SwiftAgents adapter can extract tool calls directly
3. `generateWithToolCalls()` will work as designed
4. Full `ToolCallingAgent` support enabled

No additional SwiftAgents changes needed beyond the original adapter plan.
