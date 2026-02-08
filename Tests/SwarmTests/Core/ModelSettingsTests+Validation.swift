// ModelSettingsTests+Validation.swift
// SwarmTests
//
// Validation tests for ModelSettings.

import Foundation
@testable import Swarm
import Testing

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
