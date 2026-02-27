import Conduit
import Foundation

/// Bridges a Conduit TextGenerator into Swarm' InferenceProvider.
///
/// This adapter keeps tool execution in Swarm by returning tool calls
/// upstream, avoiding Conduit's internal ToolExecutor.
public struct ConduitInferenceProvider<Provider: Conduit.TextGenerator>: InferenceProvider, ToolCallStreamingInferenceProvider {
    public init(
        provider: Provider,
        model: Provider.ModelID,
        baseConfig: Conduit.GenerateConfig = .default
    ) {
        self.provider = provider
        self.model = model
        self.baseConfig = baseConfig
    }

    public func generate(prompt: String, options: InferenceOptions) async throws -> String {
        let config = apply(options: options, to: baseConfig)
        return try await provider.generate(prompt, model: model, config: config)
    }

    public func stream(prompt: String, options: InferenceOptions) -> AsyncThrowingStream<String, Error> {
        let config = apply(options: options, to: baseConfig)
        return provider.stream(prompt, model: model, config: config)
    }

    public func generateWithToolCalls(
        prompt: String,
        tools: [ToolSchema],
        options: InferenceOptions
    ) async throws -> InferenceResponse {
        var config = apply(options: options, to: baseConfig)
        let toolDefinitions = try ConduitToolSchemaConverter.toolDefinitions(from: tools)
        config = config.tools(toolDefinitions)

        if !tools.isEmpty, let toolChoice = options.toolChoice {
            config = config.toolChoice(toolChoice.toConduitToolChoice())
        }

        let result = try await provider.generate(
            messages: [Conduit.Message.user(prompt)],
            model: model,
            config: config
        )

        let parsedToolCalls = try ConduitToolCallConverter.toParsedToolCalls(result.toolCalls)
        let finishReason = mapFinishReason(result.finishReason, toolCalls: parsedToolCalls)
        let usage = result.usage.map { usage in
            InferenceResponse.TokenUsage(
                inputTokens: usage.promptTokens,
                outputTokens: usage.completionTokens
            )
        }

        return InferenceResponse(
            content: result.text.isEmpty ? nil : result.text,
            toolCalls: parsedToolCalls,
            finishReason: finishReason,
            usage: usage
        )
    }

    public func streamWithToolCalls(
        prompt: String,
        tools: [ToolSchema],
        options: InferenceOptions
    ) -> AsyncThrowingStream<InferenceStreamUpdate, Error> {
        StreamHelper.makeTrackedStream { continuation in
            var config = apply(options: options, to: baseConfig)
            let toolDefinitions = try ConduitToolSchemaConverter.toolDefinitions(from: tools)
            config = config.tools(toolDefinitions)

            if !tools.isEmpty, let toolChoice = options.toolChoice {
                config = config.toolChoice(toolChoice.toConduitToolChoice())
            }

            var lastFragmentByCallId: [String: String] = [:]

            let chunkStream = provider.streamWithMetadata(
                messages: [Conduit.Message.user(prompt)],
                model: model,
                config: config
            )

            for try await chunk in chunkStream {
                if !chunk.text.isEmpty {
                    continuation.yield(.outputChunk(chunk.text))
                }

                if let partial = chunk.partialToolCall {
                    // Avoid emitting duplicate fragments if the provider repeats the same buffer.
                    if lastFragmentByCallId[partial.id] != partial.argumentsFragment {
                        lastFragmentByCallId[partial.id] = partial.argumentsFragment
                        continuation.yield(.toolCallPartial(
                            PartialToolCallUpdate(
                                providerCallId: partial.id,
                                toolName: partial.toolName,
                                index: partial.index,
                                argumentsFragment: partial.argumentsFragment
                            )
                        ))
                    }
                }

                if let usage = chunk.usage {
                    continuation.yield(.usage(
                        InferenceResponse.TokenUsage(
                            inputTokens: usage.promptTokens,
                            outputTokens: usage.completionTokens
                        )
                    ))
                }

                if let completed = chunk.completedToolCalls, !completed.isEmpty {
                    let parsedToolCalls = try ConduitToolCallConverter.toParsedToolCalls(completed)
                    continuation.yield(.toolCallsCompleted(parsedToolCalls))
                }
            }

            continuation.finish()
        }
    }

    // MARK: - Private

    private let provider: Provider
    private let model: Provider.ModelID
    private let baseConfig: Conduit.GenerateConfig

