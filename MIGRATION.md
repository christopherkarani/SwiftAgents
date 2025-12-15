# Migration Guide: Server Compatibility Update

This guide helps you migrate from the pre-server-compatibility version of SwiftAgents to the new cross-platform version.

## Breaking Changes Summary

### 1. Logging API Migration

**Before (os.Logger):**
```swift
import os

// Old API - Apple platforms only
Logger.agents.info("Starting agent")
Logger.memory.error("Failed: \(error, privacy: .private)")
```

**After (swift-log):**
```swift
import SwiftAgents

// Bootstrap logging once at app startup
Log.bootstrap()  // Required!

// New API - cross-platform
Log.agents.info("Starting agent")
Log.memory.error("Failed: \(error.localizedDescription)")
```

**Key Changes:**
- `Logger.*` → `Log.*`
- Must call `Log.bootstrap()` once at application startup
- No `privacy:` parameter support (swift-log limitation)
- Log levels: `.trace`, `.debug`, `.info`, `.notice`, `.warning`, `.error`, `.critical`

**Migration Steps:**
1. Add `Log.bootstrap()` to your app initialization code
2. Find and replace all `Logger.` with `Log.`
3. Remove all `privacy: .private` or `privacy: .public` parameters from log statements

### 2. SwiftAgentsUI Module Removed

**Before:**
```swift
import SwiftAgents
import SwiftAgentsUI  // ❌ No longer available

// SwiftUI components from SwiftAgentsUI
```

**After:**
```swift
import SwiftAgents

// Build custom SwiftUI views using SwiftAgents directly
// See README SwiftUI Integration section for examples
```

**Why?** SwiftAgentsUI was Apple-platform-specific and out of scope for the server compatibility goal. The core SwiftAgents framework now works on Linux servers.

**Migration Steps:**
1. Remove `SwiftAgentsUI` from your Package.swift dependencies
2. Copy any SwiftAgentsUI components you were using into your own codebase
3. Build custom views using SwiftAgents agent APIs

### 3. SwiftDataMemory Changes

**Before:**
```swift
let memory = SwiftDataMemory(
    modelContainer: container,
    conversationId: "user_123"
)
```

**After (Apple platforms only):**
```swift
#if canImport(SwiftData)
let backend = try SwiftDataBackend.persistent()
let memory = PersistentMemory(
    backend: backend,
    conversationId: "user_123"
)
#endif
```

**For cross-platform code:**
```swift
// Use InMemoryBackend for ephemeral storage on all platforms
let backend = InMemoryBackend()
let memory = PersistentMemory(
    backend: backend,
    conversationId: "user_123"
)
```

**Migration Steps:**
1. Replace direct `SwiftDataMemory` usage with `PersistentMemory` wrapper
2. Use `SwiftDataBackend` on Apple platforms
3. Use `InMemoryBackend` or implement custom backend for Linux

### 4. Memory Merge Strategy Naming

**Before:**
```swift
// Ambiguous naming caused conflicts
MergeStrategy.interleave
```

**After:**
```swift
// Explicit type-specific strategies
MemoryMergeStrategy.interleave  // For memory systems
ResultMergeStrategy.latest      // For agent results
```

**Migration Steps:**
1. Check any code using `MergeStrategy` enums
2. Update to use the specific strategy types

## New Features

### 1. Pluggable Memory Backends

You can now implement custom memory backends for databases:

