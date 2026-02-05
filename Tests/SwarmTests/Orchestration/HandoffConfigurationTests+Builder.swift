// HandoffConfigurationTests+Builder.swift
// SwarmTests
//
// Tests for HandoffBuilder and handoff() convenience function.

import Foundation
@testable import Swarm
import Testing

// MARK: - HandoffBuilderTests

@Suite("HandoffBuilder Tests")
struct HandoffBuilderTests {
    @Test("HandoffBuilder creates basic configuration")
    func handoffBuilderBasic() async {
        let agent = MockHandoffAgent(name: "executor")

        let config = HandoffBuilder(to: agent).build()

        #expect(config.toolNameOverride == nil)
        #expect(config.toolDescription == nil)
        #expect(config.nestHandoffHistory == false)
    }

    @Test("HandoffBuilder supports fluent chaining")
    func handoffBuilderFluentChaining() async {
        let agent = MockHandoffAgent(name: "executor")

        actor CallbackState {
            var onHandoffCalled = false
            var isEnabledCalled = false

            func setOnHandoffCalled() { onHandoffCalled = true }
            func setIsEnabledCalled() { isEnabledCalled = true }

            func getOnHandoffCalled() -> Bool { onHandoffCalled }
            func getIsEnabledCalled() -> Bool { isEnabledCalled }
        }

        let state = CallbackState()

        let config = HandoffBuilder(to: agent)
            .toolName("custom_tool")
            .toolDescription("Custom description")
            .onHandoff { _, _ in
                await state.setOnHandoffCalled()
            }
            .inputFilter { data in
                var modified = data
                modified.metadata["filter_applied"] = .bool(true)
                return modified
            }
            .isEnabled { _, _ in
                await state.setIsEnabledCalled()
                return true
            }
            .nestHistory(true)
            .build()

        #expect(config.toolNameOverride == "custom_tool")
        #expect(config.toolDescription == "Custom description")
        #expect(config.onHandoff != nil)
        #expect(config.inputFilter != nil)
        #expect(config.isEnabled != nil)
        #expect(config.nestHandoffHistory == true)

        let context = AgentContext(input: "Test")
        let inputData = HandoffInputData(
            sourceAgentName: "source",
            targetAgentName: "target",
            input: "Test"
        )

        try? await config.onHandoff?(context, inputData)
        let filtered = config.inputFilter?(inputData)
        _ = await config.isEnabled?(context, agent)

        #expect(await state.getOnHandoffCalled())
        #expect(filtered?.metadata["filter_applied"]?.boolValue == true)
        #expect(await state.getIsEnabledCalled())
    }

    @Test("HandoffBuilder build produces valid configuration")
    func handoffBuilderBuild() async {
        let agent = MockHandoffAgent(name: "test_agent")

        let config = HandoffBuilder(to: agent)
            .toolName("transfer_to_test")
            .toolDescription("Transfer to test agent")
            .nestHistory(true)
            .build()

        #expect(config.effectiveToolName == "transfer_to_test")
        #expect(config.effectiveToolDescription == "Transfer to test agent")
        #expect(config.nestHandoffHistory == true)
    }

    @Test("HandoffBuilder is immutable (returns new instances)")
    func handoffBuilderImmutability() async {
        let agent = MockHandoffAgent(name: "executor")

        let builder1 = HandoffBuilder(to: agent)
        let builder2 = builder1.toolName("name1")
        let builder3 = builder1.toolName("name2")

        let config2 = builder2.build()
        let config3 = builder3.build()

        #expect(config2.toolNameOverride == "name1")
        #expect(config3.toolNameOverride == "name2")
    }

    @Test("HandoffBuilder is Sendable")
    func handoffBuilderSendable() async {
        let agent = MockHandoffAgent(name: "executor")
        let builder = HandoffBuilder(to: agent)
            .toolName("test")

        let config = await Task {
            builder.build()
        }.value

        #expect(config.toolNameOverride == "test")
    }
}

// MARK: - HandoffConvenienceFunctionTests

@Suite("handoff() Convenience Function Tests")
struct HandoffConvenienceFunctionTests {
    @Test("handoff() creates configuration with minimal parameters")
    func handoffConvenienceFunctionMinimal() async {
        let agent = MockHandoffAgent(name: "executor")

        let config = handoff(to: agent)

        #expect(config.toolNameOverride == nil)
        #expect(config.toolDescription == nil)
        #expect(config.nestHandoffHistory == false)
    }

