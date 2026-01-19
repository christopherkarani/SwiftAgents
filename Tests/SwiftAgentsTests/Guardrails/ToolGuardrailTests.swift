// ToolGuardrailTests.swift
// SwiftAgentsTests
//
// TDD tests for Tool-level guardrails - Sprint 2 of Guardrails system
// These tests define the contract for Tool guardrails before implementation

import Foundation
@testable import SwiftAgents
import Testing

// MARK: - ToolGuardrailDataTests

@Suite("ToolGuardrailData Tests")
struct ToolGuardrailDataTests {
    // MARK: Internal

    @Test("ToolGuardrailData initializes with basic fields")
    func toolGuardrailDataInitialization() {
        // Given
        let tool = MockTool(name: "test_tool")
        let arguments: [String: SendableValue] = ["key": .string("value")]

        // When
        let data = ToolGuardrailData(
            tool: tool,
            arguments: arguments,
            agent: nil,
            context: nil
        )

        // Then
        #expect(data.tool.name == "test_tool")
        #expect(data.arguments["key"] == .string("value"))
        #expect(data.agent == nil)
        #expect(data.context == nil)
    }

    @Test("ToolGuardrailData initializes with all fields")
    func toolGuardrailDataWithAllFields() async {
        // Given
        let tool = MockTool(name: "weather")
        let arguments: [String: SendableValue] = [
            "location": .string("NYC"),
            "units": .string("fahrenheit")
        ]
        let agent = createMockAgent()
        let context = AgentContext(input: "test input")

        // When
        let data = ToolGuardrailData(
            tool: tool,
            arguments: arguments,
            agent: agent,
            context: context
        )

        // Then
        #expect(data.tool.name == "weather")
        #expect(data.arguments["location"] == .string("NYC"))
        #expect(data.arguments["units"] == .string("fahrenheit"))
        #expect(data.agent != nil)
        #expect(data.agent?.configuration.name == "mock_agent")

        let originalInput = await context.originalInput
        #expect(originalInput == "test input")
    }

    @Test("ToolGuardrailData is Sendable across async boundaries")
    func toolGuardrailDataSendable() async {
        // Given
        let tool = MockTool(name: "calculator")
        let arguments: [String: SendableValue] = ["expression": .string("2+2")]
        let data = ToolGuardrailData(
            tool: tool,
            arguments: arguments,
            agent: nil,
            context: nil
        )

        // When - pass data across async boundary
        let receivedData = await withCheckedContinuation { continuation in
            Task {
                continuation.resume(returning: data)
            }
        }

        // Then
        #expect(receivedData.tool.name == "calculator")
        #expect(receivedData.arguments["expression"] == .string("2+2"))
    }

    // MARK: Private

    // MARK: - Helpers

    private func createMockAgent() -> any Agent {
        MockAgentForGuardrails(name: "mock_agent")
    }
}

// MARK: - ToolInputGuardrailTests

@Suite("ToolInputGuardrail Tests")
struct ToolInputGuardrailTests {
    @Test("ToolInputGuardrail protocol conforms to Sendable")
    func toolInputGuardrailProtocolConformance() async throws {
        // Given
        let guardrail = MockToolInputGuardrail(
            name: "test_input_guardrail",
            result: .passed(message: "Validation passed")
        )

        // When
        let tool = MockTool(name: "test_tool")
        let data = ToolGuardrailData(
            tool: tool,
            arguments: [:],
            agent: nil,
            context: nil
        )
        let result = try await guardrail.validate(data)

        // Then
        #expect(result.tripwireTriggered == false)
        #expect(result.message == "Validation passed")
    }

    @Test("ClosureToolInputGuardrail validates input arguments")
    func closureToolInputGuardrailValidation() async throws {
        // Given
        let guardrail = ClosureToolInputGuardrail(name: "argument_checker") { data in
            // Check for required argument
            guard data.arguments["api_key"] != nil else {
                return .tripwire(message: "Missing API key")
            }
            return .passed(message: "API key present")
        }

        // When - missing API key
        let tool = MockTool(name: "api_call")
        let invalidData = ToolGuardrailData(
            tool: tool,
            arguments: [:],
            agent: nil,
            context: nil
        )
        let failResult = try await guardrail.validate(invalidData)

        // Then
        #expect(failResult.tripwireTriggered == true)
        #expect(failResult.message == "Missing API key")

        // When - API key present
        let validData = ToolGuardrailData(
            tool: tool,
            arguments: ["api_key": .string("secret123")],
            agent: nil,
            context: nil
        )
        let passResult = try await guardrail.validate(validData)

        // Then
        #expect(passResult.tripwireTriggered == false)
        #expect(passResult.message == "API key present")
    }

