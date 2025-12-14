// AgentOperators.swift
// SwiftAgents Framework
//
// Operators for composing agents declaratively.

import Foundation

// MARK: - Operator Precedence

precedencegroup AgentCompositionPrecedence {
    higherThan: AdditionPrecedence
    associativity: left
}

precedencegroup AgentSequentialPrecedence {
    higherThan: AgentCompositionPrecedence
    associativity: left
}

precedencegroup AgentConditionalPrecedence {
    lowerThan: AgentCompositionPrecedence
    associativity: left
}

// MARK: - Parallel Composition Operator

infix operator &+: AgentCompositionPrecedence

/// Combines two agents for parallel execution.
///
/// Both agents receive the same input and run concurrently.
/// Results are merged according to the default strategy.
///
/// Example:
/// ```swift
/// let parallel = weatherAgent &+ newsAgent &+ stockAgent
/// let result = try await parallel.run("Get today's info")
/// ```
public func &+ (lhs: any Agent, rhs: any Agent) -> ParallelComposition {
    ParallelComposition(agents: [lhs, rhs])
}

/// Adds another agent to a parallel composition.
public func &+ (lhs: ParallelComposition, rhs: any Agent) -> ParallelComposition {
    var agents = lhs.parallelAgents
    agents.append(rhs)
    return ParallelComposition(
        agents: agents,
        mergeStrategy: lhs.currentMergeStrategy,
        errorHandling: lhs.currentErrorHandling
    )
}

// MARK: - Sequential Composition Operator

infix operator ~>: AgentSequentialPrecedence

/// Chains two agents sequentially with output passing.
///
/// The first agent runs, then its output becomes the input for the second agent.
///
/// Example:
/// ```swift
/// let sequential = fetchAgent ~> analyzeAgent ~> summarizeAgent
/// let result = try await sequential.run("Analyze Q4 sales")
/// ```
public func ~> (lhs: any Agent, rhs: any Agent) -> AgentSequence {
    AgentSequence(agents: [lhs, rhs])
}

/// Adds another agent to a sequential chain.
public func ~> (lhs: AgentSequence, rhs: any Agent) -> AgentSequence {
    var agents = lhs.sequentialAgents
    agents.append(rhs)
    return AgentSequence(agents: agents, transformers: lhs.currentTransformers)
}

// MARK: - Conditional/Fallback Operator

infix operator |?: AgentConditionalPrecedence

/// Creates a conditional router where the second agent is a fallback.
///
/// The first agent runs; if it fails, the second agent runs instead.
///
/// Example:
/// ```swift
/// let resilient = primaryAgent |? fallbackAgent
/// let result = try await resilient.run("Handle request")
/// ```
public func |? (lhs: any Agent, rhs: any Agent) -> ConditionalFallback {
    ConditionalFallback(primary: lhs, fallback: rhs)
}

// MARK: - ParallelComposition

