// InMemorySessionTests.swift
// SwiftAgents Framework
//
// Comprehensive tests for InMemorySession actor implementation.

import Foundation
@testable import SwiftAgents
import Testing

@Suite("InMemorySession Tests")
struct InMemorySessionTests {
    // MARK: - Initialization Tests

    @Test("Creates with default UUID session ID")
    func defaultSessionId() async {
        let session = InMemorySession()

        let sessionId = await session.sessionId
        #expect(!sessionId.isEmpty)

        // Verify it looks like a UUID (contains hyphens, 36 chars)
        #expect(sessionId.count == 36)
        #expect(sessionId.contains("-"))
    }

    @Test("Creates with custom session ID")
    func customSessionId() async {
        let customId = "my-custom-session-123"
        let session = InMemorySession(sessionId: customId)

        let sessionId = await session.sessionId
        #expect(sessionId == customId)
    }

    @Test("Each default session has unique ID")
    func uniqueDefaultIds() async {
        let session1 = InMemorySession()
        let session2 = InMemorySession()

        let id1 = await session1.sessionId
        let id2 = await session2.sessionId

        #expect(id1 != id2)
    }

    @Test("Starts with empty state")
    func startsEmpty() async {
        let session = InMemorySession()

        #expect(await session.isEmpty == true)
        #expect(await session.itemCount == 0)
    }

    // MARK: - Add and Retrieve Tests

    @Test("Adds single item successfully")
    func addSingleItem() async throws {
        let session = InMemorySession()
        let message = MemoryMessage.user("Hello, world!")

        try await session.addItem(message)

        let items = try await session.getAllItems()
        #expect(items.count == 1)
        #expect(items[0].content == "Hello, world!")
        #expect(items[0].role == .user)
    }

    @Test("Adds multiple items in batch")
    func addMultipleItems() async throws {
        let session = InMemorySession()
        let messages = [
            MemoryMessage.user("First message"),
            MemoryMessage.assistant("Second message"),
            MemoryMessage.system("Third message")
        ]

        try await session.addItems(messages)

        #expect(await session.itemCount == 3)
    }

    @Test("Preserves message properties after storage")
    func preservesMessageProperties() async throws {
        let session = InMemorySession()

        let originalId = UUID()
        let originalTimestamp = Date()
        let originalMetadata = ["key": "value", "source": "test"]

        let message = MemoryMessage(
            id: originalId,
            role: .assistant,
            content: "Test content",
            timestamp: originalTimestamp,
            metadata: originalMetadata
        )

        try await session.addItem(message)

        let items = try await session.getAllItems()
        let retrieved = items[0]

        #expect(retrieved.id == originalId)
        #expect(retrieved.role == .assistant)
        #expect(retrieved.content == "Test content")
        #expect(retrieved.timestamp == originalTimestamp)
        #expect(retrieved.metadata == originalMetadata)
    }

    // MARK: - Chronological Order Tests

    @Test("Maintains chronological order")
    func maintainsChronologicalOrder() async throws {
        let session = InMemorySession()

        try await session.addItem(MemoryMessage.user("First"))
        try await session.addItem(MemoryMessage.assistant("Second"))
        try await session.addItem(MemoryMessage.user("Third"))
        try await session.addItem(MemoryMessage.assistant("Fourth"))

        let items = try await session.getAllItems()

        #expect(items[0].content == "First")
        #expect(items[1].content == "Second")
        #expect(items[2].content == "Third")
        #expect(items[3].content == "Fourth")
    }

    @Test("Batch add preserves order within batch")
    func batchAddPreservesOrder() async throws {
        let session = InMemorySession()

        let messages = [
            MemoryMessage.user("A"),
            MemoryMessage.user("B"),
            MemoryMessage.user("C"),
            MemoryMessage.user("D")
        ]

        try await session.addItems(messages)

        let items = try await session.getAllItems()

        #expect(items[0].content == "A")
        #expect(items[1].content == "B")
        #expect(items[2].content == "C")
        #expect(items[3].content == "D")
    }

