// InferenceOptionsBuilderTests.swift
// SwarmTests
//
// Tests for fluent InferenceOptions builder methods.

import Foundation
@testable import Swarm
import Testing

// MARK: - InferenceOptionsBuilderTests

@Suite("InferenceOptions Builder Tests")
struct InferenceOptionsBuilderTests {
    // MARK: - Basic Fluent Methods

    @Test("Set temperature with fluent method")
    func setTemperatureWithFluentMethod() {
        let options = InferenceOptions.default
            .temperature(0.7)

        #expect(options.temperature == 0.7)
    }

    @Test("Set maxTokens with fluent method")
    func setMaxTokensWithFluentMethod() {
        let options = InferenceOptions.default
            .maxTokens(2000)

        #expect(options.maxTokens == 2000)
    }

    @Test("Set stopSequences with fluent method")
    func setStopSequencesWithFluentMethod() {
        let options = InferenceOptions.default
            .stopSequences("END", "STOP", "###")

        #expect(options.stopSequences == ["END", "STOP", "###"])
    }

    // MARK: - Chained Configuration

    @Test("Chain multiple fluent methods")
    func chainMultipleFluentMethods() {
        let options = InferenceOptions.default
            .temperature(0.9)
            .maxTokens(4000)
            .stopSequences("END")

        #expect(options.temperature == 0.9)
        #expect(options.maxTokens == 4000)
        #expect(options.stopSequences == ["END"])
    }

    @Test("Fluent methods don't mutate original")
    func fluentMethodsDontMutateOriginal() {
        let original = InferenceOptions.default
        let modified = original.temperature(0.5)

        #expect(original.temperature == 1.0) // Default
        #expect(modified.temperature == 0.5)
    }

    // MARK: - Extended Options

    @Test("Set topP with fluent method")
    func setTopPWithFluentMethod() {
        let options = InferenceOptions.default
            .topP(0.95)

        #expect(options.topP == 0.95)
    }

    @Test("Set topK with fluent method")
    func setTopKWithFluentMethod() {
        let options = InferenceOptions.default
            .topK(40)

        #expect(options.topK == 40)
    }

    @Test("Set presencePenalty with fluent method")
    func setPresencePenaltyWithFluentMethod() {
        let options = InferenceOptions.default
            .presencePenalty(0.6)

        #expect(options.presencePenalty == 0.6)
    }

    @Test("Set frequencyPenalty with fluent method")
    func setFrequencyPenaltyWithFluentMethod() {
        let options = InferenceOptions.default
            .frequencyPenalty(0.3)

        #expect(options.frequencyPenalty == 0.3)
    }

    // MARK: - Full Configuration

    @Test("Configure all extended options")
    func configureAllExtendedOptions() {
        let options = InferenceOptions.default
            .temperature(0.8)
            .maxTokens(3000)
            .topP(0.92)
            .topK(50)
            .presencePenalty(0.5)
            .frequencyPenalty(0.4)
            .stopSequences("###", "END")

        #expect(options.temperature == 0.8)
        #expect(options.maxTokens == 3000)
        #expect(options.topP == 0.92)
        #expect(options.topK == 50)
        #expect(options.presencePenalty == 0.5)
        #expect(options.frequencyPenalty == 0.4)
        #expect(options.stopSequences == ["###", "END"])
    }

    // MARK: - Preset Configurations

    @Test("Creative preset")
    func creativePreset() {
        let options = InferenceOptions.creative

        #expect(options.temperature >= 1.0)
        #expect((options.topP ?? 0) >= 0.9)
    }

    @Test("Precise preset")
    func precisePreset() {
        let options = InferenceOptions.precise

        #expect(options.temperature <= 0.3)
    }

    @Test("Balanced preset")
    func balancedPreset() {
        let options = InferenceOptions.balanced

        #expect(options.temperature >= 0.5 && options.temperature <= 0.8)
    }

    @Test("Code generation preset")
    func codeGenerationPreset() {
        let options = InferenceOptions.codeGeneration

        #expect(options.temperature <= 0.2)
        #expect(options.stopSequences.contains("```"))
    }

    // MARK: - Validation

    @Test("Temperature accepts any Double value")
    func temperatureAcceptsAnyValue() {
        let low = InferenceOptions.default.temperature(-0.5)
        let high = InferenceOptions.default.temperature(3.0)
        let normal = InferenceOptions.default.temperature(0.7)

        // InferenceOptions allows setting temperature to any value
        // Validation of ranges is deferred to providers or validation layers
        #expect(low.temperature == -0.5)
        #expect(high.temperature == 3.0)
        #expect(normal.temperature == 0.7)
    }

