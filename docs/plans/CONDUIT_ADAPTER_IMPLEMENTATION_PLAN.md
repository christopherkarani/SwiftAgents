# SwiftAgents-Conduit Integration Plan

## Executive Summary

This document details the implementation plan for integrating Conduit as the inference layer for SwiftAgents. The integration creates a `ConduitProvider` that implements SwiftAgents' `InferenceProvider` protocol, bridging the two frameworks while maintaining Conduit's independence.

**Key Principle**: Conduit remains standalone. SwiftAgents depends on Conduit, not vice versa.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         APPLICATION LAYER                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                      SwiftAgents Framework                       │    │
│  │  ┌─────────────┐  ┌─────────────┐  ┌──────────────────────┐    │    │
│  │  │ ReActAgent  │  │ToolCalling │  │ PlanAndExecuteAgent  │    │    │
│  │  │             │  │   Agent    │  │                      │    │    │
│  │  └──────┬──────┘  └──────┬─────┘  └──────────┬───────────┘    │    │
│  │         │                │                    │                │    │
│  │         └────────────────┼────────────────────┘                │    │
│  │                          │                                      │    │
│  │                          ▼                                      │    │
│  │              ┌───────────────────────┐                          │    │
│  │              │   InferenceProvider   │  (Protocol)              │    │
│  │              │   - generate()        │                          │    │
│  │              │   - stream()          │                          │    │
│  │              │   - generateWithTools │                          │    │
│  │              └───────────┬───────────┘                          │    │
│  │                          │                                      │    │
│  │  ┌───────────────────────┼───────────────────────┐              │    │
│  │  │                       │                       │              │    │
│  │  ▼                       ▼                       ▼              │    │
│  │  ┌─────────────┐  ┌─────────────────┐  ┌──────────────┐        │    │
│  │  │OpenRouter   │  │ ConduitProvider │  │  Future      │        │    │
│  │  │Provider     │  │    (NEW)        │  │  Providers   │        │    │
│  │  └─────────────┘  └────────┬────────┘  └──────────────┘        │    │
│  │                            │                                    │    │
│  └────────────────────────────┼────────────────────────────────────┘    │
│                               │                                          │
│  ┌────────────────────────────┼────────────────────────────────────┐    │
│  │                            ▼                                     │    │
│  │                   Conduit Framework                              │    │
│  │  ┌─────────────────────────────────────────────────────────┐    │    │
│  │  │                    AIProvider Protocol                   │    │    │
│  │  │    - generate(messages:model:config:)                   │    │    │
│  │  │    - stream(messages:model:config:)                     │    │    │
│  │  └─────────────────────────────────────────────────────────┘    │    │
│  │                            │                                     │    │
│  │    ┌───────────┬───────────┼───────────┬───────────────┐        │    │
│  │    ▼           ▼           ▼           ▼               ▼        │    │
│  │  ┌─────┐  ┌─────────┐  ┌───────┐  ┌────────┐  ┌────────────┐   │    │
│  │  │ MLX │  │Anthropic│  │OpenAI │  │Hugging │  │Foundation  │   │    │
│  │  │     │  │         │  │       │  │ Face   │  │  Models    │   │    │
│  │  └─────┘  └─────────┘  └───────┘  └────────┘  └────────────┘   │    │
│  │                                                                  │    │
│  └──────────────────────────────────────────────────────────────────┘    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Type Mapping Strategy

### 1. InferenceOptions → GenerateConfig

| SwiftAgents (`InferenceOptions`) | Conduit (`GenerateConfig`) | Notes |
|----------------------------------|---------------------------|-------|
| `temperature: Double` | `temperature: Float` | Direct (cast) |
| `maxTokens: Int?` | `maxTokens: Int?` | Direct |
| `topP: Double?` | `topP: Float` | Direct (cast) |
| `topK: Int?` | `topK: Int?` | Direct |
| `stopSequences: [String]` | `stopSequences: [String]` | Direct |
| `presencePenalty: Double?` | `presencePenalty: Float` | Direct (cast) |
| `frequencyPenalty: Double?` | `frequencyPenalty: Float` | Direct (cast) |

### 2. GenerationResult → InferenceResponse

