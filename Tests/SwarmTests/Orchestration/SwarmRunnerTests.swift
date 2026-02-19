// SwarmRunnerTests.swift
// Swarm Framework
//
// Tests for SwarmRunner streaming tool-call handling.

import Foundation
@testable import Swarm
import Testing

private final class TestStreamingProvider: InferenceProvider, InferenceStreamingProvider, @unchecked Sendable {
    private let eventsByCall: [[InferenceStreamEvent]]
    private var callIndex = 0
    private let lock = NSLock()

    init(eventsByCall: [[InferenceStreamEvent]]) {
        self.eventsByCall = eventsByCall
    }

    func generate(prompt _: String, options _: InferenceOptions) async throws -> String {
        ""
    }

    func stream(prompt _: String, options _: InferenceOptions) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }

    func generateWithToolCalls(
        prompt _: String,
        tools _: [ToolSchema],
        options _: InferenceOptions
    ) async throws -> InferenceResponse {
        InferenceResponse(content: "", toolCalls: [], finishReason: .completed)
    }

    func streamWithToolCalls(
        prompt _: String,
        tools _: [ToolSchema],
        options _: InferenceOptions
    ) -> AsyncThrowingStream<InferenceStreamEvent, Error> {
        lock.lock()
        let index = callIndex
        callIndex += 1
        lock.unlock()
        let events = index < eventsByCall.count ? eventsByCall[index] : []

        return AsyncThrowingStream { continuation in
            for event in events {
                continuation.yield(event)
            }
            continuation.finish()
        }
    }
}

private struct SwarmRunnerTestAgent: AgentRuntime {
    let tools: [any AnyJSONTool]
    let instructions: String
    var configuration: AgentConfiguration
    let provider: any InferenceProvider

    init(name: String, tools: [any AnyJSONTool], provider: any InferenceProvider) {
        self.tools = tools
        self.instructions = "Test"
        self.configuration = AgentConfiguration(name: name, enableStreaming: true)
        self.provider = provider
    }

    nonisolated var inferenceProvider: (any InferenceProvider)? { provider }

    func run(_ input: String, session _: (any Session)?, hooks _: (any RunHooks)?) async throws -> AgentResult {
        AgentResult(output: input)
    }

    nonisolated func stream(
        _ input: String,
        session _: (any Session)?,
        hooks _: (any RunHooks)?
    ) -> AsyncThrowingStream<AgentEvent, Error> {
        StreamHelper.makeTrackedStream { continuation in
            continuation.yield(.started(input: input))
            continuation.yield(.completed(result: AgentResult(output: input)))
            continuation.finish()
        }
    }

    func cancel() async {}
}

@Suite("SwarmRunner Streaming Tool Calls")
struct SwarmRunnerStreamingToolCallTests {
    @Test("Streaming tool calls accept empty arguments with nil id")
    func streamingToolCallsAcceptEmptyArguments() async throws {
        let tool = FunctionTool(name: "noop", description: "No-op") { _ in
            .string("ok")
        }

        let provider = TestStreamingProvider(eventsByCall: [
            [
                .toolCallDelta(index: 0, id: nil, name: "noop", arguments: ""),
                .done
            ],
            [
                .textDelta("final"),
                .done
            ]
        ])

        let agent = SwarmRunnerTestAgent(name: "tester", tools: [tool], provider: provider)
        let runner = try SwarmRunner(agents: [agent])

        let response = try await runner.run(
            agentName: "tester",
            messages: [.user("hi")],
            executeTools: true
        )

        let toolMessages = response.messages.filter { $0.role == .tool }
        #expect(toolMessages.count == 1)
        #expect(toolMessages.first?.content == "\"ok\"")
    }

    @Test("Streaming tool calls reject missing tool names")
    func streamingToolCallsRejectMissingNames() async throws {
        let tool = FunctionTool(name: "noop", description: "No-op") { _ in
            .string("ok")
        }

        let provider = TestStreamingProvider(eventsByCall: [
            [
                .toolCallDelta(index: 0, id: "call-1", name: nil, arguments: "{}"),
                .done
            ]
        ])

        let agent = SwarmRunnerTestAgent(name: "tester", tools: [tool], provider: provider)
        let runner = try SwarmRunner(agents: [agent])

        await #expect(throws: SwarmError.self) {
            _ = try await runner.run(
                agentName: "tester",
                messages: [.user("hi")],
                executeTools: true
            )
        }
    }
}
