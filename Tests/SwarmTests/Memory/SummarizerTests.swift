// SummarizerTests.swift
// Swarm Framework
//
// Comprehensive tests for Summarizer protocol and implementations.

import Foundation
@testable import Swarm
import Testing

// MARK: - TruncatingSummarizerTests

@Suite("TruncatingSummarizer Tests")
struct TruncatingSummarizerTests {
    // MARK: - Basic Functionality

    @Test("Shared instance is available")
    func sharedInstanceIsAvailable() async {
        let summarizer = TruncatingSummarizer.shared
        let available = await summarizer.isAvailable
        #expect(available == true)
    }

    @Test("isAvailable returns true")
    func isAvailableReturnsTrue() async {
        let summarizer = TruncatingSummarizer()
        let available = await summarizer.isAvailable
        #expect(available == true)
    }

    @Test("Returns text as-is when within token limit")
    func returnsTextAsIsWhenWithinLimit() async throws {
        let summarizer = TruncatingSummarizer()
        let shortText = "Hello world"

        let result = try await summarizer.summarize(shortText, maxTokens: 1000)

        #expect(result == shortText)
    }

    // MARK: - Truncation at Sentence Boundaries

    @Test("Truncates at sentence boundary (period)")
    func truncatesAtSentenceBoundary() async throws {
        let summarizer = TruncatingSummarizer()
        let text = "First sentence. Second sentence. Third sentence that goes on and on and should be cut off because it exceeds the token limit significantly."

        let result = try await summarizer.summarize(text, maxTokens: 10)

        // Should truncate at last period within limit
        #expect(result.hasSuffix("."))
        #expect(result.count < text.count)
        #expect(result.contains("First sentence."))
    }

    @Test("Truncates at newline when no period found")
    func truncatesAtNewlineWhenNoPeriodFound() async throws {
        let summarizer = TruncatingSummarizer()
        let text = "First line without period\nSecond line also without period\nThird line that continues with lots of extra text to exceed the limit"

        let result = try await summarizer.summarize(text, maxTokens: 10)

        // Should truncate at newline
        #expect(!result.hasSuffix("..."))
        #expect(result.count < text.count)
    }

    // MARK: - Truncation at Word Boundaries

    @Test("Truncates at word boundary with ellipsis when no sentence boundary")
    func truncatesAtWordBoundaryWithEllipsis() async throws {
        let summarizer = TruncatingSummarizer()
        let text = "This is a very long text without any periods or newlines just continuous words going on and on"

        let result = try await summarizer.summarize(text, maxTokens: 5)

        // Should truncate at space and add ellipsis
        #expect(result.hasSuffix("..."))
        #expect(result.count < text.count)
        #expect(!result.contains("  ")) // No double spaces
    }

    @Test("Adds ellipsis when no clean boundary found")
    func addsEllipsisWhenNoCleanBoundary() async throws {
        let summarizer = TruncatingSummarizer()
        let text = "VeryLongWordWithoutAnySpacesPeriodsorNewlines" + String(repeating: "a", count: 1000)

        let result = try await summarizer.summarize(text, maxTokens: 5)

        // Should add ellipsis at the end
        #expect(result.hasSuffix("..."))
        #expect(result.count < text.count)
    }

    // MARK: - Edge Cases

    @Test("Handles empty input")
    func handlesEmptyInput() async throws {
        let summarizer = TruncatingSummarizer()
        let emptyText = ""

        let result = try await summarizer.summarize(emptyText, maxTokens: 100)

        #expect(result.isEmpty)
    }

    @Test("Handles single character input")
    func handlesSingleCharacterInput() async throws {
        let summarizer = TruncatingSummarizer()
        let text = "A"

        let result = try await summarizer.summarize(text, maxTokens: 100)

        #expect(result == "A")
    }

    @Test("Handles whitespace-only input")
    func handlesWhitespaceOnlyInput() async throws {
        let summarizer = TruncatingSummarizer()
        let text = "   \n   \t   "

        let result = try await summarizer.summarize(text, maxTokens: 100)

        #expect(result == text)
    }

