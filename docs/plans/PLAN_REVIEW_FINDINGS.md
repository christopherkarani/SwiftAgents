# Plan Review Findings

## Executive Summary

Three sub-agents reviewed the Conduit adapter implementation plan. **Critical issues were found** that require plan revision before implementation.

---

## CRITICAL BLOCKERS

### 1. Tool Calling Not Implemented in Conduit (BLOCKER)

**Finding**: Conduit's Anthropic provider does NOT extract tool calls from LLM responses.

**Evidence from AnthropicProvider source code**:
```swift
// From AnthropicProvider+Helpers.swift:
// "Tool messages: Currently filtered out (tool support is planned for a future phase)."
```

**Impact**:
- `GenerationResult` has NO `toolCalls` property
- When `finishReason == .toolCall`, the actual tool data is **discarded**
- Our `generateWithToolCalls()` method **cannot work** as designed
- `ToolCallingAgent` integration will **fail**

**Options**:
1. **Wait**: Wait for Conduit to implement tool response parsing
2. **Contribute**: Add tool parsing to Conduit ourselves (preferred)
3. **Workaround**: Implement raw response parsing in Swarm adapter
4. **MVP without tools**: Ship text generation only, add tools later

---

### 2. Model Selection Architecture Mismatch (BLOCKER)

**Finding**: Our plan stores model at init time, but Conduit passes model per-request.

**Conduit's Actual Pattern**:
```swift
// Model is passed to EACH generate() call, NOT stored on provider
let response = try await provider.generate(
    messages: messages,
    model: .claudeOpus45,  // <-- Passed per call
    config: .default
)
```

**Each Provider Has Different Model Types**:
- `AnthropicProvider` → `AnthropicModelID` (`.claudeOpus45`, `.claudeSonnet45`)
- `OpenAIProvider` → `OpenAIModelID` (`.gpt4o`, `.gpt4turbo`)
- `MLXProvider` → `ModelIdentifier` (`.mlx("...")`, `.llama3_2_1b`)

**Impact**:
- Our `ConduitProviderType` enum design is wrong
- Cannot use `any AIProvider` easily due to associated types
- Need type erasure or different architecture

**Solution Required**: Redesign to either:
1. Store model ID with provider type AND handle type conversion
2. Use type erasure wrapper (`AnyAIProvider`)
3. Create separate provider wrappers per backend

---

### 3. Associated Types Complexity (MAJOR)

**Finding**: `AIProvider` protocol uses associated types that prevent simple generic usage.

```swift
public protocol AIProvider<Response>: Actor, Sendable {
    associatedtype Response: Sendable      // GenerationResult
    associatedtype StreamChunk: Sendable   // GenerationChunk
    associatedtype ModelID: ModelIdentifying  // Provider-specific!
}
```

**Impact**:
- Cannot store `any AIProvider` and call methods with model parameter
- Each provider expects its own `ModelID` type
- Type erasure is complex

---

## IMPORTANT ISSUES (Code Quality)

### 4. Missing Import for OrderedDictionary

**Location**: `ConduitToolConverter.swift`

**Issue**: Uses `OrderedDictionary` without import.

**Fix**: Either:
- Add `import Collections` (swift-collections package)
- Use regular `[String: Property]` dictionary
- Verify if Conduit re-exports OrderedDictionary

---

### 5. Unused `required` Array in Tool Converter

**Location**: `ConduitToolConverter.swift` line 360

**Issue**: Creates `required` array but never uses it.

```swift
var required: [String] = []
// ... populates array
// ... never passes to Schema
```

**Fix**: Pass to Schema constructor or remove.

---

### 6. Missing Test Initializer

**Location**: `ConduitProvider.swift`

**Issue**: Tests show:
```swift
let provider = ConduitProvider(wrapping: mockProvider, configuration: .mock)
```

But implementation only has:
```swift
public init(configuration: ConduitConfiguration) throws
```

**Fix**: Add dependency injection initializer for testing.

---

### 7. Stream Method Missing Prompt Validation

**Location**: `ConduitProvider.swift`

**Issue**: `generate()` and `generateWithToolCalls()` validate empty prompts, but `stream()` does not.

**Fix**: Add consistent validation or document why omitted.

---

### 8. FoundationModels Availability Issue

**Location**: `ConduitProviderType.swift`

**Issue**: `@available` on enum case, but `modelIdentifier` computed property lacks availability check.