/// An agent that runs multiple agents in parallel and merges results.
///
/// `ParallelComposition` executes all agents concurrently with the same input,
/// then combines their results according to the configured merge strategy.
///
/// Example:
/// ```swift
/// let parallel = weatherAgent &+ newsAgent
/// let configured = parallel
///     .withMergeStrategy(.concatenate(separator: "\n---\n"))
///     .withErrorHandling(.continueOnPartialFailure)
///
/// let result = try await configured.run("What's happening today?")
/// ```
public actor ParallelComposition: Agent {
    // MARK: - Agent Protocol (nonisolated)

    public nonisolated let tools: [any Tool] = []
    public nonisolated let instructions: String = "Parallel composition of agents"
    public nonisolated let configuration: AgentConfiguration
    public nonisolated var memory: (any AgentMemory)? { nil }
    public nonisolated var inferenceProvider: (any InferenceProvider)? { nil }

    // MARK: - Properties (nonisolated)

    public nonisolated let parallelAgents: [any Agent]
    public nonisolated let currentMergeStrategy: ParallelMergeStrategy
    public nonisolated let currentErrorHandling: ParallelErrorHandling

    // MARK: - Private State

    private var isCancelled = false

    // MARK: - Initialization

    /// Creates a parallel composition of agents.
    public init(
        agents: [any Agent],
        mergeStrategy: ParallelMergeStrategy = .concatenate(separator: "\n"),
        errorHandling: ParallelErrorHandling = .failFast,
        configuration: AgentConfiguration = .default
    ) {
        self.parallelAgents = agents
        self.currentMergeStrategy = mergeStrategy
        self.currentErrorHandling = errorHandling
        self.configuration = configuration
    }

    // MARK: - Configuration

    /// Returns a new composition with the specified merge strategy.
    public nonisolated func withMergeStrategy(_ strategy: ParallelMergeStrategy) -> ParallelComposition {
        ParallelComposition(
            agents: parallelAgents,
            mergeStrategy: strategy,
            errorHandling: currentErrorHandling,
            configuration: configuration
        )
    }

    /// Returns a new composition with the specified error handling.
    public nonisolated func withErrorHandling(_ handling: ParallelErrorHandling) -> ParallelComposition {
        ParallelComposition(
            agents: parallelAgents,
            mergeStrategy: currentMergeStrategy,
            errorHandling: handling,
            configuration: configuration
        )
    }

    // MARK: - Agent Protocol

    public func run(_ input: String) async throws -> AgentResult {
        guard !parallelAgents.isEmpty else {
            throw OrchestrationError.noAgentsConfigured
        }

        if isCancelled {
            throw AgentError.cancelled
        }

        let startTime = ContinuousClock.now

        var results: [AgentResult] = []
        var errors: [Error] = []

        await withTaskGroup(of: Result<AgentResult, Error>.self) { group in
            for agent in parallelAgents {
                group.addTask {
                    do {
                        let result = try await agent.run(input)
                        return .success(result)
                    } catch {
                        return .failure(error)
                    }
                }
            }

            for await result in group {
                switch result {
                case .success(let agentResult):
                    results.append(agentResult)
                case .failure(let error):
                    errors.append(error)
                    if case .failFast = currentErrorHandling {
                        group.cancelAll()
                    }
                }
            }
        }

        // Handle errors based on strategy
        switch currentErrorHandling {
        case .failFast:
            if let firstError = errors.first {
                throw firstError
            }
        case .continueOnPartialFailure:
            if results.isEmpty && !errors.isEmpty {
                throw errors.first!
            }
        case .collectErrors:
            // Continue with results, errors can be inspected via metadata
            break
        }

        // Merge results
        let mergedResult = mergeResults(results, errors: errors)
        let duration = ContinuousClock.now - startTime

        return AgentResult(
            output: mergedResult.output,
            toolCalls: mergedResult.toolCalls,
            toolResults: mergedResult.toolResults,
            iterationCount: mergedResult.iterationCount,
            duration: duration,
            tokenUsage: nil,
            metadata: mergedResult.metadata
        )
    }

    public nonisolated func stream(_ input: String) -> AsyncThrowingStream<AgentEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    continuation.yield(.started(input: input))
                    let result = try await self.run(input)
                    continuation.yield(.completed(result: result))
                    continuation.finish()
                } catch {
                    if let agentError = error as? AgentError {
                        continuation.yield(.failed(error: agentError))
                    } else {
                        continuation.yield(.failed(error: .internalError(reason: error.localizedDescription)))
                    }
                    continuation.finish()
                }
            }
        }
    }

    public func cancel() async {
        isCancelled = true
        for agent in parallelAgents {
            await agent.cancel()
        }
    }

    // MARK: - Private Methods

    private func mergeResults(_ results: [AgentResult], errors: [Error]) -> AgentResult {
        let outputs: [String]
        let allToolCalls = results.flatMap { $0.toolCalls }
        let allToolResults = results.flatMap { $0.toolResults }
        let maxIterations = results.map { $0.iterationCount }.max() ?? 0

        switch currentMergeStrategy {
        case .firstSuccess:
            outputs = results.first.map { [$0.output] } ?? []
        case .lastSuccess:
            outputs = results.last.map { [$0.output] } ?? []
        case .all:
            outputs = results.map { $0.output }
        case .concatenate(let separator):
            outputs = [results.map { $0.output }.joined(separator: separator)]
        case .custom(let merger):
            outputs = [merger(results)]
        }

        var metadata: [String: SendableValue] = [:]
        metadata["parallel.agent_count"] = .int(parallelAgents.count)
        metadata["parallel.success_count"] = .int(results.count)
        metadata["parallel.error_count"] = .int(errors.count)

        return AgentResult(
            output: outputs.joined(separator: "\n"),
            toolCalls: allToolCalls,
            toolResults: allToolResults,
            iterationCount: maxIterations,
            duration: .zero,
            tokenUsage: nil,
            metadata: metadata
        )
    }
}

