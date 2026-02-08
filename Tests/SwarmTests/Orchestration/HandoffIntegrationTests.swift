// HandoffIntegrationTests.swift
// SwarmTests
//
// Integration tests for agent handoffs.
// Mock types are defined in HandoffIntegrationTests+Mocks.swift

import Foundation
@testable import Swarm
import Testing

// MARK: - HandoffCoordinatorOnHandoffCallbackTests

@Suite("HandoffCoordinator OnHandoff Callback Tests")
struct HandoffCoordinatorOnHandoffCallbackTests {
    @Test("Callback is invoked before handoff execution")
    func handoffWithOnHandoffCallback() async throws {
        let sourceAgent = MockIntegrationTestAgent(name: "source")
        let targetAgent = MockIntegrationTestAgent(name: "target")
        let testState = HandoffTestState()

        let coordinator = HandoffCoordinator()
        await coordinator.register(sourceAgent, as: "source")
        await coordinator.register(targetAgent, as: "target")

        let config = AnyHandoffConfiguration(
            targetAgent: targetAgent,
            onHandoff: { _, inputData in
                await testState.setOnHandoffCalled()
                await testState.setCapturedNames(
                    source: inputData.sourceAgentName,
                    target: inputData.targetAgentName
                )
                await testState.setCapturedInput(inputData.input)
            }
        )

        let request = HandoffRequest(
            sourceAgentName: "source",
            targetAgentName: "target",
            input: "Test handoff input"
        )

        let context = AgentContext(input: "Test")
        _ = try await coordinator.executeHandoff(request, context: context, configuration: config, hooks: nil)

        #expect(await testState.getOnHandoffCalled())
        #expect(await testState.getCapturedSourceName() == "source")
        #expect(await testState.getCapturedTargetName() == "target")
        #expect(await testState.getCapturedInput() == "Test handoff input")
    }

    @Test("Callback errors are logged but do not fail handoff")
    func handoffCallbackErrorDoesNotFailHandoff() async throws {
        struct CallbackTestError: Error {}

        let targetAgent = MockIntegrationTestAgent(name: "target")
        let testState = HandoffTestState()

        let coordinator = HandoffCoordinator()
        await coordinator.register(targetAgent, as: "target")

        let config = AnyHandoffConfiguration(
            targetAgent: targetAgent,
            onHandoff: { _, _ in
                await testState.setOnHandoffCalled()
                throw CallbackTestError()
            }
        )

        let request = HandoffRequest(
            sourceAgentName: "source",
            targetAgentName: "target",
            input: "Test input"
        )

        let context = AgentContext(input: "Test")

        let result = try await coordinator.executeHandoff(
            request,
            context: context,
            configuration: config,
            hooks: nil
        )

        #expect(await testState.getOnHandoffCalled())
        #expect(result.targetAgentName == "target")
        #expect(result.result.output.contains("target"))
    }
}

// MARK: - HandoffCoordinatorInputFilterTests

@Suite("HandoffCoordinator Input Filter Tests")
struct HandoffCoordinatorInputFilterTests {
    @Test("Filter transforms HandoffInputData")
    func handoffWithInputFilter() async throws {
        let targetAgent = MockIntegrationTestAgent(name: "target")
        let testState = HandoffTestState()

        let coordinator = HandoffCoordinator()
        await coordinator.register(targetAgent, as: "target")

        let config = AnyHandoffConfiguration(
            targetAgent: targetAgent,
            onHandoff: { _, inputData in
                await testState.setCapturedMetadata(inputData.metadata)
            },
            inputFilter: { inputData in
                var modified = inputData
                modified.metadata["filtered"] = .bool(true)
                modified.metadata["filter_timestamp"] = .double(Date().timeIntervalSince1970)
                return modified
            }
        )

        let request = HandoffRequest(
            sourceAgentName: "source",
            targetAgentName: "target",
            input: "Test input"
        )

        let context = AgentContext(input: "Test")
        _ = try await coordinator.executeHandoff(request, context: context, configuration: config, hooks: nil)

        let capturedMetadata = await testState.getCapturedMetadata()
        #expect(capturedMetadata["filtered"]?.boolValue == true)
        #expect(capturedMetadata["filter_timestamp"] != nil)
    }