    @Test("Handles very small token limit")
    func handlesVerySmallTokenLimit() async throws {
        let summarizer = TruncatingSummarizer()
        let text = "This is a test."

        let result = try await summarizer.summarize(text, maxTokens: 1)

        // Should return something, even if very truncated
        #expect(!result.isEmpty)
    }

    @Test("Preserves multi-sentence structure when possible")
    func preservesMultiSentenceStructure() async throws {
        let summarizer = TruncatingSummarizer()
        let text = "First. Second. Third. Fourth. Fifth. Sixth. Seventh. Eighth."

        let result = try await summarizer.summarize(text, maxTokens: 15)

        // Should include multiple sentences, or be truncated
        #expect(result.hasSuffix(".") || result.hasSuffix("..."))
        #expect(result.count <= text.count)
    }

    // MARK: - Custom Token Estimator

    @Test("Uses custom token estimator")
    func usesCustomTokenEstimator() async throws {
        let customEstimator = CharacterBasedTokenEstimator(charactersPerToken: 2)
        let summarizer = TruncatingSummarizer(tokenEstimator: customEstimator)

        let text = String(repeating: "Hello world. ", count: 50) // Long text
        let result = try await summarizer.summarize(text, maxTokens: 3)

        // With 3 token limit and 2 chars/token, should truncate
        #expect(result.count < text.count)
        #expect(!result.isEmpty)
    }
}

// MARK: - SummarizerErrorTests

@Suite("SummarizerError Tests")
struct SummarizerErrorTests {
    @Test("Unavailable error has description")
    func unavailableErrorHasDescription() {
        let error = SummarizerError.unavailable
        let description = error.description

        #expect(!description.isEmpty)
        #expect(description.contains("not available"))
    }

    @Test("SummarizationFailed error has description with underlying error")
    func summarizationFailedErrorHasDescription() {
        struct TestError: Error {}
        let underlyingError = TestError()
        let error = SummarizerError.summarizationFailed(underlying: underlyingError)
        let description = error.description

        #expect(!description.isEmpty)
        #expect(description.contains("failed"))
    }

    @Test("InputTooShort error has description")
    func inputTooShortErrorHasDescription() {
        let error = SummarizerError.inputTooShort
        let description = error.description

        #expect(!description.isEmpty)
        #expect(description.contains("too short"))
    }

    @Test("Timeout error has description")
    func timeoutErrorHasDescription() {
        let error = SummarizerError.timeout
        let description = error.description

        #expect(!description.isEmpty)
        #expect(description.contains("timed out"))
    }

    @Test("All error cases have unique descriptions")
    func allErrorCasesHaveUniqueDescriptions() {
        struct TestError: Error {}

        let errors: [SummarizerError] = [
            .unavailable,
            .summarizationFailed(underlying: TestError()),
            .inputTooShort,
            .timeout
        ]

        let descriptions = Set(errors.map(\.description))
        #expect(descriptions.count == 4)
    }
}

// MARK: - FallbackSummarizerTests

@Suite("FallbackSummarizer Tests")
struct FallbackSummarizerTests {
    // MARK: - Primary Success Path

    @Test("Uses primary summarizer when available")
    func usesPrimarySummarizerWhenAvailable() async throws {
        let primary = MockSummarizer.succeeding(with: "Primary summary")
        let fallback = MockSummarizer.succeeding(with: "Fallback summary")
        let summarizer = FallbackSummarizer(primary: primary, fallback: fallback)

        let result = try await summarizer.summarize("Test text", maxTokens: 100)

        #expect(result == "Primary summary")
        #expect(await primary.callCount == 1)
        #expect(await fallback.callCount == 0)
    }

    @Test("Passes correct parameters to primary")
    func passesCorrectParametersToPrimary() async throws {
        let primary = MockSummarizer.succeeding()
        let summarizer = FallbackSummarizer(primary: primary, fallback: TruncatingSummarizer.shared)

        _ = try await summarizer.summarize("Test input", maxTokens: 500)

        let lastCall = await primary.lastCall
        #expect(lastCall?.text == "Test input")
        #expect(lastCall?.maxTokens == 500)
    }

    // MARK: - Fallback Path

