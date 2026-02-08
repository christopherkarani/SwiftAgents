import Foundation
import Swarm

#if canImport(AnyLanguageModel) && SWARM_DEMO_ANYLANGUAGEMODEL
import AnyLanguageModel
#endif




// Welcome to Swarm Playground!
// ---------------------------------
// 1. Open Swarm.xcworkspace in Xcode.
// 2. Select the 'Swarm' scheme (for macOS).
// 3. Build the scheme (Cmd + B).
// 4. Run this playground.



@main
struct MyApp {
    static func main() async {
        // Your async code here, e.g., await someNetworkRequest()
        Log.bootstrap()
        print("🚀 Starting Swarm Playground...")

        // Example: Initialize a tool
        guard let tavilyKey = ProcessInfo.processInfo.environment["TAVILY_API_KEY"], !tavilyKey.isEmpty else {
            fatalError("Missing TAVILY_API_KEY in environment variables.")
        }
        let searchTool = WebSearchTool(apiKey: tavilyKey)
        print("Search tool initialized: \(searchTool.name)")

        // Swarm allows you to build autonomous agents that can use tools.
        // Explore the docs in the 'docs/' directory for more examples.

        let instruction = "Your a research Agent"
        guard let openRouterKey = ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"], !openRouterKey.isEmpty else {
            fatalError("Missing OPENROUTER_API_KEY in environment variables.")
        }
        let config = try! OpenRouterConfiguration(apiKey: openRouterKey, model: .init("xiaomi/mimo-v2-flash:free")
        )
        let provider = OpenRouterProvider(configuration: config)

        let inferenceProvider: any InferenceProvider
        #if canImport(AnyLanguageModel) && SWARM_DEMO_ANYLANGUAGEMODEL
            guard let anthropicKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !anthropicKey.isEmpty else {
                fatalError("Missing ANTHROPIC_API_KEY in environment variables.")
            }
            let model = AnthropicLanguageModel(
                apiKey: anthropicKey,
                model: "claude-haiku-4-5"
            )

            let session = LanguageModelSession(model: model, tools: []) {
                """
                You are a helpful research assistant.
                You have access to a websearch tool.
                You never give up.
                """
            }
            inferenceProvider = session
        #else
            inferenceProvider = provider
        #endif

       

        let input = "Conduct deep research on the war on ukraine and its impact on global security. Provide a detailed report with findings, potential implications, and recommendations."


        

        let agent = ReActAgent.Builder()
            .instructions("Your a deep research Agent, when you dont find something you keep looking ")
            .inferenceProvider(inferenceProvider)
            .addTool(searchTool)
            .addTool(StringTool())
            .addTool(DateTimeTool())
            .tracer(PrettyConsoleTracer())
            .build()

       
   //     let age = SupervisorAgent(agents: [planAgent, agent], routingStrategy: session)

     
            do {
                for try await event in agent.stream(input) {
                    switch event {
                    // Text output from the agent
                    case .thinking(thought: let text):
                        print(text, terminator: "")

                    // A tool call is about to be made
                    // The result of a tool call
                    case .toolCallStarted(call: let tool):
                        print("""
                        ✅ Tool \"\(tool.toolName)\" returned:
                        \(tool.description)
                        """)

                        
                    case .toolCallCompleted(call: let tool, result: let result):
                        print("""
                        ✅ Tool \"\(tool.toolName)\" returned:
                        \(result.output)
                        """)
                    // The agent has finished its reasoning loop
                    case .completed(result: let result):
                        print("""
                        🏁 Finished with reason: \(result.output)
                        """)

                    // Any other event type that may be added later
                    default:
                        print("⚠️ Unhandled event: \(event)")
                    }
                }

            } catch {
                print("Error: \(error)")
            }
        
    }
}

// Proper InferenceProvider conformance for LanguageModelSession
#if canImport(AnyLanguageModel) && SWARM_DEMO_ANYLANGUAGEMODEL
extension LanguageModelSession: InferenceProvider {
    public func generate(prompt: String, options _: InferenceOptions) async throws -> String {
        let response = try await respond(to: prompt)
        return response.content
    }

    public func stream(prompt: String, options _: InferenceOptions) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let response = try await respond(to: prompt)
                    continuation.yield(response.content)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func generateWithToolCalls(
        prompt: String,
        tools: [ToolDefinition],
        options _: InferenceOptions
    ) async throws -> InferenceResponse {
        let response = try await respond(to: prompt)
        return InferenceResponse(
            content: response.content,
            toolCalls: [],
            finishReason: .completed
        )
    }
}
#endif
