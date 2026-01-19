// AgentOperators.swift
// SwiftAgents Framework
//
// Operators for composing agents declaratively.

import Foundation

// MARK: - Operator Precedence

precedencegroup AgentConditionalPrecedence {
    higherThan: AdditionPrecedence
    associativity: left
}

precedencegroup AgentCompositionPrecedence {
    higherThan: AgentConditionalPrecedence
    associativity: left
}

precedencegroup AgentSequentialPrecedence {
    higherThan: AgentCompositionPrecedence
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
@available(*, deprecated, message: "Use ParallelGroup for parallel orchestration.")
public actor ParallelComposition: Agent {
    // MARK: Public

    // MARK: - Agent Protocol (nonisolated)

    nonisolated public let tools: [any AnyJSONTool] = []
    nonisolated public let instructions: String = "Parallel composition of agents"
    nonisolated public let configuration: AgentConfiguration

    // MARK: - Properties (nonisolated)

    nonisolated public let parallelAgents: [any Agent]
    nonisolated public let currentMergeStrategy: ParallelMergeStrategy
    nonisolated public let currentErrorHandling: ParallelErrorHandling

    nonisolated public var memory: (any Memory)? { nil }
    nonisolated public var inferenceProvider: (any InferenceProvider)? { nil }

    // MARK: - Initialization

    /// Creates a parallel composition of agents.
    public init(
        agents: [any Agent],
        mergeStrategy: ParallelMergeStrategy = .concatenate(separator: "\n"),
        errorHandling: ParallelErrorHandling = .continueOnPartialFailure,
        configuration: AgentConfiguration = .default
    ) {
        parallelAgents = agents
        currentMergeStrategy = mergeStrategy
        currentErrorHandling = errorHandling
        self.configuration = configuration
    }

    // MARK: - Configuration

    /// Returns a new composition with the specified merge strategy.
    nonisolated public func withMergeStrategy(_ strategy: ParallelMergeStrategy) -> ParallelComposition {
        ParallelComposition(
            agents: parallelAgents,
            mergeStrategy: strategy,
            errorHandling: currentErrorHandling,
            configuration: configuration
        )
    }

    /// Returns a new composition with the specified error handling.
    nonisolated public func withErrorHandling(_ handling: ParallelErrorHandling) -> ParallelComposition {
        ParallelComposition(
            agents: parallelAgents,
            mergeStrategy: currentMergeStrategy,
            errorHandling: handling,
            configuration: configuration
        )
    }

    // MARK: - Agent Protocol

    public func run(_ input: String, session: (any Session)? = nil, hooks: (any RunHooks)? = nil) async throws -> AgentResult {
        guard !parallelAgents.isEmpty else {
            throw AgentError.invalidInput(reason: "No agents configured in parallel composition")
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
                        let result = try await agent.run(input, session: session, hooks: hooks)
                        return .success(result)
                    } catch {
                        return .failure(error)
                    }
                }
            }

            for await result in group {
                switch result {
                case let .success(agentResult):
                    results.append(agentResult)
                case let .failure(error):
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
                // Convert to AgentError if needed
                if let agentError = firstError as? AgentError {
                    throw agentError
                } else {
                    throw AgentError.internalError(reason: firstError.localizedDescription)
                }
            }
        case .continueOnPartialFailure:
            if results.isEmpty, !errors.isEmpty {
                let firstError = errors.first!
                if let agentError = firstError as? AgentError {
                    throw agentError
                } else {
                    throw AgentError.internalError(reason: firstError.localizedDescription)
                }
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

    nonisolated public func stream(_ input: String, session: (any Session)? = nil, hooks: (any RunHooks)? = nil) -> AsyncThrowingStream<AgentEvent, Error> {
        StreamHelper.makeTrackedStream(for: self) { actor, continuation in
            continuation.yield(.started(input: input))
            do {
                let result = try await actor.run(input, session: session, hooks: hooks)
                continuation.yield(.completed(result: result))
                continuation.finish()
            } catch let error as AgentError {
                continuation.yield(.failed(error: error))
                continuation.finish(throwing: error)
            } catch {
                let agentError = AgentError.internalError(reason: error.localizedDescription)
                continuation.yield(.failed(error: agentError))
                continuation.finish(throwing: error)
            }
        }
    }

    public func cancel() async {
        isCancelled = true
        for agent in parallelAgents {
            await agent.cancel()
        }
    }

    // MARK: Private

    // MARK: - Private State

    private var isCancelled = false

    // MARK: - Private Methods

    private func mergeResults(_ results: [AgentResult], errors: [Error]) -> AgentResult {
        let outputs: [String]
        let allToolCalls = results.flatMap(\.toolCalls)
        let allToolResults = results.flatMap(\.toolResults)
        let maxIterations = results.map(\.iterationCount).max() ?? 0

        switch currentMergeStrategy {
        case .firstSuccess:
            outputs = results.first.map { [$0.output] } ?? []
        case .lastSuccess:
            outputs = results.last.map { [$0.output] } ?? []
        case .all:
            outputs = results.map(\.output)
        case let .concatenate(separator):
            outputs = [results.map(\.output).joined(separator: separator)]
        case let .custom(merger):
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
@available(*, deprecated, message: "Use SequentialChain for sequential orchestration.")
public actor AgentSequence: Agent {
    // MARK: Public

    // MARK: - Agent Protocol (nonisolated)

    nonisolated public let tools: [any AnyJSONTool] = []
    nonisolated public let instructions: String = "Sequential composition of agents"
    nonisolated public let configuration: AgentConfiguration

    // MARK: - Properties (nonisolated)

    nonisolated public let sequentialAgents: [any Agent]
    nonisolated public let currentTransformers: [Int: OutputTransformer]

    nonisolated public var memory: (any Memory)? { nil }
    nonisolated public var inferenceProvider: (any InferenceProvider)? { nil }

    // MARK: - Initialization

    public init(
        agents: [any Agent],
        transformers: [Int: OutputTransformer] = [:],
        configuration: AgentConfiguration = .default
    ) {
        sequentialAgents = agents
        currentTransformers = transformers
        self.configuration = configuration
    }

    // MARK: - Configuration

    /// Returns a new sequence with a transformer after the specified index.
    nonisolated public func withTransformer(
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

    public func run(_ input: String, session: (any Session)? = nil, hooks: (any RunHooks)? = nil) async throws -> AgentResult {
        guard !sequentialAgents.isEmpty else {
            throw AgentError.invalidInput(reason: "No agents configured in sequential composition")
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

            let result = try await agent.run(currentInput, session: session, hooks: hooks)
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

    nonisolated public func stream(_ input: String, session: (any Session)? = nil, hooks: (any RunHooks)? = nil) -> AsyncThrowingStream<AgentEvent, Error> {
        StreamHelper.makeTrackedStream(for: self) { actor, continuation in
            continuation.yield(.started(input: input))
            do {
                let result = try await actor.run(input, session: session, hooks: hooks)
                continuation.yield(.completed(result: result))
                continuation.finish()
            } catch let error as AgentError {
                continuation.yield(.failed(error: error))
                continuation.finish(throwing: error)
            } catch {
                let agentError = AgentError.internalError(reason: error.localizedDescription)
                continuation.yield(.failed(error: agentError))
                continuation.finish(throwing: error)
            }
        }
    }

    public func cancel() async {
        isCancelled = true
        for agent in sequentialAgents {
            await agent.cancel()
        }
    }

    // MARK: Private

    // MARK: - Private State

    private var isCancelled = false
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
    // MARK: Public

    // MARK: - Agent Protocol (nonisolated)

    nonisolated public let tools: [any AnyJSONTool] = []
    nonisolated public let instructions: String = "Conditional fallback agent"
    nonisolated public let configuration: AgentConfiguration

    nonisolated public var memory: (any Memory)? { nil }
    nonisolated public var inferenceProvider: (any InferenceProvider)? { nil }

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

    public func run(_ input: String, session: (any Session)? = nil, hooks: (any RunHooks)? = nil) async throws -> AgentResult {
        if isCancelled {
            throw AgentError.cancelled
        }

        do {
            var result = try await primary.run(input, session: session, hooks: hooks)
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
            var result = try await fallback.run(input, session: session, hooks: hooks)
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

    nonisolated public func stream(_ input: String, session: (any Session)? = nil, hooks: (any RunHooks)? = nil) -> AsyncThrowingStream<AgentEvent, Error> {
        StreamHelper.makeTrackedStream(for: self) { actor, continuation in
            continuation.yield(.started(input: input))
            do {
                let result = try await actor.run(input, session: session, hooks: hooks)
                continuation.yield(.completed(result: result))
                continuation.finish()
            } catch let error as AgentError {
                continuation.yield(.failed(error: error))
                continuation.finish(throwing: error)
            } catch {
                let agentError = AgentError.internalError(reason: error.localizedDescription)
                continuation.yield(.failed(error: agentError))
                continuation.finish(throwing: error)
            }
        }
    }

    public func cancel() async {
        isCancelled = true
        await primary.cancel()
        await fallback.cancel()
    }

    // MARK: Private

    private let primary: any Agent
    private let fallback: any Agent
    private var isCancelled = false
}

// MARK: - ParallelMergeStrategy

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

// MARK: - ParallelErrorHandling

/// Strategy for handling errors in parallel execution.
public enum ParallelErrorHandling: Sendable {
    /// Fail immediately on first error.
    case failFast

    /// Continue execution, fail only if all agents fail.
    case continueOnPartialFailure

    /// Collect all errors, continue execution.
    case collectErrors
}