    @Test("Uses fallback when primary is unavailable")
    func usesFallbackWhenPrimaryUnavailable() async throws {
        let primary = MockSummarizer.unavailable()
        let fallback = MockSummarizer.succeeding(with: "Fallback summary")
        let summarizer = FallbackSummarizer(primary: primary, fallback: fallback)

        let result = try await summarizer.summarize("Test text", maxTokens: 100)

        #expect(result == "Fallback summary")
        #expect(await primary.callCount == 0)
        #expect(await fallback.callCount == 1)
    }

    @Test("Uses fallback when primary throws error")
    func usesFallbackWhenPrimaryThrows() async throws {
        let primary = MockSummarizer.failing(with: SummarizerError.timeout)
        let fallback = MockSummarizer.succeeding(with: "Fallback summary")
        let summarizer = FallbackSummarizer(primary: primary, fallback: fallback)

        let result = try await summarizer.summarize("Test text", maxTokens: 100)

        #expect(result == "Fallback summary")
        #expect(await primary.callCount == 1)
        #expect(await fallback.callCount == 1)
    }

    @Test("Passes correct parameters to fallback")
    func passesCorrectParametersToFallback() async throws {
        let primary = MockSummarizer.unavailable()
        let fallback = MockSummarizer.succeeding()
        let summarizer = FallbackSummarizer(primary: primary, fallback: fallback)

        _ = try await summarizer.summarize("Fallback input", maxTokens: 250)

        let lastCall = await fallback.lastCall
        #expect(lastCall?.text == "Fallback input")
        #expect(lastCall?.maxTokens == 250)
    }

    // MARK: - Error Handling

    @Test("Throws unavailable when both are unavailable")
    func throwsUnavailableWhenBothUnavailable() async throws {
        let primary = MockSummarizer.unavailable()
        let fallback = MockSummarizer.unavailable()
        let summarizer = FallbackSummarizer(primary: primary, fallback: fallback)

        await #expect(throws: SummarizerError.self, performing: {
            try await summarizer.summarize("Test text", maxTokens: 100)
        })
    }

    @Test("Throws unavailable when primary unavailable and fallback throws")
    func throwsUnavailableWhenPrimaryUnavailableAndFallbackThrows() async throws {
        let primary = MockSummarizer.unavailable()
        let fallback = MockSummarizer.failing(with: SummarizerError.inputTooShort)
        let summarizer = FallbackSummarizer(primary: primary, fallback: fallback)

        await #expect(throws: SummarizerError.self, performing: {
            try await summarizer.summarize("Test text", maxTokens: 100)
        })
    }

    @Test("Propagates fallback error when primary throws and fallback throws")
    func propagatesFallbackErrorWhenBothThrow() async throws {
        let primary = MockSummarizer.failing(with: SummarizerError.timeout)
        let fallback = MockSummarizer.failing(with: SummarizerError.inputTooShort)
        let summarizer = FallbackSummarizer(primary: primary, fallback: fallback)

        await #expect(throws: SummarizerError.self, performing: {
            try await summarizer.summarize("Test text", maxTokens: 100)
        })
    }

    // MARK: - Availability Logic

    @Test("isAvailable true when primary available")
    func isAvailableTrueWhenPrimaryAvailable() async {
        let primary = MockSummarizer(isAvailable: true)
        let fallback = MockSummarizer(isAvailable: false)
        let summarizer = FallbackSummarizer(primary: primary, fallback: fallback)

        let available = await summarizer.isAvailable

        #expect(available == true)
    }

    @Test("isAvailable true when fallback available")
    func isAvailableTrueWhenFallbackAvailable() async {
        let primary = MockSummarizer(isAvailable: false)
        let fallback = MockSummarizer(isAvailable: true)
        let summarizer = FallbackSummarizer(primary: primary, fallback: fallback)

        let available = await summarizer.isAvailable

        #expect(available == true)
    }

    @Test("isAvailable true when both available")
    func isAvailableTrueWhenBothAvailable() async {
        let primary = MockSummarizer(isAvailable: true)
        let fallback = MockSummarizer(isAvailable: true)
        let summarizer = FallbackSummarizer(primary: primary, fallback: fallback)

        let available = await summarizer.isAvailable

        #expect(available == true)
    }

    @Test("isAvailable false when both unavailable")
    func isAvailableFalseWhenBothUnavailable() async {
        let primary = MockSummarizer(isAvailable: false)
        let fallback = MockSummarizer(isAvailable: false)
        let summarizer = FallbackSummarizer(primary: primary, fallback: fallback)

        let available = await summarizer.isAvailable

        #expect(available == false)
    }

    // MARK: - Default Fallback

    @Test("Uses TruncatingSummarizer as default fallback")
    func usesTruncatingSummarizerAsDefaultFallback() async throws {
        let primary = MockSummarizer.unavailable()
        let summarizer = FallbackSummarizer(primary: primary)

        let longText = String(repeating: "Hello world. ", count: 100)
        let result = try await summarizer.summarize(longText, maxTokens: 10)

        // Should get truncated result from TruncatingSummarizer
        #expect(result.count < longText.count)
        #expect(!result.isEmpty)
    }

    // MARK: - Integration Tests

    @Test("Works with mixed real and mock summarizers")
    func worksWithMixedRealAndMockSummarizers() async throws {
        let primary = MockSummarizer.succeeding(with: "Mock result")
        let fallback = TruncatingSummarizer.shared
        let summarizer = FallbackSummarizer(primary: primary, fallback: fallback)

        let result = try await summarizer.summarize("Test", maxTokens: 100)

        #expect(result == "Mock result")
    }

    @Test("Fallback to TruncatingSummarizer works correctly")
    func fallbackToTruncatingSummarizerWorks() async throws {
        let primary = MockSummarizer.failing()
        let fallback = TruncatingSummarizer.shared
        let summarizer = FallbackSummarizer(primary: primary, fallback: fallback)

        let text = "First sentence. Second sentence. Third sentence with lots of extra content."
        let result = try await summarizer.summarize(text, maxTokens: 5)

        // Should get truncated result
        #expect(result.count < text.count)
        #expect(!result.isEmpty)
    }
}

