import Foundation

/// Enforces context-envelope limits for provider prompts.
enum PromptEnvelope {
    private static let truncationMarker = "\n\n[... context truncated for strict4k budget ...]\n\n"

    static func enforce(prompt: String, profile: ContextProfile) -> String {
        guard profile.preset == .strict4k else {
            return prompt
        }

        let charsPerToken = CharacterBasedTokenEstimator.shared.charactersPerToken
        let maxChars = max(1, profile.budget.maxInputTokens * charsPerToken)

        guard prompt.count > maxChars else {
            return prompt
        }

        let marker = truncationMarker
        let markerCount = marker.count

        if maxChars <= markerCount + 16 {
            return String(marker.prefix(maxChars))
        }

        // Preserve the beginning (instructions/system context) and the end
        // (latest user/tool context), trimming middle context first.
        let tailChars = max(16, maxChars / 3)
        let headChars = max(16, maxChars - markerCount - tailChars)

        let head = prefix(prompt, maxCharacters: headChars)
        let tail = suffix(prompt, maxCharacters: tailChars)

        var combined = head + marker + tail
        if combined.count <= maxChars {
            return combined
        }

        let overflow = combined.count - maxChars
        let adjustedTail = max(0, tailChars - overflow)
        combined = head + marker + suffix(prompt, maxCharacters: adjustedTail)

        if combined.count <= maxChars {
            return combined
        }

        let adjustedHead = max(0, maxChars - markerCount)
        return prefix(prompt, maxCharacters: adjustedHead) + marker
    }

    private static func prefix(_ text: String, maxCharacters: Int) -> String {
        guard maxCharacters > 0 else { return "" }
        guard text.count > maxCharacters else { return text }
        let end = text.index(text.startIndex, offsetBy: maxCharacters)
        return String(text[..<end])
    }

    private static func suffix(_ text: String, maxCharacters: Int) -> String {
        guard maxCharacters > 0 else { return "" }
        guard text.count > maxCharacters else { return text }
        let start = text.index(text.endIndex, offsetBy: -maxCharacters)
        return String(text[start...])
    }
}
