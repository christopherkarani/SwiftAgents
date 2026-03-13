/// A handoff is a tool. Sits in `@ToolV3Builder` alongside regular tools.
/// When the LLM calls it, execution transfers to the target agent.
///
/// ```swift
/// let specialist = AgentV3("Expert in billing.").named("billing")
/// let agent = AgentV3("Route requests.") {
///     Handoff(specialist)
///     SearchTool()
/// }
/// ```
public struct Handoff: ToolV3 {
    public let target: AgentV3
    public let handoffDescription: String

    // Static conformance — instance-level names used instead
    public static var name: String { "handoff" }
    public static var description: String { "Transfer execution to another agent" }

    /// The tool name seen by the LLM: `handoff_to_<snake_case_target_name>`
    public var instanceName: String {
        let snake = target.name
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
        return "handoff_to_\(snake)"
    }

    public init(_ target: AgentV3, description: String? = nil) {
        self.target = target
        self.handoffDescription = description ?? "Transfer to \(target.name)"
    }

    public func call() async throws -> String {
        // Not called directly — LegacyAgent runtime intercepts handoff tool calls
        fatalError("Handoff.call() should never be invoked directly")
    }

    public func toAnyJSONTool() -> any AnyJSONTool {
        HandoffAnyJSONTool(self)
    }
}

// MARK: - Internal bridge

/// Bridges a V3 `Handoff` into `AnyJSONTool` for the existing LegacyAgent actor runtime.
struct HandoffAnyJSONTool: AnyJSONTool {
    let handoff: Handoff

    init(_ handoff: Handoff) { self.handoff = handoff }

    /// Convenience init from AgentV3 (used in AgentV3.makeRuntime)
    init(_ target: AgentV3) { handoff = Handoff(target) }

    var name: String { handoff.instanceName }
    var description: String { handoff.handoffDescription }
    var parameters: [ToolParameter] { [] }

    func execute(arguments _: [String: SendableValue]) async throws -> SendableValue {
        // The LegacyAgent runtime intercepts calls to handoff_to_* tools before they reach here
        throw AgentError.toolExecutionFailed(
            toolName: handoff.instanceName,
            underlyingError: "Handoff tools must be intercepted by the agent runtime"
        )
    }
}
