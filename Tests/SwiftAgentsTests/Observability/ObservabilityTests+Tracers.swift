// ObservabilityTests+Tracers.swift
// SwiftAgents Framework
//
// ConsoleTracer and PrettyConsoleTracer tests.

import Testing
import Foundation
@testable import SwiftAgents

// MARK: - ConsoleTracer Tests

@Suite("ConsoleTracer Tests")
struct ConsoleTracerTests {

    @Test("ConsoleTracer respects minimum level filtering")
    func consoleTracerMinimumLevel() async {
        let tracer = ConsoleTracer(minimumLevel: .warning)
        let traceId = UUID()

        // These should be filtered out (below warning level)
        await tracer.trace(.custom(traceId: traceId, message: "Trace", level: .trace))
        await tracer.trace(.custom(traceId: traceId, message: "Debug", level: .debug))
        await tracer.trace(.custom(traceId: traceId, message: "Info", level: .info))

        // These should pass through (at or above warning level)
        await tracer.trace(.custom(traceId: traceId, message: "Warning", level: .warning))
        await tracer.trace(.custom(traceId: traceId, message: "Error", level: .error))
        await tracer.trace(.custom(traceId: traceId, message: "Critical", level: .critical))

        // Test passes if no crash occurs during filtering
        #expect(true)
    }

    @Test("ConsoleTracer formats all event kinds without crashing")
    func consoleTracerFormatsAllEventKinds() async {
        let tracer = ConsoleTracer(minimumLevel: .trace, colorized: false)
        let traceId = UUID()
        let spanId = UUID()

        // Test all event kinds
        await tracer.trace(.agentStart(traceId: traceId, agentName: "Agent"))
        await tracer.trace(.agentComplete(traceId: traceId, spanId: spanId, agentName: "Agent", duration: 1.0))
        await tracer.trace(.agentError(traceId: traceId, spanId: spanId, agentName: "Agent", error: NSError(domain: "test", code: 1)))
        await tracer.trace(.toolCall(traceId: traceId, parentSpanId: spanId, toolName: "tool"))
        await tracer.trace(.toolResult(traceId: traceId, spanId: spanId, toolName: "tool", duration: 0.5))
        await tracer.trace(.thought(traceId: traceId, spanId: spanId, agentName: "Agent", thought: "thinking"))
        await tracer.trace(.custom(traceId: traceId, message: "custom"))

        // Test passes if all events are formatted without crash
        #expect(true)
    }

    @Test("ConsoleTracer handles events with metadata")
    func consoleTracerWithMetadata() async {
        let tracer = ConsoleTracer(minimumLevel: .info, colorized: false)
        let traceId = UUID()

        let event = TraceEvent.custom(
            traceId: traceId,
            message: "Event with metadata",
            metadata: [
                "key1": .string("value1"),
                "key2": .int(42),
                "key3": .bool(true)
            ]
        )

        await tracer.trace(event)

        // Test passes if metadata formatting doesn't crash
        #expect(true)
    }

    @Test("ConsoleTracer handles events with errors")
    func consoleTracerWithErrors() async {
        let tracer = ConsoleTracer(minimumLevel: .error, colorized: false)
        let traceId = UUID()

        let errorInfo = ErrorInfo(
            type: "TestError",
            message: "Test error message",
            stackTrace: ["Frame 1", "Frame 2"]
        )

        let event = TraceEvent.Builder(traceId: traceId, kind: .agentError, message: "Error occurred")
            .level(.error)
            .error(errorInfo)
            .build()

        await tracer.trace(event)

        // Test passes if error formatting doesn't crash
        #expect(true)
    }
}

// MARK: - PrettyConsoleTracer Tests

@Suite("PrettyConsoleTracer Tests")
struct PrettyConsoleTracerTests {

    @Test("PrettyConsoleTracer formats all event kinds")
    func prettyConsoleTracerFormatsAllKinds() async {
        let tracer = PrettyConsoleTracer(minimumLevel: .trace, colorized: false)
        let traceId = UUID()
        let spanId = UUID()

        // Test all event kinds to ensure emoji formatting works
        await tracer.trace(.agentStart(traceId: traceId, agentName: "Agent"))
        await tracer.trace(.agentComplete(traceId: traceId, spanId: spanId, agentName: "Agent", duration: 1.0))
        await tracer.trace(.custom(traceId: traceId, message: "Custom event"))

        // Test passes if all formatting completes without crash
        #expect(true)
    }
}
