// ParallelGroup.swift
// SwiftAgents Framework
//
// Parallel execution orchestrator for running multiple agents concurrently.

import Foundation

// MARK: - ResultMergeStrategy

/// A strategy for merging results from parallel agent executions.
///
/// Merge strategies determine how multiple `AgentResult` values from
/// concurrent agent runs are combined into a single result.
///
/// Example:
/// ```swift
/// let strategy = MergeStrategies.Concatenate(separator: "\n---\n", shouldIncludeAgentNames: true)
/// let merged = try await strategy.merge(results)
/// ```
public protocol ResultMergeStrategy: Sendable {
    /// Merges multiple agent results into a single result.
    ///
    /// - Parameter results: Dictionary of agent names to their results.
    /// - Returns: A single merged AgentResult.
    /// - Throws: `OrchestrationError.mergeStrategyFailed` if merging fails.
    func merge(_ results: [String: AgentResult]) async throws -> AgentResult
}

// MARK: - MergeStrategies

/// Built-in merge strategies for parallel execution.
public enum MergeStrategies {
    // MARK: - Concatenate Strategy

    /// Concatenates all agent outputs with a separator.
    ///
    /// Joins the outputs from all agents in order of their names,
    /// optionally including agent names as prefixes.
    ///
    /// Example:
    /// ```swift
    /// let strategy = MergeStrategies.Concatenate(separator: "\n\n", shouldIncludeAgentNames: true)
    /// // Result:
    /// // Agent1:
    /// // Output from agent1
    /// //
    /// // Agent2:
    /// // Output from agent2
    /// ```
    public struct Concatenate: ResultMergeStrategy {
        /// Separator to use between outputs.
        public let separator: String

        /// Whether to include agent names in the output.
        public let shouldIncludeAgentNames: Bool

        /// Creates a concatenate merge strategy.
        ///
        /// - Parameters:
        ///   - separator: String to join outputs. Default: "\n\n"
        ///   - shouldIncludeAgentNames: Whether to prefix outputs with agent names. Default: false
        public init(separator: String = "\n\n", shouldIncludeAgentNames: Bool = false) {
            self.separator = separator
            self.shouldIncludeAgentNames = shouldIncludeAgentNames
        }

        /// Creates a concatenate merge strategy.
        ///
        /// - Parameters:
        ///   - separator: String to join outputs. Default: "\n\n"
        ///   - includeAgentNames: Whether to prefix outputs with agent names.
        @available(*, deprecated, message: "Use shouldIncludeAgentNames instead of includeAgentNames")
        public init(separator: String = "\n\n", includeAgentNames: Bool) {
            self.init(separator: separator, shouldIncludeAgentNames: includeAgentNames)
        }

        public func merge(_ results: [String: AgentResult]) async throws -> AgentResult {
            guard !results.isEmpty else {
                throw OrchestrationError.mergeStrategyFailed(reason: "No results to merge")
            }

            // Sort by agent name for consistent ordering
            let sortedResults = results.sorted { $0.key < $1.key }

            let outputs: [String] = sortedResults.map { name, result in
                if shouldIncludeAgentNames {
                    "\(name):\n\(result.output)"
                } else {
                    result.output
                }
            }

            let mergedOutput = outputs.joined(separator: separator)

            // Combine all tool calls and results
            let allToolCalls = sortedResults.flatMap(\.value.toolCalls)
            let allToolResults = sortedResults.flatMap(\.value.toolResults)

            // Sum iteration counts
            let totalIterations = sortedResults.reduce(0) { $0 + $1.value.iterationCount }

            // Sum durations
            let totalDuration = sortedResults.reduce(Duration.zero) { $0 + $1.value.duration }

            // Merge token usage if all results have it
            let tokenUsage: TokenUsage? = {
                let usages = sortedResults.compactMap(\.value.tokenUsage)
                guard usages.count == sortedResults.count else { return nil }
                let totalInput = usages.reduce(0) { $0 + $1.inputTokens }
                let totalOutput = usages.reduce(0) { $0 + $1.outputTokens }
                return TokenUsage(inputTokens: totalInput, outputTokens: totalOutput)
            }()

            // Merge metadata
            var mergedMetadata: [String: SendableValue] = [:]
            for (agentName, result) in results {
                for (key, value) in result.metadata {
                    let prefixedKey = "\(agentName).\(key)"
                    mergedMetadata[prefixedKey] = value
                }
            }
            mergedMetadata["agent_count"] = .int(results.count)

            return AgentResult(
                output: mergedOutput,
                toolCalls: allToolCalls,
                toolResults: allToolResults,
                iterationCount: totalIterations,
                duration: totalDuration,
                tokenUsage: tokenUsage,
                metadata: mergedMetadata
            )
        }
    }

