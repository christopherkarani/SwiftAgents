// TracerTests+NoOp.swift
// SwiftAgents Framework
//
// NoOpTracer tests

import Foundation
import Testing
@testable import SwiftAgents

// MARK: - NoOpTracer Tests

@Suite("NoOpTracer Tests")
struct NoOpTracerTests {

    @Test("NoOpTracer initializes successfully")
    func initializesSuccessfully() async {
        // When
        let tracer = NoOpTracer()

        // Then - verify by using it
        let traceId = UUID()
        await tracer.trace(TraceEvent.agentStart(traceId: traceId, agentName: "TestAgent"))
    }

    @Test("NoOpTracer trace does nothing and does not crash")
    func traceDoesNothingAndDoesNotCrash() async {
        // Given
        let tracer = NoOpTracer()
        let traceId = UUID()

        let event = TraceEvent.agentStart(
            traceId: traceId,
            agentName: "TestAgent"
        )

        // When/Then - should not crash
        await tracer.trace(event)
    }

    @Test("NoOpTracer flush does nothing and does not crash")
    func flushDoesNothingAndDoesNotCrash() async {
        // Given
        let tracer = NoOpTracer()

        // When/Then - should not crash
        await tracer.flush()
    }

    @Test("NoOpTracer handles multiple trace calls")
    func handlesMultipleTraceCalls() async {
        // Given
        let tracer = NoOpTracer()
        let traceId = UUID()

        // When - trace many events
        for index in 0..<100 {
            await tracer.trace(TraceEvent.custom(
                traceId: traceId,
                message: "Event \(index)"
            ))
        }

        // Then - should not crash
        await tracer.flush()
    }

    @Test("NoOpTracer handles all event kinds")
    func handlesAllEventKinds() async {
        // Given
        let tracer = NoOpTracer()
        let traceId = UUID()
        let spanId = UUID()

        // When/Then - should not crash for any event kind
        await tracer.trace(TraceEvent.agentStart(traceId: traceId, agentName: "Agent"))
        await tracer.trace(TraceEvent.agentComplete(traceId: traceId, spanId: spanId, agentName: "Agent", duration: 1.0))
        await tracer.trace(TraceEvent.agentError(traceId: traceId, spanId: spanId, agentName: "Agent", error: NSError(domain: "test", code: 1)))
        await tracer.trace(TraceEvent.toolCall(traceId: traceId, parentSpanId: nil, toolName: "Tool"))
        await tracer.trace(TraceEvent.toolResult(traceId: traceId, spanId: spanId, toolName: "Tool", duration: 0.5))
        await tracer.trace(TraceEvent.thought(traceId: traceId, spanId: spanId, agentName: "Agent", thought: "Thinking..."))
        await tracer.trace(TraceEvent.custom(traceId: traceId, message: "Custom"))
    }
}
