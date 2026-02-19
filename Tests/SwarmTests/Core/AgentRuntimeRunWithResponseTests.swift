// AgentRuntimeRunWithResponseTests.swift
// SwarmTests

import Foundation
@testable import Swarm
import Testing

@Suite("AgentRuntime runWithResponse Tests")
struct AgentRuntimeRunWithResponseTests {
    @Test("Duplicate tool call IDs do not crash and prefer first call")
    func duplicateToolCallIds() async throws {
        let agent = DuplicateToolCallAgent()
        let response = try await agent.runWithResponse("hello")

        #expect(response.toolCalls.count == 1)
        #expect(response.toolCalls.first?.toolName == "first")
    }
}

private struct DuplicateToolCallAgent: AgentRuntime {
    nonisolated let tools: [any AnyJSONTool] = []
    nonisolated let instructions: String = "Test"
    nonisolated let configuration: AgentConfiguration

    init() {
        var config = AgentConfiguration.default
        config.name = "DuplicateToolCallAgent"
        configuration = config
    }

    func run(_ input: String, session: (any Session)?, hooks: (any RunHooks)?) async throws -> AgentResult {
        let duplicateId = UUID()
        let firstCall = ToolCall(id: duplicateId, toolName: "first")
        let secondCall = ToolCall(id: duplicateId, toolName: "second")
        let result = ToolResult.success(callId: duplicateId, output: .string("ok"), duration: .zero)

        return AgentResult(
            output: input,
            toolCalls: [firstCall, secondCall],
            toolResults: [result],
            iterationCount: 1,
            duration: .zero
        )
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
