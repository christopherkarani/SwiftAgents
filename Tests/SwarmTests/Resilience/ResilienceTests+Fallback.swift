// ResilienceTests+Fallback.swift
// Swarm Framework
//
// Tests for FallbackChain resilience component using Swift Testing framework.

import Foundation
@testable import Swarm
import Testing

// MARK: - FallbackChain Tests

@Suite("FallbackChain Tests")
struct FallbackChainTests {
    // MARK: - Success Tests

    @Test("First attempt succeeds without fallback")
    func firstAttemptSucceeds() async throws {
        let primaryFlag = TestFlag()
        let fallbackFlag = TestFlag()

        let result = try await FallbackChain<String>()
            .attempt(name: "Primary") {
                await primaryFlag.set(true)
                return "primary-result"
            }
            .attempt(name: "Fallback") {
                await fallbackFlag.set(true)
                return "fallback-result"
            }
            .execute()

        #expect(result == "primary-result")
        #expect(await primaryFlag.get() == true)
        #expect(await fallbackFlag.get() == false)
    }

    @Test("Immediate success with single step")
    func immediateSingleStepSuccess() async throws {
        let chain = FallbackChain<Int>()
            .attempt(name: "Only") {
                42
            }

        let result = try await chain.execute()
        #expect(result == 42)
    }

    // MARK: - Fallback Tests

    @Test("Fallback to second option on failure")
    func fallbackOnFailure() async throws {
        let primaryFlag = TestFlag()
        let secondaryFlag = TestFlag()

        let result = try await FallbackChain<String>()
            .attempt(name: "Primary") {
                await primaryFlag.set(true)
                throw TestError.network
            }
            .attempt(name: "Secondary") {
                await secondaryFlag.set(true)
                return "secondary-success"
            }
            .execute()

        #expect(result == "secondary-success")
        #expect(await primaryFlag.get() == true)
        #expect(await secondaryFlag.get() == true)
    }

    @Test("Multiple fallbacks cascade correctly")
    func multipleFallbacksCascade() async throws {
        let recorder = TestRecorder<String>()

        let result = try await FallbackChain<String>()
            .attempt(name: "First") {
                await recorder.append("first")
                throw TestError.network
            }
            .attempt(name: "Second") {
                await recorder.append("second")
                throw TestError.timeout
            }
            .attempt(name: "Third") {
                await recorder.append("third")
                return "third-success"
            }
            .execute()

        #expect(result == "third-success")
        #expect(await recorder.getAll() == ["first", "second", "third"])
    }

    // MARK: - All Fallbacks Fail Tests

    @Test("All fallbacks fail throws ResilienceError.allFallbacksFailed")
    func allFallbacksFail() async throws {
        do {
            _ = try await FallbackChain<String>()
                .attempt(name: "First") {
                    throw TestError.network
                }
                .attempt(name: "Second") {
                    throw TestError.timeout
                }
                .execute()

            Issue.record("Should have thrown allFallbacksFailed")
        } catch let error as ResilienceError {
            if case let .allFallbacksFailed(errors) = error {
                #expect(errors.count == 2)
                #expect(errors[0].contains("First"))
                #expect(errors[1].contains("Second"))
            } else {
                Issue.record("Expected allFallbacksFailed, got \(error)")
            }
        }
    }

    @Test("Empty chain throws allFallbacksFailed")
    func emptyChainFails() async throws {
        let chain = FallbackChain<String>()

        do {
            _ = try await chain.execute()
            Issue.record("Should have thrown error")
        } catch let error as ResilienceError {
            if case let .allFallbacksFailed(errors) = error {
                #expect(errors.count == 1)
                #expect(errors[0].contains("No steps configured"))
            } else {
                Issue.record("Expected allFallbacksFailed")
            }
        }
    }

    // MARK: - Final Fallback Tests

    @Test("Final fallback always succeeds with value")
    func finalFallbackValue() async throws {
        let result = try await FallbackChain<String>()
            .attempt(name: "Primary") {
                throw TestError.network
            }
            .attempt(name: "Secondary") {
                throw TestError.timeout
            }
            .fallback(name: "Default", "fallback-value")
            .execute()

        #expect(result == "fallback-value")
    }

