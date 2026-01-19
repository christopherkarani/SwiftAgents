// ToolGuardrails.swift
// SwiftAgents Framework
//
// Tool-level guardrails for validating tool inputs and outputs.
// Provides fine-grained validation before and after tool execution.

import Foundation

/// Type alias for tool input validation handler closures.
public typealias ToolInputValidationHandler = @Sendable (ToolGuardrailData) async throws -> GuardrailResult

/// Type alias for tool output validation handler closures.
public typealias ToolOutputValidationHandler =
    @Sendable (ToolGuardrailData, SendableValue) async throws -> GuardrailResult

// MARK: - ToolGuardrailData

/// Data container for tool guardrail validation.
///
/// `ToolGuardrailData` encapsulates all information needed to validate
/// tool inputs and outputs, including the tool itself, its arguments,
/// and optional execution context.
///
/// Example:
/// ```swift
/// let data = ToolGuardrailData(
///     tool: weatherTool,
///     arguments: ["location": .string("NYC")],
///     agent: myAgent,
///     context: executionContext
/// )
/// ```
public struct ToolGuardrailData: Sendable {
    /// The tool being validated.
    public let tool: any AnyJSONTool

    /// The arguments passed to the tool.
    public let arguments: [String: SendableValue]

    /// The agent executing the tool, if available.
    public let agent: (any Agent)?

    /// The orchestration context, if available.
    public let context: AgentContext?

    // MARK: - Initialization

    /// Creates tool guardrail data.
    ///
    /// - Parameters:
    ///   - tool: The tool being validated.
    ///   - arguments: The arguments for tool execution.
    ///   - agent: Optional agent executing the tool.
    ///   - context: Optional orchestration context.
    public init(
        tool: any AnyJSONTool,
        arguments: [String: SendableValue],
        agent: (any Agent)?,
        context: AgentContext?
    ) {
        self.tool = tool
        self.arguments = arguments
        self.agent = agent
        self.context = context
    }
}

// MARK: - ToolInputGuardrail

/// Protocol for validating tool inputs before execution.
///
/// `ToolInputGuardrail` implementations validate tool arguments before
/// the tool is executed, enabling checks for:
/// - Required parameters
/// - Parameter format and constraints
/// - Sensitive data detection
/// - Rate limiting
/// - Authorization
///
/// Example:
/// ```swift
/// struct APIKeyGuardrail: ToolInputGuardrail {
///     let name = "api_key_validator"
///
///     func validate(_ data: ToolGuardrailData) async throws -> GuardrailResult {
///         guard data.arguments["api_key"] != nil else {
///             return .tripwire(message: "Missing API key")
///         }
///         return .passed(message: "API key present")
///     }
/// }
/// ```
public protocol ToolInputGuardrail: Sendable {
    /// The unique name of this guardrail.
    var name: String { get }

    /// Validates tool input arguments before execution.
    ///
    /// - Parameter data: The tool execution data to validate.
    /// - Returns: A result indicating whether validation passed or triggered a tripwire.
    /// - Throws: Errors if validation cannot be completed.
    func validate(_ data: ToolGuardrailData) async throws -> GuardrailResult
}

// MARK: - ToolOutputGuardrail

/// Protocol for validating tool outputs after execution.
///
/// `ToolOutputGuardrail` implementations validate tool results after
/// execution, enabling checks for:
/// - Output format and structure
/// - Sensitive data in results
/// - Error detection
/// - Result size limits
/// - Content filtering
///
/// Example:
/// ```swift
/// struct OutputSizeGuardrail: ToolOutputGuardrail {
///     let name = "output_size_limiter"
///     let maxSize = 10_000
///
///     func validate(_ data: ToolGuardrailData, output: SendableValue) async throws -> GuardrailResult {
///         if let str = output.stringValue, str.count > maxSize {
///             return .tripwire(
///                 message: "Output exceeds maximum size",
///                 metadata: ["size": .int(str.count), "limit": .int(maxSize)]
///             )
///         }
///         return .passed()
///     }
/// }
/// ```
public protocol ToolOutputGuardrail: Sendable {
    /// The unique name of this guardrail.
    var name: String { get }

    /// Validates tool output after execution.
    ///
    /// - Parameters:
    ///   - data: The tool execution data.
    ///   - output: The output produced by the tool.
    /// - Returns: A result indicating whether validation passed or triggered a tripwire.
    /// - Throws: Errors if validation cannot be completed.
    func validate(_ data: ToolGuardrailData, output: SendableValue) async throws -> GuardrailResult
}

// MARK: - ClosureToolInputGuardrail