| Conduit (`GenerationResult`) | SwiftAgents (`InferenceResponse`) | Notes |
|------------------------------|----------------------------------|-------|
| `text: String` | `content: String?` | Direct |
| `finishReason: FinishReason` | `finishReason: FinishReason` | Enum mapping required |
| `usage: UsageStats?` | `usage: TokenUsage?` | Struct mapping |
| — | `toolCalls: [ParsedToolCall]` | Parse from response |

### 3. FinishReason Mapping

| Conduit | SwiftAgents |
|---------|-------------|
| `.stop` | `.completed` |
| `.maxTokens` | `.maxTokens` |
| `.stopSequence` | `.completed` |
| `.cancelled` | `.cancelled` |
| `.contentFilter` | `.contentFilter` |
| `.toolCall` | `.toolCall` |

### 4. Error Mapping (AIError → AgentError)

| Conduit (`AIError`) | SwiftAgents (`AgentError`) |
|---------------------|---------------------------|
| `.providerUnavailable` | `.inferenceProviderUnavailable` |
| `.modelNotFound` | `.modelNotAvailable` |
| `.generationFailed` | `.generationFailed` |
| `.rateLimited` | `.rateLimitExceeded` |
| `.invalidInput` | `.invalidInput` |
| `.timeout` | `.generationFailed` (with context) |
| `.networkError` | `.generationFailed` (with context) |
| `.authenticationFailed` | `.inferenceProviderUnavailable` |

---

## File Structure

```
Sources/SwiftAgents/Providers/Conduit/
├── ConduitProvider.swift              # Main actor implementing InferenceProvider
├── ConduitConfiguration.swift         # Configuration with provider/model selection
├── ConduitProviderType.swift          # Enum for backend selection
├── ConduitTypeMappers.swift           # Type conversion utilities
├── ConduitToolConverter.swift         # ToolDefinition ↔ Conduit tool format
├── ConduitToolCallParser.swift        # Parse tool calls from LLM responses
└── ConduitError.swift                 # Error mapping utilities

Tests/SwiftAgentsTests/Providers/Conduit/
├── ConduitProviderTests.swift         # Unit tests
├── ConduitTypeMappersTests.swift      # Type conversion tests
├── ConduitToolConverterTests.swift    # Tool conversion tests
└── MockConduitProvider.swift          # Test mock
```

---

## Detailed Implementation

### File 1: ConduitProviderType.swift

```swift
import Conduit

/// Supported Conduit backend providers.
public enum ConduitProviderType: Sendable {
    /// Local MLX inference on Apple Silicon.
    case mlx(model: ModelIdentifier)

    /// Anthropic Claude models.
    case anthropic(model: ModelIdentifier, apiKey: String)

    /// OpenAI GPT models.
    case openAI(model: ModelIdentifier, apiKey: String)

    /// HuggingFace Inference API.
    case huggingFace(model: String, token: String?)

    /// Apple Foundation Models (iOS 26+).
    @available(iOS 26.0, macOS 26.0, *)
    case foundationModels

    /// Returns the model identifier for this provider type.
    public var modelIdentifier: ModelIdentifier {
        switch self {
        case .mlx(let model): return model
        case .anthropic(let model, _): return model
        case .openAI(let model, _): return model
        case .huggingFace(let model, _): return .huggingFace(model)
        case .foundationModels: return .foundationModels
        }
    }
}
```

### File 2: ConduitConfiguration.swift

```swift
import Foundation

/// Configuration for ConduitProvider.
public struct ConduitConfiguration: Sendable {
    /// The backend provider type and model.
    public let providerType: ConduitProviderType

    /// Optional system prompt prepended to all requests.
    public var systemPrompt: String?

    /// Request timeout interval.
    public var timeout: TimeInterval

    /// Maximum retry attempts for transient failures.
    public var maxRetries: Int

    /// Creates a ConduitConfiguration.
    public init(
        providerType: ConduitProviderType,
        systemPrompt: String? = nil,
        timeout: TimeInterval = 60.0,
        maxRetries: Int = 3
    ) {
        self.providerType = providerType
        self.systemPrompt = systemPrompt
        self.timeout = timeout
        self.maxRetries = maxRetries
    }

    // MARK: - Convenience Initializers

    /// Creates configuration for local MLX inference.
    public static func mlx(
        model: ModelIdentifier = .llama3_2_1b,
        systemPrompt: String? = nil
    ) -> ConduitConfiguration {
        ConduitConfiguration(
            providerType: .mlx(model: model),
            systemPrompt: systemPrompt
        )
    }

    /// Creates configuration for Anthropic Claude.
    public static func anthropic(
        model: ModelIdentifier = .claude35Sonnet,
        apiKey: String,
        systemPrompt: String? = nil
    ) -> ConduitConfiguration {
        ConduitConfiguration(
            providerType: .anthropic(model: model, apiKey: apiKey),
            systemPrompt: systemPrompt
        )
    }

    /// Creates configuration for OpenAI.
    public static func openAI(
        model: ModelIdentifier = .gpt4o,
        apiKey: String,
        systemPrompt: String? = nil
    ) -> ConduitConfiguration {
        ConduitConfiguration(
            providerType: .openAI(model: model, apiKey: apiKey),
            systemPrompt: systemPrompt
        )
    }
}
```

