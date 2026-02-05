# Inference Providers

## Overview

Swarm uses inference providers to connect agents to LLM backends. Providers abstract the underlying language model, allowing agents to work with different model backends through a unified interface. This architecture enables flexibility in choosing between cloud APIs, on-device models, and custom inference solutions.

The provider system supports:
- Multiple LLM backends (OpenRouter, Foundation Models, custom providers)
- Streaming and non-streaming responses
- Tool calling for agent-based workflows
- Automatic retry and error handling
- Multi-provider routing with fallback support

## InferenceProvider Protocol

The `InferenceProvider` protocol defines the contract all providers must implement:

```swift
public protocol InferenceProvider: Sendable {
    /// Generates a response for the given prompt.
    func generate(prompt: String, options: InferenceOptions) async throws -> String

    /// Streams a response for the given prompt.
    func stream(prompt: String, options: InferenceOptions) -> AsyncThrowingStream<String, Error>

    /// Generates a response with potential tool calls.
    func generateWithToolCalls(
        prompt: String,
        tools: [ToolSchema],
        options: InferenceOptions
    ) async throws -> InferenceResponse
}
```

### Core Methods

#### generate()

Generates a complete response for the given prompt. This is the simplest method for basic text generation.

```swift
let response = try await provider.generate(
    prompt: "Explain quantum computing in simple terms",
    options: .default
)
print(response)
```

#### stream()

Streams response tokens as they are generated. Use this for real-time UI updates or when dealing with long responses.

```swift
for try await token in provider.stream(prompt: "Write a story about...", options: .default) {
    print(token, terminator: "")
}
```

#### generateWithToolCalls()

Generates a response that may include requests to call tools. This is essential for agent-based workflows where the model needs to use external tools.

```swift
let response = try await provider.generateWithToolCalls(
    prompt: "What's the weather in San Francisco?",
    tools: [weatherTool.definition],
    options: .default
)

if response.hasToolCalls {
    for toolCall in response.toolCalls {
        print("Tool: \(toolCall.name), Args: \(toolCall.arguments)")
    }
}
```

### InferenceResponse

The `InferenceResponse` type captures the model's output:

```swift
public struct InferenceResponse: Sendable, Equatable {
    /// The text content of the response, if any.
    public let content: String?

    /// Tool calls requested by the model.
    public let toolCalls: [ParsedToolCall]

    /// The reason generation finished.
    public let finishReason: FinishReason

    /// Token usage statistics, if available.
    public let usage: TokenUsage?

    /// Whether this response includes tool calls.
    public var hasToolCalls: Bool
}
```

#### FinishReason

```swift
public enum FinishReason: String, Sendable, Codable {
    case completed     // Generation completed normally
    case toolCall      // Model requested tool calls
    case maxTokens     // Hit maximum token limit
    case contentFilter // Content was filtered
    case cancelled     // Generation was cancelled
}
```

## Built-in Providers

### OpenRouterProvider

OpenRouter provides unified access to models from OpenAI, Anthropic, Google, Meta, Mistral, and other providers through a single API. This is the recommended provider for most use cases.

#### Basic Setup

```swift
import Swarm

// Simple initialization
let provider = try OpenRouterProvider(
    apiKey: "sk-or-v1-...",
    model: .claude35Sonnet
)

// Generate a response
let response = try await provider.generate(
    prompt: "Explain quantum computing",
    options: .default
)
```

#### Configuration

Use `OpenRouterConfiguration` for full control over provider settings:

```swift
let config = try OpenRouterConfiguration(
    apiKey: "sk-or-v1-...",
    model: .claude35Sonnet,
    timeout: .seconds(120),
    maxTokens: 4096,
    systemPrompt: "You are a helpful assistant.",
    temperature: 0.7,
    topP: 0.9,
    appName: "MyApp",
    siteURL: URL(string: "https://myapp.com"),
    retryStrategy: .default
)

let provider = OpenRouterProvider(configuration: config)
```

