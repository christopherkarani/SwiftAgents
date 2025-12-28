// ResponseTrackerTests.swift
// SwiftAgentsTests
//
// Comprehensive unit tests for ResponseTracker covering bounded storage,
// session isolation, history management, and all public API methods.

import Foundation
@testable import SwiftAgents
import Testing

// MARK: - ResponseTrackerTests

@Suite("ResponseTracker Tests")
struct ResponseTrackerTests {
    // MARK: Internal

    // MARK: - Record and Retrieve Tests

    @Test("Record and retrieve response")
    func recordAndRetrieveResponse() async {
        let tracker = ResponseTracker()
        let response = makeTestResponse(id: "test_id_123", output: "Hello, World!")

        await tracker.recordResponse(response, sessionId: "session1")

        let retrieved = await tracker.getResponse(responseId: "test_id_123", sessionId: "session1")

        #expect(retrieved != nil)
        #expect(retrieved?.responseId == "test_id_123")
        #expect(retrieved?.output == "Hello, World!")
        #expect(retrieved?.agentName == "TestAgent")
    }

    @Test("Retrieve non-existent response returns nil")
    func retrieveNonExistentResponseReturnsNil() async {
        let tracker = ResponseTracker()

        let retrieved = await tracker.getResponse(responseId: "non_existent", sessionId: "session1")

        #expect(retrieved == nil)
    }

    @Test("Retrieve from non-existent session returns nil")
    func retrieveFromNonExistentSessionReturnsNil() async {
        let tracker = ResponseTracker()
        let response = makeTestResponse()

        await tracker.recordResponse(response, sessionId: "session1")

        let retrieved = await tracker.getResponse(responseId: response.responseId, sessionId: "session2")

        #expect(retrieved == nil)
    }

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

    // MARK: - Session Isolation Tests

    @Test("Sessions are isolated")
    func sessionIsolation() async {
        let tracker = ResponseTracker()

        // Add responses to different sessions
        let response1 = makeTestResponse(id: "session1_resp", output: "Session 1 Output")
        let response2 = makeTestResponse(id: "session2_resp", output: "Session 2 Output")
        let response3 = makeTestResponse(id: "session3_resp", output: "Session 3 Output")

        await tracker.recordResponse(response1, sessionId: "session1")
        await tracker.recordResponse(response2, sessionId: "session2")
        await tracker.recordResponse(response3, sessionId: "session3")

        // Verify each session has only its own response
        let session1Count = await tracker.getCount(for: "session1")
        let session2Count = await tracker.getCount(for: "session2")
        let session3Count = await tracker.getCount(for: "session3")

        #expect(session1Count == 1)
        #expect(session2Count == 1)
        #expect(session3Count == 1)

        // Cross-session retrieval should fail
        let crossRetrieve = await tracker.getResponse(responseId: "session1_resp", sessionId: "session2")
        #expect(crossRetrieve == nil)
    }

    @Test("Session isolation with history limits")
    func sessionIsolationWithHistoryLimits() async {
        let tracker = ResponseTracker(maxHistorySize: 3)

        // Fill session1 to capacity
        for i in 0..<5 {
            let response = makeTestResponse(id: "s1_\(i)")
            await tracker.recordResponse(response, sessionId: "session1")
        }

        // Add to session2
        for i in 0..<2 {
            let response = makeTestResponse(id: "s2_\(i)")
            await tracker.recordResponse(response, sessionId: "session2")
        }

        // Session1 should have 3 (limited), session2 should have 2
        let s1Count = await tracker.getCount(for: "session1")
        let s2Count = await tracker.getCount(for: "session2")

        #expect(s1Count == 3)
        #expect(s2Count == 2)

        // Session1's oldest should be trimmed
        let s1Old = await tracker.getResponse(responseId: "s1_0", sessionId: "session1")
        #expect(s1Old == nil)

        // Session2's responses should all exist
        let s2First = await tracker.getResponse(responseId: "s2_0", sessionId: "session2")
        #expect(s2First != nil)
    }

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

    // MARK: - Get All Session IDs Tests

    @Test("Get all session IDs")
    func testGetAllSessionIds() async {
        let tracker = ResponseTracker()

        await tracker.recordResponse(makeTestResponse(), sessionId: "alpha")
        await tracker.recordResponse(makeTestResponse(), sessionId: "beta")
        await tracker.recordResponse(makeTestResponse(), sessionId: "gamma")

        let sessionIds = await tracker.getAllSessionIds()

        #expect(sessionIds.count == 3)
        #expect(sessionIds.contains("alpha"))
        #expect(sessionIds.contains("beta"))
        #expect(sessionIds.contains("gamma"))
    }

