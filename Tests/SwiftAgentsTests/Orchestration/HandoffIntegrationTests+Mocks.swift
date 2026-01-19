// HandoffIntegrationTests+Mocks.swift
// SwiftAgentsTests
//
// Mock types and test state actors for handoff integration tests.

import Foundation
@testable import SwiftAgents

// MARK: - HandoffTestState

/// Thread-safe state tracking for handoff callback tests.
actor HandoffTestState {
    var onHandoffCalled = false
    var capturedSourceName: String?
    var capturedTargetName: String?
    var capturedInput: String?
    var capturedMetadata: [String: SendableValue] = [:]
    var callbackError: Error?

    func setOnHandoffCalled() { onHandoffCalled = true }
    func setCapturedNames(source: String, target: String) {
        capturedSourceName = source
        capturedTargetName = target
    }

    func setCapturedInput(_ input: String) { capturedInput = input }
    func setCapturedMetadata(_ metadata: [String: SendableValue]) { capturedMetadata = metadata }
    func setCallbackError(_ error: Error) { callbackError = error }

    func getOnHandoffCalled() -> Bool { onHandoffCalled }
    func getCapturedSourceName() -> String? { capturedSourceName }
    func getCapturedTargetName() -> String? { capturedTargetName }
    func getCapturedInput() -> String? { capturedInput }
    func getCapturedMetadata() -> [String: SendableValue] { capturedMetadata }
    func getCallbackError() -> Error? { callbackError }

    func reset() {
        onHandoffCalled = false
        capturedSourceName = nil
        capturedTargetName = nil
        capturedInput = nil
        capturedMetadata = [:]
        callbackError = nil
    }
}

// MARK: - HooksTestState

/// Thread-safe state tracking for RunHooks tests.
actor HooksTestState {
    var onHandoffHookCalled = false
    var capturedFromAgentName: String?
    var capturedToAgentName: String?

    func setOnHandoffHookCalled() { onHandoffHookCalled = true }
    func setCapturedAgentNames(from: String, to: String) {
        capturedFromAgentName = from
        capturedToAgentName = to
    }

    func getOnHandoffHookCalled() -> Bool { onHandoffHookCalled }
    func getCapturedFromAgentName() -> String? { capturedFromAgentName }
    func getCapturedToAgentName() -> String? { capturedToAgentName }

    func reset() {
        onHandoffHookCalled = false
        capturedFromAgentName = nil
        capturedToAgentName = nil
    }
}

// MARK: - MockIntegrationTestAgent

/// Mock agent for integration testing handoff scenarios.
actor MockIntegrationTestAgent: Agent {
    nonisolated let tools: [any AnyJSONTool] = []
    nonisolated let instructions: String
    nonisolated let configuration: AgentConfiguration

    private(set) var runCallCount = 0
    private(set) var lastInput: String?

    nonisolated var memory: (any Memory)? { nil }
    nonisolated var inferenceProvider: (any InferenceProvider)? { nil }

    init(name: String, instructions: String = "Mock agent instructions") {
        self.instructions = instructions
        configuration = AgentConfiguration(name: name)
    }

    func run(
        _ input: String,
        session _: (any Session)? = nil,
        hooks _: (any RunHooks)? = nil
    ) async throws -> AgentResult {
        runCallCount += 1
        lastInput = input
        let builder = AgentResult.Builder()
        builder.start()
        builder.setOutput("Response from \(configuration.name): \(input)")
        return builder.build()
    }

    nonisolated func stream(
        _ input: String,
        session _: (any Session)? = nil,
        hooks _: (any RunHooks)? = nil
    ) -> AsyncThrowingStream<AgentEvent, Error> {
        let (stream, continuation) = AsyncThrowingStream<AgentEvent, Error>.makeStream()
        Task { @Sendable [weak self] in
            guard let self else {
                continuation.finish()
                return
            }
            do {
                continuation.yield(.started(input: input))
                let result = try await run(input)
                continuation.yield(.completed(result: result))
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        return stream
    }

    func cancel() async {}

    func getCallCount() -> Int { runCallCount }
    func getLastInput() -> String? { lastInput }
}

// MARK: - MockRunHooks

/// Mock RunHooks implementation for testing hook invocations.
struct MockRunHooks: RunHooks {
    let state: HooksTestState

    func onHandoff(context _: AgentContext?, fromAgent: any Agent, toAgent: any Agent) async {
        await state.setOnHandoffHookCalled()
        await state.setCapturedAgentNames(
            from: fromAgent.configuration.name,
            to: toAgent.configuration.name
        )
    }
}
