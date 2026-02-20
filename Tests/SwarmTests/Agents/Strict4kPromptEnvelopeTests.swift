import Foundation
@testable import Swarm
import Testing

@Suite("Strict4k Prompt Envelope")
struct Strict4kPromptEnvelopeTests {
    @Test("ChatAgent caps prompt to strict4k max input budget")
    func chatAgentCapsPrompt() async throws {
        let provider = MockInferenceProvider(responses: ["chat-ok"])
        let memory = MockAgentMemory(context: longBlock("memory", lines: 420))
        let session = try await makeLargeSession()

        let chat = ChatAgent(
            longBlock("instructions", lines: 220),
            configuration: strict4kConfig(),
            memory: memory,
            inferenceProvider: provider
        )

        _ = try await chat.run("needle-user-input", session: session)

        guard let prompt = await provider.lastGenerateCall?.prompt else {
            Issue.record("Expected ChatAgent to call generate()")
            return
        }

        let tokenCount = CharacterBasedTokenEstimator.shared.estimateTokens(for: prompt)
        #expect(tokenCount <= ContextProfile.strict4k.budget.maxInputTokens)
        #expect(prompt.contains("needle-user-input"))
    }

    @Test("Agent caps prompt to strict4k max input budget")
    func agentCapsPrompt() async throws {
        let provider = MockInferenceProvider(responses: ["agent-ok"])
        let memory = MockAgentMemory(context: longBlock("memory", lines: 420))
        let session = try await makeLargeSession()

        let agent = Agent(
            tools: [],
            instructions: longBlock("instructions", lines: 220),
            configuration: strict4kConfig(),
            memory: memory,
            inferenceProvider: provider
        )

        _ = try await agent.run("needle-user-input", session: session)

        guard let prompt = await provider.lastGenerateCall?.prompt else {
            Issue.record("Expected Agent to call generate() when no tools are configured")
            return
        }

        let tokenCount = CharacterBasedTokenEstimator.shared.estimateTokens(for: prompt)
        #expect(tokenCount <= ContextProfile.strict4k.budget.maxInputTokens)
        #expect(prompt.contains("needle-user-input"))
    }

    @Test("ReActAgent caps prompt to strict4k max input budget")
    func reactAgentCapsPrompt() async throws {
        let provider = MockInferenceProvider(responses: ["Final Answer: react-ok"])
        let memory = MockAgentMemory(context: longBlock("memory", lines: 420))
        let session = try await makeLargeSession()

        let agent = ReActAgent(
            tools: [],
            instructions: longBlock("instructions", lines: 220),
            configuration: strict4kConfig(),
            memory: memory,
            inferenceProvider: provider
        )

        _ = try await agent.run("needle-user-input", session: session)

        guard let prompt = await provider.lastGenerateCall?.prompt else {
            Issue.record("Expected ReActAgent to call generate() when no tools are configured")
            return
        }

        let tokenCount = CharacterBasedTokenEstimator.shared.estimateTokens(for: prompt)
        #expect(tokenCount <= ContextProfile.strict4k.budget.maxInputTokens)
        #expect(prompt.contains("needle-user-input"))
    }
}

private func strict4kConfig() -> AgentConfiguration {
    AgentConfiguration(
        name: "strict4k-test",
        contextMode: .strict4k,
        defaultTracingEnabled: false
    )
}

private func longBlock(_ label: String, lines: Int) -> String {
    (0 ..< lines)
        .map { index in
            "\(label)-\(index): this is intentionally verbose content to stress prompt budget enforcement."
        }
        .joined(separator: "\n")
}

private func makeLargeSession() async throws -> InMemorySession {
    let session = InMemorySession()
    for index in 0 ..< 120 {
        try await session.addItems([
            .user("history-user-\(index): \(longBlock("u", lines: 1))"),
            .assistant("history-assistant-\(index): \(longBlock("a", lines: 1))"),
        ])
    }
    return session
}
