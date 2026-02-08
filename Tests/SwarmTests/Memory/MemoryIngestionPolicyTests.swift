import Testing
@testable import Swarm

@Suite("Memory Ingestion Policy")
struct MemoryIngestionPolicyTests {
    @Test("Agent stores tool results in memory")
    func agentStoresToolResults() async throws {
        let tool = MockTool(name: "mock_tool", result: .string("ok"))

        let provider = MockInferenceProvider()
        await provider.setToolCallResponses([
            InferenceResponse(
                toolCalls: [.init(id: "1", name: "mock_tool", arguments: [:])],
                finishReason: .toolCall
            ),
            InferenceResponse(content: "done", finishReason: .completed)
        ])

        let memory = MockAgentMemory()
        let agent = Agent(
            tools: [tool],
            configuration: .default.maxIterations(3),
            memory: memory,
            inferenceProvider: provider
        )

        let result = try await agent.run("hi")
        #expect(result.output == "done")

        let added = await memory.addCalls
        #expect(added.contains(where: { message in
            message.role == .tool
                && message.metadata["tool_name"] == "mock_tool"
                && message.content.contains("ok")
        }))
    }

    @Test("Session history is seeded only when memory is empty")
    func sessionHistorySeedsOnce() async throws {
        let session = InMemorySession(sessionId: "test")
        try await session.addItems([
            .user("seed-user"),
            .assistant("seed-assistant")
        ])

        let provider = MockInferenceProvider(responses: ["Final Answer: ok"])
        let memory = MockAgentMemory()

        let agent = Agent(
            memory: memory,
            inferenceProvider: provider
        )

        _ = try await agent.run("turn-1", session: session)
        _ = try await agent.run("turn-2", session: session)

        let added = await memory.addCalls
        let seededUserCount = added.filter { $0.content == "seed-user" }.count
        let seededAssistantCount = added.filter { $0.content == "seed-assistant" }.count

        #expect(seededUserCount == 1)
        #expect(seededAssistantCount == 1)
    }
}
