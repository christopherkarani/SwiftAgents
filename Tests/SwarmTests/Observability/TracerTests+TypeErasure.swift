// TracerTests+TypeErasure.swift
// Swarm Framework
//
// AnyTracer type erasure tests

import Foundation
@testable import Swarm
import Testing

// MARK: - AnyTracer Tests

@Suite("AnyTracer Tests")
struct AnyTracerTests {
    @Test("AnyTracer wraps tracer correctly")
    func wrapsTracerCorrectly() async {
        // Given
        let spy = SpyTracer()

        // When
        let wrapped = AnyTracer(spy)

        // Then - verify by using it
        let traceId = UUID()
        await wrapped.trace(TraceEvent.agentStart(traceId: traceId, agentName: "TestAgent"))

        let spyEvents = await spy.tracedEvents
        #expect(spyEvents.count == 1)
    }

    @Test("AnyTracer forwards trace calls to wrapped tracer")
    func forwardsTraceCallsToWrappedTracer() async {
        // Given
        let spy = SpyTracer()
        let wrapped = AnyTracer(spy)

        let traceId = UUID()
        let event = TraceEvent.agentStart(
            traceId: traceId,
            agentName: "TestAgent"
        )

        // When
        await wrapped.trace(event)

        // Then
        let spyEvents = await spy.tracedEvents
        #expect(spyEvents.count == 1)
        #expect(spyEvents.first?.kind == .agentStart)
    }

    @Test("AnyTracer forwards flush calls to wrapped tracer")
    func forwardsFlushCallsToWrappedTracer() async {
        // Given
        let spy = SpyTracer()
        let wrapped = AnyTracer(spy)

        // When
        await wrapped.flush()

        // Then
        let flushCount = await spy.flushCallCount
        #expect(flushCount == 1)
    }

    @Test("AnyTracer handles multiple trace calls")
    func handlesMultipleTraceCalls() async {
        // Given
        let spy = SpyTracer()
        let wrapped = AnyTracer(spy)

        let traceId = UUID()
        let events = (0..<10).map { index in
            TraceEvent.custom(
                traceId: traceId,
                message: "Event \(index)"
            )
        }

        // When
        for event in events {
            await wrapped.trace(event)
        }

        // Then
        let spyEvents = await spy.tracedEvents
        #expect(spyEvents.count == 10)
    }

    @Test("AnyTracer can wrap NoOpTracer")
    func canWrapNoOpTracer() async {
        // Given
        let noOp = NoOpTracer()

        // When
        let wrapped = AnyTracer(noOp)

        let traceId = UUID()
        let event = TraceEvent.agentStart(
            traceId: traceId,
            agentName: "TestAgent"
        )

        // Then - should not crash
        await wrapped.trace(event)
        await wrapped.flush()
    }

    @Test("AnyTracer can be stored in heterogeneous collections")
    func canBeStoredInHeterogeneousCollections() async {
        // Given
        let spy1 = SpyTracer()
        let spy2 = SpyTracer()
        let noOp = NoOpTracer()

        let wrapped1 = AnyTracer(spy1)
        let wrapped2 = AnyTracer(spy2)
        let wrapped3 = AnyTracer(noOp)

        // When - store in array
        let tracers: [AnyTracer] = [wrapped1, wrapped2, wrapped3]

        let traceId = UUID()
        let event = TraceEvent.agentStart(
            traceId: traceId,
            agentName: "TestAgent"
        )

        // Then - can iterate and trace
        for tracer in tracers {
            await tracer.trace(event)
        }

        let spy1Events = await spy1.tracedEvents
        let spy2Events = await spy2.tracedEvents

        #expect(spy1Events.count == 1)
        #expect(spy2Events.count == 1)
    }
}
