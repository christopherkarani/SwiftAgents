// ResponseTrackerTests.swift
// SwarmTests
//
// Comprehensive unit tests for ResponseTracker covering bounded storage,
// session isolation, history management, and all public API methods.
//
// Tests are split across multiple files for maintainability:
// - ResponseTrackerTests+BasicTests.swift: Basic record/retrieve and session isolation
// - ResponseTrackerTests+HistoryTests.swift: History limiting, ordering, and counts
// - ResponseTrackerTests+ConcurrencyTests.swift: Concurrent access and clear operations
// - ResponseTrackerTests+CleanupTests.swift: Session cleanup and metadata

import Foundation
@testable import Swarm
import Testing

// This file serves as the main entry point for ResponseTracker tests.
// All test implementations are in the extension files listed above.
