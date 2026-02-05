// TraceContextTests.swift
// Swarm Framework
//
// Tests for TraceContext actor with @TaskLocal storage.

import Foundation
@testable import Swarm
import Testing

// MARK: - TraceContextCreationTests

@Suite("TraceContext Creation Tests")
struct TraceContextCreationTests {
    @Test("TraceContext creation via withTrace")
    func traceContextCreationViaWithTrace() async throws {
        let capturedContext = await TraceContext.withTrace("test-trace") {
            TraceContext.current
        }

        #expect(capturedContext != nil)
        let name = await capturedContext!.name
        #expect(name == "test-trace")
    }

    @Test("TraceContext has unique traceId")
    func traceContextHasUniqueTraceId() async throws {
        let traceId1 = await TraceContext.withTrace("trace-1") {
            await TraceContext.current?.traceId
        }

        let traceId2 = await TraceContext.withTrace("trace-2") {
            await TraceContext.current?.traceId
        }

        #expect(traceId1 != nil)
        #expect(traceId2 != nil)
        #expect(traceId1 != traceId2)
    }

    @Test("TraceContext with custom groupId")
    func traceContextWithGroupId() async throws {
        let capturedGroupId = await TraceContext.withTrace("trace", groupId: "session-123") {
            await TraceContext.current?.groupId
        }

        #expect(capturedGroupId == "session-123")
    }

    @Test("TraceContext with metadata")
    func traceContextWithMetadata() async throws {
        let testMetadata: [String: SendableValue] = [
            "user": .string("alice"),
            "priority": .int(1)
        ]

        let capturedMetadata = await TraceContext.withTrace("trace", metadata: testMetadata) {
            await TraceContext.current?.metadata
        }

        #expect(capturedMetadata?["user"]?.stringValue == "alice")
        #expect(capturedMetadata?["priority"]?.intValue == 1)
    }

    @Test("TraceContext records startTime")
    func traceContextRecordsStartTime() async throws {
        let before = Date()

        let startTime = await TraceContext.withTrace("trace") {
            await TraceContext.current?.startTime
        }

        let after = Date()

        #expect(startTime != nil)
        #expect(startTime! >= before)
        #expect(startTime! <= after)
    }
}

// MARK: - TraceContextTaskLocalTests

@Suite("TraceContext Task-Local Storage Tests")
struct TraceContextTaskLocalTests {
    @Test("current is nil outside withTrace")
    func currentNilOutsideWithTrace() {
        let context = TraceContext.current
        #expect(context == nil)
    }

    @Test("current is non-nil inside withTrace")
    func currentNonNilInsideWithTrace() async throws {
        let insideContext = await TraceContext.withTrace("test") {
            TraceContext.current
        }

        #expect(insideContext != nil)
    }

    @Test("current is nil after withTrace completes")
    func currentNilAfterWithTrace() async throws {
        await TraceContext.withTrace("test") {
            // Inside trace
        }

        let afterContext = TraceContext.current
        #expect(afterContext == nil)
    }

    @Test("Nested trace contexts - inner overrides outer")
    func nestedTraceContextsInnerOverridesOuter() async throws {
        let (outerName, innerName, afterInnerName) = await TraceContext.withTrace("outer") {
            let outer = await TraceContext.current?.name

            let inner = await TraceContext.withTrace("inner") {
                await TraceContext.current?.name
            }

            let afterInner = await TraceContext.current?.name
            return (outer, inner, afterInner)
        }

        #expect(outerName == "outer")
        #expect(innerName == "inner")
        #expect(afterInnerName == "outer") // Restored after inner completes
    }

    @Test("Deeply nested trace contexts restore correctly")
    func deeplyNestedTraceContexts() async throws {
        let names = await TraceContext.withTrace("level-0") {
            var collected: [String] = []

            if let name = await TraceContext.current?.name {
                collected.append(name)
            }

            let innerNames = await TraceContext.withTrace("level-1") {
                var level1Collected: [String] = []

                if let name = await TraceContext.current?.name {
                    level1Collected.append(name)
                }

                let level2Name = await TraceContext.withTrace("level-2") {
                    await TraceContext.current?.name
                }
                if let name = level2Name {
                    level1Collected.append(name)
                }

                if let name = await TraceContext.current?.name {
                    level1Collected.append(name)
                }
                return level1Collected
            }
            collected.append(contentsOf: innerNames)

            if let name = await TraceContext.current?.name {
                collected.append(name)
            }
            return collected
        }

        #expect(names == ["level-0", "level-1", "level-2", "level-1", "level-0"])
    }
}

