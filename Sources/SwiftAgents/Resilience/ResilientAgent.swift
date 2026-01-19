// ResilientAgent.swift
// SwiftAgents Framework
//
// Fluent resilience patterns for agents: retry, circuit breaker, fallback, timeout.

import Foundation

// MARK: - ResilientAgent

/// An agent wrapper that adds resilience patterns like retry, circuit breaker, fallback, and timeout.
///
/// `ResilientAgent` decorates any agent with fault-tolerant execution behavior.
/// Resilience patterns can be chained fluently for comprehensive protection.
///
/// Example:
/// ```swift
/// let resilientAgent = myAgent
///     .withRetry(.exponentialBackoff(maxAttempts: 3))
///     .withCircuitBreaker(threshold: 5, resetTimeout: .seconds(60))
///     .withFallback(fallbackAgent)
///     .withTimeout(.seconds(30))
///
/// let result = try await resilientAgent.run("process request")
/// ```
public actor ResilientAgent: Agent {
    // MARK: Public

    // MARK: - Agent Protocol (nonisolated)

    nonisolated public let tools: [any AnyJSONTool]
    nonisolated public let instructions: String
    nonisolated public let configuration: AgentConfiguration

    nonisolated public var memory: (any Memory)? { baseMemory }
    nonisolated public var inferenceProvider: (any InferenceProvider)? { baseInferenceProvider }
    nonisolated public var tracer: (any Tracer)? { baseTracer }
    nonisolated public var inputGuardrails: [any InputGuardrail] { baseInputGuardrails }
    nonisolated public var outputGuardrails: [any OutputGuardrail] { baseOutputGuardrails }
    nonisolated public var handoffs: [AnyHandoffConfiguration] { baseHandoffs }

    // MARK: - Initialization

    /// Creates a resilient agent wrapper.
    ///
    /// - Parameters:
    ///   - base: The base agent to wrap.
    ///   - retryPolicy: Optional retry policy for transient failures.
    ///   - circuitBreaker: Optional circuit breaker for failure protection.
    ///   - fallbackAgent: Optional fallback agent when all else fails.
    ///   - timeout: Optional timeout duration for execution.
    public init(
        base: any Agent,
        retryPolicy: RetryPolicy? = nil,
        circuitBreaker: CircuitBreaker? = nil,
        fallbackAgent: (any Agent)? = nil,
        timeout: Duration? = nil
    ) {
        self.base = base
        tools = base.tools
        instructions = base.instructions
        configuration = base.configuration
        baseMemory = base.memory
        baseInferenceProvider = base.inferenceProvider
        baseTracer = base.tracer
        baseInputGuardrails = base.inputGuardrails
        baseOutputGuardrails = base.outputGuardrails
        baseHandoffs = base.handoffs
        self.retryPolicy = retryPolicy
        self.circuitBreaker = circuitBreaker
        self.fallbackAgent = fallbackAgent
        timeoutDuration = timeout
    }

    // MARK: - Fluent Configuration

    /// Returns a new resilient agent with retry behavior.
    ///
    /// - Parameter policy: The retry policy to apply.
    /// - Returns: A new resilient agent with retry enabled.
    nonisolated public func withRetry(_ policy: RetryPolicy) -> ResilientAgent {
        ResilientAgent(
            base: base,
            retryPolicy: policy,
            circuitBreaker: circuitBreaker,
            fallbackAgent: fallbackAgent,
            timeout: timeoutDuration
        )
    }

    /// Returns a new resilient agent with circuit breaker protection.
    ///
    /// - Parameters:
    ///   - threshold: Number of failures before opening the circuit.
    ///   - resetTimeout: Time to wait before attempting recovery.
    /// - Returns: A new resilient agent with circuit breaker enabled.
    nonisolated public func withCircuitBreaker(threshold: Int, resetTimeout: Duration) -> ResilientAgent {
        let breaker = CircuitBreaker(
            name: "agent-\(UUID().uuidString)",
            failureThreshold: threshold,
            resetTimeout: resetTimeout.timeInterval
        )
        return ResilientAgent(
            base: base,
            retryPolicy: retryPolicy,
            circuitBreaker: breaker,
            fallbackAgent: fallbackAgent,
            timeout: timeoutDuration
        )
    }

    /// Returns a new resilient agent with a fallback agent.
    ///
    /// - Parameter fallback: The agent to use when the primary fails.
    /// - Returns: A new resilient agent with fallback enabled.
    nonisolated public func withFallback(_ fallback: any Agent) -> ResilientAgent {
        ResilientAgent(
            base: base,
            retryPolicy: retryPolicy,
            circuitBreaker: circuitBreaker,
            fallbackAgent: fallback,
            timeout: timeoutDuration
        )
    }

    /// Returns a new resilient agent with timeout protection.
    ///
    /// - Parameter duration: Maximum execution time.
    /// - Returns: A new resilient agent with timeout enabled.
    nonisolated public func withTimeout(_ duration: Duration) -> ResilientAgent {
        ResilientAgent(
            base: base,
            retryPolicy: retryPolicy,
            circuitBreaker: circuitBreaker,
            fallbackAgent: fallbackAgent,
            timeout: duration
        )
    }

    // MARK: - Agent Protocol

    public func run(_ input: String, session: (any Session)? = nil, hooks: (any RunHooks)? = nil) async throws -> AgentResult {
        if isCancelled {
            throw AgentError.cancelled
        }

        let startTime = ContinuousClock.now

        do {
            // Apply timeout if configured
            let result: AgentResult = if let timeout = timeoutDuration {
                try await executeWithTimeout(input, session: session, hooks: hooks, timeout: timeout)
            } else {
                try await executeWithResilience(input, session: session, hooks: hooks)
            }

            // Add resilience metadata
            let duration = ContinuousClock.now - startTime
            return addResilienceMetadata(to: result, duration: duration, usedFallback: false)

        } catch {
            // Try fallback if available
            if let fallback = fallbackAgent {
                do {
                    // Notify hooks of handoff to fallback agent
                    let fallbackContext = AgentContext(input: input)
                    await hooks?.onHandoff(context: fallbackContext, fromAgent: self, toAgent: fallback)

                    let fallbackResult = try await fallback.run(input, session: session, hooks: hooks)
                    let duration = ContinuousClock.now - startTime
                    return addResilienceMetadata(to: fallbackResult, duration: duration, usedFallback: true, primaryError: error)
                } catch let fallbackError {
                    // Fallback run() already returns AgentError due to typed throws
                    throw fallbackError
                }
            }
            // Error from run() is already AgentError due to typed throws
            throw error
        }
    }

    nonisolated public func stream(_ input: String, session: (any Session)? = nil, hooks: (any RunHooks)? = nil) -> AsyncThrowingStream<AgentEvent, Error> {
        // Forward streaming events from the base agent for richer observability
        let baseAgent = self.base
        let fallback = self.fallbackAgent
        let hasTimeout = self.timeoutDuration != nil
        let hasRetry = self.retryPolicy != nil
        let hasCircuitBreaker = self.circuitBreaker != nil

        return AsyncThrowingStream { continuation in
            let task = Task {
                continuation.yield(.started(input: input))

                do {
                    // Stream from the base agent, forwarding all intermediate events
                    var lastResult: AgentResult?

                    for try await event in baseAgent.stream(input, session: session, hooks: hooks) {
                        // Forward intermediate events
                        switch event {
                        case .completed(let result):
                            // Capture the result but don't yield yet - we'll add metadata
                            lastResult = result
                        case .failed:
                            // Don't forward failure yet - we may have fallback
                            break
                        default:
                            // Forward all other events (thinking, tool calls, iterations, etc.)
                            continuation.yield(event)
                        }
                    }

                    // If we got a result, add resilience metadata and complete
                    if let result = lastResult {
                        var metadata = result.metadata
                        metadata["resilience.used_fallback"] = .bool(false)
                        metadata["resilience.has_retry"] = .bool(hasRetry)
                        metadata["resilience.has_circuit_breaker"] = .bool(hasCircuitBreaker)
                        metadata["resilience.has_timeout"] = .bool(hasTimeout)

                        let enrichedResult = AgentResult(
                            output: result.output,
                            toolCalls: result.toolCalls,
                            toolResults: result.toolResults,
                            iterationCount: result.iterationCount,
                            duration: result.duration,
                            tokenUsage: result.tokenUsage,
                            metadata: metadata
                        )
                        continuation.yield(.completed(result: enrichedResult))
                        continuation.finish()
                    }

                } catch {
                    // Try fallback if available
                    if let fallbackAgent = fallback {
                        continuation.yield(.handoffStarted(from: "ResilientAgent", to: fallbackAgent.configuration.name, input: input))

                        do {
                            var fallbackResult: AgentResult?

                            for try await event in fallbackAgent.stream(input, session: session, hooks: hooks) {
                                switch event {
                                case .completed(let result):
                                    fallbackResult = result
                                default:
                                    continuation.yield(event)
                                }
                            }

                            if let result = fallbackResult {
                                var metadata = result.metadata
                                metadata["resilience.used_fallback"] = .bool(true)
                                metadata["resilience.primary_error"] = .string(error.localizedDescription)
                                metadata["resilience.has_retry"] = .bool(hasRetry)
                                metadata["resilience.has_circuit_breaker"] = .bool(hasCircuitBreaker)
                                metadata["resilience.has_timeout"] = .bool(hasTimeout)

                                let enrichedResult = AgentResult(
                                    output: result.output,
                                    toolCalls: result.toolCalls,
                                    toolResults: result.toolResults,
                                    iterationCount: result.iterationCount,
                                    duration: result.duration,
                                    tokenUsage: result.tokenUsage,
                                    metadata: metadata
                                )
                                continuation.yield(.completed(result: enrichedResult))
                                continuation.finish()
                            }
                        } catch let fallbackError {
                            let agentError = (fallbackError as? AgentError) ?? AgentError.internalError(reason: fallbackError.localizedDescription)
                            continuation.yield(.failed(error: agentError))
                            continuation.finish(throwing: fallbackError)
                        }
                    } else {
                        let agentError = (error as? AgentError) ?? AgentError.internalError(reason: error.localizedDescription)
                        continuation.yield(.failed(error: agentError))
                        continuation.finish(throwing: error)
                    }
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    public func cancel() async {
        isCancelled = true
        await base.cancel()
        if let fallback = fallbackAgent {
            await fallback.cancel()
        }
    }

    // MARK: Internal

    // MARK: - Internal Initialization for Chaining

    /// Internal initializer for chaining resilience patterns.
    init(
        wrapping resilient: ResilientAgent,
        retryPolicy: RetryPolicy? = nil,
        circuitBreaker: CircuitBreaker? = nil,
        fallbackAgent: (any Agent)? = nil,
        timeout: Duration? = nil
    ) {
        // Get base values synchronously from nonisolated properties
        let baseAgent = resilient.base
        base = baseAgent
        tools = resilient.tools
        instructions = resilient.instructions
        configuration = resilient.configuration
        baseMemory = resilient.baseMemory
        baseInferenceProvider = resilient.baseInferenceProvider
        baseTracer = resilient.baseTracer
        baseInputGuardrails = resilient.baseInputGuardrails
        baseOutputGuardrails = resilient.baseOutputGuardrails
        baseHandoffs = resilient.baseHandoffs

        // Merge resilience configurations
        self.retryPolicy = retryPolicy ?? resilient.retryPolicy
        self.circuitBreaker = circuitBreaker ?? resilient.circuitBreaker
        self.fallbackAgent = fallbackAgent ?? resilient.fallbackAgent
        timeoutDuration = timeout ?? resilient.timeoutDuration
    }

    // MARK: Private

    // MARK: - Stored Properties (nonisolated)

    nonisolated private let baseMemory: (any Memory)?
    nonisolated private let baseInferenceProvider: (any InferenceProvider)?
    nonisolated private let baseTracer: (any Tracer)?
    nonisolated private let baseInputGuardrails: [any InputGuardrail]
    nonisolated private let baseOutputGuardrails: [any OutputGuardrail]
    nonisolated private let baseHandoffs: [AnyHandoffConfiguration]

    // MARK: - Resilience Configuration

    nonisolated private let base: any Agent
    nonisolated private let retryPolicy: RetryPolicy?
    nonisolated private let circuitBreaker: CircuitBreaker?
    nonisolated private let fallbackAgent: (any Agent)?
    nonisolated private let timeoutDuration: Duration?

    // MARK: - Private State

    private var isCancelled = false

    // MARK: - Private Methods

    /// Executes the agent with timeout protection.
    private func executeWithTimeout(_ input: String, session: (any Session)?, hooks: (any RunHooks)?, timeout: Duration) async throws -> AgentResult {
        do {
            return try await withThrowingTaskGroup(of: AgentResult.self) { group in
                group.addTask {
                    try await self.executeWithResilience(input, session: session, hooks: hooks)
                }

                group.addTask {
                    try await Task.sleep(for: timeout)
                    throw AgentError.timeout(duration: timeout)
                }

                guard let result = try await group.next() else {
                    throw AgentError.timeout(duration: timeout)
                }

                group.cancelAll()
                return result
            }
        } catch let error as AgentError {
            throw error
        } catch {
            throw AgentError.internalError(reason: error.localizedDescription)
        }
    }

    /// Executes the agent with retry and circuit breaker protection.
    private func executeWithResilience(_ input: String, session: (any Session)?, hooks: (any RunHooks)?) async throws -> AgentResult {
        do {
            // Wrap execution in circuit breaker if configured
            if let breaker = circuitBreaker {
                return try await breaker.execute {
                    try await self.executeWithRetry(input, session: session, hooks: hooks)
                }
            } else {
                return try await executeWithRetry(input, session: session, hooks: hooks)
            }
        } catch let error as AgentError {
            throw error
        } catch {
            // Convert non-AgentError to AgentError
            throw AgentError.internalError(reason: error.localizedDescription)
        }
    }

    /// Executes the agent with retry protection.
    private func executeWithRetry(_ input: String, session: (any Session)?, hooks: (any RunHooks)?) async throws -> AgentResult {
        do {
            if let policy = retryPolicy {
                return try await policy.execute {
                    try await self.base.run(input, session: session, hooks: hooks)
                }
            } else {
                return try await base.run(input, session: session, hooks: hooks)
            }
        } catch let error as AgentError {
            throw error
        } catch {
            // Convert non-AgentError to AgentError
            throw AgentError.internalError(reason: error.localizedDescription)
        }
    }

    /// Adds resilience metadata to the result.
    private func addResilienceMetadata(
        to result: AgentResult,
        duration _: ContinuousClock.Instant.Duration,
        usedFallback: Bool,
        primaryError: Error? = nil
    ) -> AgentResult {
        var metadata = result.metadata
        metadata["resilience.used_fallback"] = .bool(usedFallback)
        metadata["resilience.has_retry"] = .bool(retryPolicy != nil)
        metadata["resilience.has_circuit_breaker"] = .bool(circuitBreaker != nil)
        metadata["resilience.has_timeout"] = .bool(timeoutDuration != nil)

        if let error = primaryError {
            metadata["resilience.primary_error"] = .string(error.localizedDescription)
        }

        if let policy = retryPolicy {
            metadata["resilience.max_retry_attempts"] = .int(policy.maxAttempts)
        }

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

// MARK: - Agent Resilience Extensions

public extension Agent {
    /// Wraps this agent with retry behavior.
    ///
    /// - Parameter policy: The retry policy to apply.
    /// - Returns: A resilient agent with retry enabled.
    ///
    /// Example:
    /// ```swift
    /// let resilient = myAgent.withRetry(.exponentialBackoff(maxAttempts: 3))
    /// ```
    func withRetry(_ policy: RetryPolicy) -> ResilientAgent {
        if let resilient = self as? ResilientAgent {
            return resilient.withRetry(policy)
        }
        return ResilientAgent(base: self, retryPolicy: policy)
    }

    /// Wraps this agent with circuit breaker protection.
    ///
    /// - Parameters:
    ///   - threshold: Number of consecutive failures before opening the circuit.
    ///   - resetTimeout: Time to wait before attempting recovery.
    /// - Returns: A resilient agent with circuit breaker enabled.
    ///
    /// Example:
    /// ```swift
    /// let resilient = myAgent.withCircuitBreaker(threshold: 5, resetTimeout: .seconds(60))
    /// ```
    func withCircuitBreaker(threshold: Int, resetTimeout: Duration) -> ResilientAgent {
        if let resilient = self as? ResilientAgent {
            return resilient.withCircuitBreaker(threshold: threshold, resetTimeout: resetTimeout)
        }
        let breaker = CircuitBreaker(
            name: "agent-\(UUID().uuidString)",
            failureThreshold: threshold,
            resetTimeout: resetTimeout.timeInterval
        )
        return ResilientAgent(base: self, circuitBreaker: breaker)
    }

    /// Wraps this agent with a fallback agent.
    ///
    /// - Parameter fallback: The agent to use when the primary fails.
    /// - Returns: A resilient agent with fallback enabled.
    ///
    /// Example:
    /// ```swift
    /// let resilient = primaryAgent.withFallback(backupAgent)
    /// ```
    func withFallback(_ fallback: any Agent) -> ResilientAgent {
        if let resilient = self as? ResilientAgent {
            return resilient.withFallback(fallback)
        }
        return ResilientAgent(base: self, fallbackAgent: fallback)
    }

    /// Wraps this agent with timeout protection.
    ///
    /// - Parameter timeout: Maximum execution time.
    /// - Returns: A resilient agent with timeout enabled.
    ///
    /// Example:
    /// ```swift
    /// let resilient = myAgent.withTimeout(.seconds(30))
    /// ```
    func withTimeout(_ timeout: Duration) -> ResilientAgent {
        if let resilient = self as? ResilientAgent {
            return resilient.withTimeout(timeout)
        }
        return ResilientAgent(base: self, timeout: timeout)
    }
}

// MARK: - RetryPolicy Fluent Extensions

public extension RetryPolicy {
    /// Creates a retry policy with fixed delay between attempts.
    ///
    /// - Parameters:
    ///   - maxAttempts: Maximum number of retry attempts.
    ///   - delay: Fixed delay between retries.
    /// - Returns: A configured retry policy.
    ///
    /// Example:
    /// ```swift
    /// let policy = RetryPolicy.fixed(maxAttempts: 3, delay: .seconds(1))
    /// ```
    static func fixed(maxAttempts: Int, delay: Duration) -> RetryPolicy {
        RetryPolicy(
            maxAttempts: maxAttempts,
            backoff: .fixed(delay: delay.timeInterval)
        )
    }

    /// Creates a retry policy with exponential backoff.
    ///
    /// - Parameters:
    ///   - maxAttempts: Maximum number of retry attempts.
    ///   - baseDelay: Initial delay duration.
    ///   - maxDelay: Maximum delay between retries.
    ///   - multiplier: Factor to multiply delay by each attempt.
    ///   - jitter: Random jitter factor (0.0 to 1.0) to add variance.
    /// - Returns: A configured retry policy.
    ///
    /// Example:
    /// ```swift
    /// let policy = RetryPolicy.exponentialBackoff(
    ///     maxAttempts: 5,
    ///     baseDelay: .seconds(1),
    ///     maxDelay: .seconds(60),
    ///     multiplier: 2.0
    /// )
    /// ```
    static func exponentialBackoff(
        maxAttempts: Int,
        baseDelay: Duration = .seconds(1),
        maxDelay: Duration = .seconds(60),
        multiplier: Double = 2.0,
        jitter: Double = 0.0
    ) -> RetryPolicy {
        let backoff: BackoffStrategy = if jitter > 0 {
            .exponentialWithJitter(
                base: baseDelay.timeInterval,
                multiplier: multiplier,
                maxDelay: maxDelay.timeInterval
            )
        } else {
            .exponential(
                base: baseDelay.timeInterval,
                multiplier: multiplier,
                maxDelay: maxDelay.timeInterval
            )
        }

        return RetryPolicy(maxAttempts: maxAttempts, backoff: backoff)
    }

    /// Creates a retry policy with decorrelated jitter for better distribution.
    ///
    /// - Parameters:
    ///   - maxAttempts: Maximum number of retry attempts.
    ///   - baseDelay: Base delay duration.
    ///   - maxDelay: Maximum delay between retries.
    /// - Returns: A configured retry policy.
    ///
    /// Example:
    /// ```swift
    /// let policy = RetryPolicy.decorrelatedJitter(
    ///     maxAttempts: 5,
    ///     baseDelay: .milliseconds(100),
    ///     maxDelay: .seconds(10)
    /// )
    /// ```
    static func decorrelatedJitter(
        maxAttempts: Int,
        baseDelay: Duration = .milliseconds(100),
        maxDelay: Duration = .seconds(10)
    ) -> RetryPolicy {
        RetryPolicy(
            maxAttempts: maxAttempts,
            backoff: .decorrelatedJitter(base: baseDelay.timeInterval, maxDelay: maxDelay.timeInterval)
        )
    }

    /// Creates a retry policy with linear backoff.
    ///
    /// - Parameters:
    ///   - maxAttempts: Maximum number of retry attempts.
    ///   - initialDelay: Initial delay duration.
    ///   - increment: Amount to add to delay each attempt.
    ///   - maxDelay: Maximum delay between retries.
    /// - Returns: A configured retry policy.
    ///
    /// Example:
    /// ```swift
    /// let policy = RetryPolicy.linear(
    ///     maxAttempts: 5,
    ///     initialDelay: .seconds(1),
    ///     increment: .seconds(2),
    ///     maxDelay: .seconds(30)
    /// )
    /// ```
    static func linear(
        maxAttempts: Int,
        initialDelay: Duration = .seconds(1),
        increment: Duration = .seconds(1),
        maxDelay: Duration = .seconds(30)
    ) -> RetryPolicy {
        RetryPolicy(
            maxAttempts: maxAttempts,
            backoff: .linear(
                initial: initialDelay.timeInterval,
                increment: increment.timeInterval,
                maxDelay: maxDelay.timeInterval
            )
        )
    }

    /// Creates a retry policy with no delay between attempts.
    ///
    /// - Parameter maxAttempts: Maximum number of retry attempts.
    /// - Returns: A configured retry policy.
    ///
    /// Example:
    /// ```swift
    /// let policy = RetryPolicy.immediate(maxAttempts: 3)
    /// ```
    static func immediate(maxAttempts: Int) -> RetryPolicy {
        RetryPolicy(maxAttempts: maxAttempts, backoff: .immediate)
    }
}
