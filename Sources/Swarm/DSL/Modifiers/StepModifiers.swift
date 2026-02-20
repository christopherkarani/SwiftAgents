// StepModifiers.swift
// Swarm Framework
//
// SwiftUI-style StepModifier protocol and built-in modifiers for OrchestrationStep.

import Foundation
import Logging

// MARK: - StepModifier Protocol

/// A modifier that wraps an OrchestrationStep with additional behavior.
///
/// StepModifiers follow the SwiftUI modifier pattern, allowing you to compose
/// cross-cutting concerns like retry, timeout, logging, and naming onto any step.
///
/// Example:
/// ```swift
/// let step = myAgent
///     .retry(maxAttempts: 3)
///     .timeout(.seconds(30))
///     .logged(label: "main-agent")
/// ```
public protocol StepModifier: Sendable {
    /// Executes the modified behavior around the wrapped step.
    /// - Parameters:
    ///   - content: The original step being modified.
    ///   - input: The input string.
    ///   - context: The orchestration context.
    /// - Returns: The result of executing the modified step.
    func body(content: OrchestrationStep, input: String, context: OrchestrationStepContext) async throws -> AgentResult
}

// MARK: - ModifiedStep

/// Wrapper that applies a StepModifier to any OrchestrationStep.
///
/// You typically don't create this directly; use the modifier convenience methods
/// on `OrchestrationStep` instead.
public struct ModifiedStep: OrchestrationStep, Sendable {
    /// The step being modified.
    public let content: OrchestrationStep

    /// The modifier applied to the step.
    public let modifier: any StepModifier

    /// Creates a new modified step.
    /// - Parameters:
    ///   - content: The step to modify.
    ///   - modifier: The modifier to apply.
    public init(content: OrchestrationStep, modifier: any StepModifier) {
        self.content = content
        self.modifier = modifier
    }

    // NOTE: Must implement execute(_:context:) directly to break the
    // bidirectional default cycle in OrchestrationStep.
    public func execute(_ input: String, context: OrchestrationStepContext) async throws -> AgentResult {
        try await modifier.body(content: content, input: input, context: context)
    }
}

// MARK: - OrchestrationStep Modifier Extensions

public extension OrchestrationStep {
    /// Applies a custom StepModifier to this step.
    /// - Parameter modifier: The modifier to apply.
    /// - Returns: A new step with the modifier applied.
    func modifier(_ modifier: any StepModifier) -> ModifiedStep {
        ModifiedStep(content: self, modifier: modifier)
    }

    /// Retries this step on failure with configurable backoff.
    /// - Parameters:
    ///   - maxAttempts: Maximum number of attempts (including the first).
    ///   - delay: Initial delay between retries. Default: 1 second.
    ///   - backoff: Multiplier applied to delay after each retry. Default: 2.0.
    /// - Returns: A modified step that retries on failure.
    func retry(maxAttempts: Int, delay: Duration = .seconds(1), backoff: Double = 2.0) -> ModifiedStep {
        modifier(RetryModifier(maxAttempts: maxAttempts, initialDelay: delay, backoffMultiplier: backoff))
    }

    /// Applies a hard timeout deadline to this step.
    /// - Parameter duration: The maximum time allowed for execution.
    /// - Returns: A modified step that throws on timeout.
    func timeout(_ duration: Duration) -> ModifiedStep {
        modifier(TimeoutModifier(deadline: duration))
    }

    /// Adds a name to this step's metadata for tracing and debugging.
    /// - Parameter name: The step name.
    /// - Returns: A modified step with name metadata.
    func named(_ name: String) -> ModifiedStep {
        modifier(NamedModifier(name: name))
    }

    /// Logs step input and output using swift-log.
    /// - Parameter label: Optional label for the log messages. Default: "OrchestrationStep".
    /// - Returns: A modified step that logs execution.
    func logged(label: String? = nil) -> ModifiedStep {
        modifier(LoggingModifier(label: label))
    }
}

// MARK: - RetryModifier

/// Retries a step on failure with configurable exponential backoff.
///
/// On success, adds `retry.attempts` and `retry.succeeded` metadata.
/// On exhaustion, throws the last error encountered.
///
/// Example:
/// ```swift
/// myStep.retry(maxAttempts: 3, delay: .seconds(1), backoff: 2.0)
/// ```
public struct RetryModifier: StepModifier {
    /// Maximum number of attempts (including the initial attempt).
    public let maxAttempts: Int

    /// Delay before the first retry.
    public let initialDelay: Duration

    /// Multiplier applied to the delay after each failed attempt.
    public let backoffMultiplier: Double