### File 3: ConduitTypeMappers.swift

```swift
import Conduit

// MARK: - InferenceOptions → GenerateConfig

extension InferenceOptions {
    /// Converts SwiftAgents InferenceOptions to Conduit GenerateConfig.
    func toConduitConfig() -> GenerateConfig {
        var config = GenerateConfig()

        config.temperature = Float(temperature)

        if let maxTokens {
            config.maxTokens = maxTokens
        }

        if let topP {
            config.topP = Float(topP)
        }

        if let topK {
            config.topK = topK
        }

        if !stopSequences.isEmpty {
            config.stopSequences = stopSequences
        }

        if let presencePenalty {
            config.presencePenalty = Float(presencePenalty)
        }

        if let frequencyPenalty {
            config.frequencyPenalty = Float(frequencyPenalty)
        }

        return config
    }
}

// MARK: - GenerationResult → InferenceResponse

extension GenerationResult {
    /// Converts Conduit GenerationResult to SwiftAgents InferenceResponse.
    func toInferenceResponse(toolCalls: [InferenceResponse.ParsedToolCall] = []) -> InferenceResponse {
        InferenceResponse(
            content: text,
            toolCalls: toolCalls,
            finishReason: finishReason.toSwiftAgentsReason(),
            usage: usage?.toTokenUsage()
        )
    }
}

// MARK: - FinishReason Mapping

extension Conduit.FinishReason {
    /// Converts Conduit FinishReason to SwiftAgents FinishReason.
    func toSwiftAgentsReason() -> InferenceResponse.FinishReason {
        switch self {
        case .stop, .stopSequence:
            return .completed
        case .maxTokens:
            return .maxTokens
        case .cancelled:
            return .cancelled
        case .contentFilter:
            return .contentFilter
        case .toolCall:
            return .toolCall
        case .pauseTurn, .modelContextWindowExceeded:
            return .completed
        }
    }
}

// MARK: - UsageStats → TokenUsage

extension Conduit.UsageStats {
    /// Converts Conduit UsageStats to SwiftAgents TokenUsage.
    func toTokenUsage() -> InferenceResponse.TokenUsage {
        InferenceResponse.TokenUsage(
            inputTokens: inputTokens,
            outputTokens: outputTokens
        )
    }
}
```

### File 4: ConduitToolConverter.swift

```swift
import Conduit

/// Converts SwiftAgents tool definitions to Conduit format.
public enum ConduitToolConverter {

    /// Converts SwiftAgents ToolDefinition array to Conduit tool definitions.
    public static func toConduitTools(_ definitions: [ToolDefinition]) -> [Conduit.ToolDefinition] {
        definitions.map { def in
            Conduit.ToolDefinition(
                name: def.name,
                description: def.description,
                parameters: convertParameters(def.parameters)
            )
        }
    }

    /// Converts ToolParameter array to Conduit Schema.
    private static func convertParameters(_ parameters: [ToolParameter]) -> Conduit.Schema {
        var properties: OrderedDictionary<String, Conduit.Property> = [:]
        var required: [String] = []

        for param in parameters {
            properties[param.name] = Conduit.Property(
                schema: convertParameterType(param.type),
                description: param.description,
                isRequired: param.isRequired
            )

            if param.isRequired {
                required.append(param.name)
            }
        }

        return .object(
            name: "parameters",
            description: nil,
            properties: properties
        )
    }

    /// Converts ToolParameter.ParameterType to Conduit Schema.
    private static func convertParameterType(_ type: ToolParameter.ParameterType) -> Conduit.Schema {
        switch type {
        case .string:
            return .string
        case .int:
            return .integer
        case .double:
            return .number
        case .bool:
            return .boolean
        case .array(let elementType):
            return .array(items: convertParameterType(elementType), constraints: nil)
        case .object(let properties):
            return convertParameters(properties)
        case .oneOf(let options):
            return .string // with constraint
        case .any:
            return .object(name: "any", description: nil, properties: [:])
        }
    }
}
```

