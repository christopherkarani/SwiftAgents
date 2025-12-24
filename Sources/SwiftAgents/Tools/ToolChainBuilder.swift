// ToolChainBuilder.swift
// SwiftAgents Framework
//
// Declarative DSL for composing tool chains with retry, timeout, and transformation.

import Foundation

// MARK: - Result Builder

/// A result builder for composing tool execution chains.
///
/// `ToolChainBuilder` enables declarative syntax for building tool pipelines
/// with transformations, filters, and conditionals. Similar to SwiftUI's view builders,
/// it supports conditionals, loops, and optional steps.
///
/// Example:
/// ```swift
/// let pipeline = ToolChain {
///     SearchTool()
///         .retry(count: 3, delay: .seconds(1))
///
///     ToolTransform { results in
///         // Filter and transform search results
///         guard let items = results.arrayValue else {
///             return .array([])
///         }
///         return .array(items.prefix(5).map { $0 })
///     }
///
///     SummarizeTool()
///         .timeout(.seconds(30))
///         .fallback(to: DefaultSummarizeTool())
/// }
///
/// let result = try await pipeline.execute(.string("Swift concurrency"))
/// ```
@resultBuilder
public struct ToolChainBuilder {
    /// Builds a chain from multiple steps.
    public static func buildBlock(_ steps: ToolChainStep...) -> [ToolChainStep] {
        steps
    }

    /// Builds an empty chain.
    public static func buildBlock() -> [ToolChainStep] {
        []
    }

    /// Builds a chain from arrays of steps.
    public static func buildBlock(_ steps: [ToolChainStep]...) -> [ToolChainStep] {
        steps.flatMap(\.self)
    }

    /// Builds a chain from an optional step.
    public static func buildOptional(_ component: [ToolChainStep]?) -> [ToolChainStep] {
        component ?? []
    }

    /// Builds a chain from the first branch of an if-else.
    public static func buildEither(first component: [ToolChainStep]) -> [ToolChainStep] {
        component
    }

    /// Builds a chain from the second branch of an if-else.
    public static func buildEither(second component: [ToolChainStep]) -> [ToolChainStep] {
        component
    }

    /// Builds a chain from a for-in loop.
    public static func buildArray(_ components: [[ToolChainStep]]) -> [ToolChainStep] {
        components.flatMap(\.self)
    }

    /// Converts a single tool to a chain step.
    public static func buildExpression(_ tool: any Tool) -> ToolChainStep {
        ToolStep(tool)
    }

    /// Converts a step to a chain step array.
    public static func buildExpression(_ step: ToolChainStep) -> ToolChainStep {
        step
    }

    /// Builds from a limited availability check.
    public static func buildLimitedAvailability(_ component: [ToolChainStep]) -> [ToolChainStep] {
        component
    }

    /// Builds the final result.
    public static func buildFinalResult(_ component: [ToolChainStep]) -> [ToolChainStep] {
        component
    }
}

// MARK: - Chain Step Protocol

/// A step in a tool execution chain.
///
/// `ToolChainStep` represents a single operation in a tool chain pipeline.
/// Steps can be tools, transformations, filters, or conditionals.
///
/// All tools automatically conform to this protocol via an extension.
///
/// Example:
/// ```swift
/// let step: ToolChainStep = SearchTool()
/// let result = try await step.execute(input: .string("query"))
/// ```
public protocol ToolChainStep: Sendable {
    /// Executes this step with the given input.
    ///
    /// - Parameter input: The input value from the previous step or initial input.
    /// - Returns: The output value to pass to the next step.
    /// - Throws: Any error that occurs during execution.
    func execute(input: SendableValue) async throws -> SendableValue
}

// MARK: - Tool Extension

extension Tool {
    /// Executes this tool as a chain step.
    ///
    /// Automatically converts the input to tool arguments:
    /// - If input is a dictionary, uses it directly as arguments
    /// - Otherwise, wraps it as `["input": input]`
    ///
    /// - Parameter input: The input value from the previous step.
    /// - Returns: The tool's execution result.
    /// - Throws: Tool execution errors.
    public func execute(input: SendableValue) async throws -> SendableValue {
        let arguments: [String: SendableValue]
        if let dict = input.dictionaryValue {
            arguments = dict
        } else {
            arguments = ["input": input]
        }
        return try await execute(arguments: arguments)
    }
}