    // MARK: - Limited Retrieval Tests

    @Test("getItems with limit returns last N items")
    func getItemsWithLimit() async throws {
        let session = InMemorySession()

        for i in 1...10 {
            try await session.addItem(MemoryMessage.user("Message \(i)"))
        }

        let lastThree = try await session.getItems(limit: 3)

        #expect(lastThree.count == 3)
        #expect(lastThree[0].content == "Message 8")
        #expect(lastThree[1].content == "Message 9")
        #expect(lastThree[2].content == "Message 10")
    }

    @Test("getItems with limit larger than count returns all items")
    func getItemsWithLargeLimitReturnsAll() async throws {
        let session = InMemorySession()

        try await session.addItems([
            MemoryMessage.user("One"),
            MemoryMessage.user("Two"),
            MemoryMessage.user("Three")
        ])

        let items = try await session.getItems(limit: 100)

        #expect(items.count == 3)
    }

    @Test("getItems with limit of zero returns empty array")
    func getItemsWithZeroLimit() async throws {
        let session = InMemorySession()

        try await session.addItems([
            MemoryMessage.user("One"),
            MemoryMessage.user("Two")
        ])

        let items = try await session.getItems(limit: 0)

        #expect(items.isEmpty)
    }

    @Test("getItems with nil limit returns all items")
    func getItemsWithNilLimit() async throws {
        let session = InMemorySession()

        for i in 1...5 {
            try await session.addItem(MemoryMessage.user("Message \(i)"))
        }

        let items = try await session.getItems(limit: nil)

        #expect(items.count == 5)
    }

    // MARK: - Pop Item Tests (LIFO Behavior)

    @Test("popItem returns last added item")
    func popItemReturnsLast() async throws {
        let session = InMemorySession()

        try await session.addItem(MemoryMessage.user("First"))
        try await session.addItem(MemoryMessage.user("Second"))
        try await session.addItem(MemoryMessage.user("Third"))

        let popped = try await session.popItem()

        #expect(popped?.content == "Third")
    }

    @Test("popItem removes the item from session")
    func popItemRemoves() async throws {
        let session = InMemorySession()

        try await session.addItems([
            MemoryMessage.user("First"),
            MemoryMessage.user("Second"),
            MemoryMessage.user("Third")
        ])

        _ = try await session.popItem()

        let remaining = try await session.getAllItems()
        #expect(remaining.count == 2)
        #expect(remaining[0].content == "First")
        #expect(remaining[1].content == "Second")
    }

    @Test("Multiple pops follow LIFO order")
    func multiplePopLIFO() async throws {
        let session = InMemorySession()

        try await session.addItems([
            MemoryMessage.user("First"),
            MemoryMessage.user("Second"),
            MemoryMessage.user("Third")
        ])

        let pop1 = try await session.popItem()
        let pop2 = try await session.popItem()
        let pop3 = try await session.popItem()

        #expect(pop1?.content == "Third")
        #expect(pop2?.content == "Second")
        #expect(pop3?.content == "First")
        #expect(await session.isEmpty == true)
    }

    @Test("popItem on empty session returns nil")
    func popItemOnEmptySession() async throws {
        let session = InMemorySession()

        let result = try await session.popItem()

        #expect(result == nil)
    }

    @Test("popItem on empty session does not throw")
    func popItemOnEmptyDoesNotThrow() async throws {
        let session = InMemorySession()

        // Should not throw
        _ = try await session.popItem()
        _ = try await session.popItem()
        _ = try await session.popItem()

        #expect(await session.isEmpty == true)
    }

    // MARK: - Clear Session Tests

    @Test("clearSession removes all items")
    func clearSessionRemovesAll() async throws {
        let session = InMemorySession()

        try await session.addItems([
            MemoryMessage.user("One"),
            MemoryMessage.assistant("Two"),
            MemoryMessage.user("Three")
        ])

        try await session.clearSession()

        #expect(await session.isEmpty == true)
        #expect(await session.itemCount == 0)
    }

