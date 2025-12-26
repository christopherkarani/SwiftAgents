// SessionTests.swift
// SwiftAgents Framework
//
// Tests for Session protocol requirements and default extension methods.

import Foundation
@testable import SwiftAgents
import Testing

@Suite("Session Protocol Tests")
struct SessionTests {
    // MARK: - Protocol Requirements Tests

    @Test("Session has required sessionId property")
    func sessionIdProperty() async {
        let session = InMemorySession()

        let sessionId = await session.sessionId
        #expect(!sessionId.isEmpty)
    }

    @Test("Session has required itemCount property")
    func itemCountProperty() async {
        let session = InMemorySession()

        let count = await session.itemCount
        #expect(count == 0)
    }

    @Test("Session has required isEmpty property")
    func isEmptyProperty() async {
        let session = InMemorySession()

        let empty = await session.isEmpty
        #expect(empty == true)
    }

    // MARK: - Default Extension Method Tests

    @Test("addItem extension method adds single item")
    func addItemExtension() async throws {
        let session = InMemorySession()
        let message = MemoryMessage.user("Hello")

        try await session.addItem(message)

        let count = await session.itemCount
        #expect(count == 1)
    }

    @Test("getAllItems extension method retrieves all items")
    func getAllItemsExtension() async throws {
        let session = InMemorySession()

        try await session.addItems([
            MemoryMessage.user("First"),
            MemoryMessage.assistant("Second"),
            MemoryMessage.user("Third")
        ])

        let items = try await session.getAllItems()
        #expect(items.count == 3)
    }

    @Test("getAllItems returns items in chronological order")
    func getAllItemsOrder() async throws {
        let session = InMemorySession()

        try await session.addItem(MemoryMessage.user("First"))
        try await session.addItem(MemoryMessage.assistant("Second"))
        try await session.addItem(MemoryMessage.user("Third"))

        let items = try await session.getAllItems()

        #expect(items[0].content == "First")
        #expect(items[1].content == "Second")
        #expect(items[2].content == "Third")
    }

    // MARK: - Core Method Tests

    @Test("getItems returns all items when limit is nil")
    func getItemsWithoutLimit() async throws {
        let session = InMemorySession()

        try await session.addItems([
            MemoryMessage.user("One"),
            MemoryMessage.user("Two"),
            MemoryMessage.user("Three")
        ])

        let items = try await session.getItems(limit: nil)
        #expect(items.count == 3)
    }

    @Test("getItems respects limit parameter")
    func getItemsWithLimit() async throws {
        let session = InMemorySession()

        try await session.addItems([
            MemoryMessage.user("One"),
            MemoryMessage.user("Two"),
            MemoryMessage.user("Three"),
            MemoryMessage.user("Four"),
            MemoryMessage.user("Five")
        ])

        let items = try await session.getItems(limit: 3)
        #expect(items.count == 3)
    }

    @Test("addItems adds multiple items")
    func addItemsMultiple() async throws {
        let session = InMemorySession()
        let messages = [
            MemoryMessage.user("Hello"),
            MemoryMessage.assistant("Hi there"),
            MemoryMessage.user("How are you?")
        ]

        try await session.addItems(messages)

        let count = await session.itemCount
        #expect(count == 3)
    }

    @Test("popItem removes and returns last item")
    func popItemRemovesLast() async throws {
        let session = InMemorySession()

        try await session.addItems([
            MemoryMessage.user("First"),
            MemoryMessage.user("Second"),
            MemoryMessage.user("Third")
        ])

        let popped = try await session.popItem()

        #expect(popped?.content == "Third")
        #expect(await session.itemCount == 2)
    }

    @Test("popItem returns nil on empty session")
    func popItemEmpty() async throws {
        let session = InMemorySession()

        let popped = try await session.popItem()

        #expect(popped == nil)
    }

    @Test("clearSession removes all items")
    func clearSessionRemovesAll() async throws {
        let session = InMemorySession()

        try await session.addItems([
            MemoryMessage.user("One"),
            MemoryMessage.user("Two")
        ])

        try await session.clearSession()

        #expect(await session.isEmpty == true)
        #expect(await session.itemCount == 0)
    }

    // MARK: - State Consistency Tests

    @Test("isEmpty returns false after adding items")
    func isEmptyAfterAdd() async throws {
        let session = InMemorySession()

        #expect(await session.isEmpty == true)

        try await session.addItem(MemoryMessage.user("Hello"))

        #expect(await session.isEmpty == false)
    }

    @Test("isEmpty returns true after clearing")
    func isEmptyAfterClear() async throws {
        let session = InMemorySession()

        try await session.addItem(MemoryMessage.user("Hello"))
        try await session.clearSession()

        #expect(await session.isEmpty == true)
    }

    @Test("itemCount updates correctly through operations")
    func itemCountUpdates() async throws {
        let session = InMemorySession()

        #expect(await session.itemCount == 0)

        try await session.addItem(MemoryMessage.user("One"))
        #expect(await session.itemCount == 1)

        try await session.addItems([
            MemoryMessage.user("Two"),
            MemoryMessage.user("Three")
        ])
        #expect(await session.itemCount == 3)

        _ = try await session.popItem()
        #expect(await session.itemCount == 2)

        try await session.clearSession()
        #expect(await session.itemCount == 0)
    }
}
