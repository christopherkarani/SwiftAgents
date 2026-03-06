import Foundation
@testable import Swarm
import Testing

@Suite("Hive-Only Runtime Contract")
struct HiveOnlyRuntimeContractTests {
    @Test("Agent run records hive runtime metadata")
    func agentRunRecordsHiveRuntimeMetadata() async throws {
        let provider = MockInferenceProvider()
        await provider.setToolCallResponses([
            InferenceResponse(
                content: nil,
                toolCalls: [
                    InferenceResponse.ParsedToolCall(
                        id: "call_lookup",
                        name: "lookup",
                        arguments: ["query": .string("hive runtime")]
                    )
                ],
                finishReason: .toolCall,
                usage: nil
            ),
            InferenceResponse(
                content: "Final answer from tool",
                toolCalls: [],
                finishReason: .completed,
                usage: nil
            )
        ])

        let config = AgentConfiguration.default

        let agent = try Agent(
            tools: [MockTool(name: "lookup", result: .string("resolved"))],
            instructions: "Use tools when needed.",
            configuration: config,
            inferenceProvider: provider
        )

        let result = try await agent.run("Lookup runtime mode")
        #expect(result.output == "Final answer from tool")
        #expect(result.toolCalls.count == 1)
        #expect(result.metadata["runtime.engine"]?.stringValue == "hive")
    }

    @Test("Agent stream completed result records hive runtime metadata")
    func agentStreamCompletedResultRecordsHiveRuntimeMetadata() async throws {
        let provider = MockInferenceProvider(responses: ["Final answer"])

        let config = AgentConfiguration.default

        let agent = try Agent(
            tools: [],
            instructions: "Return final answer.",
            configuration: config,
            inferenceProvider: provider
        )

        let events = try await collectEvents(from: agent.stream("Run stream"))
        guard let completed = completedResult(from: events) else {
            Issue.record("Expected .completed event with AgentResult")
            return
        }

        #expect(completed.output == "Final answer")
        #expect(completed.metadata["runtime.engine"]?.stringValue == "hive")
    }

    @Test("ReActAgent run records hive runtime metadata")
    func reactRunRecordsHiveRuntimeMetadata() async throws {
        let provider = MockInferenceProvider(responses: [
            "Thought: I should call lookup.\nAction: lookup()",
            "Final Answer: done"
        ])

        let config = AgentConfiguration.default

        let react = try ReActAgent(
            tools: [MockTool(name: "lookup", result: .string("resolved"))],
            instructions: "Use tools when needed.",
            configuration: config,
            inferenceProvider: provider
        )

        let result = try await react.run("Use lookup")
        #expect(result.output == "done")
        #expect(result.toolCalls.count == 1)
        #expect(result.metadata["runtime.engine"]?.stringValue == "hive")
    }

    @Test("ReActAgent stream completed result records hive runtime metadata")
    func reactStreamCompletedResultRecordsHiveRuntimeMetadata() async throws {
        let provider = MockInferenceProvider(responses: ["Final Answer: streamed-done"])

        let config = AgentConfiguration.default

        let react = try ReActAgent(
            tools: [],
            instructions: "Return a final answer.",
            configuration: config,
            inferenceProvider: provider
        )

        let events = try await collectEvents(from: react.stream("Run stream"))
        guard let completed = completedResult(from: events) else {
            Issue.record("Expected .completed event with AgentResult")
            return
        }

        #expect(completed.output == "streamed-done")
        #expect(completed.metadata["runtime.engine"]?.stringValue == "hive")
    }

    @Test("ChatAgent run records hive runtime metadata")
    func chatRunRecordsHiveRuntimeMetadata() async throws {
        let provider = MockInferenceProvider(responses: ["chat-final"])

        let config = AgentConfiguration.default

        let chat = ChatAgent(
            "You are chat.",
            configuration: config,
            inferenceProvider: provider
        )

        let result = try await chat.run("Hi")
        #expect(result.output == "chat-final")
        #expect(result.iterationCount == 1)
        #expect(result.metadata["runtime.engine"]?.stringValue == "hive")
    }

    @Test("ChatAgent stream emits iteration lifecycle and hive runtime metadata")
    func chatStreamEmitsIterationLifecycleAndHiveRuntimeMetadata() async throws {
        let provider = MockInferenceProvider(responses: ["chat-stream-final"])

        let config = AgentConfiguration.default

        let chat = ChatAgent(
            "You are chat.",
            configuration: config,
            inferenceProvider: provider
        )

        let events = try await collectEvents(from: chat.stream("Hi stream"))
        #expect(events.contains(where: isIterationStartedOne))
        #expect(events.contains(where: isIterationCompletedOne))

        guard let completed = completedResult(from: events) else {
            Issue.record("Expected .completed event with AgentResult")
            return
        }

        #expect(completed.output == "chat-stream-final")
        #expect(completed.metadata["runtime.engine"]?.stringValue == "hive")
    }

    @Test("All core agent runtimes report hive in stream completion metadata")
    func allCoreAgentRuntimesReportHiveInStreamCompletionMetadata() async throws {
        let config = AgentConfiguration.default

        let agent = try Agent(
            tools: [],
            instructions: "Agent",
            configuration: config,
            inferenceProvider: MockInferenceProvider(responses: ["agent-out"])
        )
        let react = try ReActAgent(
            tools: [],
            instructions: "ReAct",
            configuration: config,
            inferenceProvider: MockInferenceProvider(responses: ["Final Answer: react-out"])
        )
        let chat = ChatAgent(
            "Chat",
            configuration: config,
            inferenceProvider: MockInferenceProvider(responses: ["chat-out"])
        )

        let agentResult = try await requireCompletedResult(from: agent.stream("agent"))
        let reactResult = try await requireCompletedResult(from: react.stream("react"))
        let chatResult = try await requireCompletedResult(from: chat.stream("chat"))

        #expect(agentResult.metadata["runtime.engine"]?.stringValue == "hive")
        #expect(reactResult.metadata["runtime.engine"]?.stringValue == "hive")
        #expect(chatResult.metadata["runtime.engine"]?.stringValue == "hive")
    }
}

private func collectEvents(from stream: AsyncThrowingStream<AgentEvent, Error>) async throws -> [AgentEvent] {
    var events: [AgentEvent] = []
    for try await event in stream {
        events.append(event)
    }
    return events
}

private func completedResult(from events: [AgentEvent]) -> AgentResult? {
    for event in events {
        if case let .completed(result) = event {
            return result
        }
    }
    return nil
}

private func requireCompletedResult(from stream: AsyncThrowingStream<AgentEvent, Error>) async throws -> AgentResult {
    let events = try await collectEvents(from: stream)
    guard let result = completedResult(from: events) else {
        throw TestFailureError("Expected .completed event with AgentResult")
    }
    return result
}

private func isIterationStartedOne(_ event: AgentEvent) -> Bool {
    if case .iterationStarted(let number) = event {
        return number == 1
    }
    return false
}

private func isIterationCompletedOne(_ event: AgentEvent) -> Bool {
    if case .iterationCompleted(let number) = event {
        return number == 1
    }
    return false
}

private struct TestFailureError: Error, CustomStringConvertible {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var description: String { message }
}
