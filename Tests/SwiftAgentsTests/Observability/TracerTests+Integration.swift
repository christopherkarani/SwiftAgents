// TracerTests+Integration.swift
// SwiftAgents Framework
//
// Integration tests for tracer combinations

import Foundation
import Testing
@testable import SwiftAgents

// MARK: - Integration Tests

@Suite("Tracer Integration Tests")
struct TracerIntegrationTests {

    @Test("CompositeTracer with BufferedTracer children")
    func compositeWithBufferedChildren() async {
        // Given
        let destination1 = SpyTracer()
        let destination2 = SpyTracer()

        let buffered1 = BufferedTracer(destination: destination1, maxBufferSize: 5)
        let buffered2 = BufferedTracer(destination: destination2, maxBufferSize: 5)

        let composite = CompositeTracer(
            tracers: [buffered1, buffered2],
            parallel: true
        )

        let traceId = UUID()

        // When - trace events
        for index in 0..<5 {
            await composite.trace(TraceEvent.custom(
                traceId: traceId,
                message: "Event \(index)"
            ))
        }

        // Then - destinations should have auto-flushed
        let dest1Events = await destination1.tracedEvents
        let dest2Events = await destination2.tracedEvents

        #expect(dest1Events.count == 5)
        #expect(dest2Events.count == 5)
    }

    @Test("CompositeTracer with mixed tracer types")
    func compositeWithMixedTracerTypes() async {
        // Given
        let spy = SpyTracer()
        let noOp = NoOpTracer()
        let destination = SpyTracer()
        let buffered = BufferedTracer(destination: destination, maxBufferSize: 10)

        let composite = CompositeTracer(
            tracers: [spy, noOp, buffered]
        )

        let traceId = UUID()
        let event = TraceEvent.agentStart(
            traceId: traceId,
            agentName: "TestAgent"
        )

        // When
        await composite.trace(event)
        await composite.flush()

        // Then
        let spyEvents = await spy.tracedEvents
        let destinationEvents = await destination.tracedEvents

        #expect(spyEvents.count == 1)
        #expect(destinationEvents.count == 1)
    }

    @Test("AnyAgentTracer wrapping CompositeTracer")
    func anyTracerWrappingComposite() async {
        // Given
        let spy1 = SpyTracer()
        let spy2 = SpyTracer()
        let composite = CompositeTracer(tracers: [spy1, spy2])
        let wrapped = AnyAgentTracer(composite)

        let traceId = UUID()
        let event = TraceEvent.agentStart(
            traceId: traceId,
            agentName: "TestAgent"
        )

        // When
        await wrapped.trace(event)

        // Then
        let spy1Events = await spy1.tracedEvents
        let spy2Events = await spy2.tracedEvents

        #expect(spy1Events.count == 1)
        #expect(spy2Events.count == 1)
    }
}
