// ModelSettingsTests+Enums.swift
// SwarmTests
//
// Tests for ModelSettings supporting enums: ToolChoice, TruncationStrategy, Verbosity, CacheRetention.

import Foundation
@testable import Swarm
import Testing

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