// MARK: - AgentSequence

/// An agent that runs multiple agents sequentially, passing output to input.
///
/// `AgentSequence` executes agents in order, where each agent's output
/// becomes the next agent's input.
///
/// Example:
/// ```swift
/// let sequence = fetchAgent ~> processAgent ~> formatAgent
/// let result = try await sequence.run("Process data")
/// ```
public actor AgentSequence: Agent {
    // MARK: - Agent Protocol (nonisolated)

    public nonisolated let tools: [any Tool] = []
    public nonisolated let instructions: String = "Sequential composition of agents"
    public nonisolated let configuration: AgentConfiguration
    public nonisolated var memory: (any AgentMemory)? { nil }
    public nonisolated var inferenceProvider: (any InferenceProvider)? { nil }

    // MARK: - Properties (nonisolated)

    public nonisolated let sequentialAgents: [any Agent]
    public nonisolated let currentTransformers: [Int: OutputTransformer]

    // MARK: - Private State

    private var isCancelled = false

    // MARK: - Initialization

    public init(
        agents: [any Agent],
        transformers: [Int: OutputTransformer] = [:],
        configuration: AgentConfiguration = .default
    ) {
        self.sequentialAgents = agents
        self.currentTransformers = transformers
        self.configuration = configuration
    }

    // MARK: - Configuration

    /// Returns a new sequence with a transformer after the specified index.
    public nonisolated func withTransformer(
        after index: Int,
        _ transformer: OutputTransformer
    ) -> AgentSequence {
        var transformers = currentTransformers
        transformers[index] = transformer
        return AgentSequence(
            agents: sequentialAgents,
            transformers: transformers,
            configuration: configuration
        )
    }

    // MARK: - Agent Protocol

    public func run(_ input: String) async throws -> AgentResult {
        guard !sequentialAgents.isEmpty else {
            throw OrchestrationError.noAgentsConfigured
        }

        if isCancelled {
            throw AgentError.cancelled
        }

        let startTime = ContinuousClock.now
        var currentInput = input
        var allToolCalls: [ToolCall] = []
        var allToolResults: [ToolResult] = []
        var totalIterations = 0
        var lastResult: AgentResult?

        for (index, agent) in sequentialAgents.enumerated() {
            if isCancelled {
                throw AgentError.cancelled
            }

            let result = try await agent.run(currentInput)
            allToolCalls.append(contentsOf: result.toolCalls)
            allToolResults.append(contentsOf: result.toolResults)
            totalIterations += result.iterationCount

            lastResult = result

            // Apply transformer or use passthrough
            let transformer = currentTransformers[index] ?? .passthrough
            currentInput = transformer.apply(result)
        }

        let duration = ContinuousClock.now - startTime

        return AgentResult(
            output: lastResult?.output ?? "",
            toolCalls: allToolCalls,
            toolResults: allToolResults,
            iterationCount: totalIterations,
            duration: duration,
            tokenUsage: nil,
            metadata: ["sequential.agent_count": .int(sequentialAgents.count)]
        )
    }

    public nonisolated func stream(_ input: String) -> AsyncThrowingStream<AgentEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    continuation.yield(.started(input: input))
                    let result = try await self.run(input)
                    continuation.yield(.completed(result: result))
                    continuation.finish()
                } catch {
                    if let agentError = error as? AgentError {
                        continuation.yield(.failed(error: agentError))
                    } else {
                        continuation.yield(.failed(error: .internalError(reason: error.localizedDescription)))
                    }
                    continuation.finish()
                }
            }
        }
    }

    public func cancel() async {
        isCancelled = true
        for agent in sequentialAgents {
            await agent.cancel()
        }
    }
}

