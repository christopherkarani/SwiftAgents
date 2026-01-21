// Pipeline.swift
// SwiftAgents Framework
//
// Type-safe pipeline for composing transformations with explicit input/output types.

import Foundation

// MARK: - Pipeline Composition Operator

/// Operator for pipeline composition.
infix operator >>>: AdditionPrecedence

// MARK: - Pipeline

/// A type-safe pipeline with explicit input and output types.
///
/// `Pipeline` enables composing transformations with compile-time type safety.
/// Pipelines can be chained using the `>>>` operator, with the compiler ensuring
/// that output types match input types at each stage.
///
/// Example:
/// ```swift
/// let parse = Pipeline<String, [String]> { $0.components(separatedBy: ",") }
/// let count = Pipeline<[String], Int> { $0.count }
/// let format = Pipeline<Int, String> { "Found \($0) items" }
///
/// let combined = parse >>> count >>> format
/// let result = try await combined.execute("a,b,c,d")
/// // Result: "Found 4 items"
/// ```
///
/// ## Memory Characteristics
///
/// Each pipeline operation (`map`, `then`, `>>>`) creates a new closure that captures
/// the previous pipeline. For long chains, this creates a nested capture chain where:
/// - Each pipeline step retains a reference to the previous step
/// - Memory usage scales linearly with chain length: O(n) where n = number of steps
/// - Each closure captures its transform function and any context it references
///
/// **Performance Considerations**:
/// - Short chains (≤10 steps): Negligible overhead, optimal for most use cases
/// - Medium chains (10-50 steps): Acceptable overhead, monitor memory if transformations capture large contexts
/// - Long chains (50+ steps): Consider refactoring into batched operations or custom pipelines
///
/// **Best Practices**:
/// ```swift
/// // ✅ Good - short, focused chains
/// let pipeline = parseJSON >>> extractField("data") >>> validateSchema
///
/// // ⚠️ Acceptable - moderate chain, monitor if transforms capture large data
/// let pipeline = step1 >>> step2 >>> step3 >>> ... >>> step15
///
/// // ❌ Avoid - very long chains may accumulate memory
/// // Consider refactoring into multiple pipelines or a custom implementation
/// let pipeline = step1 >>> step2 >>> ... >>> step100
/// ```
///
/// The capture chain is deallocated after pipeline execution completes, so memory
/// overhead only persists for the lifetime of the pipeline instance itself.
public struct Pipeline<Input: Sendable, Output: Sendable>: Sendable {
    // MARK: Public

    /// Creates a new pipeline with the given transformation.
    ///
    /// - Parameter transform: The async transformation function.
    public init(_ transform: @escaping @Sendable (Input) async throws -> Output) {
        self.transform = transform
    }

    /// Executes the pipeline with the given input.
    ///
    /// - Parameter input: The input value.
    /// - Returns: The transformed output.
    /// - Throws: Any error from the transformation.
    public func execute(_ input: Input) async throws -> Output {
        try await transform(input)
    }

    /// Executes the pipeline, returning a Result.
    ///
    /// - Parameter input: The input value.
    /// - Returns: A Result containing the output or error.
    public func executeResult(_ input: Input) async -> Result<Output, Error> {
        do {
            let output = try await execute(input)
            return .success(output)
        } catch {
            return .failure(error)
        }
    }

    // MARK: Private

    /// The transformation function.
    private let transform: @Sendable (Input) async throws -> Output
}

// MARK: - Pipeline Transformations

public extension Pipeline {
    /// Transforms the output of this pipeline.
    ///
    /// - Parameter transform: The transformation to apply to the output.
    /// - Returns: A new pipeline with the transformed output type.
    ///
    /// Example:
    /// ```swift
    /// let stringLength = Pipeline<String, Int> { $0.count }
    /// let doubled = stringLength.map { $0 * 2 }
    /// let result = try await doubled.execute("hello")  // 10
    /// ```
    func map<NewOutput: Sendable>(
        _ transform: @escaping @Sendable (Output) async throws -> NewOutput
    ) -> Pipeline<Input, NewOutput> {
        Pipeline<Input, NewOutput> { input in
            let output = try await self.execute(input)
            return try await transform(output)
        }
    }

