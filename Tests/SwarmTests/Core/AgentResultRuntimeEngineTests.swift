// AgentResultRuntimeEngineTests.swift
// SwarmTests
//
// Tests for AgentResult.runtimeEngine typed accessor.

import Testing
@testable import Swarm

@Suite("AgentResult.runtimeEngine")
struct AgentResultRuntimeEngineTests {

    @Test("returns nil when metadata has no runtime.engine key")
    func returnsNilWhenAbsent() {
        let result = AgentResult(output: "hi")
        #expect(result.runtimeEngine == nil)
    }

    @Test("returns engine name from metadata")
    func returnsEngineFromMetadata() {
        let result = AgentResult(
            output: "hi",
            metadata: ["runtime.engine": .string("hive")]
        )
        #expect(result.runtimeEngine == "hive")
    }

    @Test("returns nil when metadata value is not a string")
    func returnsNilForNonString() {
        let result = AgentResult(
            output: "hi",
            metadata: ["runtime.engine": .int(1)]
        )
        #expect(result.runtimeEngine == nil)
    }
}
