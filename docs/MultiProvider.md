# MultiProvider: Multi-Backend Model Routing

MultiProvider enables using multiple LLM backends within the same application by routing requests based on model name prefixes.

## Overview

When building applications that need to use different LLM providers (Anthropic, OpenAI, Google, etc.), MultiProvider simplifies the architecture by:

- **Unified Interface**: Single `InferenceProvider` that routes to multiple backends
- **Prefix-Based Routing**: Model names like `anthropic/claude-3` automatically route to the correct provider
- **Default Fallback**: Models without prefixes use a configurable default provider
- **Thread-Safe**: Implemented as an actor for safe concurrent access

## Quick Start

```swift
import Swarm

// Create with a default provider
let multiProvider = MultiProvider(defaultProvider: openRouterProvider)

// Register providers for specific prefixes
try await multiProvider.register(prefix: "anthropic", provider: anthropicProvider)
try await multiProvider.register(prefix: "openai", provider: openAIProvider)

// Set the model and generate
await multiProvider.setModel("anthropic/claude-3-5-sonnet-20241022")
let response = try await multiProvider.generate(prompt: "Hello!", options: .default)
```

## Model Name Format

Model names follow the format `prefix/model-name`:

| Model Name | Prefix | Routes To |
|------------|--------|-----------|
| `anthropic/claude-3-5-sonnet-20241022` | `anthropic` | Anthropic provider |
| `openai/gpt-4o` | `openai` | OpenAI provider |
| `google/gemini-pro` | `google` | Google provider |
| `gpt-4` | (none) | Default provider |
| `claude-3` | (none) | Default provider |

## API Reference

### Initialization

```swift
/// Creates a MultiProvider with a default provider for unmatched prefixes.
public init(defaultProvider: any InferenceProvider)
```

### Provider Registration

```swift
/// Registers a provider for a specific prefix.
/// - Throws: `MultiProviderError.emptyPrefix` if prefix is empty
public func register(prefix: String, provider: any InferenceProvider) throws

/// Unregisters a provider for a specific prefix.
public func unregister(prefix: String)

/// Returns all registered prefixes (sorted).
public var registeredPrefixes: [String] { get }

/// Returns the number of registered providers.
public var providerCount: Int { get }

/// Checks if a provider is registered for the given prefix.
public func hasProvider(for prefix: String) -> Bool

/// Returns the provider for a given prefix, if registered.
public func provider(for prefix: String) -> (any InferenceProvider)?
```

### Model Selection

```swift
/// Sets the current model for subsequent inference calls.
public func setModel(_ model: String)

/// Returns the currently selected model, if any.
public var model: String? { get }

/// Clears the current model selection.
public func clearModel()
```

### InferenceProvider Methods

MultiProvider conforms to `InferenceProvider`, so all standard methods are available:

```swift
/// Generates a response using the current model.
public func generate(prompt: String, options: InferenceOptions) async throws -> String

/// Streams a response using the current model.
public nonisolated func stream(
    prompt: String,
    options: InferenceOptions
) -> AsyncThrowingStream<String, Error>

/// Generates a response with potential tool calls.
public func generateWithToolCalls(
    prompt: String,
    tools: [ToolSchema],
    options: InferenceOptions
) async throws -> InferenceResponse
```

## Usage Examples

### Basic Usage

```swift
// Create providers for different services
let anthropicProvider = try AnthropicProvider(apiKey: "sk-ant-...")
let openAIProvider = try OpenAIProvider(apiKey: "sk-...")
let openRouterProvider = try OpenRouterProvider(apiKey: "sk-or-...")

// Create multi-provider with OpenRouter as default
let multiProvider = MultiProvider(defaultProvider: openRouterProvider)

// Register specific providers
try await multiProvider.register(prefix: "anthropic", provider: anthropicProvider)
try await multiProvider.register(prefix: "openai", provider: openAIProvider)

// Use Anthropic
await multiProvider.setModel("anthropic/claude-3-5-sonnet-20241022")
let claudeResponse = try await multiProvider.generate(
    prompt: "Explain quantum computing",
    options: .default
)

// Switch to OpenAI
await multiProvider.setModel("openai/gpt-4o")
let gptResponse = try await multiProvider.generate(
    prompt: "Explain quantum computing",
    options: .default
)

// Use default (OpenRouter)
await multiProvider.setModel("meta-llama/llama-3-70b-instruct")
let llamaResponse = try await multiProvider.generate(
    prompt: "Explain quantum computing",
    options: .default
)
```

### With Agents