### File 5: ConduitToolCallParser.swift

```swift
import Foundation
import Conduit

/// Parses tool calls from Conduit LLM responses.
public enum ConduitToolCallParser {

    /// Parses AIToolCall array to SwiftAgents ParsedToolCall array.
    public static func parse(_ toolCalls: [Conduit.AIToolCall]) throws -> [InferenceResponse.ParsedToolCall] {
        try toolCalls.map { call in
            let arguments = try parseArguments(call.arguments)
            return InferenceResponse.ParsedToolCall(
                id: call.id,
                name: call.toolName,
                arguments: arguments
            )
        }
    }

    /// Parses JSON Data to SendableValue dictionary.
    private static func parseArguments(_ data: Data) throws -> [String: SendableValue] {
        guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AgentError.invalidToolArguments(
                toolName: "unknown",
                reason: "Arguments must be a JSON object"
            )
        }

        var result: [String: SendableValue] = [:]
        for (key, value) in jsonObject {
            result[key] = SendableValue.from(jsonValue: value)
        }
        return result
    }
}

// MARK: - SendableValue JSON Conversion

extension SendableValue {
    /// Creates SendableValue from a JSON value.
    static func from(jsonValue: Any) -> SendableValue {
        switch jsonValue {
        case is NSNull:
            return .null
        case let bool as Bool:
            return .bool(bool)
        case let int as Int:
            return .int(int)
        case let double as Double:
            return .double(double)
        case let string as String:
            return .string(string)
        case let array as [Any]:
            return .array(array.map { from(jsonValue: $0) })
        case let dict as [String: Any]:
            var result: [String: SendableValue] = [:]
            for (key, val) in dict {
                result[key] = from(jsonValue: val)
            }
            return .dictionary(result)
        default:
            return .string(String(describing: jsonValue))
        }
    }
}
```

### File 6: ConduitError.swift

```swift
import Conduit

/// Maps Conduit AIError to SwiftAgents AgentError.
public enum ConduitErrorMapper {

    /// Converts a Conduit AIError to a SwiftAgents AgentError.
    public static func map(_ error: Conduit.AIError) -> AgentError {
        switch error {
        case .providerUnavailable(let reason):
            return .inferenceProviderUnavailable(reason: "Provider unavailable: \(reason)")

        case .modelNotFound(let model):
            return .modelNotAvailable(model: model.displayName)

        case .modelNotCached(let model):
            return .modelNotAvailable(model: "\(model.displayName) (not cached)")

        case .incompatibleModel(let model, let reasons):
            return .modelNotAvailable(model: "\(model.displayName): \(reasons.joined(separator: ", "))")

        case .authenticationFailed(let message):
            return .inferenceProviderUnavailable(reason: "Authentication failed: \(message)")

        case .billingError(let message):
            return .inferenceProviderUnavailable(reason: "Billing error: \(message)")

        case .generationFailed(let underlying):
            return .generationFailed(reason: underlying.localizedDescription)

        case .tokenLimitExceeded(let count, let limit):
            return .generationFailed(reason: "Token limit exceeded: \(count)/\(limit)")

        case .contentFiltered(let reason):
            return .generationFailed(reason: "Content filtered: \(reason ?? "unknown reason")")

        case .cancelled:
            return .generationFailed(reason: "Generation cancelled")

        case .timeout(let interval):
            return .generationFailed(reason: "Request timed out after \(interval)s")

        case .networkError(let urlError):
            return .generationFailed(reason: "Network error: \(urlError.localizedDescription)")

        case .serverError(let statusCode, let message):
            return .generationFailed(reason: "Server error \(statusCode): \(message ?? "unknown")")

        case .rateLimited(let retryAfter):
            return .rateLimitExceeded(retryAfter: retryAfter)

        case .invalidInput(let message):
            return .invalidInput(reason: message)

        default:
            return .generationFailed(reason: "Conduit error: \(error)")
        }
    }
}
```

