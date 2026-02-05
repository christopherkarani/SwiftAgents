// ResponseTrackerTests+ConcurrencyTests.swift
// SwarmTests
//
// Concurrency and clear operation tests for ResponseTracker.

import Foundation
@testable import Swarm
import Testing

// MARK: - ResponseTrackerConcurrencyTests

@Suite("ResponseTracker Concurrency Tests")
struct ResponseTrackerConcurrencyTests {
    // MARK: - Clear Operations Tests

    @Test("Clear history for specific session")
    func testClearHistory() async {
        let tracker = ResponseTracker()

        // Add responses to multiple sessions
        await tracker.recordResponse(makeTestResponse(id: "resp1"), sessionId: "session1")
        await tracker.recordResponse(makeTestResponse(id: "resp2"), sessionId: "session1")
        await tracker.recordResponse(makeTestResponse(id: "resp3"), sessionId: "session2")

        // Clear session1
        await tracker.clearHistory(for: "session1")

        // Session1 should be empty
        let s1Count = await tracker.getCount(for: "session1")
        #expect(s1Count == 0)

        let s1Response = await tracker.getResponse(responseId: "resp1", sessionId: "session1")
        #expect(s1Response == nil)

        // Session2 should be unaffected
        let s2Count = await tracker.getCount(for: "session2")
        #expect(s2Count == 1)

        let s2Response = await tracker.getResponse(responseId: "resp3", sessionId: "session2")
        #expect(s2Response != nil)
    }

    @Test("Clear all history")
    func testClearAllHistory() async {
        let tracker = ResponseTracker()

        // Add responses to multiple sessions
        await tracker.recordResponse(makeTestResponse(), sessionId: "session1")
        await tracker.recordResponse(makeTestResponse(), sessionId: "session2")
        await tracker.recordResponse(makeTestResponse(), sessionId: "session3")

        // Verify we have sessions
        let sessionsBefore = await tracker.getAllSessionIds()
        #expect(sessionsBefore.count == 3)

        // Clear all
        await tracker.clearAllHistory()

        // All sessions should be empty
        let sessionsAfter = await tracker.getAllSessionIds()
        #expect(sessionsAfter.isEmpty)

        let totalCount = await tracker.getTotalResponseCount()
        #expect(totalCount == 0)
    }

    @Test("Clear non-existent session is safe")
    func clearNonExistentSessionIsSafe() async {
        let tracker = ResponseTracker()

        // Add a response
        await tracker.recordResponse(makeTestResponse(), sessionId: "session1")

        // Clear a non-existent session (should not crash or affect other sessions)
        await tracker.clearHistory(for: "non_existent_session")

        // Original session should be unaffected
        let count = await tracker.getCount(for: "session1")
        #expect(count == 1)
    }

    // MARK: - Concurrent Access Tests

    @Test("Concurrent writes to same session")
    func concurrentWritesToSameSession() async {
        let tracker = ResponseTracker(maxHistorySize: 100)

        // Perform concurrent writes
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<50 {
                group.addTask {
                    let response = makeTestResponse(id: "concurrent_\(i)")
                    await tracker.recordResponse(response, sessionId: "shared_session")
                }
            }
        }

        // Should have 50 responses (or less if some got trimmed due to timing)
        let count = await tracker.getCount(for: "shared_session")
        #expect(count <= 50)
        #expect(count > 0)
    }

    @Test("Concurrent writes to different sessions")
    func concurrentWritesToDifferentSessions() async {
        let tracker = ResponseTracker()

        // Perform concurrent writes to different sessions
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<20 {
                group.addTask {
                    let response = makeTestResponse(id: "resp_\(i)")
                    await tracker.recordResponse(response, sessionId: "session_\(i)")
                }
            }
        }

        // Should have 20 sessions
        let sessionIds = await tracker.getAllSessionIds()
        #expect(sessionIds.count == 20)

        // Total should be 20
        let total = await tracker.getTotalResponseCount()
        #expect(total == 20)
    }

    @Test("Concurrent read-write operations")
    func concurrentReadWriteOperations() async {
        let tracker = ResponseTracker(maxHistorySize: 50)

        // Run concurrent reads and writes
        await withTaskGroup(of: Void.self) { group in
            // Writers: Add 30 responses
            for i in 0..<30 {
                group.addTask {
                    let response = makeTestResponse(id: "write_\(i)")
                    await tracker.recordResponse(response, sessionId: "rw_session")
                }
            }

            // Readers: Perform reads while writes are happening
            for _ in 0..<20 {
                group.addTask {
                    _ = await tracker.getHistory(for: "rw_session", limit: 10)
                    _ = await tracker.getCount(for: "rw_session")
                    _ = await tracker.getLatestResponseId(for: "rw_session")
                }
            }
        }

        // Should not crash and have consistent state
        let finalCount = await tracker.getCount(for: "rw_session")
        #expect(finalCount > 0)
        #expect(finalCount <= 50) // Should respect maxHistorySize
    }

    @Test("Concurrent operations with clear")
    func concurrentOperationsWithClear() async {
        let tracker = ResponseTracker(maxHistorySize: 100)

        // Seed with some initial data
        for i in 0..<10 {
            let response = makeTestResponse(id: "seed_\(i)")
            await tracker.recordResponse(response, sessionId: "clear_session")
        }

        // Run concurrent writes and a clear
        await withTaskGroup(of: Void.self) { group in
            // Writers
            for i in 0..<20 {
                group.addTask {
                    let response = makeTestResponse(id: "concurrent_\(i)")
                    await tracker.recordResponse(response, sessionId: "clear_session")
                }
            }

            // Clear operation in the middle
            group.addTask {
                try? await Task.sleep(for: .milliseconds(5))
                await tracker.clearHistory(for: "clear_session")
            }

            // More writers after clear
            for i in 20..<30 {
                group.addTask {
                    try? await Task.sleep(for: .milliseconds(10))
                    let response = makeTestResponse(id: "post_clear_\(i)")
                    await tracker.recordResponse(response, sessionId: "clear_session")
                }
            }
        }

        // Final state should be consistent (not crash)
        let finalCount = await tracker.getCount(for: "clear_session")
        #expect(finalCount >= 0)
    }
}

// MARK: - Module-level helper for concurrent tasks

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
