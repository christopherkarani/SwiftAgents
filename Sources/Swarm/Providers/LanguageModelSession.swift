//
//  LanguageModelSession.swift
//  Swarm
//
//  Created by Chris Karani on 16/01/2026.
//

import Foundation

// Gate FoundationModels import for cross-platform builds (Linux, Windows, etc.)
#if canImport(FoundationModels)
import FoundationModels

@available(macOS 26.0, iOS 26.0, *)
extension LanguageModelSession: InferenceProvider {
    public func generate(prompt: String, options: InferenceOptions) async throws -> String {
        // Create a request with the prompt
        let response = try await self.respond(to: prompt)
        var content = response.content

        // Handle manual stop sequences since Foundation Models might not support them natively via this API
        for stopSequence in options.stopSequences {
            if let range = content.range(of: stopSequence) {
                content = String(content[..<range.lowerBound])
            }
        }

        return content
    }

    public func stream(prompt: String, options _: InferenceOptions) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // For streaming, we'll generate the full response and yield it
                    for try await stream in self.streamResponse(to: prompt) {
                        continuation.yield(stream.content)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func generateWithToolCalls(
        prompt: String,
        tools: [ToolSchema],
        options: InferenceOptions
    ) async throws -> InferenceResponse {
        // Build tool-aware prompt if tools are provided
        let toolPrompt = buildToolPrompt(basePrompt: prompt, tools: tools)
        
        // Generate response with the enhanced prompt
        let response = try await self.respond(to: toolPrompt)
        let content = response.content
        
        // If no tools provided, return simple response
        guard !tools.isEmpty else {
            return InferenceResponse(
                content: content,
                toolCalls: [],
                finishReason: .completed
            )
        }
        
        // Attempt to parse tool calls from the response
        if let toolCalls = parseToolCalls(from: content, availableTools: tools) {
            // Response contains valid tool calls
            return InferenceResponse(
                content: nil,  // Tool call responses typically have no content
                toolCalls: toolCalls,
                finishReason: .toolCall
            )
        }
        
        // No valid tool calls found - return as regular content
        return InferenceResponse(
            content: content,
            toolCalls: [],
            finishReason: .completed
        )
    }
    
    // MARK: - Private Helpers
    
    /// Builds a tool-aware prompt by appending tool definitions to the base prompt.
    private func buildToolPrompt(basePrompt: String, tools: [ToolSchema]) -> String {
        guard !tools.isEmpty else { return basePrompt }
        
        var toolDefinitions: [String] = []
        for tool in tools {
            let params = tool.parameters.map { param in
                let typeDesc = parameterTypeDescription(param.type)
                let required = param.isRequired ? " (required)" : ""
                return "  - \(param.name): \(typeDesc)\(required) - \(param.description)"
            }.joined(separator: "\n")
            
            let paramSection = params.isEmpty ? "  (no parameters)" : params
            
            let toolDef = """
                \(tool.name):
                  Description: \(tool.description)
                  Parameters:
                \(paramSection)
                """
            toolDefinitions.append(toolDef)
        }
        
        return """
            \(basePrompt)
            
            Available tools:
            \(toolDefinitions.joined(separator: "\n\n"))
            
            To use a tool, respond with a JSON object in this exact format:
            {"tool": "tool_name", "arguments": {"param1": "value1", "param2": "value2"}}
            
            If no tool is needed, respond normally without JSON.
            """
    }
    
    /// Converts a ToolParameter type to a human-readable description.
    private func parameterTypeDescription(_ type: ToolParameter.ParameterType) -> String {
        switch type {
        case .string:
            return "string"
        case .int:
            return "integer"
        case .double:
            return "number"
        case .bool:
            return "boolean"
        case let .array(elementType):
            return "array of \(parameterTypeDescription(elementType))"
        case .object:
            return "object"
        case let .oneOf(options):
            return "one of: \(options.joined(separator: ", "))"
        case .any:
            return "any type"
        }
    }
    
    /// Parses tool calls from model response.
    /// Returns nil if no valid tool calls are found.
    private func parseToolCalls(
        from content: String,
        availableTools: [ToolSchema]
    ) -> [InferenceResponse.ParsedToolCall]? {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Look for JSON tool call format: {"tool": "name", "arguments": {...}}
        // Try to find JSON object in the response
        guard let jsonStart = trimmed.firstIndex(of: "{"),
              let jsonEnd = trimmed.lastIndex(of: "}") else {
            return nil
        }
        
        let jsonString = String(trimmed[jsonStart...jsonEnd])
        
        guard let data = jsonString.data(using: .utf8) else {
            return nil
        }
        
        do {
            guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }
            
            // Extract tool name (support both "tool" and "name" keys)
            let toolName = (jsonObject["tool"] as? String) ?? (jsonObject["name"] as? String)
            guard let toolName = toolName?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                return nil
            }
            
            // Verify the tool exists in available tools
            guard availableTools.contains(where: { $0.name == toolName }) else {
                return nil
            }
            
            // Extract arguments
            var arguments: [String: SendableValue] = [:]
            if let argsObject = jsonObject["arguments"] as? [String: Any] {
                for (key, value) in argsObject {
                    arguments[key] = SendableValue.fromJSONValue(value)
                }
            }
            
            // Extract optional call ID
            let callId = jsonObject["id"] as? String
            
            return [InferenceResponse.ParsedToolCall(
                id: callId,
                name: toolName,
                arguments: arguments
            )]
        } catch {
            // JSON parsing failed - not a valid tool call
            return nil
        }
    }
}
#endif