/// Closure-based implementation of ToolInputGuardrail.
///
/// Provides a lightweight way to create tool input guardrails using closures
/// without defining a new type.
///
/// Example:
/// ```swift
/// let locationValidator = ClosureToolInputGuardrail(name: "location_validator") { data in
///     guard let location = data.arguments["location"]?.stringValue,
///           !location.isEmpty else {
///         return .tripwire(message: "Invalid or missing location")
///     }
///     return .passed()
/// }
/// ```
public struct ClosureToolInputGuardrail: ToolInputGuardrail {
    // MARK: Public

    /// The unique name of this guardrail.
    public let name: String

    // MARK: - Initialization

    /// Creates a closure-based tool input guardrail.
    ///
    /// - Parameters:
    ///   - name: The unique name for this guardrail.
    ///   - handler: The validation closure.
    public init(
        name: String,
        handler: @escaping @Sendable (ToolGuardrailData) async throws -> GuardrailResult
    ) {
        self.name = name
        self.handler = handler
    }

    // MARK: - ToolInputGuardrail

    /// Validates tool input using the provided closure.
    ///
    /// - Parameter data: The tool execution data to validate.
    /// - Returns: The result from the validation handler.
    /// - Throws: Any errors thrown by the validation handler.
    public func validate(_ data: ToolGuardrailData) async throws -> GuardrailResult {
        try await handler(data)
    }

    // MARK: Private

    /// The validation handler.
    private let handler: @Sendable (ToolGuardrailData) async throws -> GuardrailResult
}

// MARK: - ClosureToolOutputGuardrail

/// Closure-based implementation of ToolOutputGuardrail.
///
/// Provides a lightweight way to create tool output guardrails using closures
/// without defining a new type.
///
/// Example:
/// ```swift
/// let piiDetector = ClosureToolOutputGuardrail(name: "pii_detector") { data, output in
///     if let text = output.stringValue, text.contains("@") {
///         return .passed(
///             message: "PII detected",
///             outputInfo: .dictionary(["piiDetected": .bool(true)])
///         )
///     }
///     return .passed(outputInfo: .dictionary(["piiDetected": .bool(false)]))
/// }
/// ```
public struct ClosureToolOutputGuardrail: ToolOutputGuardrail {
    // MARK: Public

    /// The unique name of this guardrail.
    public let name: String

    // MARK: - Initialization

    /// Creates a closure-based tool output guardrail.
    ///
    /// - Parameters:
    ///   - name: The unique name for this guardrail.
    ///   - handler: The validation closure that receives tool data and output.
    public init(
        name: String,
        handler: @escaping @Sendable (ToolGuardrailData, SendableValue) async throws -> GuardrailResult
    ) {
        self.name = name
        self.handler = handler
    }

    // MARK: - ToolOutputGuardrail

    /// Validates tool output using the provided closure.
    ///
    /// - Parameters:
    ///   - data: The tool execution data.
    ///   - output: The output produced by the tool.
    /// - Returns: The result from the validation handler.
    /// - Throws: Any errors thrown by the validation handler.
    public func validate(_ data: ToolGuardrailData, output: SendableValue) async throws -> GuardrailResult {
        try await handler(data, output)
    }

    // MARK: Private

    /// The validation handler.
    private let handler: @Sendable (ToolGuardrailData, SendableValue) async throws -> GuardrailResult
}

// MARK: - ToolInputGuardrailBuilder

/// Builder for creating `ClosureToolInputGuardrail` instances with a fluent interface.
///
/// `ToolInputGuardrailBuilder` provides a chainable API for configuring tool input guardrails.
/// This builder pattern allows for clear, readable guardrail construction.
///
/// Example:
/// ```swift
/// let guardrail = ToolInputGuardrailBuilder()
///     .name("ParameterValidator")
///     .validate { data in
///         guard data.arguments["required_param"] != nil else {
///             return .tripwire(message: "Missing required parameter")
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
public struct ToolInputGuardrailBuilder: Sendable {
    // MARK: Public

    // MARK: - Initialization

