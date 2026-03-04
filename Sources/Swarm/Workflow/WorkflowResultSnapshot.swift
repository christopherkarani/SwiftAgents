import Foundation

struct WorkflowResultSnapshot: Codable, Sendable, Equatable {
    let output: String
    let toolCalls: [ToolCall]
    let toolResults: [ToolResult]
    let iterationCount: Int
    let durationSeconds: Int64
    let durationAttoseconds: Int64
    let tokenUsage: TokenUsage?
    let metadata: [String: SendableValue]

    init(_ result: AgentResult) {
        let components = result.duration.components
        output = result.output
        toolCalls = result.toolCalls
        toolResults = result.toolResults
        iterationCount = result.iterationCount
        durationSeconds = components.seconds
        durationAttoseconds = components.attoseconds
        tokenUsage = result.tokenUsage
        metadata = result.metadata
    }

    var agentResult: AgentResult {
        let duration = Duration.seconds(
            Double(durationSeconds) + Double(durationAttoseconds) / 1_000_000_000_000_000_000
        )
        return AgentResult(
            output: output,
            toolCalls: toolCalls,
            toolResults: toolResults,
            iterationCount: iterationCount,
            duration: duration,
            tokenUsage: tokenUsage,
            metadata: metadata
        )
    }
}
