@testable import Swarm
import Testing

private struct EchoTypedTool: Tool, Sendable {
    struct Input: Codable, Sendable {
        let text: String
    }

    struct Output: Codable, Sendable {
        let echoed: String
    }

    let name: String = "echo"
    let description: String = "Echoes input text."
    let parameters: [ToolParameter] = [
        ToolParameter(
            name: "text",
            description: "Text to echo.",
            type: .string,
            isRequired: true
        )
    ]

    func execute(_ input: Input) async throws -> Output {
        Output(echoed: input.text)
    }
}

@AgentActor(instructions: "You are an echo agent.")
actor MacroEchoAgent {
    func process(_ input: String) async throws -> String {
        "Echo: \(input)"
    }
}

@Suite("AgentActor macro conformance")
struct AgentActorMacroConformanceTests {
    @Test("Conforms to AgentRuntime and supports session/hooks signatures")
    func runSupportsSessionAndHooks() async throws {
        let agent: any AgentRuntime = MacroEchoAgent()
        let session = InMemorySession()

        let result = try await agent.run("hi", session: session, hooks: nil)
        #expect(result.output == "Echo: hi")

        let items = try await session.getItems(limit: nil)
        #expect(items.count == 2)
        #expect(items.first?.role == .user)
        #expect(items.first?.content == "hi")
        #expect(items.last?.role == .assistant)
        #expect(items.last?.content == "Echo: hi")
    }

    @Test("Streams via AgentRuntime signature")
    func streamSupportsSessionAndHooks() async throws {
        let agent: any AgentRuntime = MacroEchoAgent()

        var completed: AgentResult?
        for try await event in agent.stream("hello", session: nil, hooks: nil) {
            if case let .completed(result) = event {
                completed = result
            }
        }

        #expect(completed?.output == "Echo: hello")
    }

    @Test("Generated Builder supports typed tool bridging")
    func builderSupportsTypedToolBridging() async throws {
        let agent = MacroEchoAgent.Builder()
            .addTool(EchoTypedTool())
            .build()

        #expect(agent.tools.contains { $0.name == "echo" })
    }
}
