// OutputGuardrail.swift
// Swarm Framework
//
// Protocol and implementations for validating agent output before returning to users.

import Foundation

/// Type alias for output validation handler closures.
public typealias OutputValidationHandler = @Sendable (String, any AgentRuntime, AgentContext?) async throws -> GuardrailResult

// MARK: - OutputGuardrail

/// Protocol for validating agent output before returning to users.
///
/// `OutputGuardrail` enables validation and filtering of agent outputs to ensure they meet
/// safety, quality, or policy requirements. Output guardrails receive the agent's output text,
/// the agent instance, and optional context for making validation decisions.
///
/// Common use cases:
/// - Content filtering (profanity, sensitive data)
/// - Quality checks (minimum length, coherence)
/// - Policy compliance (tone, formatting)
/// - PII detection and redaction
///
/// Example:
/// ```swift
/// let guardrail = ClosureOutputGuardrail(name: "content_filter") { output, agent, context in
///     if output.contains("badword") {
///         return .tripwire(
///             message: "Profanity detected",
///             outputInfo: .dictionary(["word": .string("badword")])
///         )
///     }
///     return .passed()
/// }
///
/// let result = try await guardrail.validate(
///     "Agent response text",
///     agent: myAgent,
///     context: context
/// )
///
/// if result.tripwireTriggered {
///     print("Output blocked: \(result.message ?? "")")
/// }
/// ```
public protocol OutputGuardrail: Guardrail {
    /// The name of this guardrail for identification and logging.
    var name: String { get }

    /// Validates an agent's output.
    ///
    /// - Parameters:
    ///   - output: The output text from the agent to validate.
    ///   - agent: The agent that produced this output.
    ///   - context: Optional orchestration context with shared state.
    /// - Returns: A result indicating whether the output passed validation.
    /// - Throws: An error if validation fails unexpectedly.
    func validate(_ output: String, agent: any AgentRuntime, context: AgentContext?) async throws -> GuardrailResult
}

// MARK: - ClosureOutputGuardrail

/// A closure-based implementation of `OutputGuardrail`.
///
/// `ClosureOutputGuardrail` wraps a validation closure, making it easy to create
/// custom output guardrails without defining new types.
///
/// The closure receives:
/// - `output`: The agent's output text
/// - `agent`: The agent instance that produced the output
/// - `context`: Optional shared orchestration context
///
/// The closure is marked `@Sendable` to ensure thread-safety across async boundaries.
///
/// Example:
/// ```swift
/// // PII detection guardrail
/// let piiGuardrail = ClosureOutputGuardrail(name: "pii_detector") { output, agent, context in
///     let patterns = ["\\d{3}-\\d{2}-\\d{4}", "\\d{16}"] // SSN, credit card
///     for pattern in patterns {
///         if let _ = output.range(of: pattern, options: .regularExpression) {
///             return .tripwire(
///                 message: "PII detected in output",
///                 outputInfo: .dictionary(["pattern": .string(pattern)])
///             )
///         }
///     }
///     return .passed(message: "No PII detected")
/// }
///
/// // Length validation
/// let lengthGuardrail = ClosureOutputGuardrail(name: "min_length") { output, _, _ in
///     if output.count < 10 {
///         return .tripwire(message: "Output too short")
///     }
///     return .passed()
/// }
///
/// // Context-aware validation
/// let contextGuardrail = ClosureOutputGuardrail(name: "strict_mode") { output, _, context in
///     if let mode = await context?.get("validation_mode")?.stringValue, mode == "strict" {
///         // Apply stricter validation
///         if output.contains("forbidden") {
///             return .tripwire(message: "Forbidden content in strict mode")
///         }
///     }
///     return .passed()
/// }
/// ```
public struct ClosureOutputGuardrail: OutputGuardrail, Sendable {
    // MARK: Public

    /// The name of this guardrail.
    public let name: String

    // MARK: - Initialization

    /// Creates a closure-based output guardrail.
    ///
    /// - Parameters:
    ///   - name: The name of this guardrail for identification.
    ///   - handler: The validation closure that receives output, agent, and context.
    ///
    /// Example:
    /// ```swift
    /// let guardrail = ClosureOutputGuardrail(name: "profanity_filter") { output, agent, context in
    ///     if output.contains("badword") {
    ///         return .tripwire(message: "Profanity detected")
    ///     }
    ///     return .passed()
    /// }
    /// ```
    public init(
        name: String,
        handler: @escaping @Sendable (String, any AgentRuntime, AgentContext?) async throws -> GuardrailResult
    ) {
        self.name = name
        self.handler = handler
    }

    // MARK: - OutputGuardrail

    /// Validates the agent output by calling the handler closure.
    ///
    /// - Parameters:
    ///   - output: The output text from the agent to validate.
    ///   - agent: The agent that produced this output.
    ///   - context: Optional orchestration context with shared state.
    /// - Returns: The result from the handler closure.
    /// - Throws: Any error thrown by the handler closure.
    public func validate(_ output: String, agent: any AgentRuntime, context: AgentContext?) async throws -> GuardrailResult {
        try await handler(output, agent, context)
    }

    // MARK: Private

    /// The validation handler closure.
    private let handler: @Sendable (String, any AgentRuntime, AgentContext?) async throws -> GuardrailResult
}

// MARK: - OutputGuard

