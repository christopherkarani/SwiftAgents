// HandoffConfigurationTests.swift
// SwarmTests
//
// Tests for handoff configuration and routing.
// Mock types are in HandoffConfigurationTests+Mocks.swift
// Builder tests are in HandoffConfigurationTests+Builder.swift

import Foundation
@testable import Swarm
import Testing

// MARK: - HandoffInputDataTests

@Suite("HandoffInputData Tests")
struct HandoffInputDataTests {
    @Test("Creates HandoffInputData with all properties")
    func handoffInputDataCreation() {
        let inputData = HandoffInputData(
            sourceAgentName: "planner",
            targetAgentName: "executor",
            input: "Execute step 1",
            context: ["plan_id": .string("123")],
            metadata: ["priority": .string("high")]
        )

        #expect(inputData.sourceAgentName == "planner")
        #expect(inputData.targetAgentName == "executor")
        #expect(inputData.input == "Execute step 1")
        #expect(inputData.context["plan_id"]?.stringValue == "123")
        #expect(inputData.metadata["priority"]?.stringValue == "high")
    }

    @Test("Creates HandoffInputData with default empty context and metadata")
    func handoffInputDataDefaultValues() {
        let inputData = HandoffInputData(
            sourceAgentName: "source",
            targetAgentName: "target",
            input: "Test input"
        )

        #expect(inputData.context.isEmpty)
        #expect(inputData.metadata.isEmpty)
    }

    @Test("HandoffInputData is Equatable")
    func handoffInputDataEquatable() {
        let inputData1 = HandoffInputData(
            sourceAgentName: "planner",
            targetAgentName: "executor",
            input: "Execute step 1",
            context: ["key": .string("value")],
            metadata: ["meta": .int(42)]
        )

        let inputData2 = HandoffInputData(
            sourceAgentName: "planner",
            targetAgentName: "executor",
            input: "Execute step 1",
            context: ["key": .string("value")],
            metadata: ["meta": .int(42)]
        )

        let inputData3 = HandoffInputData(
            sourceAgentName: "different",
            targetAgentName: "executor",
            input: "Execute step 1"
        )

        #expect(inputData1 == inputData2)
        #expect(inputData1 != inputData3)
    }

    @Test("HandoffInputData metadata can be mutated")
    func handoffInputDataMetadataMutation() {
        var inputData = HandoffInputData(
            sourceAgentName: "source",
            targetAgentName: "target",
            input: "Test"
        )

        inputData.metadata["timestamp"] = .double(1_234_567_890.0)
        inputData.metadata["processed"] = .bool(true)

        #expect(inputData.metadata["timestamp"]?.doubleValue == 1_234_567_890.0)
        #expect(inputData.metadata["processed"]?.boolValue == true)
        #expect(inputData.metadata.count == 2)
    }

    @Test("HandoffInputData conforms to CustomStringConvertible")
    func handoffInputDataDescription() {
        let inputData = HandoffInputData(
            sourceAgentName: "planner",
            targetAgentName: "executor",
            input: "A short input"
        )

        let description = inputData.description

        #expect(description.contains("planner"))
        #expect(description.contains("executor"))
        #expect(description.contains("A short input"))
    }

    @Test("HandoffInputData description truncates long input")
    func handoffInputDataDescriptionTruncation() {
        let longInput = String(repeating: "a", count: 100)
        let inputData = HandoffInputData(
            sourceAgentName: "source",
            targetAgentName: "target",
            input: longInput
        )

        let description = inputData.description

        #expect(description.contains("..."))
        #expect(!description.contains(longInput))
    }

    @Test("HandoffInputData is Sendable")
    func handoffInputDataSendable() async {
        let inputData = HandoffInputData(
            sourceAgentName: "source",
            targetAgentName: "target",
            input: "Test"
        )

        let result = await Task {
            inputData.sourceAgentName
        }.value

        #expect(result == "source")
    }
}

// MARK: - CallbackTypeTests

