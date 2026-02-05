// OpenRouterTypesTests.swift
// SwarmTests
//
// Tests for OpenRouter types, specifically JSON decoding of API responses.

import Foundation
@testable import Swarm
import Testing

// MARK: - OpenRouterUsageTests

@Suite("OpenRouterUsage Decoding Tests")
struct OpenRouterUsageTests {

    // Note: OpenRouterUsage has explicit CodingKeys that handle snake_case mapping,
    // so we use a plain decoder without keyDecodingStrategy
    let decoder = JSONDecoder()

    @Test("Decodes usage with all fields present")
    func decodesAllFields() throws {
        let json = """
        {
            "prompt_tokens": 100,
            "completion_tokens": 50,
            "total_tokens": 150
        }
        """

        let data = json.data(using: .utf8)!
        let usage = try decoder.decode(OpenRouterUsage.self, from: data)

        #expect(usage.promptTokens == 100)
        #expect(usage.completionTokens == 50)
        #expect(usage.totalTokens == 150)
    }

    @Test("Decodes usage with missing prompt_tokens")
    func decodesMissingPromptTokens() throws {
        let json = """
        {
            "completion_tokens": 50,
            "total_tokens": 150
        }
        """

        let data = json.data(using: .utf8)!
        let usage = try decoder.decode(OpenRouterUsage.self, from: data)

        #expect(usage.promptTokens == nil)
        #expect(usage.completionTokens == 50)
        #expect(usage.totalTokens == 150)
    }

    @Test("Decodes usage with missing completion_tokens")
    func decodesMissingCompletionTokens() throws {
        let json = """
        {
            "prompt_tokens": 100,
            "total_tokens": 150
        }
        """

        let data = json.data(using: .utf8)!
        let usage = try decoder.decode(OpenRouterUsage.self, from: data)

        #expect(usage.promptTokens == 100)
        #expect(usage.completionTokens == nil)
        #expect(usage.totalTokens == 150)
    }

    @Test("Decodes usage with missing total_tokens")
    func decodesMissingTotalTokens() throws {
        let json = """
        {
            "prompt_tokens": 100,
            "completion_tokens": 50
        }
        """

        let data = json.data(using: .utf8)!
        let usage = try decoder.decode(OpenRouterUsage.self, from: data)

        #expect(usage.promptTokens == 100)
        #expect(usage.completionTokens == 50)
        #expect(usage.totalTokens == nil)
    }

    @Test("Decodes usage with all fields missing")
    func decodesAllFieldsMissing() throws {
        let json = "{}"

        let data = json.data(using: .utf8)!
        let usage = try decoder.decode(OpenRouterUsage.self, from: data)

        #expect(usage.promptTokens == nil)
        #expect(usage.completionTokens == nil)
        #expect(usage.totalTokens == nil)
    }

    @Test("Decodes usage with null values")
    func decodesNullValues() throws {
        let json = """
        {
            "prompt_tokens": null,
            "completion_tokens": 50,
            "total_tokens": null
        }
        """

        let data = json.data(using: .utf8)!
        let usage = try decoder.decode(OpenRouterUsage.self, from: data)

        #expect(usage.promptTokens == nil)
        #expect(usage.completionTokens == 50)
        #expect(usage.totalTokens == nil)
    }
}

// MARK: - OpenRouterResponseTests

@Suite("OpenRouterResponse Decoding Tests")
struct OpenRouterResponseTests {

    // Note: OpenRouter types have explicit CodingKeys that handle snake_case mapping,
    // so we use a plain decoder without keyDecodingStrategy
    let decoder = JSONDecoder()

    @Test("Decodes complete response with usage")
    func decodesCompleteResponse() throws {
        let json = """
        {
            "id": "gen-123",
            "created": 1735488000,
            "model": "anthropic/claude-sonnet-4.5",
            "choices": [
                {
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": "Hello, world!"
                    },
                    "finish_reason": "stop"
                }
            ],
            "usage": {
                "prompt_tokens": 100,
                "completion_tokens": 50,
                "total_tokens": 150
            }
        }
        """

        let data = json.data(using: .utf8)!
        let response = try decoder.decode(OpenRouterResponse.self, from: data)

        #expect(response.id == "gen-123")
        #expect(response.created == 1735488000)
        #expect(response.model == "anthropic/claude-sonnet-4.5")
        #expect(response.choices.count == 1)
        #expect(response.choices.first?.message.content == "Hello, world!")
        #expect(response.choices.first?.finishReason == "stop")
        #expect(response.usage?.promptTokens == 100)
        #expect(response.usage?.completionTokens == 50)
        #expect(response.usage?.totalTokens == 150)
    }

    @Test("Decodes response without usage")
    func decodesResponseWithoutUsage() throws {
        let json = """
        {
            "id": "gen-123",
            "created": 1735488000,
            "model": "anthropic/claude-sonnet-4.5",
            "choices": [
                {
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": "Hello!"
                    },
                    "finish_reason": "stop"
                }
            ]
        }
        """

        let data = json.data(using: .utf8)!
        let response = try decoder.decode(OpenRouterResponse.self, from: data)

        #expect(response.id == "gen-123")
        #expect(response.usage == nil)
    }