// MARK: - TraceContextSpanManagementTests

@Suite("TraceContext Span Management Tests")
struct TraceContextSpanManagementTests {
    @Test("startSpan creates span with correct name")
    func startSpanCreatesSpan() async throws {
        await TraceContext.withTrace("trace") {
            guard let context = TraceContext.current else {
                Issue.record("Context should not be nil")
                return
            }

            let span = await context.startSpan("operation")

            #expect(span.name == "operation")
            #expect(span.status == .active)
            #expect(span.endTime == nil)
        }
    }

    @Test("startSpan includes metadata")
    func startSpanIncludesMetadata() async throws {
        await TraceContext.withTrace("trace") {
            guard let context = TraceContext.current else {
                Issue.record("Context should not be nil")
                return
            }

            let span = await context.startSpan(
                "operation",
                metadata: ["key": .string("value")]
            )

            #expect(span.metadata["key"]?.stringValue == "value")
        }
    }

    @Test("startSpan adds span to context automatically")
    func startSpanAddsToContext() async throws {
        await TraceContext.withTrace("trace") {
            guard let context = TraceContext.current else {
                Issue.record("Context should not be nil")
                return
            }

            _ = await context.startSpan("operation")
            let spans = await context.getSpans()

            #expect(spans.count == 1)
            #expect(spans.first?.name == "operation")
        }
    }

    @Test("endSpan updates span status")
    func endSpanUpdatesStatus() async throws {
        await TraceContext.withTrace("trace") {
            guard let context = TraceContext.current else {
                Issue.record("Context should not be nil")
                return
            }

            let span = await context.startSpan("operation")
            await context.endSpan(span, status: .ok)

            let spans = await context.getSpans()
            let endedSpan = spans.first { $0.id == span.id }

            #expect(endedSpan?.status == .ok)
            #expect(endedSpan?.endTime != nil)
        }
    }

    @Test("endSpan with error status")
    func endSpanWithErrorStatus() async throws {
        await TraceContext.withTrace("trace") {
            guard let context = TraceContext.current else {
                Issue.record("Context should not be nil")
                return
            }

            let span = await context.startSpan("failing-operation")
            await context.endSpan(span, status: .error)

            let spans = await context.getSpans()
            let endedSpan = spans.first { $0.id == span.id }

            #expect(endedSpan?.status == .error)
        }
    }

    @Test("endSpan with cancelled status")
    func endSpanWithCancelledStatus() async throws {
        await TraceContext.withTrace("trace") {
            guard let context = TraceContext.current else {
                Issue.record("Context should not be nil")
                return
            }

            let span = await context.startSpan("cancellable-operation")
            await context.endSpan(span, status: .cancelled)

            let spans = await context.getSpans()
            let endedSpan = spans.first { $0.id == span.id }

            #expect(endedSpan?.status == .cancelled)
        }
    }

    @Test("addSpan adds external span to collection")
    func addSpanAddsExternalSpan() async throws {
        await TraceContext.withTrace("trace") {
            guard let context = TraceContext.current else {
                Issue.record("Context should not be nil")
                return
            }

            let externalSpan = TraceSpan(name: "external-operation")
            await context.addSpan(externalSpan)

            let spans = await context.getSpans()
            #expect(spans.contains { $0.id == externalSpan.id })
        }
    }

    @Test("getSpans returns all spans in collection")
    func getSpansReturnsAllSpans() async throws {
        await TraceContext.withTrace("trace") {
            guard let context = TraceContext.current else {
                Issue.record("Context should not be nil")
                return
            }

            _ = await context.startSpan("span-1")
            _ = await context.startSpan("span-2")
            _ = await context.startSpan("span-3")

            let spans = await context.getSpans()

            #expect(spans.count == 3)
            #expect(spans.map(\.name).sorted() == ["span-1", "span-2", "span-3"])
        }
    }