@Suite("Callback Type Tests")
struct CallbackTypeTests {
    @Test("OnHandoffCallback executes correctly")
    func onHandoffCallbackExecution() async throws {
        actor CallbackState {
            var callbackExecuted = false
            var capturedSourceName: String?
            var capturedTargetName: String?

            func setExecuted() { callbackExecuted = true }
            func setCapturedNames(source: String, target: String) {
                capturedSourceName = source
                capturedTargetName = target
            }

            func getExecuted() -> Bool { callbackExecuted }
            func getSourceName() -> String? { capturedSourceName }
            func getTargetName() -> String? { capturedTargetName }
        }

        let state = CallbackState()

        let callback: OnHandoffCallback = { context, inputData in
            await state.setExecuted()
            await state.setCapturedNames(source: inputData.sourceAgentName, target: inputData.targetAgentName)
            _ = await context.get("test_key")
        }

        let context = AgentContext(input: "Test")
        await context.set("test_key", value: .string("test_value"))

        let inputData = HandoffInputData(
            sourceAgentName: "source",
            targetAgentName: "target",
            input: "Test input"
        )

        try await callback(context, inputData)

        #expect(await state.getExecuted())
        #expect(await state.getSourceName() == "source")
        #expect(await state.getTargetName() == "target")
    }

    @Test("OnHandoffCallback can throw errors")
    func onHandoffCallbackThrows() async {
        struct HandoffValidationError: Error {}

        let callback: OnHandoffCallback = { _, _ in
            throw HandoffValidationError()
        }

        let context = AgentContext(input: "Test")
        let inputData = HandoffInputData(
            sourceAgentName: "source",
            targetAgentName: "target",
            input: "Test"
        )

        await #expect(throws: HandoffValidationError.self, performing: {
            try await callback(context, inputData)
        })
    }

    @Test("InputFilterCallback transforms data correctly")
    func inputFilterCallbackTransformation() {
        let filter: InputFilterCallback = { inputData in
            var modified = inputData
            modified.metadata["filtered_at"] = .double(Date().timeIntervalSince1970)
            modified.metadata["original_source"] = .string(inputData.sourceAgentName)
            return modified
        }

        let inputData = HandoffInputData(
            sourceAgentName: "planner",
            targetAgentName: "executor",
            input: "Test"
        )

        let filtered = filter(inputData)

        #expect(filtered.metadata["filtered_at"] != nil)
        #expect(filtered.metadata["original_source"]?.stringValue == "planner")
        #expect(filtered.sourceAgentName == "planner")
        #expect(filtered.targetAgentName == "executor")
        #expect(filtered.input == "Test")
    }

    @Test("IsEnabledCallback returns correctly")
    func isEnabledCallbackReturnsCorrectly() async {
        let agent = MockHandoffAgent(name: "test")

        let alwaysEnabled: IsEnabledCallback = { _, _ in true }
        let alwaysDisabled: IsEnabledCallback = { _, _ in false }
        let contextBased: IsEnabledCallback = { context, _ in
            await context.get("enabled")?.boolValue ?? false
        }

        let context = AgentContext(input: "Test")

        let enabled1 = await alwaysEnabled(context, agent)
        #expect(enabled1 == true)

        let enabled2 = await alwaysDisabled(context, agent)
        #expect(enabled2 == false)

        let enabled3 = await contextBased(context, agent)
        #expect(enabled3 == false)

        await context.set("enabled", value: .bool(true))
        let enabled4 = await contextBased(context, agent)
        #expect(enabled4 == true)
    }
}

// MARK: - HandoffConfigurationTests

@Suite("HandoffConfiguration Tests")
struct HandoffConfigurationTests {
    @Test("Creates HandoffConfiguration with minimal parameters")
    func handoffConfigurationCreation() async {
        let agent = MockHandoffAgent(name: "executor")

        let config = HandoffConfiguration(targetAgent: agent)

        #expect(config.toolNameOverride == nil)
        #expect(config.toolDescription == nil)
        #expect(config.onHandoff == nil)
        #expect(config.inputFilter == nil)
        #expect(config.isEnabled == nil)
        #expect(config.nestHandoffHistory == false)
    }

