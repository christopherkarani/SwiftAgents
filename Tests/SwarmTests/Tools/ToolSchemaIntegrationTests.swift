// ToolSchemaIntegrationTests.swift
// SwarmTests
//
// Coverage for typed Tool bridging and ToolSchema surfacing.

import Foundation
@testable import Swarm
import Testing

@Suite("ToolSchema Integration Tests")
struct ToolSchemaIntegrationTests {
    @Test("ToolRegistry bridges typed Tool execution")
    func registryBridgesTypedTool() async throws {
        let registry = ToolRegistry(tools: [SchemaEchoTool()])
        let result = try await registry.execute(
            toolNamed: "echo",
            arguments: ["text": .string("hello")]
        )

        let outputText = result.dictionaryValue?["text"]?.stringValue
        #expect(outputText == "hello")
    }

    @Test("ToolRegistry exposes ToolSchema for typed tools")
    func registrySchemas() async {
        let registry = ToolRegistry(tools: [SchemaEchoTool()])
        let schemas = await registry.schemas

        #expect(schemas.count == 1)
        #expect(schemas[0].name == "echo")
        #expect(schemas[0].description == "Echoes input text")
        #expect(schemas[0].parameters.first?.name == "text")
    }

    @Test("Agents accept typed Tool arrays")
    func agentsAcceptTypedTools() {
        let tool = SchemaEchoTool()

        let agent = Agent(tools: [tool])
        #expect(agent.tools.count == 1)
        #expect(agent.tools.first?.name == "echo")

        let react = ReActAgent(tools: [tool])
        #expect(react.tools.count == 1)
        #expect(react.tools.first?.name == "echo")

        let planAndExecute = PlanAndExecuteAgent(tools: [tool])
        #expect(planAndExecute.tools.count == 1)
        #expect(planAndExecute.tools.first?.name == "echo")
    }
}

// MARK: - Test Fixtures

private struct SchemaEchoTool: Tool, Sendable {
    struct Input: Codable, Sendable {
        let text: String
    }

    struct Output: Codable, Sendable {
        let text: String
    }

    let name = "echo"
    let description = "Echoes input text"
    let parameters: [ToolParameter] = [
        ToolParameter(name: "text", description: "Text to echo", type: .string)
    ]

    func execute(_ input: Input) async throws -> Output {
        Output(text: input.text)
    }
}
