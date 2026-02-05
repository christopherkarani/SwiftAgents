import Conduit
import Testing
@testable import Swarm

@Suite("Conduit Inference Provider Option Mapping")
struct ConduitInferenceProviderOptionsMappingTests {
    private final class ConfigBox: @unchecked Sendable {
        var lastPromptConfig: Conduit.GenerateConfig?
        var lastMessagesConfig: Conduit.GenerateConfig?
        var lastStreamWithMetadataConfig: Conduit.GenerateConfig?
    }

    @Test("Applies InferenceOptions.topK to Conduit GenerateConfig")
    func appliesTopK() async throws {
        struct MockModelID: Conduit.ModelIdentifying {
            let rawValue: String
            var displayName: String { rawValue }
            var provider: Conduit.ProviderType { .openAI }
            var description: String { rawValue }
            init(_ rawValue: String) { self.rawValue = rawValue }
        }

        struct CapturingTextGenerator: Conduit.TextGenerator {
            typealias ModelID = MockModelID

            let box: ConfigBox

            func generate(_ prompt: String, model _: ModelID, config: Conduit.GenerateConfig) async throws -> String {
                box.lastPromptConfig = config
                return ""
            }

            func generate(
                messages _: [Conduit.Message],
                model _: ModelID,
                config _: Conduit.GenerateConfig
            ) async throws -> Conduit.GenerationResult {
                Conduit.GenerationResult(
                    text: "",
                    tokenCount: 0,
                    generationTime: 0,
                    tokensPerSecond: 0,
                    finishReason: .stop
                )
            }

            func stream(_ prompt: String, model _: ModelID, config: Conduit.GenerateConfig) -> AsyncThrowingStream<String, Error> {
                box.lastPromptConfig = config
                return StreamHelper.makeTrackedStream { continuation in
                    continuation.finish()
                }
            }

            func streamWithMetadata(
                messages _: [Conduit.Message],
                model _: ModelID,
                config _: Conduit.GenerateConfig
            ) -> AsyncThrowingStream<Conduit.GenerationChunk, Error> {
                StreamHelper.makeTrackedStream { continuation in
                    continuation.finish()
                }
            }
        }

        let box = ConfigBox()
        let provider = CapturingTextGenerator(box: box)
        let bridge = ConduitInferenceProvider(provider: provider, model: MockModelID("mock"))

        _ = try await bridge.generate(prompt: "hi", options: InferenceOptions(topK: 40))

        let config = box.lastPromptConfig
        #expect(config?.topK == 40)
    }

    @Test("Does not apply toolChoice when tools are empty (generateWithToolCalls)")
    func doesNotApplyToolChoiceWhenNoTools_generate() async throws {
        struct MockModelID: Conduit.ModelIdentifying {
            let rawValue: String
            var displayName: String { rawValue }
            var provider: Conduit.ProviderType { .openAI }
            var description: String { rawValue }
            init(_ rawValue: String) { self.rawValue = rawValue }
        }

        struct CapturingTextGenerator: Conduit.TextGenerator {
            typealias ModelID = MockModelID

            let box: ConfigBox

            func generate(_ prompt: String, model _: ModelID, config _: Conduit.GenerateConfig) async throws -> String {
                ""
            }

            func generate(
                messages _: [Conduit.Message],
                model _: ModelID,
                config: Conduit.GenerateConfig
            ) async throws -> Conduit.GenerationResult {
                box.lastMessagesConfig = config
                return Conduit.GenerationResult(
                    text: "",
                    tokenCount: 0,
                    generationTime: 0,
                    tokensPerSecond: 0,
                    finishReason: .stop
                )
            }

            func stream(_ prompt: String, model _: ModelID, config _: Conduit.GenerateConfig) -> AsyncThrowingStream<String, Error> {
                StreamHelper.makeTrackedStream { continuation in
                    continuation.finish()
                }
            }

            func streamWithMetadata(
                messages _: [Conduit.Message],
                model _: ModelID,
                config _: Conduit.GenerateConfig
            ) -> AsyncThrowingStream<Conduit.GenerationChunk, Error> {
                StreamHelper.makeTrackedStream { continuation in
                    continuation.finish()
                }
            }
        }

        let box = ConfigBox()
        let provider = CapturingTextGenerator(box: box)
        let bridge = ConduitInferenceProvider(provider: provider, model: MockModelID("mock"))

        _ = try await bridge.generateWithToolCalls(
            prompt: "hi",
            tools: [],
            options: InferenceOptions(toolChoice: .required)
        )

        let config = box.lastMessagesConfig
        #expect(config?.toolChoice == .auto)
    }

    @Test("Does not apply toolChoice when tools are empty (streamWithToolCalls)")
    func doesNotApplyToolChoiceWhenNoTools_stream() async throws {
        struct MockModelID: Conduit.ModelIdentifying {
            let rawValue: String
            var displayName: String { rawValue }
            var provider: Conduit.ProviderType { .openAI }
            var description: String { rawValue }
            init(_ rawValue: String) { self.rawValue = rawValue }
        }

        struct CapturingTextGenerator: Conduit.TextGenerator {
            typealias ModelID = MockModelID

            let box: ConfigBox

            func generate(_ prompt: String, model _: ModelID, config _: Conduit.GenerateConfig) async throws -> String {
                ""
            }

            func generate(
                messages _: [Conduit.Message],
                model _: ModelID,
                config _: Conduit.GenerateConfig
            ) async throws -> Conduit.GenerationResult {
                Conduit.GenerationResult(
                    text: "",
                    tokenCount: 0,
                    generationTime: 0,
                    tokensPerSecond: 0,
                    finishReason: .stop
                )
            }

            func stream(_ prompt: String, model _: ModelID, config _: Conduit.GenerateConfig) -> AsyncThrowingStream<String, Error> {
                StreamHelper.makeTrackedStream { continuation in
                    continuation.finish()
                }
            }

            func streamWithMetadata(
                messages _: [Conduit.Message],
                model _: ModelID,
                config: Conduit.GenerateConfig
            ) -> AsyncThrowingStream<Conduit.GenerationChunk, Error> {
                box.lastStreamWithMetadataConfig = config
                return StreamHelper.makeTrackedStream { continuation in
                    continuation.finish()
                }
            }
        }

        let box = ConfigBox()
        let provider = CapturingTextGenerator(box: box)
        let bridge = ConduitInferenceProvider(provider: provider, model: MockModelID("mock"))

        for try await _ in bridge.streamWithToolCalls(
            prompt: "hi",
            tools: [],
            options: InferenceOptions(toolChoice: .required)
        ) {
            // no-op
        }

        let config = box.lastStreamWithMetadataConfig
        #expect(config?.toolChoice == .auto)
    }
}
