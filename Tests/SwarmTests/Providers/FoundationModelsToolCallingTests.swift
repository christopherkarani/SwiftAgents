#if canImport(FoundationModels)
    import Foundation
    import FoundationModels
    @testable import Swarm
    import Testing

    @Suite("FoundationModels Tool Calling Tests")
    struct FoundationModelsToolCallingTests {
        @Test("LanguageModelSession throws explicit unsupported error when tools are requested")
        func languageModelSessionThrowsUnsupportedToolCalling() async throws {
            guard #available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, visionOS 26.0, *) else {
                return
            }

            let session = LanguageModelSession()
            let tools = [
                ToolSchema(
                    name: "lookup",
                    description: "Look up information",
                    parameters: []
                )
            ]

            do {
                _ = try await session.generateWithToolCalls(
                    prompt: "Use the tool",
                    tools: tools,
                    options: .default
                )
                Issue.record("Expected an explicit unsupported tool-calling error")
            } catch let error as AgentError {
                switch error {
                case .toolCallingRequiresCloudProvider:
                    #expect(error.localizedDescription.localizedCaseInsensitiveContains("tool calling"))
                    #expect(error.localizedDescription.localizedCaseInsensitiveContains("Foundation Models"))
                default:
                    Issue.record("Expected toolCallingRequiresCloudProvider error, got \(error)")
                }
            } catch {
                Issue.record("Expected AgentError, got \(error)")
            }
        }
    }
#endif
