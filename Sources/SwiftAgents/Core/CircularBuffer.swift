//
//  CircularBuffer.swift
//  SwiftAgents
//
//  Created as part of audit remediation - Phase 1
//

import Foundation

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
    private var storage: [Element]
    private var head: Int = 0
    private var _count: Int = 0

    /// The maximum number of elements this buffer can hold
    public let capacity: Int

    /// Creates a new circular buffer with the specified capacity
    ///
    /// - Parameter capacity: Maximum number of elements (must be > 0)
    /// - Precondition: capacity must be greater than 0
    public init(capacity: Int) {
        precondition(capacity > 0, "CircularBuffer capacity must be positive")
        self.capacity = capacity
        self.storage = []
        self.storage.reserveCapacity(capacity)
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

    /// Returns all elements in order from oldest to newest
    ///
    /// This property allocates a new array. For iteration without allocation,
    /// use `forEach(_:)` or the Collection protocol (iterate directly).
    ///
    /// - Returns: Array of elements in chronological order (oldest first)
    /// - Complexity: O(n) time and space, where n is the number of stored elements
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

    /// Calls the given closure on each element in order from oldest to newest
    ///
    /// Use this method to iterate without allocating an array.
    /// More efficient than `elements` for read-only traversal.
    ///
    /// - Parameter body: Closure to execute for each element
    /// - Complexity: O(n) where n is the number of stored elements
    public func forEach(_ body: (Element) throws -> Void) rethrows {
        if storage.count < capacity {
            // Buffer not yet full - elements are in order
            try storage.forEach(body)
        } else {
            // Buffer is full - iterate from head to end, then start to head
            for i in head..<storage.count {
                try body(storage[i])
            }
            for i in 0..<head {
                try body(storage[i])
            }
        }
    }

    /// The number of elements currently in the buffer
    ///
    /// This is the actual count of elements stored, capped at `capacity`.
    /// When the buffer is full and overwrites occur, this remains equal to `capacity`.
    /// For the total number of elements ever appended (including overwritten ones),
    /// use `totalAppended`.
    ///
    /// - Returns: Current element count, in range [0, capacity]
    public var count: Int {
        Swift.min(_count, capacity)
    }

    /// The total number of elements ever appended to the buffer
    ///
    /// This value grows monotonically and is not capped by capacity.
    /// It represents the complete history of appends, even for elements
    /// that were overwritten. Use this to track cumulative statistics
    /// or to distinguish between buffers with different operational histories.
    ///
    /// Relationship to count:
    /// - When `totalAppended <= capacity`: `count == totalAppended`
    /// - When `totalAppended > capacity`: `count == capacity`
    ///
    /// - Returns: Total number of elements appended since initialization
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

    /// Removes all elements from the buffer
    public mutating func removeAll() {
        storage.removeAll()
        head = 0
        _count = 0
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
}

// MARK: - Collection Conformance

extension CircularBuffer: Collection {
    /// The starting index of the buffer (always 0)
    public var startIndex: Int { 0 }

    /// The ending index of the buffer (equal to count)
    public var endIndex: Int { count }

    /// Returns the next index after the given position
    ///
    /// - Parameter i: Current position
    /// - Returns: Position + 1
    public func index(after i: Int) -> Int {
        i + 1
    }

    /// Accesses the element at the specified position
    ///
    /// Indices are ordered from oldest (0) to newest (count - 1).
    /// Index 0 always refers to the oldest element in the buffer.
    /// When the buffer is full and overwrites occur, the indexing automatically
    /// adjusts to maintain this invariant.
    ///
    /// - Parameter position: The position to access (0 = oldest, count-1 = newest)
    /// - Returns: The element at the specified position
    /// - Precondition: position must be in range [0, count)
    /// - Complexity: O(1)
    public subscript(position: Int) -> Element {
        precondition(position >= 0 && position < count, "Index out of bounds")
        if storage.count < capacity {
            return storage[position]
        }
        let actualIndex = (head + position) % capacity
        return storage[actualIndex]
    }
}

// MARK: - ExpressibleByArrayLiteral

extension CircularBuffer: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Element...) {
        self.init(capacity: Swift.max(elements.count, 1))
        for element in elements {
            append(element)
        }
    }
}

// MARK: - CustomStringConvertible

extension CircularBuffer: CustomStringConvertible {
    public var description: String {
        "CircularBuffer(count: \(count), capacity: \(capacity), elements: \(elements))"
    }
}

// MARK: - Equatable

extension CircularBuffer: Equatable where Element: Equatable {
    /// Compares two circular buffers for equality
    ///
    /// Two buffers are equal if they contain the same elements in the same order,
    /// regardless of internal storage layout. This comparison is element-wise to avoid
    /// allocating arrays for each comparison.
    ///
    /// - Complexity: O(n) where n is the number of elements
    public static func == (lhs: CircularBuffer, rhs: CircularBuffer) -> Bool {
        guard lhs.count == rhs.count else { return false }

        for i in 0..<lhs.count {
            if lhs[i] != rhs[i] {
                return false
            }
        }
        return true
    }
}

// MARK: - Hashable

extension CircularBuffer: Hashable where Element: Hashable {
    /// Hashes the buffer by combining all elements in order
    ///
    /// The hash is computed element-wise (oldest to newest) without allocating
    /// an intermediate array, making it efficient even for large buffers.
    ///
    /// - Parameter hasher: The hasher to combine values into
    /// - Complexity: O(n) where n is the number of elements
    public func hash(into hasher: inout Hasher) {
        hasher.combine(count)
        forEach { element in
            hasher.combine(element)
        }
    }
}