    @Test("Final fallback always succeeds with operation")
    func finalFallbackOperation() async throws {
        let flag = TestFlag()

        let result = try await FallbackChain<Int>()
            .attempt(name: "Primary") {
                throw TestError.network
            }
            .fallback(name: "Cache") {
                await flag.set(true)
                return 999
            }
            .execute()

        #expect(result == 999)
        #expect(await flag.get() == true)
    }

    // MARK: - executeWithResult Tests

    @Test("executeWithResult returns diagnostic info")
    func executeWithResultDiagnostics() async throws {
        let result = try await FallbackChain<String>()
            .attempt(name: "Primary") {
                throw TestError.network
            }
            .attempt(name: "Secondary") {
                throw TestError.timeout
            }
            .attempt(name: "Tertiary") {
                "success"
            }
            .executeWithResult()

        #expect(result.output == "success")
        #expect(result.stepName == "Tertiary")
        #expect(result.stepIndex == 2)
        #expect(result.totalAttempts == 3)
        #expect(result.errors.count == 2)
    }

    @Test("executeWithResult captures error details")
    func executeWithResultErrorDetails() async throws {
        let result = try await FallbackChain<String>()
            .attempt(name: "First") {
                throw TestError.network
            }
            .attempt(name: "Second") {
                "ok"
            }
            .executeWithResult()

        #expect(result.errors.count == 1)
        #expect(result.errors[0].stepName == "First")
        #expect(result.errors[0].stepIndex == 0)
    }

    @Test("executeWithResult with immediate success has no errors")
    func executeWithResultNoErrors() async throws {
        let result = try await FallbackChain<String>()
            .attempt(name: "Only") {
                "success"
            }
            .executeWithResult()

        #expect(result.totalAttempts == 1)
        #expect(result.errors.isEmpty)
    }

    // MARK: - Conditional Fallback Tests

    @Test("Conditional fallback with attemptIf")
    func conditionalFallbackTrue() async throws {
        let shouldUseSecondary = true // Use let for constants

        let result = try await FallbackChain<String>()
            .attempt(name: "Primary") {
                throw TestError.network
            }
            .attemptIf(
                name: "Conditional",
                condition: { shouldUseSecondary },
                { "conditional-success" }
            )
            .execute()

        #expect(result == "conditional-success")
    }

    @Test("Conditional fallback skipped when condition false")
    func conditionalFallbackFalse() async throws {
        let shouldSkip = false // Use let for constants

        let result = try await FallbackChain<String>()
            .attempt(name: "Primary") {
                throw TestError.network
            }
            .attemptIf(
                name: "Conditional",
                condition: { shouldSkip },
                {
                    Issue.record("This should not be called")
                    return "should-not-happen"
                }
            )
            .fallback(name: "Final", "default")
            .execute()

        #expect(result == "default")
    }

    // MARK: - onFailure Callback Tests

    @Test("onFailure callback invoked for each failure")
    func onFailureCallback() async throws {
        let recorder = TestRecorder<String>()

        _ = try await FallbackChain<String>()
            .attempt(name: "First") {
                throw TestError.network
            }
            .attempt(name: "Second") {
                throw TestError.timeout
            }
            .attempt(name: "Third") {
                "success"
            }
            .onFailure { stepName, _ in
                await recorder.append(stepName)
            }
            .execute()

        #expect(await recorder.getAll() == ["First", "Second"])
    }

    @Test("onFailure not called on success")
    func onFailureNotCalledOnSuccess() async throws {
        let flag = TestFlag()

        _ = try await FallbackChain<String>()
            .attempt(name: "Primary") {
                "success"
            }
            .onFailure { _, _ in
                await flag.set(true)
            }
            .execute()

        #expect(await flag.get() == false)
    }

    // MARK: - Static Convenience Tests

    @Test("Static from constructor creates chain")
    func staticFromConstructor() async throws {
        let result = try await FallbackChain.from(
            (name: "First", operation: {
                throw TestError.network
            }),
            (name: "Second", operation: {
                "second-result"
            })
        ).execute()

        #expect(result == "second-result")
    }
}
