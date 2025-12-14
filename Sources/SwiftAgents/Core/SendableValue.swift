// SendableValue.swift
// SwiftAgents Framework
//
// A type-safe, Sendable container for dynamic values used in tool arguments and results.

import Foundation

/// A type-safe, Sendable container for dynamic values used in tool arguments and results.
/// Replaces `[String: Any]` which cannot conform to `Sendable`.
public enum SendableValue: Sendable, Equatable, Hashable, Codable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([SendableValue])
    case dictionary([String: SendableValue])

    // MARK: - Convenience Initializers

    public init(_ value: Bool) { self = .bool(value) }
    public init(_ value: Int) { self = .int(value) }
    public init(_ value: Double) { self = .double(value) }
    public init(_ value: String) { self = .string(value) }
    public init(_ value: [SendableValue]) { self = .array(value) }
    public init(_ value: [String: SendableValue]) { self = .dictionary(value) }

    // MARK: - Type-Safe Accessors

    /// Returns the Bool value if this is a `.bool`, otherwise nil.
    public var boolValue: Bool? {
        guard case .bool(let v) = self else { return nil }
        return v
    }

    /// Returns the Int value if this is an `.int`, otherwise nil.
    public var intValue: Int? {
        guard case .int(let v) = self else { return nil }
        return v
    }

    /// Returns the Double value if this is a `.double` or `.int`, otherwise nil.
    public var doubleValue: Double? {
        switch self {
        case .double(let v): return v
        case .int(let v): return Double(v)
        default: return nil
        }
    }

    /// Returns the String value if this is a `.string`, otherwise nil.
    public var stringValue: String? {
        guard case .string(let v) = self else { return nil }
        return v
    }

    /// Returns the array if this is an `.array`, otherwise nil.
    public var arrayValue: [SendableValue]? {
        guard case .array(let v) = self else { return nil }
        return v
    }

    /// Returns the dictionary if this is a `.dictionary`, otherwise nil.
    public var dictionaryValue: [String: SendableValue]? {
        guard case .dictionary(let v) = self else { return nil }
        return v
    }

    /// Returns true if this is `.null`.
    public var isNull: Bool {
        guard case .null = self else { return false }
        return true
    }

    // MARK: - Subscript Access

    /// Access dictionary values by key.
    public subscript(key: String) -> SendableValue? {
        guard case .dictionary(let dict) = self else { return nil }
        return dict[key]
    }

    /// Access array values by index.
    public subscript(index: Int) -> SendableValue? {
        guard case .array(let arr) = self, index >= 0, index < arr.count else { return nil }
        return arr[index]
    }
}

// MARK: - ExpressibleBy Literals

extension SendableValue: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) { self = .null }
}

extension SendableValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) { self = .bool(value) }
}

extension SendableValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) { self = .int(value) }
}

extension SendableValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) { self = .double(value) }
}

extension SendableValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) { self = .string(value) }
}

extension SendableValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: SendableValue...) { self = .array(elements) }
}

extension SendableValue: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, SendableValue)...) {
        self = .dictionary(Dictionary(uniqueKeysWithValues: elements))
    }
}

// MARK: - CustomStringConvertible

extension SendableValue: CustomStringConvertible {
    public var description: String {
        switch self {
        case .null: return "null"
        case .bool(let v): return String(v)
        case .int(let v): return String(v)
        case .double(let v): return String(v)
        case .string(let v): return "\"\(v)\""
        case .array(let v): return "[\(v.map(\.description).joined(separator: ", "))]"
        case .dictionary(let v):
            let pairs = v.map { "\"\($0)\": \($1.description)" }.joined(separator: ", ")
            return "{\(pairs)}"
        }
    }
}

// MARK: - CustomDebugStringConvertible

extension SendableValue: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .null: return "SendableValue.null"
        case .bool(let v): return "SendableValue.bool(\(v))"
        case .int(let v): return "SendableValue.int(\(v))"
        case .double(let v): return "SendableValue.double(\(v))"
        case .string(let v): return "SendableValue.string(\"\(v)\")"
        case .array(let v): return "SendableValue.array(\(v.map(\.debugDescription)))"
        case .dictionary(let v): return "SendableValue.dictionary(\(v))"
        }
    }
}

// MARK: - Encodable Type Conversion

extension SendableValue {
    /// Error thrown when encoding/decoding fails.
    public enum ConversionError: Error, LocalizedError {
        case encodingFailed(String)
        case decodingFailed(String)
        case unsupportedType(String)

