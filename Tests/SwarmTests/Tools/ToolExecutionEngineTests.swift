import Foundation
@testable import Swarm
import Testing

@Suite("ToolExecutionEngine Tests")
struct ToolExecutionEngineTests {
    @Test("stopOnToolError preserves cancellation semantics")
    func stopOnToolErrorPreservesCancellation() async throws {
        let registry = ToolRegistry()
        try await registry.register(CancellationTool(name: "cancel_tool"))

        let engine = ToolExecutionEngine()
        let builder = AgentResult.Builder()
        builder.start()

        do {
            _ = try await engine.execute(
                toolName: "cancel_tool",
                arguments: [:],
                registry: registry,
                agent: ParallelTestMockAgent(),
                context: nil,
                resultBuilder: builder,
                hooks: nil,
                tracing: nil,
                stopOnToolError: true
            )
            Issue.record("Expected cancellation error")
        } catch let error as AgentError {
            #expect(error == .cancelled)
        } catch {
            Issue.record("Expected AgentError.cancelled, got \(error)")
        }
    }
}

private struct CancellationTool: AnyJSONTool, Sendable {
    let name: String
    var description: String { "Always throws cancellation" }
    var parameters: [ToolParameter] { [] }

    func execute(arguments _: [String: SendableValue]) async throws -> SendableValue {
        throw CancellationError()
    }
}
