import Testing
@testable import Swarm

@Suite("AgentConfiguration Inference Options")
struct AgentConfigurationInferenceOptionsTests {
    @Test("ModelSettings execution fields propagate to InferenceOptions")
    func modelSettingsPropagation() {
        let settings = ModelSettings()
            .temperature(0.25)
            .maxTokens(321)
            .stopSequences(["A", "B"])
            .topP(0.8)
            .topK(42)
            .presencePenalty(0.3)
            .frequencyPenalty(0.4)
            .toolChoice(.required)
            .seed(99)
            .parallelToolCalls(true)
            .truncation(.auto)
            .verbosity(.high)
            .providerSettings(["openai:custom": .string("value")])

        let config = AgentConfiguration.default
            .parallelToolCalls(false)
            .modelSettings(settings)

        let options = config.inferenceOptions
        #expect(options.temperature == 0.25)
        #expect(options.maxTokens == 321)
        #expect(options.stopSequences == ["A", "B"])
        #expect(options.topP == 0.8)
        #expect(options.topK == 42)
        #expect(options.presencePenalty == 0.3)
        #expect(options.frequencyPenalty == 0.4)
        #expect(options.toolChoice == .required)
        #expect(options.seed == 99)
        #expect(options.parallelToolCalls == true)
        #expect(options.truncation == .auto)
        #expect(options.verbosity == .high)
        #expect(options.providerSettings?["openai:custom"] == .string("value"))
    }

    @Test("Fallback inference options use base config when model settings are absent")
    func fallbackInferenceOptions() {
        let config = AgentConfiguration.default
            .temperature(0.5)
            .maxTokens(123)
            .stopSequences(["STOP"])
            .parallelToolCalls(true)

        let options = config.inferenceOptions
        #expect(options.temperature == 0.5)
        #expect(options.maxTokens == 123)
        #expect(options.stopSequences == ["STOP"])
        #expect(options.parallelToolCalls == true)
        #expect(options.seed == nil)
        #expect(options.truncation == nil)
        #expect(options.verbosity == nil)
        #expect(options.providerSettings == nil)
    }

    @Test("Context mode strict4k overrides adaptive profile")
    func strict4kContextModeUsesStrictProfile() {
        let config = AgentConfiguration.default
            .contextProfile(.heavy(maxContextTokens: 8192))
            .contextMode(.strict4k)

        let effective = config.effectiveContextProfile
        #expect(effective.preset == .strict4k)
        #expect(effective.maxTotalContextTokens == 4096)
        #expect(effective.maxContextTokens == 3412)
    }
}
