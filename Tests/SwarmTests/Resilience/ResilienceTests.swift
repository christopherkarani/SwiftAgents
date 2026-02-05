// ResilienceTests.swift
// Swarm Framework
//
// Common test utilities and helpers for resilience component tests.
// Individual test suites are in extension files for better organization.

import Foundation
@testable import Swarm
import Testing

// MARK: - TestError

enum TestError: Error, Equatable, LocalizedError {
    case transient
    case permanent
    case network
    case timeout

    var errorDescription: String? {
        switch self {
        case .transient: "Transient error occurred"
        case .permanent: "Permanent error occurred"
        case .network: "Network error occurred"
        case .timeout: "Timeout error occurred"
        }
    }
}

// MARK: - TestCounter

/// Thread-safe counter for testing async code
actor TestCounter {
    // MARK: Internal

    func increment() -> Int {
        value += 1
        return value
    }

    func get() -> Int { value }

    func reset() { value = 0 }

    // MARK: Private

    private var value: Int = 0
}

// MARK: - TestRecorder

/// Thread-safe array for tracking values
actor TestRecorder<T: Sendable> {
    // MARK: Internal

    func append(_ item: T) {
        items.append(item)
    }

    func getAll() -> [T] { items }

    func count() -> Int { items.count }

    // MARK: Private

    private var items: [T] = []
}

// MARK: - TestFlag

/// Thread-safe boolean flag
actor TestFlag {
    // MARK: Internal

    func set(_ newValue: Bool) {
        value = newValue
    }

    func get() -> Bool { value }

    // MARK: Private

    private var value: Bool = false
}