    // MARK: - First Strategy

    /// Returns the first result (alphabetically by agent name).
    ///
    /// Useful when you only care about getting any result from the parallel
    /// execution, or when agent names are ordered intentionally.
    ///
    /// Example:
    /// ```swift
    /// let strategy = MergeStrategies.First()
    /// ```
    public struct First: ResultMergeStrategy {
        /// Creates a first-result merge strategy.
        public init() {}

        public func merge(_ results: [String: AgentResult]) async throws -> AgentResult {
            guard let firstResult = results.min(by: { $0.key < $1.key }) else {
                throw OrchestrationError.mergeStrategyFailed(reason: "No results to merge")
            }

            let result = firstResult.value
            var metadata = result.metadata
            metadata["selected_agent"] = .string(firstResult.key)
            metadata["total_agents"] = .int(results.count)

            return AgentResult(
                output: result.output,
                toolCalls: result.toolCalls,
                toolResults: result.toolResults,
                iterationCount: result.iterationCount,
                duration: result.duration,
                tokenUsage: result.tokenUsage,
                metadata: metadata
            )
        }
    }

    // MARK: - Longest Strategy

    /// Returns the result with the longest output.
    ///
    /// Useful when you want the most comprehensive response from parallel
    /// agents working on the same task.
    ///
    /// Example:
    /// ```swift
    /// let strategy = MergeStrategies.Longest()
    /// ```
    public struct Longest: ResultMergeStrategy {
        /// Creates a longest-output merge strategy.
        public init() {}

        public func merge(_ results: [String: AgentResult]) async throws -> AgentResult {
            guard !results.isEmpty else {
                throw OrchestrationError.mergeStrategyFailed(reason: "No results to merge")
            }

            let longest = results.max { $0.value.output.count < $1.value.output.count }!

            let result = longest.value
            var metadata = result.metadata
            metadata["selected_agent"] = .string(longest.key)
            metadata["output_length"] = .int(longest.value.output.count)
            metadata["total_agents"] = .int(results.count)

            return AgentResult(
                output: result.output,
                toolCalls: result.toolCalls,
                toolResults: result.toolResults,
                iterationCount: result.iterationCount,
                duration: result.duration,
                tokenUsage: result.tokenUsage,
                metadata: metadata
            )
        }
    }

    // MARK: - Custom Strategy

    /// Uses a custom user-provided merge function.
    ///
    /// Provides complete flexibility for custom merging logic.
    ///
    /// Example:
    /// ```swift
    /// let strategy = MergeStrategies.Custom { results in
    ///     // Custom merging logic
    ///     let output = results.values.map(\.output).joined(separator: " | ")
    ///     return AgentResult(output: output)
    /// }
    /// ```
    public struct Custom: ResultMergeStrategy {
        /// The custom merge function.
        public let mergeFunction: @Sendable ([String: AgentResult]) async throws -> AgentResult

        /// Creates a custom merge strategy.
        ///
        /// - Parameter mergeFunction: The function to use for merging results.
        public init(mergeFunction: @escaping @Sendable ([String: AgentResult]) async throws -> AgentResult) {
            self.mergeFunction = mergeFunction
        }

        public func merge(_ results: [String: AgentResult]) async throws -> AgentResult {
            try await mergeFunction(results)
        }
    }

    // MARK: - Structured Strategy

    /// Returns a structured JSON result with all agent outputs.
    ///
    /// Creates a JSON object where each key is an agent name and each value
    /// is the agent's output. Useful for programmatic processing of results.
    ///
    /// Example:
    /// ```swift
    /// let strategy = MergeStrategies.Structured()
    /// // Result output:
    /// // {
    /// //   "agent1": "Output from agent1",
    /// //   "agent2": "Output from agent2"
    /// // }
    /// ```
    public struct Structured: ResultMergeStrategy {
        /// Creates a structured merge strategy.
        public init() {}