    private func apply(options: InferenceOptions, to config: Conduit.GenerateConfig) -> Conduit.GenerateConfig {
        var updated = config

        updated = updated.temperature(Float(options.temperature))

        if let maxTokens = options.maxTokens {
            updated = updated.maxTokens(maxTokens)
        }

        if let seed = options.seed {
            updated = updated.seed(UInt64(bitPattern: Int64(seed)))
        }

        if let topP = options.topP {
            updated = updated.topP(Float(topP))
        }

        if let topK = options.topK {
            updated = updated.topK(topK)
        }

        if let frequencyPenalty = options.frequencyPenalty {
            updated = updated.frequencyPenalty(Float(frequencyPenalty))
        }

        if let presencePenalty = options.presencePenalty {
            updated = updated.presencePenalty(Float(presencePenalty))
        }

        if !options.stopSequences.isEmpty {
            updated = updated.stopSequences(options.stopSequences)
        }

        if let parallelToolCalls = options.parallelToolCalls {
            updated = updated.parallelToolCalls(parallelToolCalls)
        }

        if let providerSettings = options.providerSettings, !providerSettings.isEmpty {
            updated = applyProviderRuntimeSettings(providerSettings, to: updated)
        }

        return updated
    }

    private func applyProviderRuntimeSettings(
        _ providerSettings: [String: SendableValue],
        to config: Conduit.GenerateConfig
    ) -> Conduit.GenerateConfig {
        var updated = config

        if let runtimeFeatures = runtimeFeatures(from: providerSettings) {
            updated = updated.runtimeFeatures(runtimeFeatures)
        }

        if let runtimePolicyOverride = runtimePolicyOverride(from: providerSettings) {
            updated = updated.runtimePolicyOverride(runtimePolicyOverride)
        }

        return updated
    }

    private func runtimeFeatures(
        from providerSettings: [String: SendableValue]
    ) -> Conduit.ProviderRuntimeFeatureConfiguration? {
        var runtimeFeatures = Conduit.ProviderRuntimeFeatureConfiguration()
        var hasOverride = false

        if let enabled = firstBool(
            for: ["conduit.runtime.kv_quantization.enabled"],
            in: providerSettings
        ) {
            runtimeFeatures.kvQuantization.enabled = enabled
            hasOverride = true
        }
        if let bits = firstInt(
            for: ["conduit.runtime.kv_quantization.bits"],
            in: providerSettings
        ) {
            runtimeFeatures.kvQuantization.bits = bits
            hasOverride = true
        }

        if let enabled = firstBool(
            for: ["conduit.runtime.attention_sinks.enabled"],
            in: providerSettings
        ) {
            runtimeFeatures.attentionSinks.enabled = enabled
            hasOverride = true
        }
        if let sinkTokenCount = firstInt(
            for: ["conduit.runtime.attention_sinks.sink_token_count"],
            in: providerSettings
        ) {
            runtimeFeatures.attentionSinks.sinkTokenCount = sinkTokenCount
            hasOverride = true
        }

        if let enabled = firstBool(
            for: ["conduit.runtime.kv_swap.enabled"],
            in: providerSettings
        ) {
            runtimeFeatures.kvSwap.enabled = enabled
            hasOverride = true
        }
        if let ioBudgetMBPerSecond = firstInt(
            for: ["conduit.runtime.kv_swap.io_budget_mb_per_second"],
            in: providerSettings
        ) {
            runtimeFeatures.kvSwap.ioBudgetMBPerSecond = ioBudgetMBPerSecond
            hasOverride = true
        }

        if let enabled = firstBool(
            for: ["conduit.runtime.incremental_prefill.enabled"],
            in: providerSettings
        ) {
            runtimeFeatures.incrementalPrefill.enabled = enabled
            hasOverride = true
        }
        if let maxPrefixTokens = firstInt(
            for: ["conduit.runtime.incremental_prefill.max_prefix_tokens"],
            in: providerSettings
        ) {
            runtimeFeatures.incrementalPrefill.maxPrefixTokens = maxPrefixTokens
            hasOverride = true
        }

        if let enabled = firstBool(
            for: [
                "conduit.runtime.speculative.enabled",
                "conduit.runtime.speculative_scheduling.enabled",
            ],
            in: providerSettings
        ) {
            runtimeFeatures.speculativeScheduling.enabled = enabled
            hasOverride = true
        }
        if let draftStreamCount = firstInt(
            for: [
                "conduit.runtime.speculative.draft_stream_count",
                "conduit.runtime.speculative_scheduling.draft_stream_count",
            ],
            in: providerSettings
        ) {
            runtimeFeatures.speculativeScheduling.draftStreamCount = draftStreamCount
            hasOverride = true
        }
        if let draftAheadTokens = firstInt(
            for: [
                "conduit.runtime.speculative.draft_ahead_tokens",
                "conduit.runtime.speculative_scheduling.draft_ahead_tokens",
            ],
            in: providerSettings
        ) {
            runtimeFeatures.speculativeScheduling.draftAheadTokens = draftAheadTokens
            hasOverride = true
        }
        if let verificationBatchTokens = firstInt(
            for: [
                "conduit.runtime.speculative.verification_batch_tokens",
                "conduit.runtime.speculative_scheduling.verification_batch_tokens",
            ],
            in: providerSettings
        ) {
            runtimeFeatures.speculativeScheduling.verificationBatchTokens = verificationBatchTokens
            hasOverride = true
        }
        if let rollbackTokenBudgetPerTurn = firstInt(
            for: [
                "conduit.runtime.speculative.rollback_token_budget_per_turn",
                "conduit.runtime.speculative_scheduling.rollback_token_budget_per_turn",
            ],
            in: providerSettings
        ) {
            runtimeFeatures.speculativeScheduling.rollbackTokenBudgetPerTurn = rollbackTokenBudgetPerTurn
            hasOverride = true
        }
        if let autoDisableDivergenceRate = firstDouble(
            for: [
                "conduit.runtime.speculative.auto_disable_divergence_rate",
                "conduit.runtime.speculative_scheduling.auto_disable_divergence_rate",
            ],
            in: providerSettings
        ) {
            runtimeFeatures.speculativeScheduling.autoDisableDivergenceRate = autoDisableDivergenceRate
            hasOverride = true
        }

        return hasOverride ? runtimeFeatures : nil
    }

