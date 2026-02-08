// TracerTests+EdgeCases.swift
// Swarm Framework
//
// Edge case tests for tracers

import Foundation
@testable import Swarm
import Testing

// MARK: - Edge Case Tests

@Suite("Tracer Edge Case Tests")
struct TracerEdgeCaseTests {
    @Test("CompositeTracer with single tracer")
    func compositeWithSingleTracer() async {
        // Given
        let spy = SpyTracer()
        let composite = CompositeTracer(tracers: [spy])

        let traceId = UUID()
        let event = TraceEvent.agentStart(
            traceId: traceId,
            agentName: "TestAgent"
        )

        // When
        await composite.trace(event)

        // Then
        let spyEvents = await spy.tracedEvents
        #expect(spyEvents.count == 1)
    }

    @Test("BufferedTracer with maxBufferSize of 1")
    func bufferedWithMaxBufferSizeOne() async {
        // Given
        let destination = SpyTracer()
        let buffered = BufferedTracer(destination: destination, maxBufferSize: 1)

        let traceId = UUID()

        // When - trace one event
        await buffered.trace(TraceEvent.agentStart(
            traceId: traceId,
            agentName: "TestAgent"
        ))

        // Then - should auto-flush immediately
        let destinationEvents = await destination.tracedEvents
        #expect(destinationEvents.count == 1)
    }

    @Test("CompositeTracer with all event levels")
    func compositeWithAllEventLevels() async {
        // Given
        let spy = SpyTracer()
        let composite = CompositeTracer(
            tracers: [spy],
            minimumLevel: .trace // Accept all levels
        )

        let traceId = UUID()

        // When - trace all levels
        for level in EventLevel.allCases {
            await composite.trace(TraceEvent.custom(
                traceId: traceId,
                message: "Level: \(level)",
                level: level
            ))
        }

        // Then - all should be traced
        let spyEvents = await spy.tracedEvents
        #expect(spyEvents.count == EventLevel.allCases.count)
    }

    @Test("BufferedTracer with very large maxBufferSize")
    func bufferedWithVeryLargeMaxBufferSize() async {
        // Given
        let destination = SpyTracer()
        let buffered = BufferedTracer(
            destination: destination,
            maxBufferSize: 10000
        )

        let traceId = UUID()

        // When - trace many events (but less than buffer size)
        for index in 0..<100 {
            await buffered.trace(TraceEvent.custom(
                traceId: traceId,
                message: "Event \(index)"
            ))
        }

        // Then - should not auto-flush
        var destinationEvents = await destination.tracedEvents
        #expect(destinationEvents.isEmpty)

        // When - manual flush
        await buffered.flush()

        // Then - all events should be flushed
        destinationEvents = await destination.tracedEvents
        #expect(destinationEvents.count == 100)
    }
}
