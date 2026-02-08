// TracerTests+Buffered.swift
// Swarm Framework
//
// BufferedTracer tests

import Foundation
@testable import Swarm
import Testing

// MARK: - BufferedTracer Tests

@Suite("BufferedTracer Tests")
struct BufferedTracerTests {
    @Test("BufferedTracer initializes with destination tracer")
    func initializesWithDestination() async {
        // Given
        let destination = SpyTracer()

        // When
        let buffered = BufferedTracer(
            destination: destination,
            maxBufferSize: 100,
            flushInterval: .seconds(5)
        )

        // Then - verify it works by tracing
        let traceId = UUID()
        await buffered.trace(TraceEvent.agentStart(traceId: traceId, agentName: "TestAgent"))
        await buffered.flush()

        let events = await destination.tracedEvents
        #expect(events.count == 1)
    }

    @Test("BufferedTracer buffers events without immediate forwarding")
    func buffersEventsWithoutImmediateForwarding() async {
        // Given
        let destination = SpyTracer()
        let buffered = BufferedTracer(
            destination: destination,
            maxBufferSize: 10
        )

        let traceId = UUID()
        let event = TraceEvent.agentStart(
            traceId: traceId,
            agentName: "TestAgent"
        )

        // When - trace event but don't flush
        await buffered.trace(event)

        // Then - destination should not have the event yet
        let destinationEvents = await destination.tracedEvents
        #expect(destinationEvents.isEmpty)
    }

    @Test("BufferedTracer flushes on manual flush call")
    func flushesOnManualFlushCall() async {
        // Given
        let destination = SpyTracer()
        let buffered = BufferedTracer(
            destination: destination,
            maxBufferSize: 100
        )

        let traceId = UUID()
        let events = (0..<5).map { index in
            TraceEvent.custom(
                traceId: traceId,
                message: "Event \(index)"
            )
        }

        // When - trace events
        for event in events {
            await buffered.trace(event)
        }

        // Then - destination should not have events yet
        var destinationEvents = await destination.tracedEvents
        #expect(destinationEvents.isEmpty)

        // When - manual flush
        await buffered.flush()

        // Then - destination should have all events
        destinationEvents = await destination.tracedEvents
        #expect(destinationEvents.count == 5)
    }

    @Test("BufferedTracer auto-flushes when buffer reaches max size")
    func autoFlushesWhenBufferReachesMaxSize() async {
        // Given
        let destination = SpyTracer()
        let buffered = BufferedTracer(
            destination: destination,
            maxBufferSize: 5 // Small buffer for testing
        )

        let traceId = UUID()

        // When - trace exactly maxBufferSize events
        for index in 0..<5 {
            await buffered.trace(TraceEvent.custom(
                traceId: traceId,
                message: "Event \(index)"
            ))
        }

        // Then - should auto-flush
        let destinationEvents = await destination.tracedEvents
        #expect(destinationEvents.count == 5)
    }

    @Test("BufferedTracer calls flush on destination during flush")
    func callsFlushOnDestination() async {
        // Given
        let destination = SpyTracer()
        let buffered = BufferedTracer(destination: destination)

        let traceId = UUID()
        await buffered.trace(TraceEvent.agentStart(
            traceId: traceId,
            agentName: "TestAgent"
        ))

        // When
        await buffered.flush()

        // Then
        let flushCount = await destination.flushCallCount
        #expect(flushCount == 1)
    }

    @Test("BufferedTracer does not flush empty buffer")
    func doesNotFlushEmptyBuffer() async {
        // Given
        let destination = SpyTracer()
        let buffered = BufferedTracer(destination: destination)

        // When - flush without any events
        await buffered.flush()

        // Then - flush should not call destination
        let destinationEvents = await destination.tracedEvents
        let flushCount = await destination.flushCallCount

        #expect(destinationEvents.isEmpty)
        #expect(flushCount == 0)
    }

    @Test("BufferedTracer clears buffer after flush")
    func clearsBufferAfterFlush() async {
        // Given
        let destination = SpyTracer()
        let buffered = BufferedTracer(destination: destination)

        let traceId = UUID()
        await buffered.trace(TraceEvent.agentStart(
            traceId: traceId,
            agentName: "TestAgent"
        ))

        // When - flush
        await buffered.flush()

        // Then - destination has 1 event
        var destinationEvents = await destination.tracedEvents
        #expect(destinationEvents.count == 1)

        // When - flush again without new events
        await buffered.flush()

        // Then - destination should still have only 1 event (no duplicates)
        destinationEvents = await destination.tracedEvents
        #expect(destinationEvents.count == 1)
    }

    @Test("BufferedTracer handles multiple flush cycles")
    func handlesMultipleFlushCycles() async {
        // Given
        let destination = SpyTracer()
        let buffered = BufferedTracer(destination: destination, maxBufferSize: 10)

        let traceId = UUID()

        // When - first batch
        for index in 0..<3 {
            await buffered.trace(TraceEvent.custom(
                traceId: traceId,
                message: "Batch1-\(index)"
            ))
        }
        await buffered.flush()

        // Then
        var destinationEvents = await destination.tracedEvents
        #expect(destinationEvents.count == 3)

        // When - second batch
        for index in 0..<2 {
            await buffered.trace(TraceEvent.custom(
                traceId: traceId,
                message: "Batch2-\(index)"
            ))
        }
        await buffered.flush()

        // Then - total should be 5
        destinationEvents = await destination.tracedEvents
        #expect(destinationEvents.count == 5)
    }
}