    @Test("Filter can add metadata that is merged into context")
    func handoffInputFilterModifiesMetadata() async throws {
        let targetAgent = MockIntegrationTestAgent(name: "target")

        let coordinator = HandoffCoordinator()
        await coordinator.register(targetAgent, as: "target")

        let config = AnyHandoffConfiguration(
            targetAgent: targetAgent,
            inputFilter: { inputData in
                var modified = inputData
                modified.metadata["custom_key"] = .string("custom_value")
                modified.metadata["priority"] = .int(1)
                return modified
            }
        )

        let request = HandoffRequest(
            sourceAgentName: "source",
            targetAgentName: "target",
            input: "Test input"
        )

        let context = AgentContext(input: "Test")
        let result = try await coordinator.executeHandoff(
            request,
            context: context,
            configuration: config,
            hooks: nil
        )

        #expect(result.transferredContext["custom_key"]?.stringValue == "custom_value")
        #expect(result.transferredContext["priority"]?.intValue == 1)
    }
}

// MARK: - HandoffCoordinatorIsEnabledTests

@Suite("HandoffCoordinator IsEnabled Tests")
struct HandoffCoordinatorIsEnabledTests {
    @Test("Handoff executes when isEnabled returns true")
    func handoffWithIsEnabledTrue() async throws {
        let targetAgent = MockIntegrationTestAgent(name: "target")

        let coordinator = HandoffCoordinator()
        await coordinator.register(targetAgent, as: "target")

        let config = AnyHandoffConfiguration(
            targetAgent: targetAgent,
            isEnabled: { _, _ in true }
        )

        let request = HandoffRequest(
            sourceAgentName: "source",
            targetAgentName: "target",
            input: "Test input"
        )

        let context = AgentContext(input: "Test")
        let result = try await coordinator.executeHandoff(
            request,
            context: context,
            configuration: config,
            hooks: nil
        )

        #expect(result.targetAgentName == "target")
        #expect(result.result.output.contains("target"))
    }

    @Test("Handoff throws handoffSkipped when isEnabled returns false")
    func handoffWithIsEnabledFalse() async throws {
        let targetAgent = MockIntegrationTestAgent(name: "target")

        let coordinator = HandoffCoordinator()
        await coordinator.register(targetAgent, as: "target")

        let config = AnyHandoffConfiguration(
            targetAgent: targetAgent,
            isEnabled: { _, _ in false }
        )

        let request = HandoffRequest(
            sourceAgentName: "source",
            targetAgentName: "target",
            input: "Test input"
        )

        let context = AgentContext(input: "Test")

        do {
            _ = try await coordinator.executeHandoff(
                request,
                context: context,
                configuration: config,
                hooks: nil
            )
            Issue.record("Expected OrchestrationError.handoffSkipped")
        } catch let error as OrchestrationError {
            switch error {
            case let .handoffSkipped(from, to, _):
                #expect(from == "source")
                #expect(to == "target")
            default:
                Issue.record("Unexpected OrchestrationError: \(error)")
            }
        }
    }

    @Test("IsEnabled callback receives correct context and agent")
    func isEnabledCallbackReceivesCorrectParameters() async throws {
        let targetAgent = MockIntegrationTestAgent(name: "target")
        let testState = HandoffTestState()

        let coordinator = HandoffCoordinator()
        await coordinator.register(targetAgent, as: "target")

        let config = AnyHandoffConfiguration(
            targetAgent: targetAgent,
            isEnabled: { context, agent in
                let ready = await context.get("ready")?.boolValue ?? false
                await testState.setCapturedNames(source: "context_check", target: agent.configuration.name)
                return ready
            }
        )

        let request = HandoffRequest(
            sourceAgentName: "source",
            targetAgentName: "target",
            input: "Test input"
        )

        let context = AgentContext(input: "Test")
        await context.set("ready", value: .bool(true))

        let result = try await coordinator.executeHandoff(
            request,
            context: context,
            configuration: config,
            hooks: nil
        )

        #expect(await testState.getCapturedTargetName() == "target")
        #expect(result.targetAgentName == "target")
    }
}

