// AgentEnvironment.swift
// Swarm Framework
//
// Task-local environment values for declarative agent configuration.

import Foundation

/// Environment values that can be provided implicitly to agents during execution.
///
/// `AgentEnvironment` is modeled after SwiftUI's `EnvironmentValues` pattern: a caller can
/// set environment values once (e.g. an inference provider) and agents that do not have an
/// explicit configuration can fall back to these values.
///
/// Environment values are propagated using `TaskLocal` via `AgentEnvironmentValues.current`.
public struct AgentEnvironment: Sendable {
    public var inferenceProvider: (any InferenceProvider)?
    public var tracer: (any Tracer)?
    public var memory: (any Memory)?

    public init(
        inferenceProvider: (any InferenceProvider)? = nil,
        tracer: (any Tracer)? = nil,
        memory: (any Memory)? = nil
    ) {
        self.inferenceProvider = inferenceProvider
        self.tracer = tracer
        self.memory = memory
    }
}

/// Task-local access to the current `AgentEnvironment`.
///
/// Callers should generally prefer using the `.environment(...)` modifier on `AgentRuntime`
/// (see `EnvironmentAgent`) instead of interacting with `TaskLocal` directly.
public enum AgentEnvironmentValues {
    @TaskLocal public static var current = AgentEnvironment()
}

