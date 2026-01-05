// ConduitTypeMappersTests.swift
// SwiftAgentsTests
//
// Tests for type mapping between SwiftAgents and Conduit types.

import Conduit
import Foundation
@testable import SwiftAgents
import Testing

@Suite("ConduitTypeMappers Tests")
struct ConduitTypeMappersTests {
    // MARK: - InferenceOptions to GenerateConfig Tests

    @Test("toConduitConfig converts basic options correctly")
    func toConduitConfigConvertsBasicOptionsCorrectly() {
        let options = InferenceOptions(
            temperature: 0.7,
            maxTokens: 1000,
            stopSequences: ["STOP"],
            topP: 0.9,
            topK: 50
        )

        let config = options.toConduitConfig()

        #expect(config.temperature == Float(0.7))
        #expect(config.maxTokens == 1000)
        #expect(config.stopSequences == ["STOP"])
        #expect(config.topP == Float(0.9))
        #expect(config.topK == 50)
    }

    @Test("toConduitConfig handles nil topP with default")
    func toConduitConfigHandlesNilTopPWithDefault() {
        let options = InferenceOptions(temperature: 0.7, maxTokens: 1000, topP: nil)

        let config = options.toConduitConfig()

        #expect(config.topP == 0.9) // Default value
    }

    @Test("toConduitConfig converts penalties correctly")
    func toConduitConfigConvertsPenaltiesCorrectly() {
        let options = InferenceOptions(
            temperature: 0.7,
            maxTokens: 1000,
            presencePenalty: 0.5,
            frequencyPenalty: 0.3
        )

        let config = options.toConduitConfig()

        #expect(config.presencePenalty == Float(0.5))
        #expect(config.frequencyPenalty == Float(0.3))
    }

    @Test("toConduitConfig handles nil penalties with defaults")
    func toConduitConfigHandlesNilPenaltiesWithDefaults() {
        let options = InferenceOptions(
            temperature: 0.7,
            maxTokens: 1000,
            presencePenalty: nil,
            frequencyPenalty: nil
        )

        let config = options.toConduitConfig()

        #expect(config.presencePenalty == 0.0)
        #expect(config.frequencyPenalty == 0.0)
    }

    @Test("from conduitConfig creates options correctly")
    func fromConduitConfigCreatesOptionsCorrectly() {
        let config = GenerateConfig(
            maxTokens: 1000,
            temperature: 0.7,
            topP: 0.9,
            topK: 50,
            frequencyPenalty: 0.3,
            presencePenalty: 0.5,
            stopSequences: ["STOP"]
        )

        let options = InferenceOptions.from(conduitConfig: config)

        #expect(abs(options.temperature - 0.7) < 0.001)
        #expect(options.maxTokens == 1000)
        #expect(abs(options.topP! - 0.9) < 0.001)
        #expect(options.topK == 50)
        #expect(abs(options.frequencyPenalty! - 0.3) < 0.001)
        #expect(abs(options.presencePenalty! - 0.5) < 0.001)
        #expect(options.stopSequences == ["STOP"])
    }

    @Test("round trip conversion preserves values within precision")
    func roundTripConversionPreservesValuesWithinPrecision() {
        let original = InferenceOptions(
            temperature: 0.75,
            maxTokens: 2000,
            stopSequences: ["END"],
            topP: 0.95,
            topK: 40,
            presencePenalty: 0.6,
            frequencyPenalty: 0.4
        )

        let config = original.toConduitConfig()
        let result = InferenceOptions.from(conduitConfig: config)

        // Float precision means values may differ slightly but should be very close
        #expect(abs(result.temperature - original.temperature) < 0.0001)
        #expect(result.maxTokens == original.maxTokens)
        #expect(result.stopSequences == original.stopSequences)
        #expect(abs(result.topP! - original.topP!) < 0.0001)
        #expect(result.topK == original.topK)
    }

    // MARK: - FinishReason Mapping Tests

    @Test("FinishReason.stop maps to completed")
    func finishReasonStopMapsToCompleted() {
        let conduitReason = FinishReason.stop
        let agentsReason = conduitReason.toSwiftAgentsFinishReason()

        #expect(agentsReason == .completed)
    }

    @Test("FinishReason.maxTokens maps to maxTokens")
    func finishReasonMaxTokensMapsToMaxTokens() {
        let conduitReason = FinishReason.maxTokens
        let agentsReason = conduitReason.toSwiftAgentsFinishReason()

        #expect(agentsReason == .maxTokens)
    }

    @Test("FinishReason.toolCalls maps to toolCall")
    func finishReasonToolCallsMapsToToolCall() {
        let conduitReason = FinishReason.toolCalls
        let agentsReason = conduitReason.toSwiftAgentsFinishReason()

        #expect(agentsReason == .toolCall)
    }

    @Test("FinishReason.contentFilter maps to contentFilter")
    func finishReasonContentFilterMapsToContentFilter() {
        let conduitReason = FinishReason.contentFilter
        let agentsReason = conduitReason.toSwiftAgentsFinishReason()

        #expect(agentsReason == .contentFilter)
    }

