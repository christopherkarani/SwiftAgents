// ContextProfile.swift
// Swarm Framework
//
// Profiles and budgets for managing on-device context allocation.

import Foundation
import Logging

// MARK: - ContextProfile

/// Defines context budgeting defaults for long-running agent workflows.
///
/// Use `ContextProfile` to select a preset policy (lite/balanced/heavy) and
/// derive token budgets for memory, working context, and tool I/O.
public struct ContextProfile: Sendable, Equatable {
    // MARK: Presets

    public enum Preset: String, Sendable {
        case lite
        case balanced
        case heavy
        case strict4k
    }

    /// Template values for strict 4k context enforcement.
    public struct Strict4kTemplate: Sendable, Equatable {
        public static let `default` = Strict4kTemplate()

        public var maxTotalContextTokens: Int
        public var systemTokens: Int
        public var historyTokens: Int
        public var memoryTokens: Int
        public var toolIOTokens: Int
        public var outputReserveTokens: Int
        public var protocolOverheadReserveTokens: Int
        public var safetyMarginTokens: Int
        public var maxToolOutputTokens: Int
        public var maxRetrievedItems: Int
        public var maxRetrievedItemTokens: Int
        public var summaryCadenceTurns: Int
        public var summaryTriggerUtilization: Double

        public var maxInputTokens: Int {
            maxTotalContextTokens - outputReserveTokens - protocolOverheadReserveTokens - safetyMarginTokens
        }

        public init(
            maxTotalContextTokens: Int = 4096,
            systemTokens: Int = 512,
            historyTokens: Int = 1400,
            memoryTokens: Int = 900,
            toolIOTokens: Int = 600,
            outputReserveTokens: Int = 500,
            protocolOverheadReserveTokens: Int = 120,
            safetyMarginTokens: Int = 64,
            maxToolOutputTokens: Int = 600,
            maxRetrievedItems: Int = 3,
            maxRetrievedItemTokens: Int = 300,
            summaryCadenceTurns: Int = 2,
            summaryTriggerUtilization: Double = 0.65
        ) {
            precondition(maxTotalContextTokens > 0, "maxTotalContextTokens must be positive")
            precondition(systemTokens >= 0, "systemTokens cannot be negative")
            precondition(historyTokens >= 0, "historyTokens cannot be negative")
            precondition(memoryTokens >= 0, "memoryTokens cannot be negative")
            precondition(toolIOTokens >= 0, "toolIOTokens cannot be negative")
            precondition(outputReserveTokens >= 0, "outputReserveTokens cannot be negative")
            precondition(protocolOverheadReserveTokens >= 0, "protocolOverheadReserveTokens cannot be negative")
            precondition(safetyMarginTokens >= 0, "safetyMarginTokens cannot be negative")
            precondition(maxToolOutputTokens > 0, "maxToolOutputTokens must be positive")
            precondition(maxRetrievedItems > 0, "maxRetrievedItems must be positive")
            precondition(maxRetrievedItemTokens > 0, "maxRetrievedItemTokens must be positive")
            precondition(summaryCadenceTurns > 0, "summaryCadenceTurns must be positive")
            precondition((0.0 ... 1.0).contains(summaryTriggerUtilization), "summaryTriggerUtilization must be 0.0-1.0")

            let maxInput = maxTotalContextTokens - outputReserveTokens - protocolOverheadReserveTokens - safetyMarginTokens
            precondition(maxInput > 0, "Strict4k maxInputTokens must be positive")

            let allocated = systemTokens + historyTokens + memoryTokens + toolIOTokens
            precondition(allocated <= maxInput, "Strict4k buckets exceed maxInputTokens")

            self.maxTotalContextTokens = maxTotalContextTokens
            self.systemTokens = systemTokens
            self.historyTokens = historyTokens
            self.memoryTokens = memoryTokens
            self.toolIOTokens = toolIOTokens
            self.outputReserveTokens = outputReserveTokens
            self.protocolOverheadReserveTokens = protocolOverheadReserveTokens
            self.safetyMarginTokens = safetyMarginTokens
            self.maxToolOutputTokens = maxToolOutputTokens
            self.maxRetrievedItems = maxRetrievedItems
            self.maxRetrievedItemTokens = maxRetrievedItemTokens
            self.summaryCadenceTurns = summaryCadenceTurns
            self.summaryTriggerUtilization = summaryTriggerUtilization
        }
    }

