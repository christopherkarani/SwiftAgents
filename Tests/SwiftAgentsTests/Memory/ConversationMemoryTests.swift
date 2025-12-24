// ConversationMemoryTests.swift
// SwiftAgents Framework

import Foundation
@testable import SwiftAgents
import Testing

@Suite("ConversationMemory Tests")
struct ConversationMemoryTests {
    // MARK: - Initialization Tests

    @Test("Creates with default configuration")
    func defaultInit() async {
        let memory = ConversationMemory()

        #expect(await memory.maxMessages == 100)
        #expect(await memory.isEmpty)
    }

    @Test("Creates with custom max messages")
    func customMaxMessages() async {
        let memory = ConversationMemory(maxMessages: 50)

        #expect(await memory.maxMessages == 50)
    }

    @Test("Enforces minimum max messages of 1")
    func minimumMaxMessages() async {
        let memory = ConversationMemory(maxMessages: 0)

        #expect(await memory.maxMessages == 1)
    }

    // MARK: - Add Tests

    @Test("Adds single message")
    func addSingleMessage() async {
        let memory = ConversationMemory()
        let message = MemoryMessage.user("Hello")

        await memory.add(message)

        #expect(await memory.count == 1)
    }

    @Test("Adds multiple messages")
    func addMultipleMessages() async {
        let memory = ConversationMemory()

        await memory.add(.user("Hello"))
        await memory.add(.assistant("Hi there"))
        await memory.add(.user("How are you?"))

        #expect(await memory.count == 3)
    }

    @Test("Maintains message order")
    func messageOrder() async {
        let memory = ConversationMemory()

        await memory.add(.user("First"))
        await memory.add(.assistant("Second"))
        await memory.add(.user("Third"))

        let messages = await memory.allMessages()

        #expect(messages[0].content == "First")
        #expect(messages[1].content == "Second")
        #expect(messages[2].content == "Third")
    }

    // MARK: - FIFO Behavior Tests

    @Test("Removes oldest messages when limit exceeded")
    func fIFOBehavior() async {
        let memory = ConversationMemory(maxMessages: 3)

        await memory.add(.user("1"))
        await memory.add(.user("2"))
        await memory.add(.user("3"))
        await memory.add(.user("4")) // Should remove "1"

        let messages = await memory.allMessages()

        #expect(messages.count == 3)
        #expect(messages[0].content == "2")
        #expect(messages[2].content == "4")
    }

    @Test("Never exceeds max messages")
    func neverExceedsMax() async {
        let memory = ConversationMemory(maxMessages: 5)

        for i in 1...20 {
            await memory.add(.user("Message \(i)"))
        }

        #expect(await memory.count == 5)
    }

    // MARK: - Context Retrieval Tests

    @Test("Gets context within token limit")
    func testGetContext() async {
        let memory = ConversationMemory()

        await memory.add(.user("Hello"))
        await memory.add(.assistant("Hi there"))

        let context = await memory.context(for: "test", tokenLimit: 1000)

        #expect(context.contains("[user]: Hello"))
        #expect(context.contains("[assistant]: Hi there"))
    }

    @Test("Respects token limit in context")
    func contextTokenLimit() async {
        let memory = ConversationMemory()

        // Add many messages
        for i in 1...100 {
            await memory.add(.user("Message number \(i) with some content"))
        }

        // Request very small token limit
        let context = await memory.context(for: "test", tokenLimit: 50)

        // Should only include a few messages
        let lines = context.split(separator: "\n\n")
        #expect(lines.count < 10)
    }

    // MARK: - Clear Tests

    @Test("Clears all messages")
    func testClear() async {
        let memory = ConversationMemory()

        await memory.add(.user("Hello"))
        await memory.add(.assistant("Hi"))

        #expect(await memory.count == 2)

        await memory.clear()

        #expect(await memory.isEmpty)
    }

    // MARK: - Batch Operations Tests

    @Test("Adds all messages in batch")
    func testAddAll() async {
        let memory = ConversationMemory()
        let messages = [
            MemoryMessage.user("1"),
            MemoryMessage.user("2"),
            MemoryMessage.user("3")
        ]

        await memory.addAll(messages)

        #expect(await memory.count == 3)
    }

    @Test("Gets recent messages")
    func testGetRecentMessages() async {
        let memory = ConversationMemory()

        for i in 1...10 {
            await memory.add(.user("Message \(i)"))
        }

        let recent = await memory.getRecentMessages(3)

        #expect(recent.count == 3)
        #expect(recent[0].content == "Message 8")
        #expect(recent[2].content == "Message 10")
    }

    @Test("Gets oldest messages")
    func testGetOldestMessages() async {
        let memory = ConversationMemory()

        for i in 1...10 {
            await memory.add(.user("Message \(i)"))
        }

        let oldest = await memory.getOldestMessages(3)

        #expect(oldest.count == 3)
        #expect(oldest[0].content == "Message 1")
        #expect(oldest[2].content == "Message 3")
    }

    // MARK: - Query Operations Tests

    @Test("Filters messages by predicate")
    func testFilter() async {
        let memory = ConversationMemory()

        await memory.add(.user("Hello"))
        await memory.add(.assistant("Hi"))
        await memory.add(.user("How are you?"))

        let userMessages = await memory.filter { $0.role == .user }

        #expect(userMessages.count == 2)
    }

    @Test("Gets messages by role")
    func messagesByRole() async {
        let memory = ConversationMemory()

        await memory.add(.user("Hello"))
        await memory.add(.assistant("Hi"))
        await memory.add(.system("Be helpful"))
        await memory.add(.user("Thanks"))

        let userMessages = await memory.messages(withRole: .user)
        let systemMessages = await memory.messages(withRole: .system)

        #expect(userMessages.count == 2)
        #expect(systemMessages.count == 1)
    }

    @Test("Gets last and first message")
    func lastAndFirstMessage() async {
        let memory = ConversationMemory()

        await memory.add(.user("First"))
        await memory.add(.user("Last"))

        #expect(await memory.lastMessage?.content == "Last")
        #expect(await memory.firstMessage?.content == "First")
    }

    // MARK: - Diagnostics Tests

    @Test("Provides accurate diagnostics")
    func testDiagnostics() async {
        let memory = ConversationMemory(maxMessages: 10)

        await memory.add(.user("Hello"))
        await memory.add(.assistant("Hi"))

        let diagnostics = await memory.diagnostics()

        #expect(diagnostics.messageCount == 2)
        #expect(diagnostics.maxMessages == 10)
        #expect(diagnostics.utilizationPercent == 20.0)
        #expect(diagnostics.oldestTimestamp != nil)
        #expect(diagnostics.newestTimestamp != nil)
    }
}
