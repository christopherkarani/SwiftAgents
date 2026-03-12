// WorkflowValidationError.swift
// Swarm Framework
//
// Typed validation errors for user-configurable workflow graphs.

import Foundation

/// Typed validation failures for workflow graph construction.
public enum WorkflowValidationError: Error, Sendable, Equatable {
    /// Graph contains no executable nodes.
    case emptyGraph

    /// Graph contains duplicate node names.
    case duplicateNode(name: String)

    /// A node references a dependency that is not declared in the graph.
    case unknownDependency(node: String, dependency: String, availableNodes: [String])

    /// A cycle exists in the workflow graph.
    case cycleDetected(nodes: [String])
}

extension WorkflowValidationError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .emptyGraph:
            "Workflow graph must contain at least one node."
        case let .duplicateNode(name):
            "Workflow graph contains duplicate node name '\(name)'."
        case let .unknownDependency(node, dependency, available):
            "Node '\(node)' depends on unknown node '\(dependency)'. Available nodes: \(available.joined(separator: ", "))."
        case let .cycleDetected(nodes):
            "Cycle detected in workflow graph involving nodes: \(nodes.joined(separator: ", "))."
        }
    }
}
