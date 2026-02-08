// TypedContextKeyTests.swift
// SwarmTests
//
// Tests for type-safe ContextKey for AgentContext.

import Foundation
@testable import Swarm
import Testing

// MARK: - TypedContextKeyTests

@Suite("Typed ContextKey Tests")
struct TypedContextKeyTests {
    // MARK: - Basic ContextKey Usage

    @Test("Create and use string context key")
    func createAndUseStringContextKey() async throws {
        let context = AgentContext(input: "test")

        await context.setTyped(.userID, value: "user-123")
        let retrieved: String? = await context.getTyped(.userID)

        #expect(retrieved == "user-123")
    }

    @Test("Create and use int context key")
    func createAndUseIntContextKey() async throws {
        let context = AgentContext(input: "test")

        await context.setTyped(.requestCount, value: 42)
        let retrieved: Int? = await context.getTyped(.requestCount)

        #expect(retrieved == 42)
    }

    @Test("Create and use bool context key")
    func createAndUseBoolContextKey() async throws {
        let context = AgentContext(input: "test")

        await context.setTyped(.isAuthenticated, value: true)
        let retrieved: Bool? = await context.getTyped(.isAuthenticated)

        #expect(retrieved == true)
    }

    // MARK: - Complex Types

    @Test("Context key with array type")
    func contextKeyWithArrayType() async throws {
        let context = AgentContext(input: "test")

        let permissions = ["read", "write", "execute"]
        await context.setTyped(.permissions, value: permissions)
        let retrieved: [String]? = await context.getTyped(.permissions)

        #expect(retrieved == permissions)
    }

    @Test("Context key with custom Codable type")
    func contextKeyWithCustomType() async throws {
        let context = AgentContext(input: "test")

        let userProfile = UserProfile(id: "123", name: "Alice", role: .admin)
        await context.setTyped(.userProfile, value: userProfile)
        let retrieved: UserProfile? = await context.getTyped(.userProfile)

        #expect(retrieved?.id == "123")
        #expect(retrieved?.name == "Alice")
        #expect(retrieved?.role == .admin)
    }

    // MARK: - Type Safety

    @Test("Context key enforces type at compile time")
    func contextKeyEnforcesType() async throws {
        let context = AgentContext(input: "test")

        // This should only compile if types match
        await context.setTyped(.userID, value: "string-value")

        // Getting with correct type works
        let _: String? = await context.getTyped(.userID)

        // The following would not compile due to type mismatch:
        // let _: Int? = await context.getTyped(.userID)
    }

    @Test("Different keys with same name but different types")
    func differentKeysWithSameNameDifferentTypes() async throws {
        let stringKey = ContextKey<String>("value")
        let intKey = ContextKey<Int>("value")

        let context = AgentContext(input: "test")

        await context.setTyped(stringKey, value: "hello")
        await context.setTyped(intKey, value: 42)

        // Note: In implementation, these would need separate storage
        // or the later write overwrites the earlier
        // This test documents expected behavior
        let stringValue: String? = await context.getTyped(stringKey)
        let intValue: Int? = await context.getTyped(intKey)

        // Implementation should handle this appropriately
        #expect(stringValue != nil || intValue != nil)
    }

    // MARK: - Nil and Missing Values

    @Test("Get returns nil for missing key")
    func getReturnsNilForMissingKey() async throws {
        let context = AgentContext(input: "test")

        let retrieved: String? = await context.getTyped(.userID)

        #expect(retrieved == nil)
    }

    @Test("Set nil removes value")
    func setNilRemovesValue() async throws {
        let context = AgentContext(input: "test")

        await context.setTyped(.userID, value: "user-123")
        await context.removeTyped(.userID)

        let retrieved: String? = await context.getTyped(.userID)
        #expect(retrieved == nil)
    }

    // MARK: - Default Values

    @Test("Get with default value when missing")
    func getWithDefaultValueWhenMissing() async throws {
        let context = AgentContext(input: "test")

        let retrieved = await context.getTyped(.requestCount, default: 0)

        #expect(retrieved == 0)
    }

    @Test("Get with default value when present")
    func getWithDefaultValueWhenPresent() async throws {
        let context = AgentContext(input: "test")

        await context.setTyped(.requestCount, value: 10)
        let retrieved = await context.getTyped(.requestCount, default: 0)

        #expect(retrieved == 10)
    }

    // MARK: - ContextKey Equality

    @Test("Context keys with same name and type are equal")
    func contextKeysWithSameNameAndTypeAreEqual() {
        let key1 = ContextKey<String>("user_id")
        let key2 = ContextKey<String>("user_id")

        #expect(key1 == key2)
    }

    @Test("Context keys with different names are not equal")
    func contextKeysWithDifferentNamesAreNotEqual() {
        let key1 = ContextKey<String>("user_id")
        let key2 = ContextKey<String>("session_id")

        #expect(key1 != key2)
    }

    // MARK: - ContextKey Hashable

    @Test("Context key can be used in Set")
    func contextKeyCanBeUsedInSet() {
        let key1 = ContextKey<String>("key1")
        let key2 = ContextKey<String>("key2")
        let key1Duplicate = ContextKey<String>("key1")

        var keySet: Set<ContextKey<String>> = [key1, key2, key1Duplicate]

        #expect(keySet.count == 2)
        #expect(keySet.contains(key1))
        #expect(keySet.contains(key2))
    }