// MARK: - Tool Step

/// A tool wrapper with retry, timeout, and fallback capabilities.
///
/// `ToolStep` wraps any tool and adds resilience features through a fluent API.
///
/// Example:
/// ```swift
/// let step = ToolStep(SearchTool())
///     .retry(count: 3, delay: .seconds(1))
///     .timeout(.seconds(30))
///     .fallback(to: CachedSearchTool())
/// ```
public struct ToolStep: ToolChainStep, Sendable {
    // MARK: - Properties

    private let tool: any Tool
    private let retryCount: Int
    private let retryDelay: Duration
    private let timeoutDuration: Duration?
    private let fallbackTool: (any Tool)?

    // MARK: - Initialization

    /// Creates a tool step from a tool.
    ///
    /// - Parameter tool: The tool to wrap.
    public init(_ tool: any Tool) {
        self.tool = tool
        retryCount = 0
        retryDelay = .seconds(1)
        timeoutDuration = nil
        fallbackTool = nil
    }

    private init(
        tool: any Tool,
        retryCount: Int,
        retryDelay: Duration,
        timeoutDuration: Duration?,
        fallbackTool: (any Tool)?
    ) {
        self.tool = tool
        self.retryCount = retryCount
        self.retryDelay = retryDelay
        self.timeoutDuration = timeoutDuration
        self.fallbackTool = fallbackTool
    }

    // MARK: - Configuration

    /// Configures automatic retry on failure.
    ///
    /// The tool will be retried up to `count` times with the specified delay between attempts.
    ///
    /// - Parameters:
    ///   - count: The number of retry attempts (0 = no retries).
    ///   - delay: The duration to wait between retry attempts.
    /// - Returns: A configured tool step.
    public func retry(count: Int, delay: Duration = .seconds(1)) -> ToolStep {
        ToolStep(
            tool: tool,
            retryCount: max(0, count),
            retryDelay: delay,
            timeoutDuration: timeoutDuration,
            fallbackTool: fallbackTool
        )
    }

    /// Configures execution timeout.
    ///
    /// If the tool doesn't complete within the specified duration, a timeout error is thrown.
    ///
    /// - Parameter duration: The maximum execution duration.
    /// - Returns: A configured tool step.
    public func timeout(_ duration: Duration) -> ToolStep {
        ToolStep(
            tool: tool,
            retryCount: retryCount,
            retryDelay: retryDelay,
            timeoutDuration: duration,
            fallbackTool: fallbackTool
        )
    }

    /// Configures a fallback tool to use if this tool fails.
    ///
    /// If all retry attempts fail, the fallback tool is executed with the same input.
    ///
    /// - Parameter tool: The fallback tool to use on failure.
    /// - Returns: A configured tool step.
    public func fallback(to tool: any Tool) -> ToolStep {
        ToolStep(
            tool: self.tool,
            retryCount: retryCount,
            retryDelay: retryDelay,
            timeoutDuration: timeoutDuration,
            fallbackTool: tool
        )
    }

    // MARK: - Execution

    /// Executes the tool with retry, timeout, and fallback as configured.
    ///
    /// - Parameter input: The input value from the previous step.
    /// - Returns: The tool's execution result.
    /// - Throws: `ToolChainError` or tool-specific errors.
    public func execute(input: SendableValue) async throws -> SendableValue {
        if let timeout = timeoutDuration {
            return try await executeWithTimeout(input: input, timeout: timeout)
        } else {
            return try await executeWithRetry(input: input)
        }
    }

    // MARK: - Private Methods

    private func executeWithTimeout(input: SendableValue, timeout: Duration) async throws -> SendableValue {
        try await withThrowingTaskGroup(of: SendableValue.self) { group in
            // Add actual execution task
            group.addTask {
                try await self.executeWithRetry(input: input)
            }

            // Add timeout task
            group.addTask {
                try await Task.sleep(for: timeout)
                throw ToolChainError.timeout(toolName: self.tool.name, duration: timeout)
            }

            // First to complete wins
            guard let result = try await group.next() else {
                throw ToolChainError.executionFailed(
                    toolName: tool.name,
                    reason: "No result from task group"
                )
            }

            // Cancel remaining task
            group.cancelAll()
            return result
        }
    }