    private func runtimePolicyOverride(
        from providerSettings: [String: SendableValue]
    ) -> Conduit.ProviderRuntimePolicyOverride? {
        var featureFlags = Conduit.ProviderRuntimeFeatureFlagOverride()
        var modelAllowlist = Conduit.ProviderRuntimeModelAllowlistOverride()
        var hasFeatureFlagOverride = false
        var hasAllowlistOverride = false

        if let enabled = firstBool(
            for: ["conduit.runtime.policy.kv_quantization.enabled"],
            in: providerSettings
        ) {
            featureFlags.kvQuantization = enabled
            hasFeatureFlagOverride = true
        }

        if let enabled = firstBool(
            for: ["conduit.runtime.policy.attention_sinks.enabled"],
            in: providerSettings
        ) {
            featureFlags.attentionSinks = enabled
            hasFeatureFlagOverride = true
        }

        if let enabled = firstBool(
            for: ["conduit.runtime.policy.kv_swap.enabled"],
            in: providerSettings
        ) {
            featureFlags.kvSwap = enabled
            hasFeatureFlagOverride = true
        }

        if let enabled = firstBool(
            for: ["conduit.runtime.policy.incremental_prefill.enabled"],
            in: providerSettings
        ) {
            featureFlags.incrementalPrefill = enabled
            hasFeatureFlagOverride = true
        }

        if let enabled = firstBool(
            for: [
                "conduit.runtime.policy.speculative.enabled",
                "conduit.runtime.policy.speculative_scheduling.enabled",
            ],
            in: providerSettings
        ) {
            featureFlags.speculativeScheduling = enabled
            hasFeatureFlagOverride = true
        }

        if let globalAllowlist = firstStringSet(
            for: ["conduit.runtime.policy.model_allowlist"],
            in: providerSettings
        ) {
            modelAllowlist.kvQuantizationModels = globalAllowlist
            modelAllowlist.attentionSinkModels = globalAllowlist
            modelAllowlist.kvSwapModels = globalAllowlist
            modelAllowlist.incrementalPrefillModels = globalAllowlist
            modelAllowlist.speculativeSchedulingModels = globalAllowlist
            hasAllowlistOverride = true
        }

        if let allowlist = firstStringSet(
            for: ["conduit.runtime.policy.kv_quantization.model_allowlist"],
            in: providerSettings
        ) {
            modelAllowlist.kvQuantizationModels = allowlist
            hasAllowlistOverride = true
        }

        if let allowlist = firstStringSet(
            for: ["conduit.runtime.policy.attention_sinks.model_allowlist"],
            in: providerSettings
        ) {
            modelAllowlist.attentionSinkModels = allowlist
            hasAllowlistOverride = true
        }

        if let allowlist = firstStringSet(
            for: ["conduit.runtime.policy.kv_swap.model_allowlist"],
            in: providerSettings
        ) {
            modelAllowlist.kvSwapModels = allowlist
            hasAllowlistOverride = true
        }

        if let allowlist = firstStringSet(
            for: ["conduit.runtime.policy.incremental_prefill.model_allowlist"],
            in: providerSettings
        ) {
            modelAllowlist.incrementalPrefillModels = allowlist
            hasAllowlistOverride = true
        }

        if let allowlist = firstStringSet(
            for: [
                "conduit.runtime.policy.speculative.model_allowlist",
                "conduit.runtime.policy.speculative_scheduling.model_allowlist",
            ],
            in: providerSettings
        ) {
            modelAllowlist.speculativeSchedulingModels = allowlist
            hasAllowlistOverride = true
        }

        if !hasFeatureFlagOverride, !hasAllowlistOverride {
            return nil
        }

        return Conduit.ProviderRuntimePolicyOverride(
            featureFlags: featureFlags,
            modelAllowlist: modelAllowlist
        )
    }