    @Test("Creates HandoffConfiguration with all properties")
    func handoffConfigurationWithAllProperties() async {
        let agent = MockHandoffAgent(name: "executor")

        actor CallbackState {
            var callbackCalled = false
            func setCalled() { callbackCalled = true }
            func getCalled() -> Bool { callbackCalled }
        }

        let state = CallbackState()

        let onHandoff: OnHandoffCallback = { _, _ in
            await state.setCalled()
        }

        let inputFilter: InputFilterCallback = { data in
            var modified = data
            modified.metadata["filtered"] = .bool(true)
            return modified
        }

        let isEnabled: IsEnabledCallback = { _, _ in true }

        let config = HandoffConfiguration(
            targetAgent: agent,
            toolNameOverride: "execute_task",
            toolDescription: "Execute the planned task",
            onHandoff: onHandoff,
            inputFilter: inputFilter,
            isEnabled: isEnabled,
            nestHandoffHistory: true
        )

        #expect(config.toolNameOverride == "execute_task")
        #expect(config.toolDescription == "Execute the planned task")
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
        #expect(await state.getCalled())

        let filtered = config.inputFilter?(inputData)
        #expect(filtered?.metadata["filtered"]?.boolValue == true)

        let enabled = await config.isEnabled?(context, agent)
        #expect(enabled == true)
    }

    @Test("effectiveToolName returns override when set")
    func effectiveToolNameWithOverride() async {
        let agent = MockHandoffAgent(name: "executor")
        let config = HandoffConfiguration(
            targetAgent: agent,
            toolNameOverride: "custom_handoff"
        )

        #expect(config.effectiveToolName == "custom_handoff")
    }

    @Test("effectiveToolName generates from type name when no override")
    func effectiveToolNameGenerated() async {
        let agent = MockHandoffAgent(name: "ExecutorAgent")
        let config = HandoffConfiguration(targetAgent: agent)

        let toolName = config.effectiveToolName
        #expect(toolName.hasPrefix("handoff_to_"))
        #expect(toolName.contains("mock"))
    }

    @Test("effectiveToolDescription returns description when set")
    func effectiveToolDescriptionWithOverride() async {
        let agent = MockHandoffAgent(name: "executor")
        let config = HandoffConfiguration(
            targetAgent: agent,
            toolDescription: "Custom description"
        )

        #expect(config.effectiveToolDescription == "Custom description")
    }

    @Test("effectiveToolDescription generates default when not set")
    func effectiveToolDescriptionGenerated() async {
        let agent = MockHandoffAgent(name: "executor")
        let config = HandoffConfiguration(targetAgent: agent)

        let description = config.effectiveToolDescription
        #expect(description.hasPrefix("Hand off execution to"))
    }

    @Test("HandoffConfiguration is Sendable")
    func handoffConfigurationSendable() async {
        let agent = MockHandoffAgent(name: "executor")
        let config = HandoffConfiguration(
            targetAgent: agent,
            toolNameOverride: "test_handoff"
        )

        let result = await Task {
            config.toolNameOverride
        }.value

        #expect(result == "test_handoff")
    }
}

// MARK: - AnyHandoffConfigurationTests

@Suite("AnyHandoffConfiguration Tests")
struct AnyHandoffConfigurationTests {
    @Test("AnyHandoffConfiguration creates from typed configuration")
    func anyHandoffConfigurationFromTyped() async {
        let agent = MockHandoffAgent(name: "executor")

        let typedConfig = HandoffConfiguration(
            targetAgent: agent,
            toolNameOverride: "execute",
            toolDescription: "Execute task",
            nestHandoffHistory: true
        )

        let anyConfig = AnyHandoffConfiguration(typedConfig)

        #expect(anyConfig.toolNameOverride == "execute")
        #expect(anyConfig.toolDescription == "Execute task")
        #expect(anyConfig.nestHandoffHistory == true)
    }

