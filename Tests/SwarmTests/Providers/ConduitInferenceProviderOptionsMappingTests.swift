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

    @Test("Applies seed and parallelToolCalls to Conduit GenerateConfig")
    func appliesSeedAndParallelToolCalls() async throws {
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

        _ = try await bridge.generate(
            prompt: "hi",
            options: InferenceOptions(seed: 42, parallelToolCalls: false)
        )

        let config = box.lastPromptConfig
        #expect(config?.seed == 42)
        #expect(config?.parallelToolCalls == false)
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

    @Test("Maps providerSettings runtime flags into runtimeFeatures")
    func mapsProviderSettingsRuntimeFeatures() async throws {
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

        let options = InferenceOptions(
            providerSettings: [
                "conduit.runtime.kv_quantization.enabled": .bool(true),
                "conduit.runtime.kv_quantization.bits": .int(8),
                "conduit.runtime.attention_sinks.enabled": .bool(true),
                "conduit.runtime.attention_sinks.sink_token_count": .int(32),
                "conduit.runtime.kv_swap.enabled": .bool(true),
                "conduit.runtime.kv_swap.io_budget_mb_per_second": .int(96),
                "conduit.runtime.incremental_prefill.enabled": .bool(true),
                "conduit.runtime.incremental_prefill.max_prefix_tokens": .int(2048),
                "conduit.runtime.speculative.enabled": .bool(true),
                "conduit.runtime.speculative.draft_stream_count": .int(2),
                "conduit.runtime.speculative.draft_ahead_tokens": .int(16),
                "conduit.runtime.speculative.verification_batch_tokens": .int(8),
                "conduit.runtime.speculative.rollback_token_budget_per_turn": .int(64),
                "conduit.runtime.speculative.auto_disable_divergence_rate": .double(0.25),
            ]
        )

        _ = try await bridge.generate(prompt: "hi", options: options)
        let config = try #require(box.lastPromptConfig)

        let runtime = try #require(config.runtimeFeatures)

        #expect(runtime.kvQuantization.enabled == true)
        #expect(runtime.kvQuantization.bits == 8)
        #expect(runtime.attentionSinks.enabled == true)
        #expect(runtime.attentionSinks.sinkTokenCount == 32)
        #expect(runtime.kvSwap.enabled == true)
        #expect(runtime.kvSwap.ioBudgetMBPerSecond == 96)
        #expect(runtime.incrementalPrefill.enabled == true)
        #expect(runtime.incrementalPrefill.maxPrefixTokens == 2048)
        #expect(runtime.speculativeScheduling.enabled == true)
        #expect(runtime.speculativeScheduling.draftStreamCount == 2)
        #expect(runtime.speculativeScheduling.draftAheadTokens == 16)
        #expect(runtime.speculativeScheduling.verificationBatchTokens == 8)
        #expect(runtime.speculativeScheduling.rollbackTokenBudgetPerTurn == 64)
        #expect(runtime.speculativeScheduling.autoDisableDivergenceRate == 0.25)
    }

    @Test("Maps providerSettings runtime policy into runtimePolicyOverride")
    func mapsProviderSettingsRuntimePolicy() async throws {
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

        let options = InferenceOptions(
            providerSettings: [
                "conduit.runtime.policy.kv_quantization.enabled": .bool(false),
                "conduit.runtime.policy.attention_sinks.enabled": .bool(true),
                "conduit.runtime.policy.kv_swap.enabled": .bool(true),
                "conduit.runtime.policy.incremental_prefill.enabled": .bool(true),
                "conduit.runtime.policy.speculative.enabled": .bool(false),
                "conduit.runtime.policy.model_allowlist": .array([.string("mock"), .string("allowlisted")]),
            ]
        )

        _ = try await bridge.generate(prompt: "hi", options: options)
        let config = try #require(box.lastPromptConfig)

        let runtimePolicy = try #require(config.runtimePolicyOverride)

        #expect(runtimePolicy.featureFlags.kvQuantization == false)
        #expect(runtimePolicy.featureFlags.attentionSinks == true)
        #expect(runtimePolicy.featureFlags.kvSwap == true)
        #expect(runtimePolicy.featureFlags.incrementalPrefill == true)
        #expect(runtimePolicy.featureFlags.speculativeScheduling == false)

        let expectedAllowlist: Set<String> = ["allowlisted", "mock"]
        #expect(runtimePolicy.modelAllowlist.kvQuantizationModels == expectedAllowlist)
        #expect(runtimePolicy.modelAllowlist.attentionSinkModels == expectedAllowlist)
        #expect(runtimePolicy.modelAllowlist.kvSwapModels == expectedAllowlist)
        #expect(runtimePolicy.modelAllowlist.incrementalPrefillModels == expectedAllowlist)
        #expect(runtimePolicy.modelAllowlist.speculativeSchedulingModels == expectedAllowlist)
    }
}
