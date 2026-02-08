// MemoryPromptDescriptor.swift
// Swarm Framework
//
// Optional prompt metadata for memory implementations.

import Foundation

/// Priority hint for memory context usage in prompts.
public enum MemoryPriorityHint: Sendable {
    case primary
    case secondary
}

/// Optional prompt metadata for memory-backed context.
///
/// Conform to this protocol to provide custom labels and guidance
/// for how the model should treat retrieved memory.
public protocol MemoryPromptDescriptor: Sendable {
    /// The label/title to display above memory context in prompts.
    var memoryPromptTitle: String { get }

    /// Optional guidance text to instruct how memory should be used.
    var memoryPromptGuidance: String? { get }

    /// Whether this memory should be treated as primary or secondary context.
    var memoryPriority: MemoryPriorityHint { get }
}
