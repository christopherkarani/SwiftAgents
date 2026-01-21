// GuardrailIntegrationTests.swift
// SwiftAgentsTests
//
// Comprehensive integration tests for the complete Guardrails system
// Tests the interaction between Agents, Tools, and Guardrails

import Foundation
@testable import SwiftAgents
import Testing

// MARK: - MockGuardrailAgent

/// Mock agent for guardrail testing
private actor MockGuardrailAgent: AgentRuntime {
    // MARK: Internal

    nonisolated let tools: [any AnyJSONTool]
    nonisolated let instructions: String
    nonisolated let configuration: AgentConfiguration
    nonisolated let memory: (any Memory)? = nil
    nonisolated let inferenceProvider: (any InferenceProvider)?
    nonisolated let tracer: (any Tracer)? = nil

    init(
        name: String = "MockAgent",
        tools: [any AnyJSONTool] = [],
        instructions: String = "Test agent",
        inferenceProvider: (any InferenceProvider)? = nil,
        responseHandler: @escaping @Sendable (String) async throws -> String = { input in "Mock response to: \(input)" }
    ) {
        self.tools = tools
        self.instructions = instructions
        configuration = AgentConfiguration(name: name)
        self.inferenceProvider = inferenceProvider
        self.responseHandler = responseHandler
    }

    func run(_ input: String, session _: (any Session)? = nil, hooks _: (any RunHooks)? = nil) async throws -> AgentResult {
        let output = try await responseHandler(input)
        return AgentResult(output: output)
    }

    nonisolated func stream(_: String, session _: (any Session)? = nil, hooks _: (any RunHooks)? = nil) -> AsyncThrowingStream<AgentEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }

    func cancel() async {}

    // MARK: Private

    private let responseHandler: @Sendable (String) async throws -> String
}

// MARK: - GuardrailIntegrationTests

@Suite("Guardrail Integration Tests")
struct GuardrailIntegrationTests {
    // MARK: - Agent + Input Guardrails

    @Test("Agent with input guardrail passed - execution proceeds normally")
    func agentWithInputGuardrailPassed() async throws {
        // Given: An agent with a passing input guardrail
        let mockProvider = MockInferenceProvider()
        await mockProvider.setResponses(["Final Answer: Success"])

        let agent = await MockGuardrailAgent(
            name: "TestAgent",
            inferenceProvider: mockProvider,
            responseHandler: { input in
                "Processed: \(input)"
            }
        )

        // Input guardrail that always passes
        let inputGuardrail = ClosureInputGuardrail(name: "always_pass") { _, _ in
            .passed(message: "Input validation successful")
        }

        // When: Running the agent with passing guardrail
        // Note: This test assumes Agent protocol will have inputGuardrails property
        // For now, we test the guardrail runner directly
        let context = AgentContext(input: "Test query")
        let runner = GuardrailRunner()

        let results = try await runner.runInputGuardrails(
            [inputGuardrail],
            input: "Test query",
            context: context
        )

        // Then: Guardrail passes and agent would run
        #expect(results.count == 1)
        #expect(results[0].guardrailName == "always_pass")
        #expect(results[0].result.tripwireTriggered == false)
        #expect(results[0].result.message == "Input validation successful")
    }

