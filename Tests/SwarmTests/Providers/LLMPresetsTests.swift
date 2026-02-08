import Conduit
import Testing
@testable import Swarm

@Suite("LLM Presets")
struct LLMPresetsTests {
    @Test("OpenAI preset builds Conduit OpenAI provider")
    func openAIPresetBuildsProvider() {
        let agent = Agent(.openAI(key: "test-key", model: "gpt-4o-mini"))

        let provider = agent.inferenceProvider
        #expect(provider != nil)
        if let provider {
            #expect(provider is LLM)
            if let preset = provider as? LLM {
                #expect(preset._makeProviderForTesting() is ConduitInferenceProvider<OpenAIProvider>)
            }
        }
    }

    @Test("Anthropic preset builds Conduit Anthropic provider")
    func anthropicPresetBuildsProvider() {
        let agent = Agent(.anthropic(key: "test-key", model: "claude-3-opus-20240229"))

        let provider = agent.inferenceProvider
        #expect(provider != nil)
        if let provider {
            #expect(provider is LLM)
            if let preset = provider as? LLM {
                #expect(preset._makeProviderForTesting() is ConduitInferenceProvider<AnthropicProvider>)
            }
        }
    }

    @Test("OpenRouter preset builds Conduit OpenAI-compatible provider")
    func openRouterPresetBuildsProvider() {
        let agent = Agent(.openRouter(key: "test-key", model: "anthropic/claude-3-opus"))

        let provider = agent.inferenceProvider
        #expect(provider != nil)
        if let provider {
            #expect(provider is LLM)
            if let preset = provider as? LLM {
                #expect(preset._makeProviderForTesting() is ConduitInferenceProvider<OpenAIProvider>)
            }
        }
    }
}
