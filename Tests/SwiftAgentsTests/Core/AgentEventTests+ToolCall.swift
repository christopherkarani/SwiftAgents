// AgentEventTests+ToolCall.swift
// SwiftAgentsTests
//
// Tests for ToolCall type

import Testing
import Foundation
@testable import SwiftAgents

// MARK: - ToolCall Tests

@Suite("ToolCall Tests")
struct ToolCallTests {

    // MARK: - Initialization

    @Test("ToolCall default initialization")
    func defaultInitialization() {
        let toolCall = ToolCall(toolName: "calculator")

        #expect(toolCall.toolName == "calculator")
        #expect(toolCall.arguments.isEmpty)
        #expect(toolCall.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)

        // Verify timestamp is recent (within last second)
        let now = Date()
        let difference = now.timeIntervalSince(toolCall.timestamp)
        #expect(difference >= 0)
        #expect(difference < 1.0)
    }

    @Test("ToolCall custom initialization")
    func customInitialization() {
        let id = UUID()
        let timestamp = Date(timeIntervalSince1970: 1000000)
        let arguments: [String: SendableValue] = [
            "query": .string("search term"),
            "limit": .int(10),
            "verbose": .bool(true)
        ]

        let toolCall = ToolCall(
            id: id,
            toolName: "search",
            arguments: arguments,
            timestamp: timestamp
        )

        #expect(toolCall.id == id)
        #expect(toolCall.toolName == "search")
        #expect(toolCall.arguments["query"] == .string("search term"))
        #expect(toolCall.arguments["limit"] == .int(10))
        #expect(toolCall.arguments["verbose"] == .bool(true))
        #expect(toolCall.timestamp == timestamp)
    }

    @Test("ToolCall with empty arguments")
    func emptyArguments() {
        let toolCall = ToolCall(
            toolName: "get_time",
            arguments: [:]
        )

        #expect(toolCall.arguments.isEmpty)
        #expect(toolCall.toolName == "get_time")
    }

    @Test("ToolCall with complex arguments")
    func complexArguments() {
        let toolCall = ToolCall(
            toolName: "complex_tool",
            arguments: [
                "nested": .dictionary([
                    "key1": .string("value1"),
                    "key2": .int(42)
                ]),
                "array": .array([.int(1), .int(2), .int(3)]),
                "null": .null
            ]
        )

        #expect(toolCall.arguments.count == 3)
        #expect(toolCall.arguments["nested"]?["key1"] == .string("value1"))
        #expect(toolCall.arguments["array"]?[0] == .int(1))
        #expect(toolCall.arguments["null"] == .null)
    }

    // MARK: - Equatable Conformance

    @Test("ToolCall Equatable - same values")
    func equatableSameValues() {
        let id = UUID()
        let timestamp = Date(timeIntervalSince1970: 1000000)
        let arguments: [String: SendableValue] = ["key": .string("value")]

        let toolCall1 = ToolCall(
            id: id,
            toolName: "test",
            arguments: arguments,
            timestamp: timestamp
        )

        let toolCall2 = ToolCall(
            id: id,
            toolName: "test",
            arguments: arguments,
            timestamp: timestamp
        )

        #expect(toolCall1 == toolCall2)
    }

    @Test("ToolCall Equatable - different IDs")
    func equatableDifferentIds() {
        let timestamp = Date(timeIntervalSince1970: 1000000)

        let toolCall1 = ToolCall(
            id: UUID(),
            toolName: "test",
            arguments: [:],
            timestamp: timestamp
        )

        let toolCall2 = ToolCall(
            id: UUID(),
            toolName: "test",
            arguments: [:],
            timestamp: timestamp
        )

        #expect(toolCall1 != toolCall2)
    }

    @Test("ToolCall Equatable - different tool names")
    func equatableDifferentToolNames() {
        let id = UUID()
        let timestamp = Date(timeIntervalSince1970: 1000000)

        let toolCall1 = ToolCall(
            id: id,
            toolName: "tool1",
            arguments: [:],
            timestamp: timestamp
        )

        let toolCall2 = ToolCall(
            id: id,
            toolName: "tool2",
            arguments: [:],
            timestamp: timestamp
        )

        #expect(toolCall1 != toolCall2)
    }