    private func executeWithRetry(input: SendableValue) async throws -> SendableValue {
        var lastError: Error?

        for attempt in 0 ... retryCount {
            // Check for cancellation before each attempt
            try Task.checkCancellation()

            do {
                return try await tool.execute(input: input)
            } catch {
                lastError = error

                // If this is the last attempt, stop retrying
                if attempt == retryCount {
                    break
                }

                // Wait before next retry
                try await Task.sleep(for: retryDelay)
            }
        }

        // All retries failed, try fallback if available
        if let fallback = fallbackTool {
            do {
                return try await fallback.execute(input: input)
            } catch {
                // Fallback also failed, throw original error
                throw lastError ?? error
            }
        }

        // No fallback, throw the last error
        throw lastError ?? ToolChainError.executionFailed(
            toolName: tool.name,
            reason: "Unknown error"
        )
    }
}

// MARK: - Transform Step

/// A transformation step that modifies values in the chain.
///
/// Example:
/// ```swift
/// ToolTransform { results in
///     guard let items = results.arrayValue else {
///         return .array([])
///     }
///     return .array(items.prefix(10).map { $0 })
/// }
/// ```
public struct ToolTransform: ToolChainStep, Sendable {
    // MARK: - Properties

    private let transform: @Sendable (SendableValue) async throws -> SendableValue

    // MARK: - Initialization

    /// Creates a transformation step.
    ///
    /// - Parameter transform: The transformation function to apply.
    public init(_ transform: @escaping @Sendable (SendableValue) async throws -> SendableValue) {
        self.transform = transform
    }

    // MARK: - Execution

    /// Executes the transformation.
    ///
    /// - Parameter input: The input value from the previous step.
    /// - Returns: The transformed value.
    /// - Throws: Any error thrown by the transform function.
    public func execute(input: SendableValue) async throws -> SendableValue {
        try await transform(input)
    }
}

// MARK: - Filter Step

/// A filter step that conditionally passes or replaces values.
///
/// If the predicate returns false, the default value is returned instead.
///
/// Example:
/// ```swift
/// ToolFilter({ result in
///     result.arrayValue?.isEmpty == false
/// }, defaultValue: .array([]))
/// ```
public struct ToolFilter: ToolChainStep, Sendable {
    // MARK: - Properties

    private let predicate: @Sendable (SendableValue) async throws -> Bool
    private let defaultValue: SendableValue

    // MARK: - Initialization

    /// Creates a filter step.
    ///
    /// - Parameters:
    ///   - predicate: The filter condition.
    ///   - defaultValue: The value to return if the predicate fails.
    public init(
        _ predicate: @escaping @Sendable (SendableValue) async throws -> Bool,
        defaultValue: SendableValue = .null
    ) {
        self.predicate = predicate
        self.defaultValue = defaultValue
    }

    // MARK: - Execution

    /// Executes the filter.
    ///
    /// - Parameter input: The input value from the previous step.
    /// - Returns: The input if predicate passes, otherwise the default value.
    /// - Throws: Any error thrown by the predicate.
    public func execute(input: SendableValue) async throws -> SendableValue {
        let passes = try await predicate(input)
        return passes ? input : defaultValue
    }
}

// MARK: - Conditional Step

/// A conditional step that executes different branches based on a condition.
///
/// Example:
/// ```swift
/// ToolConditional(
///     if: { input in
///         input.stringValue?.contains("urgent") == true
///     },
///     then: PriorityTool(),
///     else: StandardTool()
/// )
/// ```
public struct ToolConditional: ToolChainStep, Sendable {
    // MARK: - Properties

    private let condition: @Sendable (SendableValue) async throws -> Bool
    private let thenStep: ToolChainStep
    private let elseStep: ToolChainStep?

    // MARK: - Initialization