    /// Creates a new builder instance.
    ///
    /// Example:
    /// ```swift
    /// let builder = ToolInputGuardrailBuilder()
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
    /// let builder = ToolInputGuardrailBuilder()
    ///     .name("MyGuardrail")
    /// ```
    @discardableResult
    public func name(_ name: String) -> ToolInputGuardrailBuilder {
        ToolInputGuardrailBuilder(name: name, handler: currentHandler)
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
    /// let builder = ToolInputGuardrailBuilder()
    ///     .validate { data in
    ///         .passed()
    ///     }
    /// ```
    @discardableResult
    public func validate(
        _ handler: @escaping @Sendable (ToolGuardrailData) async throws -> GuardrailResult
    ) -> ToolInputGuardrailBuilder {
        ToolInputGuardrailBuilder(name: currentName, handler: handler)
    }

    // MARK: - Build

    /// Builds the final `ClosureToolInputGuardrail` instance.
    ///
    /// - Returns: A configured `ClosureToolInputGuardrail`.
    ///
    /// Example:
    /// ```swift
    /// let guardrail = ToolInputGuardrailBuilder()
    ///     .name("RequiredParams")
    ///     .validate { data in
    ///         data.arguments.isEmpty ? .tripwire(message: "No params") : .passed()
    ///     }
    ///     .build()
    /// ```
    ///
    /// - Note: If no name is provided, defaults to "UnnamedToolInputGuardrail".
    ///         If no handler is provided, defaults to always passing.
    public func build() -> ClosureToolInputGuardrail {
        let finalName = currentName ?? "UnnamedToolInputGuardrail"
        let finalHandler = currentHandler ?? { _ in .passed() }

        return ClosureToolInputGuardrail(name: finalName, handler: finalHandler)
    }

    // MARK: Private

    // MARK: - Private Properties

    /// The current name being built.
    private let currentName: String?

    /// The current validation handler being built.
    private let currentHandler: (@Sendable (ToolGuardrailData) async throws -> GuardrailResult)?

    /// Private initializer for builder chaining.
    private init(
        name: String?,
        handler: (@Sendable (ToolGuardrailData) async throws -> GuardrailResult)?
    ) {
        currentName = name
        currentHandler = handler
    }
}

// MARK: - ToolOutputGuardrailBuilder

/// Builder for creating `ClosureToolOutputGuardrail` instances with a fluent interface.
///
/// `ToolOutputGuardrailBuilder` provides a chainable API for configuring tool output guardrails.
/// This builder pattern allows for clear, readable guardrail construction.
///
/// Example:
/// ```swift
/// let guardrail = ToolOutputGuardrailBuilder()
///     .name("OutputValidator")
///     .validate { data, output in
///         if let text = output.stringValue, text.isEmpty {
///             return .tripwire(message: "Empty output")
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
public struct ToolOutputGuardrailBuilder: Sendable {
    // MARK: Public

    // MARK: - Initialization

    /// Creates a new builder instance.
    ///
    /// Example:
    /// ```swift
    /// let builder = ToolOutputGuardrailBuilder()
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
    /// let builder = ToolOutputGuardrailBuilder()
    ///     .name("MyGuardrail")
    /// ```
    @discardableResult
    public func name(_ name: String) -> ToolOutputGuardrailBuilder {
        ToolOutputGuardrailBuilder(name: name, handler: currentHandler)
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
    /// let builder = ToolOutputGuardrailBuilder()
    ///     .validate { data, output in
    ///         .passed()
    ///     }
    /// ```
    @discardableResult
    public func validate(
        _ handler: @escaping @Sendable (ToolGuardrailData, SendableValue) async throws -> GuardrailResult
    ) -> ToolOutputGuardrailBuilder {
        ToolOutputGuardrailBuilder(name: currentName, handler: handler)
    }

    // MARK: - Build

    /// Builds the final `ClosureToolOutputGuardrail` instance.
    ///
    /// - Returns: A configured `ClosureToolOutputGuardrail`.
    ///
    /// Example:
    /// ```swift
    /// let guardrail = ToolOutputGuardrailBuilder()
    ///     .name("SizeLimit")
    ///     .validate { data, output in
    ///         if let str = output.stringValue, str.count > 1000 {
    ///             return .tripwire(message: "Output too large")
    ///         }
    ///         return .passed()
    ///     }
    ///     .build()
    /// ```
    ///
    /// - Note: If no name is provided, defaults to "UnnamedToolOutputGuardrail".
    ///         If no handler is provided, defaults to always passing.
    public func build() -> ClosureToolOutputGuardrail {
        let finalName = currentName ?? "UnnamedToolOutputGuardrail"
        let finalHandler = currentHandler ?? { _, _ in .passed() }

        return ClosureToolOutputGuardrail(name: finalName, handler: finalHandler)
    }

    // MARK: Private

    // MARK: - Private Properties

    /// The current name being built.
    private let currentName: String?

    /// The current validation handler being built.
    private let currentHandler: (@Sendable (ToolGuardrailData, SendableValue) async throws -> GuardrailResult)?

    /// Private initializer for builder chaining.
    private init(
        name: String?,
        handler: (@Sendable (ToolGuardrailData, SendableValue) async throws -> GuardrailResult)?
    ) {
        currentName = name
        currentHandler = handler
    }
}