// MARK: - SummarizerProtocolConformanceTests

@Suite("Summarizer Protocol Conformance Tests")
struct SummarizerProtocolConformanceTests {
    @Test("TruncatingSummarizer conforms to Summarizer")
    func truncatingSummarizerConformsToSummarizer() async throws {
        let summarizer: any Summarizer = TruncatingSummarizer.shared

        let available = await summarizer.isAvailable
        #expect(available == true)

        let result = try await summarizer.summarize("Test", maxTokens: 100)
        #expect(result == "Test")
    }

    @Test("FallbackSummarizer conforms to Summarizer")
    func fallbackSummarizerConformsToSummarizer() async throws {
        let primary = MockSummarizer.succeeding()
        let summarizer: any Summarizer = FallbackSummarizer(primary: primary)

        let available = await summarizer.isAvailable
        #expect(available == true)

        let result = try await summarizer.summarize("Test", maxTokens: 100)
        #expect(!result.isEmpty)
    }

    @Test("MockSummarizer conforms to Summarizer")
    func mockSummarizerConformsToSummarizer() async throws {
        let summarizer: any Summarizer = MockSummarizer.succeeding()

        let available = await summarizer.isAvailable
        #expect(available == true)

        let result = try await summarizer.summarize("Test", maxTokens: 100)
        #expect(!result.isEmpty)
    }
}

// MARK: - SendableConformanceTests

@Suite("Sendable Conformance Tests")
struct SendableConformanceTests {
    @Test("TruncatingSummarizer is Sendable")
    func truncatingSummarizerIsSendable() {
        func requiresSendable(_: some Sendable) {}
        requiresSendable(TruncatingSummarizer.shared)
    }

    @Test("FallbackSummarizer is Sendable")
    func fallbackSummarizerIsSendable() {
        func requiresSendable(_: some Sendable) {}
        let summarizer = FallbackSummarizer(
            primary: TruncatingSummarizer.shared,
            fallback: TruncatingSummarizer.shared
        )
        requiresSendable(summarizer)
    }

    @Test("SummarizerError is Sendable")
    func summarizerErrorIsSendable() {
        func requiresSendable(_: some Sendable) {}
        requiresSendable(SummarizerError.unavailable)
    }
}
