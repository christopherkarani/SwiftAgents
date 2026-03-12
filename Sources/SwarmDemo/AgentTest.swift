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
        Log.bootstrap()
        print("🚀 Starting Swarm Playground...")

        guard let tavilyKey = ProcessInfo.processInfo.environment["TAVILY_API_KEY"], !tavilyKey.isEmpty else {
            fatalError("Missing TAVILY_API_KEY in environment variables.")
        }
        let searchTool = WebSearchTool(apiKey: tavilyKey)
        print("Search tool initialized: \(searchTool.name)")

        guard let openRouterKey = ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"], !openRouterKey.isEmpty else {
            fatalError("Missing OPENROUTER_API_KEY in environment variables.")
        }
        let provider = LLM.openRouter(apiKey: openRouterKey, model: "xiaomi/mimo-v2-flash:free")

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

        let agent = Agent.Builder()
            .instructions("Your a deep research Agent, when you dont find something you keep looking ")
            .inferenceProvider(inferenceProvider)
            .addTool(searchTool)
            .addTool(StringTool())
            .addTool(DateTimeTool())
            .tracer(PrettyConsoleTracer())
            .build()

        do {
            for try await event in agent.stream(input) {
                switch event {
                // Lifecycle
                case .started(input: let input):
                    print("Agent started with input: \(input.prefix(80))...")
                case .completed(result: let result):
                    print("🏁 Finished with reason: \(result.output)")
                case .failed(error: let error):
                    print("❌ Agent failed: \(error)")
                case .cancelled:
                    print("⚠️ Agent cancelled")

                // Thinking
                case .thinking(thought: let text):
                    print(text, terminator: "")
                case .thinkingPartial(partialThought: let text):
                    print(text, terminator: "")

                // Tool calls
                case .toolCallStarted(call: let call):
                    print("-> Calling \"\(call.toolName)\" with \(call.arguments)")
                case .toolCallPartial:
                    break
                case .toolCallCompleted(call: let tool, result: let result):
                    print("✅ Tool \"\(tool.toolName)\" returned: \(result.output)")
                case .toolCallFailed(call: let tool, error: let error):
                    print("❌ Tool \"\(tool.toolName)\" failed: \(error)")

                // Output streaming
                case .outputToken:
                    break
                case .outputChunk(chunk: let chunk):
                    print(chunk, terminator: "")

                // Iteration tracking
                case .iterationStarted, .iterationCompleted:
                    break

                // LLM lifecycle
                case .llmStarted, .llmCompleted:
                    break

                // Decision and planning
                case .decision(decision: let decision, options: _):
                    print("Decision: \(decision)")
                case .planUpdated(plan: let plan, stepCount: let steps):
                    print("Plan updated (\(steps) steps): \(plan.prefix(80))...")

                // Handoffs
                case .handoffRequested(fromAgent: let from, toAgent: let to, reason: let reason):
                    print("Handoff requested: \(from) -> \(to) (\(reason ?? "no reason"))")
                case .handoffStarted(from: let from, to: let to, input: _):
                    print("Handoff started: \(from) -> \(to)")
                case .handoffCompleted(fromAgent: let from, toAgent: let to):
                    print("Handoff completed: \(from) -> \(to)")
                case .handoffCompletedWithResult(from: let from, to: let to, result: _):
                    print("Handoff completed with result: \(from) -> \(to)")
                case .handoffSkipped(from: let from, to: let to, reason: let reason):
                    print("Handoff skipped: \(from) -> \(to) (\(reason))")

                // Guardrails
                case .guardrailFailed(error: let error):
                    print("❌ Guardrail failed: \(error)")
                case .guardrailStarted(name: let name, type: _):
                    print("Guardrail started: \(name)")
                case .guardrailPassed(name: let name, type: _):
                    print("Guardrail passed: \(name)")
                case .guardrailTriggered(name: let name, type: _, message: let msg):
                    print("⚠️ Guardrail triggered: \(name) — \(msg ?? "")")

                // Memory
                case .memoryAccessed(operation: let op, count: let count):
                    print("Memory \(op): \(count) items")
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
        tools _: [ToolSchema],
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
