// ModelSettingsTests.swift
// SwiftAgentsTests
//
// Comprehensive tests for ModelSettings, ToolChoice, and supporting enums

import Foundation
@testable import SwiftAgents
import Testing

// MARK: - ModelSettingsInitializationTests

@Suite("ModelSettings Initialization Tests")
struct ModelSettingsInitializationTests {
    @Test("Default initialization - all values are nil")
    func defaultInitialization() {
        let settings = ModelSettings()

        #expect(settings.temperature == nil)
        #expect(settings.topP == nil)
        #expect(settings.topK == nil)
        #expect(settings.maxTokens == nil)
        #expect(settings.frequencyPenalty == nil)
        #expect(settings.presencePenalty == nil)
        #expect(settings.stopSequences == nil)
        #expect(settings.seed == nil)
        #expect(settings.toolChoice == nil)
        #expect(settings.parallelToolCalls == nil)
        #expect(settings.truncation == nil)
        #expect(settings.verbosity == nil)
        #expect(settings.promptCacheRetention == nil)
        #expect(settings.repetitionPenalty == nil)
        #expect(settings.minP == nil)
        #expect(settings.providerSettings == nil)
    }

    @Test("Static default preset - all values are nil")
    func staticDefaultPreset() {
        let settings = ModelSettings.default

        #expect(settings.temperature == nil)
        #expect(settings.topP == nil)
        #expect(settings.topK == nil)
        #expect(settings.maxTokens == nil)
    }

    @Test("Static creative preset - temperature 1.2, topP 0.95")
    func staticCreativePreset() {
        let settings = ModelSettings.creative

        #expect(settings.temperature == 1.2)
        #expect(settings.topP == 0.95)
        #expect(settings.maxTokens == nil)
        #expect(settings.topK == nil)
    }

    @Test("Static precise preset - temperature 0.2, topP 0.9")
    func staticPrecisePreset() {
        let settings = ModelSettings.precise

        #expect(settings.temperature == 0.2)
        #expect(settings.topP == 0.9)
        #expect(settings.maxTokens == nil)
        #expect(settings.topK == nil)
    }

    @Test("Static balanced preset - temperature 0.7, topP 0.9")
    func staticBalancedPreset() {
        let settings = ModelSettings.balanced

        #expect(settings.temperature == 0.7)
        #expect(settings.topP == 0.9)
        #expect(settings.maxTokens == nil)
        #expect(settings.topK == nil)
    }
}

// MARK: - ModelSettingsFluentBuilderTests

@Suite("ModelSettings Fluent Builder Tests")
struct ModelSettingsFluentBuilderTests {
    @Test("Temperature builder method")
    func temperatureBuilder() {
        let settings = ModelSettings.default.temperature(0.8)

        #expect(settings.temperature == 0.8)
        #expect(settings.topP == nil)
        #expect(settings.maxTokens == nil)
    }

    @Test("TopP builder method")
    func topPBuilder() {
        let settings = ModelSettings.default.topP(0.85)

        #expect(settings.topP == 0.85)
        #expect(settings.temperature == nil)
        #expect(settings.maxTokens == nil)
    }

    @Test("MaxTokens builder method")
    func maxTokensBuilder() {
        let settings = ModelSettings.default.maxTokens(2048)

        #expect(settings.maxTokens == 2048)
        #expect(settings.temperature == nil)
        #expect(settings.topP == nil)
    }

    @Test("ToolChoice builder method")
    func toolChoiceBuilder() {
        let settings = ModelSettings.default.toolChoice(.required)

        #expect(settings.toolChoice == .required)
        #expect(settings.temperature == nil)
    }

