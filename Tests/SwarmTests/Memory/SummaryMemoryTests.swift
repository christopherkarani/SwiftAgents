// SummaryMemoryTests.swift
// Swarm Framework

import Foundation
@testable import Swarm
import Testing

@Suite("SummaryMemory Tests")
struct SummaryMemoryTests {
    // MARK: - Initialization Tests

    @Test("Creates with default configuration")
    func defaultInit() async {
        let memory = SummaryMemory()

        let config = await memory.configuration
        #expect(config.recentMessageCount == 20)
        #expect(config.summarizationThreshold == 50)
        #expect(config.summaryTokenTarget == 500)
    }

    @Test("Creates with custom configuration")
    func customConfiguration() async {
        let config = SummaryMemory.Configuration(
            recentMessageCount: 10,
            summarizationThreshold: 30,
            summaryTokenTarget: 200
        )
        let memory = SummaryMemory(configuration: config)

        let memoryConfig = await memory.configuration
        #expect(memoryConfig.recentMessageCount == 10)
        #expect(memoryConfig.summarizationThreshold == 30)
    }

    @Test("Configuration enforces minimums")
    func configurationMinimums() async {
        let config = SummaryMemory.Configuration(
            recentMessageCount: 1,
            summarizationThreshold: 5,
            summaryTokenTarget: 10
        )

        #expect(config.recentMessageCount >= 5)
        #expect(config.summarizationThreshold >= 15) // recentMessageCount + 10
        #expect(config.summaryTokenTarget >= 100)
    }

    // MARK: - Add Tests

    @Test("Adds messages before threshold")
    func addBeforeThreshold() async {
        let memory = SummaryMemory(
            configuration: .init(summarizationThreshold: 100)
        )

        await memory.add(.user("Hello"))
        await memory.add(.assistant("Hi"))

        #expect(await memory.count == 2)
        #expect(await memory.hasSummary == false)
    }

    @Test("Tracks total messages added")
    func totalMessagesTracking() async {
        let memory = SummaryMemory()

        await memory.add(.user("1"))
        await memory.add(.user("2"))
        await memory.add(.user("3"))

        #expect(await memory.totalMessages == 3)
    }

    // MARK: - Summarization Tests

    @Test("Triggers summarization at threshold")
    func summarizationTrigger() async {
        let mockSummarizer = MockSummarizer()
        await mockSummarizer.stub(result: "Test summary")

        // Note: With recentMessageCount=5, minimum threshold is enforced to 15 (5+10)
        let config = SummaryMemory.Configuration(
            recentMessageCount: 5,
            summarizationThreshold: 15
        )
        let memory = SummaryMemory(
            configuration: config,
            summarizer: mockSummarizer
        )

        // Add messages to trigger summarization (>= threshold)
        for i in 1...15 {
            await memory.add(.user("Message \(i)"))
        }

        // Should have triggered summarization
        let callCount = await mockSummarizer.callCount
        #expect(callCount >= 1)
    }

    @Test("Keeps recent messages after summarization")
    func keepsRecentMessages() async {
        let mockSummarizer = MockSummarizer()
        await mockSummarizer.stub(result: "Summary of old messages")

        // Note: With recentMessageCount=5, minimum threshold is enforced to 15 (5+10)
        let config = SummaryMemory.Configuration(
            recentMessageCount: 5,
            summarizationThreshold: 15
        )
        let memory = SummaryMemory(
            configuration: config,
            summarizer: mockSummarizer
        )

        for i in 1...15 {
            await memory.add(.user("Message \(i)"))
        }

        // Should have kept only recent messages
        #expect(await memory.count == 5)
    }

    @Test("Creates summary from old messages")
    func createsSummary() async {
        let mockSummarizer = MockSummarizer()
        await mockSummarizer.stub(result: "This is the summary")

        // Note: With recentMessageCount=5, minimum threshold is enforced to 15 (5+10)
        let config = SummaryMemory.Configuration(
            recentMessageCount: 5,
            summarizationThreshold: 15
        )
        let memory = SummaryMemory(
            configuration: config,
            summarizer: mockSummarizer
        )

        for i in 1...15 {
            await memory.add(.user("Message \(i)"))
        }

        #expect(await memory.hasSummary == true)
        #expect(await memory.currentSummary == "This is the summary")
    }

    // MARK: - Fallback Tests

