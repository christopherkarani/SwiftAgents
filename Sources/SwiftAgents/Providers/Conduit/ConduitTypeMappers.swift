// ConduitTypeMappers.swift
// SwiftAgents Framework
//
// Type mapping utilities for converting between SwiftAgents and Conduit types.

import Conduit
import Foundation

// MARK: - InferenceOptions to GenerateConfig

extension InferenceOptions {
    /// Converts SwiftAgents `InferenceOptions` to Conduit `GenerateConfig`.
    ///
    /// This mapper handles the conversion of generation parameters including:
    /// - Temperature (Double to Float conversion)
    /// - Sampling parameters (topP, topK)
    /// - Token limits (maxTokens)
    /// - Penalties (frequency, presence)
    /// - Stop sequences
    ///
    /// - Note: **Precision Loss**: Several parameters undergo `Double` to `Float` conversion
    ///   (`temperature`, `topP`, `frequencyPenalty`, `presencePenalty`). This conversion may
    ///   lose precision beyond 6-7 significant decimal digits. For LLM inference parameters,
    ///   this precision loss is negligible and has no practical impact on generation quality,
    ///   as these parameters typically use values between 0.0 and 2.0 with at most 2-3
    ///   significant digits (e.g., temperature=0.7, topP=0.95).
    ///
    /// - Returns: A Conduit `GenerateConfig` with equivalent settings.
    public func toConduitConfig() -> GenerateConfig {
        // Note: Double to Float conversion for temperature, topP, and penalties.
        // Precision loss beyond 6-7 decimal places is acceptable for LLM parameters.
        GenerateConfig(
            maxTokens: maxTokens,
            temperature: Float(temperature),
            topP: topP.map { Float($0) } ?? 0.9,
            topK: topK,
            frequencyPenalty: frequencyPenalty.map { Float($0) } ?? 0.0,
            presencePenalty: presencePenalty.map { Float($0) } ?? 0.0,
            stopSequences: stopSequences
        )
    }

    /// Creates `InferenceOptions` from a Conduit `GenerateConfig`.
    ///
    /// This reverse mapper allows converting Conduit configuration back to
    /// SwiftAgents format for consistency in multi-provider scenarios.
    ///
    /// - Note: Float to Double conversion is lossless. Any precision that was lost
    ///   during the original Double to Float conversion (see `toConduitConfig()`)
    ///   cannot be recovered by this reverse conversion.
    ///
    /// - Parameter config: The Conduit `GenerateConfig` to convert.
    /// - Returns: Equivalent SwiftAgents `InferenceOptions`.
    public static func from(conduitConfig config: GenerateConfig) -> InferenceOptions {
        // Float to Double is lossless; any precision lost in toConduitConfig() remains lost
        InferenceOptions(
            temperature: Double(config.temperature),
            maxTokens: config.maxTokens,
            stopSequences: config.stopSequences,
            topP: Double(config.topP),
            topK: config.topK,
            presencePenalty: Double(config.presencePenalty),
            frequencyPenalty: Double(config.frequencyPenalty)
        )
    }
}

// MARK: - GenerationResult to InferenceResponse

extension GenerationResult {
    /// Converts Conduit `GenerationResult` to SwiftAgents `InferenceResponse`.
    ///
    /// This mapper handles:
    /// - Text content extraction
    /// - Tool call conversion (AIToolCall to ParsedToolCall)
    /// - Finish reason mapping
    /// - Usage statistics conversion
    ///
    /// - Returns: A SwiftAgents `InferenceResponse` with equivalent data.
    /// - Throws: `ConduitMappingError` if tool call conversion fails.
    public func toInferenceResponse() throws -> InferenceResponse {
        let parsedToolCalls = try toolCalls.map { call in
            try call.toParsedToolCall()
        }

        return InferenceResponse(
            content: text.isEmpty ? nil : text,
            toolCalls: parsedToolCalls,
            finishReason: finishReason.toSwiftAgentsFinishReason(),
            usage: usage?.toTokenUsage()
        )
    }
}

// MARK: - FinishReason Mapping

extension FinishReason {
    /// Converts Conduit `FinishReason` to SwiftAgents `InferenceResponse.FinishReason`.
    ///
    /// Mapping:
    /// - `.stop`, `.stopSequence` -> `.completed`
    /// - `.maxTokens` -> `.maxTokens`
    /// - `.toolCall`, `.toolCalls` -> `.toolCall`
    /// - `.contentFilter` -> `.contentFilter`
    /// - `.cancelled` -> `.cancelled`
    /// - `.pauseTurn`, `.modelContextWindowExceeded` -> `.completed` (graceful fallback)
    ///
    /// - Returns: The equivalent SwiftAgents finish reason.
    public func toSwiftAgentsFinishReason() -> InferenceResponse.FinishReason {
        switch self {
        case .stop, .stopSequence:
            return .completed
        case .maxTokens:
            return .maxTokens
        case .toolCall, .toolCalls:
            return .toolCall
        case .contentFilter:
            return .contentFilter
        case .cancelled:
            return .cancelled
        case .pauseTurn, .modelContextWindowExceeded:
            // These don't have direct equivalents; treat as completed
            return .completed
        }
    }
}

extension InferenceResponse.FinishReason {
    /// Converts SwiftAgents `FinishReason` to Conduit `FinishReason`.
    ///
    /// - Returns: The equivalent Conduit finish reason.
    public func toConduitFinishReason() -> FinishReason {
        switch self {
        case .completed:
            return .stop
        case .maxTokens:
            return .maxTokens
        case .toolCall:
            return .toolCall
        case .contentFilter:
            return .contentFilter
        case .cancelled:
            return .cancelled
        }
    }
}

// MARK: - UsageStats to TokenUsage