    /// Chains this pipeline with another pipeline.
    ///
    /// - Parameter next: The pipeline to execute after this one.
    /// - Returns: A combined pipeline.
    ///
    /// Example:
    /// ```swift
    /// let pipeline1 = Pipeline<String, Int> { $0.count }
    /// let pipeline2 = Pipeline<Int, String> { "Length: \($0)" }
    /// let combined = pipeline1.flatMap { _ in pipeline2 }
    /// ```
    func flatMap<NewOutput: Sendable>(
        _ transform: @escaping @Sendable (Output) async throws -> Pipeline<Output, NewOutput>
    ) -> Pipeline<Input, NewOutput> {
        Pipeline<Input, NewOutput> { input in
            let output = try await self.execute(input)
            let nextPipeline = try await transform(output)
            return try await nextPipeline.execute(output)
        }
    }

    /// Chains this pipeline with another pipeline directly.
    ///
    /// - Parameter next: The next pipeline in the chain.
    /// - Returns: A combined pipeline.
    func then<NewOutput: Sendable>(
        _ next: Pipeline<Output, NewOutput>
    ) -> Pipeline<Input, NewOutput> {
        Pipeline<Input, NewOutput> { input in
            let output = try await self.execute(input)
            return try await next.execute(output)
        }
    }
}

// MARK: - Pipeline Identity and Constants

public extension Pipeline where Input == Output {
    /// An identity pipeline that passes through the input unchanged.
    static var identity: Pipeline<Input, Output> {
        Pipeline { $0 }
    }
}

public extension Pipeline {
    /// Creates a pipeline that always returns the same value.
    ///
    /// - Parameter value: The constant value to return.
    /// - Returns: A pipeline that ignores input and returns the constant.
    static func constant(_ value: Output) -> Pipeline<Input, Output> {
        Pipeline { _ in value }
    }
}

// MARK: - Pipeline Error Handling

public extension Pipeline {
    /// Catches errors and returns a fallback value.
    ///
    /// - Parameters:
    ///   - fallback: The value to return on error.
    ///   - onError: Optional closure called with the error before returning fallback.
    ///              Useful for logging or diagnostic purposes.
    /// - Returns: A pipeline that returns the fallback on error.
    ///
    /// Example:
    /// ```swift
    /// let safe = pipeline.catchError("default") { error in
    ///     print("Pipeline failed: \(error)")
    ///     // Log to analytics, monitoring, etc.
    /// }
    /// ```
    func catchError(
        _ fallback: Output,
        onError: (@Sendable (Error) -> Void)? = nil
    ) -> Pipeline<Input, Output> {
        Pipeline { input in
            do {
                return try await self.execute(input)
            } catch {
                onError?(error)
                return fallback
            }
        }
    }

    /// Catches errors and transforms them.
    ///
    /// - Parameter handler: A closure that transforms errors to outputs.
    /// - Returns: A pipeline that handles errors.
    func catchError(
        _ handler: @escaping @Sendable (Error) async throws -> Output
    ) -> Pipeline<Input, Output> {
        Pipeline { input in
            do {
                return try await self.execute(input)
            } catch {
                return try await handler(error)
            }
        }
    }

    /// Retries the pipeline on failure.
    ///
    /// - Parameters:
    ///   - attempts: Maximum number of attempts.
    ///   - delay: Delay between attempts.
    /// - Returns: A pipeline that retries on failure.
    func retry(
        attempts: Int,
        delay: Duration = .zero
    ) -> Pipeline<Input, Output> {
        Pipeline { input in
            var lastError: Error?
            for attempt in 0..<attempts {
                do {
                    return try await self.execute(input)
                } catch {
                    lastError = error
                    if attempt < attempts - 1, delay > .zero {
                        try? await Task.sleep(for: delay)
                    }
                }
            }
            throw lastError ?? PipelineError.maxRetriesExceeded
        }
    }
}

