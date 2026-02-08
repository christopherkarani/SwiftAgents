// AgentBlueprintTests.swift
// Swarm Framework
//
// Tests for the SwiftUI-style AgentBlueprint layer.

@testable import Swarm
import Testing

// MARK: - Test Agents

private struct PrefixAgent: AgentRuntime {
    let prefix: String

    var tools: [any AnyJSONTool] { [] }
    var instructions: String { "Prefix(\(prefix))" }
    var configuration: AgentConfiguration { AgentConfiguration(name: "Prefix(\(prefix))") }

    func run(
        _ input: String,
        session _: (any Session)?,
        hooks _: (any RunHooks)?
    ) async throws -> AgentResult {
        AgentResult(output: "\(prefix)\(input)")
    }

    nonisolated func stream(
        _ input: String,
        session _: (any Session)?,
        hooks _: (any RunHooks)?
    ) -> AsyncThrowingStream<AgentEvent, Error> {
        StreamHelper.makeTrackedStream { continuation in
            continuation.yield(.started(input: input))
            continuation.yield(.completed(result: AgentResult(output: "\(prefix)\(input)")))
            continuation.finish()
        }
    }

    func cancel() async {}
}

// MARK: - Blueprints

private struct SampleBlueprint: AgentBlueprint {
    @OrchestrationBuilder var body: some OrchestrationStep {
        PrefixAgent(prefix: "A")
        PrefixAgent(prefix: "B")
    }
}

private struct BillingBlueprint: AgentBlueprint {
    @OrchestrationBuilder var body: some OrchestrationStep {
        PrefixAgent(prefix: "bill:")
    }
}

@Suite("AgentBlueprint Tests")
struct AgentBlueprintTests {
    @Test("Blueprint runs in reading order")
    func blueprintRunIsSequential() async throws {
        let result = try await SampleBlueprint().run("x")
        #expect(result.output == "BAx")
    }

    @Test("Blueprint can be nested in Orchestration")
    func blueprintCanBeNested() async throws {
        let workflow = Orchestration {
            SampleBlueprint()
        }

        let result = try await workflow.run("x")
        #expect(result.output == "BAx")
    }

    @Test("Router can route to a blueprint via When")
    func routerRoutesToBlueprint() async throws {
        let workflow = Orchestration {
            Router {
                When(.contains("bill")) { BillingBlueprint() }
                Otherwise { PrefixAgent(prefix: "fallback:") }
            }
        }

        let billed = try await workflow.run("billing help")
        #expect(billed.output == "bill:billing help")

        let fallback = try await workflow.run("technical help")
        #expect(fallback.output == "fallback:technical help")
    }
}