    /// Platform defaults for base context sizing.
    public struct PlatformDefaults: Sendable, Equatable {
        /// Maximum context tokens for iOS defaults.
        public static let iOS = PlatformDefaults(maxContextTokens: 4096)
        /// Maximum context tokens for macOS defaults.
        public static let macOS = PlatformDefaults(maxContextTokens: 8192)

        /// The platform-default context sizing for the current OS.
        public static var current: PlatformDefaults {
            #if os(macOS)
            PlatformDefaults.macOS
            #else
            PlatformDefaults.iOS
            #endif
        }

        /// Base maximum context tokens.
        public let maxContextTokens: Int
    }

    /// Default profile for the current platform (balanced preset).
    public static var platformDefault: ContextProfile {
        ContextProfile.balanced(maxContextTokens: PlatformDefaults.current.maxContextTokens)
    }

    /// Lite preset tuned for low-latency, mobile-first usage.
    public static var lite: ContextProfile {
        ContextProfile.lite(maxContextTokens: PlatformDefaults.current.maxContextTokens)
    }

    /// Balanced preset tuned for general-purpose usage.
    public static var balanced: ContextProfile {
        ContextProfile.balanced(maxContextTokens: PlatformDefaults.current.maxContextTokens)
    }

    /// Heavy preset tuned for deep research and multi-step reasoning.
    public static var heavy: ContextProfile {
        ContextProfile.heavy(maxContextTokens: PlatformDefaults.current.maxContextTokens)
    }

    /// Strict 4k preset with an explicit 4096 total token contract.
    public static var strict4k: ContextProfile {
        ContextProfile.strict4k(template: .default)
    }

    /// Creates a lite preset with a custom context window size.
    public static func lite(maxContextTokens: Int) -> ContextProfile {
        ContextProfile(
            preset: .lite,
            maxContextTokens: maxContextTokens,
            workingTokenRatio: 0.50,
            memoryTokenRatio: 0.35,
            toolIOTokenRatio: 0.15,
            summaryTokenRatio: 0.60,
            maxToolOutputTokens: 800,
            maxRetrievedItems: 2,
            maxRetrievedItemTokens: 300,
            summaryCadenceTurns: 2,
            summaryTriggerUtilization: 0.60
        )
    }

    /// Creates a balanced preset with a custom context window size.
    public static func balanced(maxContextTokens: Int) -> ContextProfile {
        ContextProfile(
            preset: .balanced,
            maxContextTokens: maxContextTokens,
            workingTokenRatio: 0.55,
            memoryTokenRatio: 0.30,
            toolIOTokenRatio: 0.15,
            summaryTokenRatio: 0.50,
            maxToolOutputTokens: 1000,
            maxRetrievedItems: 3,
            maxRetrievedItemTokens: 400,
            summaryCadenceTurns: 3,
            summaryTriggerUtilization: 0.65
        )
    }

    /// Creates a heavy preset with a custom context window size.
    public static func heavy(maxContextTokens: Int) -> ContextProfile {
        ContextProfile(
            preset: .heavy,
            maxContextTokens: maxContextTokens,
            workingTokenRatio: 0.60,
            memoryTokenRatio: 0.25,
            toolIOTokenRatio: 0.15,
            summaryTokenRatio: 0.40,
            maxToolOutputTokens: 1200,
            maxRetrievedItems: 5,
            maxRetrievedItemTokens: 500,
            summaryCadenceTurns: 3,
            summaryTriggerUtilization: 0.70
        )
    }