        public func merge(_ results: [String: AgentResult]) async throws -> AgentResult {
            guard !results.isEmpty else {
                throw OrchestrationError.mergeStrategyFailed(reason: "No results to merge")
            }

            // Build JSON structure
            var jsonObject: [String: SendableValue] = [:]
            for (name, result) in results {
                jsonObject[name] = .string(result.output)
            }

            // Convert to JSON string
            let jsonData = try JSONSerialization.data(
                withJSONObject: jsonObject.mapValues { $0.stringValue ?? "" },
                options: [.prettyPrinted, .sortedKeys]
            )
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                throw OrchestrationError.mergeStrategyFailed(reason: "Failed to encode JSON")
            }

            // Combine all tool calls and results
            let allToolCalls = results.values.flatMap(\.toolCalls)
            let allToolResults = results.values.flatMap(\.toolResults)

            // Sum iteration counts and durations
            let totalIterations = results.values.reduce(0) { $0 + $1.iterationCount }
            let totalDuration = results.values.reduce(Duration.zero) { $0 + $1.duration }

            // Metadata
            var metadata: [String: SendableValue] = [:]
            metadata["agent_count"] = .int(results.count)
            metadata["format"] = .string("structured_json")

            return AgentResult(
                output: jsonString,
                toolCalls: allToolCalls,
                toolResults: allToolResults,
                iterationCount: totalIterations,
                duration: totalDuration,
                tokenUsage: nil,
                metadata: metadata
            )
        }
    }
}

// MARK: - ParallelGroup