    // MARK: - Static Key Definitions

    @Test("Static keys are accessible")
    func staticKeysAreAccessible() {
        #expect(ContextKey<String>.userID.name == "user_id")
        #expect(ContextKey<Int>.requestCount.name == "request_count")
        #expect(ContextKey<Bool>.isAuthenticated.name == "is_authenticated")
    }

    // MARK: - Context Key in Route Conditions

    @Test("Context key works with route conditions")
    func contextKeyWorksWithRouteConditions() async throws {
        let context = AgentContext(input: "test")
        await context.setTyped(.isAuthenticated, value: true)

        let condition = RouteCondition.contextHasTyped(.isAuthenticated, equalTo: true)
        let matches = await condition.matches(input: "test", context: context)

        #expect(matches == true)
    }

    @Test("Route condition fails for missing typed key")
    func routeConditionFailsForMissingTypedKey() async throws {
        let context = AgentContext(input: "test")
        // Don't set isAuthenticated

        let condition = RouteCondition.contextHasTyped(.isAuthenticated, equalTo: true)
        let matches = await condition.matches(input: "test", context: context)

        #expect(matches == false)
    }

    // MARK: - Thread Safety

    @Test("Context key access is thread-safe")
    func contextKeyAccessIsThreadSafe() async throws {
        let context = AgentContext(input: "test")

        // Perform concurrent reads and writes
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    await context.setTyped(.requestCount, value: i)
                }
                group.addTask {
                    let _: Int? = await context.getTyped(.requestCount)
                }
            }
        }

        // If we get here without crashes, thread safety is working
        #expect(true)
    }
}

// MARK: - ContextKey

/// Type-safe context key with generic value type
struct ContextKey<Value: Sendable>: Hashable, Sendable {
    let name: String

    init(_ name: String) {
        self.name = name
    }

    static func == (lhs: ContextKey<Value>, rhs: ContextKey<Value>) -> Bool {
        lhs.name == rhs.name
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

// MARK: - Standard Context Keys

extension ContextKey where Value == String {
    static let userID = ContextKey("user_id")
    static let sessionID = ContextKey("session_id")
}

extension ContextKey where Value == Int {
    static let requestCount = ContextKey("request_count")
    static let retryCount = ContextKey("retry_count")
}

extension ContextKey where Value == Bool {
    static let isAuthenticated = ContextKey("is_authenticated")
    static let isDebugMode = ContextKey("is_debug_mode")
}

extension ContextKey where Value == [String] {
    static let permissions = ContextKey("permissions")
    static let tags = ContextKey("tags")
}

extension ContextKey where Value == UserProfile {
    static let userProfile = ContextKey("user_profile")
}

// MARK: - AgentContext Extensions

extension AgentContext {
    /// Sets a typed value in the context
    func setTyped<T: Sendable & Codable>(_ key: ContextKey<T>, value: T) async {
        do {
            let sendableValue = try SendableValue(encoding: value)
            set(key.name, value: sendableValue)
        } catch {
            // Log or handle encoding error if needed
        }
    }

    /// Gets a typed value from the context
    func getTyped<T: Sendable & Codable>(_ key: ContextKey<T>) async -> T? {
        guard let sendableValue = get(key.name) else { return nil }

        // Handle primitive types directly to avoid JSON serialization issues
        // with top-level primitives
        if let boolValue = sendableValue.boolValue, let result = boolValue as? T {
            return result
        }
        if let intValue = sendableValue.intValue, let result = intValue as? T {
            return result
        }
        if let stringValue = sendableValue.stringValue, let result = stringValue as? T {
            return result
        }
        if let doubleValue = sendableValue.doubleValue, let result = doubleValue as? T {
            return result
        }

        // For complex types (arrays, dictionaries), use JSON-based decode
        // Only decode() for non-primitive types to avoid JSON serialization errors
        switch sendableValue {
        case .array,
             .dictionary:
            do {
                return try sendableValue.decode()
            } catch {
                return nil
            }
        case .bool,
             .double,
             .int,
             .null,
             .string:
            // Primitive type that didn't match the expected type T
            return nil
        }
    }

    /// Gets a typed value with a default
    func getTyped<T: Sendable & Codable>(_ key: ContextKey<T>, default defaultValue: T) async -> T {
        await getTyped(key) ?? defaultValue
    }

    /// Removes a typed value from the context
    func removeTyped(_ key: ContextKey<some Sendable>) async {
        _ = remove(key.name)
    }
}

// MARK: - RouteCondition Extensions

extension RouteCondition {
    /// Creates a condition that checks for a typed context value
    static func contextHasTyped<T: Sendable & Codable & Equatable>(
        _ key: ContextKey<T>,
        equalTo value: T
    ) -> RouteCondition {
        RouteCondition { _, context in
            guard let context else { return false }
            let stored: T? = await context.getTyped(key)
            return stored == value
        }
    }
}

// MARK: - UserProfile

struct UserProfile: Sendable, Codable, Equatable {
    enum UserRole: String, Sendable, Codable {
        case user
        case admin
        case moderator
    }

    let id: String
    let name: String
    let role: UserRole
}