// MARK: - HandoffCoordinatorRunHooksIntegrationTests

@Suite("HandoffCoordinator RunHooks Integration Tests")
struct HandoffCoordinatorRunHooksIntegrationTests {
    @Test("RunHooks.onHandoff is called during handoff")
    func handoffWithRunHooksIntegration() async throws {
        let sourceAgent = MockIntegrationTestAgent(name: "source")
        let targetAgent = MockIntegrationTestAgent(name: "target")
        let hooksState = HooksTestState()

        let coordinator = HandoffCoordinator()
        await coordinator.register(sourceAgent, as: "source")
        await coordinator.register(targetAgent, as: "target")

        let hooks = MockRunHooks(state: hooksState)

        let request = HandoffRequest(
            sourceAgentName: "source",
            targetAgentName: "target",
            input: "Test input"
        )

        let context = AgentContext(input: "Test")

        _ = try await coordinator.executeHandoff(
            request,
            context: context,
            configuration: nil,
            hooks: hooks
        )

        #expect(await hooksState.getOnHandoffHookCalled())
        #expect(await hooksState.getCapturedFromAgentName() == "source")
        #expect(await hooksState.getCapturedToAgentName() == "target")
    }

    @Test("RunHooks.onHandoff is called with configuration callbacks")
    func handoffRunHooksWithConfigurationCallbacks() async throws {
        let sourceAgent = MockIntegrationTestAgent(name: "source")
        let targetAgent = MockIntegrationTestAgent(name: "target")
        let hooksState = HooksTestState()
        let testState = HandoffTestState()

        let coordinator = HandoffCoordinator()
        await coordinator.register(sourceAgent, as: "source")
        await coordinator.register(targetAgent, as: "target")

        let hooks = MockRunHooks(state: hooksState)

        let config = AnyHandoffConfiguration(
            targetAgent: targetAgent,
            onHandoff: { _, _ in
                await testState.setOnHandoffCalled()
            }
        )

        let request = HandoffRequest(
            sourceAgentName: "source",
            targetAgentName: "target",
            input: "Test input"
        )

        let context = AgentContext(input: "Test")

        _ = try await coordinator.executeHandoff(
            request,
            context: context,
            configuration: config,
            hooks: hooks
        )

        #expect(await hooksState.getOnHandoffHookCalled())
        #expect(await testState.getOnHandoffCalled())
    }
}

// MARK: - HandoffCoordinatorErrorHandlingTests

@Suite("HandoffCoordinator Error Handling Tests")
struct HandoffCoordinatorErrorHandlingTests {
    @Test("Throws agentNotFound for unregistered agent")
    func handoffToUnregisteredAgent() async throws {
        let sourceAgent = MockIntegrationTestAgent(name: "source")

        let coordinator = HandoffCoordinator()
        await coordinator.register(sourceAgent, as: "source")

        let request = HandoffRequest(
            sourceAgentName: "source",
            targetAgentName: "unknown_target",
            input: "Test input"
        )

        let context = AgentContext(input: "Test")

        do {
            _ = try await coordinator.executeHandoff(
                request,
                context: context,
                configuration: nil,
                hooks: nil
            )
            Issue.record("Expected OrchestrationError.agentNotFound")
        } catch let error as OrchestrationError {
            switch error {
            case .agentNotFound:
                #expect(true)
            default:
                Issue.record("Unexpected OrchestrationError: \(error)")
            }
        }
    }

