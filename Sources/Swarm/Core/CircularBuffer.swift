// CircularBuffer.swift
// Swarm Framework
//
// Fixed-size circular buffer for bounded memory management.

import Foundation

// MARK: - CircularBuffer

/// A fixed-size circular buffer that prevents unbounded memory growth
///
/// When the buffer reaches capacity, new elements overwrite the oldest elements.
/// This is essential for long-running processes where metrics/data accumulate.
///
/// Thread Safety:
/// - The buffer itself is a value type with copy-on-write semantics
/// - For concurrent access, wrap in an actor or use with actor isolation
///
/// Usage:
/// ```swift
/// var buffer = CircularBuffer<TimeInterval>(capacity: 1000)
/// buffer.append(1.5)
/// buffer.append(2.0)
/// let allValues = buffer.elements  // Returns in order: oldest to newest
/// ```
public struct CircularBuffer<Element: Sendable>: Sendable {
    // MARK: Public

    /// The maximum number of elements this buffer can hold
    public let capacity: Int

    /// Returns all elements in order from oldest to newest
    ///
    /// - Returns: Array of elements in chronological order
    /// - Complexity: O(n) where n is the number of stored elements
    public var elements: [Element] {
        guard !storage.isEmpty else { return [] }

        if storage.count < capacity {
            // Buffer not yet full - elements are in order
            return storage
        }

        // Buffer is full - head points to oldest element
        // Return elements from head to end, then start to head
        return Array(storage[head...]) + Array(storage[..<head])
    }

    /// The number of elements currently in the buffer
    ///
    /// Note: This is the actual count, not the total appended.
    /// Maximum value is `capacity`.
    public var count: Int {
        Swift.min(_count, capacity)
    }

    /// The total number of elements ever appended
    ///
    /// This can exceed capacity and represents the full history count.
    public var totalAppended: Int {
        _count
    }

    /// Whether the buffer contains no elements
    public var isEmpty: Bool {
        storage.isEmpty
    }

    /// Whether the buffer has reached capacity
    public var isFull: Bool {
        storage.count >= capacity
    }

    /// The most recently added element, if any
    public var last: Element? {
        guard !storage.isEmpty else { return nil }
        let lastIndex = head == 0 ? storage.count - 1 : head - 1
        return storage[lastIndex]
    }

    /// The oldest element in the buffer, if any
    public var first: Element? {
        guard !storage.isEmpty else { return nil }
        if storage.count < capacity {
            return storage.first
        }
        return storage[head]
    }

    /// Creates a new circular buffer with the specified capacity
    ///
    /// - Parameter capacity: Maximum number of elements (must be > 0)
    /// - Precondition: capacity must be greater than 0
    public init(capacity: Int) {
        precondition(capacity > 0, "CircularBuffer capacity must be positive")
        self.capacity = capacity
        storage = []
        storage.reserveCapacity(capacity)
    }

    /// Appends an element to the buffer
    ///
    /// If the buffer is at capacity, the oldest element is overwritten.
    ///
    /// - Parameter element: The element to append
    /// - Complexity: O(1)
    public mutating func append(_ element: Element) {
        if storage.count < capacity {
            storage.append(element)
        } else {
            storage[head] = element
        }
        head = (head + 1) % capacity
        _count += 1
    }

    /// Removes all elements from the buffer
    public mutating func removeAll() {
        storage.removeAll()
        head = 0
        _count = 0
    }

    // MARK: Private

    private var storage: [Element]
    private var head: Int = 0
    private var _count: Int = 0
}

// MARK: Collection

extension CircularBuffer: Collection {
    public var startIndex: Int { 0 }
    public var endIndex: Int { count }

    public func index(after i: Int) -> Int {
        i + 1
    }

    public subscript(position: Int) -> Element {
        precondition(position >= 0 && position < count, "Index out of bounds")
        if storage.count < capacity {
            return storage[position]
        }
        let actualIndex = (head + position) % capacity
        return storage[actualIndex]
    }
}

// MARK: ExpressibleByArrayLiteral

extension CircularBuffer: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Element...) {
        self.init(capacity: Swift.max(elements.count, 1))
        for element in elements {
            append(element)
        }
    }
}

// MARK: CustomStringConvertible

extension CircularBuffer: CustomStringConvertible {
    public var description: String {
        "CircularBuffer(count: \(count), capacity: \(capacity), elements: \(elements))"
    }
}

// MARK: Equatable

extension CircularBuffer: Equatable where Element: Equatable {
    public static func == (lhs: CircularBuffer, rhs: CircularBuffer) -> Bool {
        lhs.elements == rhs.elements
    }
}

// MARK: Hashable

extension CircularBuffer: Hashable where Element: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(elements)
    }
}
