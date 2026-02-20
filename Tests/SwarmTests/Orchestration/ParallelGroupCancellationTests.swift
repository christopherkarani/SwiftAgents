import Foundation
@testable import Swarm
import Testing

@Suite("ParallelGroup Cancellation Tests")
struct ParallelGroupCancellationTests {
    @Test("cancel promptly unblocks in-flight run")
    func cancelUnblocksInflightRunPromptly() async throws {
        let first = SlowCancellableRuntimeAgent(name: "first")
        let second = SlowCancellableRuntimeAgent(name: "second")
        let group = ParallelGroup(
            agents: [
                ("first", first),
                ("second", second)
            ],
            shouldContinueOnError: true
        )

        let runTask = Task {
            try await group.run("work")
        }

        try await Task.sleep(for: .milliseconds(50))
        await group.cancel()

        let completion = await awaitParallelTaskResult(runTask, timeout: .milliseconds(500))
        guard let completion else {
            // Clean up to avoid leaking long-running tasks in a failing state.
            _ = await awaitParallelTaskResult(runTask, timeout: .seconds(3))
            Issue.record("ParallelGroup.run did not unblock promptly after cancel()")
            return
        }

        switch completion {
        case .success:
            Issue.record("Expected cancellation error but run succeeded")
        case let .failure(error as AgentError):
            #expect(error == .cancelled)
        case let .failure(error):
            Issue.record("Expected AgentError.cancelled, got \(error)")
        }
    }
}

private actor SlowCancellableRuntimeAgent: AgentRuntime {
    nonisolated let tools: [any AnyJSONTool] = []
    nonisolated let instructions: String
    nonisolated let configuration: AgentConfiguration

    private var inFlight: Task<AgentResult, Error>?

    init(name: String) {
        instructions = "Slow \(name)"
        configuration = AgentConfiguration(name: name)
    }

    func run(
        _ input: String,
        session _: (any Session)?,
        hooks _: (any RunHooks)?
    ) async throws -> AgentResult {
        let task = Task {
            try await Task.sleep(for: .seconds(2))
            return AgentResult(output: "done: \(input)")
        }
        inFlight = task
        defer { inFlight = nil }
        return try await task.value
    }

    nonisolated func stream(
        _ input: String,
        session _: (any Session)?,
        hooks _: (any RunHooks)?
    ) -> AsyncThrowingStream<AgentEvent, Error> {
        StreamHelper.makeTrackedStream { continuation in
            continuation.yield(.started(input: input))
            continuation.finish(throwing: AgentError.cancelled)
        }
    }

    func cancel() async {
        inFlight?.cancel()
    }
}

private func awaitParallelTaskResult<T: Sendable>(
    _ task: Task<T, Error>,
    timeout: Duration
) async -> Result<T, Error>? {
    await withTaskGroup(of: Result<T, Error>?.self) { group in
        group.addTask {
            do {
                return .success(try await task.value)
            } catch {
                return .failure(error)
            }
        }

        group.addTask {
            try? await Task.sleep(for: timeout)
            return nil
        }

        let first = await group.next() ?? nil
        group.cancelAll()
        return first
    }
}