    /// Creates a strict 4k profile from an override template.
    public static func strict4k(template: Strict4kTemplate = .default) -> ContextProfile {
        let maxInput = template.maxInputTokens
        let minimumWorkingTokens = template.systemTokens + template.historyTokens
        let workingTokens = max(maxInput - template.memoryTokens - template.toolIOTokens, minimumWorkingTokens)

        let workingRatio = Double(workingTokens) / Double(maxInput)
        let memoryRatio = Double(template.memoryTokens) / Double(maxInput)
        let toolIORatio = Double(template.toolIOTokens) / Double(maxInput)

        return ContextProfile(
            preset: .strict4k,
            maxContextTokens: maxInput,
            workingTokenRatio: workingRatio,
            memoryTokenRatio: memoryRatio,
            toolIOTokenRatio: toolIORatio,
            summaryTokenRatio: 0.50,
            maxToolOutputTokens: template.maxToolOutputTokens,
            maxRetrievedItems: template.maxRetrievedItems,
            maxRetrievedItemTokens: template.maxRetrievedItemTokens,
            summaryCadenceTurns: template.summaryCadenceTurns,
            summaryTriggerUtilization: template.summaryTriggerUtilization,
            maxTotalContextTokens: template.maxTotalContextTokens,
            outputReserveTokens: template.outputReserveTokens,
            protocolOverheadReserveTokens: template.protocolOverheadReserveTokens,
            safetyMarginTokens: template.safetyMarginTokens,
            bucketCaps: ContextBucketCaps(
                system: template.systemTokens,
                history: template.historyTokens,
                memory: template.memoryTokens,
                toolIO: template.toolIOTokens
            )
        )
    }

    // MARK: Stored Properties

    /// Preset name for introspection.
    public let preset: Preset

    /// Maximum context window size in tokens.
    public let maxContextTokens: Int

    /// Maximum total context envelope in tokens (input + reserves).
    public let maxTotalContextTokens: Int

    /// Ratio allocated to working context (system + user + recent history).
    public let workingTokenRatio: Double

    /// Ratio allocated to memory retrieval (summaries + recalled context).
    public let memoryTokenRatio: Double

    /// Ratio reserved for tool I/O buffers.
    public let toolIOTokenRatio: Double

    /// Ratio of memory budget allocated to summaries (0.0 - 1.0).
    public let summaryTokenRatio: Double

    /// Maximum tokens to accept from a single tool output.
    public let maxToolOutputTokens: Int

    /// Maximum items to retrieve from memory.
    public let maxRetrievedItems: Int

    /// Maximum tokens per retrieved memory item.
    public let maxRetrievedItemTokens: Int

    /// Turn cadence for summary refresh.
    public let summaryCadenceTurns: Int

    /// Utilization threshold that triggers summary refresh.
    public let summaryTriggerUtilization: Double

    /// Output budget reserved for model completion tokens.
    public let outputReserveTokens: Int

    /// Protocol overhead budget reserved for provider/runtime envelopes.
    public let protocolOverheadReserveTokens: Int

    /// Safety margin reserved to avoid edge overflows.
    public let safetyMarginTokens: Int

    /// Optional explicit bucket ceilings (used by strict profiles).
    public let bucketCaps: ContextBucketCaps?

    // MARK: Initialization