    @Test("Chained builders - multiple properties set")
    func chainedBuilders() {
        let settings = ModelSettings.default
            .temperature(0.7)
            .topP(0.9)
            .maxTokens(1024)
            .topK(50)
            .frequencyPenalty(0.5)
            .presencePenalty(0.3)
            .seed(42)
            .toolChoice(.auto)
            .parallelToolCalls(true)
            .truncation(.auto)
            .verbosity(.medium)
            .promptCacheRetention(.twentyFourHours)
            .repetitionPenalty(1.1)
            .minP(0.05)
            .stopSequences(["STOP", "END"])

        #expect(settings.temperature == 0.7)
        #expect(settings.topP == 0.9)
        #expect(settings.maxTokens == 1024)
        #expect(settings.topK == 50)
        #expect(settings.frequencyPenalty == 0.5)
        #expect(settings.presencePenalty == 0.3)
        #expect(settings.seed == 42)
        #expect(settings.toolChoice == .auto)
        #expect(settings.parallelToolCalls == true)
        #expect(settings.truncation == .auto)
        #expect(settings.verbosity == .medium)
        #expect(settings.promptCacheRetention == .twentyFourHours)
        #expect(settings.repetitionPenalty == 1.1)
        #expect(settings.minP == 0.05)
        #expect(settings.stopSequences == ["STOP", "END"])
    }

    @Test("Fluent builder does not mutate original")
    func fluentBuilderImmutability() {
        let original = ModelSettings.default
        let modified = original
            .temperature(0.5)
            .maxTokens(512)

        // Original unchanged (value semantics)
        #expect(original.temperature == nil)
        #expect(original.maxTokens == nil)

        // Modified has new values
        #expect(modified.temperature == 0.5)
        #expect(modified.maxTokens == 512)
    }
}

// MARK: - ModelSettingsValidationTests

@Suite("ModelSettings Validation Tests")
struct ModelSettingsValidationTests {
    @Test("Valid temperature at lower bound")
    func validTemperatureLowerBound() throws {
        let settings = ModelSettings().temperature(0.0)
        try settings.validate()
    }

    @Test("Valid temperature at upper bound")
    func validTemperatureUpperBound() throws {
        let settings = ModelSettings().temperature(2.0)
        try settings.validate()
    }

    @Test("Valid temperature in middle range")
    func validTemperature() throws {
        let settings = ModelSettings().temperature(1.0)
        try settings.validate()
    }