    private func firstBool(
        for keys: [String],
        in providerSettings: [String: SendableValue]
    ) -> Bool? {
        for key in keys {
            if let value = providerSettings[key]?.boolValue {
                return value
            }
        }
        return nil
    }

    private func firstInt(
        for keys: [String],
        in providerSettings: [String: SendableValue]
    ) -> Int? {
        for key in keys {
            if let value = providerSettings[key]?.intValue {
                return value
            }
        }
        return nil
    }

    private func firstDouble(
        for keys: [String],
        in providerSettings: [String: SendableValue]
    ) -> Double? {
        for key in keys {
            if let value = providerSettings[key]?.doubleValue {
                return value
            }
        }
        return nil
    }

    private func firstStringSet(
        for keys: [String],
        in providerSettings: [String: SendableValue]
    ) -> Set<String>? {
        for key in keys {
            guard let elements = providerSettings[key]?.arrayValue else { continue }
            return Set(elements.compactMap(\.stringValue))
        }
        return nil
    }

    private func mapFinishReason(
        _ reason: Conduit.FinishReason,
        toolCalls: [InferenceResponse.ParsedToolCall]
    ) -> InferenceResponse.FinishReason {
        if reason.isToolCallRequest || !toolCalls.isEmpty {
            return .toolCall
        }

        switch reason {
        case .maxTokens:
            return .maxTokens
        case .contentFilter:
            return .contentFilter
        case .cancelled:
            return .cancelled
        default:
            return .completed
        }
    }
}

// MARK: - ToolChoice Mapping

private extension ToolChoice {
    func toConduitToolChoice() -> Conduit.ToolChoice {
        switch self {
        case .auto:
            return .auto
        case .none:
            return .none
        case .required:
            return .required
        case .specific(let toolName):
            return .tool(name: toolName)
        }
    }
}

// MARK: - Tool Schema Conversion

enum ConduitToolSchemaConverter {
    static func toolDefinitions(from tools: [ToolSchema]) throws -> [Conduit.Transcript.ToolDefinition] {
        try tools.map { tool in
            let schema = try generationSchema(for: tool)
            return Conduit.Transcript.ToolDefinition(
                name: tool.name,
                description: tool.description,
                parameters: schema
            )
        }
    }

    static func generationSchema(for tool: ToolSchema) throws -> Conduit.GenerationSchema {
        let rootName = SchemaName.rootName(for: tool.name)
        let properties = try tool.parameters.map { parameter in
            let schema = try dynamicSchema(
                for: parameter.type,
                name: SchemaName.propertyName(root: rootName, property: parameter.name)
            )
            return Conduit.DynamicGenerationSchema.Property(
                name: parameter.name,
                description: parameter.description,
                schema: schema,
                isOptional: !parameter.isRequired
            )
        }

        let root = Conduit.DynamicGenerationSchema(
            name: rootName,
            description: "Tool parameters for \(tool.name)",
            properties: properties
        )

        return try Conduit.GenerationSchema(root: root, dependencies: [])
    }

