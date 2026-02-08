// ChatAgent.swift
// Swarm Framework
//
// Simple chat-only agent (no tools) backed by an InferenceProvider.

import Foundation

/// A simple chat-only agent that calls an inference provider once per request.
///
/// Unlike `ReActAgent` or `Agent`, `ChatAgent` does not invoke tools.
/// It is useful for the common "instructions + user input" chat pattern.
public actor ChatAgent: AgentRuntime {
    // MARK: Public

    nonisolated public var tools: [any AnyJSONTool] { [] }
    nonisolated public let instructions: String
    nonisolated public let configuration: AgentConfiguration
    nonisolated public let memory: (any Memory)?
    nonisolated public let inferenceProvider: (any InferenceProvider)?
    nonisolated public let tracer: (any Tracer)?
    nonisolated public let inputGuardrails: [any InputGuardrail]
    nonisolated public let outputGuardrails: [any OutputGuardrail]

    nonisolated public var handoffs: [AnyHandoffConfiguration] { [] }

    public init(
        _ instructions: String,
        configuration: AgentConfiguration = .default,
        memory: (any Memory)? = nil,
        inferenceProvider: (any InferenceProvider)? = nil,
        tracer: (any Tracer)? = nil,
        inputGuardrails: [any InputGuardrail] = [],
        outputGuardrails: [any OutputGuardrail] = []
    ) {
        self.instructions = instructions
        self.configuration = configuration
        self.memory = memory
        self.inferenceProvider = inferenceProvider
        self.tracer = tracer
        self.inputGuardrails = inputGuardrails
        self.outputGuardrails = outputGuardrails
    }

    public func run(
        _ input: String,
        session: (any Session)? = nil,
        hooks: (any RunHooks)? = nil
    ) async throws -> AgentResult {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AgentError.invalidInput(reason: "Input cannot be empty")
        }

        let activeTracer = tracer ?? AgentEnvironmentValues.current.tracer
        let activeMemory = memory ?? AgentEnvironmentValues.current.memory
        let provider = inferenceProvider ?? AgentEnvironmentValues.current.inferenceProvider

        guard let provider else {
            throw AgentError.inferenceProviderUnavailable(
                reason: "No inference provider configured. Please provide an InferenceProvider."
            )
        }

        let tracing = TracingHelper(
            tracer: activeTracer,
                agentName: configuration.name.isEmpty ? "ChatAgent" : configuration.name
        )
        await tracing.traceStart(input: input)

        await hooks?.onAgentStart(context: nil, agent: self, input: input)

        do {
            let runner = GuardrailRunner(hooks: hooks)
            _ = try await runner.runInputGuardrails(inputGuardrails, input: input, context: nil)

            let startTime = ContinuousClock.now

            var sessionHistory: [MemoryMessage] = []
            if let session {
                sessionHistory = try await session.getItems(limit: configuration.sessionHistoryLimit)
            }

            // Store session history + user message in memory (if configured)
            if let mem = activeMemory {
                for msg in sessionHistory {
                    await mem.add(msg)
                }
                await mem.add(.user(input))
            }

            // Retrieve memory context (RAG / summarization) if available
            let tokenLimit = configuration.contextProfile.memoryTokenLimit
            let memoryContext: String = if let mem = activeMemory {
                await mem.context(for: input, tokenLimit: tokenLimit)
            } else {
                ""
            }

            let prompt = buildPrompt(input: input, sessionHistory: sessionHistory, memoryContext: memoryContext)

            await hooks?.onLLMStart(
                context: nil,
                agent: self,
                systemPrompt: instructions,
                inputMessages: [MemoryMessage.user(prompt)]
            )

            let output = try await provider.generate(prompt: prompt, options: configuration.inferenceOptions)

            await hooks?.onLLMEnd(
                context: nil,
                agent: self,
                response: output,
                usage: nil
            )

            _ = try await runner.runOutputGuardrails(outputGuardrails, output: output, agent: self, context: nil)

            if let session {
                try await session.addItems([.user(input), .assistant(output)])
            }

            if let mem = activeMemory {
                await mem.add(.assistant(output))
            }

            let duration = ContinuousClock.now - startTime
            let result = AgentResult(
                output: output,
                toolCalls: [],
                toolResults: [],
                iterationCount: 1,
                duration: duration,
                tokenUsage: nil,
                metadata: [
                    "chat.duration": .double(
                        Double(duration.components.seconds) +
                            Double(duration.components.attoseconds) / 1e18
                    ),
                ]
            )

            await tracing.traceComplete(result: result)
            await hooks?.onAgentEnd(context: nil, agent: self, result: result)
            return result
        } catch {
            await hooks?.onError(context: nil, agent: self, error: error)
            await tracing.traceError(error)
            throw error
        }
    }

    nonisolated public func stream(
        _ input: String,
        session: (any Session)? = nil,
        hooks: (any RunHooks)? = nil
    ) -> AsyncThrowingStream<AgentEvent, Error> {
        StreamHelper.makeTrackedStream(for: self) { agent, continuation in
            let streamHooks = EventStreamHooks(continuation: continuation)

            let combinedHooks: any RunHooks
            if let userHooks = hooks {
                combinedHooks = CompositeRunHooks(hooks: [userHooks, streamHooks])
            } else {
                combinedHooks = streamHooks
            }

            do {
                _ = try await agent.run(input, session: session, hooks: combinedHooks)
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }

    public func cancel() async {
        // Single-shot agent; cancellation is handled via Task cancellation in callers.
    }

    // MARK: Private

    private func buildPrompt(input: String, sessionHistory: [MemoryMessage], memoryContext: String) -> String {
        var parts: [String] = []

        let trimmedInstructions = instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedInstructions.isEmpty {
            parts.append(trimmedInstructions)
        }

        if !memoryContext.isEmpty {
            parts.append("""
            Relevant Context from Memory:
            \(memoryContext)
            """)
        }

        if !sessionHistory.isEmpty {
            parts.append(formatConversationContext(from: sessionHistory))
        }

        parts.append("User: \(input)")
        return parts.joined(separator: "\n\n")
    }

    private func formatConversationContext(from sessionHistory: [MemoryMessage]) -> String {
        var lines: [String] = []
        for message in sessionHistory {
            switch message.role {
            case .user:
                lines.append("User: \(message.content)")
            case .assistant:
                lines.append("Assistant: \(message.content)")
            case .system:
                lines.append("System: \(message.content)")
            case .tool:
                lines.append("Tool: \(message.content)")
            }
        }
        return lines.joined(separator: "\n")
    }
}
