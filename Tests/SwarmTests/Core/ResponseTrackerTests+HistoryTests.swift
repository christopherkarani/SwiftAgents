// ResponseTrackerTests+HistoryTests.swift
// SwarmTests
//
// History management tests for ResponseTracker: limiting, ordering, and custom sizes.

import Foundation
@testable import Swarm
import Testing

// MARK: - ResponseTrackerHistoryTests

@Suite("ResponseTracker History Tests")
struct ResponseTrackerHistoryTests {
    // MARK: Internal

    // MARK: - History Limiting Tests (CRITICAL)

    @Test("History is limited to maxHistorySize")
    func historyLimiting() async {
        let maxSize = 5
        let tracker = ResponseTracker(maxHistorySize: maxSize)

        // Add more responses than the limit
        for i in 0..<10 {
            let response = makeTestResponse(id: "resp_\(i)", output: "Response \(i)")
            await tracker.recordResponse(response, sessionId: "session1")
        }

        // Should only have 5 (the last 5)
        let count = await tracker.getCount(for: "session1")
        #expect(count == maxSize)

        // First responses should be gone (trimmed)
        let first = await tracker.getResponse(responseId: "resp_0", sessionId: "session1")
        #expect(first == nil)

        let second = await tracker.getResponse(responseId: "resp_1", sessionId: "session1")
        #expect(second == nil)

        let third = await tracker.getResponse(responseId: "resp_4", sessionId: "session1")
        #expect(third == nil)

        // Last 5 responses should exist (resp_5 through resp_9)
        for i in 5..<10 {
            let response = await tracker.getResponse(responseId: "resp_\(i)", sessionId: "session1")
            #expect(response != nil, "Response \(i) should exist")
            #expect(response?.output == "Response \(i)")
        }
    }

    @Test("History trimming maintains FIFO order")
    func historyTrimmingMaintainsFIFOOrder() async {
        let tracker = ResponseTracker(maxHistorySize: 3)

        // Add 5 responses
        for i in 0..<5 {
            let response = makeTestResponse(id: "id_\(i)", output: "Output \(i)")
            await tracker.recordResponse(response, sessionId: "session")
        }

        // Get history and verify order
        let history = await tracker.getHistory(for: "session")

        #expect(history.count == 3)
        #expect(history[0].responseId == "id_2") // Oldest remaining
        #expect(history[1].responseId == "id_3")
        #expect(history[2].responseId == "id_4") // Newest
    }

    @Test("Bounded storage prevents unbounded growth")
    func boundedStoragePreventsUnboundedGrowth() async {
        let tracker = ResponseTracker(maxHistorySize: 10)

        // Add many responses
        for i in 0..<1000 {
            let response = makeTestResponse(id: "resp_\(i)")
            await tracker.recordResponse(response, sessionId: "stress_session")
        }

        // Should still only have 10
        let count = await tracker.getCount(for: "stress_session")
        #expect(count == 10)

        // Total count should also be 10
        let total = await tracker.getTotalResponseCount()
        #expect(total == 10)
    }

    // MARK: - History Ordering Tests

    @Test("History is in chronological order")
    func historyOrdering() async {
        let tracker = ResponseTracker()

        // Add responses with specific IDs to track order
        await tracker.recordResponse(makeTestResponse(id: "first", output: "1"), sessionId: "session1")
        await tracker.recordResponse(makeTestResponse(id: "second", output: "2"), sessionId: "session1")
        await tracker.recordResponse(makeTestResponse(id: "third", output: "3"), sessionId: "session1")

        let history = await tracker.getHistory(for: "session1")

        #expect(history.count == 3)
        #expect(history[0].responseId == "first") // Oldest first
        #expect(history[1].responseId == "second")
        #expect(history[2].responseId == "third") // Newest last
    }

    @Test("History with limit returns most recent")
    func historyWithLimit() async {
        let tracker = ResponseTracker()

        for i in 0..<10 {
            await tracker.recordResponse(
                makeTestResponse(id: "resp_\(i)", output: "Output \(i)"),
                sessionId: "session1"
            )
        }

        // Get only last 3
        let limitedHistory = await tracker.getHistory(for: "session1", limit: 3)

        #expect(limitedHistory.count == 3)
        #expect(limitedHistory[0].responseId == "resp_7") // Oldest of last 3
        #expect(limitedHistory[1].responseId == "resp_8")
        #expect(limitedHistory[2].responseId == "resp_9") // Most recent
    }

    @Test("History with limit larger than count returns all")
    func historyWithLimitLargerThanCount() async {
        let tracker = ResponseTracker()

        await tracker.recordResponse(makeTestResponse(id: "only"), sessionId: "session1")

        let history = await tracker.getHistory(for: "session1", limit: 100)

        #expect(history.count == 1)
        #expect(history[0].responseId == "only")
    }

