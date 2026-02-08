// AgentConfiguration.swift
// Swarm Framework
//
// Runtime configuration settings for agent execution.

import Foundation

// MARK: - SwarmRuntimeMode

/// Runtime execution mode for orchestration.
public enum SwarmRuntimeMode: Sendable, Equatable {
    /// Always execute orchestration using the Swift in-process engine.
    case swift

    /// Execute orchestration using the Hive runtime. Fails if Hive is unavailable.
    case hive

    /// Alias for `.hive` — explicitly communicates that Hive is required.
    case requireHive
}

/// Optional Hive run options override for orchestration execution.
public struct SwarmHiveRunOptionsOverride: Sendable, Equatable {
    public var maxSteps: Int?
    public var maxConcurrentTasks: Int?
    public var debugPayloads: Bool?
    public var deterministicTokenStreaming: Bool?
    public var eventBufferCapacity: Int?

    public init(
        maxSteps: Int? = nil,
        maxConcurrentTasks: Int? = nil,
        debugPayloads: Bool? = nil,
        deterministicTokenStreaming: Bool? = nil,
        eventBufferCapacity: Int? = nil
    ) {
        self.maxSteps = maxSteps
        self.maxConcurrentTasks = maxConcurrentTasks
        self.debugPayloads = debugPayloads
        self.deterministicTokenStreaming = deterministicTokenStreaming
        self.eventBufferCapacity = eventBufferCapacity
    }
}

// MARK: - InferencePolicy

/// Policy hints for model inference routing.
///
/// When running on the Hive runtime, these map to `HiveInferenceHints`.
/// On the Swift runtime, these inform provider selection.
public struct InferencePolicy: Sendable, Equatable {
    /// Desired latency tier for inference.
    public enum LatencyTier: String, Sendable, Equatable {
        /// Low-latency, interactive use (e.g., chat).
        case interactive
        /// Higher latency acceptable (e.g., batch processing).
        case background
    }

    /// Network conditions relevant to inference routing.
    public enum NetworkState: String, Sendable, Equatable {
        case offline
        case online
        case metered
    }

    /// Desired latency tier. Default: `.interactive`
    public var latencyTier: LatencyTier

    /// Whether on-device/private inference is required. Default: `false`
    public var privacyRequired: Bool

    /// Optional output token budget hint for inference.
    ///
    /// This limits the model's generation length, not the context window.
    /// For context window management, see ``AgentConfiguration/contextProfile``.
    /// Default: `nil`
    public var tokenBudget: Int?

    /// Current network state hint. Default: `.online`
    public var networkState: NetworkState

    public init(
        latencyTier: LatencyTier = .interactive,
        privacyRequired: Bool = false,
        tokenBudget: Int? = nil,
        networkState: NetworkState = .online
    ) {
        if let tokenBudget {
            precondition(tokenBudget > 0, "tokenBudget must be positive")
        }
        self.latencyTier = latencyTier
        self.privacyRequired = privacyRequired
        self.tokenBudget = tokenBudget
        self.networkState = networkState
    }
}

// MARK: - AgentConfiguration

/// Configuration settings for agent execution.
///
/// Use this struct to customize agent behavior including iteration limits,
/// timeouts, model parameters, and execution options.
///
/// Example:
/// ```swift
/// let config = AgentConfiguration.default
///     .maxIterations(15)
///     .temperature(0.8)
///     .timeout(.seconds(120))
/// ```
@Builder
public struct AgentConfiguration: Sendable, Equatable {
    // MARK: - Default Configuration

    /// Default configuration with sensible defaults.
    public static let `default` = AgentConfiguration()

    /// Default runtime mode based on build capabilities.
    public static var defaultRuntimeMode: SwarmRuntimeMode {
#if SWARM_HIVE_RUNTIME && canImport(HiveCore)
        .hive
#else
        .swift
#endif
    }

    // MARK: - Identity

    /// The name of the agent for identification and logging.
    /// Default: "Agent"
    public var name: String

    // MARK: - Iteration Limits

    /// Maximum number of reasoning iterations before stopping.
    /// Default: 10
    public var maxIterations: Int

    /// Maximum time allowed for the entire execution.
    /// Default: 60 seconds
    public var timeout: Duration

    // MARK: - Model Settings

    /// Temperature for model generation (0.0 = deterministic, 2.0 = creative).
    /// Default: 1.0
    public var temperature: Double

    /// Maximum tokens to generate per response.
    /// Default: nil (model default)
    public var maxTokens: Int?

