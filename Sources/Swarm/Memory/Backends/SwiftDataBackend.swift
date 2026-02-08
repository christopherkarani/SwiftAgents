// SwiftDataBackend.swift
// Swarm Framework
//
// SwiftData implementation of PersistentMemoryBackend.

#if canImport(SwiftData)
    import Foundation
    import SwiftData

    /// SwiftData implementation of `PersistentMemoryBackend`.
    ///
    /// Available only on Apple platforms (iOS 17+, macOS 14+).
    /// Uses the existing `PersistedMessage` model for storage.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let backend = try SwiftDataBackend.persistent()
    /// let memory = PersistentMemory(backend: backend)
    ///
    /// await memory.add(.user("Hello"))
    /// ```
    @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
    public actor SwiftDataBackend: PersistentMemoryBackend {
        // MARK: Public

        /// Creates a backend with an existing ModelContainer.
        ///
        /// - Parameter modelContainer: The SwiftData model container to use.
        public init(modelContainer: ModelContainer) {
            self.modelContainer = modelContainer
            modelContext = ModelContext(modelContainer)
        }

        /// Creates an in-memory backend for testing.
        ///
        /// Data is not persisted to disk.
        ///
        /// - Returns: A new SwiftDataBackend with in-memory storage.
        public static func inMemory() throws -> SwiftDataBackend {
            let container = try PersistedMessage.makeContainer(inMemory: true)
            return SwiftDataBackend(modelContainer: container)
        }

        /// Creates a persistent backend with disk storage.
        ///
        /// - Returns: A new SwiftDataBackend with persistent storage.
        public static func persistent() throws -> SwiftDataBackend {
            let container = try PersistedMessage.makeContainer(inMemory: false)
            return SwiftDataBackend(modelContainer: container)
        }

        // MARK: - PersistentMemoryBackend Protocol

        public func store(_ message: MemoryMessage, conversationId: String) async throws {
            let persisted = PersistedMessage(from: message, conversationId: conversationId)
            modelContext.insert(persisted)
            try modelContext.save()
            Log.memory.debug("Stored message for conversation: \(conversationId)")
        }

        public func fetchMessages(conversationId: String) async throws -> [MemoryMessage] {
            let descriptor = PersistedMessage.fetchDescriptor(forConversation: conversationId)
            let persisted = try modelContext.fetch(descriptor)
            return persisted.compactMap { $0.toMemoryMessage() }
        }

        public func fetchRecentMessages(conversationId: String, limit: Int) async throws -> [MemoryMessage] {
            let descriptor = PersistedMessage.fetchDescriptor(
                forConversation: conversationId,
                limit: limit
            )
            let persisted = try modelContext.fetch(descriptor)
            // Reverse because fetch was in descending order
            return persisted.reversed().compactMap { $0.toMemoryMessage() }
        }

        public func deleteMessages(conversationId: String) async throws {
            let descriptor = PersistedMessage.fetchDescriptor(forConversation: conversationId)
            let messages = try modelContext.fetch(descriptor)
            for message in messages {
                modelContext.delete(message)
            }
            try modelContext.save()
            Log.memory.debug("Deleted \(messages.count) messages for conversation: \(conversationId)")
        }

        public func messageCount(conversationId: String) async throws -> Int {
            let descriptor = PersistedMessage.fetchDescriptor(forConversation: conversationId)
            return try modelContext.fetchCount(descriptor)
        }

        public func allConversationIds() async throws -> [String] {
            let descriptor = PersistedMessage.allConversationsDescriptor
            let messages = try modelContext.fetch(descriptor)
            return Array(Set(messages.map(\.conversationId))).sorted()
        }

        public func storeAll(_ messages: [MemoryMessage], conversationId: String) async throws {
            guard !messages.isEmpty else { return }

            // For small batches (<=100), use single transaction for efficiency
            if messages.count <= 100 {
                for message in messages {
                    let persisted = PersistedMessage(from: message, conversationId: conversationId)
                    modelContext.insert(persisted)
                }
                try modelContext.save()
            } else {
                // For large batches, save in chunks to manage memory pressure
                let batchSize = 100
                var startIndex = messages.startIndex

                while startIndex < messages.endIndex {
                    let endIndex = messages.index(startIndex, offsetBy: batchSize, limitedBy: messages.endIndex) ?? messages.endIndex
                    let chunk = messages[startIndex..<endIndex]

                    for message in chunk {
                        let persisted = PersistedMessage(from: message, conversationId: conversationId)
                        modelContext.insert(persisted)
                    }
                    try modelContext.save()

                    startIndex = endIndex
                }
            }

            Log.memory.debug("Stored \(messages.count) messages for conversation: \(conversationId)")
        }

        public func deleteOldestMessages(conversationId: String, keepRecent: Int) async throws {
            let currentCount = try await messageCount(conversationId: conversationId)
            guard currentCount > keepRecent else { return }

            let deleteCount = currentCount - keepRecent

            // Fetch oldest messages to delete
            var descriptor = FetchDescriptor<PersistedMessage>(
                predicate: #Predicate { $0.conversationId == conversationId },
                sortBy: [SortDescriptor(\.timestamp, order: .forward)]
            )
            descriptor.fetchLimit = deleteCount

            let messagesToDelete = try modelContext.fetch(descriptor)
            for message in messagesToDelete {
                modelContext.delete(message)
            }
            try modelContext.save()
            Log.memory.debug("Deleted \(deleteCount) oldest messages for conversation: \(conversationId)")
        }

        public func deleteLastMessage(conversationId: String) async throws -> MemoryMessage? {
            // O(1) optimized implementation: fetch only the last message with fetchLimit: 1
            var descriptor = FetchDescriptor<PersistedMessage>(
                predicate: #Predicate { $0.conversationId == conversationId },
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            descriptor.fetchLimit = 1

            let messages = try modelContext.fetch(descriptor)
            guard let lastPersisted = messages.first else {
                return nil
            }

            // Convert to MemoryMessage before deletion
            let memoryMessage = lastPersisted.toMemoryMessage()

            // Delete just this one message
            modelContext.delete(lastPersisted)
            try modelContext.save()

            Log.memory.debug("Deleted last message for conversation: \(conversationId)")
            return memoryMessage
        }

        // MARK: Private

        private let modelContainer: ModelContainer
        private let modelContext: ModelContext
    }
#endif
