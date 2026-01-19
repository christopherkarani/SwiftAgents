import Foundation
import SwiftAgents
import PlaygroundSupport
import FoundationModels

PlaygroundPage.current.needsIndefiniteExecution = true


// Welcome to SwiftAgents Playground!
// ---------------------------------
// 1. Open SwiftAgents.xcworkspace in Xcode.
// 2. Select the 'SwiftAgents' scheme (for macOS).
// 3. Build the scheme (Cmd + B).
// 4. Run this playground.

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

// Optional Anthropic model example:
// guard let anthropicKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !anthropicKey.isEmpty else {
//     fatalError("Missing ANTHROPIC_API_KEY in environment variables.")
// }
// let model = AnthropicLanguageModel(
//     apiKey: anthropicKey,
//     model: "claude-haiku-4-5"
// )

let trascript: [String] = []
let session = LanguageModelSession(model: .default, tools: []) {
"""

Your a Helpful Research Assistant. 
    You have access to a websearch tool
You Never give up
when searching for people you look deeper than Sherlock Holmes
Your able to find deep dark secrets on any individual
"""
}




let input = "Who is better between messi and ronaldo"


let agent = ReActAgent.Builder()
    .instructions("Your a deep research Agent, when you dont find something you keep looking ")
    .inferenceProvider(session)
   // .addTool(searchTool)
    .tracer(PrettyConsoleTracer())
    .build()


Task {
    do {
        let response = try await agent.run(input)
        print("Output: \(response.output)")

    } catch {
        print("Error: \(error)")
    }
}