```swift
public actor PostgreSQLBackend: PersistentMemoryBackend {
    private let pool: PostgresConnectionPool

    public init(connectionString: String) async throws {
        self.pool = try await PostgresConnectionPool(connectionString)
    }

    public func store(_ message: MemoryMessage, conversationId: String) async throws {
        try await pool.execute(
            "INSERT INTO messages (id, conversation_id, role, content) VALUES ($1, $2, $3, $4)",
            [message.id, conversationId, message.role.rawValue, message.content]
        )
    }

    public func fetchMessages(conversationId: String) async throws -> [MemoryMessage] {
        let rows = try await pool.query(
            "SELECT * FROM messages WHERE conversation_id = $1 ORDER BY created_at ASC",
            [conversationId]
        )
        return rows.map { /* convert row to MemoryMessage */ }
    }

    // Implement remaining PersistentMemoryBackend methods...
}

// Use with PersistentMemory
let backend = try await PostgreSQLBackend(connectionString: "postgres://...")
let memory = PersistentMemory(backend: backend, conversationId: "user_123")
```

### 2. Server-Side Summarization

Use any LLM for memory summarization (not just Foundation Models):

```swift
let summarizer = InferenceProviderSummarizer.conversationSummarizer(
    provider: myServerLLM,
    maxTokens: 500
)

let summaryMemory = SummaryMemory(
    maxTokens: 4000,
    summaryThreshold: 3000,
    summarizer: summarizer
)
```

### 3. Cross-Platform Tracing

```swift
// Apple platforms - OSLog with privacy
#if canImport(os)
let tracer = OSLogTracer(subsystem: "com.myapp", category: "agents")
#else
// Linux - swift-log
let tracer = SwiftLogTracer.production()
#endif

agent.configuration.tracer = tracer
```

## Platform Requirements Update

**Before:** iOS 26+, macOS 26+ (incorrect placeholder values)

**After:**
- **Apple Platforms:** iOS 17+, macOS 14+, watchOS 10+, tvOS 17+, visionOS 1+
- **Linux:** Ubuntu 22.04+ with Swift 6.2

## Privacy and Security Considerations

### No Privacy Annotations in swift-log

Unlike `os.Logger`, swift-log doesn't support `privacy:` parameters. To protect sensitive data:

**Best Practices:**
1. Don't log user data, PII, or credentials directly
2. Configure log handlers to redact sensitive information:
   ```swift
   Log.bootstrap { label in
       var handler = StreamLogHandler.standardOutput(label: label)
       handler.logLevel = .info  // Reduce verbosity in production
       return handler
   }
   ```
3. Use error codes instead of detailed error messages in production
4. For Apple platforms with sensitive data, use OSLogTracer wrapped in `#if canImport(os)`

## Testing Changes

### Mock Implementations

All memory backends are now actors, so update your test mocks:

```swift
// Before
class MockMemory: AgentMemory { ... }

// After
actor MockMemory: AgentMemory {
    // Methods must be async
    func add(_ message: MemoryMessage) async { ... }
}
```

## Deployment

### Linux Server Deployment

SwiftAgents now works on Linux servers:

```bash
# Install Swift 6.2 on Ubuntu
curl -L https://swiftlang.github.io/swiftly/swiftly-install.sh | bash
swiftly install 6.2

# Build your server application
swift build -c release

# Run with custom logging
./.build/release/YourServer
```

### Custom Backend Examples

See `Sources/SwiftAgents/Memory/PersistentMemoryBackend.swift` for PostgreSQL implementation example.

## Troubleshooting

### "Logger.agents not found"

**Solution:** Replace `Logger.*` with `Log.*` and call `Log.bootstrap()` at startup.

### "privacy: .private" compile error

**Solution:** Remove all `privacy:` parameters from log statements. swift-log doesn't support privacy annotations.

### "SwiftAgentsUI module not found"

**Solution:** Remove SwiftAgentsUI from dependencies. Build custom UI components.

### "SwiftDataMemory not available on Linux"

**Solution:** Use `PersistentMemory` with `InMemoryBackend` or implement a database backend.

## Questions?

- **Documentation:** [Full documentation](https://chriskarani.github.io/SwiftAgents/)
- **Issues:** [GitHub Issues](https://github.com/chriskarani/SwiftAgents/issues)
- **Discussions:** [GitHub Discussions](https://github.com/chriskarani/SwiftAgents/discussions)