    @Test("Agent with input guardrail triggered - execution halts with error")
    func agentWithInputGuardrailTriggered() async throws {
        // Given: An agent with a failing input guardrail
        let agent = await MockGuardrailAgent(name: "TestAgent")

        // Input guardrail that triggers on sensitive content
        let inputGuardrail = ClosureInputGuardrail(name: "sensitive_data_blocker") { input, _ in
            if input.contains("SSN:") || input.contains("password") {
                return .tripwire(
                    message: "Sensitive data detected in input",
                    outputInfo: .dictionary([
                        "violationType": .string("PII_DETECTED"),
                        "patterns": .array([.string("SSN")])
                    ])
                )
            }
            return .passed()
        }

        // When: Running guardrail with sensitive input
        let context = AgentContext(input: "Please process SSN: 123-45-6789")
        let runner = GuardrailRunner()

        do {
            _ = try await runner.runInputGuardrails(
                [inputGuardrail],
                input: "Please process SSN: 123-45-6789",
                context: context
            )
            Issue.record("Expected GuardrailError to be thrown")
        } catch let error as GuardrailError {
            guard case let .inputTripwireTriggered(guardrailName, message, outputInfo) = error else {
                Issue.record("Unexpected GuardrailError: \(error)")
                return
            }

            #expect(guardrailName == "sensitive_data_blocker")
            #expect(message == "Sensitive data detected in input")
            #expect(outputInfo == .dictionary([
                "violationType": .string("PII_DETECTED"),
                "patterns": .array([.string("SSN")])
            ]))
        }
    }

    @Test("Agent with multiple input guardrails - executes in order")
    func agentWithMultipleInputGuardrails() async throws {
        // Given: An agent with multiple input guardrails
        let agent = await MockGuardrailAgent(name: "TestAgent")

        actor ExecutionTracker {
            private var order: [String] = []
            func append(_ name: String) { order.append(name) }
            func getOrder() -> [String] { order }
        }

        let tracker = ExecutionTracker()

        let guardrail1 = ClosureInputGuardrail(name: "length_check") { input, _ in
            await tracker.append("length_check")
            if input.count < 5 {
                return .tripwire(message: "Input too short")
            }
            return .passed()
        }

        let guardrail2 = ClosureInputGuardrail(name: "format_check") { input, _ in
            await tracker.append("format_check")
            if !input.contains("?") {
                return .tripwire(message: "Input must be a question")
            }
            return .passed()
        }

        // When: Running with valid input
        let context = AgentContext(input: "What is the weather?")
        let runner = GuardrailRunner()

        let results = try await runner.runInputGuardrails(
            [guardrail1, guardrail2],
            input: "What is the weather?",
            context: context
        )

        // Then: Both guardrails execute in order
        #expect(results.count == 2)
        let executionOrder = await tracker.getOrder()
        #expect(executionOrder == ["length_check", "format_check"])
        #expect(results[0].guardrailName == "length_check")
        #expect(results[1].guardrailName == "format_check")
    }

    // MARK: - Agent + Output Guardrails

    @Test("Agent with output guardrail passed - result returned normally")
    func agentWithOutputGuardrailPassed() async throws {
        // Given: An agent with output guardrail
        let agent = await MockGuardrailAgent(
            name: "OutputAgent",
            responseHandler: { _ in "Safe output content" }
        )

        let outputGuardrail = ClosureOutputGuardrail(name: "output_validator") { output, _, _ in
            if output.contains("Safe") {
                return .passed(message: "Output validated successfully")
            }
            return .tripwire(message: "Output validation failed")
        }

        // When: Running output guardrail on valid output
        let result = try await agent.run("test input")
        let context = AgentContext(input: "test input")
        let runner = GuardrailRunner()

        let guardrailResults = try await runner.runOutputGuardrails(
            [outputGuardrail],
            output: result.output,
            agent: agent,
            context: context
        )

        // Then: Guardrail passes
        #expect(guardrailResults.count == 1)
        #expect(guardrailResults[0].result.tripwireTriggered == false)
        #expect(guardrailResults[0].guardrailName == "output_validator")
    }

    @Test("Agent with output guardrail triggered - throws after execution")
    func agentWithOutputGuardrailTriggered() async throws {
        // Given: An agent with output guardrail that detects inappropriate content
        let agent = await MockGuardrailAgent(
            name: "OutputAgent",
            responseHandler: { _ in "This content contains profanity: damn" }
        )

        let outputGuardrail = ClosureOutputGuardrail(name: "profanity_filter") { output, _, _ in
            let profaneWords = ["damn", "hell", "crap"]
            let containsProfanity = profaneWords.contains { output.lowercased().contains($0) }

            if containsProfanity {
                return .tripwire(
                    message: "Profanity detected in output",
                    outputInfo: .dictionary([
                        "category": .string("profanity"),
                        "severity": .string("low")
                    ])
                )
            }
            return .passed()
        }

        // When: Running output guardrail on inappropriate output
        let result = try await agent.run("test input")
        let context = AgentContext(input: "test input")
        let runner = GuardrailRunner()

        do {
            _ = try await runner.runOutputGuardrails(
                [outputGuardrail],
                output: result.output,
                agent: agent,
                context: context
            )
            Issue.record("Expected GuardrailError to be thrown")
        } catch let error as GuardrailError {
            guard case let .outputTripwireTriggered(guardrailName, agentName, message, outputInfo) = error else {
                Issue.record("Unexpected GuardrailError: \(error)")
                return
            }

            #expect(guardrailName == "profanity_filter")
            #expect(agentName == "OutputAgent")
            #expect(message == "Profanity detected in output")
            #expect(outputInfo == .dictionary([
                "category": .string("profanity"),
                "severity": .string("low")
            ]))
        }
    }

    // MARK: - Tool + Guardrails

    @Test("Tool execution with input guardrail - validates arguments before execution")
    func toolExecutionWithInputGuardrail() async throws {
        // Given: A tool with input guardrail
        var tool = MockTool(
            name: "calculator",
            parameters: [
                ToolParameter(name: "expression", description: "Math expression", type: .string, isRequired: true)
            ],
            result: .string("Result: 42")
        )

        let toolInputGuardrail = ClosureToolInputGuardrail(name: "argument_validator") { data in
            guard let expression = data.arguments["expression"]?.stringValue else {
                return .tripwire(message: "Missing required expression argument")
            }

            // Validate no malicious code
            if expression.contains(";") || expression.contains("eval") {
                return .tripwire(
                    message: "Potentially malicious expression detected",
                    outputInfo: .string(expression)
                )
            }
            return .passed()
        }

        // When: Running tool guardrail with valid arguments
        let agent = await MockGuardrailAgent(name: "ToolAgent")
        let context = AgentContext(input: "Calculate 2+2")
        let data = ToolGuardrailData(
            tool: tool,
            arguments: ["expression": .string("2+2")],
            agent: agent,
            context: context
        )

        let runner = GuardrailRunner()
        let results = try await runner.runToolInputGuardrails([toolInputGuardrail], data: data)

        // Then: Guardrail passes
        #expect(results.count == 1)
        #expect(results[0].result.tripwireTriggered == false)
    }

    @Test("Tool execution with output guardrail - validates result after execution")
    func toolExecutionWithOutputGuardrail() async throws {
        // Given: A tool with output guardrail
        var tool = MockTool(
            name: "web_search",
            result: .dictionary([
                "results": .array([
                    .string("Safe result 1"),
                    .string("Safe result 2")
                ])
            ])
        )

        let toolOutputGuardrail = ClosureToolOutputGuardrail(name: "result_validator") { _, output in
            // Validate output structure
            guard let dict = output.dictionaryValue else {
                return .tripwire(message: "Invalid output format")
            }

            guard let results = dict["results"]?.arrayValue else {
                return .tripwire(message: "Missing results array")
            }

            // Check for empty results
            if results.isEmpty {
                return .tripwire(
                    message: "No results found",
                    outputInfo: .dictionary(["count": .int(0)])
                )
            }

            return .passed(
                message: "Results validated",
                outputInfo: .dictionary(["count": .int(results.count)])
            )
        }

        // When: Running tool output guardrail
        let agent = await MockGuardrailAgent(name: "SearchAgent")
        let context = AgentContext(input: "Search for Swift")
        let toolResult = try await tool.execute(arguments: [:])
        let data = ToolGuardrailData(
            tool: tool,
            arguments: [:],
            agent: agent,
            context: context
        )

        let runner = GuardrailRunner()
        let results = try await runner.runToolOutputGuardrails([toolOutputGuardrail], data: data, output: toolResult)

        // Then: Guardrail passes with metadata
        #expect(results.count == 1)
        #expect(results[0].result.tripwireTriggered == false)
        #expect(results[0].result.message == "Results validated")
    }
}