**Fix**: Add availability check in switch case.

---

### 9. FinishReason Table Incomplete

**Location**: Documentation vs Code mismatch

**Issue**: Mapping table doesn't include `pauseTurn` and `modelContextWindowExceeded` cases that code handles.

**Fix**: Update documentation table.

---

### 10. Double to Float Precision Loss

**Location**: `ConduitTypeMappers.swift`

**Issue**: Swarm uses `Double` for temperature, Conduit uses `Float`.

```swift
config.temperature = Float(temperature)  // Precision loss
```

**Fix**: Document this limitation.

---

## REVISED ARCHITECTURE RECOMMENDATION

Given the critical issues, here's the recommended approach:

### Phase 1: MVP (Text Generation Only)

```swift
/// Simplified ConduitProvider for text generation
public actor ConduitProvider: InferenceProvider {
    private enum Backend {
        case anthropic(AnthropicProvider, AnthropicModelID)
        case openAI(OpenAIProvider, OpenAIModelID)
        case mlx(MLXProvider, ModelIdentifier)
    }

    private let backend: Backend
    private let systemPrompt: String?

    public init(configuration: ConduitConfiguration) throws {
        switch configuration.providerType {
        case .anthropic(let model, let apiKey):
            let provider = AnthropicProvider(apiKey: apiKey)
            self.backend = .anthropic(provider, model)
        case .openAI(let model, let apiKey):
            let provider = OpenAIProvider(apiKey: apiKey)
            self.backend = .openAI(provider, model)
        case .mlx(let model):
            let provider = MLXProvider()
            self.backend = .mlx(provider, model)
        }
        self.systemPrompt = configuration.systemPrompt
    }

    public func generate(prompt: String, options: InferenceOptions) async throws -> String {
        let messages = buildMessages(prompt: prompt)
        let config = options.toConduitConfig()

        switch backend {
        case .anthropic(let provider, let model):
            let result = try await provider.generate(messages: messages, model: model, config: config)
            return result.text
        case .openAI(let provider, let model):
            let result = try await provider.generate(messages: messages, model: model, config: config)
            return result.text
        case .mlx(let provider, let model):
            let result = try await provider.generate(messages: messages, model: model, config: config)
            return result.text
        }
    }

    public func generateWithToolCalls(...) async throws -> InferenceResponse {
        // Phase 1: Throw not supported error
        throw AgentError.generationFailed(reason: "Tool calling requires Conduit enhancement. Use OpenRouterProvider for tool support.")
    }
}
```

### Phase 2: Tool Support (Requires Conduit Changes)

Add to Conduit:
1. `toolCalls: [AIToolCall]?` property on `GenerationResult`
2. Tool call parsing in AnthropicProvider
3. Tool call parsing in OpenAIProvider

Then update Swarm adapter to use tool calls.

---

## ACTION ITEMS

### Immediate (Before Implementation)

- [ ] **Decision**: Proceed with MVP (no tools) or wait/contribute to Conduit?
- [ ] **Fix**: Redesign `ConduitProviderType` to handle provider-specific model types
- [ ] **Fix**: Use enum-based backend storage instead of `any AIProvider`
- [ ] **Fix**: Add missing imports (OrderedDictionary or remove usage)
- [ ] **Fix**: Add test initializer for dependency injection
- [ ] **Update**: Plan document with revised architecture

### For Conduit (Optional Enhancement)

- [ ] Add `toolCalls` to `GenerationResult`
- [ ] Implement tool call parsing in AnthropicProvider
- [ ] Implement tool call parsing in OpenAIProvider
- [ ] Add `MockAIProvider` for testing

---

## Summary

| Issue | Severity | Status |
|-------|----------|--------|
| Tool calling not implemented | CRITICAL | Blocker |
| Model selection mismatch | CRITICAL | Needs redesign |
| Associated types complexity | MAJOR | Needs enum approach |
| Missing OrderedDictionary import | MEDIUM | Easy fix |
| Unused required array | MEDIUM | Easy fix |
| Missing test initializer | MEDIUM | Easy fix |
| Stream validation missing | LOW | Easy fix |
| FoundationModels availability | LOW | Easy fix |
| FinishReason table incomplete | LOW | Doc fix |
| Double→Float precision | LOW | Doc fix |

**Recommendation**: Proceed with **Phase 1 MVP** (text generation only), then contribute tool support to Conduit for Phase 2.
