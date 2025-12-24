// TracerTests.swift
// SwiftAgents Framework
//
// Core tests for tracer types from Tracer protocol
// Additional test suites are in extension files:
// - TracerTests+Buffered.swift
// - TracerTests+NoOp.swift
// - TracerTests+TypeErasure.swift
// - TracerTests+Integration.swift
// - TracerTests+EdgeCases.swift

import Foundation
@testable import SwiftAgents
import Testing

// MARK: - SpyTracer

/// Spy tracer that records all traced events for verification.
/// This is shared across all test files via internal access.
actor SpyTracer: Tracer {
    private(set) var tracedEvents: [TraceEvent] = []
    private(set) var flushCallCount: Int = 0
    private(set) var traceCallCount: Int = 0

    func trace(_ event: TraceEvent) async {
        tracedEvents.append(event)
        traceCallCount += 1
    }

    func flush() async {
        flushCallCount += 1
    }

    /// Reset the spy to initial state
    func reset() {
        tracedEvents.removeAll()
        flushCallCount = 0
        traceCallCount = 0
    }

    /// Check if a specific event was traced
    func wasTraced(eventWithKind kind: EventKind) -> Bool {
        tracedEvents.contains { $0.kind == kind }
    }

    /// Get events matching a specific level
    func events(withLevel level: EventLevel) -> [TraceEvent] {
        tracedEvents.filter { $0.level == level }
    }
}

// MARK: - CompositeTracerTests

@Suite("CompositeTracer Tests")
struct CompositeTracerTests {
    @Test("CompositeTracer initializes with multiple tracers")
    func initializesWithMultipleTracers() async {
        // Given
        let spy1 = SpyTracer()
        let spy2 = SpyTracer()
        let spy3 = SpyTracer()

        // When
        let composite = CompositeTracer(
            tracers: [spy1, spy2, spy3],
            minimumLevel: .info,
            shouldExecuteInParallel: true
        )

        // Then - composite created successfully
        let traceId = UUID()
        let event = TraceEvent.agentStart(traceId: traceId, agentName: "TestAgent")
        await composite.trace(event)

        // Verify it works
        let spy1Events = await spy1.tracedEvents
        #expect(spy1Events.count == 1)
    }

    @Test("CompositeTracer forwards events to all child tracers")
    func forwardsEventsToAllChildTracers() async {
        // Given
        let spy1 = SpyTracer()
        let spy2 = SpyTracer()
        let spy3 = SpyTracer()
        let composite = CompositeTracer(tracers: [spy1, spy2, spy3])

        let traceId = UUID()
        let event = TraceEvent.agentStart(
            traceId: traceId,
            agentName: "TestAgent"
        )

        // When
        await composite.trace(event)

        // Then
        let spy1Events = await spy1.tracedEvents
        let spy2Events = await spy2.tracedEvents
        let spy3Events = await spy3.tracedEvents

        #expect(spy1Events.count == 1)
        #expect(spy2Events.count == 1)
        #expect(spy3Events.count == 1)

        #expect(spy1Events.first?.kind == .agentStart)
        #expect(spy2Events.first?.kind == .agentStart)
        #expect(spy3Events.first?.kind == .agentStart)
    }

    @Test("CompositeTracer filters events below minimum level")
    func filtersEventsBelowMinimumLevel() async {
        // Given
        let spy = SpyTracer()
        let composite = CompositeTracer(
            tracers: [spy],
            minimumLevel: .warning // Only warning and above
        )

        let traceId = UUID()

        // When - trace events at different levels
        await composite.trace(TraceEvent.custom(
            traceId: traceId,
            message: "trace level",
            level: .trace
        ))
        await composite.trace(TraceEvent.custom(
            traceId: traceId,
            message: "debug level",
            level: .debug
        ))
        await composite.trace(TraceEvent.custom(
            traceId: traceId,
            message: "info level",
            level: .info
        ))
        await composite.trace(TraceEvent.custom(
            traceId: traceId,
            message: "warning level",
            level: .warning
        ))
        await composite.trace(TraceEvent.custom(
            traceId: traceId,
            message: "error level",
            level: .error
        ))

        // Then - only warning and error should be traced
        let tracedEvents = await spy.tracedEvents
        #expect(tracedEvents.count == 2)
        #expect(tracedEvents[0].level == .warning)
        #expect(tracedEvents[1].level == .error)
    }

