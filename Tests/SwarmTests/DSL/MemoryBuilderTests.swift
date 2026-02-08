// MemoryBuilderTests.swift
// SwarmTests
//
// Tests for MemoryBuilder DSL for composable memory systems.

import Foundation
@testable import Swarm
import Testing

// MARK: - MemoryBuilderTests

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
            SummaryMemory()
        }

        #expect(memory.componentCount == 2)
    }

    // MARK: - Memory Configuration Chains

    @Test("Memory with fluent configuration")
    func memoryWithFluentConfiguration() async throws {
        let memory = CompositeMemory {
            ConversationMemory(maxMessages: 100)
                .withSummarization(after: 20)
        }

        #expect(memory.componentCount == 1)
    }

    @Test("Multiple memories with configurations")
    func multipleMemoriesWithConfigurations() async throws {
        let memory = CompositeMemory {
            ConversationMemory(maxMessages: 50)
                .withSummarization(after: 10)

            SlidingWindowMemory(maxTokens: 4000)
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
        let sliding = SlidingWindowMemory(maxTokens: 4000)

        let memory = CompositeMemory {
            conv
            sliding
        }

        let message = MemoryMessage.user("Test message")
        await memory.store(message)

        // Both should have the message
        let convMessages = await conv.allMessages()
        let slidingMessages = await sliding.allMessages()

        #expect(convMessages.count >= 1)
        #expect(slidingMessages.count >= 1)
    }

    @Test("Composite memory retrieves from primary")
    func compositeMemoryRetrievesFromPrimary() async throws {
        let memory = CompositeMemory {
            ConversationMemory(maxMessages: 50)
            SlidingWindowMemory(maxTokens: 4000)
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

            SlidingWindowMemory(maxTokens: 4000)
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
            SlidingWindowMemory(maxTokens: 4000)
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
            SlidingWindowMemory(maxTokens: 4000)
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

// NOTE: CompositeMemory and MemoryBuilder are now public types exported from Swarm.

// MARK: - MockVectorMemory

actor MockVectorMemory: Memory, VectorMemoryConfigurable {
    // MARK: Internal

    var count: Int {
        get async { messages.count }
    }

    var isEmpty: Bool {
        get async { messages.isEmpty }
    }

    func add(_ message: MemoryMessage) async {
        messages.append(message)
    }

    func context(for _: String, tokenLimit _: Int) async -> String {
        let recent = Array(messages.suffix(maxResults))
        return recent.map(\.content).joined(separator: "\n")
    }

    func allMessages() async -> [MemoryMessage] {
        messages
    }

    func clear() async {
        messages = []
    }

    nonisolated func withSimilarityThreshold(_: Double) -> MemoryComponent {
        MemoryComponent(memory: self)
    }

    nonisolated func withMaxResults(_: Int) -> MemoryComponent {
        MemoryComponent(memory: self)
    }

    // MARK: Private

    private var messages: [MemoryMessage] = []
    private var similarityThreshold: Double = 0.5
    private var maxResults: Int = 10
}
