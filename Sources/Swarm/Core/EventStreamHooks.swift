// EventStreamHooks.swift
// Swarm Framework
//
// Internal hook implementation that pipes events to a stream continuation.

import Foundation

/// Internal hook implementation that pipes agent events to an `AsyncThrowingStream` continuation.
///
/// This serves as the bridge between the internal hook-based observation system
/// and the external stream-based observation API.
internal struct EventStreamHooks: RunHooks {
    /// The continuation to yield events to.
    private let continuation: AsyncThrowingStream<AgentEvent, Error>.Continuation
    private let toolCallStore = ToolCallStore()

    /// Creates a new event stream hook.
    /// - Parameter continuation: The continuation to yield events to.
    init(continuation: AsyncThrowingStream<AgentEvent, Error>.Continuation) {
        self.continuation = continuation
    }

    // MARK: - RunHooks Implementation

    func onAgentStart(context _: AgentContext?, agent _: any AgentRuntime, input: String) async {
        continuation.yield(.started(input: input))
    }

    func onAgentEnd(context _: AgentContext?, agent _: any AgentRuntime, result: AgentResult) async {
        continuation.yield(.completed(result: result))
    }

    func onError(context _: AgentContext?, agent _: any AgentRuntime, error: Error) async {
        if let agentError = error as? AgentError {
            continuation.yield(.failed(error: agentError))
        } else {
            continuation.yield(.failed(error: .internalError(reason: error.localizedDescription)))
        }
    }

    func onToolStart(context _: AgentContext?, agent _: any AgentRuntime, call: ToolCall) async {
        await toolCallStore.record(call)
        continuation.yield(.toolCallStarted(call: call))
    }

    func onToolCallPartial(context _: AgentContext?, agent _: any AgentRuntime, update: PartialToolCallUpdate) async {
        continuation.yield(.toolCallPartial(update: update))
    }

    func onToolEnd(context _: AgentContext?, agent _: any AgentRuntime, result: ToolResult) async {
        let call = await toolCallStore.take(id: result.callId)
            ?? ToolCall(id: result.callId, toolName: "unknown", arguments: [:])
        continuation.yield(.toolCallCompleted(call: call, result: result))

        if !result.isSuccess {
            let errorMessage = result.errorMessage ?? "Unknown error"
            continuation.yield(.toolCallFailed(
                call: call,
                error: .toolExecutionFailed(toolName: call.toolName, underlyingError: errorMessage)
            ))
        }
    }

    func onThinking(context _: AgentContext?, agent _: any AgentRuntime, thought: String) async {
        continuation.yield(.thinking(thought: thought))
    }

    func onThinkingPartial(context _: AgentContext?, agent _: any AgentRuntime, partialThought: String) async {
        continuation.yield(.thinkingPartial(partialThought: partialThought))
    }

    func onOutputToken(context _: AgentContext?, agent _: any AgentRuntime, token: String) async {
        continuation.yield(.outputToken(token: token))
    }

    func onIterationStart(context _: AgentContext?, agent _: any AgentRuntime, number: Int) async {
        continuation.yield(.iterationStarted(number: number))
    }

    func onIterationEnd(context _: AgentContext?, agent _: any AgentRuntime, number: Int) async {
        continuation.yield(.iterationCompleted(number: number))
    }
    
    func onGuardrailTriggered(context: AgentContext?, guardrailName: String, guardrailType: GuardrailType, result: GuardrailResult) async {
        continuation.yield(.guardrailTriggered(name: guardrailName, type: guardrailType, message: result.message))
    }

    func onHandoff(context: AgentContext?, fromAgent: any AgentRuntime, toAgent: any AgentRuntime) async {
        let fromName = fromAgent.configuration.name.isEmpty ? String(describing: type(of: fromAgent)) : fromAgent.configuration.name
        let toName = toAgent.configuration.name.isEmpty ? String(describing: type(of: toAgent)) : toAgent.configuration.name
        
        continuation.yield(.handoffRequested(fromAgent: fromName, toAgent: toName, reason: nil))
    }

    func onLLMStart(context: AgentContext?, agent: any AgentRuntime, systemPrompt: String?, inputMessages: [MemoryMessage]) async {
        // Calculate prompt tokens if possible, otherwise nil
        continuation.yield(.llmStarted(model: nil, promptTokens: nil))
    }

    func onLLMEnd(context: AgentContext?, agent: any AgentRuntime, response: String, usage: InferenceResponse.TokenUsage?) async {
        continuation.yield(.llmCompleted(
            model: nil, 
            promptTokens: usage?.inputTokens, 
            completionTokens: usage?.outputTokens, 
            duration: 0 // We don't have duration here easily without tracking
        ))
    }
}

// MARK: - ToolCallStore

private actor ToolCallStore {
    private var calls: [UUID: ToolCall] = [:]

    func record(_ call: ToolCall) {
        calls[call.id] = call
    }

    func take(id: UUID) -> ToolCall? {
        defer { calls.removeValue(forKey: id) }
        return calls[id]
    }
}
