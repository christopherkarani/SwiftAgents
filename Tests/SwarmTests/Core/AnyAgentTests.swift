import Foundation
@testable import Swarm
import Testing

@Suite("AnyAgent")
struct AnyAgentTests {
    @Test("runWithResponse forwards to wrapped runtime implementation")
    func runWithResponseForwardsToWrappedRuntimeImplementation() async throws {
        let wrapped = ResponseAwareRuntime()
        let erased = AnyAgent(wrapped)

        let response = try await erased.runWithResponse("hello")

        #expect(response.responseId == "forwarded-response-id")
        #expect(response.output == "forwarded output")
    }
}

private struct ResponseAwareRuntime: AgentRuntime, Sendable {
    nonisolated let tools: [any AnyJSONTool] = []
    nonisolated let instructions: String = "test"
    nonisolated let configuration: AgentConfiguration = .default

    func run(_ input: String, session _: (any Session)?, observer _: (any AgentObserver)?) async throws -> AgentResult {
        AgentResult(output: "default run output: \(input)")
    }

    nonisolated func stream(
        _ input: String,
        session _: (any Session)?,
        observer _: (any AgentObserver)?
    ) -> AsyncThrowingStream<AgentEvent, Error> {
        StreamHelper.makeTrackedStream { continuation in
            continuation.yield(.started(input: input))
            continuation.yield(.completed(result: AgentResult(output: "stream output")))
            continuation.finish()
        }
    }

    func cancel() async {}

    func runWithResponse(
        _ input: String,
        session _: (any Session)?,
        observer _: (any AgentObserver)?
    ) async throws -> AgentResponse {
        AgentResponse(
            responseId: "forwarded-response-id",
            output: "forwarded output",
            agentName: configuration.name,
            timestamp: Date(),
            metadata: ["input": .string(input)],
            toolCalls: [],
            usage: nil,
            iterationCount: 1
        )
    }
}