    @Test("FinishReason.cancelled maps to cancelled")
    func finishReasonCancelledMapsToCancelled() {
        let conduitReason = FinishReason.cancelled
        let agentsReason = conduitReason.toSwiftAgentsFinishReason()

        #expect(agentsReason == .cancelled)
    }

    @Test("FinishReason.stopSequence maps to completed")
    func finishReasonStopSequenceMapsToCompleted() {
        let conduitReason = FinishReason.stopSequence
        let agentsReason = conduitReason.toSwiftAgentsFinishReason()

        #expect(agentsReason == .completed)
    }

    // MARK: - SwiftAgents FinishReason to Conduit Tests

    @Test("SwiftAgents completed maps to Conduit stop")
    func swiftAgentsCompletedMapsToConduitStop() {
        let agentsReason = InferenceResponse.FinishReason.completed
        let conduitReason = agentsReason.toConduitFinishReason()

        #expect(conduitReason == .stop)
    }

    @Test("SwiftAgents maxTokens maps to Conduit maxTokens")
    func swiftAgentsMaxTokensMapsToConduitMaxTokens() {
        let agentsReason = InferenceResponse.FinishReason.maxTokens
        let conduitReason = agentsReason.toConduitFinishReason()

        #expect(conduitReason == .maxTokens)
    }

    @Test("SwiftAgents toolCall maps to Conduit toolCall")
    func swiftAgentsToolCallMapsToConduitToolCall() {
        let agentsReason = InferenceResponse.FinishReason.toolCall
        let conduitReason = agentsReason.toConduitFinishReason()

        #expect(conduitReason == .toolCall)
    }

    // MARK: - Usage Mapping Tests

    @Test("UsageStats converts to TokenUsage correctly")
    func usageStatsConvertsToTokenUsageCorrectly() {
        let usage = UsageStats(
            promptTokens: 100,
            completionTokens: 50
        )

        let tokenUsage = usage.toTokenUsage()

        #expect(tokenUsage.inputTokens == 100)
        #expect(tokenUsage.outputTokens == 50)
    }

    @Test("nil UsageStats maps to nil TokenUsage")
    func nilUsageStatsMapsToNilTokenUsage() {
        let usage: UsageStats? = nil

        let tokenUsage = usage?.toTokenUsage()

        #expect(tokenUsage == nil)
    }

    @Test("TokenUsage converts to UsageStats correctly")
    func tokenUsageConvertsToUsageStatsCorrectly() {
        let tokenUsage = InferenceResponse.TokenUsage(
            inputTokens: 100,
            outputTokens: 50
        )

        let usage = tokenUsage.toConduitUsageStats()

        #expect(usage.promptTokens == 100)
        #expect(usage.completionTokens == 50)
    }

    // MARK: - StructuredContent to SendableValue Tests

    @Test("string StructuredContent maps to string SendableValue")
    func stringStructuredContentMapsToStringSendableValue() {
        let content = StructuredContent.string("Hello, world!")
        let sendableValue = content.toSendableValue()

        if case let .string(text) = sendableValue {
            #expect(text == "Hello, world!")
        } else {
            Issue.record("Expected string SendableValue, got \(sendableValue)")
        }
    }

    @Test("number StructuredContent with integer maps to int SendableValue")
    func numberStructuredContentWithIntegerMapsToIntSendableValue() {
        let content = StructuredContent.number(42.0)
        let sendableValue = content.toSendableValue()

        if case let .int(value) = sendableValue {
            #expect(value == 42)
        } else {
            Issue.record("Expected int SendableValue, got \(sendableValue)")
        }
    }

    @Test("number StructuredContent with decimal maps to double SendableValue")
    func numberStructuredContentWithDecimalMapsToDoubleSendableValue() {
        let content = StructuredContent.number(42.5)
        let sendableValue = content.toSendableValue()

        if case let .double(value) = sendableValue {
            #expect(value == 42.5)
        } else {
            Issue.record("Expected double SendableValue, got \(sendableValue)")
        }
    }

    @Test("boolean StructuredContent maps to bool SendableValue")
    func booleanStructuredContentMapsToBoolSendableValue() {
        let content = StructuredContent.bool(true)
        let sendableValue = content.toSendableValue()

        if case let .bool(value) = sendableValue {
            #expect(value == true)
        } else {
            Issue.record("Expected bool SendableValue, got \(sendableValue)")
        }
    }

    @Test("null StructuredContent maps to null SendableValue")
    func nullStructuredContentMapsToNullSendableValue() {
        let content = StructuredContent.null
        let sendableValue = content.toSendableValue()

        if case .null = sendableValue {
            // Success
        } else {
            Issue.record("Expected null SendableValue, got \(sendableValue)")
        }
    }

    @Test("array StructuredContent maps to array SendableValue")
    func arrayStructuredContentMapsToArraySendableValue() {
        let content = StructuredContent.array([
            .string("item1"),
            .number(42),
            .bool(true)
        ])

        let sendableValue = content.toSendableValue()

        if case let .array(items) = sendableValue {
            #expect(items.count == 3)
        } else {
            Issue.record("Expected array SendableValue, got \(sendableValue)")
        }
    }

