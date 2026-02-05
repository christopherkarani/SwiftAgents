// PartialToolCallUpdate.swift
// Swarm Framework
//
// Public, provider-agnostic representation of a partially streamed tool call.

import Foundation

/// A partially streamed tool call update, suitable for live UI.
///
/// Providers may stream tool call arguments as JSON fragments before the tool call is complete.
/// Swarm surfaces these fragments so clients can render progress (e.g. "assembling arguments").
public struct PartialToolCallUpdate: Sendable, Equatable, Hashable, Codable {
    /// Provider-assigned tool call identifier (for correlation with completed tool calls).
    public let providerCallId: String

    /// Name of the tool being called.
    public let toolName: String

    /// Index of this tool call in the response (for multiple parallel tool calls).
    public let index: Int

    /// Current accumulated arguments JSON fragment.
    ///
    /// This may be invalid JSON until the tool call is complete.
    public let argumentsFragment: String

    public init(providerCallId: String, toolName: String, index: Int, argumentsFragment: String) {
        self.providerCallId = providerCallId
        self.toolName = toolName
        self.index = index
        self.argumentsFragment = argumentsFragment
    }
}

