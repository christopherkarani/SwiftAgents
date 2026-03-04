@testable import Swarm
import Testing

// MARK: - SwarmConfigurationTests

@Suite("SwarmConfiguration")
struct SwarmConfigurationTests {
    // MARK: Internal

    @Test("configure sets global provider")
    func configureProvider() async throws {
        try await withIsolatedConfiguration {
            let mock = MockInferenceProvider()
            await Swarm.configure(provider: mock)
            let resolved = await Swarm.defaultProvider
            #expect(resolved != nil)
        }
    }

    @Test("configure with cloud provider")
    func configureCloudProvider() async throws {
        try await withIsolatedConfiguration {
            let mock = MockInferenceProvider()
            await Swarm.configure(cloudProvider: mock)
            let resolved = await Swarm.cloudProvider
            #expect(resolved != nil)
        }
    }

    @Test("reset clears all providers")
    func resetConfiguration() async throws {
        try await withIsolatedConfiguration {
            let mock = MockInferenceProvider()
            await Swarm.configure(provider: mock)
            await Swarm.configure(cloudProvider: mock)
            await Swarm.reset()
            let p = await Swarm.defaultProvider
            let c = await Swarm.cloudProvider
            #expect(p == nil)
            #expect(c == nil)
        }
    }

    @Test("Agent resolves Swarm.defaultProvider when no explicit provider")
    func agentResolvesGlobalProvider() async throws {
        try await withIsolatedConfiguration {
            let mock = MockInferenceProvider(responses: ["from global"])
            await Swarm.configure(provider: mock)
            let agent = try Agent(instructions: "test")
            let result = try await agent.run("hello")
            #expect(result.output == "from global")
        }
    }

    @Test("Explicit provider on Agent takes priority over global")
    func explicitProviderPriority() async throws {
        try await withIsolatedConfiguration {
            let globalMock = MockInferenceProvider(responses: ["from global"])
            let explicitMock = MockInferenceProvider(responses: ["from explicit"])
            await Swarm.configure(provider: globalMock)
            let agent = try Agent(instructions: "test", inferenceProvider: explicitMock)
            let result = try await agent.run("hello")
            #expect(result.output == "from explicit")
        }
    }

    @Test("Agent with tools resolves Swarm.cloudProvider")
    func cloudProviderForToolAgents() async throws {
        try await withIsolatedConfiguration {
            let cloudMock = MockInferenceProvider(responses: ["from cloud"])
            await Swarm.configure(cloudProvider: cloudMock)
            let tool = MockTool(name: "test_tool")
            let agent = try Agent(tools: [tool], instructions: "test")
            let result = try await agent.run("use tool")
            #expect(result.output == "from cloud")
        }
    }

    @Test("defaultProvider preferred over cloudProvider for toolless agents")
    func defaultPreferredOverCloud() async throws {
        try await withIsolatedConfiguration {
            let defaultMock = MockInferenceProvider(responses: ["from default"])
            let cloudMock = MockInferenceProvider(responses: ["from cloud"])
            await Swarm.configure(provider: defaultMock)
            await Swarm.configure(cloudProvider: cloudMock)
            let agent = try Agent(instructions: "test")
            let result = try await agent.run("hello")
            #expect(result.output == "from default")
        }
    }

    @Test("Agent with handoff only resolves Swarm.cloudProvider")
    func cloudProviderForHandoffOnlyAgents() async throws {
        try await withIsolatedConfiguration {
            let cloudMock = MockInferenceProvider(responses: ["from handoff-cloud"])
            let handoffProvider = MockInferenceProvider(responses: ["unused"])
            await Swarm.configure(cloudProvider: cloudMock)

            let handoffTarget = try Agent(instructions: "handoff target", inferenceProvider: handoffProvider)
            let agent = try Agent(instructions: "route", handoffAgents: [handoffTarget])

            let result = try await agent.run("transfer me")
            #expect(result.output == "from handoff-cloud")
        }
    }

    // MARK: Private

    private func withIsolatedConfiguration<T: Sendable>(
        _ operation: @Sendable () async throws -> T
    ) async rethrows -> T {
        try await withSwarmConfigurationIsolation(operation)
    }
}
