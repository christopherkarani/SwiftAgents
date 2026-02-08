// ObservabilityTests.swift
// Swarm Framework
//
// Comprehensive tests for Phase 4 Observability components.
// Tests TraceEvent, ConsoleTracer, and MetricsCollector functionality.
//
// Tests are organized into extension files:
// - ObservabilityTests+TraceEvents.swift: TraceEvent, SourceLocation, and ErrorInfo tests
// - ObservabilityTests+Tracers.swift: ConsoleTracer and PrettyConsoleTracer tests
// - ObservabilityTests+Metrics.swift: MetricsCollector and JSONMetricsReporter tests

import Foundation
@testable import Swarm
import Testing
