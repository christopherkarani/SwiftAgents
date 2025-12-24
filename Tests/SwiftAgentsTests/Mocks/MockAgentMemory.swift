// MockAgentMemory.swift
// SwiftAgents Framework
//
// Mock memory for testing agents and orchestration.

import Foundation
@testable import SwiftAgents

// MARK: - MockAgentMemory

/// Mock memory for testing agents and orchestration.
///
/// Provides controllable memory behavior for unit tests.
/// Tracks all method calls for verification.
///
/// ## Usage
///
/// ```swift
/// let mock = MockAgentMemory()
/// await mock.stub(context: "Custom context")
///
/// // Use with agent or orchestrator
/// let agent = SomeAgent(memory: mock)
///
/// // Verify interactions
/// #expect(await mock.addCalls.count == 2)
/// #expect(await mock.getContextCalls.count == 1)
/// ```
public actor MockAgentMemory: Memory {
    /// Internal message storage.
    public var messages: [MemoryMessage]

    /// Custom context to return from getContext().
    /// If empty, returns formatted messages.
    public var contextToReturn: String

    /// Records of all add() calls.
    public var addCalls: [MemoryMessage] = []

    /// Records of all getContext() calls.
    public var getContextCalls: [(query: String, tokenLimit: Int)] = []

    /// Records of all allMessages() calls.
    public var getAllMessagesCalls: Int = 0

    /// Records of all clear() calls.
    public var clearCalls: Int = 0

    /// Whether operations should simulate a delay.
    public var responseDelay: Duration

    public var count: Int {
        get async {
            messages.count
        }
    }

    public var isEmpty: Bool {
        get async {
            messages.isEmpty
        }
    }

    /// Returns the last message added, if any.
    public var lastAddedMessage: MemoryMessage? {
        addCalls.last
    }

    /// Returns the last getContext call parameters, if any.
    public var lastGetContextCall: (query: String, tokenLimit: Int)? {
        getContextCalls.last
    }

    /// Creates a new mock memory with configurable initial state.
    ///
    /// - Parameters:
    ///   - messages: Initial messages to seed. Default: []
    ///   - context: Context to return from getContext(). Default: "" (formats messages)
    ///   - delay: Response delay for async testing. Default: .zero
    public init(
        messages: [MemoryMessage] = [],
        context: String = "",
        delay: Duration = .zero
    ) {
        self.messages = messages
        contextToReturn = context
        responseDelay = delay
    }

    // MARK: - Memory Protocol

    public func add(_ message: MemoryMessage) async {
        if responseDelay > .zero {
            try? await Task.sleep(for: responseDelay)
        }

        addCalls.append(message)
        messages.append(message)
    }

    public func context(for query: String, tokenLimit: Int) async -> String {
        if responseDelay > .zero {
            try? await Task.sleep(for: responseDelay)
        }

        getContextCalls.append((query, tokenLimit))

        if contextToReturn.isEmpty {
            return messages.map(\.formattedContent).joined(separator: "\n")
        }
        return contextToReturn
    }

    public func allMessages() async -> [MemoryMessage] {
        if responseDelay > .zero {
            try? await Task.sleep(for: responseDelay)
        }

        getAllMessagesCalls += 1
        return messages
    }

    public func clear() async {
        if responseDelay > .zero {
            try? await Task.sleep(for: responseDelay)
        }

        clearCalls += 1
        messages.removeAll()
    }

    // MARK: - Test Helpers

    /// Resets all state to defaults.
    public func reset() {
        messages.removeAll()
        addCalls.removeAll()
        getContextCalls.removeAll()
        getAllMessagesCalls = 0
        clearCalls = 0
        contextToReturn = ""
        responseDelay = .zero
    }

    /// Pre-populates memory with messages.
    public func seed(with messages: [MemoryMessage]) {
        self.messages = messages
    }

    /// Pre-populates memory with simple text messages.
    public func seed(userMessages: [String]) {
        messages = userMessages.map { .user($0) }
    }

    /// Configures the context to return.
    public func stub(context: String) {
        contextToReturn = context
    }

    /// Verifies that add was called with a message containing the given content.
    public func wasAddedMessageContaining(_ content: String) -> Bool {
        addCalls.contains { $0.content.contains(content) }
    }

    /// Verifies that getContext was called with the given query.
    public func wasContextRequestedFor(_ query: String) -> Bool {
        getContextCalls.contains { $0.query == query }
    }
}

// MARK: - Convenience Factory

public extension MockAgentMemory {
    /// Creates a mock pre-seeded with messages.
    static func seeded(with messages: [MemoryMessage]) -> MockAgentMemory {
        MockAgentMemory(messages: messages)
    }

    /// Creates a mock that returns a fixed context.
    static func returning(context: String) -> MockAgentMemory {
        MockAgentMemory(context: context)
    }

    /// Creates a mock with a simulated response delay.
    static func withDelay(_ delay: Duration) -> MockAgentMemory {
        MockAgentMemory(delay: delay)
    }
}

// MARK: - Assertions Helpers

public extension MockAgentMemory {
    /// Returns true if no add() calls have been made.
    var wasNeverAdded: Bool {
        addCalls.isEmpty
    }

    /// Returns true if no getContext() calls have been made.
    var wasNeverQueried: Bool {
        getContextCalls.isEmpty
    }

    /// Returns true if clear() was never called.
    var wasNeverCleared: Bool {
        clearCalls == 0
    }

    /// Returns total number of operations performed.
    var totalOperations: Int {
        addCalls.count + getContextCalls.count + getAllMessagesCalls + clearCalls
    }
}