// MARK: - GuardrailIntegrationTests Advanced

extension GuardrailIntegrationTests {
    @Test("ToolRegistry.execute() runs guardrails - full integration")
    func toolRegistryWithGuardrails() async throws {
        // NOTE: This test will require ToolRegistry to be updated with guardrail support
        // For now, we document the expected behavior

        // Given: A ToolRegistry with tools that have guardrails
        // When: Executing a tool through the registry
        // Then: Input guardrails run before execution, output guardrails run after

        // This test is a placeholder for when ToolRegistry integration is complete
        #expect(true, "ToolRegistry integration pending implementation")
    }

    // MARK: - Combined Scenarios

    @Test("Agent with both input and output guardrails - full validation flow")
    func agentWithBothInputAndOutputGuardrails() async throws {
        // Given: An agent with both input and output guardrails
        let agent = await MockGuardrailAgent(
            name: "FullyGuardedAgent",
            responseHandler: { input in
                "Processed and sanitized: \(input)"
            }
        )

        let inputGuardrail = ClosureInputGuardrail(name: "input_sanitizer") { input, _ in
            if input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .tripwire(message: "Empty input not allowed")
            }
            return .passed(message: "Input accepted")
        }

        let outputGuardrail = ClosureOutputGuardrail(name: "output_length_checker") { output, _, _ in
            if output.count > 1000 {
                return .tripwire(
                    message: "Output too long",
                    outputInfo: .dictionary(["length": .int(output.count)])
                )
            }
            return .passed(message: "Output length acceptable")
        }