#### Available Models

OpenRouter supports numerous models through static presets:

```swift
// OpenAI Models
OpenRouterModel.gpt4o           // openai/gpt-4o
OpenRouterModel.gpt4oMini       // openai/gpt-4o-mini
OpenRouterModel.gpt4Turbo       // openai/gpt-4-turbo

// Anthropic Models
OpenRouterModel.claude35Sonnet  // anthropic/claude-3.5-sonnet
OpenRouterModel.claude35Haiku   // anthropic/claude-3.5-haiku
OpenRouterModel.claude3Opus     // anthropic/claude-3-opus

// Google Models
OpenRouterModel.geminiPro15     // google/gemini-pro-1.5
OpenRouterModel.geminiFlash15   // google/gemini-flash-1.5

// Meta Models
OpenRouterModel.llama31405B     // meta-llama/llama-3.1-405b-instruct
OpenRouterModel.llama3170B      // meta-llama/llama-3.1-70b-instruct

// Other Models
OpenRouterModel.mistralLarge    // mistralai/mistral-large
OpenRouterModel.deepseekCoder   // deepseek/deepseek-coder
```

#### Custom Models

Use any OpenRouter-supported model via string literal:

```swift
let customModel: OpenRouterModel = "meta-llama/llama-3.1-8b-instruct"
let provider = try OpenRouterProvider(apiKey: apiKey, model: customModel)
```

Or programmatically:

```swift
let model = try OpenRouterModel("anthropic/claude-3-opus-20240229")
```

#### Retry Strategy

Configure automatic retry behavior for failed requests:

```swift
// Default strategy: 3 retries with exponential backoff
let defaultStrategy = OpenRouterRetryStrategy.default

// Custom strategy
let customStrategy = OpenRouterRetryStrategy(
    maxRetries: 5,
    baseDelay: 0.5,
    maxDelay: 60.0,
    backoffMultiplier: 2.0,
    retryableStatusCodes: [429, 500, 502, 503, 504]
)

// No retry
let noRetry = OpenRouterRetryStrategy.none

let config = try OpenRouterConfiguration(
    apiKey: apiKey,
    model: .gpt4o,
    retryStrategy: customStrategy
)
```

#### Provider Preferences

Control which upstream providers OpenRouter uses:

```swift
let preferences = try OpenRouterProviderPreferences(
    order: ["anthropic", "openai"],      // Prefer Anthropic, then OpenAI
    allowFallbacks: true,                 // Allow fallback to other providers
    sort: .latency,                       // Sort by latency
    maxPrice: 0.0001                      // Maximum price per token
)

let config = try OpenRouterConfiguration(
    apiKey: apiKey,
    model: .claude35Sonnet,
    providerPreferences: preferences
)
```

#### Fallback Models

Configure fallback models for resilience:

```swift
let config = try OpenRouterConfiguration(
    apiKey: apiKey,
    model: .claude35Sonnet,
    fallbackModels: [.gpt4o, .geminiPro15],
    routingStrategy: .fallback  // or .roundRobin
)
```

#### Streaming Example

```swift
let provider = try OpenRouterProvider(apiKey: apiKey, model: .gpt4o)

for try await token in provider.stream(prompt: "Write a poem about Swift", options: .default) {
    print(token, terminator: "")
    fflush(stdout)
}
print() // New line at end
```

#### Tool Calling Example

```swift
let provider = try OpenRouterProvider(apiKey: apiKey, model: .gpt4o)

let response = try await provider.generateWithToolCalls(
    prompt: "What's 42 * 17?",
    tools: [calculatorTool.definition],
    options: .default
)

switch response.finishReason {
case .toolCall:
    for toolCall in response.toolCalls {
        print("Call tool: \(toolCall.name)")
        print("Arguments: \(toolCall.arguments)")
    }
case .completed:
    print("Response: \(response.content ?? "")")
default:
    break
}
```

### Foundation Models (Apple)

