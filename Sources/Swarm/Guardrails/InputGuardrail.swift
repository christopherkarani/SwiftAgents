// InputGuardrail.swift
// Swarm Framework
//
// Input validation guardrails for agent systems.
// Provides validation and safety checks for agent inputs before processing.

import Foundation

/// Type alias for input validation handler closures.
public typealias InputValidationHandler = @Sendable (String, AgentContext?) async throws -> GuardrailResult

// MARK: - InputGuardrail

/// Protocol for input validation guardrails.
///
/// `InputGuardrail` defines the contract for validating agent inputs before they are processed.
/// Guardrails can check for sensitive data, malicious content, policy violations, or any
/// custom validation logic.
///
/// Guardrails are composable and can be chained together to create complex validation pipelines.
/// They return a `GuardrailResult` indicating whether the input passed validation or triggered
/// a tripwire.
///
/// Example:
/// ```swift
/// struct SensitiveDataGuardrail: InputGuardrail {
///     let name = "SensitiveDataGuardrail"
///
///     func validate(_ input: String, context: AgentContext?) async throws -> GuardrailResult {
///         if input.contains("SSN:") || input.contains("password:") {
///             return .tripwire(message: "Sensitive data detected")
///         }
///         return .passed()
///     }
/// }
/// ```
public protocol InputGuardrail: Guardrail {
    /// The name of this guardrail for identification and logging.
    var name: String { get }

    /// Validates the input and returns a result.
    ///
    /// - Parameters:
    ///   - input: The input string to validate.
    ///   - context: Optional agent context for validation decisions.
    /// - Returns: A result indicating whether validation passed or triggered a tripwire.
    /// - Throws: Validation errors if the check cannot be completed.
    func validate(_ input: String, context: AgentContext?) async throws -> GuardrailResult
}

// MARK: - ClosureInputGuardrail

/// A closure-based implementation of `InputGuardrail`.
///
/// `ClosureInputGuardrail` wraps a validation closure, allowing for quick guardrail creation
/// without defining a new type. The closure receives the input and optional context, and
/// returns a `GuardrailResult`.
///
/// This is particularly useful for:
/// - Prototyping guardrails quickly
/// - Simple validation logic
/// - Dynamic guardrail creation
/// - Testing scenarios
///
/// Example:
/// ```swift
/// let lengthGuardrail = ClosureInputGuardrail(name: "MaxLength") { input, context in
///     if input.count > 1000 {
///         return .tripwire(message: "Input exceeds maximum length")
///     }
///     return .passed()
/// }
///
/// let result = try await lengthGuardrail.validate("user input", context: nil)
/// ```
public struct ClosureInputGuardrail: InputGuardrail, Sendable {
    // MARK: Public

    /// The name of this guardrail for identification and logging.
    public let name: String

    // MARK: - Initialization

    /// Creates a closure-based input guardrail.
    ///
    /// - Parameters:
    ///   - name: The name of this guardrail.
    ///   - handler: The validation closure that receives input and context, returning a result.
    ///
    /// Example:
    /// ```swift
    /// let guardrail = ClosureInputGuardrail(name: "ProfanityFilter") { input, context in
    ///     let profanityWords = ["badword1", "badword2"]
    ///     for word in profanityWords {
    ///         if input.lowercased().contains(word) {
    ///             return .tripwire(
    ///                 message: "Profanity detected",
    ///                 outputInfo: .dictionary(["word": .string(word)])
    ///             )
    ///         }
    ///     }
    ///     return .passed(message: "Content is clean")
    /// }
    /// ```
    public init(
        name: String,
        handler: @escaping @Sendable (String, AgentContext?) async throws -> GuardrailResult
    ) {
        self.name = name
        self.handler = handler
    }

    // MARK: - InputGuardrail Conformance

    /// Validates the input using the handler closure.
    ///
    /// - Parameters:
    ///   - input: The input string to validate.
    ///   - context: Optional agent context for validation decisions.
    /// - Returns: The result from the handler closure.
    /// - Throws: Any error thrown by the handler closure.
    public func validate(_ input: String, context: AgentContext?) async throws -> GuardrailResult {
        try await handler(input, context)
    }

    // MARK: Private

    /// The validation handler closure.
    private let handler: @Sendable (String, AgentContext?) async throws -> GuardrailResult
}

// MARK: - InputGuard