    @Test("Backward compatible with nil configuration")
    func handoffWithNilConfiguration() async throws {
        let targetAgent = MockIntegrationTestAgent(name: "target")

        let coordinator = HandoffCoordinator()
        await coordinator.register(targetAgent, as: "target")

        let request = HandoffRequest(
            sourceAgentName: "source",
            targetAgentName: "target",
            input: "Test input"
        )

        let context = AgentContext(input: "Test")

        let result = try await coordinator.executeHandoff(
            request,
            context: context,
            configuration: nil,
            hooks: nil
        )

        #expect(result.targetAgentName == "target")
        #expect(result.result.output.contains("target"))
    }
}

// MARK: - HandoffCoordinatorContextPropagationTests

@Suite("HandoffCoordinator Context Propagation Tests")
struct HandoffCoordinatorContextPropagationTests {
    @Test("Context from request is merged correctly")
    func handoffContextMerging() async throws {
        let targetAgent = MockIntegrationTestAgent(name: "target")

        let coordinator = HandoffCoordinator()
        await coordinator.register(targetAgent, as: "target")

        let request = HandoffRequest(
            sourceAgentName: "source",
            targetAgentName: "target",
            input: "Test input",
            context: [
                "plan_id": .string("plan-123"),
                "step": .int(1),
                "priority": .string("high")
            ]
        )

        let context = AgentContext(input: "Test")
        let result = try await coordinator.executeHandoff(
            request,
            context: context,
            configuration: nil,
            hooks: nil
        )

        #expect(result.transferredContext["plan_id"]?.stringValue == "plan-123")
        #expect(result.transferredContext["step"]?.intValue == 1)
        #expect(result.transferredContext["priority"]?.stringValue == "high")
    }

    @Test("HandoffInputData is populated correctly")
    func handoffInputDataContainsCorrectValues() async throws {
        let targetAgent = MockIntegrationTestAgent(name: "target")
        let testState = HandoffTestState()

        let coordinator = HandoffCoordinator()
        await coordinator.register(targetAgent, as: "target")

        let config = AnyHandoffConfiguration(
            targetAgent: targetAgent,
            onHandoff: { _, inputData in
                await testState.setCapturedNames(
                    source: inputData.sourceAgentName,
                    target: inputData.targetAgentName
                )
                await testState.setCapturedInput(inputData.input)
                await testState.setCapturedMetadata(inputData.context)
            }
        )

        let request = HandoffRequest(
            sourceAgentName: "planner",
            targetAgentName: "target",
            input: "Execute step 1",
            context: ["workflow_id": .string("workflow-456")]
        )

        let context = AgentContext(input: "Test")
        _ = try await coordinator.executeHandoff(
            request,
            context: context,
            configuration: config,
            hooks: nil
        )

        #expect(await testState.getCapturedSourceName() == "planner")
        #expect(await testState.getCapturedTargetName() == "target")
        #expect(await testState.getCapturedInput() == "Execute step 1")

        let capturedContext = await testState.getCapturedMetadata()
        #expect(capturedContext["workflow_id"]?.stringValue == "workflow-456")
    }

    @Test("Context values are set in AgentContext after handoff")
    func contextValuesSetAfterHandoff() async throws {
        let targetAgent = MockIntegrationTestAgent(name: "target")

        let coordinator = HandoffCoordinator()
        await coordinator.register(targetAgent, as: "target")

        let request = HandoffRequest(
            sourceAgentName: "source",
            targetAgentName: "target",
            input: "Test input",
            context: ["shared_data": .string("shared_value")]
        )

        let context = AgentContext(input: "Test")
        _ = try await coordinator.executeHandoff(
            request,
            context: context,
            configuration: nil,
            hooks: nil
        )

        let sharedData = await context.get("shared_data")
        #expect(sharedData?.stringValue == "shared_value")
    }
}

// MARK: - HandoffFullWorkflowIntegrationTests