    @Test("handoff() creates configuration with all parameters")
    func handoffConvenienceFunctionFull() async {
        let agent = MockHandoffAgent(name: "executor")

        actor CallbackState {
            var callbackExecuted = false
            func setExecuted() { callbackExecuted = true }
            func getExecuted() -> Bool { callbackExecuted }
        }

        let state = CallbackState()

        let config = handoff(
            to: agent,
            toolName: "execute_task",
            toolDescription: "Execute the task",
            onHandoff: { _, _ in
                await state.setExecuted()
            },
            inputFilter: { data in
                var modified = data
                modified.metadata["filtered"] = .bool(true)
                return modified
            },
            isEnabled: { _, _ in true },
            nestHistory: true
        )

        #expect(config.toolNameOverride == "execute_task")
        #expect(config.toolDescription == "Execute the task")
        #expect(config.onHandoff != nil)
        #expect(config.inputFilter != nil)
        #expect(config.isEnabled != nil)
        #expect(config.nestHandoffHistory == true)

        let context = AgentContext(input: "Test")
        let inputData = HandoffInputData(
            sourceAgentName: "source",
            targetAgentName: "target",
            input: "Test"
        )

        try? await config.onHandoff?(context, inputData)
        #expect(await state.getExecuted())
    }

    @Test("handoff() produces equivalent result to HandoffConfiguration init")
    func handoffConvenienceFunctionEquivalence() async {
        let agent = MockHandoffAgent(name: "executor")

        let configViaFunction = handoff(
            to: agent,
            toolName: "test_tool",
            toolDescription: "Test description",
            nestHistory: true
        )

        let configViaDirect = HandoffConfiguration(
            targetAgent: agent,
            toolNameOverride: "test_tool",
            toolDescription: "Test description",
            nestHandoffHistory: true
        )

        #expect(configViaFunction.toolNameOverride == configViaDirect.toolNameOverride)
        #expect(configViaFunction.toolDescription == configViaDirect.toolDescription)
        #expect(configViaFunction.nestHandoffHistory == configViaDirect.nestHandoffHistory)
    }
}

// MARK: - HandoffConfigurationIntegrationTests

@Suite("Handoff Configuration Integration Tests")
struct HandoffConfigurationIntegrationTests {
    @Test("Full handoff workflow with callbacks and filters")
    func fullHandoffWorkflow() async throws {
        let targetAgent = MockHandoffAgent(name: "executor")

        actor WorkflowLogger {
            var workflowLog: [String] = []
            func append(_ message: String) { workflowLog.append(message) }
            func getLog() -> [String] { workflowLog }
        }

        let logger = WorkflowLogger()

        let config = HandoffBuilder(to: targetAgent)
            .toolName("execute_plan")
            .toolDescription("Execute the planned steps")
            .onHandoff { context, inputData in
                await logger.append("onHandoff: \(inputData.sourceAgentName) -> \(inputData.targetAgentName)")
                await context.set("handoff_logged", value: .bool(true))
            }
            .inputFilter { data in
                var modified = data
                modified.metadata["processed_at"] = .double(Date().timeIntervalSince1970)
                modified.metadata["workflow_step"] = .string("filtered")
                return modified
            }
            .isEnabled { context, _ in
                let enabled = await context.get("can_handoff")?.boolValue ?? true
                await logger.append("isEnabled: \(enabled)")
                return enabled
            }
            .nestHistory(true)
            .build()

        let context = AgentContext(input: "Initial input")
        await context.set("can_handoff", value: .bool(true))

        let inputData = HandoffInputData(
            sourceAgentName: "planner",
            targetAgentName: "executor",
            input: "Execute step 1"
        )

        let enabled = await config.isEnabled?(context, targetAgent)
        #expect(enabled == true)

        try await config.onHandoff?(context, inputData)

        let filteredData = config.inputFilter?(inputData)

        let workflowLog = await logger.getLog()
        #expect(workflowLog.count == 2)
        #expect(workflowLog[0].contains("isEnabled: true"))
        #expect(workflowLog[1].contains("onHandoff"))

        let handoffLogged = await context.get("handoff_logged")?.boolValue
        #expect(handoffLogged == true)

        #expect(filteredData?.metadata["processed_at"] != nil)
        #expect(filteredData?.metadata["workflow_step"]?.stringValue == "filtered")
    }

    @Test("Multiple configurations with different agents")
    func multipleConfigurations() async {
        let plannerAgent = MockHandoffAgent(name: "planner")
        let executorAgent = MockHandoffAgent(name: "executor")
        let reviewerAgent = MockHandoffAgent(name: "reviewer")

        let configs: [AnyHandoffConfiguration] = [
            AnyHandoffConfiguration(handoff(
                to: plannerAgent,
                toolName: "plan_task",
                toolDescription: "Create a plan for the task"
            )),
            AnyHandoffConfiguration(handoff(
                to: executorAgent,
                toolName: "execute_task",
                toolDescription: "Execute the planned task"
            )),
            AnyHandoffConfiguration(handoff(
                to: reviewerAgent,
                toolName: "review_task",
                toolDescription: "Review the executed task"
            ))
        ]

        #expect(configs.count == 3)

        let toolNames = Set(configs.map(\.effectiveToolName))
        #expect(toolNames.count == 3)
        #expect(toolNames.contains("plan_task"))
        #expect(toolNames.contains("execute_task"))
        #expect(toolNames.contains("review_task"))
    }
}