/// An orchestrator that runs multiple agents in parallel.
///
/// `ParallelGroup` executes multiple agents concurrently on the same input
/// and merges their results using a configurable merge strategy.
///
/// Features:
/// - Concurrent execution using structured concurrency
/// - Configurable concurrency limits
/// - Multiple merge strategies (concatenate, first, longest, custom, structured)
/// - Error handling with continue-on-error support
/// - Cancellation support
///
/// Example:
/// ```swift
/// let group = ParallelGroup(
///     agents: [
///         ("summarizer", SummarizerAgent()),
///         ("translator", TranslatorAgent()),
///         ("analyzer", AnalyzerAgent())
///     ],
///     mergeStrategy: MergeStrategies.Concatenate(shouldIncludeAgentNames: true),
///     shouldContinueOnError: true,
///     maxConcurrency: 2
/// )
///
/// let result = try await group.run("Analyze this text")
/// ```
public actor ParallelGroup: Agent {
    // MARK: Public

    nonisolated public let configuration: AgentConfiguration

    // MARK: - Group Properties (nonisolated)

    /// The agents in this parallel group with their names.
    nonisolated public let agents: [(name: String, agent: any Agent)]

    // MARK: - Agent Protocol Properties (nonisolated)

    nonisolated public var tools: [any AnyJSONTool] { [] }

    nonisolated public var instructions: String {
        "Parallel group of \(agents.count) agents"
    }

    nonisolated public var memory: (any Memory)? { nil }

    nonisolated public var inferenceProvider: (any InferenceProvider)? { nil }

    /// Tracer for this group. Returns `nil` as orchestrators delegate tracing to their sub-agents.
    nonisolated public var tracer: (any Tracer)? { nil }

    // MARK: - Initialization

    /// Creates a new parallel group orchestrator.
    ///
    /// - Parameters:
    ///   - agents: Array of (name, agent) tuples.
    ///   - mergeStrategy: Strategy for merging results. Default: Concatenate()
    ///   - shouldContinueOnError: Whether to continue if some agents fail. Default: true
    ///   - maxConcurrency: Maximum concurrent agents. Default: nil (unlimited)
    ///   - configuration: Agent configuration. Default: .default
    public init(
        agents: [(name: String, agent: any Agent)],
        mergeStrategy: any ResultMergeStrategy = MergeStrategies.Concatenate(),
        shouldContinueOnError: Bool = true,
        maxConcurrency: Int? = nil,
        configuration: AgentConfiguration = .default
    ) {
        self.agents = agents
        self.mergeStrategy = mergeStrategy
        self.shouldContinueOnError = shouldContinueOnError
        self.maxConcurrency = maxConcurrency
        self.configuration = configuration
    }

    /// Convenience initializer that auto-generates agent names.
    ///
    /// Agent names will be "agent_0", "agent_1", etc.
    ///
    /// - Parameters:
    ///   - agents: Array of agents.
    ///   - mergeStrategy: Strategy for merging results. Default: Concatenate()
    ///   - shouldContinueOnError: Whether to continue if some agents fail. Default: true
    ///   - maxConcurrency: Maximum concurrent agents. Default: nil (unlimited)
    ///   - configuration: Agent configuration. Default: .default
    public init(
        agents: [any Agent],
        mergeStrategy: any ResultMergeStrategy = MergeStrategies.Concatenate(),
        shouldContinueOnError: Bool = true,
        maxConcurrency: Int? = nil,
        configuration: AgentConfiguration = .default
    ) {
        self.agents = agents.enumerated().map { index, agent in
            ("agent_\(index)", agent)
        }
        self.mergeStrategy = mergeStrategy
        self.shouldContinueOnError = shouldContinueOnError
        self.maxConcurrency = maxConcurrency
        self.configuration = configuration
    }

    // MARK: - Deprecated Initializers

    /// Creates a new parallel group orchestrator.
    ///
    /// - Parameters:
    ///   - agents: Array of (name, agent) tuples.
    ///   - mergeStrategy: Strategy for merging results. Default: Concatenate()
    ///   - continueOnError: Whether to continue if some agents fail. Default: false
    ///   - maxConcurrency: Maximum concurrent agents. Default: nil (unlimited)
    ///   - configuration: Agent configuration. Default: .default
    @available(*, deprecated, message: "Use shouldContinueOnError instead of continueOnError")
    public init(
        agents: [(name: String, agent: any Agent)],
        mergeStrategy: any ResultMergeStrategy = MergeStrategies.Concatenate(),
        continueOnError: Bool,
        maxConcurrency: Int? = nil,
        configuration: AgentConfiguration = .default
    ) {
        self.init(
            agents: agents,
            mergeStrategy: mergeStrategy,
            shouldContinueOnError: continueOnError,
            maxConcurrency: maxConcurrency,
            configuration: configuration
        )
    }

    /// Convenience initializer that auto-generates agent names.
    ///
    /// - Parameters:
    ///   - agents: Array of agents.
    ///   - mergeStrategy: Strategy for merging results. Default: Concatenate()
    ///   - continueOnError: Whether to continue if some agents fail. Default: false
    ///   - maxConcurrency: Maximum concurrent agents. Default: nil (unlimited)
    ///   - configuration: Agent configuration. Default: .default
    @available(*, deprecated, message: "Use shouldContinueOnError instead of continueOnError")
    public init(
        agents: [any Agent],
        mergeStrategy: any ResultMergeStrategy = MergeStrategies.Concatenate(),
        continueOnError: Bool,
        maxConcurrency: Int? = nil,
        configuration: AgentConfiguration = .default
    ) {
        self.init(
            agents: agents,
            mergeStrategy: mergeStrategy,
            shouldContinueOnError: continueOnError,
            maxConcurrency: maxConcurrency,
            configuration: configuration
        )
    }

    // MARK: - Context Management

    /// Sets the shared context for orchestration.
    ///
    /// - Parameter context: The context to use.
    public func setContext(_ context: AgentContext) {
        self.context = context
    }

    // MARK: - Agent Protocol Methods

    /// Executes all agents in parallel and merges their results.
    ///
    /// Runs all agents concurrently on the same input, respecting the
    /// `maxConcurrency` limit if set. Results are merged using the
    /// configured merge strategy.
    ///
    /// - Parameters:
    ///   - input: The input to send to all agents.
    ///   - session: Optional session for state persistence.
    ///   - hooks: Optional hooks for lifecycle callbacks.
    /// - Returns: The merged result from all agents.
    /// - Throws: `OrchestrationError.allAgentsFailed` if all agents fail,
    ///           or rethrows the first agent error if `shouldContinueOnError` is false.
    public func run(_ input: String, session: (any Session)? = nil, hooks: (any RunHooks)? = nil) async throws -> AgentResult {
        guard !agents.isEmpty else {
            throw OrchestrationError.noAgentsConfigured
        }

        isCancelled = false

        var results: [String: AgentResult] = [:]
        var errors: [String: Error] = [:]

        let sharedContext = context ?? AgentContext(input: input)
        context = sharedContext
        await sharedContext.recordExecution(agentName: "ParallelGroup")

        // Execute agents with structured concurrency
        try await withThrowingTaskGroup(of: (String, Result<AgentResult, Error>).self) { group in
            var runningCount = 0

            for (name, agent) in agents {
                // Check cancellation
                if isCancelled {
                    break
                }

                // Respect concurrency limit
                if let limit = maxConcurrency {
                    while runningCount >= limit {
                        // Wait for one task to complete
                        if let (completedName, result) = try await group.next() {
                            runningCount -= 1
                            switch result {
                            case let .success(agentResult):
                                results[completedName] = agentResult
                            case let .failure(error):
                                errors[completedName] = error
                                if !shouldContinueOnError {
                                    throw error
                                }
                            }
                        }
                    }
                }

                // Start agent execution
                group.addTask {
                    do {
                        let result = try await agent.run(input, session: session, hooks: hooks)
                        return (name, .success(result))
                    } catch {
                        return (name, .failure(error))
                    }
                }
                runningCount += 1
            }

            // Collect remaining results
            for try await (name, result) in group {
                switch result {
                case let .success(agentResult):
                    results[name] = agentResult
                case let .failure(error):
                    errors[name] = error
                    if !shouldContinueOnError {
                        throw error
                    }
                }
            }
        }

        // Check if execution was cancelled
        if isCancelled {
            throw AgentError.cancelled
        }

        // If all agents failed, throw combined error
        if results.isEmpty, !errors.isEmpty {
            let errorMessages = errors.map { "\($0.key): \($0.value.localizedDescription)" }
            throw OrchestrationError.allAgentsFailed(errors: errorMessages)
        }

        // Merge results using the configured strategy
        guard !results.isEmpty else {
            throw OrchestrationError.mergeStrategyFailed(reason: "No successful results to merge")
        }

        let mergedResult = try await mergeStrategy.merge(results)

        // Record result in context if available
        if let context {
            await context.setPreviousOutput(mergedResult)
        }

        return mergedResult
    }

    /// Streams execution events from parallel agents.
    ///
    /// Note: Events from all agents are interleaved as they occur.
    /// The final event will be `.completed` with the merged result.
    ///
    /// - Parameters:
    ///   - input: The input to send to all agents.
    ///   - session: Optional session for state persistence.
    ///   - hooks: Optional hooks for lifecycle callbacks.
    /// - Returns: An async stream of agent events.
    nonisolated public func stream(_ input: String, session: (any Session)? = nil, hooks: (any RunHooks)? = nil) -> AsyncThrowingStream<AgentEvent, Error> {
        StreamHelper.makeTrackedStream(for: self) { actor, continuation in
            continuation.yield(.started(input: input))

            let groupName = actor.configuration.name.isEmpty ? "ParallelGroup" : actor.configuration.name
            let relay = ParallelStreamRelay(continuation: continuation)

            do {
                let result = try await actor.streamExecution(
                    input: input,
                    session: session,
                    hooks: hooks,
                    relay: relay,
                    groupName: groupName
                )
                continuation.yield(.completed(result: result))
                continuation.finish()
            } catch let error as AgentError {
                continuation.yield(.failed(error: error))
                continuation.finish(throwing: error)
            } catch {
                let agentError = AgentError.internalError(reason: error.localizedDescription)
                continuation.yield(.failed(error: agentError))
                continuation.finish(throwing: agentError)
            }
        }
    }

    /// Cancels the parallel execution.
    ///
    /// This sets the cancellation flag. Individual agents must support
    /// cancellation for this to take effect.
    public func cancel() async {
        isCancelled = true
    }

    // MARK: Private

    // MARK: - Private State

    /// The strategy for merging parallel results.
    private let mergeStrategy: any ResultMergeStrategy

    /// Whether to continue execution if some agents fail.
    private let shouldContinueOnError: Bool

    /// Maximum number of agents to run concurrently.
    /// If nil, all agents run without limit.
    private let maxConcurrency: Int?

    /// Whether the execution has been cancelled.
    private var isCancelled: Bool = false

    /// Optional shared context for orchestration.
    private var context: AgentContext?

    // MARK: - Streaming Helpers

    private func streamExecution(
        input: String,
        session: (any Session)?,
        hooks: (any RunHooks)?,
        relay: ParallelStreamRelay,
        groupName: String
    ) async throws -> AgentResult {
        guard !agents.isEmpty else {
            throw OrchestrationError.noAgentsConfigured
        }

        isCancelled = false

        var results: [String: AgentResult] = [:]
        var errors: [String: Error] = [:]

        let sharedContext = context ?? AgentContext(input: input)
        context = sharedContext
        await sharedContext.recordExecution(agentName: groupName)

        try await withThrowingTaskGroup(of: (String, Result<AgentResult, Error>).self) { group in
            var runningCount = 0

            for (name, agent) in agents {
                if isCancelled {
                    break
                }

                if let limit = maxConcurrency {
                    while runningCount >= limit {
                        if let (completedName, result) = try await group.next() {
                            runningCount -= 1
                            switch result {
                            case let .success(agentResult):
                                results[completedName] = agentResult
                            case let .failure(error):
                                errors[completedName] = error
                                if !shouldContinueOnError {
                                    throw error
                                }
                            }
                        }
                    }
                }

                group.addTask { [groupName] in
                    do {
                        let result = try await self.streamAgent(
                            name: name,
                            agent: agent,
                            input: input,
                            session: session,
                            hooks: hooks,
                            relay: relay,
                            groupName: groupName
                        )
                        return (name, .success(result))
                    } catch {
                        return (name, .failure(error))
                    }
                }
                runningCount += 1
            }

            for try await (name, result) in group {
                switch result {
                case let .success(agentResult):
                    results[name] = agentResult
                case let .failure(error):
                    errors[name] = error
                    if !shouldContinueOnError {
                        throw error
                    }
                }
            }
        }

        if isCancelled {
            throw AgentError.cancelled
        }

        if results.isEmpty, !errors.isEmpty {
            let errorMessages = errors.map { "\($0.key): \($0.value.localizedDescription)" }
            throw OrchestrationError.allAgentsFailed(errors: errorMessages)
        }

        guard !results.isEmpty else {
            throw OrchestrationError.mergeStrategyFailed(reason: "No successful results to merge")
        }

        let mergedResult = try await mergeStrategy.merge(results)

        if let context {
            await context.setPreviousOutput(mergedResult)
        }

        return mergedResult
    }

    private func streamAgent(
        name: String,
        agent: any Agent,
        input: String,
        session: (any Session)?,
        hooks: (any RunHooks)?,
        relay: ParallelStreamRelay,
        groupName: String
    ) async throws -> AgentResult {
        await relay.yield(.handoffStarted(from: groupName, to: name, input: input))
        var result: AgentResult?

        for try await event in agent.stream(input, session: session, hooks: hooks) {
            switch event {
            case .started:
                continue
            case let .completed(subResult):
                result = subResult
            case let .failed(error):
                throw error
            default:
                await relay.yield(event)
            }
        }

        guard let finalResult = result else {
            throw AgentError.internalError(reason: "ParallelGroup stream ended without completion")
        }

        await relay.yield(.handoffCompletedWithResult(from: groupName, to: name, result: finalResult))
        return finalResult
    }
}

// MARK: CustomStringConvertible

extension ParallelGroup: CustomStringConvertible {
    nonisolated public var description: String {
        let agentNames = agents.map(\.name).joined(separator: ", ")
        return "ParallelGroup(\(agents.count) agents: [\(agentNames)])"
    }
}

// MARK: - ParallelStreamRelay

private actor ParallelStreamRelay {
    private let continuation: AsyncThrowingStream<AgentEvent, Error>.Continuation

    init(continuation: AsyncThrowingStream<AgentEvent, Error>.Continuation) {
        self.continuation = continuation
    }

    func yield(_ event: AgentEvent) {
        continuation.yield(event)
    }
}
