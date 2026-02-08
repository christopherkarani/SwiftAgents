// ToolExecutionEngine.swift
// Swarm Framework
//
// Shared tool execution implementation used across agents.

import Foundation

/// Centralized tool-call execution path.
///
/// This standardizes:
/// - ToolCall + ToolResult creation
/// - AgentResult.Builder recording
/// - RunHooks emission
/// - ToolRegistry execution wiring
public struct ToolExecutionEngine: Sendable {
    public init() {}

    public struct Outcome: Sendable {
        public let call: ToolCall
        public let result: ToolResult
    }

    public func execute(
        toolName: String,
        arguments: [String: SendableValue],
        providerCallId: String? = nil,
        registry: ToolRegistry,
        agent: any AgentRuntime,
        context: AgentContext?,
        resultBuilder: AgentResult.Builder,
        hooks: (any RunHooks)?,
        tracing: TracingHelper?,
        stopOnToolError: Bool
    ) async throws -> Outcome {
        let call = ToolCall(providerCallId: providerCallId, toolName: toolName, arguments: arguments)
        _ = resultBuilder.addToolCall(call)

        await hooks?.onToolStart(context: context, agent: agent, call: call)

        let spanId: UUID? = if let tracing { await tracing.traceToolCall(name: toolName, arguments: arguments) } else { nil }

        let startTime = ContinuousClock.now
        do {
            let output = try await registry.execute(
                toolNamed: toolName,
                arguments: arguments,
                agent: agent,
                context: context,
                hooks: hooks
            )

            let duration = ContinuousClock.now - startTime
            let result = ToolResult.success(callId: call.id, output: output, duration: duration)
            _ = resultBuilder.addToolResult(result)

            if let tracing, let spanId {
                await tracing.traceToolResult(spanId: spanId, name: toolName, result: output.description, duration: duration)
            }

            await hooks?.onToolEnd(context: context, agent: agent, result: result)

            return Outcome(call: call, result: result)
        } catch {
            let duration = ContinuousClock.now - startTime
            let errorMessage = (error as? AgentError)?.localizedDescription ?? error.localizedDescription

            let result = ToolResult.failure(callId: call.id, error: errorMessage, duration: duration)
            _ = resultBuilder.addToolResult(result)

            if let tracing, let spanId {
                await tracing.traceToolError(spanId: spanId, name: toolName, error: error)
            }

            await hooks?.onToolEnd(context: context, agent: agent, result: result)

            if stopOnToolError {
                throw AgentError.toolExecutionFailed(toolName: toolName, underlyingError: errorMessage)
            }

            return Outcome(call: call, result: result)
        }
    }
}