    @Test("ToolCall Equatable - different arguments")
    func equatableDifferentArguments() {
        let id = UUID()
        let timestamp = Date(timeIntervalSince1970: 1000000)

        let toolCall1 = ToolCall(
            id: id,
            toolName: "test",
            arguments: ["key": .string("value1")],
            timestamp: timestamp
        )

        let toolCall2 = ToolCall(
            id: id,
            toolName: "test",
            arguments: ["key": .string("value2")],
            timestamp: timestamp
        )

        #expect(toolCall1 != toolCall2)
    }

    @Test("ToolCall Equatable - different timestamps")
    func equatableDifferentTimestamps() {
        let id = UUID()

        let toolCall1 = ToolCall(
            id: id,
            toolName: "test",
            arguments: [:],
            timestamp: Date(timeIntervalSince1970: 1000000)
        )

        let toolCall2 = ToolCall(
            id: id,
            toolName: "test",
            arguments: [:],
            timestamp: Date(timeIntervalSince1970: 2000000)
        )

        #expect(toolCall1 != toolCall2)
    }

    // MARK: - Identifiable Conformance

    @Test("ToolCall Identifiable conformance")
    func identifiableConformance() {
        let toolCall1 = ToolCall(toolName: "test")
        let toolCall2 = ToolCall(toolName: "test")

        // Each tool call should have a unique ID
        #expect(toolCall1.id != toolCall2.id)

        // ID should be stable for the same instance
        let id1 = toolCall1.id
        let id2 = toolCall1.id
        #expect(id1 == id2)
    }

    // MARK: - Codable Conformance

    @Test("ToolCall Codable round-trip")
    func codableRoundTrip() throws {
        let original = ToolCall(
            id: UUID(uuidString: "12345678-1234-1234-1234-123456789012")!,
            toolName: "calculator",
            arguments: [
                "expression": .string("2+2"),
                "verbose": .bool(true),
                "precision": .int(2)
            ],
            timestamp: Date(timeIntervalSince1970: 1000000)
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ToolCall.self, from: data)

        #expect(decoded == original)
        #expect(decoded.id == original.id)
        #expect(decoded.toolName == original.toolName)
        #expect(decoded.arguments == original.arguments)
        #expect(decoded.timestamp.timeIntervalSince1970 == original.timestamp.timeIntervalSince1970)
    }

    @Test("ToolCall Codable with empty arguments")
    func codableEmptyArguments() throws {
        let original = ToolCall(
            toolName: "simple_tool",
            arguments: [:]
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ToolCall.self, from: data)

        #expect(decoded.toolName == original.toolName)
        #expect(decoded.arguments.isEmpty)
    }

    @Test("ToolCall Codable with nested arguments")
    func codableNestedArguments() throws {
        let original = ToolCall(
            toolName: "nested_tool",
            arguments: [
                "config": .dictionary([
                    "timeout": .int(30),
                    "retry": .bool(true),
                    "endpoints": .array([
                        .string("http://api1.com"),
                        .string("http://api2.com")
                    ])
                ])
            ]
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ToolCall.self, from: data)

        #expect(decoded.toolName == original.toolName)
        #expect(decoded.arguments["config"]?["timeout"] == .int(30))
        #expect(decoded.arguments["config"]?["retry"] == .bool(true))
        #expect(decoded.arguments["config"]?["endpoints"]?[0] == .string("http://api1.com"))
    }

    // MARK: - CustomStringConvertible

    @Test("ToolCall description")
    func customStringConvertible() {
        let toolCall = ToolCall(
            toolName: "search",
            arguments: ["query": .string("swift")]
        )

        let description = toolCall.description

        #expect(description.contains("ToolCall"))
        #expect(description.contains("search"))
        #expect(description.contains("args"))
    }
}