    @Test("Decodes response with partial usage")
    func decodesResponseWithPartialUsage() throws {
        let json = """
        {
            "id": "gen-123",
            "created": 1735488000,
            "model": "anthropic/claude-sonnet-4.5",
            "choices": [
                {
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": "Hello!"
                    },
                    "finish_reason": "stop"
                }
            ],
            "usage": {
                "prompt_tokens": 100
            }
        }
        """

        let data = json.data(using: .utf8)!
        let response = try decoder.decode(OpenRouterResponse.self, from: data)

        #expect(response.usage != nil)
        #expect(response.usage?.promptTokens == 100)
        #expect(response.usage?.completionTokens == nil)
        #expect(response.usage?.totalTokens == nil)
    }

    @Test("Decodes response with empty usage object")
    func decodesResponseWithEmptyUsage() throws {
        let json = """
        {
            "id": "gen-123",
            "created": 1735488000,
            "model": "anthropic/claude-sonnet-4.5",
            "choices": [
                {
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": "Hello!"
                    },
                    "finish_reason": "stop"
                }
            ],
            "usage": {}
        }
        """

        let data = json.data(using: .utf8)!
        let response = try decoder.decode(OpenRouterResponse.self, from: data)

        #expect(response.usage != nil)
        #expect(response.usage?.promptTokens == nil)
        #expect(response.usage?.completionTokens == nil)
        #expect(response.usage?.totalTokens == nil)
    }

    @Test("Decodes real OpenRouter response format")
    func decodesRealOpenRouterResponse() throws {
        // This mimics the actual response format from OpenRouter API
        let json = """
        {
            "id": "gen-1234567890abcdef",
            "provider": "Anthropic",
            "model": "anthropic/claude-sonnet-4.5",
            "object": "chat.completion",
            "created": 1767053276,
            "choices": [
                {
                    "logprobs": null,
                    "finish_reason": "stop",
                    "native_finish_reason": "stop",
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": "```json\\n{\\"category\\": \\"Software Engineering\\", \\"is_aggregator\\": true, \\"confidence\\": 1.0}\\n```"
                    }
                }
            ],
            "usage": {
                "prompt_tokens": 245,
                "completion_tokens": 28,
                "total_tokens": 273
            }
        }
        """

        let data = json.data(using: .utf8)!
        let response = try decoder.decode(OpenRouterResponse.self, from: data)

        #expect(response.id == "gen-1234567890abcdef")
        #expect(response.model == "anthropic/claude-sonnet-4.5")
        #expect(response.choices.count == 1)
        #expect(response.choices.first?.finishReason == "stop")
        #expect(response.choices.first?.message.content?.contains("Software Engineering") == true)
        #expect(response.usage?.promptTokens == 245)
        #expect(response.usage?.completionTokens == 28)
        #expect(response.usage?.totalTokens == 273)
    }

    @Test("Decodes response with tool calls")
    func decodesResponseWithToolCalls() throws {
        let json = """
        {
            "id": "gen-456",
            "created": 1735488000,
            "model": "anthropic/claude-sonnet-4.5",
            "choices": [
                {
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": null,
                        "tool_calls": [
                            {
                                "id": "call_123",
                                "type": "function",
                                "function": {
                                    "name": "get_weather",
                                    "arguments": "{\\"location\\": \\"San Francisco\\"}"
                                }
                            }
                        ]
                    },
                    "finish_reason": "tool_calls"
                }
            ],
            "usage": {
                "prompt_tokens": 50,
                "completion_tokens": 25,
                "total_tokens": 75
            }
        }
        """

        let data = json.data(using: .utf8)!
        let response = try decoder.decode(OpenRouterResponse.self, from: data)

        #expect(response.choices.first?.finishReason == "tool_calls")
        #expect(response.choices.first?.message.content == nil)
        #expect(response.choices.first?.message.toolCalls?.count == 1)
        #expect(response.choices.first?.message.toolCalls?.first?.id == "call_123")
        #expect(response.choices.first?.message.toolCalls?.first?.function.name == "get_weather")
    }
}

// MARK: - OpenRouterChoiceTests

@Suite("OpenRouterChoice Decoding Tests")
struct OpenRouterChoiceTests {

    // Note: OpenRouterChoice has explicit CodingKeys that handle snake_case mapping,
    // so we use a plain decoder without keyDecodingStrategy
    let decoder = JSONDecoder()

    @Test("Decodes choice with all finish reasons")
    func decodesAllFinishReasons() throws {
        let finishReasons = ["stop", "length", "tool_calls", "content_filter"]

        for reason in finishReasons {
            let json = """
            {
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": "Test"
                },
                "finish_reason": "\(reason)"
            }
            """

            let data = json.data(using: .utf8)!
            let choice = try decoder.decode(OpenRouterChoice.self, from: data)

            #expect(choice.finishReason == reason)
        }
    }

    @Test("Decodes choice with null finish reason")
    func decodesNullFinishReason() throws {
        let json = """
        {
            "index": 0,
            "message": {
                "role": "assistant",
                "content": "Test"
            },
            "finish_reason": null
        }
        """

        let data = json.data(using: .utf8)!
        let choice = try decoder.decode(OpenRouterChoice.self, from: data)

        #expect(choice.finishReason == nil)
    }
}
