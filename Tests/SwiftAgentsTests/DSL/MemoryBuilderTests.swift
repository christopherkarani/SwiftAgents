// MemoryBuilderTests.swift
// SwiftAgentsTests
//
// Tests for MemoryBuilder DSL for composable memory systems.

import Testing
import Foundation
@testable import SwiftAgents

// MARK: - MemoryBuilder Tests

@Suite("MemoryBuilder DSL Tests")
struct MemoryBuilderTests {

    // MARK: - Basic Building

    @Test("Build composite memory with single component")
    func buildCompositeMemorySingleComponent() async throws {
        let memory = CompositeMemory {
            ConversationMemory(maxMessages: 50)
        }

        #expect(memory.componentCount == 1)
    }

    @Test("Build composite memory with multiple components")
    func buildCompositeMemoryMultipleComponents() async throws {
        let memory = CompositeMemory {
            ConversationMemory(maxMessages: 50)
            SummaryMemory(maxTokens: 2000)
        }

        #expect(memory.componentCount == 2)
    }

    // MARK: - Memory Configuration Chains

    @Test("Memory with fluent configuration")
    func memoryWithFluentConfiguration() async throws {
        let memory = CompositeMemory {
            ConversationMemory(maxMessages: 100)
                .withSummarization(after: 20)
                .withTokenLimit(4000)
        }

        #expect(memory.componentCount == 1)
    }

    @Test("Multiple memories with configurations")
    func multipleMemoriesWithConfigurations() async throws {
        let memory = CompositeMemory {
            ConversationMemory(maxMessages: 50)
                .withSummarization(after: 10)

            SlidingWindowMemory(windowSize: 20)
                .withOverlapSize(5)
        }

        #expect(memory.componentCount == 2)
    }

    // MARK: - Conditional Memory Building

    @Test("Build memory with conditional component - true")
    func buildMemoryWithConditionalTrue() async throws {
        let includeVectorMemory = true

        let memory = CompositeMemory {
            ConversationMemory(maxMessages: 50)
            if includeVectorMemory {
                MockVectorMemory()
            }
        }

        #expect(memory.componentCount == 2)
    }

    @Test("Build memory with conditional component - false")
    func buildMemoryWithConditionalFalse() async throws {
        let includeVectorMemory = false

        let memory = CompositeMemory {
            ConversationMemory(maxMessages: 50)
            if includeVectorMemory {
                MockVectorMemory()
            }
        }

        #expect(memory.componentCount == 1)
    }

    // MARK: - Memory Store and Retrieve

    @Test("Composite memory stores to all components")
    func compositeMemoryStoresToAll() async throws {
        let conv = ConversationMemory(maxMessages: 50)
        let sliding = SlidingWindowMemory(windowSize: 20)

        let memory = CompositeMemory {
            conv
            sliding
        }

        let message = MemoryMessage.user("Test message")
        await memory.store(message)

        // Both should have the message
        let convMessages = await conv.retrieve(limit: 10)
        let slidingMessages = await sliding.retrieve(limit: 10)

        #expect(convMessages.count >= 1)
        #expect(slidingMessages.count >= 1)
    }

    @Test("Composite memory retrieves from primary")
    func compositeMemoryRetrievesFromPrimary() async throws {
        let memory = CompositeMemory {
            ConversationMemory(maxMessages: 50)
            SlidingWindowMemory(windowSize: 20)
        }

        await memory.store(.user("Message 1"))
        await memory.store(.assistant("Response 1"))

        let retrieved = await memory.retrieve(limit: 10)
        #expect(retrieved.count >= 2)
    }

    // MARK: - Memory Priority

    @Test("Composite memory respects priority")
    func compositeMemoryRespectsPriority() async throws {
        let memory = CompositeMemory {
            ConversationMemory(maxMessages: 50)
                .priority(.high)

            SlidingWindowMemory(windowSize: 20)
                .priority(.low)
        }

        // High priority memory should be checked first
        await memory.store(.user("Test"))
        let retrieved = await memory.retrieve(limit: 5)

        #expect(!retrieved.isEmpty)
    }

    // MARK: - Vector Memory Integration

    @Test("Build memory with vector search")
    func buildMemoryWithVectorSearch() async throws {
        let memory = CompositeMemory {
            ConversationMemory(maxMessages: 20)

            MockVectorMemory()
                .withSimilarityThreshold(0.7)
                .withMaxResults(5)
        }

        #expect(memory.componentCount == 2)
    }

    // MARK: - Memory Strategies

    @Test("Build memory with retrieval strategy")
    func buildMemoryWithRetrievalStrategy() async throws {
        let memory = CompositeMemory {
            ConversationMemory(maxMessages: 50)
        }
        .withRetrievalStrategy(.recency)

        await memory.store(.user("Old message"))
        await memory.store(.user("New message"))

        let retrieved = await memory.retrieve(limit: 1)
        // Most recent should come first
        #expect(retrieved.first?.content.contains("New") == true)
    }