    public init(maxAttempts: Int, initialDelay: Duration = .seconds(1), backoffMultiplier: Double = 2.0) {
        if maxAttempts < 1 {
            Log.orchestration.warning("RetryModifier: maxAttempts \(maxAttempts) must be >= 1; using 1")
        }
        if !backoffMultiplier.isFinite || backoffMultiplier <= 0 {
            Log.orchestration.warning("RetryModifier: backoffMultiplier \(backoffMultiplier) is invalid; using 1.0")
        }
        self.maxAttempts = max(1, maxAttempts)
        self.initialDelay = initialDelay
        self.backoffMultiplier = (!backoffMultiplier.isFinite || backoffMultiplier <= 0) ? 1.0 : backoffMultiplier
    }

    public func body(content: OrchestrationStep, input: String, context: OrchestrationStepContext) async throws -> AgentResult {
        var lastError: (any Error)?
        var currentDelay = initialDelay

        for attempt in 1 ... maxAttempts {
            do {
                let result = try await content.execute(input, context: context)
                var metadata = result.metadata
                metadata["retry.attempts"] = .int(attempt)
                metadata["retry.succeeded"] = .bool(true)
                return AgentResult(
                    output: result.output,
                    toolCalls: result.toolCalls,
                    toolResults: result.toolResults,
                    iterationCount: result.iterationCount,
                    duration: result.duration,
                    tokenUsage: result.tokenUsage,
                    metadata: metadata
                )
            } catch {
                lastError = error
                if attempt < maxAttempts {
                    try await Task.sleep(for: currentDelay)
                    let seconds = Double(currentDelay.components.seconds)
                        + Double(currentDelay.components.attoseconds) / 1e18
                    let newSeconds = seconds * backoffMultiplier
                    currentDelay = .nanoseconds(Int64(newSeconds * 1e9))
                }
            }
        }

        // maxAttempts is always >= 1 (clamped in init), so the loop above
        // always executes at least once. If it exits here, lastError is guaranteed
        // to be set. The nil branch below is a logic-bug guard, not a runtime path.
        guard let error = lastError else {
            assertionFailure("RetryModifier exhausted attempts without capturing an error — this is a logic bug")
            throw AgentError.internalError(reason: "Retry exhausted")
        }
        throw error
    }
}

// MARK: - TimeoutModifier

/// Enforces a hard deadline on step execution.
///
/// Uses a task group to race the step against a sleep. If the sleep wins,
/// the step's task is cancelled and `AgentError.timeout` is thrown.
///
/// Example:
/// ```swift
/// myStep.timeout(.seconds(30))
/// ```
public struct TimeoutModifier: StepModifier {
    /// The maximum duration allowed for the step.
    public let deadline: Duration

    public init(deadline: Duration) {
        self.deadline = deadline
    }

    public func body(content: OrchestrationStep, input: String, context: OrchestrationStepContext) async throws -> AgentResult {
        try await withThrowingTaskGroup(of: AgentResult?.self) { group in
            group.addTask {
                try await content.execute(input, context: context)
            }

            group.addTask {
                try await Task.sleep(for: deadline)
                return nil
            }

            guard let first = try await group.next() else {
                throw AgentError.timeout(duration: deadline)
            }

            if let result = first {
                group.cancelAll()
                return result
            } else {
                // Sleep finished first -- the step timed out.
                group.cancelAll()
                throw AgentError.timeout(duration: deadline)
            }
        }
    }
}

// MARK: - NamedModifier

/// Adds a name to the step's result metadata for tracing and debugging.
///
/// Example:
/// ```swift
/// myStep.named("preprocess")
/// ```
public struct NamedModifier: StepModifier {
    /// The name to attach.
    public let name: String

    public init(name: String) {
        self.name = name
    }

    public func body(content: OrchestrationStep, input: String, context: OrchestrationStepContext) async throws -> AgentResult {
        let result = try await content.execute(input, context: context)
        var metadata = result.metadata
        metadata["step.name"] = .string(name)
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

// MARK: - LoggingModifier

/// Logs step input and output using swift-log and records them in metadata.
///
/// Example:
/// ```swift
/// myStep.logged(label: "analysis-step")
/// ```
public struct LoggingModifier: StepModifier {
    /// Label for log messages. Defaults to "OrchestrationStep".
    public let label: String

    public init(label: String? = nil) {
        self.label = label ?? "OrchestrationStep"
    }

    public func body(content: OrchestrationStep, input: String, context: OrchestrationStepContext) async throws -> AgentResult {
        Log.orchestration.info("[\(label)] executing with input: \(input.prefix(200))")

        let result = try await content.execute(input, context: context)

        Log.orchestration.info("[\(label)] completed with output: \(result.output.prefix(200))")

        var metadata = result.metadata
        metadata["logging.label"] = .string(label)
        metadata["logging.input"] = .string(input)
        metadata["logging.output"] = .string(result.output)
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