    @Test("Falls back when summarizer unavailable")
    func fallbackWhenUnavailable() async {
        let unavailableSummarizer = MockSummarizer()
        await unavailableSummarizer.stub(available: false)

        let fallbackSummarizer = MockSummarizer()
        await fallbackSummarizer.stub(result: "Fallback summary")

        // Note: With recentMessageCount=5, minimum threshold is enforced to 15 (5+10)
        let config = SummaryMemory.Configuration(
            recentMessageCount: 5,
            summarizationThreshold: 15
        )
        let memory = SummaryMemory(
            configuration: config,
            summarizer: unavailableSummarizer,
            fallbackSummarizer: fallbackSummarizer
        )

        for i in 1...15 {
            await memory.add(.user("Message \(i)"))
        }

        let fallbackCalls = await fallbackSummarizer.callCount
        #expect(fallbackCalls >= 1)
    }

    @Test("Handles summarization failure gracefully")
    func handlesSummarizationFailure() async {
        let failingSummarizer = MockSummarizer()
        await failingSummarizer.stub(error: SummarizerError.unavailable)

        // Note: With recentMessageCount=5, minimum threshold is enforced to 15 (5+10)
        let config = SummaryMemory.Configuration(
            recentMessageCount: 5,
            summarizationThreshold: 15
        )
        let memory = SummaryMemory(
            configuration: config,
            summarizer: failingSummarizer,
            fallbackSummarizer: failingSummarizer
        )

        // Should not crash
        for i in 1...15 {
            await memory.add(.user("Message \(i)"))
        }

        // Should still have some summary (fallback to truncation)
        // or keep recent messages
        #expect(await memory.count == 5)
    }

    // MARK: - Context Retrieval Tests

    @Test("Context includes summary when present")
    func contextIncludesSummary() async {
        let mockSummarizer = MockSummarizer()
        await mockSummarizer.stub(result: "Summary content")

        // Note: With recentMessageCount=5, minimum threshold is enforced to 15 (5+10)
        let config = SummaryMemory.Configuration(
            recentMessageCount: 5,
            summarizationThreshold: 15
        )
        let memory = SummaryMemory(
            configuration: config,
            summarizer: mockSummarizer
        )

        for i in 1...15 {
            await memory.add(.user("Message \(i)"))
        }

        let context = await memory.context(for: "test", tokenLimit: 2000)

        #expect(context.contains("summary"))
    }

    // MARK: - Clear Tests

    @Test("Clear removes messages and summary")
    func testClear() async {
        let mockSummarizer = MockSummarizer()
        await mockSummarizer.stub(result: "Test summary")

        // Note: With recentMessageCount=5, minimum threshold is enforced to 15 (5+10)
        let config = SummaryMemory.Configuration(
            recentMessageCount: 5,
            summarizationThreshold: 15
        )
        let memory = SummaryMemory(
            configuration: config,
            summarizer: mockSummarizer
        )

        for i in 1...15 {
            await memory.add(.user("Message \(i)"))
        }

        await memory.clear()

        #expect(await memory.isEmpty)
        #expect(await memory.hasSummary == false)
        #expect(await memory.totalMessages == 0)
    }

    // MARK: - Manual Operations Tests

    @Test("Force summarize works before threshold")
    func testForceSummarize() async {
        let mockSummarizer = MockSummarizer()
        await mockSummarizer.stub(result: "Forced summary")

        let config = SummaryMemory.Configuration(
            recentMessageCount: 5,
            summarizationThreshold: 100
        )
        let memory = SummaryMemory(
            configuration: config,
            summarizer: mockSummarizer
        )

        for i in 1...20 {
            await memory.add(.user("Message \(i)"))
        }

        // Before force summarize, no summary yet
        #expect(await memory.hasSummary == false)

        await memory.forceSummarize()

        #expect(await memory.hasSummary == true)
    }

    @Test("Set custom summary")
    func testSetSummary() async {
        let memory = SummaryMemory()

        await memory.setSummary("Custom summary")

        #expect(await memory.currentSummary == "Custom summary")
        #expect(await memory.hasSummary == true)
    }

    // MARK: - Diagnostics Tests

    @Test("Provides accurate diagnostics")
    func testDiagnostics() async {
        let mockSummarizer = MockSummarizer()
        await mockSummarizer.stub(result: "Test summary")

        // Note: With recentMessageCount=5, minimum threshold is enforced to 15 (5+10)
        let config = SummaryMemory.Configuration(
            recentMessageCount: 5,
            summarizationThreshold: 15
        )
        let memory = SummaryMemory(
            configuration: config,
            summarizer: mockSummarizer
        )

        for i in 1...15 {
            await memory.add(.user("Message \(i)"))
        }

        let diagnostics = await memory.diagnostics()

        #expect(diagnostics.recentMessageCount == 5)
        #expect(diagnostics.totalMessagesProcessed == 15)
        #expect(diagnostics.hasSummary == true)
        #expect(diagnostics.summarizationCount >= 1)
    }
}
