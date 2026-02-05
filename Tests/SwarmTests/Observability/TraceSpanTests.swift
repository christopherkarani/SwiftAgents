// TraceSpanTests.swift
// Swarm Framework
//
// Tests for TraceSpan struct and SpanStatus enum.

import Foundation
@testable import Swarm
import Testing

// MARK: - SpanStatusTests

@Suite("SpanStatus Tests")
struct SpanStatusTests {
    @Test("SpanStatus has all expected cases")
    func spanStatusHasAllCases() {
        let allCases = SpanStatus.allCases
        #expect(allCases.count == 4)
        #expect(allCases.contains(.active))
        #expect(allCases.contains(.ok))
        #expect(allCases.contains(.error))
        #expect(allCases.contains(.cancelled))
    }

    @Test("SpanStatus raw values are correct strings")
    func spanStatusRawValues() {
        #expect(SpanStatus.active.rawValue == "active")
        #expect(SpanStatus.ok.rawValue == "ok")
        #expect(SpanStatus.error.rawValue == "error")
        #expect(SpanStatus.cancelled.rawValue == "cancelled")
    }

    @Test("SpanStatus is Codable")
    func spanStatusCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for status in SpanStatus.allCases {
            let data = try encoder.encode(status)
            let decoded = try decoder.decode(SpanStatus.self, from: data)
            #expect(decoded == status)
        }
    }

    @Test("SpanStatus is Sendable across async boundaries")
    func spanStatusSendable() async {
        let status = SpanStatus.active

        let transferred = await Task { @Sendable in
            status
        }.value

        #expect(transferred == status)
    }
}

// MARK: - TraceSpanTests

@Suite("TraceSpan Tests")
struct TraceSpanTests {
    // MARK: - Span Creation Tests

    @Test("Span creation with default values")
    func spanCreationWithDefaults() {
        let span = TraceSpan(name: "test-operation")

        #expect(span.name == "test-operation")
        #expect(span.parentSpanId == nil)
        #expect(span.endTime == nil)
        #expect(span.status == .active)
        #expect(span.metadata.isEmpty)
        #expect(span.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
    }

    @Test("Span creation with custom values")
    func spanCreationWithCustomValues() {
        let customId = UUID()
        let parentId = UUID()
        let startTime = Date(timeIntervalSince1970: 1000)
        let endTime = Date(timeIntervalSince1970: 1005)
        let metadata: [String: SendableValue] = [
            "key1": .string("value1"),
            "key2": .int(42)
        ]

        let span = TraceSpan(
            id: customId,
            parentSpanId: parentId,
            name: "custom-operation",
            startTime: startTime,
            endTime: endTime,
            status: .ok,
            metadata: metadata
        )

        #expect(span.id == customId)
        #expect(span.parentSpanId == parentId)
        #expect(span.name == "custom-operation")
        #expect(span.startTime == startTime)
        #expect(span.endTime == endTime)
        #expect(span.status == .ok)
        #expect(span.metadata["key1"]?.stringValue == "value1")
        #expect(span.metadata["key2"]?.intValue == 42)
    }

    // MARK: - Duration Calculation Tests

    @Test("Duration is nil when span is active (no endTime)")
    func durationNilWhenActive() {
        let span = TraceSpan(name: "active-span")

        #expect(span.duration == nil)
        #expect(span.status == .active)
        #expect(span.endTime == nil)
    }

    @Test("Duration is calculated when endTime is set")
    func durationCalculatedWhenEndTimeSet() {
        let startTime = Date(timeIntervalSince1970: 1000)
        let endTime = Date(timeIntervalSince1970: 1005)

        let span = TraceSpan(
            name: "completed-span",
            startTime: startTime,
            endTime: endTime,
            status: .ok
        )

        #expect(span.duration != nil)
        #expect(span.duration! == 5.0)
    }

    @Test("Duration is precise for sub-second intervals")
    func durationPrecisionSubSecond() {
        let startTime = Date(timeIntervalSince1970: 1000.0)
        let endTime = Date(timeIntervalSince1970: 1000.5)

        let span = TraceSpan(
            name: "fast-span",
            startTime: startTime,
            endTime: endTime,
            status: .ok
        )

        #expect(span.duration != nil)
        #expect(abs(span.duration! - 0.5) < 0.001)
    }

    // MARK: - Completed Method Tests

    @Test("completed() returns new span with endTime and status")
    func completedMethodReturnsNewSpan() {
        let originalSpan = TraceSpan(name: "original-span")

        let completedSpan = originalSpan.completed()

        #expect(completedSpan.id == originalSpan.id)
        #expect(completedSpan.name == originalSpan.name)
        #expect(completedSpan.startTime == originalSpan.startTime)
        #expect(completedSpan.parentSpanId == originalSpan.parentSpanId)
        #expect(completedSpan.metadata == originalSpan.metadata)
        #expect(completedSpan.endTime != nil)
        #expect(completedSpan.status == .ok)
    }

    @Test("completed() preserves original span (immutability)")
    func completedPreservesOriginal() {
        let originalSpan = TraceSpan(name: "original-span")

        _ = originalSpan.completed()

        // Original should remain unchanged
        #expect(originalSpan.endTime == nil)
        #expect(originalSpan.status == .active)
    }

    @Test("completed() with custom status")
    func completedWithCustomStatus() {
        let span = TraceSpan(name: "span-with-error")

        let errorSpan = span.completed(status: .error)
        let cancelledSpan = span.completed(status: .cancelled)

        #expect(errorSpan.status == .error)
        #expect(cancelledSpan.status == .cancelled)
        #expect(errorSpan.endTime != nil)
        #expect(cancelledSpan.endTime != nil)
    }