Foundation Models provide on-device inference on Apple platforms (iOS 26+, macOS 15+). This enables private, offline AI capabilities without sending data to external servers.

> **Note**: Foundation Models are only available on supported Apple devices with Apple Silicon.

```swift
// Foundation Models integration is automatic when no provider is specified
let agent = ReActAgent(
    tools: [myTool],
    instructions: "You are a helpful assistant."
)
// Uses Foundation Models by default on supported devices
let result = try await agent.run("Hello!")
```

For explicit Foundation Models usage, implement a custom provider wrapper:

```swift
// Example Foundation Models wrapper (iOS 26+)
#if canImport(FoundationModels)
import FoundationModels

public actor FoundationModelsProvider: InferenceProvider {
    private let model: LanguageModel

    public init() async throws {
        self.model = try await LanguageModel()
    }

    public func generate(prompt: String, options: InferenceOptions) async throws -> String {
        let response = try await model.generate(prompt: prompt)
        return response.content
    }

    // Implement stream() and generateWithToolCalls()...
}
#endif
```

### MultiProvider

`MultiProvider` routes requests to different inference providers based on model name prefixes. This enables using multiple backends within the same application.

#### Model Name Format

Model names follow the format `prefix/model-name`:
- `anthropic/claude-3-5-sonnet` routes to the Anthropic provider
- `openai/gpt-4o` routes to the OpenAI provider
- `gpt-4` (no prefix) routes to the default provider

#### Basic Setup

```swift
// Create with a default provider
let defaultProvider = try OpenRouterProvider(apiKey: apiKey, model: .gpt4o)
let multiProvider = MultiProvider(defaultProvider: defaultProvider)

// Register providers for specific prefixes
try await multiProvider.register(prefix: "anthropic", provider: anthropicProvider)
try await multiProvider.register(prefix: "openai", provider: openAIProvider)
try await multiProvider.register(prefix: "google", provider: googleProvider)
```

#### Usage

```swift
// Set the current model - subsequent calls use this model
await multiProvider.setModel("anthropic/claude-3-5-sonnet-20241022")

// Generate a response - routes to Anthropic provider
let response = try await multiProvider.generate(
    prompt: "Hello, world!",
    options: .default
)

// Switch to a different model
await multiProvider.setModel("openai/gpt-4o")
let response2 = try await multiProvider.generate(
    prompt: "Tell me a joke",
    options: .default
)

// Use default provider (no prefix)
await multiProvider.setModel("gpt-4")
let response3 = try await multiProvider.generate(
    prompt: "What's the weather?",
    options: .default
)
```

#### Factory Method

Convenience factory for OpenRouter as default:

```swift
let multiProvider = try MultiProvider.withOpenRouter(
    apiKey: "sk-or-v1-...",
    defaultModel: .gpt4o
)
```

#### Provider Management

```swift
// Check if a provider is registered
if await multiProvider.hasProvider(for: "anthropic") {
    print("Anthropic provider available")
}

// Get registered prefixes
let prefixes = await multiProvider.registeredPrefixes
print("Available: \(prefixes)")  // ["anthropic", "google", "openai"]

// Unregister a provider
await multiProvider.unregister(prefix: "google")

// Clear model selection
await multiProvider.clearModel()
```

## Custom Providers

Implement `InferenceProvider` to create custom providers for any LLM backend.

### Basic Implementation