    /// Creates a context profile.
    ///
    /// - Parameters:
    ///   - preset: Preset label.
    ///   - maxContextTokens: Maximum context window size.
    ///   - workingTokenRatio: Ratio allocated to working context.
    ///   - memoryTokenRatio: Ratio allocated to memory retrieval.
    ///   - toolIOTokenRatio: Ratio reserved for tool I/O.
    ///   - summaryTokenRatio: Ratio of memory budget for summaries.
    ///   - maxToolOutputTokens: Max tokens per tool output.
    ///   - maxRetrievedItems: Max number of retrieved memory items.
    ///   - maxRetrievedItemTokens: Max tokens per retrieved memory item.
    ///   - summaryCadenceTurns: Turns between summary updates.
    ///   - summaryTriggerUtilization: Trigger threshold for summary refresh.
    ///   - maxTotalContextTokens: Optional total context envelope.
    ///   - outputReserveTokens: Reserved output budget.
    ///   - protocolOverheadReserveTokens: Reserved protocol overhead budget.
    ///   - safetyMarginTokens: Reserved safety margin budget.
    ///   - bucketCaps: Optional explicit bucket caps.
    public init(
        preset: Preset,
        maxContextTokens: Int,
        workingTokenRatio: Double,
        memoryTokenRatio: Double,
        toolIOTokenRatio: Double,
        summaryTokenRatio: Double,
        maxToolOutputTokens: Int,
        maxRetrievedItems: Int,
        maxRetrievedItemTokens: Int,
        summaryCadenceTurns: Int,
        summaryTriggerUtilization: Double,
        maxTotalContextTokens: Int? = nil,
        outputReserveTokens: Int = 0,
        protocolOverheadReserveTokens: Int = 0,
        safetyMarginTokens: Int = 0,
        bucketCaps: ContextBucketCaps? = nil
    ) {
        let safeWorking = Self.clampUnitInterval(workingTokenRatio)
        let safeMemory = Self.clampUnitInterval(memoryTokenRatio)
        let safeToolIO = Self.clampUnitInterval(toolIOTokenRatio)
        if safeWorking != workingTokenRatio {
            Log.agents.warning("ContextProfile: workingTokenRatio \(workingTokenRatio) out of [0,1]; clamped to \(safeWorking)")
        }
        if safeMemory != memoryTokenRatio {
            Log.agents.warning("ContextProfile: memoryTokenRatio \(memoryTokenRatio) out of [0,1]; clamped to \(safeMemory)")
        }
        if safeToolIO != toolIOTokenRatio {
            Log.agents.warning("ContextProfile: toolIOTokenRatio \(toolIOTokenRatio) out of [0,1]; clamped to \(safeToolIO)")
        }
        let normalizedRatios = Self.normalizeContextRatios(
            working: safeWorking,
            memory: safeMemory,
            toolIO: safeToolIO
        )
        let safeSummary = Self.clampUnitInterval(summaryTokenRatio)
        if safeSummary != summaryTokenRatio {
            Log.agents.warning("ContextProfile: summaryTokenRatio \(summaryTokenRatio) out of [0,1]; clamped to \(safeSummary)")
        }
        let safeSummaryTrigger = Self.clampUnitInterval(summaryTriggerUtilization)
        if safeSummaryTrigger != summaryTriggerUtilization {
            Log.agents.warning("ContextProfile: summaryTriggerUtilization \(summaryTriggerUtilization) out of [0,1]; clamped to \(safeSummaryTrigger)")
        }

        self.preset = preset
        self.maxContextTokens = max(1, maxContextTokens)
        let safeOutputReserveTokens = max(0, outputReserveTokens)
        let safeProtocolOverheadTokens = max(0, protocolOverheadReserveTokens)
        let safeSafetyMarginTokens = max(0, safetyMarginTokens)
        let reserved = safeOutputReserveTokens + safeProtocolOverheadTokens + safeSafetyMarginTokens
        let resolvedMaxTotal = maxTotalContextTokens ?? (max(1, maxContextTokens) + reserved)
        self.maxTotalContextTokens = max(resolvedMaxTotal, max(1, maxContextTokens) + reserved)
        self.workingTokenRatio = normalizedRatios.working
        self.memoryTokenRatio = normalizedRatios.memory
        self.toolIOTokenRatio = normalizedRatios.toolIO
        self.summaryTokenRatio = safeSummary
        self.maxToolOutputTokens = max(1, maxToolOutputTokens)
        self.maxRetrievedItems = max(1, maxRetrievedItems)
        self.maxRetrievedItemTokens = max(1, maxRetrievedItemTokens)
        self.summaryCadenceTurns = max(1, summaryCadenceTurns)
        self.summaryTriggerUtilization = safeSummaryTrigger
        self.outputReserveTokens = safeOutputReserveTokens
        self.protocolOverheadReserveTokens = safeProtocolOverheadTokens
        self.safetyMarginTokens = safeSafetyMarginTokens
        self.bucketCaps = bucketCaps
    }

    // MARK: Derived Budgets

