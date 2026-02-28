import Foundation

#if canImport(Membrane)
import Membrane
#endif

#if canImport(MembraneHive)
import MembraneHive
#endif

public struct MembraneFeatureConfiguration: Sendable, Equatable {
    public static let `default` = MembraneFeatureConfiguration()

    public var jitMinToolCount: Int
    public var defaultJITLoadCount: Int
    public var pointerThresholdBytes: Int
    public var pointerSummaryMaxChars: Int
    /// Optional provider-runtime feature policy flags keyed by namespaced identifier.
    ///
    /// Example keys:
    /// - `conduit.runtime.kv_quantization`
    /// - `conduit.runtime.attention_sinks`
    public var runtimeFeatureFlags: [String: Bool]
    /// Optional provider model allowlist used by runtime feature policy.
    public var runtimeModelAllowlist: [String]

    public init(
        jitMinToolCount: Int = 12,
        defaultJITLoadCount: Int = 6,
        pointerThresholdBytes: Int = 1024,
        pointerSummaryMaxChars: Int = 240,
        runtimeFeatureFlags: [String: Bool] = [:],
        runtimeModelAllowlist: [String] = []
    ) {
        self.jitMinToolCount = max(1, jitMinToolCount)
        self.defaultJITLoadCount = max(1, defaultJITLoadCount)
        self.pointerThresholdBytes = max(1, pointerThresholdBytes)
        self.pointerSummaryMaxChars = max(0, pointerSummaryMaxChars)
        self.runtimeFeatureFlags = runtimeFeatureFlags
        self.runtimeModelAllowlist = runtimeModelAllowlist.sorted()
    }
}

public struct MembraneEnvironment: Sendable {
    public var isEnabled: Bool
    public var configuration: MembraneFeatureConfiguration
    public var adapter: (any MembraneAgentAdapter)?

    public init(
        isEnabled: Bool = true,
        configuration: MembraneFeatureConfiguration = .default,
        adapter: (any MembraneAgentAdapter)? = nil
    ) {
        self.isEnabled = isEnabled
        self.configuration = configuration
        self.adapter = adapter
    }

    public static let disabled = MembraneEnvironment(isEnabled: false)
    public static let enabled = MembraneEnvironment(isEnabled: true)
}

public struct MembranePlannedBoundary: Sendable {
    public let prompt: String
    public let toolSchemas: [ToolSchema]
    public let mode: String

    public init(prompt: String, toolSchemas: [ToolSchema], mode: String) {
        self.prompt = prompt
        self.toolSchemas = toolSchemas
        self.mode = mode
    }
}

public struct MembraneToolResultBoundary: Sendable {
    public let textForConversation: String
    public let pointerID: String?

    public init(textForConversation: String, pointerID: String? = nil) {
        self.textForConversation = textForConversation
        self.pointerID = pointerID
    }
}

public enum MembraneAgentAdapterError: Error, Sendable, Equatable {
    case unsupportedInternalTool(name: String)
    case invalidInternalToolArguments(name: String, reason: String)
}

public protocol MembraneAgentAdapter: Sendable {
    func plan(
        prompt: String,
        toolSchemas: [ToolSchema],
        profile: ContextProfile
    ) async throws -> MembranePlannedBoundary

    func transformToolResult(
        toolName: String,
        output: String
    ) async throws -> MembraneToolResultBoundary

    func handleInternalToolCall(
        name: String,
        arguments: [String: SendableValue]
    ) async throws -> String?

    func restore(checkpointData: Data?) async throws
    func snapshotCheckpointData() async throws -> Data?
}