    @Test("AnyHandoffConfiguration preserves callbacks from typed configuration")
    func anyHandoffConfigurationPreservesCallbacks() async throws {
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

        let typedConfig = HandoffConfiguration(
            targetAgent: agent,
            onHandoff: { _, _ in await state.setOnHandoffCalled() },
            inputFilter: { data in
                var modified = data
                modified.metadata["filter_applied"] = .bool(true)
                return modified
            },
            isEnabled: { _, _ in
                await state.setIsEnabledCalled()
                return true
            }
        )

        let anyConfig = AnyHandoffConfiguration(typedConfig)

        let context = AgentContext(input: "Test")
        let inputData = HandoffInputData(
            sourceAgentName: "source",
            targetAgentName: "target",
            input: "Test"
        )

        try await anyConfig.onHandoff?(context, inputData)
        let filtered = anyConfig.inputFilter?(inputData)
        _ = await anyConfig.isEnabled?(context, agent)

        #expect(await state.getOnHandoffCalled())
        #expect(filtered?.metadata["filter_applied"]?.boolValue == true)
        #expect(await state.getIsEnabledCalled())
    }

    @Test("AnyHandoffConfiguration creates directly")
    func anyHandoffConfigurationDirectCreation() async {
        let agent = MockHandoffAgent(name: "executor")

        let config = AnyHandoffConfiguration(
            targetAgent: agent,
            toolNameOverride: "direct_handoff",
            toolDescription: "Direct creation",
            nestHandoffHistory: true
        )

        #expect(config.toolNameOverride == "direct_handoff")
        #expect(config.toolDescription == "Direct creation")
        #expect(config.nestHandoffHistory == true)
    }

    @Test("AnyHandoffConfiguration effectiveToolName works")
    func anyHandoffConfigurationEffectiveToolName() async {
        let agent = MockHandoffAgent(name: "executor")

        let configWithOverride = AnyHandoffConfiguration(
            targetAgent: agent,
            toolNameOverride: "custom_name"
        )
        #expect(configWithOverride.effectiveToolName == "custom_name")

        let configWithoutOverride = AnyHandoffConfiguration(targetAgent: agent)
        #expect(configWithoutOverride.effectiveToolName.hasPrefix("handoff_to_"))
    }

    @Test("AnyHandoffConfiguration effectiveToolDescription works")
    func anyHandoffConfigurationEffectiveToolDescription() async {
        let agent = MockHandoffAgent(name: "executor")

        let configWithDesc = AnyHandoffConfiguration(
            targetAgent: agent,
            toolDescription: "Custom description"
        )
        #expect(configWithDesc.effectiveToolDescription == "Custom description")

        let configWithoutDesc = AnyHandoffConfiguration(targetAgent: agent)
        #expect(configWithoutDesc.effectiveToolDescription.hasPrefix("Hand off execution to"))
    }

    @Test("AnyHandoffConfiguration is Sendable")
    func anyHandoffConfigurationSendable() async {
        let agent = MockHandoffAgent(name: "executor")
        let config = AnyHandoffConfiguration(
            targetAgent: agent,
            toolNameOverride: "test"
        )

        let result = await Task {
            config.toolNameOverride
        }.value

        #expect(result == "test")
    }

    @Test("AnyHandoffConfiguration can be stored in heterogeneous collection")
    func anyHandoffConfigurationHeterogeneousCollection() async {
        let agent1 = MockHandoffAgent(name: "agent1")
        let agent2 = MockHandoffAgent(name: "agent2")

        let config1 = handoff(to: agent1, toolName: "handoff_1")
        let config2 = handoff(to: agent2, toolName: "handoff_2")

        let configurations: [AnyHandoffConfiguration] = [
            AnyHandoffConfiguration(config1),
            AnyHandoffConfiguration(config2)
        ]

        #expect(configurations.count == 2)
        #expect(configurations[0].toolNameOverride == "handoff_1")
        #expect(configurations[1].toolNameOverride == "handoff_2")
    }
}