@Suite("Handoff Full Workflow Integration Tests")
struct HandoffFullWorkflowIntegrationTests {
    @Test("Complete handoff workflow with all callbacks")
    func completeHandoffWorkflow() async throws {
        let sourceAgent = MockIntegrationTestAgent(name: "planner")
        let targetAgent = MockIntegrationTestAgent(name: "executor")
        let testState = HandoffTestState()
        let hooksState = HooksTestState()

        let coordinator = HandoffCoordinator()
        await coordinator.register(sourceAgent, as: "planner")
        await coordinator.register(targetAgent, as: "executor")

        let hooks = MockRunHooks(state: hooksState)

        let config = AnyHandoffConfiguration(
            targetAgent: targetAgent,
            toolNameOverride: "execute_plan",
            toolDescription: "Execute the planned steps",
            onHandoff: { context, inputData in
                await testState.setOnHandoffCalled()
                await testState.setCapturedNames(
                    source: inputData.sourceAgentName,
                    target: inputData.targetAgentName
                )
                await context.set("handoff_logged", value: .bool(true))
            },
            inputFilter: { inputData in
                var modified = inputData
                modified.metadata["processed_at"] = .double(Date().timeIntervalSince1970)
                modified.metadata["workflow_step"] = .string("filtered")
                return modified
            },
            isEnabled: { context, _ in
                await context.get("can_handoff")?.boolValue ?? true
            },
            nestHandoffHistory: true
        )

        let request = HandoffRequest(
            sourceAgentName: "planner",
            targetAgentName: "executor",
            input: "Execute step 1",
            context: ["plan_id": .string("plan-789")]
        )

        let context = AgentContext(input: "Initial input")
        await context.set("can_handoff", value: .bool(true))

        let result = try await coordinator.executeHandoff(
            request,
            context: context,
            configuration: config,
            hooks: hooks
        )

        #expect(await testState.getOnHandoffCalled())
        #expect(await testState.getCapturedSourceName() == "planner")
        #expect(await testState.getCapturedTargetName() == "executor")

        #expect(await hooksState.getOnHandoffHookCalled())
        #expect(await hooksState.getCapturedFromAgentName() == "planner")
        #expect(await hooksState.getCapturedToAgentName() == "executor")

        let handoffLogged = await context.get("handoff_logged")?.boolValue
        #expect(handoffLogged == true)

        #expect(result.transferredContext["processed_at"] != nil)
        #expect(result.transferredContext["workflow_step"]?.stringValue == "filtered")

        #expect(result.targetAgentName == "executor")
        #expect(result.input == "Execute step 1")
    }

    @Test("Multiple sequential handoffs maintain context")
    func multipleSequentialHandoffs() async throws {
        let agent1 = MockIntegrationTestAgent(name: "agent1")
        let agent2 = MockIntegrationTestAgent(name: "agent2")
        let agent3 = MockIntegrationTestAgent(name: "agent3")

        let coordinator = HandoffCoordinator()
        await coordinator.register(agent1, as: "agent1")
        await coordinator.register(agent2, as: "agent2")
        await coordinator.register(agent3, as: "agent3")

        let context = AgentContext(input: "Initial")

        let request1 = HandoffRequest(
            sourceAgentName: "agent1",
            targetAgentName: "agent2",
            input: "Step 1",
            context: ["step": .int(1)]
        )

        let result1 = try await coordinator.executeHandoff(
            request1,
            context: context,
            configuration: nil,
            hooks: nil
        )
        #expect(result1.targetAgentName == "agent2")

        let request2 = HandoffRequest(
            sourceAgentName: "agent2",
            targetAgentName: "agent3",
            input: "Step 2",
            context: ["step": .int(2)]
        )

        let result2 = try await coordinator.executeHandoff(
            request2,
            context: context,
            configuration: nil,
            hooks: nil
        )
        #expect(result2.targetAgentName == "agent3")

        let executionPath = await context.getExecutionPath()
        #expect(executionPath.contains("agent2"))
        #expect(executionPath.contains("agent3"))
    }
}