        public var errorDescription: String? {
            switch self {
            case .encodingFailed(let message):
                return "Failed to encode value: \(message)"
            case .decodingFailed(let message):
                return "Failed to decode value: \(message)"
            case .unsupportedType(let type):
                return "Unsupported type for conversion: \(type)"
            }
        }
    }

    /// Creates a SendableValue by encoding an Encodable value.
    ///
    /// This initializer converts any `Encodable` type to a `SendableValue`,
    /// enabling type-safe tools to return their results through the standard
    /// `Tool` interface.
    ///
    /// - Parameter value: The value to encode.
    /// - Throws: `ConversionError.encodingFailed` if encoding fails.
    ///
    /// Example:
    /// ```swift
    /// struct UserInfo: Codable {
    ///     let name: String
    ///     let age: Int
    /// }
    ///
    /// let user = UserInfo(name: "Alice", age: 30)
    /// let sendable = try SendableValue(encoding: user)
    /// // Result: .dictionary(["name": .string("Alice"), "age": .int(30)])
    /// ```
    public init<T: Encodable>(encoding value: T) throws {
        // Handle primitive types directly for efficiency
        if let boolValue = value as? Bool {
            self = .bool(boolValue)
            return
        }
        if let intValue = value as? Int {
            self = .int(intValue)
            return
        }
        if let doubleValue = value as? Double {
            self = .double(doubleValue)
            return
        }
        if let stringValue = value as? String {
            self = .string(stringValue)
            return
        }

        // Handle arrays of SendableValue
        if let arrayValue = value as? [SendableValue] {
            self = .array(arrayValue)
            return
        }

        // Handle dictionaries of SendableValue
        if let dictValue = value as? [String: SendableValue] {
            self = .dictionary(dictValue)
            return
        }

        // For complex types, use JSON encoding as an intermediate format
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        do {
            let data = try encoder.encode(value)
            let jsonObject = try JSONSerialization.jsonObject(with: data)
            self = try Self.fromJSONObject(jsonObject)
        } catch {
            throw ConversionError.encodingFailed(String(describing: error))
        }
    }

    /// Decodes this SendableValue to a Decodable type.
    ///
    /// - Returns: The decoded value.
    /// - Throws: `ConversionError.decodingFailed` if decoding fails.
    ///
    /// Example:
    /// ```swift
    /// let sendable: SendableValue = .dictionary([
    ///     "name": .string("Alice"),
    ///     "age": .int(30)
    /// ])
    ///
    /// let user: UserInfo = try sendable.decode()
    /// // Result: UserInfo(name: "Alice", age: 30)
    /// ```
    public func decode<T: Decodable>() throws -> T {
        // Handle primitive types directly
        if T.self == Bool.self, let value = boolValue {
            return value as! T
        }
        if T.self == Int.self, let value = intValue {
            return value as! T
        }
        if T.self == Double.self, let value = doubleValue {
            return value as! T
        }
        if T.self == String.self, let value = stringValue {
            return value as! T
        }

        // For complex types, use JSON decoding as an intermediate format
        let jsonObject = toJSONObject()
        do {
            let data = try JSONSerialization.data(withJSONObject: jsonObject)
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            throw ConversionError.decodingFailed(String(describing: error))
        }
    }

    /// Converts a JSON object to SendableValue.
    private static func fromJSONObject(_ object: Any) throws -> SendableValue {
        switch object {
        case is NSNull:
            return .null
        case let bool as Bool:
            return .bool(bool)
        case let int as Int:
            return .int(int)
        case let double as Double:
            // Check if it's actually an integer stored as double
            if double.truncatingRemainder(dividingBy: 1) == 0,
               double >= Double(Int.min), double <= Double(Int.max) {
                return .int(Int(double))
            }
            return .double(double)
        case let string as String:
            return .string(string)
        case let array as [Any]:
            return .array(try array.map { try fromJSONObject($0) })
        case let dict as [String: Any]:
            var result: [String: SendableValue] = [:]
            for (key, value) in dict {
                result[key] = try fromJSONObject(value)
            }
            return .dictionary(result)
        default:
            throw ConversionError.unsupportedType(String(describing: type(of: object)))
        }
    }

    /// Converts this SendableValue to a JSON-compatible object.
    private func toJSONObject() -> Any {
        switch self {
        case .null:
            return NSNull()
        case .bool(let v):
            return v
        case .int(let v):
            return v
        case .double(let v):
            return v
        case .string(let v):
            return v
        case .array(let v):
            return v.map { $0.toJSONObject() }
        case .dictionary(let v):
            var result: [String: Any] = [:]
            for (key, value) in v {
                result[key] = value.toJSONObject()
            }
            return result
        }
    }
}