    @Test("Empty session history returns empty array")
    func emptySessionHistoryReturnsEmptyArray() async {
        let tracker = ResponseTracker()

        let history = await tracker.getHistory(for: "empty_session")

        #expect(history.isEmpty)
    }

    // MARK: - Custom Max History Size Tests

    @Test("Custom max history size of 1")
    func customMaxHistorySizeOfOne() async {
        let tracker = ResponseTracker(maxHistorySize: 1)

        await tracker.recordResponse(makeTestResponse(id: "first"), sessionId: "session")
        await tracker.recordResponse(makeTestResponse(id: "second"), sessionId: "session")
        await tracker.recordResponse(makeTestResponse(id: "third"), sessionId: "session")

        let count = await tracker.getCount(for: "session")
        #expect(count == 1)

        let latestId = await tracker.getLatestResponseId(for: "session")
        #expect(latestId == "third")

        let firstGone = await tracker.getResponse(responseId: "first", sessionId: "session")
        #expect(firstGone == nil)
    }

    @Test("Custom large max history size")
    func customLargeMaxHistorySize() async {
        let tracker = ResponseTracker(maxHistorySize: 500)

        // Add 200 responses
        for i in 0..<200 {
            await tracker.recordResponse(makeTestResponse(id: "resp_\(i)"), sessionId: "session")
        }

        // All should be present
        let count = await tracker.getCount(for: "session")
        #expect(count == 200)

        // Check maxHistorySize is set correctly
        #expect(tracker.maxHistorySize == 500)
    }

    @Test("Default max history size is 100")
    func defaultMaxHistorySize() async {
        let tracker = ResponseTracker()

        #expect(tracker.maxHistorySize == 100)

        // Verify it works
        for i in 0..<150 {
            await tracker.recordResponse(makeTestResponse(id: "resp_\(i)"), sessionId: "session")
        }

        let count = await tracker.getCount(for: "session")
        #expect(count == 100)
    }

    // MARK: - Get Count Tests

    @Test("Get count for session")
    func testGetCount() async {
        let tracker = ResponseTracker()

        // Empty session
        let emptyCount = await tracker.getCount(for: "empty_session")
        #expect(emptyCount == 0)

        // Add responses
        await tracker.recordResponse(makeTestResponse(), sessionId: "session1")
        await tracker.recordResponse(makeTestResponse(), sessionId: "session1")
        await tracker.recordResponse(makeTestResponse(), sessionId: "session1")

        let count = await tracker.getCount(for: "session1")
        #expect(count == 3)
    }

    @Test("Get total response count")
    func testGetTotalResponseCount() async {
        let tracker = ResponseTracker()

        // Empty tracker
        let emptyTotal = await tracker.getTotalResponseCount()
        #expect(emptyTotal == 0)

        // Add responses across sessions
        await tracker.recordResponse(makeTestResponse(), sessionId: "session1")
        await tracker.recordResponse(makeTestResponse(), sessionId: "session1")
        await tracker.recordResponse(makeTestResponse(), sessionId: "session2")
        await tracker.recordResponse(makeTestResponse(), sessionId: "session3")
        await tracker.recordResponse(makeTestResponse(), sessionId: "session3")
        await tracker.recordResponse(makeTestResponse(), sessionId: "session3")

        let total = await tracker.getTotalResponseCount()
        #expect(total == 6)
    }

    // MARK: - Latest Response ID Tests

    @Test("Get latest response ID")
    func latestResponseId() async {
        let tracker = ResponseTracker()

        // Add responses in order
        await tracker.recordResponse(makeTestResponse(id: "first"), sessionId: "session1")
        await tracker.recordResponse(makeTestResponse(id: "second"), sessionId: "session1")
        await tracker.recordResponse(makeTestResponse(id: "third"), sessionId: "session1")

        let latestId = await tracker.getLatestResponseId(for: "session1")

        #expect(latestId == "third")
    }

    @Test("Latest response ID for empty session returns nil")
    func latestResponseIdForEmptySessionReturnsNil() async {
        let tracker = ResponseTracker()

        let latestId = await tracker.getLatestResponseId(for: "empty_session")

        #expect(latestId == nil)
    }

    @Test("Latest response ID after clear returns nil")
    func latestResponseIdAfterClearReturnsNil() async {
        let tracker = ResponseTracker()

        await tracker.recordResponse(makeTestResponse(id: "test"), sessionId: "session1")
        await tracker.clearHistory(for: "session1")

        let latestId = await tracker.getLatestResponseId(for: "session1")

        #expect(latestId == nil)
    }

    // MARK: Private

    // MARK: - Test Helpers

    private func makeTestResponse(
        id: String = UUID().uuidString,
        output: String = "test output",
        agentName: String = "TestAgent",
        timestamp: Date = Date()
    ) -> AgentResponse {
        AgentResponse(
            responseId: id,
            output: output,
            agentName: agentName,
            timestamp: timestamp,
            metadata: [:],
            toolCalls: [],
            usage: nil
        )
    }
}
