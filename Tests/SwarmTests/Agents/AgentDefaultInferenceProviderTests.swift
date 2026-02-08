import Testing
@testable import Swarm

@Suite("Agent Defaults")
struct AgentDefaultInferenceProviderTests {
    @Test("Throws if no inference provider is set and Foundation Models are unavailable")
    func throwsIfNoProviderAndFoundationModelsUnavailable() async {
        // Keep this deterministic across environments: if Foundation Models are available at runtime,
        // Agent may run without an explicit provider.
        if DefaultInferenceProviderFactory.makeFoundationModelsProviderIfAvailable() != nil {
            return
        }

        do {
            _ = try await Agent().run("hi")
            Issue.record("Expected inference provider unavailable error")
        } catch let error as AgentError {
            switch error {
            case .inferenceProviderUnavailable(let reason):
                #expect(reason.contains("Foundation Models"))
                #expect(reason.contains("inference provider"))
            default:
                Issue.record("Unexpected AgentError: \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

