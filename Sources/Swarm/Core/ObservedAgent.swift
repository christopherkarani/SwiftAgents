import Foundation

/// Internal wrapper that attaches an observer to an existing agent runtime.
struct ObservedAgent<Wrapped: AgentRuntime>: AgentRuntime {
    let wrapped: Wrapped
    let observer: any AgentObserver

    nonisolated var name: String { wrapped.name }
    nonisolated var tools: [any AnyJSONTool] { wrapped.tools }
    nonisolated var instructions: String { wrapped.instructions }
    nonisolated var configuration: AgentConfiguration { wrapped.configuration }
    nonisolated var memory: (any Memory)? { wrapped.memory }
    nonisolated var inferenceProvider: (any InferenceProvider)? { wrapped.inferenceProvider }
    nonisolated var tracer: (any Tracer)? { wrapped.tracer }
    nonisolated var handoffs: [AnyHandoffConfiguration] { wrapped.handoffs }
    nonisolated var inputGuardrails: [any InputGuardrail] { wrapped.inputGuardrails }
    nonisolated var outputGuardrails: [any OutputGuardrail] { wrapped.outputGuardrails }

    func cancel() async {
        await wrapped.cancel()
    }

    func run(_ input: String, session: (any Session)?, observer additionalObserver: (any AgentObserver)?) async throws -> AgentResult {
        await observer.onAgentStart(context: nil, agent: wrapped, input: input)
        do {
            let result = try await wrapped.run(input, session: session, observer: additionalObserver)
            await observer.onAgentEnd(context: nil, agent: wrapped, result: result)
            return result
        } catch {
            await observer.onError(context: nil, agent: wrapped, error: error)
            throw error
        }
    }

    nonisolated func stream(
        _ input: String,
        session: (any Session)?,
        observer additionalObserver: (any AgentObserver)?
    ) -> AsyncThrowingStream<AgentEvent, Error> {
        wrapped.stream(input, session: session, observer: additionalObserver)
    }

    func runWithResponse(
        _ input: String,
        session: (any Session)?,
        observer additionalObserver: (any AgentObserver)?
    ) async throws -> AgentResponse {
        try await wrapped.runWithResponse(input, session: session, observer: additionalObserver)
    }
}

public extension AgentRuntime {
    /// Wraps this agent with an observer that receives lifecycle callbacks.
    func observed(by observer: some AgentObserver) -> some AgentRuntime {
        ObservedAgent(wrapped: self, observer: observer)
    }
}