    @Test("Invalid temperature too high throws")
    func invalidTemperatureTooHigh() {
        let settings = ModelSettings().temperature(2.1)
        #expect(throws: ModelSettingsValidationError.self) {
            try settings.validate()
        }
    }

    @Test("Invalid temperature too low throws")
    func invalidTemperatureTooLow() {
        let settings = ModelSettings().temperature(-0.1)
        #expect(throws: ModelSettingsValidationError.self) {
            try settings.validate()
        }
    }

    @Test("Valid topP at lower bound")
    func validTopPLowerBound() throws {
        let settings = ModelSettings().topP(0.0)
        try settings.validate()
    }

    @Test("Valid topP at upper bound")
    func validTopPUpperBound() throws {
        let settings = ModelSettings().topP(1.0)
        try settings.validate()
    }

    @Test("Valid topP in middle range")
    func validTopP() throws {
        let settings = ModelSettings().topP(0.5)
        try settings.validate()
    }

    @Test("Invalid topP too high throws")
    func invalidTopPTooHigh() {
        let settings = ModelSettings().topP(1.1)
        #expect(throws: ModelSettingsValidationError.self) {
            try settings.validate()
        }
    }

    @Test("Invalid topP too low throws")
    func invalidTopPTooLow() {
        let settings = ModelSettings().topP(-0.1)
        #expect(throws: ModelSettingsValidationError.self) {
            try settings.validate()
        }
    }

    @Test("Valid maxTokens positive value")
    func validMaxTokens() throws {
        let settings = ModelSettings().maxTokens(1000)
        try settings.validate()
    }

    @Test("Valid maxTokens at minimum boundary")
    func validMaxTokensMinimum() throws {
        let settings = ModelSettings().maxTokens(1)
        try settings.validate()
    }

    @Test("Invalid maxTokens zero throws")
    func invalidMaxTokensZero() {
        let settings = ModelSettings().maxTokens(0)
        #expect(throws: ModelSettingsValidationError.self) {
            try settings.validate()
        }
    }

    @Test("Invalid maxTokens negative throws")
    func invalidMaxTokensNegative() {
        let settings = ModelSettings().maxTokens(-100)
        #expect(throws: ModelSettingsValidationError.self) {
            try settings.validate()
        }
    }

    @Test("Valid frequencyPenalty at lower bound")
    func validFrequencyPenaltyLowerBound() throws {
        let settings = ModelSettings().frequencyPenalty(-2.0)
        try settings.validate()
    }

    @Test("Valid frequencyPenalty at upper bound")
    func validFrequencyPenaltyUpperBound() throws {
        let settings = ModelSettings().frequencyPenalty(2.0)
        try settings.validate()
    }

    @Test("Valid frequencyPenalty in middle range")
    func validFrequencyPenalty() throws {
        let settings = ModelSettings().frequencyPenalty(0.5)
        try settings.validate()
    }

    @Test("Invalid frequencyPenalty too high throws")
    func invalidFrequencyPenaltyTooHigh() {
        let settings = ModelSettings().frequencyPenalty(2.1)
        #expect(throws: ModelSettingsValidationError.self) {
            try settings.validate()
        }
    }

    @Test("Invalid frequencyPenalty too low throws")
    func invalidFrequencyPenaltyTooLow() {
        let settings = ModelSettings().frequencyPenalty(-2.1)
        #expect(throws: ModelSettingsValidationError.self) {
            try settings.validate()
        }
    }

    @Test("Valid presencePenalty at lower bound")
    func validPresencePenaltyLowerBound() throws {
        let settings = ModelSettings().presencePenalty(-2.0)
        try settings.validate()
    }

    @Test("Valid presencePenalty at upper bound")
    func validPresencePenaltyUpperBound() throws {
        let settings = ModelSettings().presencePenalty(2.0)
        try settings.validate()
    }

    @Test("Valid presencePenalty in middle range")
    func validPresencePenalty() throws {
        let settings = ModelSettings().presencePenalty(0.0)
        try settings.validate()
    }

    @Test("Invalid presencePenalty too high throws")
    func invalidPresencePenaltyTooHigh() {
        let settings = ModelSettings().presencePenalty(2.1)
        #expect(throws: ModelSettingsValidationError.self) {
            try settings.validate()
        }
    }

    @Test("Invalid presencePenalty too low throws")
    func invalidPresencePenaltyTooLow() {
        let settings = ModelSettings().presencePenalty(-2.1)
        #expect(throws: ModelSettingsValidationError.self) {
            try settings.validate()
        }
    }

    @Test("Valid topK positive value")
    func validTopK() throws {
        let settings = ModelSettings().topK(50)
        try settings.validate()
    }

    @Test("Valid topK at minimum boundary")
    func validTopKMinimum() throws {
        let settings = ModelSettings().topK(1)
        try settings.validate()
    }

    @Test("Invalid topK zero throws")
    func invalidTopKZero() {
        let settings = ModelSettings().topK(0)
        #expect(throws: ModelSettingsValidationError.self) {
            try settings.validate()
        }
    }

    @Test("Invalid topK negative throws")
    func invalidTopKNegative() {
        let settings = ModelSettings().topK(-10)
        #expect(throws: ModelSettingsValidationError.self) {
            try settings.validate()
        }
    }

    @Test("Validate with all valid settings passes")
    func validateWithAllValidSettings() throws {
        let settings = ModelSettings()
            .temperature(1.0)
            .topP(0.9)
            .topK(40)
            .maxTokens(2048)
            .frequencyPenalty(0.5)
            .presencePenalty(0.5)
            .minP(0.1)

        try settings.validate()
    }

    @Test("Valid minP at lower bound")
    func validMinPLowerBound() throws {
        let settings = ModelSettings().minP(0.0)
        try settings.validate()
    }

    @Test("Valid minP at upper bound")
    func validMinPUpperBound() throws {
        let settings = ModelSettings().minP(1.0)
        try settings.validate()
    }

    @Test("Invalid minP too high throws")
    func invalidMinPTooHigh() {
        let settings = ModelSettings().minP(1.1)
        #expect(throws: ModelSettingsValidationError.self) {
            try settings.validate()
        }
    }

    @Test("Invalid minP too low throws")
    func invalidMinPTooLow() {
        let settings = ModelSettings().minP(-0.1)
        #expect(throws: ModelSettingsValidationError.self) {
            try settings.validate()
        }
    }

    // MARK: - NaN/Infinity Validation Tests

    @Test("Invalid temperature NaN throws")
    func invalidTemperatureNaN() {
        let settings = ModelSettings().temperature(.nan)
        #expect(throws: ModelSettingsValidationError.self) {
            try settings.validate()
        }
    }

    @Test("Invalid temperature positive infinity throws")
    func invalidTemperaturePositiveInfinity() {
        let settings = ModelSettings().temperature(.infinity)
        #expect(throws: ModelSettingsValidationError.self) {
            try settings.validate()
        }
    }

    @Test("Invalid temperature negative infinity throws")
    func invalidTemperatureNegativeInfinity() {
        let settings = ModelSettings().temperature(-.infinity)
        #expect(throws: ModelSettingsValidationError.self) {
            try settings.validate()
        }
    }

    @Test("Invalid topP NaN throws")
    func invalidTopPNaN() {
        let settings = ModelSettings().topP(.nan)
        #expect(throws: ModelSettingsValidationError.self) {
            try settings.validate()
        }
    }

    @Test("Invalid topP infinity throws")
    func invalidTopPInfinity() {
        let settings = ModelSettings().topP(.infinity)
        #expect(throws: ModelSettingsValidationError.self) {
            try settings.validate()
        }
    }

    @Test("Invalid frequencyPenalty NaN throws")
    func invalidFrequencyPenaltyNaN() {
        let settings = ModelSettings().frequencyPenalty(.nan)
        #expect(throws: ModelSettingsValidationError.self) {
            try settings.validate()
        }
    }

    @Test("Invalid presencePenalty NaN throws")
    func invalidPresencePenaltyNaN() {
        let settings = ModelSettings().presencePenalty(.nan)
        #expect(throws: ModelSettingsValidationError.self) {
            try settings.validate()
        }
    }

    @Test("Invalid minP NaN throws")
    func invalidMinPNaN() {
        let settings = ModelSettings().minP(.nan)
        #expect(throws: ModelSettingsValidationError.self) {
            try settings.validate()
        }
    }

    // MARK: - Repetition Penalty Validation Tests

    @Test("Valid repetitionPenalty positive value")
    func validRepetitionPenalty() throws {
        let settings = ModelSettings().repetitionPenalty(1.5)
        try settings.validate()
    }

    @Test("Valid repetitionPenalty at zero bound")
    func validRepetitionPenaltyZero() throws {
        let settings = ModelSettings().repetitionPenalty(0.0)
        try settings.validate()
    }

    @Test("Invalid repetitionPenalty negative throws")
    func invalidRepetitionPenaltyNegative() {
        let settings = ModelSettings().repetitionPenalty(-0.5)
        #expect(throws: ModelSettingsValidationError.self) {
            try settings.validate()
        }
    }

    @Test("Invalid repetitionPenalty NaN throws")
    func invalidRepetitionPenaltyNaN() {
        let settings = ModelSettings().repetitionPenalty(.nan)
        #expect(throws: ModelSettingsValidationError.self) {
            try settings.validate()
        }
    }

    @Test("Invalid repetitionPenalty infinity throws")
    func invalidRepetitionPenaltyInfinity() {
        let settings = ModelSettings().repetitionPenalty(.infinity)
        #expect(throws: ModelSettingsValidationError.self) {
            try settings.validate()
        }
    }
}