```swift
public actor CustomProvider: InferenceProvider {
    private let apiKey: String
    private let session: URLSession

    public init(apiKey: String) {
        self.apiKey = apiKey
        self.session = URLSession.shared
    }

    public func generate(prompt: String, options: InferenceOptions) async throws -> String {
        // Build and send request to your API
        let request = buildRequest(prompt: prompt, options: options)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AgentError.generationFailed(reason: "API request failed")
        }

        // Parse response
        let result = try JSONDecoder().decode(APIResponse.self, from: data)
        return result.content
    }

    nonisolated public func stream(
        prompt: String,
        options: InferenceOptions
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await self.performStream(prompt: prompt, options: options, continuation: continuation)
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    public func generateWithToolCalls(
        prompt: String,
        tools: [ToolSchema],
        options: InferenceOptions
    ) async throws -> InferenceResponse {
        // Build request with tools
        let request = buildToolRequest(prompt: prompt, tools: tools, options: options)
        let (data, _) = try await session.data(for: request)

        // Parse response and extract tool calls
        let result = try JSONDecoder().decode(ToolAPIResponse.self, from: data)

        let toolCalls = result.toolCalls.map { call in
            InferenceResponse.ParsedToolCall(
                id: call.id,
                name: call.name,
                arguments: call.arguments
            )
        }

        return InferenceResponse(
            content: result.content,
            toolCalls: toolCalls,
            finishReason: result.toolCalls.isEmpty ? .completed : .toolCall
        )
    }

    // Private helper methods...
}
```

### Using Custom Providers with Agents

```swift
let customProvider = CustomProvider(apiKey: "my-api-key")

let agent = ReActAgent(
    tools: [myTool],
    instructions: "You are a helpful assistant.",
    inferenceProvider: customProvider
)

let result = try await agent.run("Hello!")
```

## Configuration

### InferenceOptions

Control generation behavior with `InferenceOptions`:

```swift
public struct InferenceOptions: Sendable, Equatable {
    /// Temperature for generation (0.0 = deterministic, 2.0 = creative).
    public var temperature: Double

    /// Maximum tokens to generate.
    public var maxTokens: Int?

    /// Sequences that will stop generation.
    public var stopSequences: [String]

    /// Top-p (nucleus) sampling parameter.
    public var topP: Double?

    /// Top-k sampling parameter.
    public var topK: Int?

    /// Presence penalty for reducing repetition.
    public var presencePenalty: Double?

    /// Frequency penalty for reducing repetition.
    public var frequencyPenalty: Double?
}
```

### Preset Configurations

```swift
// Default options
let options = InferenceOptions.default

// Creative writing - high temperature
let creative = InferenceOptions.creative  // temperature: 1.2, topP: 0.95

// Precise/deterministic - low temperature
let precise = InferenceOptions.precise    // temperature: 0.2, topP: 0.9

// Balanced for general use
let balanced = InferenceOptions.balanced  // temperature: 0.7, topP: 0.9

// Code generation
let code = InferenceOptions.codeGeneration  // temperature: 0.1, maxTokens: 4000

// Chat/conversation
let chat = InferenceOptions.chat  // temperature: 0.8, presencePenalty: 0.6
```

### Fluent Builder Pattern

```swift
let options = InferenceOptions.default
    .temperature(0.7)
    .maxTokens(2000)
    .topP(0.9)
    .stopSequences("END", "STOP")
    .presencePenalty(0.5)
```

### Timeouts

Configure request timeouts in `OpenRouterConfiguration`:

```swift
let config = try OpenRouterConfiguration(
    apiKey: apiKey,
    model: .gpt4o,
    timeout: .seconds(180)  // 3 minutes
)
```

### Token Limits

Set maximum tokens at the configuration or request level:

```swift
// Configuration level (default for all requests)
let config = try OpenRouterConfiguration(
    apiKey: apiKey,
    model: .gpt4o,
    maxTokens: 8192
)

// Request level (overrides configuration)
let options = InferenceOptions.default.maxTokens(2000)
let response = try await provider.generate(prompt: prompt, options: options)
```

## Best Practices

### API Key Management

Never hardcode API keys. Use secure storage:

```swift
// Environment variables (development)
let apiKey = ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"] ?? ""

// Keychain (production iOS/macOS)
func getAPIKey() throws -> String {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.myapp.openrouter",
        kSecReturnData as String: true
    ]

    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)

    guard status == errSecSuccess,
          let data = result as? Data,
          let key = String(data: data, encoding: .utf8) else {
        throw KeychainError.itemNotFound
    }

    return key
}

// Configuration file (server-side)
struct Config: Codable {
    let openRouterAPIKey: String
}
let config = try JSONDecoder().decode(Config.self, from: configData)
```

