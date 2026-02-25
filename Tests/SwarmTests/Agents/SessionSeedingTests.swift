import Foundation
@testable import Swarm
import Testing

@Suite("Session Seeding Tests")
struct SessionSeedingTests {
    @Test("ChatAgent seeds session history into memory only once")
    func chatAgentSeedsSessionHistoryOnlyOnce() async throws {
        let memory = MockAgentMemory()
        let provider = MockInferenceProvider(responses: ["chat-final-1", "chat-final-2"])
        let session = InMemorySession(sessionId: "chat-session")

        try await session.addItems([
            .user("history-user"),
            .assistant("history-assistant")
        ])

        let agent = ChatAgent(
            "You are a chat agent.",
            memory: memory,
            inferenceProvider: provider
        )

        _ = try await agent.run("first", session: session)
        _ = try await agent.run("second", session: session)

        let messages = await memory.allMessages()
        #expect(messages.count == 6)
        #expect(messages.filter { $0.content == "history-user" }.count == 1)
        #expect(messages.filter { $0.content == "history-assistant" }.count == 1)
    }

    @Test("PlanAndExecuteAgent seeds session history into memory only once")
    func planAndExecuteAgentSeedsSessionHistoryOnlyOnce() async throws {
        let memory = MockAgentMemory()
        let planningResponse = """
        {
          "steps": [
            {
              "stepNumber": 1,
              "description": "Do the task",
              "toolName": null,
              "toolArguments": {},
              "dependsOn": []
            }
          ]
        }
        """
        let provider = MockInferenceProvider(responses: [
            planningResponse, "step-one-result", "final-answer-one",
            planningResponse, "step-two-result", "final-answer-two"
        ])
        let session = InMemorySession(sessionId: "plan-session")

        try await session.addItems([
            .user("history-user"),
            .assistant("history-assistant")
        ])

        let agent = try PlanAndExecuteAgent(
            instructions: "You are a planning agent.",
            memory: memory,
            inferenceProvider: provider
        )

        _ = try await agent.run("first", session: session)
        _ = try await agent.run("second", session: session)

        let messages = await memory.allMessages()
        #expect(messages.count == 6)
        #expect(messages.filter { $0.content == "history-user" }.count == 1)
        #expect(messages.filter { $0.content == "history-assistant" }.count == 1)
    }
}