    private static func dynamicSchema(
        for type: ToolParameter.ParameterType,
        name: String
    ) throws -> Conduit.DynamicGenerationSchema {
        switch type {
        case .string:
            return Conduit.DynamicGenerationSchema(type: String.self)
        case .int:
            return Conduit.DynamicGenerationSchema(type: Int.self)
        case .double:
            return Conduit.DynamicGenerationSchema(type: Double.self)
        case .bool:
            return Conduit.DynamicGenerationSchema(type: Bool.self)
        case .array(let elementType):
            let elementSchema = try dynamicSchema(for: elementType, name: SchemaName.childName(base: name, suffix: "item"))
            return Conduit.DynamicGenerationSchema(arrayOf: elementSchema)
        case .object(let properties):
            let objectName = SchemaName.objectName(for: name)
            let objectProperties = try properties.map { parameter in
                let schema = try dynamicSchema(
                    for: parameter.type,
                    name: SchemaName.childName(base: objectName, suffix: parameter.name)
                )
                return Conduit.DynamicGenerationSchema.Property(
                    name: parameter.name,
                    description: parameter.description,
                    schema: schema,
                    isOptional: !parameter.isRequired
                )
            }
            return Conduit.DynamicGenerationSchema(
                name: objectName,
                description: nil,
                properties: objectProperties
            )
        case .oneOf(let options):
            return Conduit.DynamicGenerationSchema(
                name: SchemaName.enumName(for: name),
                description: nil,
                anyOf: options
            )
        case .any:
            return Conduit.DynamicGenerationSchema(
                name: SchemaName.anyName(for: name),
                description: nil,
                anyOf: [
                    Conduit.DynamicGenerationSchema(type: String.self),
                    Conduit.DynamicGenerationSchema(type: Double.self),
                    Conduit.DynamicGenerationSchema(type: Bool.self)
                ]
            )
        }
    }

    private enum SchemaName {
        static func rootName(for toolName: String) -> String {
            sanitize("SwarmToolParams_\(toolName)")
        }

        static func propertyName(root: String, property: String) -> String {
            sanitize("\(root)_\(property)")
        }

        static func childName(base: String, suffix: String) -> String {
            sanitize("\(base)_\(suffix)")
        }

        static func objectName(for name: String) -> String {
            sanitize("\(name)_Object")
        }

        static func enumName(for name: String) -> String {
            sanitize("\(name)_Enum")
        }

        static func anyName(for name: String) -> String {
            sanitize("\(name)_Any")
        }

        private static func sanitize(_ value: String) -> String {
            let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_")
            let sanitized = value.map { allowed.contains($0) ? $0 : "_" }
            let trimmed = String(sanitized).trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "SwarmToolParams" : trimmed
        }
    }
}

// MARK: - Tool Call Conversion

enum ConduitToolCallConverter {
    static func toParsedToolCalls(
        _ toolCalls: [Conduit.Transcript.ToolCall]
    ) throws -> [InferenceResponse.ParsedToolCall] {
        try toolCalls.map { try toParsedToolCall($0) }
    }

    static func toParsedToolCall(
        _ toolCall: Conduit.Transcript.ToolCall
    ) throws -> InferenceResponse.ParsedToolCall {
        let arguments = try parseArguments(toolCall.arguments, toolName: toolCall.toolName)
        return InferenceResponse.ParsedToolCall(
            id: toolCall.id,
            name: toolCall.toolName,
            arguments: arguments
        )
    }

    private static func parseArguments(
        _ content: Conduit.GeneratedContent,
        toolName: String
    ) throws -> [String: SendableValue] {
        let jsonString = content.jsonString
        guard let data = jsonString.data(using: .utf8) else {
            throw AgentError.invalidToolArguments(toolName: toolName, reason: "Invalid UTF-8 tool arguments")
        }

        let jsonObject = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        guard let dict = jsonObject as? [String: Any] else {
            throw AgentError.invalidToolArguments(toolName: toolName, reason: "Tool arguments must be a JSON object")
        }

        var result: [String: SendableValue] = [:]
        for (key, value) in dict {
            result[key] = SendableValue.fromJSONValue(value)
        }
        return result
    }
}
