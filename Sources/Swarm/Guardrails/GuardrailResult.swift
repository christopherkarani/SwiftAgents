// GuardrailResult.swift
// Swarm Framework
//
// Result type for guardrail validation checks.
// Indicates whether a tripwire was triggered and provides diagnostic information.

import Foundation

// MARK: - GuardrailResult

/// Result of a guardrail validation check.
///
/// `GuardrailResult` encapsulates the outcome of a guardrail check, indicating whether
/// a tripwire was triggered and providing optional diagnostic information.
///
/// Use the static factory methods to create results:
/// - `passed()` for successful validations
/// - `tripwire()` for failed validations that triggered a guardrail
///
/// Example:
/// ```swift
/// // Successful validation
/// let success = GuardrailResult.passed(
///     message: "Input validation successful",
///     metadata: ["tokensChecked": .int(42)]
/// )
///
/// // Failed validation with tripwire
/// let failure = GuardrailResult.tripwire(
///     message: "Sensitive data detected",
///     outputInfo: .dictionary(["violationType": .string("PII_DETECTED")]),
///     metadata: ["severity": .string("high")]
/// )
/// ```
public struct GuardrailResult: Sendable, Equatable {
    /// Indicates whether a tripwire was triggered during the check.
    /// `true` if the guardrail blocked the input/output, `false` if it passed.
    public let tripwireTriggered: Bool

    /// Optional diagnostic information about what was detected or validated.
    ///
    /// Use this to provide structured data about the validation result:
    /// - For tripwires: Details about what triggered the violation (e.g., detected patterns, PII types)
    /// - For passes: Optional summary of what was checked
    ///
    /// Example:
    /// ```swift
    /// outputInfo: .dictionary([
    ///     "violationType": .string("PII_DETECTED"),
    ///     "patterns": .array([.string("SSN"), .string("email")])
    /// ])
    /// ```
    public let outputInfo: SendableValue?

    /// Optional human-readable message describing the result.
    public let message: String?

    /// Additional metadata about the guardrail execution.
    ///
    /// Use this for operational/diagnostic data about the guardrail execution itself:
    /// - Execution time
    /// - Model version used
    /// - Confidence scores
    /// - Cache hits
    ///
    /// Example:
    /// ```swift
    /// metadata: [
    ///     "executionTimeMs": .double(42.5),
    ///     "modelVersion": .string("v2.1"),
    ///     "cacheHit": .bool(true)
    /// ]
    /// ```
    public let metadata: [String: SendableValue]

    // MARK: - Initializer

    /// Creates a guardrail result with all properties.
    ///
    /// - Parameters:
    ///   - tripwireTriggered: Whether a tripwire was triggered.
    ///   - outputInfo: Optional diagnostic information.
    ///   - message: Optional descriptive message.
    ///   - metadata: Additional metadata about the check.
    public init(
        tripwireTriggered: Bool,
        outputInfo: SendableValue? = nil,
        message: String? = nil,
        metadata: [String: SendableValue] = [:]
    ) {
        self.tripwireTriggered = tripwireTriggered
        self.outputInfo = outputInfo
        self.message = message
        self.metadata = metadata
    }

    // MARK: - Factory Methods

    /// Creates a result indicating the check passed successfully.
    ///
    /// - Parameters:
    ///   - message: Optional message describing what passed.
    ///   - outputInfo: Optional diagnostic information about the check.
    ///   - metadata: Additional metadata about the check execution.
    /// - Returns: A result with `tripwireTriggered = false`.
    public static func passed(
        message: String? = nil,
        outputInfo: SendableValue? = nil,
        metadata: [String: SendableValue] = [:]
    ) -> GuardrailResult {
        GuardrailResult(
            tripwireTriggered: false,
            outputInfo: outputInfo,
            message: message,
            metadata: metadata
        )
    }

    /// Creates a result indicating a tripwire was triggered.
    ///
    /// - Parameters:
    ///   - message: Description of why the tripwire was triggered.
    ///   - outputInfo: Optional diagnostic information about the violation.
    ///   - metadata: Additional metadata about the check execution.
    /// - Returns: A result with `tripwireTriggered = true`.
    public static func tripwire(
        message: String,
        outputInfo: SendableValue? = nil,
        metadata: [String: SendableValue] = [:]
    ) -> GuardrailResult {
        GuardrailResult(
            tripwireTriggered: true,
            outputInfo: outputInfo,
            message: message,
            metadata: metadata
        )
    }
}

// MARK: CustomDebugStringConvertible

extension GuardrailResult: CustomDebugStringConvertible {
    public var debugDescription: String {
        var components: [String] = []

        components.append("GuardrailResult(")
        components.append("tripwireTriggered: \(tripwireTriggered)")

        if let message {
            components.append("message: \"\(message)\"")
        }

        if let outputInfo {
            components.append("outputInfo: \(outputInfo.debugDescription)")
        }

        if !metadata.isEmpty {
            components.append("metadata: \(metadata)")
        }

        return components.joined(separator: ", ") + ")"
    }
}
