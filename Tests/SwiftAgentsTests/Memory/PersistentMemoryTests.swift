// PersistentMemoryTests.swift
// SwiftAgents Framework

import Foundation
@testable import SwiftAgents
import Testing

// MARK: - PersistentMemoryTests

@Suite("PersistentMemory Tests")
struct PersistentMemoryTests {
    @Test("InMemoryBackend stores and retrieves messages")
    func inMemoryBackendBasics() async throws {
        let backend = InMemoryBackend()
        let memory = PersistentMemory(backend: backend, conversationId: "test-1")

        await memory.add(.user("Hello"))
        await memory.add(.assistant("Hi there!"))

        #expect(await memory.count == 2)

        let messages = await memory.allMessages()
        #expect(messages.count == 2)
        #expect(messages[0].role == .user)
        #expect(messages[0].content == "Hello")
        #expect(messages[1].role == .assistant)
    }

    @Test("PersistentMemory respects maxMessages")
    func testMaxMessages() async throws {
        let backend = InMemoryBackend()
        let memory = PersistentMemory(
            backend: backend,
            conversationId: "test-2",
            maxMessages: 3
        )

        await memory.add(.user("Message 1"))
        await memory.add(.assistant("Response 1"))
        await memory.add(.user("Message 2"))
        await memory.add(.assistant("Response 2"))
        await memory.add(.user("Message 3"))

        // Should have trimmed to 3 messages (oldest 2 removed)
        #expect(await memory.count == 3)

        let messages = await memory.allMessages()
        // After trimming, the oldest 2 messages (Message 1, Response 1) are removed
        // Remaining: Message 2, Response 2, Message 3
        #expect(messages[0].content == "Message 2")
        #expect(messages[1].content == "Response 2")
        #expect(messages[2].content == "Message 3")
    }

    @Test("Clear removes all messages")
    func testClear() async throws {
        let backend = InMemoryBackend()
        let memory = PersistentMemory(backend: backend, conversationId: "test-3")

        await memory.add(.user("Hello"))
        await memory.add(.assistant("Hi"))

        await memory.clear()

        #expect(await memory.isEmpty)
    }

    @Test("Different conversations are isolated")
    func conversationIsolation() async throws {
        let backend = InMemoryBackend()

        let memory1 = PersistentMemory(backend: backend, conversationId: "conv-1")
        let memory2 = PersistentMemory(backend: backend, conversationId: "conv-2")

        await memory1.add(.user("Hello from conv 1"))
        await memory2.add(.user("Hello from conv 2"))
        await memory2.add(.assistant("Response in conv 2"))

        #expect(await memory1.count == 1)
        #expect(await memory2.count == 2)
    }

    @Test("getContext formats messages within token limit")
    func testGetContext() async throws {
        let backend = InMemoryBackend()
        let memory = PersistentMemory(backend: backend, conversationId: "test-4")

        await memory.add(.user("What is 2+2?"))
        await memory.add(.assistant("2+2 equals 4."))

        let context = await memory.context(for: "math", tokenLimit: 1000)

        #expect(context.contains("What is 2+2?"))
        #expect(context.contains("2+2 equals 4."))
    }

    @Test("getRecentMessages returns limited results")
    func testGetRecentMessages() async throws {
        let backend = InMemoryBackend()
        let memory = PersistentMemory(backend: backend, conversationId: "test-5")

        await memory.add(.user("Message 1"))
        await memory.add(.assistant("Response 1"))
        await memory.add(.user("Message 2"))
        await memory.add(.assistant("Response 2"))
        await memory.add(.user("Message 3"))

        let recent = await memory.getRecentMessages(limit: 2)

        #expect(recent.count == 2)
        #expect(recent[0].content == "Response 2")
        #expect(recent[1].content == "Message 3")
    }
}

// MARK: - InMemoryBackendTests

@Suite("InMemoryBackend Tests")
struct InMemoryBackendTests {
    @Test("allConversationIds returns all conversations")
    func testAllConversationIds() async throws {
        let backend = InMemoryBackend()

        try await backend.store(.user("Hello"), conversationId: "conv-a")
        try await backend.store(.user("Hi"), conversationId: "conv-b")
        try await backend.store(.user("Hey"), conversationId: "conv-c")

        let ids = try await backend.allConversationIds()

        #expect(ids.count == 3)
        #expect(ids.contains("conv-a"))
        #expect(ids.contains("conv-b"))
        #expect(ids.contains("conv-c"))
    }

    @Test("storeAll stores multiple messages")
    func testStoreAll() async throws {
        let backend = InMemoryBackend()

        let messages: [MemoryMessage] = [
            .user("Message 1"),
            .assistant("Response 1"),
            .user("Message 2")
        ]

        try await backend.storeAll(messages, conversationId: "batch-test")

        let retrieved = try await backend.fetchMessages(conversationId: "batch-test")
        #expect(retrieved.count == 3)
    }

    @Test("clearAll removes all data")
    func testClearAll() async throws {
        let backend = InMemoryBackend()

        try await backend.store(.user("Hello"), conversationId: "conv-1")
        try await backend.store(.user("Hi"), conversationId: "conv-2")

        await backend.clearAll()

        #expect(await backend.conversationCount == 0)
        #expect(await backend.totalMessageCount == 0)
    }
}
