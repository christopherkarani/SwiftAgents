import Testing
@testable import Swarm

@Suite("AgentObserver")
struct AgentObserverTests {
    @Test("AgentObserver conformance works")
    func observerConformance() async throws {
        struct TestObserver: AgentObserver {
            func onAgentStart(context: AgentContext?, agent: any AgentRuntime, input: String) async {}
        }
        let observer = TestObserver()
        await observer.onAgentStart(context: nil, agent: MockAgentRuntime(response: ""), input: "test")
    }

    @Test("observed(by:) wraps agent and calls observer")
    func observedByFluent() async throws {
        let mock = MockInferenceProvider()
        await mock.setResponses(["ok"])
        let agent = try Agent(instructions: "test", inferenceProvider: mock)
        let observer = CallCountObserver()
        let observed = agent.observed(by: observer)
        _ = try await observed.run("hello")
        #expect(await observer.startCount == 1)
    }

    @Test("LoggingObserver conforms to AgentObserver")
    func loggingObserverConformance() {
        let _: any AgentObserver = LoggingObserver()
    }

    @Test("run with observer: parameter compiles")
    func runWithObserverParam() async throws {
        let mock = MockInferenceProvider()
        await mock.setResponses(["ok"])
        let agent = try Agent(instructions: "test", inferenceProvider: mock)
        let observer = LoggingObserver()
        _ = try await agent.run("hello", observer: observer)
    }
}

actor CallCountObserver: AgentObserver {
    var startCount = 0
    var endCount = 0

    func onAgentStart(context: AgentContext?, agent: any AgentRuntime, input: String) async {
        startCount += 1
    }

    func onAgentEnd(context: AgentContext?, agent: any AgentRuntime, result: AgentResult) async {
        endCount += 1
    }
}
