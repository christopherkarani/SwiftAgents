// ModelSettingsTests.swift
// SwarmTests
//
// Comprehensive tests for ModelSettings, ToolChoice, and supporting enums.
//
// Tests are split across multiple files for maintainability:
// - ModelSettingsTests.swift: Initialization, fluent builder, merge, codable, equatable
// - ModelSettingsTests+Validation.swift: All validation tests
// - ModelSettingsTests+Enums.swift: ToolChoice, TruncationStrategy, Verbosity, CacheRetention

import Foundation
@testable import Swarm
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

// MARK: - ModelSettingsMergeTests

@Suite("ModelSettings Merge Tests")
struct ModelSettingsMergeTests {
    @Test("Merge empty settings with populated settings")
    func mergeEmptyWithSettings() throws {
        let empty = ModelSettings()
        let populated = ModelSettings()
            .temperature(0.8)
            .topP(0.9)
            .maxTokens(1024)

        let merged = try empty.merged(with: populated)

        #expect(merged.temperature == 0.8)
        #expect(merged.topP == 0.9)
        #expect(merged.maxTokens == 1024)
    }

    @Test("Merge settings - other takes precedence")
    func mergeSettingsOverrides() throws {
        let base = ModelSettings()
            .temperature(0.5)
            .topP(0.8)
            .maxTokens(512)

        let overrides = ModelSettings()
            .temperature(1.0)
            .maxTokens(2048)

        let merged = try base.merged(with: overrides)

        #expect(merged.temperature == 1.0) // Overridden
        #expect(merged.topP == 0.8) // Kept from base
        #expect(merged.maxTokens == 2048) // Overridden
    }

    @Test("Merge provider settings - dictionaries are merged")
    func mergeProviderSettings() throws {
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

        let merged = try base.merged(with: overrides)

        #expect(merged.providerSettings?["key1"] == .string("value1"))
        #expect(merged.providerSettings?["key2"] == .int(100)) // Overridden
        #expect(merged.providerSettings?["key3"] == .bool(true)) // New
    }

    @Test("Merge with nil provider settings returns base")
    func mergeNilProviderSettings() throws {
        let base = ModelSettings()
            .providerSettings(["key": .string("value")])

        let overrides = ModelSettings()

        let merged = try base.merged(with: overrides)

        #expect(merged.providerSettings?["key"] == .string("value"))
    }

    @Test("Merge nil base with populated provider settings")
    func mergeNilBaseProviderSettings() throws {
        let base = ModelSettings()

        let overrides = ModelSettings()
            .providerSettings(["key": .string("value")])

        let merged = try base.merged(with: overrides)

        #expect(merged.providerSettings?["key"] == .string("value"))
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
