// Guardrail.swift
// Swarm Framework
//
// Shared guardrail marker protocol.

import Foundation

/// Marker protocol shared by input/output/tool guardrails.
///
/// Guardrails are small validation components that can be composed and executed
/// before/after agent steps.
public protocol Guardrail: Sendable {
    /// A stable name for identification, logging, and errors.
    var name: String { get }
}

