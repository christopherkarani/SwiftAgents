// OrchestrationError.swift
// Swarm Framework
//
// Comprehensive error types for multi-agent orchestration operations.

import Foundation

// MARK: - OrchestrationError

/// Errors that can occur during multi-agent orchestration.
public enum OrchestrationError: Error, Sendable, Equatable {
    // MARK: - Agent Registration Errors

    /// An agent with the given name was not found in the orchestrator.
    case agentNotFound(name: String)

    /// No agents are configured in the orchestrator.
    case noAgentsConfigured

    // MARK: - Handoff Errors

    /// Agent handoff failed between source and target agents.
    case handoffFailed(source: String, target: String, reason: String)

    /// Agent handoff was skipped because it was disabled.
    case handoffSkipped(from: String, to: String, reason: String)

    // MARK: - Routing Errors

    /// Routing decision failed to determine the next agent.
    case routingFailed(reason: String)

    /// Route condition is invalid or cannot be evaluated.
    case invalidRouteCondition(reason: String)

    // MARK: - Parallel Execution Errors

    /// Merge strategy failed to combine parallel agent results.
    case mergeStrategyFailed(reason: String)

    /// All agents in parallel execution failed.
    case allAgentsFailed(errors: [String])
}

// MARK: LocalizedError

extension OrchestrationError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .agentNotFound(name):
            return "Agent not found: \(name)"
        case .noAgentsConfigured:
            return "No agents configured in orchestrator"
        case let .handoffFailed(source, target, reason):
            return "Handoff failed from '\(source)' to '\(target)': \(reason)"
        case let .handoffSkipped(from, to, reason):
            return "Handoff skipped from '\(from)' to '\(to)': \(reason)"
        case let .routingFailed(reason):
            return "Routing decision failed: \(reason)"
        case let .invalidRouteCondition(reason):
            return "Invalid route condition: \(reason)"
        case let .mergeStrategyFailed(reason):
            return "Merge strategy failed: \(reason)"
        case let .allAgentsFailed(errors):
            let errorList = errors.joined(separator: ", ")
            return "All parallel agents failed: [\(errorList)]"
        }
    }
}

// MARK: CustomDebugStringConvertible

extension OrchestrationError: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case let .agentNotFound(name):
            return "OrchestrationError.agentNotFound(name: \(name))"
        case .noAgentsConfigured:
            return "OrchestrationError.noAgentsConfigured"
        case let .handoffFailed(source, target, reason):
            return "OrchestrationError.handoffFailed(source: \(source), target: \(target), reason: \(reason))"
        case let .handoffSkipped(from, to, reason):
            return "OrchestrationError.handoffSkipped(from: \(from), to: \(to), reason: \(reason))"
        case let .routingFailed(reason):
            return "OrchestrationError.routingFailed(reason: \(reason))"
        case let .invalidRouteCondition(reason):
            return "OrchestrationError.invalidRouteCondition(reason: \(reason))"
        case let .mergeStrategyFailed(reason):
            return "OrchestrationError.mergeStrategyFailed(reason: \(reason))"
        case let .allAgentsFailed(errors):
            return "OrchestrationError.allAgentsFailed(errors: \(errors))"
        }
    }
}