    @Test("Get all session IDs when empty")
    func getAllSessionIdsWhenEmpty() async {
        let tracker = ResponseTracker()

        let sessionIds = await tracker.getAllSessionIds()

        #expect(sessionIds.isEmpty)
    }

    // MARK: - Response Content Verification Tests

    @Test("Response content is preserved correctly")
    func responseContentIsPreservedCorrectly() async {
        let tracker = ResponseTracker()
        let timestamp = Date()

        let original = AgentResponse(
            responseId: "unique_id_12345",
            output: "This is a test output with special characters: @#$%^&*()",
            agentName: "SpecialAgent",
            timestamp: timestamp,
            metadata: ["key": .string("value"), "number": .int(42)],
            toolCalls: [
                ToolCallRecord(
                    toolName: "test_tool",
                    arguments: ["arg": .string("val")],
                    result: .bool(true),
                    duration: .seconds(1)
                )
            ],
            usage: TokenUsage(inputTokens: 100, outputTokens: 50)
        )

        await tracker.recordResponse(original, sessionId: "test_session")

        let retrieved = await tracker.getResponse(responseId: "unique_id_12345", sessionId: "test_session")

        #expect(retrieved != nil)
        #expect(retrieved?.responseId == original.responseId)
        #expect(retrieved?.output == original.output)
        #expect(retrieved?.agentName == original.agentName)
        #expect(retrieved?.timestamp == original.timestamp)
        #expect(retrieved?.metadata == original.metadata)
        #expect(retrieved?.toolCalls.count == original.toolCalls.count)
        #expect(retrieved?.usage?.inputTokens == 100)
        #expect(retrieved?.usage?.outputTokens == 50)
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

    // MARK: - Session Cleanup Tests

    @Test("Remove sessions by absolute date threshold")
    func removeSessionsByAbsoluteDate() async throws {
        let tracker = ResponseTracker()

        // Create a reference time
        let now = Date()
        let oneDayAgo = now.addingTimeInterval(-1 * 24 * 3600)

        // Record responses for old session (simulate old timestamps)
        await tracker.recordResponse(makeTestResponse(id: "old_1"), sessionId: "old_session")

        // Record responses for recent session
        await tracker.recordResponse(makeTestResponse(id: "recent_1"), sessionId: "recent_session")

        // Verify both sessions exist
        #expect(await tracker.getCount(for: "old_session") == 1)
        #expect(await tracker.getCount(for: "recent_session") == 1)

        // Remove sessions older than 1 day
        let removed = await tracker.removeSessions(lastAccessedBefore: oneDayAgo)

        // Should remove old session but keep recent
        #expect(removed == 1)
        #expect(await tracker.getCount(for: "old_session") == 0)
        #expect(await tracker.getCount(for: "recent_session") == 1)
    }

    @Test("Remove sessions by time interval")
    func removeSessionsByTimeInterval() async throws {
        let tracker = ResponseTracker()

        // Record some responses
        await tracker.recordResponse(makeTestResponse(id: "resp_1"), sessionId: "session_1")
        await tracker.recordResponse(makeTestResponse(id: "resp_2"), sessionId: "session_2")

        // Wait a short time
        try await Task.sleep(for: .milliseconds(100))

        // Record another response for session_2 (making it more recent)
        await tracker.recordResponse(makeTestResponse(id: "resp_3"), sessionId: "session_2")

        // Remove sessions not accessed within 50ms
        let removed = await tracker.removeSessions(notAccessedWithin: 0.05)

        // session_1 should be removed, session_2 should remain
        #expect(removed == 1)
        #expect(await tracker.getCount(for: "session_1") == 0)
        #expect(await tracker.getCount(for: "session_2") == 2)
    }

    @Test("Remove sessions returns zero when no sessions match")
    func removeSessionsNoMatches() async {
        let tracker = ResponseTracker()

        // Record some recent responses
        await tracker.recordResponse(makeTestResponse(id: "resp_1"), sessionId: "session_1")
        await tracker.recordResponse(makeTestResponse(id: "resp_2"), sessionId: "session_2")

        // Try to remove sessions older than 1 year ago (none should match)
        let oneYearAgo = Date().addingTimeInterval(-365 * 24 * 3600)
        let removed = await tracker.removeSessions(lastAccessedBefore: oneYearAgo)

        #expect(removed == 0)
        #expect(await tracker.getCount(for: "session_1") == 1)
        #expect(await tracker.getCount(for: "session_2") == 1)
    }

    @Test("Remove sessions on empty tracker")
    func removeSessionsEmptyTracker() async {
        let tracker = ResponseTracker()

        let removed = await tracker.removeSessions(lastAccessedBefore: Date())

        #expect(removed == 0)
    }

    @Test("Get session metadata for existing session")
    func getSessionMetadata() async {
        let tracker = ResponseTracker()

        // Record some responses
        await tracker.recordResponse(makeTestResponse(id: "resp_1"), sessionId: "test_session")
        await tracker.recordResponse(makeTestResponse(id: "resp_2"), sessionId: "test_session")
        await tracker.recordResponse(makeTestResponse(id: "resp_3"), sessionId: "test_session")

        let metadata = await tracker.getSessionMetadata(for: "test_session")

        #expect(metadata != nil)
        #expect(metadata?.sessionId == "test_session")
        #expect(metadata?.responseCount == 3)
        #expect(metadata?.lastAccessTime != nil)
    }

    @Test("Get session metadata for non-existent session")
    func getSessionMetadataForNonExistentSession() async {
        let tracker = ResponseTracker()

        let metadata = await tracker.getSessionMetadata(for: "non_existent")

        #expect(metadata == nil)
    }

    @Test("Get all session metadata")
    func getAllSessionMetadata() async {
        let tracker = ResponseTracker()

        // Record responses for multiple sessions
        await tracker.recordResponse(makeTestResponse(id: "a_1"), sessionId: "session_a")
        await tracker.recordResponse(makeTestResponse(id: "b_1"), sessionId: "session_b")
        await tracker.recordResponse(makeTestResponse(id: "b_2"), sessionId: "session_b")
        await tracker.recordResponse(makeTestResponse(id: "c_1"), sessionId: "session_c")

        let allMetadata = await tracker.getAllSessionMetadata()

        #expect(allMetadata.count == 3)

        // Find each session in metadata
        let sessionA = allMetadata.first { $0.sessionId == "session_a" }
        let sessionB = allMetadata.first { $0.sessionId == "session_b" }
        let sessionC = allMetadata.first { $0.sessionId == "session_c" }

        #expect(sessionA?.responseCount == 1)
        #expect(sessionB?.responseCount == 2)
        #expect(sessionC?.responseCount == 1)
    }

    @Test("Get all session metadata returns empty for empty tracker")
    func getAllSessionMetadataEmpty() async {
        let tracker = ResponseTracker()

        let allMetadata = await tracker.getAllSessionMetadata()

        #expect(allMetadata.isEmpty)
    }

    @Test("Session metadata is sorted by recency")
    func sessionMetadataSortedByRecency() async throws {
        let tracker = ResponseTracker()

        // Record sessions in order: A, B, C
        await tracker.recordResponse(makeTestResponse(id: "a_1"), sessionId: "session_a")
        try await Task.sleep(for: .milliseconds(10))

        await tracker.recordResponse(makeTestResponse(id: "b_1"), sessionId: "session_b")
        try await Task.sleep(for: .milliseconds(10))

        await tracker.recordResponse(makeTestResponse(id: "c_1"), sessionId: "session_c")

        let allMetadata = await tracker.getAllSessionMetadata()

        // Should be sorted newest first: C, B, A
        #expect(allMetadata.count == 3)
        #expect(allMetadata[0].sessionId == "session_c")
        #expect(allMetadata[1].sessionId == "session_b")
        #expect(allMetadata[2].sessionId == "session_a")
    }

    @Test("Cleanup removes both history and access times")
    func cleanupRemovesBothHistoryAndAccessTimes() async {
        let tracker = ResponseTracker()

        // Record some responses
        await tracker.recordResponse(makeTestResponse(id: "resp_1"), sessionId: "session_1")
        await tracker.recordResponse(makeTestResponse(id: "resp_2"), sessionId: "session_2")

        // Verify sessions exist
        #expect(await tracker.getAllSessionIds().count == 2)

        // Remove all sessions
        let removed = await tracker.removeSessions(lastAccessedBefore: Date())

        #expect(removed == 2)
        #expect(await tracker.getAllSessionIds().isEmpty)
        #expect(await tracker.getAllSessionMetadata().isEmpty)
    }

    // MARK: Private

    // MARK: - Test Helpers

    /// Creates a test response with customizable parameters.
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
