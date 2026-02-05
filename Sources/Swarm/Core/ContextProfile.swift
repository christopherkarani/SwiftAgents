// ContextProfile.swift
// Swarm Framework
//
// Profiles and budgets for managing on-device context allocation.

import Foundation

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

    // MARK: Stored Properties

    /// Preset name for introspection.
    public let preset: Preset

    /// Maximum context window size in tokens.
    public let maxContextTokens: Int

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
        summaryTriggerUtilization: Double
    ) {
        precondition(maxContextTokens > 0, "maxContextTokens must be positive")
        precondition((0.0 ... 1.0).contains(workingTokenRatio), "workingTokenRatio must be 0.0-1.0")
        precondition((0.0 ... 1.0).contains(memoryTokenRatio), "memoryTokenRatio must be 0.0-1.0")
        precondition((0.0 ... 1.0).contains(toolIOTokenRatio), "toolIOTokenRatio must be 0.0-1.0")
        precondition((0.0 ... 1.0).contains(summaryTokenRatio), "summaryTokenRatio must be 0.0-1.0")
        let ratioSum = workingTokenRatio + memoryTokenRatio + toolIOTokenRatio
        precondition(abs(ratioSum - 1.0) < 0.0001, "Context ratios must sum to 1.0")
        precondition(maxToolOutputTokens > 0, "maxToolOutputTokens must be positive")
        precondition(maxRetrievedItems > 0, "maxRetrievedItems must be positive")
        precondition(maxRetrievedItemTokens > 0, "maxRetrievedItemTokens must be positive")
        precondition(summaryCadenceTurns > 0, "summaryCadenceTurns must be positive")
        precondition((0.0 ... 1.0).contains(summaryTriggerUtilization), "summaryTriggerUtilization must be 0.0-1.0")

        self.preset = preset
        self.maxContextTokens = maxContextTokens
        self.workingTokenRatio = workingTokenRatio
        self.memoryTokenRatio = memoryTokenRatio
        self.toolIOTokenRatio = toolIOTokenRatio
        self.summaryTokenRatio = summaryTokenRatio
        self.maxToolOutputTokens = maxToolOutputTokens
        self.maxRetrievedItems = maxRetrievedItems
        self.maxRetrievedItemTokens = maxRetrievedItemTokens
        self.summaryCadenceTurns = summaryCadenceTurns
        self.summaryTriggerUtilization = summaryTriggerUtilization
    }

    // MARK: Derived Budgets

    /// The computed context budget for this profile.
    public var budget: ContextBudget {
        let workingTokens = Int(Double(maxContextTokens) * workingTokenRatio)
        let memoryTokens = Int(Double(maxContextTokens) * memoryTokenRatio)
        let toolIOTokens = maxContextTokens - workingTokens - memoryTokens
        return ContextBudget(
            maxContextTokens: maxContextTokens,
            workingTokens: workingTokens,
            memoryTokens: memoryTokens,
            toolIOTokens: toolIOTokens,
            maxToolOutputTokens: maxToolOutputTokens,
            maxRetrievedItems: maxRetrievedItems,
            maxRetrievedItemTokens: maxRetrievedItemTokens
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
}

// MARK: - ContextBudget

/// Computed token budget derived from a context profile.
public struct ContextBudget: Sendable, Equatable {
    public let maxContextTokens: Int
    public let workingTokens: Int
    public let memoryTokens: Int
    public let toolIOTokens: Int
    public let maxToolOutputTokens: Int
    public let maxRetrievedItems: Int
    public let maxRetrievedItemTokens: Int
}