// MARK: - ModelSettingsMergeTests

@Suite("ModelSettings Merge Tests")
struct ModelSettingsMergeTests {
    @Test("Merge empty settings with populated settings")
    func mergeEmptyWithSettings() {
        let empty = ModelSettings()
        let populated = ModelSettings()
            .temperature(0.8)
            .topP(0.9)
            .maxTokens(1024)

        let merged = empty.merged(with: populated)

        #expect(merged.temperature == 0.8)
        #expect(merged.topP == 0.9)
        #expect(merged.maxTokens == 1024)
    }

    @Test("Merge settings - other takes precedence")
    func mergeSettingsOverrides() {
        let base = ModelSettings()
            .temperature(0.5)
            .topP(0.8)
            .maxTokens(512)

        let overrides = ModelSettings()
            .temperature(1.0)
            .maxTokens(2048)

        let merged = base.merged(with: overrides)

        #expect(merged.temperature == 1.0) // Overridden
        #expect(merged.topP == 0.8) // Kept from base
        #expect(merged.maxTokens == 2048) // Overridden
    }

    @Test("Merge provider settings - dictionaries are merged")
    func mergeProviderSettings() {
        let base = ModelSettings()
            .providerSettings([
                "key1": .string("value1"),
                "key2": .int(42)
            ])

        let overrides = ModelSettings()
            .providerSettings([
                "key2": .int(100), // Override
                "key3": .bool(true) // New
            ])

        let merged = base.merged(with: overrides)

        #expect(merged.providerSettings?["key1"] == .string("value1"))
        #expect(merged.providerSettings?["key2"] == .int(100)) // Overridden
        #expect(merged.providerSettings?["key3"] == .bool(true)) // New
    }