    @Test("CompositeTracer parallel forwarding forwards to all tracers concurrently")
    func parallelForwardingForwardsConcurrently() async {
        // Given
        let spy1 = SpyTracer()
        let spy2 = SpyTracer()
        let spy3 = SpyTracer()
        let composite = CompositeTracer(
            tracers: [spy1, spy2, spy3],
            shouldExecuteInParallel: true
        )

        let traceId = UUID()
        let events = (0..<10).map { index in
            TraceEvent.custom(
                traceId: traceId,
                message: "Event \(index)"
            )
        }

        // When - trace multiple events
        for event in events {
            await composite.trace(event)
        }

        // Then - all tracers should have all events
        let spy1Events = await spy1.tracedEvents
        let spy2Events = await spy2.tracedEvents
        let spy3Events = await spy3.tracedEvents

        #expect(spy1Events.count == 10)
        #expect(spy2Events.count == 10)
        #expect(spy3Events.count == 10)
    }

    @Test("CompositeTracer sequential forwarding forwards in order")
    func sequentialForwardingForwardsInOrder() async {
        // Given
        let spy1 = SpyTracer()
        let spy2 = SpyTracer()
        let composite = CompositeTracer(
            tracers: [spy1, spy2],
            shouldExecuteInParallel: false // Sequential
        )

        let traceId = UUID()
        let event = TraceEvent.agentStart(
            traceId: traceId,
            agentName: "TestAgent"
        )

        // When
        await composite.trace(event)

        // Then - both spies should have the event
        let spy1Events = await spy1.tracedEvents
        let spy2Events = await spy2.tracedEvents

        #expect(spy1Events.count == 1)
        #expect(spy2Events.count == 1)
    }

    @Test("CompositeTracer flush calls flush on all children in parallel")
    func flushCallsFlushOnAllChildrenInParallel() async {
        // Given
        let spy1 = SpyTracer()
        let spy2 = SpyTracer()
        let spy3 = SpyTracer()
        let composite = CompositeTracer(
            tracers: [spy1, spy2, spy3],
            shouldExecuteInParallel: true
        )

        // When
        await composite.flush()

        // Then
        let spy1FlushCount = await spy1.flushCallCount
        let spy2FlushCount = await spy2.flushCallCount
        let spy3FlushCount = await spy3.flushCallCount

        #expect(spy1FlushCount == 1)
        #expect(spy2FlushCount == 1)
        #expect(spy3FlushCount == 1)
    }

    @Test("CompositeTracer flush calls flush on all children sequentially")
    func flushCallsFlushOnAllChildrenSequentially() async {
        // Given
        let spy1 = SpyTracer()
        let spy2 = SpyTracer()
        let composite = CompositeTracer(
            tracers: [spy1, spy2],
            shouldExecuteInParallel: false // Sequential
        )

        // When
        await composite.flush()

        // Then
        let spy1FlushCount = await spy1.flushCallCount
        let spy2FlushCount = await spy2.flushCallCount

        #expect(spy1FlushCount == 1)
        #expect(spy2FlushCount == 1)
    }

    @Test("CompositeTracer with empty tracers array does not crash")
    func emptyTracersArrayDoesNotCrash() async {
        // Given
        let composite = CompositeTracer(tracers: [])

        let traceId = UUID()
        let event = TraceEvent.agentStart(
            traceId: traceId,
            agentName: "TestAgent"
        )

        // When/Then - should not crash
        await composite.trace(event)
        await composite.flush()
    }

    @Test("CompositeTracer filters by minimum level correctly for edge cases")
    func filtersMinimumLevelEdgeCases() async {
        // Given
        let spy = SpyTracer()
        let composite = CompositeTracer(
            tracers: [spy],
            minimumLevel: .info
        )

        let traceId = UUID()

        // When - trace event exactly at minimum level
        await composite.trace(TraceEvent.custom(
            traceId: traceId,
            message: "exactly info",
            level: .info
        ))

        // Then - should be traced
        let tracedEvents = await spy.tracedEvents
        #expect(tracedEvents.count == 1)
        #expect(tracedEvents[0].level == .info)
    }
}