    @Test("MaxTokens accepts positive values")
    func maxTokensAcceptsPositiveValues() {
        let options = InferenceOptions.default.maxTokens(100)
        #expect(options.maxTokens == 100)
    }

    @Test("Negative maxTokens is allowed")
    func negativeMaxTokensAllowed() {
        let options = InferenceOptions.default.maxTokens(-1)
        // InferenceOptions allows setting negative values
        // Validation is deferred to providers or validation layers
        #expect(options.maxTokens == -1)
    }

    // MARK: - Stop Sequences

    @Test("Add single stop sequence")
    func addSingleStopSequence() {
        let options = InferenceOptions.default
            .addStopSequence("END")

        #expect(options.stopSequences.contains("END"))
    }

    @Test("Add multiple stop sequences")
    func addMultipleStopSequences() {
        let options = InferenceOptions.default
            .addStopSequence("A")
            .addStopSequence("B")
            .addStopSequence("C")

        #expect(options.stopSequences.count >= 3)
    }

    @Test("Clear stop sequences")
    func clearStopSequences() {
        let options = InferenceOptions.default
            .stopSequences("A", "B", "C")
            .clearStopSequences()

        #expect(options.stopSequences.isEmpty)
    }

    // MARK: - Equatable

    @Test("Options equality")
    func optionsEquality() {
        let options1 = InferenceOptions.default
            .temperature(0.7)
            .maxTokens(1000)

        let options2 = InferenceOptions.default
            .temperature(0.7)
            .maxTokens(1000)

        #expect(options1 == options2)
    }

    @Test("Options inequality on temperature")
    func optionsInequalityOnTemperature() {
        let options1 = InferenceOptions.default.temperature(0.7)
        let options2 = InferenceOptions.default.temperature(0.8)

        #expect(options1 != options2)
    }

    // MARK: - Builder Pattern for Complex Configs

    @Test("InferenceOptionsBuilder for complex configuration")
    func builderForComplexConfiguration() {
        let options = InferenceOptionsBuilder()
            .setTemperature(0.8)
            .setMaxTokens(2000)
            .setTopP(0.95)
            .addStopSequence("END")
            .addStopSequence("STOP")
            .build()

        #expect(options.temperature == 0.8)
        #expect(options.maxTokens == 2000)
        #expect(options.topP == 0.95)
        #expect(options.stopSequences.contains("END"))
        #expect(options.stopSequences.contains("STOP"))
    }

    // MARK: - Copy With Modifications

    @Test("Copy and modify options")
    func copyAndModifyOptions() {
        let base = InferenceOptions.default
            .temperature(0.7)
            .maxTokens(1000)

        let modified = base.with {
            $0.temperature = 0.9
        }

        #expect(base.temperature == 0.7)
        #expect(modified.temperature == 0.9)
        #expect(modified.maxTokens == 1000) // Preserved
    }
}

// MARK: - InferenceOptions Test Extensions

extension InferenceOptions {
    /// Copy with modifications helper for tests
    func with(_ modifications: (inout InferenceOptions) -> Void) -> InferenceOptions {
        var copy = self
        modifications(&copy)
        return copy
    }
}

// MARK: - InferenceOptionsBuilder

/// Builder class for constructing InferenceOptions
class InferenceOptionsBuilder {
    // MARK: Internal

    func setTemperature(_ value: Double) -> InferenceOptionsBuilder {
        temperature = value
        return self
    }

    func setMaxTokens(_ value: Int) -> InferenceOptionsBuilder {
        maxTokens = value
        return self
    }

    func setTopP(_ value: Double) -> InferenceOptionsBuilder {
        topP = value
        return self
    }

    func setTopK(_ value: Int) -> InferenceOptionsBuilder {
        topK = value
        return self
    }

    func setPresencePenalty(_ value: Double) -> InferenceOptionsBuilder {
        presencePenalty = value
        return self
    }

    func setFrequencyPenalty(_ value: Double) -> InferenceOptionsBuilder {
        frequencyPenalty = value
        return self
    }

    func addStopSequence(_ sequence: String) -> InferenceOptionsBuilder {
        stopSequences.append(sequence)
        return self
    }

    func build() -> InferenceOptions {
        InferenceOptions(
            temperature: temperature,
            maxTokens: maxTokens,
            stopSequences: stopSequences,
            topP: topP,
            topK: topK,
            presencePenalty: presencePenalty,
            frequencyPenalty: frequencyPenalty
        )
    }

    // MARK: Private

    private var temperature: Double = 1.0
    private var maxTokens: Int?
    private var stopSequences: [String] = []
    private var topP: Double?
    private var topK: Int?
    private var presencePenalty: Double?
    private var frequencyPenalty: Double?
}