    /// Creates a conditional step.
    ///
    /// - Parameters:
    ///   - condition: The condition to evaluate.
    ///   - then: The step to execute if condition is true.
    ///   - else: The optional step to execute if condition is false.
    public init(
        if condition: @escaping @Sendable (SendableValue) async throws -> Bool,
        then thenStep: ToolChainStep,
        else elseStep: ToolChainStep? = nil
    ) {
        self.condition = condition
        self.thenStep = thenStep
        self.elseStep = elseStep
    }

    // MARK: - Execution

    /// Executes the appropriate branch based on the condition.
    ///
    /// - Parameter input: The input value from the previous step.
    /// - Returns: The result from the executed branch.
    /// - Throws: Any error thrown by the condition or executed step.
    public func execute(input: SendableValue) async throws -> SendableValue {
        let shouldExecuteThen = try await condition(input)

        if shouldExecuteThen {
            return try await thenStep.execute(input: input)
        } else if let elseStep {
            return try await elseStep.execute(input: input)
        } else {
            // No else branch, pass through input
            return input
        }
    }
}

// MARK: - Tool Chain Container

/// A container for a chain of tool execution steps.
///
/// `ToolChain` executes steps sequentially, passing the output of each step
/// as input to the next. It provides multiple convenience methods for execution.
///
/// Example:
/// ```swift
/// let pipeline = ToolChain {
///     SearchTool().retry(count: 3)
///     ToolTransform { $0 }  // Transform results
///     SummarizeTool().timeout(.seconds(30))
/// }
///
/// let result = try await pipeline.execute(.string("Swift patterns"))
/// ```
public struct ToolChain: Sendable {
    // MARK: - Properties

    private let steps: [ToolChainStep]

    // MARK: - Initialization

    /// Creates a tool chain using the result builder DSL.
    ///
    /// - Parameter content: The builder closure containing chain steps.
    public init(@ToolChainBuilder _ content: () -> [ToolChainStep]) {
        steps = content()
    }

    // MARK: - Execution

    /// Executes the chain with dictionary arguments.
    ///
    /// - Parameter arguments: The arguments to pass to the first step.
    /// - Returns: The final result after all steps execute.
    /// - Throws: `ToolChainError.emptyChain` if the chain has no steps, or any execution error.
    public func execute(with arguments: [String: SendableValue]) async throws -> SendableValue {
        try await execute(.dictionary(arguments))
    }

    /// Executes the chain with a string query.
    ///
    /// Convenience method that wraps the query as `["query": query]`.
    ///
    /// - Parameter query: The query string.
    /// - Returns: The final result after all steps execute.
    /// - Throws: `ToolChainError.emptyChain` if the chain has no steps, or any execution error.
    public func execute(query: String) async throws -> SendableValue {
        try await execute(.dictionary(["query": .string(query)]))
    }

    /// Executes the chain with a SendableValue input.
    ///
    /// - Parameter input: The input value for the first step.
    /// - Returns: The final result after all steps execute.
    /// - Throws: `ToolChainError.emptyChain` if the chain has no steps, or any execution error.
    public func execute(_ input: SendableValue) async throws -> SendableValue {
        guard !steps.isEmpty else {
            throw ToolChainError.emptyChain
        }

        var currentValue = input

        for step in steps {
            try Task.checkCancellation()
            currentValue = try await step.execute(input: currentValue)
        }

        return currentValue
    }
}

// MARK: - Errors

/// Errors that can occur during tool chain execution.
public enum ToolChainError: Error, Sendable, LocalizedError, CustomStringConvertible {
    /// A tool execution timed out.
    case timeout(toolName: String, duration: Duration)

    /// A tool execution failed.
    case executionFailed(toolName: String, reason: String)

    /// The tool chain is empty (has no steps).
    case emptyChain

    // MARK: - CustomStringConvertible

    public var description: String {
        switch self {
        case let .timeout(toolName, duration):
            "Tool '\(toolName)' timed out after \(duration)"
        case let .executionFailed(toolName, reason):
            "Tool '\(toolName)' failed: \(reason)"
        case .emptyChain:
            "Cannot execute empty tool chain"
        }
    }

    // MARK: - LocalizedError

    public var errorDescription: String? {
        description
    }
}