    @Test("Multiple startSpan and endSpan calls work correctly")
    func multipleStartAndEndSpans() async throws {
        await TraceContext.withTrace("trace") {
            guard let context = TraceContext.current else {
                Issue.record("Context should not be nil")
                return
            }

            let span1 = await context.startSpan("operation-1")
            let span2 = await context.startSpan("operation-2")

            await context.endSpan(span1, status: .ok)
            await context.endSpan(span2, status: .error)

            let spans = await context.getSpans()

            let ended1 = spans.first { $0.id == span1.id }
            let ended2 = spans.first { $0.id == span2.id }

            #expect(ended1?.status == .ok)
            #expect(ended2?.status == .error)
        }
    }
}

// MARK: - TraceContextMetadataTests

@Suite("TraceContext Metadata Propagation Tests")
struct TraceContextMetadataTests {
    @Test("Trace metadata is accessible from spans")
    func traceMetadataAccessibleFromContext() async throws {
        let traceMetadata: [String: SendableValue] = [
            "requestId": .string("req-123"),
            "userId": .string("user-456")
        ]

        await TraceContext.withTrace("trace", metadata: traceMetadata) {
            guard let context = TraceContext.current else {
                Issue.record("Context should not be nil")
                return
            }

            let metadata = await context.metadata

            #expect(metadata["requestId"]?.stringValue == "req-123")
            #expect(metadata["userId"]?.stringValue == "user-456")
        }
    }

    @Test("Empty metadata is valid")
    func emptyMetadataIsValid() async throws {
        await TraceContext.withTrace("trace", metadata: [:]) {
            guard let context = TraceContext.current else {
                Issue.record("Context should not be nil")
                return
            }

            let metadata = await context.metadata
            #expect(metadata.isEmpty)
        }
    }
}

// MARK: - TraceContextGroupIdTests

@Suite("TraceContext GroupId Tests")
struct TraceContextGroupIdTests {
    @Test("GroupId links related traces")
    func groupIdLinksRelatedTraces() async throws {
        let sessionId = "session-abc"

        let trace1GroupId = await TraceContext.withTrace("trace-1", groupId: sessionId) {
            await TraceContext.current?.groupId
        }

        let trace2GroupId = await TraceContext.withTrace("trace-2", groupId: sessionId) {
            await TraceContext.current?.groupId
        }

        #expect(trace1GroupId == sessionId)
        #expect(trace2GroupId == sessionId)
        #expect(trace1GroupId == trace2GroupId)
    }

    @Test("GroupId is nil when not provided")
    func groupIdNilWhenNotProvided() async throws {
        await TraceContext.withTrace("trace") {
            let groupId = await TraceContext.current?.groupId
            #expect(groupId == nil)
        }
    }
}

// MARK: - TraceContextDurationTests

@Suite("TraceContext Duration Tests")
struct TraceContextDurationTests {
    @Test("Duration is calculated from startTime")
    func durationCalculatedFromStartTime() async throws {
        await TraceContext.withTrace("trace") {
            guard let context = TraceContext.current else {
                Issue.record("Context should not be nil")
                return
            }

            // Small delay to ensure measurable duration
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms

            let duration = await context.duration

            #expect(duration >= 0.01) // At least 10ms
            #expect(duration < 1.0) // Less than 1 second
        }
    }

    @Test("Duration increases over time")
    func durationIncreasesOverTime() async throws {
        await TraceContext.withTrace("trace") {
            guard let context = TraceContext.current else {
                Issue.record("Context should not be nil")
                return
            }

            let duration1 = await context.duration

            try? await Task.sleep(nanoseconds: 5_000_000) // 5ms

            let duration2 = await context.duration

            #expect(duration2 > duration1)
        }
    }
}

// MARK: - TraceContextConcurrentTests