### Error Handling

Handle provider errors appropriately:

```swift
do {
    let response = try await provider.generate(prompt: prompt, options: .default)
    print(response)
} catch AgentError.rateLimitExceeded(let retryAfter) {
    print("Rate limited. Retry after \(retryAfter) seconds")
    try await Task.sleep(for: .seconds(retryAfter))
    // Retry request
} catch AgentError.invalidInput(let reason) {
    print("Invalid input: \(reason)")
} catch AgentError.modelNotAvailable(let model) {
    print("Model not available: \(model)")
    // Fall back to different model
} catch AgentError.inferenceProviderUnavailable(let reason) {
    print("Provider unavailable: \(reason)")
    // Use fallback provider
} catch AgentError.generationFailed(let reason) {
    print("Generation failed: \(reason)")
} catch AgentError.cancelled {
    print("Request was cancelled")
} catch {
    print("Unexpected error: \(error)")
}
```

### Cost Optimization

Optimize API costs with these strategies:

```swift
// 1. Use appropriate models for the task
let simpleTask = try OpenRouterProvider(apiKey: apiKey, model: .gpt4oMini)  // Cheaper
let complexTask = try OpenRouterProvider(apiKey: apiKey, model: .claude3Opus)  // More capable

// 2. Limit max tokens
let options = InferenceOptions.default.maxTokens(500)

// 3. Use caching for repeated queries
actor ResponseCache {
    private var cache: [String: String] = [:]

    func get(_ key: String) -> String? { cache[key] }
    func set(_ key: String, value: String) { cache[key] = value }
}

// 4. Set max price in provider preferences
let preferences = try OpenRouterProviderPreferences(
    maxPrice: 0.00005  // Maximum price per token
)

// 5. Use streaming for long responses (can cancel early)
var fullResponse = ""
for try await token in provider.stream(prompt: prompt, options: .default) {
    fullResponse += token
    if fullResponse.count > 1000 {
        break  // Stop early if needed
    }
}
```

### Concurrency Best Practices

```swift
// Providers are actors - thread-safe by default
let provider = try OpenRouterProvider(apiKey: apiKey, model: .gpt4o)

// Parallel requests
async let response1 = provider.generate(prompt: "Question 1", options: .default)
async let response2 = provider.generate(prompt: "Question 2", options: .default)
let (r1, r2) = try await (response1, response2)

// Batch processing with TaskGroup
func processBatch(_ prompts: [String]) async throws -> [String] {
    try await withThrowingTaskGroup(of: String.self) { group in
        for prompt in prompts {
            group.addTask {
                try await provider.generate(prompt: prompt, options: .default)
            }
        }

        var results: [String] = []
        for try await result in group {
            results.append(result)
        }
        return results
    }
}
```

### Logging and Observability

```swift
import Swarm

// Enable logging
Log.bootstrap()

// Use with tracer for observability
let tracer = OSLogTracer()

let agent = ReActAgent(
    tools: [myTool],
    instructions: "You are helpful.",
    inferenceProvider: provider,
    tracer: tracer
)
```

## Summary

The inference provider system in Swarm offers:

1. **Unified Interface** - Single protocol for all LLM backends
2. **OpenRouter Integration** - Access to 100+ models through one API
3. **Multi-Provider Routing** - Use multiple backends in one application
4. **Resilience** - Automatic retry, fallback models, and error handling
5. **Flexibility** - Easy custom provider implementation
6. **Performance** - Streaming support, parallel requests, caching strategies

Choose the right provider strategy for your use case:
- **Single Provider** - Simple applications with one LLM backend
- **MultiProvider** - Applications needing multiple model families
- **Custom Provider** - Integration with proprietary or specialized LLMs
- **Foundation Models** - On-device inference for privacy-sensitive applications