### File 7: ConduitProvider.swift (Main Implementation)

```swift
import Foundation
import Conduit

/// Conduit-based inference provider for SwiftAgents.
///
/// ConduitProvider bridges SwiftAgents' agent framework with Conduit's
/// unified LLM inference layer, enabling access to MLX, Anthropic, OpenAI,
/// HuggingFace, and Foundation Models backends.
///
/// Example:
/// ```swift
/// let provider = try ConduitProvider(
///     configuration: .anthropic(
///         model: .claude35Sonnet,
///         apiKey: "sk-ant-...",
///         systemPrompt: "You are a helpful assistant"
///     )
/// )
///
/// let agent = ToolCallingAgent(
///     tools: [CalculatorTool()],
///     inferenceProvider: provider
/// )
///
/// let result = try await agent.run("What is 42 * 17?")
/// ```
public actor ConduitProvider: InferenceProvider {

    // MARK: - Properties

    /// The provider configuration.
    public let configuration: ConduitConfiguration

    /// The underlying Conduit provider.
    private let provider: any AIProvider

    /// Model identifier for inference calls.
    private let modelIdentifier: ModelIdentifier

    // MARK: - Initialization

    /// Creates a ConduitProvider with the given configuration.
    /// - Parameter configuration: The provider configuration.
    /// - Throws: `AgentError` if provider initialization fails.
    public init(configuration: ConduitConfiguration) throws {
        self.configuration = configuration
        self.modelIdentifier = configuration.providerType.modelIdentifier
        self.provider = try Self.createProvider(for: configuration.providerType)
    }

    // MARK: - InferenceProvider Conformance

    /// Generates a response for the given prompt.
    public func generate(prompt: String, options: InferenceOptions) async throws -> String {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AgentError.invalidInput(reason: "Prompt cannot be empty")
        }

        let messages = buildMessages(prompt: prompt)
        let config = options.toConduitConfig()

        do {
            let result = try await provider.generate(
                messages: messages,
                model: modelIdentifier,
                config: config
            )
            return result.text
        } catch let error as AIError {
            throw ConduitErrorMapper.map(error)
        }
    }

    /// Streams a response for the given prompt.
    nonisolated public func stream(
        prompt: String,
        options: InferenceOptions
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let messages = await self.buildMessages(prompt: prompt)
                    let config = options.toConduitConfig()
                    let modelId = await self.modelIdentifier
                    let conduitProvider = await self.provider

                    for try await chunk in conduitProvider.stream(
                        messages: messages,
                        model: modelId,
                        config: config
                    ) {
                        continuation.yield(chunk.text)
                    }
                    continuation.finish()
                } catch let error as AIError {
                    continuation.finish(throwing: ConduitErrorMapper.map(error))
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Generates a response with potential tool calls.
    public func generateWithToolCalls(
        prompt: String,
        tools: [ToolDefinition],
        options: InferenceOptions
    ) async throws -> InferenceResponse {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AgentError.invalidInput(reason: "Prompt cannot be empty")
        }

        let messages = buildMessages(prompt: prompt)
        var config = options.toConduitConfig()

        // Add tools to config
        config.tools = ConduitToolConverter.toConduitTools(tools)
        config.toolChoice = .auto

        do {
            let result = try await provider.generate(
                messages: messages,
                model: modelIdentifier,
                config: config
            )

            // Parse tool calls if present
            let parsedToolCalls: [InferenceResponse.ParsedToolCall]
            if let toolCalls = result.toolCalls, !toolCalls.isEmpty {
                parsedToolCalls = try ConduitToolCallParser.parse(toolCalls)
            } else {
                parsedToolCalls = []
            }

            return result.toInferenceResponse(toolCalls: parsedToolCalls)

        } catch let error as AIError {
            throw ConduitErrorMapper.map(error)
        }
    }

    // MARK: - Private Helpers

    /// Builds Conduit Messages from prompt and configuration.
    private func buildMessages(prompt: String) -> [Conduit.Message] {
        var messages: [Conduit.Message] = []

        if let systemPrompt = configuration.systemPrompt {
            messages.append(.system(systemPrompt))
        }

        messages.append(.user(prompt))

        return messages
    }

    /// Creates the appropriate Conduit provider for the given type.
    private static func createProvider(for type: ConduitProviderType) throws -> any AIProvider {
        switch type {
        case .mlx(let model):
            return MLXProvider()

        case .anthropic(_, let apiKey):
            return AnthropicProvider(apiKey: apiKey)

        case .openAI(_, let apiKey):
            return OpenAIProvider(apiKey: apiKey)

        case .huggingFace(_, let token):
            if let token {
                return HuggingFaceProvider(token: token)
            } else {
                return HuggingFaceProvider()
            }

        case .foundationModels:
            if #available(iOS 26.0, macOS 26.0, *) {
                return FoundationModelsProvider()
            } else {
                throw AgentError.inferenceProviderUnavailable(
                    reason: "Foundation Models requires iOS 26+ or macOS 26+"
                )
            }
        }
    }
}
```

---

## Test Strategy

### Unit Tests

```swift
// ConduitTypeMappersTests.swift
func testInferenceOptionsToGenerateConfig() {
    let options = InferenceOptions(
        temperature: 0.7,
        maxTokens: 1000,
        topP: 0.9
    )

    let config = options.toConduitConfig()

    XCTAssertEqual(config.temperature, 0.7)
    XCTAssertEqual(config.maxTokens, 1000)
    XCTAssertEqual(config.topP, 0.9)
}

