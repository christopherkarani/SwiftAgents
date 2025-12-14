// ResilienceTests.swift
// SwiftAgents Framework
//
// Common test utilities and helpers for resilience component tests.
// Individual test suites are in extension files for better organization.

import Testing
import Foundation
@testable import SwiftAgents

// MARK: - Test Errors

enum TestError: Error, Equatable, LocalizedError {
    case transient
    case permanent
    case network
    case timeout

    var errorDescription: String? {
        switch self {
        case .transient: return "Transient error occurred"
        case .permanent: return "Permanent error occurred"
        case .network: return "Network error occurred"
        case .timeout: return "Timeout error occurred"
        }
    }
}

// MARK: - Test Helpers (Thread-safe)

/// Thread-safe counter for testing async code
actor TestCounter {
    private var value: Int = 0

    func increment() -> Int {
        value += 1
        return value
    }

    func get() -> Int { value }

    func reset() { value = 0 }
}

/// Thread-safe array for tracking values
actor TestRecorder<T: Sendable> {
    private var items: [T] = []

    func append(_ item: T) {
        items.append(item)
    }

    func getAll() -> [T] { items }

    func count() -> Int { items.count }
}

/// Thread-safe boolean flag
actor TestFlag {
    private var value: Bool = false

    func set(_ newValue: Bool) {
        value = newValue
    }

    func get() -> Bool { value }
}