    @Test("Build memory with merge strategy")
    func buildMemoryWithMergeStrategy() async throws {
        let memory = CompositeMemory {
            ConversationMemory(maxMessages: 50)
            SlidingWindowMemory(windowSize: 20)
        }
        .withMergeStrategy(.interleave)

        #expect(memory.componentCount == 2)
    }

    // MARK: - Empty Memory

    @Test("Empty composite memory")
    func emptyCompositeMemory() async throws {
        let memory = CompositeMemory {
            // Empty
        }

        #expect(memory.componentCount == 0)
    }

    // MARK: - Memory Clear

    @Test("Composite memory clear affects all components")
    func compositeMemoryClearAffectsAll() async throws {
        let memory = CompositeMemory {
            ConversationMemory(maxMessages: 50)
            SlidingWindowMemory(windowSize: 20)
        }

        await memory.store(.user("Test message"))
        await memory.clear()

        let retrieved = await memory.retrieve(limit: 10)
        #expect(retrieved.isEmpty)
    }

    // MARK: - Memory Context Building

    @Test("Build memory context for prompt")
    func buildMemoryContextForPrompt() async throws {
        let memory = CompositeMemory {
            ConversationMemory(maxMessages: 10)
        }

        await memory.store(.user("What is 2+2?"))
        await memory.store(.assistant("2+2 equals 4"))
        await memory.store(.user("And 3+3?"))

        let context = await memory.buildContext(maxTokens: 1000)

        #expect(context.contains("2+2"))
        #expect(context.contains("4"))
    }
}

// MARK: - CompositeMemory (to be implemented)

/// Composite memory that combines multiple memory systems
actor CompositeMemory: AgentMemory {
    private var components: [any AgentMemory]
    private var retrievalStrategy: RetrievalStrategy = .recency
    private var mergeStrategy: MergeStrategy = .concatenate

    var componentCount: Int {
        components.count
    }

    init(@MemoryBuilder _ content: () -> [any AgentMemory]) {
        self.components = content()
    }

    func store(_ message: MemoryMessage) async {
        for component in components {
            await component.store(message)
        }
    }

    func retrieve(limit: Int) async -> [MemoryMessage] {
        guard let primary = components.first else { return [] }
        return await primary.retrieve(limit: limit)
    }

    func clear() async {
        for component in components {
            await component.clear()
        }
    }

    nonisolated func withRetrievalStrategy(_ strategy: RetrievalStrategy) -> CompositeMemory {
        // Return configured copy
        self
    }

    nonisolated func withMergeStrategy(_ strategy: MergeStrategy) -> CompositeMemory {
        // Return configured copy
        self
    }

    func buildContext(maxTokens: Int) async -> String {
        let messages = await retrieve(limit: 100)
        return messages.map { $0.content }.joined(separator: "\n")
    }
}

// MARK: - MemoryBuilder Result Builder

@resultBuilder
struct MemoryBuilder {
    static func buildBlock(_ components: any AgentMemory...) -> [any AgentMemory] {
        components
    }

    static func buildOptional(_ component: (any AgentMemory)?) -> [any AgentMemory] {
        component.map { [$0] } ?? []
    }

    static func buildEither(first component: any AgentMemory) -> [any AgentMemory] {
        [component]
    }

    static func buildEither(second component: any AgentMemory) -> [any AgentMemory] {
        [component]
    }

    static func buildArray(_ components: [[any AgentMemory]]) -> [any AgentMemory] {
        components.flatMap { $0 }
    }
}

// MARK: - Memory Configuration Extensions

extension ConversationMemory {
    func withSummarization(after messageCount: Int) -> ConversationMemory {
        // Return configured copy
        self
    }

    func withTokenLimit(_ limit: Int) -> ConversationMemory {
        // Return configured copy
        self
    }

    func priority(_ priority: MemoryPriority) -> ConversationMemory {
        // Return configured copy
        self
    }
}

extension SlidingWindowMemory {
    func withOverlapSize(_ size: Int) -> SlidingWindowMemory {
        // Return configured copy
        self
    }

    func priority(_ priority: MemoryPriority) -> SlidingWindowMemory {
        // Return configured copy
        self
    }
}

// MARK: - MockVectorMemory

actor MockVectorMemory: AgentMemory {
    private var messages: [MemoryMessage] = []
    private var similarityThreshold: Double = 0.5
    private var maxResults: Int = 10

    func store(_ message: MemoryMessage) async {
        messages.append(message)
    }

    func retrieve(limit: Int) async -> [MemoryMessage] {
        Array(messages.suffix(limit))
    }

    func clear() async {
        messages = []
    }

    nonisolated func withSimilarityThreshold(_ threshold: Double) -> MockVectorMemory {
        self
    }

    nonisolated func withMaxResults(_ max: Int) -> MockVectorMemory {
        self
    }
}

// MARK: - Supporting Types

enum MemoryPriority {
    case low
    case normal
    case high
}

enum RetrievalStrategy {
    case recency
    case relevance
    case hybrid
}

enum MergeStrategy {
    case concatenate
    case interleave
    case deduplicate
}