    @Test("Merge with nil provider settings returns base")
    func mergeNilProviderSettings() {
        let base = ModelSettings()
            .providerSettings(["key": .string("value")])

        let overrides = ModelSettings()

        let merged = base.merged(with: overrides)

        #expect(merged.providerSettings?["key"] == .string("value"))
    }

    @Test("Merge nil base with populated provider settings")
    func mergeNilBaseProviderSettings() {
        let base = ModelSettings()

        let overrides = ModelSettings()
            .providerSettings(["key": .string("value")])

        let merged = base.merged(with: overrides)

        #expect(merged.providerSettings?["key"] == .string("value"))
    }
}

// MARK: - ToolChoiceTests

@Suite("ToolChoice Tests")
struct ToolChoiceTests {
    @Test("ToolChoice auto case")
    func toolChoiceAuto() {
        let choice = ToolChoice.auto
        #expect(choice == .auto)
    }

    @Test("ToolChoice none case")
    func toolChoiceNone() {
        let choice = ToolChoice.none
        #expect(choice == .none)
    }

    @Test("ToolChoice required case")
    func toolChoiceRequired() {
        let choice = ToolChoice.required
        #expect(choice == .required)
    }

    @Test("ToolChoice specific case with tool name")
    func toolChoiceSpecific() {
        let choice = ToolChoice.specific(toolName: "calculator")
        if case let .specific(name) = choice {
            #expect(name == "calculator")
        } else {
            Issue.record("Expected .specific case")
        }
    }

    @Test("ToolChoice encoding and decoding - auto")
    func toolChoiceEncodingAuto() throws {
        let original = ToolChoice.auto
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ToolChoice.self, from: encoded)

        #expect(decoded == original)
    }

    @Test("ToolChoice encoding and decoding - none")
    func toolChoiceEncodingNone() throws {
        let original = ToolChoice.none
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ToolChoice.self, from: encoded)

        #expect(decoded == original)
    }

    @Test("ToolChoice encoding and decoding - required")
    func toolChoiceEncodingRequired() throws {
        let original = ToolChoice.required
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ToolChoice.self, from: encoded)

        #expect(decoded == original)
    }

    @Test("ToolChoice encoding and decoding - specific")
    func toolChoiceEncodingSpecific() throws {
        let original = ToolChoice.specific(toolName: "search_tool")
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ToolChoice.self, from: encoded)

        #expect(decoded == original)
    }

    @Test("ToolChoice equatable - same cases are equal")
    func toolChoiceEquatable() {
        #expect(ToolChoice.auto == .auto)
        #expect(ToolChoice.none == .none)
        #expect(ToolChoice.required == .required)
        #expect(ToolChoice.specific(toolName: "test") == .specific(toolName: "test"))
    }

    @Test("ToolChoice equatable - different cases are not equal")
    func toolChoiceNotEquatable() {
        #expect(ToolChoice.auto != .none)
        #expect(ToolChoice.auto != .required)
        #expect(ToolChoice.none != .required)
        #expect(ToolChoice.specific(toolName: "a") != .specific(toolName: "b"))
    }
}