    @Test("completed() sets endTime close to current time")
    func completedSetsCurrentTime() {
        let span = TraceSpan(name: "test-span")
        let beforeComplete = Date()

        let completedSpan = span.completed()

        let afterComplete = Date()

        #expect(completedSpan.endTime != nil)
        #expect(completedSpan.endTime! >= beforeComplete)
        #expect(completedSpan.endTime! <= afterComplete)
    }

    // MARK: - Span Status Transitions Tests

    @Test("Span status can be set to any value at creation")
    func spanStatusAtCreation() {
        let activeSpan = TraceSpan(name: "s1", status: .active)
        let okSpan = TraceSpan(name: "s2", status: .ok)
        let errorSpan = TraceSpan(name: "s3", status: .error)
        let cancelledSpan = TraceSpan(name: "s4", status: .cancelled)

        #expect(activeSpan.status == .active)
        #expect(okSpan.status == .ok)
        #expect(errorSpan.status == .error)
        #expect(cancelledSpan.status == .cancelled)
    }

    // MARK: - Equatable/Hashable Conformance Tests

    @Test("TraceSpan Equatable - same spans are equal")
    func spanEquatable() {
        let id = UUID()
        let startTime = Date()

        let span1 = TraceSpan(
            id: id,
            name: "test",
            startTime: startTime,
            status: .active
        )
        let span2 = TraceSpan(
            id: id,
            name: "test",
            startTime: startTime,
            status: .active
        )

        #expect(span1 == span2)
    }

    @Test("TraceSpan Equatable - different IDs are not equal")
    func spanNotEqualDifferentIds() {
        let span1 = TraceSpan(name: "test")
        let span2 = TraceSpan(name: "test")

        #expect(span1 != span2)
    }

    @Test("TraceSpan Hashable - same spans have same hash")
    func spanHashable() {
        let id = UUID()
        let startTime = Date()

        let span1 = TraceSpan(id: id, name: "test", startTime: startTime)
        let span2 = TraceSpan(id: id, name: "test", startTime: startTime)

        #expect(span1.hashValue == span2.hashValue)
    }

    @Test("TraceSpan can be used in Set")
    func spanInSet() {
        let span1 = TraceSpan(name: "span1")
        let span2 = TraceSpan(name: "span2")
        let span3 = span1 // Same reference values if we use same id

        var set = Set<TraceSpan>()
        set.insert(span1)
        set.insert(span2)
        set.insert(span1) // Duplicate, should not increase count

        #expect(set.count == 2)
    }

    // MARK: - Parent Span ID Tracking Tests

    @Test("Parent span ID tracks hierarchy")
    func parentSpanIdTracking() {
        let parentSpan = TraceSpan(name: "parent-operation")
        let childSpan = TraceSpan(
            parentSpanId: parentSpan.id,
            name: "child-operation"
        )

        #expect(childSpan.parentSpanId == parentSpan.id)
        #expect(parentSpan.parentSpanId == nil)
    }

    @Test("Multiple levels of parent tracking")
    func multiLevelParentTracking() {
        let grandparent = TraceSpan(name: "level-0")
        let parent = TraceSpan(parentSpanId: grandparent.id, name: "level-1")
        let child = TraceSpan(parentSpanId: parent.id, name: "level-2")

        #expect(grandparent.parentSpanId == nil)
        #expect(parent.parentSpanId == grandparent.id)
        #expect(child.parentSpanId == parent.id)
    }

    // MARK: - Identifiable Conformance Tests

    @Test("TraceSpan conforms to Identifiable")
    func spanIdentifiable() {
        let span = TraceSpan(name: "test-span")

        // Identifiable requires `id` property
        let _: UUID = span.id

        #expect(span.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
    }

    // MARK: - Sendable Tests

    @Test("TraceSpan is Sendable across async boundaries")
    func spanSendable() async {
        let span = TraceSpan(
            name: "sendable-span",
            metadata: ["key": .string("value")]
        )

        let transferredSpan = await Task { @Sendable in
            span
        }.value

        #expect(transferredSpan.id == span.id)
        #expect(transferredSpan.name == span.name)
        #expect(transferredSpan.metadata == span.metadata)
    }

    @Test("TraceSpan metadata values are preserved across boundaries")
    func spanMetadataSendable() async {
        let metadata: [String: SendableValue] = [
            "string": .string("hello"),
            "int": .int(42),
            "bool": .bool(true),
            "array": .array([.int(1), .int(2)]),
            "dict": .dictionary(["nested": .string("value")])
        ]

        let span = TraceSpan(name: "metadata-span", metadata: metadata)

        let transferred = await Task { @Sendable in
            span
        }.value

        #expect(transferred.metadata["string"]?.stringValue == "hello")
        #expect(transferred.metadata["int"]?.intValue == 42)
        #expect(transferred.metadata["bool"]?.boolValue == true)
        #expect(transferred.metadata["array"]?.arrayValue?.count == 2)
        #expect(transferred.metadata["dict"]?.dictionaryValue?["nested"]?.stringValue == "value")
    }

    // MARK: - Edge Cases

    @Test("Span with empty name")
    func spanEmptyName() {
        let span = TraceSpan(name: "")
        #expect(span.name.isEmpty)
    }

    @Test("Span with empty metadata")
    func spanEmptyMetadata() {
        let span = TraceSpan(name: "test", metadata: [:])
        #expect(span.metadata.isEmpty)
    }

    @Test("Span with very long name")
    func spanLongName() {
        let longName = String(repeating: "a", count: 10000)
        let span = TraceSpan(name: longName)
        #expect(span.name.count == 10000)
    }
}
