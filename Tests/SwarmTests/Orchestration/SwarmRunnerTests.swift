import Foundation
@testable import Swarm
import Testing

@Suite("SwarmRunner Tests")
struct SwarmRunnerTests {
    @Test("runStream cancellation propagates to producer and provider stream")
    func runStreamCancellationPropagates() async throws {
        let provider = EndlessStreamingProvider()
        let agent = SwarmRunnerStreamingAgent(name: "streamer", provider: provider)
        let runner = try SwarmRunner(agents: [agent])

        let probe = StreamProbe()
        let consumer = Task {
            let stream = await runner.runStream(
                agentName: "streamer",
                messages: [.user("hello")],
                executeTools: false
            )

            for try await chunk in stream {
                if chunk.content != nil {
                    await probe.markContentSeen()
                }
            }
        }

        let sawContent = await waitUntil(timeout: .seconds(1)) {
            await probe.contentSeen()
        }
        #expect(sawContent)

        consumer.cancel()
        _ = await consumer.result

        let producerStopped = await waitUntil(timeout: .seconds(1)) {
            let snapshot = await provider.snapshot()
            return snapshot.terminationCount > 0 && snapshot.cancelRequestCount > 0
        }

        let snapshotAfterCancellation = await provider.snapshot()
        try? await Task.sleep(for: .milliseconds(200))
        let stabilizedSnapshot = await provider.snapshot()

        await provider.stopAllStreams()
        #expect(producerStopped)
        #expect(snapshotAfterCancellation.terminationCount > 0)
        #expect(snapshotAfterCancellation.cancelRequestCount > 0)
        #expect(stabilizedSnapshot.producedTokenCount - snapshotAfterCancellation.producedTokenCount <= 1)
    }
}

private struct SwarmRunnerStreamingAgent: AgentRuntime {
    let name: String
    let provider: any InferenceProvider

    nonisolated let tools: [any AnyJSONTool] = []
    nonisolated let instructions: String = "Streaming test agent"
    nonisolated let configuration: AgentConfiguration
    nonisolated var inferenceProvider: (any InferenceProvider)? { provider }

    init(name: String, provider: any InferenceProvider) {
        self.name = name
        self.provider = provider
        configuration = AgentConfiguration(name: name, enableStreaming: true)
    }

    func run(
        _ input: String,
        session _: (any Session)?,
        hooks _: (any RunHooks)?
    ) async throws -> AgentResult {
        AgentResult(output: input)
    }

    nonisolated func stream(
        _ input: String,
        session _: (any Session)?,
        hooks _: (any RunHooks)?
    ) -> AsyncThrowingStream<AgentEvent, Error> {
        StreamHelper.makeTrackedStream { continuation in
            continuation.yield(.started(input: input))
            continuation.yield(.completed(result: AgentResult(output: input)))
            continuation.finish()
        }
    }

    func cancel() async {}
}

private actor EndlessStreamingProvider: InferenceProvider {
    private var terminationCount: Int = 0
    private var cancelRequestCount: Int = 0
    private var producedTokenCount: Int = 0
    private var producers: [UUID: Task<Void, Never>] = [:]

    func generate(prompt _: String, options _: InferenceOptions) async throws -> String {
        try await Task.sleep(for: .seconds(5))
        return "unused"
    }

    nonisolated func stream(prompt _: String, options _: InferenceOptions) -> AsyncThrowingStream<String, Error> {
        let streamID = UUID()
        return AsyncThrowingStream { continuation in
            let producer = Task { [self, streamID] in
                defer { Task { await streamStopped(id: streamID) } }
                for _ in 0..<1_000 {
                    guard !Task.isCancelled else { break }
                    await tokenProduced()
                    continuation.yield("token")
                    try? await Task.sleep(for: .milliseconds(20))
                }
                continuation.finish()
            }
            Task { [self] in
                await streamStarted(id: streamID, producer: producer)
            }

            continuation.onTermination = { @Sendable _ in
                producer.cancel()
                Task { [self] in
                    await streamTerminatedAndCancelRequested()
                }
            }
        }
    }

    func generateWithToolCalls(
        prompt: String,
        tools _: [ToolSchema],
        options: InferenceOptions
    ) async throws -> InferenceResponse {
        let content = try await generate(prompt: prompt, options: options)
        return InferenceResponse(content: content, finishReason: .completed)
    }

    func snapshot() -> (terminationCount: Int, cancelRequestCount: Int, producedTokenCount: Int) {
        (terminationCount, cancelRequestCount, producedTokenCount)
    }

    func stopAllStreams() {
        for task in producers.values {
            task.cancel()
        }
    }

    private func streamStarted(id: UUID, producer: Task<Void, Never>) {
        producers[id] = producer
    }

    private func streamStopped(id: UUID) {
        producers[id] = nil
    }

    private func streamTerminatedAndCancelRequested() {
        terminationCount += 1
        cancelRequestCount += 1
    }

    private func tokenProduced() {
        producedTokenCount += 1
    }
}

private actor StreamProbe {
    private var sawContent = false

    func markContentSeen() {
        sawContent = true
    }

    func contentSeen() -> Bool {
        sawContent
    }
}

private func waitUntil(
    timeout: Duration,
    condition: @escaping @Sendable () async -> Bool
) async -> Bool {
    let start = ContinuousClock.now
    while ContinuousClock.now - start < timeout {
        if await condition() {
            return true
        }
        try? await Task.sleep(for: .milliseconds(25))
    }
    return false
}