public actor DefaultMembraneAgentAdapter: MembraneAgentAdapter {
    public init(configuration: MembraneFeatureConfiguration = .default) {
        self.configuration = configuration

        #if canImport(Membrane)
        jitLoader = JITToolLoader(jitMinToolCount: configuration.jitMinToolCount)
        let store = InMemoryPointerStore()
        pointerStore = store
        pointerResolver = PointerResolver(
            store: store,
            config: PointerResolverConfig(
                pointerThresholdBytes: configuration.pointerThresholdBytes,
                summaryMaxChars: configuration.pointerSummaryMaxChars
            )
        )
        toolPlan = .allowAll
        #endif

        // TODO: Restore when MembraneHive ships MembraneCheckpointAdapter
        // #if canImport(MembraneHive)
        // checkpointAdapter = MembraneCheckpointAdapter()
        // #endif
    }

    public func plan(
        prompt: String,
        toolSchemas: [ToolSchema],
        profile: ContextProfile
    ) async throws -> MembranePlannedBoundary {
        let sortedSchemas = MembraneInternalTools.sortedSchemas(toolSchemas)
        var selectedSchemas = sortedSchemas
        var mode = "allowAll"

        #if canImport(Membrane)
        let manifests = sortedSchemas.map { ToolManifest(name: $0.name, description: $0.description) }
        var nextPlan = jitLoader.plan(tools: manifests, existingPlan: toolPlan)

        switch nextPlan {
        case .allowAll:
            mode = "allowAll"
            allowListToolNames = []

        case let .allowList(toolNames):
            mode = "allowList"
            let allowSet = Set(toolNames)
            allowListToolNames = Array(allowSet).sorted()
            selectedSchemas = sortedSchemas.filter { allowSet.contains($0.name) }

        case let .jit(index, _):
            mode = "jit"

            var loadedSet = Set(loadedToolNames)
            if loadedSet.isEmpty {
                let defaults = index.map(\.name).sorted().prefix(configuration.defaultJITLoadCount)
                loadedSet.formUnion(defaults)
            }
            loadedToolNames = Array(loadedSet).sorted()

            nextPlan = ToolPlan.normalizedJIT(index: index, loadedToolNames: loadedToolNames)
            let loadedNames = Set(loadedToolNames)
            selectedSchemas = sortedSchemas.filter { loadedNames.contains($0.name) }
            selectedSchemas.append(contentsOf: MembraneInternalTools.schemaSet())
            selectedSchemas = MembraneInternalTools.sortedSchemas(selectedSchemas)
        }

        toolPlan = nextPlan
        #endif

        let distilledPrompt = distillPromptIfNeeded(
            prompt: prompt,
            profile: profile,
            toolCount: toolSchemas.count
        )

        try await syncCheckpointState(totalTokens: profile.budget.maxInputTokens)
        return MembranePlannedBoundary(
            prompt: distilledPrompt,
            toolSchemas: MembraneInternalTools.sortedSchemas(selectedSchemas),
            mode: mode
        )
    }

    public func transformToolResult(
        toolName: String,
        output: String
    ) async throws -> MembraneToolResultBoundary {
        usageCounts[toolName, default: 0] += 1

        #if canImport(Membrane)
        let decision = try await pointerResolver.pointerizeIfNeeded(toolName: toolName, output: output)
        switch decision {
        case let .inline(text):
            try await syncCheckpointState()
            return MembraneToolResultBoundary(textForConversation: text)

        case let .pointer(pointer, replacementText):
            pointerIDs.append(pointer.id)
            pointerIDs = Array(Set(pointerIDs)).sorted()
            try await syncCheckpointState()
            return MembraneToolResultBoundary(
                textForConversation: replacementText,
                pointerID: pointer.id
            )
        }
        #else
        try await syncCheckpointState()
        return MembraneToolResultBoundary(textForConversation: output)
        #endif
    }

    public func handleInternalToolCall(
        name: String,
        arguments: [String: SendableValue]
    ) async throws -> String? {
        guard MembraneInternalTools.isInternalTool(name) else {
            return nil
        }

        switch name {
        case MembraneInternalToolName.loadToolSchema:
            guard let toolName = arguments["tool_name"]?.stringValue, !toolName.isEmpty else {
                throw MembraneAgentAdapterError.invalidInternalToolArguments(
                    name: name,
                    reason: "Missing required string argument: tool_name"
                )
            }

            loadedToolNames.append(toolName)
            loadedToolNames = Array(Set(loadedToolNames)).sorted()
            try await syncCheckpointState()
            return "Loaded tool schema: \(toolName)"

        case MembraneInternalToolName.addTools:
            let names = parseToolNames(arguments["tool_names"])
            guard !names.isEmpty else {
                throw MembraneAgentAdapterError.invalidInternalToolArguments(
                    name: name,
                    reason: "Missing required array argument: tool_names"
                )
            }
            loadedToolNames = Array(Set(loadedToolNames + names)).sorted()
            try await syncCheckpointState()
            return "Added tools: \(names.sorted().joined(separator: ", "))"

        case MembraneInternalToolName.removeTools:
            let names = parseToolNames(arguments["tool_names"])
            guard !names.isEmpty else {
                throw MembraneAgentAdapterError.invalidInternalToolArguments(
                    name: name,
                    reason: "Missing required array argument: tool_names"
                )
            }
            let removals = Set(names)
            loadedToolNames.removeAll { removals.contains($0) }
            loadedToolNames.sort()
            try await syncCheckpointState()
            return "Removed tools: \(names.sorted().joined(separator: ", "))"

        case MembraneInternalToolName.resolvePointer:
            guard let pointerID = arguments["pointer_id"]?.stringValue, !pointerID.isEmpty else {
                throw MembraneAgentAdapterError.invalidInternalToolArguments(
                    name: name,
                    reason: "Missing required string argument: pointer_id"
                )
            }

            #if canImport(Membrane)
            let payload = try await pointerStore.resolve(pointerID: pointerID)
            if let text = String(data: payload, encoding: .utf8) {
                return text
            }
            return payload.base64EncodedString()
            #else
            return "Pointer resolution unavailable in this build."
            #endif

        default:
            throw MembraneAgentAdapterError.unsupportedInternalTool(name: name)
        }
    }

    public func restore(checkpointData _: Data?) async throws {
        // TODO: Restore when MembraneHive ships MembraneCheckpointAdapter/MembraneCheckpointState.
    }

    public func snapshotCheckpointData() async throws -> Data? {
        // TODO: Restore when MembraneHive ships MembraneCheckpointAdapter.
        return nil
    }

    private let configuration: MembraneFeatureConfiguration
    private var loadedToolNames: [String] = []
    private var allowListToolNames: [String] = []
    private var pointerIDs: [String] = []
    private var usageCounts: [String: Int] = [:]

    #if canImport(Membrane)
    private let jitLoader: JITToolLoader
    private let pointerStore: InMemoryPointerStore
    private let pointerResolver: PointerResolver
    private var toolPlan: ToolPlan
    #endif

    // TODO: Restore when MembraneHive ships MembraneCheckpointAdapter
    // #if canImport(MembraneHive)
    // private let checkpointAdapter: MembraneCheckpointAdapter
    // #endif

    private func parseToolNames(_ value: SendableValue?) -> [String] {
        guard let value else { return [] }
        switch value {
        case let .array(elements):
            return elements.compactMap(\.stringValue).filter { !$0.isEmpty }
        case let .string(raw):
            return raw
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        default:
            return []
        }
    }

    private func distillPromptIfNeeded(
        prompt: String,
        profile: ContextProfile,
        toolCount: Int
    ) -> String {
        guard profile.preset == .strict4k, toolCount >= configuration.jitMinToolCount else {
            return prompt
        }

        let charsPerToken = CharacterBasedTokenEstimator.shared.charactersPerToken
        let maxChars = max(1, profile.budget.maxInputTokens * charsPerToken)
        guard prompt.count > maxChars else {
            return prompt
        }

        let marker = "\n\n[Membrane distilled context]\n\n"
        if maxChars <= marker.count + 16 {
            return String(marker.prefix(maxChars))
        }

        let tailChars = max(16, maxChars / 3)
        let headChars = max(16, maxChars - marker.count - tailChars)
        let head = prefix(prompt, maxCharacters: headChars)
        let tail = suffix(prompt, maxCharacters: tailChars)

        var compacted = head + marker + tail
        if compacted.count > maxChars {
            let overflow = compacted.count - maxChars
            let adjustedTail = max(0, tailChars - overflow)
            compacted = head + marker + suffix(prompt, maxCharacters: adjustedTail)
        }

        if compacted.count <= maxChars {
            return compacted
        }

        let adjustedHead = max(0, maxChars - marker.count)
        return prefix(prompt, maxCharacters: adjustedHead) + marker
    }

    private func prefix(_ text: String, maxCharacters: Int) -> String {
        guard maxCharacters > 0 else { return "" }
        guard text.count > maxCharacters else { return text }
        let end = text.index(text.startIndex, offsetBy: maxCharacters)
        return String(text[..<end])
    }

    private func suffix(_ text: String, maxCharacters: Int) -> String {
        guard maxCharacters > 0 else { return "" }
        guard text.count > maxCharacters else { return text }
        let start = text.index(text.endIndex, offsetBy: -maxCharacters)
        return String(text[start...])
    }

    private func syncCheckpointState(totalTokens _: Int = 4_096) async throws {
        // TODO: Restore when MembraneHive ships MembraneCheckpointState/MembraneCheckpointAdapter.
    }
}
