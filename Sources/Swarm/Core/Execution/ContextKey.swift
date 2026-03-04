// ContextKey.swift
// Swarm Framework
//
// Type-safe context keys for AgentContext.

import Foundation

// MARK: - ContextKey

/// A type-safe key for accessing values in `AgentContext`.
///
/// `ContextKey` provides compile-time type safety for context values,
/// eliminating runtime type errors when storing and retrieving data.
///
/// Example:
/// ```swift
/// // Define typed keys
/// extension ContextKey where Value == String {
///     static let userID = ContextKey("user_id")
/// }
///
/// extension ContextKey where Value == Int {
///     static let retryCount = ContextKey("retry_count")
/// }
///
/// // Use with type safety
/// await context.setTyped(.userID, value: "user-123")
/// let id: String? = await context.getTyped(.userID)  // Type-safe!
/// ```
public struct ContextKey<Value: Sendable>: Hashable, Sendable {
    /// The string name of the key.
    public let name: String

    /// Creates a new context key.
    ///
    /// - Parameter name: The string name for the key.
    public init(_ name: String) {
        self.name = name
    }

    // MARK: - Equatable

    public static func == (lhs: ContextKey<Value>, rhs: ContextKey<Value>) -> Bool {
        lhs.name == rhs.name
    }

    // MARK: - Hashable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

// MARK: - Standard String Keys

public extension ContextKey where Value == String {
    /// User identifier key.
    static let userID = ContextKey("user_id")

    /// Session identifier key.
    static let sessionID = ContextKey("session_id")

    /// Correlation ID for tracing.
    static let correlationID = ContextKey("correlation_id")

    /// Current language/locale.
    static let language = ContextKey("language")

    /// API version being used.
    static let apiVersion = ContextKey("api_version")
}

// MARK: - Standard Int Keys

public extension ContextKey where Value == Int {
    /// Request counter key.
    static let requestCount = ContextKey("request_count")

    /// Retry counter key.
    static let retryCount = ContextKey("retry_count")

    /// Iteration counter key.
    static let iterationCount = ContextKey("iteration_count")

    /// Current depth in orchestration.
    static let depth = ContextKey("depth")
}

// MARK: - Standard Bool Keys

public extension ContextKey where Value == Bool {
    /// Whether the user is authenticated.
    static let isAuthenticated = ContextKey("is_authenticated")

    /// Whether debug mode is enabled.
    static let isDebugMode = ContextKey("is_debug_mode")

    /// Whether to enable verbose logging.
    static let verboseLogging = ContextKey("verbose_logging")

    /// Whether the request is a dry run.
    static let isDryRun = ContextKey("is_dry_run")
}

// MARK: - Standard Array Keys

public extension ContextKey where Value == [String] {
    /// User permissions/roles.
    static let permissions = ContextKey("permissions")

    /// Tags associated with the request.
    static let tags = ContextKey("tags")

    /// Feature flags enabled.
    static let featureFlags = ContextKey("feature_flags")
}

// MARK: - Standard Date Keys

public extension ContextKey where Value == Date {
    /// Request timestamp.
    static let timestamp = ContextKey("timestamp")

    /// Expiration time.
    static let expiresAt = ContextKey("expires_at")
}

// MARK: - AgentContext Typed Extensions

public extension AgentContext {
    /// Sets a typed value in the context.
    ///
    /// - Parameters:
    ///   - key: The typed context key.
    ///   - value: The value to store.
    ///
    /// Example:
    /// ```swift
    /// await context.setTyped(.userID, value: "user-123")
    /// await context.setTyped(.isAuthenticated, value: true)
    /// ```
    func setTyped<T: Sendable & Encodable>(_ key: ContextKey<T>, value: T) {
        do {
            let sendableValue = try SendableValue(encoding: value)
            set(key.name, value: sendableValue)
        } catch {
            // If encoding fails, store as string representation
            set(key.name, value: .string(String(describing: value)))
        }
    }

    /// Gets a typed value from the context.
    ///
    /// - Parameter key: The typed context key.
    /// - Returns: The value if found and type matches, nil otherwise.
    ///
    /// Example:
    /// ```swift
    /// let userID: String? = await context.getTyped(.userID)
    /// let isAuth: Bool? = await context.getTyped(.isAuthenticated)
    /// ```
    func getTyped<T: Sendable & Decodable>(_ key: ContextKey<T>) -> T? {
        guard let sendableValue = get(key.name) else {
            return nil
        }

        // Handle primitive types directly
        if T.self == String.self {
            return sendableValue.stringValue as? T
        }
        if T.self == Int.self {
            return sendableValue.intValue as? T
        }
        if T.self == Double.self {
            return sendableValue.doubleValue as? T
        }
        if T.self == Bool.self {
            return sendableValue.boolValue as? T
        }

        // Handle arrays
        if T.self == [String].self {
            if let array = sendableValue.arrayValue {
                let strings = array.compactMap(\.stringValue)
                return strings as? T
            }
        }

        // Handle Date
        if T.self == Date.self {
            if let timestamp = sendableValue.doubleValue {
                return Date(timeIntervalSince1970: timestamp) as? T
            }
        }

        // For complex types, try to decode
        do {
            return try sendableValue.decode()
        } catch {
            return nil
        }
    }

    /// Gets a typed value from the context with a default.
    ///
    /// - Parameters:
    ///   - key: The typed context key.
    ///   - defaultValue: The default value if not found.
    /// - Returns: The stored value or the default.
    ///
    /// Example:
    /// ```swift
    /// let count = await context.getTyped(.retryCount, default: 0)
    /// ```
    func getTyped<T: Sendable & Decodable>(_ key: ContextKey<T>, default defaultValue: T) -> T {
        getTyped(key) ?? defaultValue
    }

    /// Removes a typed value from the context.
    ///
    /// - Parameter key: The typed context key.
    ///
    /// Example:
    /// ```swift
    /// await context.removeTyped(.userID)
    /// ```
    func removeTyped(_ key: ContextKey<some Sendable>) {
        _ = remove(key.name)
    }

    /// Checks if a typed key exists in the context.
    ///
    /// - Parameter key: The typed context key.
    /// - Returns: True if the key exists.
    ///
    /// Example:
    /// ```swift
    /// if await context.hasTyped(.userID) {
    ///     // User ID is set
    /// }
    /// ```
    func hasTyped(_ key: ContextKey<some Sendable>) -> Bool {
        get(key.name) != nil
    }
}
