// ToolCallGoal.swift
// Swarm Framework
//
// Common representation of a model-requested tool call (a "tool goal").

import Foundation

/// A lightweight, provider-agnostic description of a tool invocation request.
///
/// This represents the *intent* to call a tool (name + arguments) and optionally carries a
/// provider-assigned call ID for correlation in native tool calling flows.
public protocol ToolCallGoal: Sendable {
    /// Provider-assigned tool call identifier, if available.
    var providerCallId: String? { get }

    /// The name of the tool to invoke.
    var toolName: String { get }

    /// The arguments to pass to the tool.
    var arguments: [String: SendableValue] { get }
}

public extension ToolCallGoal {
    var providerCallId: String? { nil }
}

// MARK: - Conformances

extension ToolCall: ToolCallGoal {}

extension InferenceResponse.ParsedToolCall: ToolCallGoal {
    public var providerCallId: String? { id }
    public var toolName: String { name }
}

// MARK: - ToolExecutionEngine Convenience

public extension ToolExecutionEngine {
    /// Executes a tool call goal through the shared tool execution path.
    func execute(
        _ goal: some ToolCallGoal,
        registry: ToolRegistry,
        agent: any AgentRuntime,
        context: AgentContext?,
        resultBuilder: AgentResult.Builder,
        hooks: (any RunHooks)?,
        tracing: TracingHelper?,
        stopOnToolError: Bool
    ) async throws -> Outcome {
        try await execute(
            toolName: goal.toolName,
            arguments: goal.arguments,
            providerCallId: goal.providerCallId,
            registry: registry,
            agent: agent,
            context: context,
            resultBuilder: resultBuilder,
            hooks: hooks,
            tracing: tracing,
            stopOnToolError: stopOnToolError
        )
    }
}
