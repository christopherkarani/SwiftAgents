import Foundation
@testable import Swarm
import Testing

@Suite("SequentialChain Tests")
struct SequentialChainTests {
    @Test("Handoff input filter uses matching runtime instance when agents share a type")
    func handoffUsesRuntimeIdentityForSameTypeAgents() async throws {
        let first = SequentialIdentityAgent(id: "first")
        let second = SequentialIdentityAgent(id: "second")

        let firstConfig = AnyHandoffConfiguration(handoff(
            to: first,
            inputFilter: { data in
                var updated = data
                updated = HandoffInputData(
                    sourceAgentName: data.sourceAgentName,
                    targetAgentName: data.targetAgentName,
                    input: "first-filter::\(data.input)",
                    context: data.context,
                    metadata: data.metadata
                )
                return updated
            }
        ))
        let secondConfig = AnyHandoffConfiguration(handoff(
            to: second,
            inputFilter: { data in
                var updated = data
                updated = HandoffInputData(
                    sourceAgentName: data.sourceAgentName,
                    targetAgentName: data.targetAgentName,
                    input: "second-filter::\(data.input)",
                    context: data.context,
                    metadata: data.metadata
                )
                return updated
            }
        ))

        let chain = SequentialChain(agents: [second], handoffs: [firstConfig, secondConfig])

        let result = try await chain.run("hello")
        #expect(result.output == "second:second-filter::hello")
    }
}

private final class SequentialIdentityAgent: AgentRuntime, @unchecked Sendable {
    private let id: String

    init(id: String) {
        self.id = id
    }

    nonisolated var tools: [any AnyJSONTool] { [] }
    nonisolated var instructions: String { "Sequential identity agent \(id)" }
    nonisolated var configuration: AgentConfiguration { .default }

    func run(
        _ input: String,
        session _: (any Session)?,
        hooks _: (any RunHooks)?
    ) async throws -> AgentResult {
        AgentResult(output: "\(id):\(input)")
    }

    nonisolated func stream(
        _ input: String,
        session _: (any Session)?,
        hooks _: (any RunHooks)?
    ) -> AsyncThrowingStream<AgentEvent, Error> {
        StreamHelper.makeTrackedStream { [self] continuation in
            continuation.yield(.started(input: input))
            continuation.yield(.completed(result: AgentResult(output: "\(id):\(input)")))
            continuation.finish()
        }
    }

    func cancel() async {}
}