// MARK: - TruncationStrategyTests

@Suite("TruncationStrategy Tests")
struct TruncationStrategyTests {
    @Test("TruncationStrategy auto case")
    func truncationStrategyAuto() {
        let strategy = TruncationStrategy.auto
        #expect(strategy == .auto)
        #expect(strategy.rawValue == "auto")
    }

    @Test("TruncationStrategy disabled case")
    func truncationStrategyDisabled() {
        let strategy = TruncationStrategy.disabled
        #expect(strategy == .disabled)
        #expect(strategy.rawValue == "disabled")
    }

    @Test("TruncationStrategy encoding and decoding")
    func truncationStrategyCodable() throws {
        for strategy in [TruncationStrategy.auto, .disabled] {
            let encoded = try JSONEncoder().encode(strategy)
            let decoded = try JSONDecoder().decode(TruncationStrategy.self, from: encoded)
            #expect(decoded == strategy)
        }
    }
}

// MARK: - VerbosityTests

@Suite("Verbosity Tests")
struct VerbosityTests {
    @Test("Verbosity low case")
    func verbosityLow() {
        let verbosity = Verbosity.low
        #expect(verbosity == .low)
        #expect(verbosity.rawValue == "low")
    }

    @Test("Verbosity medium case")
    func verbosityMedium() {
        let verbosity = Verbosity.medium
        #expect(verbosity == .medium)
        #expect(verbosity.rawValue == "medium")
    }

    @Test("Verbosity high case")
    func verbosityHigh() {
        let verbosity = Verbosity.high
        #expect(verbosity == .high)
        #expect(verbosity.rawValue == "high")
    }

    @Test("Verbosity encoding and decoding")
    func verbosityCodable() throws {
        for verbosity in [Verbosity.low, .medium, .high] {
            let encoded = try JSONEncoder().encode(verbosity)
            let decoded = try JSONDecoder().decode(Verbosity.self, from: encoded)
            #expect(decoded == verbosity)
        }
    }
}

// MARK: - CacheRetentionTests

@Suite("CacheRetention Tests")
struct CacheRetentionTests {
    @Test("CacheRetention inMemory case")
    func cacheRetentionInMemory() {
        let retention = CacheRetention.inMemory
        #expect(retention == .inMemory)
        #expect(retention.rawValue == "in_memory")
    }

    @Test("CacheRetention twentyFourHours case")
    func cacheRetentionTwentyFourHours() {
        let retention = CacheRetention.twentyFourHours
        #expect(retention == .twentyFourHours)
        #expect(retention.rawValue == "24h")
    }

    @Test("CacheRetention fiveMinutes case")
    func cacheRetentionFiveMinutes() {
        let retention = CacheRetention.fiveMinutes
        #expect(retention == .fiveMinutes)
        #expect(retention.rawValue == "5m")
    }

    @Test("CacheRetention encoding and decoding")
    func cacheRetentionCodable() throws {
        for retention in [CacheRetention.inMemory, .twentyFourHours, .fiveMinutes] {
            let encoded = try JSONEncoder().encode(retention)
            let decoded = try JSONDecoder().decode(CacheRetention.self, from: encoded)
            #expect(decoded == retention)
        }
    }
}

// MARK: - ModelSettingsValidationErrorTests

@Suite("ModelSettingsValidationError Tests")
struct ModelSettingsValidationErrorTests {
    @Test("Error descriptions contain relevant information")
    func errorDescriptions() {
        let errors: [ModelSettingsValidationError] = [
            .invalidTemperature(3.0),
            .invalidTopP(1.5),
            .invalidTopK(0),
            .invalidMaxTokens(-1),
            .invalidFrequencyPenalty(3.0),
            .invalidPresencePenalty(-3.0),
            .invalidMinP(2.0)
        ]

        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }

    @Test("Invalid temperature error description contains value")
    func invalidTemperatureErrorDescription() {
        let error = ModelSettingsValidationError.invalidTemperature(3.5)
        #expect(error.errorDescription?.contains("3.5") == true)
        #expect(error.errorDescription?.contains("temperature") == true)
    }

