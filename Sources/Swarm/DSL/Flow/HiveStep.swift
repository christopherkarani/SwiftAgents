// HiveStep.swift
// Swarm Framework
//
// Escape hatch for injecting raw Hive node closures into Swarm orchestrations,
// and an Interrupt step for workflow interruption.

import Foundation

// MARK: - Interrupt

/// A step that interrupts the workflow by throwing `OrchestrationError.workflowInterrupted`.
///
/// `Interrupt` halts workflow execution at the point where it appears. The payload
/// builder transforms the current input into the interruption reason.
///
/// Example:
/// ```swift
/// Sequential {
///     preprocessAgent
///     Interrupt { "Human review needed: \($0)" }
///     // This step is never reached
///     postprocessAgent
/// }
/// ```
public struct Interrupt: OrchestrationStep, Sendable {
    /// Transforms the current input into the interruption payload.
    public let payloadBuilder: @Sendable (String) -> String

    /// Creates a new interrupt step.
    /// - Parameter payloadBuilder: A closure that transforms the current input into
    ///   the interruption reason. Defaults to identity (passes input through as-is).
    public init(_ payloadBuilder: @escaping @Sendable (String) -> String = { $0 }) {
        self.payloadBuilder = payloadBuilder
    }

    public func execute(_ input: String, context: OrchestrationStepContext) async throws -> AgentResult {
        throw OrchestrationError.workflowInterrupted(reason: payloadBuilder(input))
    }
}

// MARK: - HiveStep (Hive Runtime)

#if canImport(HiveCore)

import HiveCore

/// An escape hatch that injects a raw Hive node closure into a Swarm orchestration.
///
/// `HiveStep`'s `nodeFactory` is emitted directly as a Hive graph node during compilation,
/// giving full access to `HiveNodeInput` and `HiveNodeOutput`.
///
/// Example:
/// ```swift
/// Orchestration {
///     Sequential {
///         preprocessAgent
///         HiveStep { input in
///             let currentInput = try input.store.get(OrchestrationHiveEngine.Schema.currentInputKey)
///             // Custom Hive-level processing...
///             return HiveNodeOutput(writes: [
///                 AnyHiveWrite(OrchestrationHiveEngine.Schema.currentInputKey, currentInput)
///             ])
///         }
///         postprocessAgent
///     }
/// }
/// ```
public struct HiveStep: OrchestrationStep, Sendable {
    /// The raw Hive node closure to inject into the graph.
    let nodeFactory: @Sendable (HiveNodeInput<OrchestrationHiveEngine.Schema>) async throws
        -> HiveNodeOutput<OrchestrationHiveEngine.Schema>

    /// Creates a new HiveStep with a raw Hive node closure.
    /// - Parameter node: A closure that receives `HiveNodeInput` and returns `HiveNodeOutput`.
    init(
        _ node: @escaping @Sendable (HiveNodeInput<OrchestrationHiveEngine.Schema>) async throws
            -> HiveNodeOutput<OrchestrationHiveEngine.Schema>
    ) {
        nodeFactory = node
    }

    /// Direct execution fallback.
    ///
    /// When HiveStep is executed directly (not compiled into a Hive graph),
    /// it acts as a passthrough, preserving the input unchanged.
    public func execute(_ input: String, context: OrchestrationStepContext) async throws -> AgentResult {
        AgentResult(output: input, metadata: ["hive_step.direct": .bool(true)])
    }
}

#else

@available(*, unavailable, message: "HiveStep requires HiveCore.")
public struct HiveStep: Sendable {}

#endif