/// A lightweight, closure-based `InputGuardrail` with a concise API.
///
/// Prefer `InputGuard` over `ClosureInputGuardrail` for new code.
public struct InputGuard: InputGuardrail, Sendable {
    public let name: String

    public init(
        _ name: String,
        _ validate: @escaping @Sendable (String) async throws -> GuardrailResult
    ) {
        self.name = name
        handler = { input, _ in
            try await validate(input)
        }
    }

    public init(
        _ name: String,
        _ validate: @escaping @Sendable (String, AgentContext?) async throws -> GuardrailResult
    ) {
        self.name = name
        handler = validate
    }

    public func validate(_ input: String, context: AgentContext?) async throws -> GuardrailResult {
        try await handler(input, context)
    }

    private let handler: InputValidationHandler
}

// MARK: - InputGuardrailBuilder

/// Builder for creating `ClosureInputGuardrail` instances with a fluent interface.
///
/// `InputGuardrailBuilder` provides a chainable API for configuring input guardrails.
/// This builder pattern allows for clear, readable guardrail construction.
///
/// Example:
/// ```swift
/// let guardrail = InputGuardrailBuilder()
///     .name("ContentFilter")
///     .validate { input, context in
///         if input.isEmpty {
///             return .tripwire(message: "Empty input not allowed")
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
public struct InputGuardrailBuilder: Sendable {
    // MARK: Public

    // MARK: - Initialization

    /// Creates a new builder instance.
    ///
    /// Example:
    /// ```swift
    /// let builder = InputGuardrailBuilder()
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
    /// let builder = InputGuardrailBuilder()
    ///     .name("MyGuardrail")
    /// ```
    @discardableResult
    public func name(_ name: String) -> InputGuardrailBuilder {
        InputGuardrailBuilder(name: name, handler: currentHandler)
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
    /// let builder = InputGuardrailBuilder()
    ///     .validate { input, context in
    ///         .passed()
    ///     }
    /// ```
    @discardableResult
    public func validate(
        _ handler: @escaping @Sendable (String, AgentContext?) async throws -> GuardrailResult
    ) -> InputGuardrailBuilder {
        InputGuardrailBuilder(name: currentName, handler: handler)
    }

    // MARK: - Build

    /// Builds the final `ClosureInputGuardrail` instance.
    ///
    /// - Returns: A configured `ClosureInputGuardrail`.
    ///
    /// Example:
    /// ```swift
    /// let guardrail = InputGuardrailBuilder()
    ///     .name("LengthCheck")
    ///     .validate { input, context in
    ///         input.count > 100 ? .tripwire(message: "Too long") : .passed()
    ///     }
    ///     .build()
    /// ```
    ///
    /// - Note: If no name is provided, defaults to "UnnamedGuardrail".
    ///         If no handler is provided, defaults to always passing.
    public func build() -> ClosureInputGuardrail {
        let finalName = currentName ?? "UnnamedGuardrail"
        let finalHandler = currentHandler ?? { _, _ in .passed() }

        return ClosureInputGuardrail(name: finalName, handler: finalHandler)
    }

    // MARK: Private

    // MARK: - Private Properties

    /// The current name being built.
    private let currentName: String?

    /// The current validation handler being built.
    private let currentHandler: (@Sendable (String, AgentContext?) async throws -> GuardrailResult)?

    /// Private initializer for builder chaining.
    private init(
        name: String?,
        handler: (@Sendable (String, AgentContext?) async throws -> GuardrailResult)?
    ) {
        currentName = name
        currentHandler = handler
    }
}

// MARK: - Convenience Factories

public extension ClosureInputGuardrail {
    /// Creates a guardrail that checks input length.
    static func maxLength(_ maxLength: Int, name: String = "MaxLengthGuardrail") -> ClosureInputGuardrail {
        ClosureInputGuardrail(name: name) { input, _ in
            if input.count > maxLength {
                return .tripwire(
                    message: "Input exceeds maximum length of \(maxLength)",
                    metadata: ["length": .int(input.count), "limit": .int(maxLength)]
                )
            }
            return .passed()
        }
    }

    /// Creates a guardrail that rejects empty inputs.
    static func notEmpty(name: String = "NotEmptyGuardrail") -> ClosureInputGuardrail {
        ClosureInputGuardrail(name: name) { input, _ in
            if input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .tripwire(message: "Input cannot be empty")
            }
            return .passed()
        }
    }
}