    @Test("Invalid topP error description contains value")
    func invalidTopPErrorDescription() {
        let error = ModelSettingsValidationError.invalidTopP(1.5)
        #expect(error.errorDescription?.contains("1.5") == true)
        #expect(error.errorDescription?.contains("topP") == true)
    }

    @Test("Invalid topK error description contains value")
    func invalidTopKErrorDescription() {
        let error = ModelSettingsValidationError.invalidTopK(-5)
        #expect(error.errorDescription?.contains("-5") == true)
        #expect(error.errorDescription?.contains("topK") == true)
    }

    @Test("Invalid maxTokens error description contains value")
    func invalidMaxTokensErrorDescription() {
        let error = ModelSettingsValidationError.invalidMaxTokens(0)
        #expect(error.errorDescription?.contains("0") == true)
        #expect(error.errorDescription?.contains("maxTokens") == true)
    }
}

// MARK: - ModelSettingsCodableTests

@Suite("ModelSettings Codable Tests")
struct ModelSettingsCodableTests {
    @Test("ModelSettings encoding and decoding with all properties")
    func fullCodable() throws {
        let original = ModelSettings()
            .temperature(0.8)
            .topP(0.9)
            .topK(40)
            .maxTokens(2048)
            .frequencyPenalty(0.5)
            .presencePenalty(0.3)
            .stopSequences(["STOP"])
            .seed(12345)
            .toolChoice(.auto)
            .parallelToolCalls(true)
            .truncation(.auto)
            .verbosity(.medium)
            .promptCacheRetention(.twentyFourHours)
            .repetitionPenalty(1.1)
            .minP(0.05)

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ModelSettings.self, from: encoded)

        #expect(decoded == original)
    }

    @Test("ModelSettings encoding and decoding with nil values")
    func codableWithNilValues() throws {
        let original = ModelSettings()

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ModelSettings.self, from: encoded)

        #expect(decoded == original)
    }

    @Test("ModelSettings encoding and decoding with provider settings")
    func codableWithProviderSettings() throws {
        let original = ModelSettings()
            .providerSettings([
                "stringKey": .string("value"),
                "intKey": .int(42),
                "boolKey": .bool(true)
            ])

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ModelSettings.self, from: encoded)

        #expect(decoded.providerSettings?["stringKey"] == .string("value"))
        #expect(decoded.providerSettings?["intKey"] == .int(42))
        #expect(decoded.providerSettings?["boolKey"] == .bool(true))
    }
}

// MARK: - ModelSettingsEquatableTests

@Suite("ModelSettings Equatable Tests")
struct ModelSettingsEquatableTests {
    @Test("Equal settings are equal")
    func equalSettings() {
        let settings1 = ModelSettings()
            .temperature(0.7)
            .topP(0.9)
            .maxTokens(1024)

        let settings2 = ModelSettings()
            .temperature(0.7)
            .topP(0.9)
            .maxTokens(1024)

        #expect(settings1 == settings2)
    }

    @Test("Different settings are not equal")
    func differentSettings() {
        let settings1 = ModelSettings().temperature(0.7)
        let settings2 = ModelSettings().temperature(0.8)

        #expect(settings1 != settings2)
    }

    @Test("Presets are equatable")
    func presetsEquatable() {
        let creative1 = ModelSettings.creative
        let creative2 = ModelSettings.creative

        #expect(creative1 == creative2)
        #expect(ModelSettings.creative != ModelSettings.precise)
        #expect(ModelSettings.precise != ModelSettings.balanced)
    }
}

// MARK: - ModelSettingsDescriptionTests

@Suite("ModelSettings CustomStringConvertible Tests")
struct ModelSettingsDescriptionTests {
    @Test("Default settings description")
    func defaultDescription() {
        let settings = ModelSettings()
        #expect(settings.description == "ModelSettings(default)")
    }

    @Test("Settings with values have descriptive description")
    func descriptionWithValues() {
        let settings = ModelSettings()
            .temperature(0.8)
            .maxTokens(1024)

        #expect(settings.description.contains("temperature: 0.8"))
        #expect(settings.description.contains("maxTokens: 1024"))
    }
}
