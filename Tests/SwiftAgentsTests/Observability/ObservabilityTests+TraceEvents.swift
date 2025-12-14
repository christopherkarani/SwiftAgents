// ObservabilityTests+TraceEvents.swift
// SwiftAgents Framework
//
// TraceEvent, SourceLocation, and ErrorInfo tests.

import Testing
import Foundation
@testable import SwiftAgents

// MARK: - TraceEvent Tests

@Suite("TraceEvent Tests")
struct TraceEventTests {

    // MARK: - Builder Tests

    @Test("Builder creates events with required parameters")
    func builderCreatesBasicEvent() {
        let traceId = UUID()
        let builder = TraceEvent.Builder(
            traceId: traceId,
            kind: .agentStart,
            message: "Test message"
        )

        let event = builder.build()

        #expect(event.traceId == traceId)
        #expect(event.kind == .agentStart)
        #expect(event.message == "Test message")
        #expect(event.level == .info) // default level
    }

    @Test("Builder sets optional parameters via fluent interface")
    func builderSetsOptionalParameters() {
        let traceId = UUID()
        let parentSpanId = UUID()
        let duration: TimeInterval = 1.5

        let event = TraceEvent.Builder(traceId: traceId, kind: .toolCall, message: "Tool executing")
            .parentSpan(parentSpanId)
            .duration(duration)
            .level(.debug)
            .agent("TestAgent")
            .tool("web_search")
            .build()

        #expect(event.parentSpanId == parentSpanId)
        #expect(event.duration == duration)
        #expect(event.level == .debug)
        #expect(event.agentName == "TestAgent")
        #expect(event.toolName == "web_search")
    }

    @Test("Builder adds metadata incrementally")
    func builderAddsMetadata() {
        let traceId = UUID()
        let event = TraceEvent.Builder(traceId: traceId, kind: .custom, message: "Test")
            .metadata(key: "key1", value: .string("value1"))
            .metadata(key: "key2", value: .int(42))
            .build()

        #expect(event.metadata["key1"]?.stringValue == "value1")
        #expect(event.metadata["key2"]?.intValue == 42)
    }

    @Test("Builder replaces all metadata")
    func builderReplacesMetadata() {
        let traceId = UUID()
        let initialMetadata: [String: SendableValue] = ["initial": .string("data")]
        let newMetadata: [String: SendableValue] = ["new": .string("data")]

        let event = TraceEvent.Builder(traceId: traceId, kind: .custom, message: "Test")
            .metadata(initialMetadata)
            .metadata(newMetadata)
            .build()

        #expect(event.metadata["initial"] == nil)
        #expect(event.metadata["new"]?.stringValue == "data")
    }

    @Test("Builder merges additional metadata")
    func builderMergesMetadata() {
        let traceId = UUID()
        let event = TraceEvent.Builder(traceId: traceId, kind: .custom, message: "Test")
            .metadata(["key1": .string("value1")])
            .addingMetadata(["key2": .int(42)])
            .build()

        #expect(event.metadata["key1"]?.stringValue == "value1")
        #expect(event.metadata["key2"]?.intValue == 42)
    }