    /// The computed context budget for this profile.
    public var budget: ContextBudget {
        let workingTokens: Int
        let memoryTokens: Int
        let toolIOTokens: Int

        if preset == .strict4k, let bucketCaps {
            memoryTokens = bucketCaps.memory
            toolIOTokens = bucketCaps.toolIO

            let strictWorkingTokens = maxContextTokens - memoryTokens - toolIOTokens
            precondition(strictWorkingTokens >= 0, "strict4k bucket caps cannot exceed maxContextTokens")
            workingTokens = strictWorkingTokens
        } else {
            workingTokens = Int(Double(maxContextTokens) * workingTokenRatio)
            memoryTokens = Int(Double(maxContextTokens) * memoryTokenRatio)
            toolIOTokens = maxContextTokens - workingTokens - memoryTokens
        }

        return ContextBudget(
            maxTotalContextTokens: maxTotalContextTokens,
            maxContextTokens: maxContextTokens,
            maxInputTokens: maxContextTokens,
            maxOutputTokens: outputReserveTokens,
            workingTokens: workingTokens,
            memoryTokens: memoryTokens,
            toolIOTokens: toolIOTokens,
            outputReserveTokens: outputReserveTokens,
            protocolOverheadReserveTokens: protocolOverheadReserveTokens,
            safetyMarginTokens: safetyMarginTokens,
            maxToolOutputTokens: maxToolOutputTokens,
            maxRetrievedItems: maxRetrievedItems,
            maxRetrievedItemTokens: maxRetrievedItemTokens,
            bucketCaps: bucketCaps
        )
    }

    /// Maximum tokens available for memory retrieval.
    public var memoryTokenLimit: Int {
        budget.memoryTokens
    }

    /// Maximum tokens reserved for summaries within memory.
    public var summaryTokenLimit: Int {
        Int(Double(budget.memoryTokens) * summaryTokenRatio)
    }

    // MARK: Private

    private static func clampUnitInterval(_ value: Double) -> Double {
        if !value.isFinite {
            return 0.0
        }
        if value < 0 {
            return 0.0
        }
        if value > 1 {
            return 1.0
        }
        return value
    }

    /// Minimum ratio floor applied to each context bucket before normalization.
    ///
    /// Prevents degenerate configurations where one or more budgets collapse to
    /// zero tokens, which can break callers that consume those budgets (e.g., memory
    /// retrieval, tool I/O). Each ratio is guaranteed to be at least this value
    /// after normalization.
    private static let minimumContextRatio: Double = 0.05

    private static func normalizeContextRatios(working: Double, memory: Double, toolIO: Double) -> (working: Double, memory: Double, toolIO: Double) {
        // Apply a minimum floor so no budget collapses to zero tokens.
        let w = max(minimumContextRatio, working)
        let m = max(minimumContextRatio, memory)
        let t = max(minimumContextRatio, toolIO)
        let sum = w + m + t
        if sum <= .ulpOfOne {
            return (0.55, 0.30, 0.15)
        }
        return (w / sum, m / sum, t / sum)
    }
}

// MARK: - ContextBudget

/// Computed token budget derived from a context profile.
public struct ContextBudget: Sendable, Equatable {
    public let maxTotalContextTokens: Int
    public let maxContextTokens: Int
    public let maxInputTokens: Int
    public let maxOutputTokens: Int
    public let workingTokens: Int
    public let memoryTokens: Int
    public let toolIOTokens: Int
    public let outputReserveTokens: Int
    public let protocolOverheadReserveTokens: Int
    public let safetyMarginTokens: Int
    public let maxToolOutputTokens: Int
    public let maxRetrievedItems: Int
    public let maxRetrievedItemTokens: Int
    public let bucketCaps: ContextBucketCaps?
}

/// Optional explicit per-bucket ceilings for prompt construction.
public struct ContextBucketCaps: Sendable, Equatable {
    public let system: Int
    public let history: Int
    public let memory: Int
    public let toolIO: Int

    public init(system: Int, history: Int, memory: Int, toolIO: Int) {
        precondition(system >= 0, "system bucket cannot be negative")
        precondition(history >= 0, "history bucket cannot be negative")
        precondition(memory >= 0, "memory bucket cannot be negative")
        precondition(toolIO >= 0, "toolIO bucket cannot be negative")

        self.system = system
        self.history = history
        self.memory = memory
        self.toolIO = toolIO
    }
}