```swift
let multiProvider = MultiProvider(defaultProvider: openRouterProvider)
try await multiProvider.register(prefix: "anthropic", provider: anthropicProvider)

// Set model before creating agent
await multiProvider.setModel("anthropic/claude-3-5-sonnet-20241022")

// Agent uses multi-provider for all inference
let agent = ReActAgent.Builder()
    .inferenceProvider(multiProvider)
    .instructions("You are a helpful assistant.")
    .addTool(CalculatorTool())
    .build()

let result = try await agent.run("What is 25% of 200?")
```

### Dynamic Model Switching

```swift
// Start with a fast model for simple tasks
await multiProvider.setModel("openai/gpt-3.5-turbo")
let quickAnswer = try await multiProvider.generate(prompt: simplePrompt, options: .default)

// Switch to a powerful model for complex reasoning
await multiProvider.setModel("anthropic/claude-3-opus-20240229")
let complexAnswer = try await multiProvider.generate(prompt: complexPrompt, options: .default)
```

### Streaming

```swift
await multiProvider.setModel("anthropic/claude-3-5-sonnet-20241022")

for try await token in multiProvider.stream(prompt: "Tell me a story", options: .default) {
    print(token, terminator: "")
}
```

### With Tool Calls

```swift
let tools: [ToolSchema] = [
    CalculatorTool().definition(),
    DateTimeTool().definition()
]

await multiProvider.setModel("openai/gpt-4o")
let response = try await multiProvider.generateWithToolCalls(
    prompt: "What is 2+2 and what time is it?",
    tools: tools,
    options: .default
)

if response.hasToolCalls {
    for toolCall in response.toolCalls {
        print("Tool: \(toolCall.name), Args: \(toolCall.arguments)")
    }
}
```

## Error Handling

```swift
// Empty prefix error
do {
    try await multiProvider.register(prefix: "", provider: someProvider)
} catch MultiProviderError.emptyPrefix {
    print("Prefix cannot be empty")
}

// Whitespace-only prefix
do {
    try await multiProvider.register(prefix: "   ", provider: someProvider)
} catch MultiProviderError.emptyPrefix {
    print("Prefix cannot be whitespace-only")
}
```

## Factory Methods

### OpenRouter Default

```swift
/// Creates a MultiProvider with OpenRouter as the default provider.
public static func withOpenRouter(
    apiKey: String,
    defaultModel: OpenRouterModel = .gpt4o
) throws -> MultiProvider
```

Usage:
```swift
let multiProvider = try MultiProvider.withOpenRouter(apiKey: "sk-or-...")
try await multiProvider.register(prefix: "anthropic", provider: anthropicProvider)
```

## Thread Safety

MultiProvider is implemented as an actor, ensuring thread-safe access to:

- Provider registry
- Current model selection
- All inference methods

You can safely use the same MultiProvider instance from multiple async contexts:

```swift
let multiProvider = MultiProvider(defaultProvider: defaultProvider)

// Safe to call concurrently
async let response1 = multiProvider.generate(prompt: "Question 1", options: .default)
async let response2 = multiProvider.generate(prompt: "Question 2", options: .default)

let results = try await [response1, response2]
```

## Case Sensitivity

Prefixes are case-insensitive:

```swift
try await multiProvider.register(prefix: "anthropic", provider: anthropicProvider)

// All of these route to the same provider:
await multiProvider.setModel("anthropic/claude-3")
await multiProvider.setModel("ANTHROPIC/claude-3")
await multiProvider.setModel("Anthropic/claude-3")
```

## Best Practices

1. **Use meaningful prefixes**: Match the provider name (anthropic, openai, google)
2. **Set a sensible default**: Use OpenRouter or a general-purpose provider as default
3. **Register early**: Register all providers during app initialization
4. **Handle missing providers gracefully**: Check `hasProvider(for:)` before routing
5. **Consider caching**: The resolved provider is determined per-call based on current model

## Integration with Orchestration

MultiProvider works seamlessly with multi-agent orchestration:

```swift
let multiProvider = MultiProvider(defaultProvider: openRouterProvider)
try await multiProvider.register(prefix: "anthropic", provider: anthropicProvider)

// Use different models for different agents
await multiProvider.setModel("anthropic/claude-3-5-sonnet-20241022")
let plannerAgent = PlanAndExecuteAgent.Builder()
    .inferenceProvider(multiProvider)
    .instructions("You create detailed plans.")
    .build()

await multiProvider.setModel("openai/gpt-4o-mini")
let executorAgent = ReActAgent.Builder()
    .inferenceProvider(multiProvider)
    .instructions("You execute tasks quickly.")
    .build()

// Supervisor uses both agents with appropriate models
let supervisor = SupervisorAgent(
    agents: [
        (name: "planner", agent: plannerAgent, description: plannerDesc),
        (name: "executor", agent: executorAgent, description: executorDesc)
    ],
    routingStrategy: LLMRoutingStrategy(inferenceProvider: multiProvider)
)
```