/// A lightweight, closure-based `OutputGuardrail` with a concise API.
///
/// Prefer `OutputGuard` over `ClosureOutputGuardrail` for new code.
///
/// Examples:
/// ```swift
/// // Minimal signature
/// let guardrail = OutputGuard("block_bad_words") { output in
///     output.contains("BAD") ? .tripwire(message: "blocked") : .passed()
/// }
///
/// // Context-aware
/// let strict = OutputGuard("strict_mode") { output, context in
///     let enabled = await context?.get("strict")?.boolValue ?? false
///     return enabled && output.contains("forbidden") ? .tripwire(message: "blocked") : .passed()
/// }
/// ```
public struct OutputGuard: OutputGuardrail, Sendable {
    public let name: String

    public init(
        _ name: String,
        _ validate: @escaping @Sendable (String) async throws -> GuardrailResult
    ) {
        self.name = name
        handler = { output, _, _ in
            try await validate(output)
        }
    }

    public init(
        _ name: String,
        _ validate: @escaping @Sendable (String, AgentContext?) async throws -> GuardrailResult
    ) {
        self.name = name
        handler = { output, _, context in
            try await validate(output, context)
        }
    }

    public init(
        _ name: String,
        _ validate: @escaping OutputValidationHandler
    ) {
        self.name = name
        handler = validate
    }

    public func validate(_ output: String, agent: any AgentRuntime, context: AgentContext?) async throws -> GuardrailResult {
        try await handler(output, agent, context)
    }

    private let handler: OutputValidationHandler
}

// MARK: - OutputGuardrailBuilder

/// Builder for creating `ClosureOutputGuardrail` instances with a fluent interface.
///
/// `OutputGuardrailBuilder` provides a chainable API for configuring output guardrails.
/// This builder pattern allows for clear, readable guardrail construction.
///
/// Example:
/// ```swift
/// let guardrail = OutputGuardrailBuilder()
///     .name("ContentFilter")
///     .validate { output, agent, context in
///         if output.isEmpty {
///             return .tripwire(message: "Empty output not allowed")
///         }
///         return .passed()
///     }
///     .build()
/// ```
///
/// The builder supports:
/// - Multiple calls to `.name()` - the last value wins
/// - Multiple calls to `.validate()` - the last handler wins
/// - Fluent chaining for readability
public struct OutputGuardrailBuilder: Sendable {
    // MARK: Public

    // MARK: - Initialization

    /// Creates a new builder instance.
    ///
    /// Example:
    /// ```swift
    /// let builder = OutputGuardrailBuilder()
    /// ```
    public init() {
        currentName = nil
        currentHandler = nil
    }

    // MARK: - Builder Methods

    /// Sets the name for the guardrail.
    ///
    /// If called multiple times, the last value wins.
    ///
    /// - Parameter name: The name to use for the guardrail.
    /// - Returns: A new builder with the updated name.
    ///
    /// Example:
    /// ```swift
    /// let builder = OutputGuardrailBuilder()
    ///     .name("MyGuardrail")
    /// ```
    @discardableResult
    public func name(_ name: String) -> OutputGuardrailBuilder {
        OutputGuardrailBuilder(name: name, handler: currentHandler)
    }

    /// Sets the validation handler for the guardrail.
    ///
    /// If called multiple times, the last handler wins.
    ///
    /// - Parameter handler: The validation closure.
    /// - Returns: A new builder with the updated handler.
    ///
    /// Example:
    /// ```swift
    /// let builder = OutputGuardrailBuilder()
    ///     .validate { output, agent, context in
    ///         .passed()
    ///     }
    /// ```
    @discardableResult
    public func validate(
        _ handler: @escaping @Sendable (String, any AgentRuntime, AgentContext?) async throws -> GuardrailResult
    ) -> OutputGuardrailBuilder {
        OutputGuardrailBuilder(name: currentName, handler: handler)
    }

    // MARK: - Build

    /// Builds the final `ClosureOutputGuardrail` instance.
    ///
    /// - Returns: A configured `ClosureOutputGuardrail`.
    ///
    /// Example:
    /// ```swift
    /// let guardrail = OutputGuardrailBuilder()
    ///     .name("LengthCheck")
    ///     .validate { output, agent, context in
    ///         output.count > 100 ? .tripwire(message: "Too long") : .passed()
    ///     }
    ///     .build()
    /// ```
    ///
    /// - Note: If no name is provided, defaults to "UnnamedOutputGuardrail".
    ///         If no handler is provided, defaults to always passing.
    public func build() -> ClosureOutputGuardrail {
        let finalName = currentName ?? "UnnamedOutputGuardrail"
        let finalHandler = currentHandler ?? { _, _, _ in .passed() }

        return ClosureOutputGuardrail(name: finalName, handler: finalHandler)
    }

    // MARK: Private

    // MARK: - Private Properties

    /// The current name being built.
    private let currentName: String?

    /// The current validation handler being built.
    private let currentHandler: (@Sendable (String, any AgentRuntime, AgentContext?) async throws -> GuardrailResult)?

    /// Private initializer for builder chaining.
    private init(
        name: String?,
        handler: (@Sendable (String, any AgentRuntime, AgentContext?) async throws -> GuardrailResult)?
    ) {
        currentName = name
        currentHandler = handler
    }
}

// MARK: - Convenience Factories

public extension ClosureOutputGuardrail {
    /// Creates a guardrail that checks output length.
    static func maxLength(_ maxLength: Int, name: String = "MaxOutputLengthGuardrail") -> ClosureOutputGuardrail {
        ClosureOutputGuardrail(name: name) { output, _, _ in
            if output.count > maxLength {
                return .tripwire(
                    message: "Output exceeds maximum length of \(maxLength)",
                    metadata: ["length": .int(output.count), "limit": .int(maxLength)]
                )
            }
            return .passed()
        }
    }
}
