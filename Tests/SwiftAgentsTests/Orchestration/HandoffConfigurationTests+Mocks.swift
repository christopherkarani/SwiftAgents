// HandoffConfigurationTests+Mocks.swift
// SwiftAgentsTests
//
// Mock types for handoff configuration tests.

import Foundation
@testable import SwiftAgents

// MARK: - MockHandoffAgent

/// Simple mock agent for testing handoff configurations.
actor MockHandoffAgent: AgentRuntime {
    nonisolated let tools: [any AnyJSONTool] = []
    nonisolated let instructions: String
    nonisolated let configuration: AgentConfiguration
    private(set) var runCallCount = 0
    private(set) var lastInput: String?

    nonisolated var memory: (any Memory)? { nil }
    nonisolated var inferenceProvider: (any InferenceProvider)? { nil }

    init(name: String = "MockAgent", instructions: String = "Mock instructions") {
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