// MARK: - Pipeline Timeout

public extension Pipeline {
    /// Adds a timeout to the pipeline.
    ///
    /// - Parameter duration: The maximum execution time.
    /// - Returns: A pipeline that throws on timeout.
    func timeout(_ duration: Duration) -> Pipeline<Input, Output> {
        Pipeline { input in
            try await withThrowingTaskGroup(of: Output.self) { group in
                group.addTask {
                    try await self.execute(input)
                }

                group.addTask {
                    try await Task.sleep(for: duration)
                    throw PipelineError.timeout
                }

                guard let result = try await group.next() else {
                    throw PipelineError.timeout
                }

                group.cancelAll()
                return result
            }
        }
    }
}

// MARK: - Pipeline Operator

/// Chains two pipelines together.
///
/// The output type of the first pipeline must match the input type of the second.
///
/// - Parameters:
///   - lhs: The first pipeline.
///   - rhs: The second pipeline.
/// - Returns: A combined pipeline.
///
/// Example:
/// ```swift
/// let combined = stringToInt >>> intToString
/// ```
public func >>> <A: Sendable, B: Sendable, C: Sendable>(
    lhs: Pipeline<A, B>,
    rhs: Pipeline<B, C>
) -> Pipeline<A, C> {
    lhs.then(rhs)
}

// MARK: - Agent Pipeline Extension

public extension AgentRuntime {
    /// Converts this agent into a pipeline.
    ///
    /// - Returns: A pipeline that runs this agent.
    ///
    /// Example:
    /// ```swift
    /// let pipeline = myAgent.asPipeline()
    /// let result = try await pipeline.execute("Hello")
    /// ```
    func asPipeline() -> Pipeline<String, AgentResult> {
        Pipeline { input in
            try await self.run(input)
        }
    }

    /// Converts this agent into a pipeline that extracts the output.
    ///
    /// - Returns: A pipeline that runs this agent and extracts the output string.
    func asOutputPipeline() -> Pipeline<String, String> {
        Pipeline { input in
            let result = try await self.run(input)
            return result.output
        }
    }
}

// MARK: - Transform Helpers

/// Creates a simple transformation pipeline.
///
/// - Parameter transform: The transformation function.
/// - Returns: A pipeline that applies the transformation.
///
/// Example:
/// ```swift
/// let uppercase = transform { (s: String) in s.uppercased() }
/// ```
public func transform<Input: Sendable, Output: Sendable>(
    _ transform: @escaping @Sendable (Input) async throws -> Output
) -> Pipeline<Input, Output> {
    Pipeline(transform)
}

/// Creates a pipeline that extracts the output from an AgentResult.
///
/// Example:
/// ```swift
/// let pipeline = agent.asPipeline() >>> extractOutput()
/// ```
public func extractOutput() -> Pipeline<AgentResult, String> {
    Pipeline { $0.output }
}

/// Creates a pipeline that extracts tool calls from an AgentResult.
public func extractToolCalls() -> Pipeline<AgentResult, [ToolCall]> {
    Pipeline { $0.toolCalls }
}

// MARK: - PipelineError

/// Errors that can occur during pipeline execution.
public enum PipelineError: Error, LocalizedError {
    // MARK: Public

    public var errorDescription: String? {
        switch self {
        case .timeout:
            "Pipeline execution timed out"
        case .maxRetriesExceeded:
            "Maximum retry attempts exceeded"
        case let .custom(message):
            message
        }
    }

    /// The pipeline timed out.
    case timeout

    /// The maximum number of retries was exceeded.
    case maxRetriesExceeded

    /// A custom pipeline error.
    case custom(String)
}