    @Test("Builder sets error from Error instance")
    func builderSetsErrorFromError() {
        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "Test error occurred" }
        }

        let traceId = UUID()
        let testError = TestError()

        let event = TraceEvent.Builder(traceId: traceId, kind: .agentError, message: "Error")
            .error(testError)
            .build()

        #expect(event.error != nil)
        #expect(event.error?.message == "Test error occurred")
    }

    @Test("Builder sets error info directly")
    func builderSetsErrorInfoDirectly() {
        let traceId = UUID()
        let errorInfo = ErrorInfo(
            type: "CustomError",
            message: "Something went wrong",
            stackTrace: ["Frame 1", "Frame 2"]
        )

        let event = TraceEvent.Builder(traceId: traceId, kind: .agentError, message: "Error")
            .error(errorInfo)
            .build()

        #expect(event.error == errorInfo)
    }

    @Test("Builder sets source location")
    func builderSetsSourceLocation() {
        let traceId = UUID()
        let location = SourceLocation(file: "/path/to/file.swift", function: "testFunc", line: 42)

        let event = TraceEvent.Builder(traceId: traceId, kind: .checkpoint, message: "Test")
            .source(location)
            .build()

        #expect(event.source == location)
    }

    // MARK: - EventLevel Tests

    @Test("EventLevel comparison works correctly")
    func eventLevelComparison() {
        #expect(EventLevel.trace < EventLevel.debug)
        #expect(EventLevel.debug < EventLevel.info)
        #expect(EventLevel.info < EventLevel.warning)
        #expect(EventLevel.warning < EventLevel.error)
        #expect(EventLevel.error < EventLevel.critical)

        #expect(EventLevel.critical > EventLevel.error)
    }

    @Test("EventLevel ordering is correct")
    func eventLevelOrdering() {
        let levels: [EventLevel] = [.critical, .trace, .warning, .debug, .error, .info]
        let sorted = levels.sorted()

        #expect(sorted == [.trace, .debug, .info, .warning, .error, .critical])
    }

    // MARK: - Sendable Tests

    @Test("TraceEvent is Sendable across async boundaries")
    func traceEventIsSendable() async {
        let traceId = UUID()
        let event = TraceEvent.Builder(traceId: traceId, kind: .agentStart, message: "Test")
            .agent("TestAgent")
            .build()

        // Transfer event across async task boundary
        let transferredEvent = await Task {
            event
        }.value

        #expect(transferredEvent.id == event.id)
        #expect(transferredEvent.message == "Test")
    }

    // MARK: - Convenience Constructor Tests

    @Test("agentStart convenience constructor")
    func agentStartConvenience() {
        let traceId = UUID()
        let spanId = UUID()
        let event = TraceEvent.agentStart(
            traceId: traceId,
            spanId: spanId,
            agentName: "MyAgent",
            metadata: ["key": .string("value")]
        )

        #expect(event.traceId == traceId)
        #expect(event.spanId == spanId)
        #expect(event.kind == .agentStart)
        #expect(event.agentName == "MyAgent")
        #expect(event.level == .info)
        #expect(event.metadata["key"]?.stringValue == "value")
    }

    @Test("agentComplete convenience constructor")
    func agentCompleteConvenience() {
        let traceId = UUID()
        let spanId = UUID()
        let duration: TimeInterval = 2.5

        let event = TraceEvent.agentComplete(
            traceId: traceId,
            spanId: spanId,
            agentName: "MyAgent",
            duration: duration
        )

        #expect(event.kind == .agentComplete)
        #expect(event.duration == duration)
        #expect(event.agentName == "MyAgent")
    }

    @Test("agentError convenience constructor")
    func agentErrorConvenience() {
        struct TestError: Error {}

        let traceId = UUID()
        let spanId = UUID()
        let event = TraceEvent.agentError(
            traceId: traceId,
            spanId: spanId,
            agentName: "MyAgent",
            error: TestError()
        )

        #expect(event.kind == .agentError)
        #expect(event.level == .error)
        #expect(event.error != nil)
    }

    @Test("toolCall convenience constructor")
    func toolCallConvenience() {
        let traceId = UUID()
        let parentSpanId = UUID()

        let event = TraceEvent.toolCall(
            traceId: traceId,
            parentSpanId: parentSpanId,
            toolName: "web_search"
        )

        #expect(event.kind == .toolCall)
        #expect(event.level == .debug)
        #expect(event.toolName == "web_search")
        #expect(event.parentSpanId != nil)
    }

    @Test("toolResult convenience constructor")
    func toolResultConvenience() {
        let traceId = UUID()
        let spanId = UUID()
        let duration: TimeInterval = 1.2

        let event = TraceEvent.toolResult(
            traceId: traceId,
            spanId: spanId,
            toolName: "web_search",
            duration: duration
        )

        #expect(event.kind == .toolResult)
        #expect(event.level == .debug)
        #expect(event.duration == duration)
    }

    @Test("thought convenience constructor")
    func thoughtConvenience() {
        let traceId = UUID()
        let spanId = UUID()

        let event = TraceEvent.thought(
            traceId: traceId,
            spanId: spanId,
            agentName: "MyAgent",
            thought: "I need to search the web"
        )

        #expect(event.kind == .thought)
        #expect(event.level == .trace)
        #expect(event.message == "I need to search the web")
        #expect(event.metadata["thought"]?.stringValue == "I need to search the web")
    }

    @Test("custom convenience constructor")
    func customConvenience() {
        let traceId = UUID()

        let event = TraceEvent.custom(
            traceId: traceId,
            message: "Custom event",
            level: .warning,
            metadata: ["custom": .bool(true)]
        )

        #expect(event.kind == .custom)
        #expect(event.level == .warning)
        #expect(event.message == "Custom event")
    }
}

// MARK: - SourceLocation Tests

@Suite("SourceLocation Tests")
struct SourceLocationTests {

    @Test("SourceLocation extracts filename from path")
    func sourceLocationFilename() {
        let location = SourceLocation(
            file: "/path/to/project/Sources/MyFile.swift",
            function: "testFunc",
            line: 42
        )

        #expect(location.filename == "MyFile.swift")
    }

    @Test("SourceLocation formats correctly")
    func sourceLocationFormatted() {
        let location = SourceLocation(
            file: "/path/to/File.swift",
            function: "myFunction()",
            line: 123
        )

        #expect(location.formatted == "File.swift:123 - myFunction()")
    }
}

// MARK: - ErrorInfo Tests

@Suite("ErrorInfo Tests")
struct ErrorInfoTests {

    @Test("ErrorInfo creates from Swift Error")
    func errorInfoFromError() {
        struct CustomError: Error, LocalizedError {
            var errorDescription: String? { "Custom error message" }
        }

        let error = CustomError()
        let errorInfo = ErrorInfo(from: error)

        #expect(errorInfo.message == "Custom error message")
        #expect(errorInfo.type.contains("CustomError"))
    }

    @Test("ErrorInfo with stack trace")
    func errorInfoWithStackTrace() {
        let errorInfo = ErrorInfo(
            type: "RuntimeError",
            message: "Something failed",
            stackTrace: ["Frame 1", "Frame 2", "Frame 3"]
        )

        #expect(errorInfo.stackTrace?.count == 3)
        #expect(errorInfo.stackTrace?[0] == "Frame 1")
    }
}
