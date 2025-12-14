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
    // MARK: - Agent Protocol (nonisolated)

    public nonisolated let tools: [any Tool]
    public nonisolated let instructions: String
    public nonisolated let configuration: AgentConfiguration
    public nonisolated var memory: (any AgentMemory)? { baseMemory }
    public nonisolated var inferenceProvider: (any InferenceProvider)? { baseInferenceProvider }

    // MARK: - Stored Properties (nonisolated)

    private nonisolated let baseMemory: (any AgentMemory)?
    private nonisolated let baseInferenceProvider: (any InferenceProvider)?

    // MARK: - Resilience Configuration

    private nonisolated let base: any Agent
    private nonisolated let retryPolicy: RetryPolicy?
    private nonisolated let circuitBreaker: CircuitBreaker?
    private nonisolated let fallbackAgent: (any Agent)?
    private nonisolated let timeoutDuration: Duration?

    // MARK: - Private State

    private var isCancelled = false

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
        self.tools = base.tools
        self.instructions = base.instructions
        self.configuration = base.configuration
        self.baseMemory = base.memory
        self.baseInferenceProvider = base.inferenceProvider
        self.retryPolicy = retryPolicy
        self.circuitBreaker = circuitBreaker
        self.fallbackAgent = fallbackAgent
        self.timeoutDuration = timeout
    }

    // MARK: - Internal Initialization for Chaining

    /// Internal initializer for chaining resilience patterns.
    nonisolated init(
        wrapping resilient: ResilientAgent,
        retryPolicy: RetryPolicy? = nil,
        circuitBreaker: CircuitBreaker? = nil,
        fallbackAgent: (any Agent)? = nil,
        timeout: Duration? = nil
    ) {
        // Get base values synchronously from nonisolated properties
        let baseAgent = resilient.base
        self.base = baseAgent
        self.tools = resilient.tools
        self.instructions = resilient.instructions
        self.configuration = resilient.configuration
        self.baseMemory = resilient.baseMemory
        self.baseInferenceProvider = resilient.baseInferenceProvider

        // Merge resilience configurations
        self.retryPolicy = retryPolicy ?? resilient.retryPolicy
        self.circuitBreaker = circuitBreaker ?? resilient.circuitBreaker
        self.fallbackAgent = fallbackAgent ?? resilient.fallbackAgent
        self.timeoutDuration = timeout ?? resilient.timeoutDuration
    }

    // MARK: - Fluent Configuration

    /// Returns a new resilient agent with retry behavior.
    ///
    /// - Parameter policy: The retry policy to apply.
    /// - Returns: A new resilient agent with retry enabled.
    public nonisolated func withRetry(_ policy: RetryPolicy) -> ResilientAgent {
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
    public nonisolated func withCircuitBreaker(threshold: Int, resetTimeout: Duration) -> ResilientAgent {
        let breaker = CircuitBreaker(
            name: "agent-\(ObjectIdentifier(base))",
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
    public nonisolated func withFallback(_ fallback: any Agent) -> ResilientAgent {
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
    public nonisolated func withTimeout(_ duration: Duration) -> ResilientAgent {
        ResilientAgent(
            base: base,
            retryPolicy: retryPolicy,
            circuitBreaker: circuitBreaker,
            fallbackAgent: fallbackAgent,
            timeout: duration
        )
    }

    // MARK: - Agent Protocol

    public func run(_ input: String) async throws -> AgentResult {
        if isCancelled {
            throw AgentError.cancelled
        }

        let startTime = ContinuousClock.now

        do {
            // Apply timeout if configured
            let result: AgentResult
            if let timeout = timeoutDuration {
                result = try await executeWithTimeout(input, timeout: timeout)
            } else {
                result = try await executeWithResilience(input)
            }

            // Add resilience metadata
            let duration = ContinuousClock.now - startTime
            return addResilienceMetadata(to: result, duration: duration, usedFallback: false)

        } catch {
            // Try fallback if available
            if let fallback = fallbackAgent {
                do {
                    let fallbackResult = try await fallback.run(input)
                    let duration = ContinuousClock.now - startTime
                    return addResilienceMetadata(to: fallbackResult, duration: duration, usedFallback: true, primaryError: error)
                } catch {
                    throw error
                }
            }
            throw error
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
        await base.cancel()
        if let fallback = fallbackAgent {
            await fallback.cancel()
        }
    }

    // MARK: - Private Methods

    /// Executes the agent with timeout protection.
    private func executeWithTimeout(_ input: String, timeout: Duration) async throws -> AgentResult {
        try await withThrowingTaskGroup(of: AgentResult.self) { group in
            group.addTask {
                try await self.executeWithResilience(input)
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
    }

    /// Executes the agent with retry and circuit breaker protection.
    private func executeWithResilience(_ input: String) async throws -> AgentResult {
        // Wrap execution in circuit breaker if configured
        if let breaker = circuitBreaker {
            return try await breaker.execute {
                try await self.executeWithRetry(input)
            }
        } else {
            return try await executeWithRetry(input)
        }
    }

    /// Executes the agent with retry protection.
    private func executeWithRetry(_ input: String) async throws -> AgentResult {
        if let policy = retryPolicy {
            return try await policy.execute {
                try await self.base.run(input)
            }
        } else {
            return try await base.run(input)
        }
    }

    /// Adds resilience metadata to the result.
    private func addResilienceMetadata(
        to result: AgentResult,
        duration: ContinuousClock.Instant.Duration,
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

extension Agent {
    /// Wraps this agent with retry behavior.
    ///
    /// - Parameter policy: The retry policy to apply.
    /// - Returns: A resilient agent with retry enabled.
    ///
    /// Example:
    /// ```swift
    /// let resilient = myAgent.withRetry(.exponentialBackoff(maxAttempts: 3))
    /// ```
    public func withRetry(_ policy: RetryPolicy) -> ResilientAgent {
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
    public func withCircuitBreaker(threshold: Int, resetTimeout: Duration) -> ResilientAgent {
        if let resilient = self as? ResilientAgent {
            return resilient.withCircuitBreaker(threshold: threshold, resetTimeout: resetTimeout)
        }
        let breaker = CircuitBreaker(
            name: "agent-\(ObjectIdentifier(self))",
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
    public func withFallback(_ fallback: any Agent) -> ResilientAgent {
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
    public func withTimeout(_ timeout: Duration) -> ResilientAgent {
        if let resilient = self as? ResilientAgent {
            return resilient.withTimeout(timeout)
        }
        return ResilientAgent(base: self, timeout: timeout)
    }
}

// MARK: - RetryPolicy Fluent Extensions

extension RetryPolicy {
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
    public static func fixed(maxAttempts: Int, delay: Duration) -> RetryPolicy {
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
    public static func exponentialBackoff(
        maxAttempts: Int,
        baseDelay: Duration = .seconds(1),
        maxDelay: Duration = .seconds(60),
        multiplier: Double = 2.0,
        jitter: Double = 0.0
    ) -> RetryPolicy {
        let backoff: BackoffStrategy
        if jitter > 0 {
            backoff = .exponentialWithJitter(
                base: baseDelay.timeInterval,
                multiplier: multiplier,
                maxDelay: maxDelay.timeInterval
            )
        } else {
            backoff = .exponential(
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
    public static func decorrelatedJitter(
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
    public static func linear(
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
    public static func immediate(maxAttempts: Int) -> RetryPolicy {
        RetryPolicy(maxAttempts: maxAttempts, backoff: .immediate)
    }
}

// MARK: - Duration Extension

extension Duration {
    /// Converts Duration to TimeInterval (seconds).
    var timeInterval: TimeInterval {
        let (seconds, attoseconds) = components
        return Double(seconds) + Double(attoseconds) / 1e18
    }
}