// MARK: - ConditionalFallback

/// An agent that tries a primary agent and falls back to another on failure.
///
/// Example:
/// ```swift
/// let resilient = primaryAgent |? fallbackAgent
/// let result = try await resilient.run("Handle request")
/// ```
public actor ConditionalFallback: Agent {
    // MARK: - Agent Protocol (nonisolated)

    public nonisolated let tools: [any Tool] = []
    public nonisolated let instructions: String = "Conditional fallback agent"
    public nonisolated let configuration: AgentConfiguration
    public nonisolated var memory: (any AgentMemory)? { nil }
    public nonisolated var inferenceProvider: (any InferenceProvider)? { nil }

    // MARK: - Properties

    private let primary: any Agent
    private let fallback: any Agent
    private var isCancelled = false

    // MARK: - Initialization

    public init(
        primary: any Agent,
        fallback: any Agent,
        configuration: AgentConfiguration = .default
    ) {
        self.primary = primary
        self.fallback = fallback
        self.configuration = configuration
    }

    // MARK: - Agent Protocol

    public func run(_ input: String) async throws -> AgentResult {
        if isCancelled {
            throw AgentError.cancelled
        }

        do {
            var result = try await primary.run(input)
            result = AgentResult(
                output: result.output,
                toolCalls: result.toolCalls,
                toolResults: result.toolResults,
                iterationCount: result.iterationCount,
                duration: result.duration,
                tokenUsage: result.tokenUsage,
                metadata: result.metadata.merging(["fallback.used": .bool(false)]) { _, new in new }
            )
            return result
        } catch {
            var result = try await fallback.run(input)
            result = AgentResult(
                output: result.output,
                toolCalls: result.toolCalls,
                toolResults: result.toolResults,
                iterationCount: result.iterationCount,
                duration: result.duration,
                tokenUsage: result.tokenUsage,
                metadata: result.metadata.merging([
                    "fallback.used": .bool(true),
                    "fallback.primary_error": .string(error.localizedDescription)
                ]) { _, new in new }
            )
            return result
        }
    }

    public nonisolated func stream(_ input: String) -> AsyncThrowingStream<AgentEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    continuation.yield(.started(input: input))
                    let result = try await self.run(input)
                    continuation.yield(.completed(result: result))
                    continuation.finish()
                } catch {
                    if let agentError = error as? AgentError {
                        continuation.yield(.failed(error: agentError))
                    } else {
                        continuation.yield(.failed(error: .internalError(reason: error.localizedDescription)))
                    }
                    continuation.finish()
                }
            }
        }
    }

    public func cancel() async {
        isCancelled = true
        await primary.cancel()
        await fallback.cancel()
    }
}

// MARK: - Supporting Types

/// Strategy for merging parallel agent results.
public enum ParallelMergeStrategy: Sendable {
    /// Use only the first successful result.
    case firstSuccess

    /// Use only the last successful result.
    case lastSuccess

    /// Include all results.
    case all

    /// Concatenate outputs with a separator.
    case concatenate(separator: String)

    /// Custom merge function.
    case custom(@Sendable ([AgentResult]) -> String)
}

/// Strategy for handling errors in parallel execution.
public enum ParallelErrorHandling: Sendable {
    /// Fail immediately on first error.
    case failFast

    /// Continue execution, fail only if all agents fail.
    case continueOnPartialFailure

    /// Collect all errors, continue execution.
    case collectErrors
}