    @Test("ToolInputGuardrail returns passed result")
    func toolInputGuardrailPassedResult() async throws {
        // Given
        let guardrail = ClosureToolInputGuardrail(name: "safe_input") { _ in
            .passed(
                message: "Input validation successful",
                outputInfo: .dictionary(["checked": .bool(true)]),
                metadata: ["duration": .double(0.001)]
            )
        }

        let tool = MockTool(name: "search")
        let data = ToolGuardrailData(
            tool: tool,
            arguments: ["query": .string("weather")],
            agent: nil,
            context: nil
        )

        // When
        let result = try await guardrail.validate(data)

        // Then
        #expect(result.tripwireTriggered == false)
        #expect(result.message == "Input validation successful")
        #expect(result.outputInfo == .dictionary(["checked": .bool(true)]))
        #expect(result.metadata["duration"] == .double(0.001))
    }

    @Test("ToolInputGuardrail returns tripwire result")
    func toolInputGuardrailTripwireResult() async throws {
        // Given
        let guardrail = ClosureToolInputGuardrail(name: "sensitive_data_detector") { data in
            // Check for sensitive patterns
            if let query = data.arguments["query"]?.stringValue,
               query.contains("SSN:") || query.contains("password") {
                return .tripwire(
                    message: "Sensitive data detected in tool input",
                    outputInfo: .dictionary([
                        "patterns": .array([.string("SSN"), .string("password")]),
                        "severity": .string("high")
                    ]),
                    metadata: ["timestamp": .int(1_234_567_890)]
                )
            }
            return .passed()
        }

        let tool = MockTool(name: "database_query")

        // When - sensitive data present
        let sensitiveData = ToolGuardrailData(
            tool: tool,
            arguments: ["query": .string("SELECT * WHERE password='admin123'")],
            agent: nil,
            context: nil
        )
        let result = try await guardrail.validate(sensitiveData)

        // Then
        #expect(result.tripwireTriggered == true)
        #expect(result.message == "Sensitive data detected in tool input")

        if case let .dictionary(dict) = result.outputInfo {
            #expect(dict["severity"] == .string("high"))
        } else {
            Issue.record("Expected dictionary outputInfo")
        }
    }
}

// MARK: - ToolOutputGuardrailTests

@Suite("ToolOutputGuardrail Tests")
struct ToolOutputGuardrailTests {
    @Test("ToolOutputGuardrail protocol conforms to Sendable")
    func toolOutputGuardrailProtocolConformance() async throws {
        // Given
        let guardrail = MockToolOutputGuardrail(
            name: "test_output_guardrail",
            result: .passed(message: "Output validated")
        )

        // When
        let tool = MockTool(name: "test_tool")
        let data = ToolGuardrailData(
            tool: tool,
            arguments: [:],
            agent: nil,
            context: nil
        )
        let output: SendableValue = .string("test output")
        let result = try await guardrail.validate(data, output: output)

        // Then
        #expect(result.tripwireTriggered == false)
        #expect(result.message == "Output validated")
    }

    @Test("ClosureToolOutputGuardrail validates output value")
    func closureToolOutputGuardrailValidation() async throws {
        // Given
        let guardrail = ClosureToolOutputGuardrail(name: "output_size_checker") { _, output in
            // Check output size
            if let str = output.stringValue, str.count > 1000 {
                return .tripwire(message: "Output too large")
            }
            return .passed(message: "Output size acceptable")
        }

        let tool = MockTool(name: "text_generator")
        let data = ToolGuardrailData(
            tool: tool,
            arguments: [:],
            agent: nil,
            context: nil
        )

        // When - small output
        let smallOutput: SendableValue = .string("Hello")
        let passResult = try await guardrail.validate(data, output: smallOutput)

        // Then
        #expect(passResult.tripwireTriggered == false)
        #expect(passResult.message == "Output size acceptable")

        // When - large output
        let largeOutput: SendableValue = .string(String(repeating: "x", count: 1500))
        let tripResult = try await guardrail.validate(data, output: largeOutput)

        // Then
        #expect(tripResult.tripwireTriggered == true)
        #expect(tripResult.message == "Output too large")
    }

