import Conduit
import Foundation
import Testing
@testable import Swarm

@Suite("Conduit Provider Selection")
struct ConduitProviderSelectionTests {
    @Test("Builds Anthropic Conduit provider")
    func buildsAnthropicProvider() {
        let provider = ConduitProviderSelection
            .anthropic(apiKey: "test-key", model: "claude-3-opus-20240229")
            .makeProvider()

        #expect(provider is ConduitInferenceProvider<AnthropicProvider>)
    }

    @Test("Builds OpenRouter Conduit provider")
    func buildsOpenRouterProvider() {
        let provider = ConduitProviderSelection
            .openrouter(apiKey: "test-key", model: "anthropic/claude-3-opus")
            .makeProvider()

        #expect(provider is ConduitInferenceProvider<OpenAIProvider>)
    }

    @Test("Builds Ollama Conduit provider")
    func buildsOllamaProvider() {
        let provider = ConduitProviderSelection
            .ollama(model: "llama3.2")
            .makeProvider()

        #expect(provider is ConduitInferenceProvider<OpenAIProvider>)
    }

    @Test("Maps OpenRouter routing to Conduit config")
    func mapsOpenRouterRouting() throws {
        let url = try #require(URL(string: "https://example.com"))
        let routing = OpenRouterRouting(
            providers: [.anthropic, .openai],
            fallbacks: false,
            routeByLatency: true,
            siteURL: url,
            appName: "Swarm",
            dataCollection: .deny
        )

        let config = routing.toConduit()
        #expect(config.providers?.map { $0.slug } == ["anthropic", "openai"])
        #expect(config.fallbacks == false)
        #expect(config.routeByLatency == true)
        #expect(config.siteURL == url)
        #expect(config.appName == "Swarm")
        #expect(config.dataCollection == Conduit.OpenRouterDataCollection.deny)
    }

    @Test("Maps Ollama settings to Conduit config")
    func mapsOllamaSettings() {
        let settings = OllamaSettings(
            host: "127.0.0.1",
            port: 11435,
            keepAlive: "10m",
            pullOnMissing: true,
            numGPU: 2,
            lowVRAM: true,
            numCtx: 4096,
            healthCheck: false
        )

        let config = settings.toConduit()
        #expect(config.keepAlive == "10m")
        #expect(config.pullOnMissing == true)
        #expect(config.numGPU == 2)
        #expect(config.lowVRAM == true)
        #expect(config.numCtx == 4096)
        #expect(config.healthCheck == false)
    }
}