    @Test("clearSession on empty session is safe")
    func clearEmptySessionIsSafe() async throws {
        let session = InMemorySession()

        // Should not throw
        try await session.clearSession()

        #expect(await session.isEmpty == true)
    }

    @Test("Session is reusable after clear")
    func sessionReusableAfterClear() async throws {
        let session = InMemorySession()

        try await session.addItem(MemoryMessage.user("Before clear"))
        try await session.clearSession()
        try await session.addItem(MemoryMessage.user("After clear"))

        let items = try await session.getAllItems()
        #expect(items.count == 1)
        #expect(items[0].content == "After clear")
    }

    // MARK: - Item Count Tests

    @Test("itemCount reflects actual count")
    func itemCountReflectsActual() async throws {
        let session = InMemorySession()

        #expect(await session.itemCount == 0)

        try await session.addItem(MemoryMessage.user("One"))
        #expect(await session.itemCount == 1)

        try await session.addItem(MemoryMessage.user("Two"))
        #expect(await session.itemCount == 2)

        try await session.addItem(MemoryMessage.user("Three"))
        #expect(await session.itemCount == 3)
    }

    @Test("itemCount updates after pop")
    func itemCountUpdatesAfterPop() async throws {
        let session = InMemorySession()

        try await session.addItems([
            MemoryMessage.user("One"),
            MemoryMessage.user("Two"),
            MemoryMessage.user("Three")
        ])

        #expect(await session.itemCount == 3)

        _ = try await session.popItem()
        #expect(await session.itemCount == 2)

        _ = try await session.popItem()
        #expect(await session.itemCount == 1)
    }

    // MARK: - isEmpty Property Tests

    @Test("isEmpty is true for new session")
    func isEmptyTrueForNew() async {
        let session = InMemorySession()

        #expect(await session.isEmpty == true)
    }

    @Test("isEmpty is false after adding items")
    func isEmptyFalseAfterAdd() async throws {
        let session = InMemorySession()

        try await session.addItem(MemoryMessage.user("Test"))

        #expect(await session.isEmpty == false)
    }

    @Test("isEmpty becomes true after removing all items")
    func isEmptyAfterRemovingAll() async throws {
        let session = InMemorySession()

        try await session.addItem(MemoryMessage.user("Only item"))
        _ = try await session.popItem()

        #expect(await session.isEmpty == true)
    }

    // MARK: - Large Data Tests

    @Test("Handles large number of items")
    func handlesLargeNumberOfItems() async throws {
        let session = InMemorySession()
        let itemCount = 1000

        for i in 1...itemCount {
            try await session.addItem(MemoryMessage.user("Message \(i)"))
        }

        #expect(await session.itemCount == itemCount)

        let items = try await session.getAllItems()
        #expect(items.count == itemCount)
        #expect(items[0].content == "Message 1")
        #expect(items[itemCount - 1].content == "Message \(itemCount)")
    }

    @Test("getItems with limit works on large dataset")
    func getItemsLimitOnLargeDataset() async throws {
        let session = InMemorySession()

        for i in 1...500 {
            try await session.addItem(MemoryMessage.user("Message \(i)"))
        }

        let lastTen = try await session.getItems(limit: 10)

        #expect(lastTen.count == 10)
        #expect(lastTen[0].content == "Message 491")
        #expect(lastTen[9].content == "Message 500")
    }

    // MARK: - Concurrent Access Tests

    @Test("Handles concurrent reads safely")
    func concurrentReadsSafe() async throws {
        let session = InMemorySession()

        try await session.addItems([
            MemoryMessage.user("One"),
            MemoryMessage.user("Two"),
            MemoryMessage.user("Three")
        ])

        // Perform multiple concurrent reads
        await withTaskGroup(of: Int.self) { group in
            for _ in 1...10 {
                group.addTask {
                    await session.itemCount
                }
            }

            var results: [Int] = []
            for await count in group {
                results.append(count)
            }

            // All reads should return the same value
            #expect(results.allSatisfy { $0 == 3 })
        }
    }