@Suite("TraceContext Concurrent Access Tests")
struct TraceContextConcurrentTests {
    @Test("All tasks see same context via task-local propagation")
    func allTasksSeeSameContext() async throws {
        await TraceContext.withTrace("shared-trace") {
            guard let expectedContext = TraceContext.current else {
                Issue.record("Context should not be nil")
                return
            }

            let expectedTraceId = await expectedContext.traceId

            // Spawn multiple concurrent tasks
            await withTaskGroup(of: UUID?.self) { group in
                for _ in 0 ..< 5 {
                    group.addTask {
                        await TraceContext.current?.traceId
                    }
                }

                for await traceId in group {
                    #expect(traceId == expectedTraceId)
                }
            }
        }
    }

    @Test("Concurrent span operations are thread-safe")
    func concurrentSpanOperationsThreadSafe() async throws {
        await TraceContext.withTrace("concurrent-trace") {
            guard let context = TraceContext.current else {
                Issue.record("Context should not be nil")
                return
            }

            // Spawn multiple concurrent tasks that create spans
            await withTaskGroup(of: Void.self) { group in
                for i in 0 ..< 10 {
                    group.addTask {
                        let span = await context.startSpan("concurrent-span-\(i)")
                        await context.endSpan(span, status: .ok)
                    }
                }
            }

            let spans = await context.getSpans()
            #expect(spans.count == 10)
        }
    }

    @Test("Child tasks inherit trace context")
    func childTasksInheritTraceContext() async throws {
        await TraceContext.withTrace("parent-trace") {
            guard let parentContext = TraceContext.current else {
                Issue.record("Parent context should not be nil")
                return
            }

            let parentTraceId = await parentContext.traceId

            // Child task should see the same context
            let childTraceId = await Task {
                await TraceContext.current?.traceId
            }.value

            #expect(childTraceId == parentTraceId)
        }
    }

    @Test("async let inherits trace context")
    func asyncLetInheritsTraceContext() async throws {
        await TraceContext.withTrace("async-let-trace") {
            guard let context = TraceContext.current else {
                Issue.record("Context should not be nil")
                return
            }

            let expectedTraceId = await context.traceId

            async let traceId1 = TraceContext.current?.traceId
            async let traceId2 = TraceContext.current?.traceId

            let (result1, result2) = await (traceId1, traceId2)

            #expect(result1 == expectedTraceId)
            #expect(result2 == expectedTraceId)
        }
    }
}

// MARK: - TraceContextReturnValueTests

@Suite("TraceContext withTrace Return Value Tests")
struct TraceContextReturnValueTests {
    @Test("withTrace returns value from operation")
    func withTraceReturnsValue() async throws {
        let result = await TraceContext.withTrace("trace") {
            "hello world"
        }

        #expect(result == "hello world")
    }

    @Test("withTrace returns complex Sendable type")
    func withTraceReturnsComplexType() async throws {
        struct Result: Sendable, Equatable {
            let value: Int
            let message: String
        }

        let result = await TraceContext.withTrace("trace") {
            Result(value: 42, message: "success")
        }

        #expect(result == Result(value: 42, message: "success"))
    }

    @Test("withTrace propagates errors")
    func withTracePropagatesErrors() async throws {
        struct TestError: Error, Equatable {}

        do {
            _ = try await TraceContext.withTrace("trace") {
                throw TestError()
            }
            Issue.record("Should have thrown error")
        } catch {
            #expect(error is TestError)
        }
    }
}

// MARK: - TraceContextEdgeCasesTests

@Suite("TraceContext Edge Cases")
struct TraceContextEdgeCasesTests {
    @Test("Empty trace name is valid")
    func emptyTraceNameIsValid() async throws {
        await TraceContext.withTrace("") {
            let name = await TraceContext.current?.name
            #expect(name?.isEmpty == true)
        }
    }

    @Test("Very long trace name is valid")
    func longTraceNameIsValid() async throws {
        let longName = String(repeating: "a", count: 10000)

        await TraceContext.withTrace(longName) {
            let name = await TraceContext.current?.name
            #expect(name?.count == 10000)
        }
    }

    @Test("Span with same name as trace is valid")
    func spanSameNameAsTrace() async throws {
        await TraceContext.withTrace("operation") {
            guard let context = TraceContext.current else {
                Issue.record("Context should not be nil")
                return
            }

            let span = await context.startSpan("operation")
            let traceName = await context.name

            #expect(span.name == traceName)
        }
    }
}