    @Test("ToolOutputGuardrail validates with output value")
    func toolOutputGuardrailWithOutput() async throws {
        // Given
        let guardrail = ClosureToolOutputGuardrail(name: "pii_detector") { _, output in
            // Check for PII in output
            if let str = output.stringValue,
               str.contains("@") || str.contains("SSN") {
                return .passed(
                    message: "PII check completed",
                    outputInfo: .dictionary([
                        "piiDetected": .bool(true),
                        "types": .array([.string("email")])
                    ])
                )
            }
            return .passed(
                message: "No PII detected",
                outputInfo: .dictionary(["piiDetected": .bool(false)])
            )
        }

        let tool = MockTool(name: "customer_lookup")
        let data = ToolGuardrailData(
            tool: tool,
            arguments: ["customer_id": .string("12345")],
            agent: nil,
            context: nil
        )

        // When
        let output: SendableValue = .string("Contact: john@example.com")
        let result = try await guardrail.validate(data, output: output)

        // Then
        #expect(result.tripwireTriggered == false)
        #expect(result.message == "PII check completed")

        if case let .dictionary(dict) = result.outputInfo {
            #expect(dict["piiDetected"] == .bool(true))
        } else {
            Issue.record("Expected dictionary outputInfo")
        }
    }

    @Test("ToolOutputGuardrail returns tripwire result on violation")
    func toolOutputGuardrailTripwireResult() async throws {
        // Given
        let guardrail = ClosureToolOutputGuardrail(name: "content_filter") { data, output in
            // Check for inappropriate content
            if let str = output.stringValue,
               str.lowercased().contains("error") || str.lowercased().contains("failed") {
                return .tripwire(
                    message: "Tool execution failed - error in output",
                    outputInfo: .dictionary([
                        "toolName": .string(data.tool.name),
                        "errorKeywords": .array([.string("error"), .string("failed")])
                    ]),
                    metadata: [
                        "severity": .string("medium"),
                        "action": .string("retry")
                    ]
                )
            }
            return .passed()
        }

        let tool = MockTool(name: "api_request")
        let data = ToolGuardrailData(
            tool: tool,
            arguments: ["endpoint": .string("/users")],
            agent: nil,
            context: nil
        )

        // When - error in output
        let errorOutput: SendableValue = .string("Request failed with error 500")
        let result = try await guardrail.validate(data, output: errorOutput)

        // Then
        #expect(result.tripwireTriggered == true)
        #expect(result.message == "Tool execution failed - error in output")
        #expect(result.metadata["severity"] == .string("medium"))

        if case let .dictionary(dict) = result.outputInfo {
            #expect(dict["toolName"] == .string("api_request"))
        } else {
            Issue.record("Expected dictionary outputInfo")
        }
    }
}

// MARK: - MockToolInputGuardrail

/// Mock implementation of ToolInputGuardrail for testing
struct MockToolInputGuardrail: ToolInputGuardrail {
    // MARK: Internal

    let name: String

    init(name: String, result: GuardrailResult) {
        self.name = name
        self.result = result
    }

    func validate(_: ToolGuardrailData) async throws -> GuardrailResult {
        result
    }

    // MARK: Private

    private let result: GuardrailResult
}

// MARK: - MockToolOutputGuardrail

/// Mock implementation of ToolOutputGuardrail for testing
struct MockToolOutputGuardrail: ToolOutputGuardrail {
    // MARK: Internal

    let name: String

    init(name: String, result: GuardrailResult) {
        self.name = name
        self.result = result
    }

    func validate(_: ToolGuardrailData, output _: SendableValue) async throws -> GuardrailResult {
        result
    }

    // MARK: Private

    private let result: GuardrailResult
}

// MARK: - MockAgentForGuardrails

/// Mock Agent for guardrail testing
struct MockAgentForGuardrails: Agent {
    let tools: [any AnyJSONTool] = []
    let instructions: String = "Mock agent for guardrail tests"
    let configuration: AgentConfiguration

    init(name: String) {
        configuration = AgentConfiguration(name: name)
    }

    func run(_ input: String, session _: (any Session)? = nil, hooks _: (any RunHooks)? = nil) async throws -> AgentResult {
        AgentResult(
            output: "Mock response to: \(input)",
            metadata: [:]
        )
    }

    nonisolated func stream(_ input: String, session _: (any Session)? = nil, hooks _: (any RunHooks)? = nil) -> AsyncThrowingStream<AgentEvent, Error> {
        AsyncThrowingStream { continuation in
            let result = AgentResult(output: "Mock response to: \(input)", metadata: [:])
            continuation.yield(.completed(result: result))
            continuation.finish()
        }
    }

    func cancel() async {
        // No-op for mock
    }
}