    @Test("object StructuredContent maps to dictionary SendableValue")
    func objectStructuredContentMapsToDictionarySendableValue() {
        let content = StructuredContent.object([
            "name": .string("John"),
            "age": .number(30)
        ])

        let sendableValue = content.toSendableValue()

        if case let .dictionary(dict) = sendableValue {
            #expect(dict.count == 2)
            #expect(dict["name"] != nil)
            #expect(dict["age"] != nil)
        } else {
            Issue.record("Expected dictionary SendableValue, got \(sendableValue)")
        }
    }

    // MARK: - SendableValue to StructuredContent Tests

    @Test("string SendableValue maps to string StructuredContent")
    func stringSendableValueMapsToStringStructuredContent() {
        let value = SendableValue.string("Test")
        let content = value.toStructuredContent()

        if case let .string(text) = content.kind {
            #expect(text == "Test")
        } else {
            Issue.record("Expected string StructuredContent, got \(content)")
        }
    }

    @Test("int SendableValue maps to number StructuredContent")
    func intSendableValueMapsToNumberStructuredContent() {
        let value = SendableValue.int(42)
        let content = value.toStructuredContent()

        if case let .number(num) = content.kind {
            #expect(num == 42.0)
        } else {
            Issue.record("Expected number StructuredContent, got \(content)")
        }
    }

    @Test("double SendableValue maps to number StructuredContent")
    func doubleSendableValueMapsToNumberStructuredContent() {
        let value = SendableValue.double(42.5)
        let content = value.toStructuredContent()

        if case let .number(num) = content.kind {
            #expect(num == 42.5)
        } else {
            Issue.record("Expected number StructuredContent, got \(content)")
        }
    }

    @Test("bool SendableValue maps to bool StructuredContent")
    func boolSendableValueMapsToBoolStructuredContent() {
        let value = SendableValue.bool(true)
        let content = value.toStructuredContent()

        if case let .bool(bool) = content.kind {
            #expect(bool == true)
        } else {
            Issue.record("Expected bool StructuredContent, got \(content)")
        }
    }

    @Test("null SendableValue maps to null StructuredContent")
    func nullSendableValueMapsToNullStructuredContent() {
        let value = SendableValue.null
        let content = value.toStructuredContent()

        if case .null = content.kind {
            // Success
        } else {
            Issue.record("Expected null StructuredContent, got \(content)")
        }
    }

    @Test("array SendableValue maps to array StructuredContent")
    func arraySendableValueMapsToArrayStructuredContent() {
        let value = SendableValue.array([
            .string("item"),
            .int(42)
        ])

        let content = value.toStructuredContent()

        if case let .array(items) = content.kind {
            #expect(items.count == 2)
        } else {
            Issue.record("Expected array StructuredContent, got \(content)")
        }
    }

    @Test("dictionary SendableValue maps to object StructuredContent")
    func dictionarySendableValueMapsToObjectStructuredContent() {
        let value = SendableValue.dictionary([
            "key": .string("value")
        ])

        let content = value.toStructuredContent()

        if case let .object(dict) = content.kind {
            #expect(dict.count == 1)
            #expect(dict["key"] != nil)
        } else {
            Issue.record("Expected object StructuredContent, got \(content)")
        }
    }

    // MARK: - Round Trip Tests

    @Test("StructuredContent round trip preserves string")
    func structuredContentRoundTripPreservesString() {
        let original = StructuredContent.string("Hello")
        let sendable = original.toSendableValue()
        let result = sendable.toStructuredContent()

        if case let .string(text) = result.kind {
            #expect(text == "Hello")
        } else {
            Issue.record("Round trip failed for string")
        }
    }

    @Test("StructuredContent round trip preserves nested structures")
    func structuredContentRoundTripPreservesNestedStructures() {
        let original = StructuredContent.object([
            "user": .object([
                "name": .string("John"),
                "age": .number(30),
                "active": .bool(true)
            ]),
            "items": .array([
                .string("item1"),
                .number(42)
            ])
        ])

        let sendable = original.toSendableValue()
        let result = sendable.toStructuredContent()

        if case let .object(dict) = result.kind {
            #expect(dict.count == 2)
            #expect(dict["user"] != nil)
            #expect(dict["items"] != nil)
        } else {
            Issue.record("Round trip failed for nested structure")
        }
    }

    // MARK: - ConduitMappingError Tests

    @Test("ConduitMappingError has descriptive messages")
    func conduitMappingErrorHasDescriptiveMessages() {
        let error1 = ConduitMappingError.argumentConversionFailed("test reason")
        #expect(error1.errorDescription?.contains("test reason") == true)

        let error2 = ConduitMappingError.toolCallCreationFailed("creation failed")
        #expect(error2.errorDescription?.contains("creation failed") == true)

        let error3 = ConduitMappingError.unexpectedType(expected: "string", actual: "number")
        #expect(error3.errorDescription?.contains("string") == true)
        #expect(error3.errorDescription?.contains("number") == true)
    }
}