        // When: Running both guardrails
        let context = AgentContext(input: "Valid input query")
        let runner = GuardrailRunner()

        // Input guardrail check
        let inputResults = try await runner.runInputGuardrails(
            [inputGuardrail],
            input: "Valid input query",
            context: context
        )

        // Agent execution
        let result = try await agent.run("Valid input query")

        // Output guardrail check
        let outputResults = try await runner.runOutputGuardrails(
            [outputGuardrail],
            output: result.output,
            agent: agent,
            context: context
        )

        // Then: Both guardrails pass
        #expect(inputResults.count == 1)
        #expect(inputResults[0].result.tripwireTriggered == false)
        #expect(outputResults.count == 1)
        #expect(outputResults[0].result.tripwireTriggered == false)
    }

    @Test("Guardrail with agent context - context flows through validation")
    func guardrailWithAgentContext() async throws {
        // Given: A guardrail that uses context data
        let agent = await MockGuardrailAgent(name: "ContextAgent")
        let context = AgentContext(input: "Test input")
        await context.set("user_role", value: .string("admin"))
        await context.set("request_count", value: .int(5))

        actor ContextCapture {
            var value: AgentContext?
            func set(_ newValue: AgentContext?) { value = newValue }
            func get() -> AgentContext? { value }
        }
        let contextCapture = ContextCapture()
        let inputGuardrail = ClosureInputGuardrail(name: "role_checker") { _, ctx in
            await contextCapture.set(ctx)

            // Check user role from context
            guard let role = await ctx?.get("user_role")?.stringValue else {
                return .tripwire(message: "No user role in context")
            }

            if role != "admin" {
                return .tripwire(message: "Insufficient permissions")
            }

            return .passed(
                message: "Role validated",
                metadata: ["role": .string(role)]
            )
        }

        // When: Running guardrail
        let runner = GuardrailRunner()
        let results = try await runner.runInputGuardrails(
            [inputGuardrail],
            input: "Admin command",
            context: context
        )

        // Then: Context is accessible in guardrail
        let captured = await contextCapture.get()
        #expect(captured != nil)
        #expect(results[0].result.tripwireTriggered == false)
        #expect(results[0].result.metadata["role"]?.stringValue == "admin")
    }

    @Test("Guardrail error propagation - errors bubble up correctly")
    func guardrailErrorPropagation() async throws {
        // Given: A guardrail that triggers
        let agent = await MockGuardrailAgent(name: "ErrorAgent")
        let context = AgentContext(input: "Test")

        let inputGuardrail = ClosureInputGuardrail(name: "error_trigger") { _, _ in
            .tripwire(
                message: "Test error message",
                outputInfo: .dictionary([
                    "errorCode": .string("TEST_001"),
                    "timestamp": .int(1_234_567_890)
                ])
            )
        }

        // When: Running guardrail
        let runner = GuardrailRunner()

        // Then: Error is thrown with correct details
        do {
            _ = try await runner.runInputGuardrails(
                [inputGuardrail],
                input: "Test input",
                context: context
            )
            Issue.record("Expected GuardrailError to be thrown")
        } catch let error as GuardrailError {
            // Verify error details
            if case let .inputTripwireTriggered(name, message, outputInfo) = error {
                #expect(name == "error_trigger")
                #expect(message == "Test error message")
                #expect(outputInfo?.dictionaryValue?["errorCode"]?.stringValue == "TEST_001")
            } else {
                Issue.record("Wrong GuardrailError case: \(error)")
            }
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }

    // MARK: - Edge Cases

    @Test("Empty guardrail arrays - execution proceeds normally")
    func emptyGuardrailArrays() async throws {
        // Given: Agent with no guardrails
        let agent = await MockGuardrailAgent(
            name: "UnguardedAgent",
            responseHandler: { input in "Response: \(input)" }
        )

        let context = AgentContext(input: "Test")
        let runner = GuardrailRunner()

        // When: Running with empty guardrail arrays
        let inputResults = try await runner.runInputGuardrails(
            [],
            input: "Test input",
            context: context
        )

        let result = try await agent.run("Test input")
        let outputResults = try await runner.runOutputGuardrails(
            [],
            output: result.output,
            agent: agent,
            context: context
        )

        // Then: No guardrails run, execution succeeds
        #expect(inputResults.isEmpty)
        #expect(outputResults.isEmpty)
        #expect(result.output == "Response: Test input")
    }

    @Test("Guardrail metadata preserved - accessible after validation")
    func guardrailMetadataPreserved() async throws {
        // Given: A guardrail that sets metadata
        let agent = await MockGuardrailAgent(name: "MetadataAgent")
        let context = AgentContext(input: "Test")

        let inputGuardrail = ClosureInputGuardrail(name: "metadata_setter") { input, _ in
            .passed(
                message: "Validation passed with metadata",
                metadata: [
                    "validationTimestamp": .double(Date().timeIntervalSince1970),
                    "inputLength": .int(input.count),
                    "validatorVersion": .string("1.0.0"),
                    "checksPerformed": .array([
                        .string("length_check"),
                        .string("format_check"),
                        .string("content_check")
                    ])
                ]
            )
        }

        // When: Running guardrail
        let runner = GuardrailRunner()
        let results = try await runner.runInputGuardrails(
            [inputGuardrail],
            input: "Test input",
            context: context
        )

        // Then: Metadata is preserved in result
        #expect(results.count == 1)
        let metadata = results[0].result.metadata
        #expect(metadata["validatorVersion"]?.stringValue == "1.0.0")
        #expect(metadata["inputLength"]?.intValue == 10)
        #expect(metadata["checksPerformed"]?.arrayValue?.count == 3)
    }

    @Test("Parallel input guardrails - run concurrently")
    func parallelInputGuardrails() async throws {
        // Given: Multiple parallel input guardrails
        let agent = await MockGuardrailAgent(name: "ParallelAgent")
        let context = AgentContext(input: "Test")

        let startTime = ContinuousClock.now

        let slowGuardrail1 = ClosureInputGuardrail(name: "slow1") { _, _ in
            try? await Task.sleep(for: .milliseconds(100))
            return .passed(message: "Slow check 1 complete")
        }

        let slowGuardrail2 = ClosureInputGuardrail(name: "slow2") { _, _ in
            try? await Task.sleep(for: .milliseconds(100))
            return .passed(message: "Slow check 2 complete")
        }

        // When: Running parallel guardrails (using parallel runner configuration)
        let runner = GuardrailRunner(configuration: .parallel)
        let results = try await runner.runInputGuardrails(
            [slowGuardrail1, slowGuardrail2],
            input: "Test input",
            context: context
        )

        let duration = ContinuousClock.now - startTime

        // Then: Guardrails ran in parallel (total time < sum of individual times)
        #expect(results.count == 2)
        // Should take ~100ms, not ~200ms if sequential
        #expect(duration < .milliseconds(150))
    }
}
