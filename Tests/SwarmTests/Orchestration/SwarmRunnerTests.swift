// SwarmRunnerTests.swift
// SwarmTests

import Foundation
@testable import Swarm
import Testing

@Suite("SwarmRunner Tests")
struct SwarmRunnerTests {
    @Test("Throws when tool-call stream omits required fields")
    func throwsOnIncompleteToolCallStream() async throws {
        let provider = IncompleteToolCallProvider()
        let tool = MockTool(name: "mock_tool")
        let agent = SwarmTestAgent(
            name: "Streamer",
            provider: provider,
            tools: [tool],
            enableStreaming: true
        )

        let runner = try SwarmRunner(agents: [agent])
        let stream = await runner.runStream(
            agentName: "Streamer",
            messages: [.user("hello")],
            executeTools: false
        )

        await #expect(throws: SwarmError.self) {
            try await drain(stream)
        }
    }

    @Test("Throws when duplicate handoff tool names are configured")
    func throwsOnDuplicateHandoffToolNames() async throws {
        let provider = MockInferenceProvider()
        let targetA = SwarmTestAgent(name: "TargetA", provider: provider)
        let targetB = SwarmTestAgent(name: "TargetB", provider: provider)

        let handoffA = AnyHandoffConfiguration(handoff(to: targetA, toolName: "handoff_dup"))
        let handoffB = AnyHandoffConfiguration(handoff(to: targetB, toolName: "handoff_dup"))

        let source = SwarmTestAgent(
            name: "Source",
            provider: provider,
            handoffs: [handoffA, handoffB]
        )

        let runner = try SwarmRunner(agents: [source, targetA, targetB], fallbackProvider: provider)
        let stream = await runner.runStream(
            agentName: "Source",
            messages: [.user("hello")],
            executeTools: false
        )

        await #expect(throws: SwarmError.self) {
            try await drain(stream)
        }
    }
}

private func drain(_ stream: AsyncThrowingStream<SwarmStreamChunk, Error>) async throws {
    for try await _ in stream {}
}

private struct IncompleteToolCallProvider: InferenceProvider, InferenceStreamingProvider {
    func generate(prompt: String, options: InferenceOptions) async throws -> String {
        ""
    }

    func stream(prompt: String, options: InferenceOptions) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }

    func generateWithToolCalls(
        prompt: String,
        tools: [ToolSchema],
        options: InferenceOptions
    ) async throws -> InferenceResponse {
        InferenceResponse(content: "", finishReason: .toolCall)
    }

    func streamWithToolCalls(
        prompt: String,
        tools: [ToolSchema],
        options: InferenceOptions
    ) -> AsyncThrowingStream<InferenceStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.toolCallDelta(index: 0, id: nil, name: "mock_tool", arguments: "{}"))
            continuation.yield(.done)
            continuation.finish()
        }
    }
}

private actor SwarmTestAgent: AgentRuntime {
    nonisolated let tools: [any AnyJSONTool]
    nonisolated let instructions: String = "Test"
    nonisolated let configuration: AgentConfiguration
    nonisolated let provider: any InferenceProvider
    nonisolated let _handoffs: [AnyHandoffConfiguration]

    nonisolated var inferenceProvider: (any InferenceProvider)? { provider }
    nonisolated var handoffs: [AnyHandoffConfiguration] { _handoffs }

    init(
        name: String,
        provider: any InferenceProvider,
        tools: [any AnyJSONTool] = [],
        handoffs: [AnyHandoffConfiguration] = [],
        enableStreaming: Bool = false
    ) {
        var config = AgentConfiguration.default
        config.name = name
        config.enableStreaming = enableStreaming
        configuration = config
        self.provider = provider
        self.tools = tools
        _handoffs = handoffs
    }

    func run(_ input: String, session: (any Session)?, hooks: (any RunHooks)?) async throws -> AgentResult {
        AgentResult(output: input)
    }

    nonisolated func stream(
        _ input: String,
        session: (any Session)?,
        hooks: (any RunHooks)?
    ) -> AsyncThrowingStream<AgentEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }

    func cancel() async {}
}