func testFinishReasonMapping() {
    XCTAssertEqual(Conduit.FinishReason.stop.toSwiftAgentsReason(), .completed)
    XCTAssertEqual(Conduit.FinishReason.maxTokens.toSwiftAgentsReason(), .maxTokens)
    XCTAssertEqual(Conduit.FinishReason.toolCall.toSwiftAgentsReason(), .toolCall)
}
```

### Integration Tests (with Mocks)

```swift
// ConduitProviderTests.swift
func testGenerateWithMockProvider() async throws {
    let mockProvider = MockConduitProvider()
    mockProvider.nextResponse = GenerationResult(text: "Hello!", ...)

    let provider = ConduitProvider(wrapping: mockProvider, configuration: .mock)
    let result = try await provider.generate(prompt: "Hi", options: .default)

    XCTAssertEqual(result, "Hello!")
}

func testToolCallingFlow() async throws {
    let mockProvider = MockConduitProvider()
    mockProvider.nextResponse = GenerationResult(
        text: nil,
        toolCalls: [AIToolCall(id: "1", toolName: "calculator", arguments: ...)]
    )

    let provider = ConduitProvider(wrapping: mockProvider, configuration: .mock)
    let response = try await provider.generateWithToolCalls(
        prompt: "Calculate 2+2",
        tools: [calculatorDefinition],
        options: .default
    )

    XCTAssertEqual(response.toolCalls.count, 1)
    XCTAssertEqual(response.toolCalls[0].name, "calculator")
}
```

---

## Implementation Order

1. **ConduitProviderType.swift** - Enum for backend selection
2. **ConduitConfiguration.swift** - Configuration struct with convenience initializers
3. **ConduitError.swift** - Error mapping
4. **ConduitTypeMappers.swift** - Type conversions
5. **ConduitToolConverter.swift** - Tool definition conversion
6. **ConduitToolCallParser.swift** - Parse tool call responses
7. **ConduitProvider.swift** - Main actor implementation
8. **Tests** - Unit and integration tests

---

## Dependencies

### Package.swift Changes

```swift
dependencies: [
    // ... existing dependencies
    .package(url: "https://github.com/christopherkarani/Conduit.git", branch: "main")
],
targets: [
    .target(
        name: "SwiftAgents",
        dependencies: [
            "SwiftAgentsMacros",
            .product(name: "Logging", package: "swift-log"),
            .product(name: "Conduit", package: "Conduit")
        ],
        // ...
    )
]
```

---

## Success Criteria

- [ ] All existing SwiftAgents tests pass
- [ ] ConduitProvider implements all InferenceProvider methods
- [ ] Type mapping is complete and tested
- [ ] Tool calling works end-to-end
- [ ] Streaming works correctly
- [ ] Error mapping covers all AIError cases
- [ ] Works with ToolCallingAgent, ReActAgent, PlanAndExecuteAgent
- [ ] Documentation and examples provided
