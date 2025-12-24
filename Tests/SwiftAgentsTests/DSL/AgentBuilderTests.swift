// AgentBuilderTests.swift
// SwiftAgentsTests
//
// Tests for AgentBuilder DSL for declarative agent construction.

import Foundation
@testable import SwiftAgents
import Testing

// MARK: - AgentBuilder Tests

@Suite("AgentBuilder DSL Tests")
struct AgentBuilderTests {
    // MARK: - Basic Agent Building

    @Test("Build agent with instructions")
    func buildAgentWithInstructions() async throws {
        let agent = ReActAgent {
            Instructions("You are a helpful assistant.")
        }

        #expect(agent.instructions == "You are a helpful assistant.")
    }

    @Test("Build agent with single tool")
    func buildAgentWithSingleTool() async throws {
        let agent = ReActAgent {
            Instructions("You are a calculator.")
            Tools {
                MockTool(name: "calculator")
            }
        }

        #expect(agent.tools.count == 1)
        #expect(agent.tools[0].name == "calculator")
    }

    @Test("Build agent with multiple tools")
    func buildAgentWithMultipleTools() async throws {
        let agent = ReActAgent {
            Instructions("You are a multi-tool assistant.")
            Tools {
                MockTool(name: "calculator")
                MockTool(name: "weather")
                MockTool(name: "search")
            }
        }

        #expect(agent.tools.count == 3)
        #expect(agent.tools.map(\.name) == ["calculator", "weather", "search"])
    }

    @Test("Build agent with memory")
    func buildAgentWithMemory() async throws {
        let agent = ReActAgent {
            Instructions("You remember conversations.")
            AgentMemoryComponent(ConversationMemory(maxMessages: 50))
        }

        #expect(agent.memory != nil)
    }

    @Test("Build agent with configuration")
    func buildAgentWithConfiguration() async throws {
        let agent = ReActAgent {
            Instructions("Configured agent.")
            Configuration(.default.maxIterations(5).temperature(0.5))
        }

        #expect(agent.configuration.maxIterations == 5)
        #expect(agent.configuration.temperature == 0.5)
    }

    // MARK: - Complete Agent Building

    @Test("Build complete agent with all components")
    func buildCompleteAgent() async throws {
        let mockProvider = MockInferenceProvider()

        let agent = ReActAgent {
            Instructions("You are a complete assistant.")

            Tools {
                MockTool(name: "tool1")
                MockTool(name: "tool2")
            }

            AgentMemoryComponent(ConversationMemory(maxMessages: 100))

            Configuration(.default
                .maxIterations(10)
                .temperature(0.7)
                .timeout(.seconds(60))
            )

            InferenceProviderComponent(mockProvider)
        }

        #expect(agent.instructions == "You are a complete assistant.")
        #expect(agent.tools.count == 2)
        #expect(agent.memory != nil)
        #expect(agent.configuration.maxIterations == 10)
        #expect(agent.inferenceProvider != nil)
    }

    // MARK: - Conditional Building

    @Test("Build agent with conditional tools")
    func buildAgentWithConditionalTools() async throws {
        let includeDebugTool = true

        let agent = ReActAgent {
            Instructions("Conditional tools agent.")
            Tools {
                MockTool(name: "required_tool")
                if includeDebugTool {
                    MockTool(name: "debug_tool")
                }
            }
        }

        #expect(agent.tools.count == 2)
        #expect(agent.tools.contains { $0.name == "debug_tool" })
    }

    @Test("Build agent without conditional tool")
    func buildAgentWithoutConditionalTool() async throws {
        let includeDebugTool = false

        let agent = ReActAgent {
            Instructions("Conditional tools agent.")
            Tools {
                MockTool(name: "required_tool")
                if includeDebugTool {
                    MockTool(name: "debug_tool")
                }
            }
        }

        #expect(agent.tools.count == 1)
        #expect(agent.tools[0].name == "required_tool")
    }

    // MARK: - Tools Array Building

    #if canImport(Darwin)
        @Test("Tools block builds array of tools")
        func toolsBlockBuildsArray() async throws {
            let agent = ReActAgent {
                Instructions("Multi-tool agent.")
                Tools {
                    CalculatorTool()
                    DateTimeTool()
                    StringTool()
                }
            }

            #expect(agent.tools.count == 3)
        }
    #endif

    @Test("Tools block with loop")
    func toolsBlockWithLoop() async throws {
        let toolNames = ["a", "b", "c"]

        let agent = ReActAgent {
            Instructions("Loop-based tools.")
            Tools {
                for name in toolNames {
                    MockTool(name: name)
                }
            }
        }

        #expect(agent.tools.count == 3)
        #expect(agent.tools.map(\.name) == ["a", "b", "c"])
    }

    // MARK: - Memory Configuration

    @Test("Build agent with hybrid memory")
    func buildAgentWithHybridMemory() async throws {
        let agent = ReActAgent {
            Instructions("Hybrid memory agent.")
            AgentMemoryComponent(HybridMemory(
                configuration: .init(
                    shortTermMaxMessages: 50,
                    longTermSummaryTokens: 2000
                )
            ))
        }

        #expect(agent.memory != nil)
    }

    // MARK: - Fluent Configuration in Builder

    @Test("Configuration uses fluent API in builder")
    func configurationFluentAPIInBuilder() async throws {
        let agent = ReActAgent {
            Instructions("Fluent config agent.")
            Configuration(
                AgentConfiguration.default
                    .maxIterations(20)
                    .temperature(0.9)
                    .timeout(.seconds(120))
                    .enableStreaming(true)
            )
        }

        #expect(agent.configuration.maxIterations == 20)
        #expect(agent.configuration.temperature == 0.9)
    }

    // MARK: - Builder Type Safety

    @Test("Builder enforces component types")
    func builderEnforcesComponentTypes() async throws {
        // This test verifies type safety at compile time
        // Invalid components would fail to compile
        let agent = ReActAgent {
            Instructions("Type-safe agent.")
            // Only valid components compile
        }

        #expect(agent.instructions == "Type-safe agent.")
    }

    // MARK: - Component Order Independence

    @Test("Component order doesn't matter")
    func componentOrderDoesntMatter() async throws {
        // Tools before Instructions
        let agent1 = ReActAgent {
            Tools {
                MockTool(name: "tool1")
            }
            Instructions("Agent 1")
        }

        // Instructions before Tools
        let agent2 = ReActAgent {
            Instructions("Agent 2")
            Tools {
                MockTool(name: "tool1")
            }
        }

        #expect(agent1.tools.count == agent2.tools.count)
    }

    // MARK: - Empty Tools

    @Test("Build agent with no tools")
    func buildAgentWithNoTools() async throws {
        let agent = ReActAgent {
            Instructions("No tools agent.")
        }

        #expect(agent.tools.isEmpty)
    }

    // MARK: - Agent Execution After Building

    @Test("Built agent can execute")
    func builtAgentCanExecute() async throws {
        let mockProvider = MockInferenceProvider(responses: [
            "Final Answer: Built successfully"
        ])

        let agent = ReActAgent {
            Instructions("Executable agent.")
            InferenceProviderComponent(mockProvider)
        }

        let result = try await agent.run("Test input")
        #expect(result.output.contains("Built successfully"))
    }
}

// NOTE: AgentComponent, Instructions, Tools, Memory, Configuration, InferenceProviderComponent,
// and ToolArrayBuilder are now public types exported from SwiftAgents.