    /// Sequences that will stop generation when encountered.
    /// Default: empty
    public var stopSequences: [String]

    /// Extended model settings for fine-grained control.
    ///
    /// When set, values in `modelSettings` take precedence over the individual
    /// `temperature`, `maxTokens`, and `stopSequences` properties above.
    /// This allows for backward compatibility while enabling advanced configuration.
    ///
    /// Example:
    /// ```swift
    /// let config = AgentConfiguration.default
    ///     .modelSettings(ModelSettings.creative
    ///         .toolChoice(.required)
    ///         .parallelToolCalls(true)
    ///     )
    /// ```
    public var modelSettings: ModelSettings?

    // MARK: - Context Settings

    /// Context budgeting profile for long-running agent workflows.
    ///
    /// Default: `.platformDefault`
    public var contextProfile: ContextProfile

    // MARK: - Runtime Engine Settings

    /// Runtime mode for orchestration execution.
    ///
    /// Default: `.hive` when Hive runtime support is compiled in, otherwise `.swift`.
    public var runtimeMode: SwarmRuntimeMode

    /// Optional Hive run options override used by orchestration runs in Hive mode.
    ///
    /// Default: `nil` (engine defaults are used).
    public var hiveRunOptionsOverride: SwarmHiveRunOptionsOverride?

    /// Inference routing policy hints.
    ///
    /// Controls model selection when multiple backends are available.
    /// When using the Hive runtime, maps directly to `HiveInferenceHints`.
    ///
    /// Default: `nil` (use default routing)
    public var inferencePolicy: InferencePolicy?

    // MARK: - Behavior Settings

    /// Whether to stream responses.
    /// Default: true
    public var enableStreaming: Bool

    /// Whether to include tool call details in the result.
    /// Default: true
    public var includeToolCallDetails: Bool

    /// Whether to stop after the first tool error.
    /// Default: false
    public var stopOnToolError: Bool

    /// Whether to include the agent's reasoning in events.
    /// Default: true
    public var includeReasoning: Bool

    // MARK: - Session Settings

    /// Maximum number of session history messages to load on each agent run.
    ///
    /// When a session is provided to an agent, this controls how many recent
    /// messages are loaded as context. Set to `nil` to load all messages.
    ///
    /// Default: 50
    public var sessionHistoryLimit: Int?

    // MARK: - Parallel Execution Settings

    /// Whether to execute multiple tool calls in parallel.
    ///
    /// When enabled, if the agent requests multiple tool calls in a single turn,
    /// they will be executed concurrently using Swift's structured concurrency.
    /// This can significantly improve performance but may increase resource usage.
    ///
    /// ## Performance Impact
    /// - Sequential: Each tool waits for previous to complete
    /// - Parallel: All tools execute simultaneously
    /// - Speedup: Up to N× faster (where N = number of tools)
    ///
    /// ## Requirements
    /// - Tools must be independent (no shared mutable state)
    /// - All tools must be thread-safe
    ///
    /// Default: `false`
    public var parallelToolCalls: Bool

    // MARK: - Response Tracking Settings

    /// Previous response ID for conversation continuation.
    ///
    /// Set this to continue a conversation from a specific response.
    /// The agent will use this to maintain context across sessions.
    ///
    /// - Note: Usually set automatically when `autoPreviousResponseId` is enabled
    public var previousResponseId: String?

    /// Whether to automatically populate previous response ID.
    ///
    /// When enabled, the agent automatically tracks response IDs
    /// and uses them for conversation continuation within a session.
    ///
    /// Default: `false`
    public var autoPreviousResponseId: Bool

    // MARK: - Observability Settings

    /// Whether to enable default tracing when no explicit tracer is configured.
    ///
    /// When `true` and no tracer is set on the agent or via environment,
    /// the agent automatically uses a `SwiftLogTracer` at `.debug` level
    /// for execution tracing. Set to `false` to disable automatic tracing.
    ///
    /// Default: `true`
    public var defaultTracingEnabled: Bool

    // MARK: - Initialization