    @Test("Handles concurrent writes safely")
    func concurrentWritesSafe() async throws {
        let session = InMemorySession()
        let writeCount = 100

        // Perform concurrent writes
        await withTaskGroup(of: Void.self) { group in
            for i in 1...writeCount {
                group.addTask {
                    try? await session.addItem(MemoryMessage.user("Message \(i)"))
                }
            }
        }

        // All writes should have completed
        let count = await session.itemCount
        #expect(count == writeCount)
    }

    @Test("Handles mixed concurrent operations safely")
    func mixedConcurrentOperations() async throws {
        let session = InMemorySession()

        // Pre-populate
        try await session.addItems([
            MemoryMessage.user("Initial 1"),
            MemoryMessage.user("Initial 2"),
            MemoryMessage.user("Initial 3")
        ])

        // Perform mixed concurrent operations
        await withTaskGroup(of: Void.self) { group in
            // Concurrent reads
            for _ in 1...5 {
                group.addTask {
                    _ = await session.itemCount
                    _ = try? await session.getAllItems()
                }
            }

            // Concurrent writes
            for i in 1...5 {
                group.addTask {
                    try? await session.addItem(MemoryMessage.user("Concurrent \(i)"))
                }
            }
        }

        // Session should be in a consistent state
        let finalCount = await session.itemCount
        #expect(finalCount >= 3) // At least the initial items
    }

    // MARK: - Edge Cases

    @Test("Handles empty content messages")
    func handlesEmptyContent() async throws {
        let session = InMemorySession()

        try await session.addItem(MemoryMessage.user(""))

        let items = try await session.getAllItems()
        #expect(items.count == 1)
        #expect(items[0].content == "")
    }

    @Test("Handles messages with special characters")
    func handlesSpecialCharacters() async throws {
        let session = InMemorySession()
        let specialContent = "Hello\n\t\"World\" <>&'\u{0000}"

        try await session.addItem(MemoryMessage.user(specialContent))

        let items = try await session.getAllItems()
        #expect(items[0].content == specialContent)
    }

    @Test("Handles unicode content")
    func handlesUnicodeContent() async throws {
        let session = InMemorySession()
        let unicodeContent = "Hello World! Emoji: 😀🎉 Chinese: 你好 Arabic: مرحبا"

        try await session.addItem(MemoryMessage.user(unicodeContent))

        let items = try await session.getAllItems()
        #expect(items[0].content == unicodeContent)
    }

    @Test("Handles very long content")
    func handlesVeryLongContent() async throws {
        let session = InMemorySession()
        let longContent = String(repeating: "a", count: 100_000)

        try await session.addItem(MemoryMessage.user(longContent))

        let items = try await session.getAllItems()
        #expect(items[0].content == longContent)
        #expect(items[0].content.count == 100_000)
    }

    @Test("All message roles are supported")
    func allRolesSupported() async throws {
        let session = InMemorySession()

        try await session.addItems([
            MemoryMessage.user("User message"),
            MemoryMessage.assistant("Assistant message"),
            MemoryMessage.system("System message"),
            MemoryMessage.tool("Tool output", toolName: "calculator")
        ])

        let items = try await session.getAllItems()

        #expect(items[0].role == .user)
        #expect(items[1].role == .assistant)
        #expect(items[2].role == .system)
        #expect(items[3].role == .tool)
    }

    // MARK: - Session Identity Tests

    @Test("Session ID remains constant throughout lifecycle")
    func sessionIdConstant() async throws {
        let session = InMemorySession(sessionId: "constant-id")

        let id1 = await session.sessionId

        try await session.addItem(MemoryMessage.user("Test"))
        let id2 = await session.sessionId

        try await session.clearSession()
        let id3 = await session.sessionId

        #expect(id1 == "constant-id")
        #expect(id2 == "constant-id")
        #expect(id3 == "constant-id")
    }
}
