import Foundation
import SwiftAgents

import AnyLanguageModel




// Welcome to SwiftAgents Playground!
// ---------------------------------
// 1. Open SwiftAgents.xcworkspace in Xcode.
// 2. Select the 'SwiftAgents' scheme (for macOS).
// 3. Build the scheme (Cmd + B).
// 4. Run this playground.



@main
struct MyApp {
    static func main() async {
        // Your async code here, e.g., await someNetworkRequest()
        Log.bootstrap()
        print("🚀 Starting SwiftAgents Playground...")

        // Example: Initialize a tool
        guard let tavilyKey = ProcessInfo.processInfo.environment["TAVILY_API_KEY"], !tavilyKey.isEmpty else {
            fatalError("Missing TAVILY_API_KEY in environment variables.")
        }
        let searchTool = WebSearchTool(apiKey: tavilyKey)
        print("Search tool initialized: \(searchTool.name)")

        // SwiftAgents allows you to build autonomous agents that can use tools.
        // Explore the docs in the 'docs/' directory for more examples.

        let instruction = "Your a research Agent"
        guard let openRouterKey = ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"], !openRouterKey.isEmpty else {
            fatalError("Missing OPENROUTER_API_KEY in environment variables.")
        }
        let config = try! OpenRouterConfiguration(apiKey: openRouterKey, model: .init("xiaomi/mimo-v2-flash:free")
        )
        let provider = OpenRouterProvider(configuration: config)

        guard let anthropicKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !anthropicKey.isEmpty else {
            fatalError("Missing ANTHROPIC_API_KEY in environment variables.")
        }
        let model = AnthropicLanguageModel(
            apiKey: anthropicKey,
            model: "claude-haiku-4-5"
        )

        let trascript: [String] = []
        
        let session = LanguageModelSession(model: model, tools: []) {
        """

        Your a Helpful Research Assistant. 
            You have access to a websearch tool
        You Never give up
        when searching for people you look deeper than Sherlock Holmes
        Your able to find deep dark secrets on any individual
        """
        }

       

        let input = "Conduct deep research on the war on ukraine and its impact on global security. Provide a detailed report with findings, potential implications, and recommendations."


        
//        let planAgent = PlanAndExecuteAgent.Builder()
//            .instructions("Your Goal is to take the take and break it down into smaller steps and create a plan")
//            .inferenceProvider(session)
//            .addTool(StringTool())
//            .withBuiltInTools()
//            .build()

        let agent = ReActAgent.Builder()
            .instructions("Your a deep research Agent, when you dont find something you keep looking ")
            .inferenceProvider(session)
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
extension LanguageModelSession: InferenceProvider {
    public func generate(prompt: String, options: InferenceOptions) async throws -> String {
        // Create a request with the prompt
        let response = try await self.respond(to: prompt)
        return response.content
    }
    
    public func stream(prompt: String, options: InferenceOptions) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // For streaming, we'll generate the full response and yield it
                    let response = try await self.respond(to: prompt)
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
        options: InferenceOptions
    ) async throws -> InferenceResponse {
        // This is a simplified implementation
        // In a full implementation, you would handle tool calls properly
        print("The Tools", tools)
        let response = try await self.respond(to: prompt)
        
        return InferenceResponse(
            content: response.content,
            toolCalls: [], // No tool calls in this simple implementation
            finishReason: .completed
        )
    }
}