extension UsageStats {
    /// Converts Conduit `UsageStats` to SwiftAgents `InferenceResponse.TokenUsage`.
    ///
    /// - Returns: Equivalent SwiftAgents token usage statistics.
    public func toTokenUsage() -> InferenceResponse.TokenUsage {
        InferenceResponse.TokenUsage(
            inputTokens: promptTokens,
            outputTokens: completionTokens
        )
    }
}

extension InferenceResponse.TokenUsage {
    /// Converts SwiftAgents `TokenUsage` to Conduit `UsageStats`.
    ///
    /// - Returns: Equivalent Conduit usage statistics.
    public func toConduitUsageStats() -> UsageStats {
        UsageStats(
            promptTokens: inputTokens,
            completionTokens: outputTokens
        )
    }
}

// MARK: - AIToolCall to ParsedToolCall

extension AIToolCall {
    /// Converts Conduit `AIToolCall` to SwiftAgents `InferenceResponse.ParsedToolCall`.
    ///
    /// This performs deep conversion of the tool call arguments from
    /// Conduit's `StructuredContent` to SwiftAgents' `SendableValue` dictionary.
    ///
    /// - Returns: Equivalent SwiftAgents parsed tool call.
    /// - Throws: `ConduitMappingError.argumentConversionFailed` if arguments cannot be converted.
    public func toParsedToolCall() throws -> InferenceResponse.ParsedToolCall {
        let convertedArguments = try arguments.toSendableValueDictionary()

        return InferenceResponse.ParsedToolCall(
            id: id,
            name: toolName,
            arguments: convertedArguments
        )
    }
}

// MARK: - StructuredContent to SendableValue

extension StructuredContent {
    /// Converts Conduit `StructuredContent` to SwiftAgents `SendableValue`.
    ///
    /// This performs recursive conversion of all JSON-like types:
    /// - null -> .null
    /// - bool -> .bool
    /// - number -> .int or .double (based on whether it's a whole number)
    /// - string -> .string
    /// - array -> .array
    /// - object -> .dictionary
    ///
    /// - Returns: Equivalent SwiftAgents `SendableValue`.
    public func toSendableValue() -> SendableValue {
        switch kind {
        case .null:
            return .null
        case let .bool(value):
            return .bool(value)
        case let .number(value):
            // Convert to int if it's a whole number, otherwise keep as double
            if value.isFinite && value == value.rounded() &&
                value >= Double(Int.min) && value <= Double(Int.max) {
                return .int(Int(value))
            }
            return .double(value)
        case let .string(value):
            return .string(value)
        case let .array(values):
            return .array(values.map { $0.toSendableValue() })
        case let .object(properties):
            var result: [String: SendableValue] = [:]
            for (key, value) in properties {
                result[key] = value.toSendableValue()
            }
            return .dictionary(result)
        }
    }

    /// Converts Conduit `StructuredContent` to a SwiftAgents `SendableValue` dictionary.
    ///
    /// Tool arguments are typically objects, so this convenience method extracts
    /// the dictionary directly and throws if the content is not an object.
    ///
    /// - Returns: A dictionary of `SendableValue` entries.
    /// - Throws: `ConduitMappingError.argumentConversionFailed` if content is not an object.
    public func toSendableValueDictionary() throws -> [String: SendableValue] {
        guard case let .object(properties) = kind else {
            throw ConduitMappingError.argumentConversionFailed(
                "Expected object for tool arguments, got \(kind.typeName)"
            )
        }

        var result: [String: SendableValue] = [:]
        for (key, value) in properties {
            result[key] = value.toSendableValue()
        }
        return result
    }
}

// MARK: - SendableValue to StructuredContent

extension SendableValue {
    /// Converts SwiftAgents `SendableValue` to Conduit `StructuredContent`.
    ///
    /// This performs recursive conversion back to Conduit's type system:
    /// - .null -> null
    /// - .bool -> bool
    /// - .int -> number
    /// - .double -> number
    /// - .string -> string
    /// - .array -> array
    /// - .dictionary -> object
    ///
    /// - Returns: Equivalent Conduit `StructuredContent`.
    public func toStructuredContent() -> StructuredContent {
        switch self {
        case .null:
            return .null
        case let .bool(value):
            return .bool(value)
        case let .int(value):
            return .number(Double(value))
        case let .double(value):
            return .number(value)
        case let .string(value):
            return .string(value)
        case let .array(values):
            return .array(values.map { $0.toStructuredContent() })
        case let .dictionary(dict):
            var properties: [String: StructuredContent] = [:]
            for (key, value) in dict {
                properties[key] = value.toStructuredContent()
            }
            return .object(properties)
        }
    }
}

// MARK: - ConduitMappingError

/// Errors that can occur during type mapping between SwiftAgents and Conduit.
public enum ConduitMappingError: Error, LocalizedError, Sendable {
    /// Failed to convert tool arguments.
    case argumentConversionFailed(String)

    /// Failed to create a tool call.
    case toolCallCreationFailed(String)

    /// An unexpected type was encountered.
    case unexpectedType(expected: String, actual: String)

    public var errorDescription: String? {
        switch self {
        case let .argumentConversionFailed(details):
            return "Failed to convert tool arguments: \(details)"
        case let .toolCallCreationFailed(details):
            return "Failed to create tool call: \(details)"
        case let .unexpectedType(expected, actual):
            return "Type mismatch: expected \(expected), got \(actual)"
        }
    }
}

// MARK: - StructuredContent.Kind Extension

private extension StructuredContent.Kind {
    /// Returns the type name for this kind.
    var typeName: String {
        switch self {
        case .null: "null"
        case .bool: "bool"
        case .number: "number"
        case .string: "string"
        case .array: "array"
        case .object: "object"
        }
    }
}