    /// Creates a new agent configuration.
    /// - Parameters:
    ///   - name: The agent name for identification. Default: "Agent"
    ///   - maxIterations: Maximum reasoning iterations. Default: 10
    ///   - timeout: Maximum execution time. Default: 60 seconds
    ///   - temperature: Model temperature (0.0-2.0). Default: 1.0
    ///   - maxTokens: Maximum tokens per response. Default: nil
    ///   - stopSequences: Generation stop sequences. Default: []
    ///   - modelSettings: Extended model settings. Default: nil
    ///   - enableStreaming: Enable response streaming. Default: true
    ///   - includeToolCallDetails: Include tool details in results. Default: true
    ///   - stopOnToolError: Stop on first tool error. Default: false
    ///   - includeReasoning: Include reasoning in events. Default: true
    ///   - sessionHistoryLimit: Maximum session history messages to load. Default: 50
    ///   - contextProfile: Context budgeting profile. Default: `.platformDefault`
    ///   - runtimeMode: Runtime mode for orchestration execution. Default: build-dependent
    ///   - hiveRunOptionsOverride: Optional Hive run options override for orchestration. Default: nil
    ///   - inferencePolicy: Inference routing policy hints. Default: nil
    ///   - parallelToolCalls: Enable parallel tool execution. Default: false
    ///   - previousResponseId: Previous response ID for continuation. Default: nil
    ///   - autoPreviousResponseId: Enable auto response ID tracking. Default: false
    ///   - defaultTracingEnabled: Enable default tracing when no tracer configured. Default: true
    public init(
        name: String = "Agent",
        maxIterations: Int = 10,
        timeout: Duration = .seconds(60),
        temperature: Double = 1.0,
        maxTokens: Int? = nil,
        stopSequences: [String] = [],
        modelSettings: ModelSettings? = nil,
        contextProfile: ContextProfile = .platformDefault,
        runtimeMode: SwarmRuntimeMode = AgentConfiguration.defaultRuntimeMode,
        hiveRunOptionsOverride: SwarmHiveRunOptionsOverride? = nil,
        inferencePolicy: InferencePolicy? = nil,
        enableStreaming: Bool = true,
        includeToolCallDetails: Bool = true,
        stopOnToolError: Bool = false,
        includeReasoning: Bool = true,
        sessionHistoryLimit: Int? = 50,
        parallelToolCalls: Bool = false,
        previousResponseId: String? = nil,
        autoPreviousResponseId: Bool = false,
        defaultTracingEnabled: Bool = true
    ) {
        precondition(maxIterations > 0, "maxIterations must be positive")
        precondition(timeout > .zero, "timeout must be positive")
        precondition((0.0 ... 2.0).contains(temperature), "temperature must be 0.0-2.0")

        self.name = name
        self.maxIterations = maxIterations
        self.timeout = timeout
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.stopSequences = stopSequences
        self.modelSettings = modelSettings
        self.contextProfile = contextProfile
        self.runtimeMode = runtimeMode
        self.hiveRunOptionsOverride = hiveRunOptionsOverride
        self.inferencePolicy = inferencePolicy
        self.enableStreaming = enableStreaming
        self.includeToolCallDetails = includeToolCallDetails
        self.stopOnToolError = stopOnToolError
        self.includeReasoning = includeReasoning
        self.sessionHistoryLimit = sessionHistoryLimit
        self.parallelToolCalls = parallelToolCalls
        self.previousResponseId = previousResponseId
        self.autoPreviousResponseId = autoPreviousResponseId
        self.defaultTracingEnabled = defaultTracingEnabled
    }
}

// MARK: CustomStringConvertible

extension AgentConfiguration: CustomStringConvertible {
    public var description: String {
        """
        AgentConfiguration(
            name: "\(name)",
            maxIterations: \(maxIterations),
            timeout: \(timeout),
            temperature: \(temperature),
            maxTokens: \(maxTokens.map(String.init) ?? "nil"),
            stopSequences: \(stopSequences),
            modelSettings: \(modelSettings.map { String(describing: $0) } ?? "nil"),
            contextProfile: \(contextProfile),
            runtimeMode: \(runtimeMode),
            hiveRunOptionsOverride: \(hiveRunOptionsOverride.map { String(describing: $0) } ?? "nil"),
            inferencePolicy: \(inferencePolicy.map { String(describing: $0) } ?? "nil"),
            enableStreaming: \(enableStreaming),
            includeToolCallDetails: \(includeToolCallDetails),
            stopOnToolError: \(stopOnToolError),
            includeReasoning: \(includeReasoning),
            sessionHistoryLimit: \(sessionHistoryLimit.map(String.init) ?? "nil"),
            parallelToolCalls: \(parallelToolCalls),
            previousResponseId: \(previousResponseId.map { "\"\($0)\"" } ?? "nil"),
            autoPreviousResponseId: \(autoPreviousResponseId),
            defaultTracingEnabled: \(defaultTracingEnabled)
        )
        """
    }
}
