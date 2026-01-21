// Environment.swift
// SwiftAgents Framework
//
// SwiftUI-style environment property wrapper for AgentEnvironment values.

import Foundation

/// Reads an `AgentEnvironment` value from the current task-local environment.
///
/// This is modeled after SwiftUI's `@Environment`:
///
/// ```swift
/// struct MyAgent: Agent {
///     @Environment(\.inferenceProvider) var provider
///     var loop: some AgentLoop { Generate() }
/// }
/// ```
@propertyWrapper
public struct Environment<Value: Sendable>: Sendable {
    private let keyPath: SendableKeyPath<AgentEnvironment, Value>

    public init(_ keyPath: KeyPath<AgentEnvironment, Value>) {
        self.keyPath = SendableKeyPath(keyPath)
    }

    public var wrappedValue: Value {
        AgentEnvironmentValues.current[keyPath: keyPath.keyPath]
    }
}

private struct SendableKeyPath<Root, Value>: @unchecked Sendable {
    let keyPath: KeyPath<Root, Value>

    init(_ keyPath: KeyPath<Root, Value>) {
        self.keyPath = keyPath
    }
}
