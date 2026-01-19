// ReActAgent+ResponseParsing.swift
// SwiftAgents Framework
//
// Response parsing logic for ReAct agent.

import Foundation

// MARK: - ReActAgent Response Parsing

extension ReActAgent {
    // MARK: - Response Parsing Types

    /// Represents the parsed response from the LLM.
    enum ParsedResponse {
        case finalAnswer(String)
        case toolCall(InferenceResponse.ParsedToolCall)
        case thinking(String)
        case invalid(String)
    }

    // MARK: - Response Parsing Methods

    /// Parses the LLM response into a structured format.
    /// - Parameter response: The raw response string from the LLM.
    /// - Returns: A `ParsedResponse` indicating what action to take.
    func parseResponse(_ response: String) -> ParsedResponse {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check for final answer
        if let finalAnswerRange = trimmed.range(of: "Final Answer:", options: .caseInsensitive) {
            let answer = String(trimmed[finalAnswerRange.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return .finalAnswer(answer)
        }

        // Check for action/tool call
        if let actionRange = trimmed.range(of: "Action:", options: .caseInsensitive) {
            let actionPart = String(trimmed[actionRange.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: "\n")
                .first ?? ""

            if let parsed = parseToolCall(actionPart) {
                return .toolCall(parsed)
            }
        }

        // Check for thought
        if let thoughtRange = trimmed.range(of: "Thought:", options: .caseInsensitive) {
            var thought = String(trimmed[thoughtRange.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Stop at next section marker if present
            if let nextMarker = thought.range(of: "Action:", options: .caseInsensitive) {
                thought = String(thought[..<nextMarker.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if let nextMarker = thought.range(of: "Final Answer:", options: .caseInsensitive) {
                thought = String(thought[..<nextMarker.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }

            return .thinking(thought)
        }

        // Couldn't parse - treat as thinking
        return .invalid(trimmed)
    }

    /// Parses a tool call from a text string.
    /// - Parameter text: The text containing the tool call.
    /// - Returns: A tuple of tool name and arguments, or nil if parsing fails.
    func parseToolCall(_ text: String) -> InferenceResponse.ParsedToolCall? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // JSON format:
        //   {"tool":"tool_name","arguments":{...}}
        //   {"name":"tool_name","arguments":{...}}
        if trimmed.first == "{", let data = trimmed.data(using: .utf8) {
            if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let callIdRaw = (jsonObject["id"] as? String) ?? (jsonObject["call_id"] as? String)
                let toolNameRaw = (jsonObject["tool"] as? String) ?? (jsonObject["name"] as? String)
                let toolName = toolNameRaw?.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let toolName, !toolName.isEmpty else { return nil }

                var arguments: [String: SendableValue] = [:]
                if let argsObject = jsonObject["arguments"] as? [String: Any] {
                    for (key, value) in argsObject {
                        arguments[key] = SendableValue.fromJSONValue(value)
                    }
                }

                return InferenceResponse.ParsedToolCall(id: callIdRaw, name: toolName, arguments: arguments)
            }
        }

        // Parse format: tool_name(arg1: value1, arg2: value2)
        guard let parenStart = trimmed.firstIndex(of: "("),
              let parenEnd = trimmed.lastIndex(of: ")") else {
            // Try simple format: tool_name with no args
            let name = trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty, !name.contains(" "), !name.contains(":") {
                return InferenceResponse.ParsedToolCall(name: name, arguments: [:])
            }
            return nil
        }

        let name = String(trimmed[..<parenStart]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }

        let argsString = String(trimmed[trimmed.index(after: parenStart)..<parenEnd])

        var arguments: [String: SendableValue] = [:]

        // Parse arguments
        let argPairs = splitArguments(argsString)
        for pair in argPairs {
            let parts = pair.components(separatedBy: ":")
            guard parts.count >= 2 else { continue }

            let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let valueStr = parts.dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespacesAndNewlines)

            // Parse value
            let value = parseValue(valueStr)
            arguments[key] = value
        }

        return InferenceResponse.ParsedToolCall(name: name, arguments: arguments)
    }

    /// Splits argument string by comma, respecting quotes and nested structures.
    /// - Parameter str: The argument string to split.
    /// - Returns: An array of argument key-value pairs.
    func splitArguments(_ str: String) -> [String] {
        var result: [String] = []
        var current = ""
        var depth = 0
        var inQuote = false
        var quoteChar: Character = "\""

        for char in str {
            if !inQuote, char == "\"" || char == "'" {
                inQuote = true
                quoteChar = char
                current.append(char)
            } else if inQuote, char == quoteChar {
                inQuote = false
                current.append(char)
            } else if !inQuote, char == "(" || char == "[" || char == "{" {
                depth += 1
                current.append(char)
            } else if !inQuote, char == ")" || char == "]" || char == "}" {
                depth -= 1
                current.append(char)
            } else if !inQuote, depth == 0, char == "," {
                result.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(char)
            }
        }

        if !current.trimmingCharacters(in: .whitespaces).isEmpty {
            result.append(current.trimmingCharacters(in: .whitespaces))
        }

        return result
    }

    /// Parses a value string into a SendableValue.
    /// - Parameter valueStr: The value string to parse.
    /// - Returns: The parsed SendableValue.
    func parseValue(_ valueStr: String) -> SendableValue {
        let trimmed = valueStr.trimmingCharacters(in: .whitespacesAndNewlines)

        // Null
        if trimmed.lowercased() == "null" || trimmed.lowercased() == "nil" {
            return .null
        }

        // Boolean
        if trimmed.lowercased() == "true" { return .bool(true) }
        if trimmed.lowercased() == "false" { return .bool(false) }

        // Number
        if let intValue = Int(trimmed) { return .int(intValue) }
        if let doubleValue = Double(trimmed) { return .double(doubleValue) }

        // String (remove quotes if present)
        var str = trimmed
        if (str.hasPrefix("\"") && str.hasSuffix("\"")) ||
            (str.hasPrefix("'") && str.hasSuffix("'")) {
            str = String(str.dropFirst().dropLast())
        }
        return .string(str)
    }
}
