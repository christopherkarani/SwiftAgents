import Testing
@testable import Swarm

@Suite("Conversation")
struct ConversationTests {
    @Test("send appends user and assistant messages")
    func sendAppendsMessages() async throws {
        let mock = MockAgentRuntime(response: "hello back")
        let conversation = Conversation(with: mock)

        try await conversation.send("hello")

        let messages = await conversation.messages
        #expect(messages.count == 2)
        #expect(messages[0].role == .user)
        #expect(messages[0].text == "hello")
        #expect(messages[1].role == .assistant)
        #expect(messages[1].text == "hello back")
    }

    @Test("streamText appends assistant from token stream")
    func streamTextAppendsTokens() async throws {
        let mock = MockAgentRuntime(streamTokens: ["Hello", " ", "world"])
        let conversation = Conversation(with: mock)

        try await conversation.streamText("say hi")

        let messages = await conversation.messages
        #expect(messages.count == 2)
        #expect(messages[1].role == .assistant)
        #expect(messages[1].text == "Hello world")
    }

    @Test("stream returns raw event stream")
    func streamReturnsEvents() async throws {
        let mock = MockAgentRuntime(streamTokens: ["Hi"])
        let conversation = Conversation(with: mock)

        var events: [AgentEvent] = []
        for try await event in conversation.stream("test") {
            events.append(event)
        }

        #expect(!events.isEmpty)
    }

    @Test("observer is passed to send")
    func observerPassedToSend() async throws {
        let mock = MockAgentRuntime(response: "ok")
        let observer = TestObserver()
        let conversation = Conversation(with: mock, observer: observer)

        try await conversation.send("hello")

        #expect(await observer.agentStartCount == 1)
    }
}

private actor TestObserver: AgentObserver {
    var agentStartCount = 0

    func onAgentStart(context: AgentContext?, agent: any AgentRuntime, input: String) async {
        agentStartCount += 1
    }
}
