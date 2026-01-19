//
//  Swarm.swift
//
//
//  Created by James Rochabrun on 10/18/24.
//

import Foundation
import SwiftOpenAI

/// An actor that manages the streaming of agent interactions and tool responses.
///
/// The `Swarm` actor coordinates the communication between an agent and tools, handling
/// the streaming of responses, executing tool calls, and updating context variables during the conversation.
public actor Swarm<Handler: ToolResponseHandler> {
  
  private let client: OpenAIService
  private let toolResponseHandler: Handler
  
  /// Initializes a new instance of the `Swarm` actor.
  ///
  /// - Parameters:
  ///   - client: An instance of `OpenAIService` used for making requests.
  ///   - toolResponseHandler: A handler conforming to `ToolResponseHandler` responsible for processing tool responses.
  public init(client: OpenAIService, toolResponseHandler: Handler) {
    self.client = client
    self.toolResponseHandler = toolResponseHandler
  }
  
  /// Runs a stream of interactions between the agent and the provided messages.
  ///
  /// This function handles the streaming of chat completion, managing tool calls, and updating the agent and context variables.
  ///
  /// - Parameters:
  ///   - agent: The agent responsible for processing the messages.
  ///   - messages: A list of chat messages to be included in the interaction.
  ///   - contextVariables: Optional context variables to use during the conversation.
  ///   - modelOverride: An optional model to override the agent's default model.
  ///   - maxTurns: The maximum number of turns the agent is allowed to take.
  ///   - executeTools: A Boolean value to determine whether the agent should execute tools during the process.
  /// - Returns: An `AsyncThrowingStream` of `StreamChunk` objects, representing the streamed interaction data.
  public func runStream(
    agent: Agent,
    messages: [ChatCompletionParameters.Message],
    contextVariables: [String: String] = [:],
    modelOverride: Model? = nil,
    executeTools: Bool = true)
  -> AsyncThrowingStream<StreamChunk, Error>
  {
    AsyncThrowingStream { continuation in
      Task {
        do {
          var activeAgent = agent
          var currentContextVariables = contextVariables
          var history = messages
          let initialMessageCount = messages.count
          
          continuation.yield(StreamChunk(delim: "start"))
          
          let completionStream = try await getChatCompletionStream(
            agent: activeAgent,
            history: history,
            contextVariables: currentContextVariables,
            modelOverride: modelOverride)
          
          let (content, toolCalls) = try await accumulateStreamContent(completionStream, continuation: continuation)
          
          let assistantMessage = ChatCompletionParameters.Message(
            role: .assistant,
            content: .text(content),
            toolCalls: toolCalls
          )
          history.append(assistantMessage)
          
          /// Check if there are available tools.
          if let availableToolCalls = toolCalls, !availableToolCalls.isEmpty && executeTools {
            let partialResponse = try await handleToolCalls(
              availableToolCalls,
              agent: activeAgent,
              contextVariables: currentContextVariables)
            
            history.append(contentsOf: partialResponse.messages)
            currentContextVariables.merge(partialResponse.contextVariables) { _, new in new }
            
            activeAgent = partialResponse.agent
            
            for message in partialResponse.messages {
              if case .text(_) = message.content {
                // We only need to stream the `availableToolCalls` at this point.
                continuation.yield(StreamChunk(content: "", toolCalls: availableToolCalls))
              }
            }
            
            // Get final response after tool execution
            let finalStream = try await getChatCompletionStream(
              agent: activeAgent,
              history: history,
              contextVariables: currentContextVariables,
              modelOverride: modelOverride)
            
            let (finalContent, _) = try await accumulateStreamContent(finalStream, continuation: continuation)
            
            if !finalContent.isEmpty {
              let finalAssistantMessage = ChatCompletionParameters.Message(
                role: .assistant,
                content: .text(finalContent)
              )
              history.append(finalAssistantMessage)
            }
          }
          
          continuation.yield(StreamChunk(delim: "end"))
          
          let finalResponse = Response(
            messages: Array(history.dropFirst(initialMessageCount)),
            agent: activeAgent,
            contextVariables: currentContextVariables
          )
          continuation.yield(StreamChunk(response: finalResponse))
          continuation.finish()
          
        } catch {
          continuation.finish(throwing: error)
        }
      }
    }
  }
  
  /// Accumulates content from a streaming response.
  ///
  /// This function gathers content and tool calls from the streamed chunks and sends updates via the provided continuation.
  ///
  /// - Parameters:
  ///   - stream: The `AsyncThrowingStream` of `ChatCompletionChunkObject` to process.
  ///   - continuation: A continuation to yield the accumulated content and tool calls as `StreamChunk` objects.
  /// - Returns: A tuple containing the accumulated content and tool calls.
  private func accumulateStreamContent(
    _ stream: AsyncThrowingStream<ChatCompletionChunkObject, Error>,
    continuation: AsyncThrowingStream<StreamChunk, Error>.Continuation)
  async throws -> (String, [ToolCall]?)
  {
    var content = ""
    var accumulatedTools: [String: (ToolCall, String)] = [:]
    
    for try await chunk in stream {
      if let chunkContent = chunk.choices?.first?.delta?.content, !chunkContent.isEmpty {
        content += chunkContent
        continuation.yield(StreamChunk(content: chunkContent))
      }
      
      if let toolCalls = chunk.choices?.first?.delta?.toolCalls, !toolCalls.isEmpty {
        for toolCall in toolCalls {
          if let id = toolCall.id {
            accumulatedTools[id] = (toolCall, toolCall.function.arguments)
          } else if let index = toolCall.index, let existingTool = accumulatedTools.values.first(where: { $0.0.index == index }) {
            let updatedArguments = existingTool.1 + (toolCall.function.arguments)
            accumulatedTools[existingTool.0.id ?? ""] = (existingTool.0, updatedArguments)
          }
        }
        continuation.yield(StreamChunk(toolCalls: toolCalls))
      }
      
      if chunk.choices?.first?.finishReason != nil {
        break
      }
    }
    let finalToolCalls = accumulatedTools.isEmpty ? nil : accumulatedTools.map { (_, value) in
      let (toolCall, arguments) = value
      return ToolCall(
        id: toolCall.id,
        type: toolCall.type ?? "function",
        function: FunctionCall(arguments: arguments, name: toolCall.function.name ?? "")
      )
    }
    
    return (content, finalToolCalls)
  }
  
  /// Retrieves the streamed chat completion from the agent.
  ///
  /// This function sends the agent's history and context variables to retrieve a streamed response.
  ///
  /// - Parameters:
  ///   - agent: The agent to use for generating the response.
  ///   - history: The chat history for the agent to base the response on.
  ///   - contextVariables: The context variables to pass to the agent.
  ///   - modelOverride: An optional model to override the agent's default model.
  /// - Returns: An `AsyncThrowingStream` of `ChatCompletionChunkObject` representing the streamed response.
  private func getChatCompletionStream(
    agent: Agent,
    history: [ChatCompletionParameters.Message],
    contextVariables: [String: String],
    modelOverride: Model?)
  async throws -> AsyncThrowingStream<ChatCompletionChunkObject, Error>
  {
    
    // Add a system message for agent's instructions
    var updatedHistory = history
    
    // Check if a system message with instructions is already present
    if let lastSystemMessageIndex = updatedHistory.lastIndex(where: { $0.role == "system" }) {
      // Update the existing system message with the current agent's instructions
      updatedHistory[lastSystemMessageIndex] = ChatCompletionParameters.Message(
        role: .system,
        content: .text(agent.instructions)
      )
    } else {
      // Add a new system message if it doesn't exist
      let systemMessage = ChatCompletionParameters.Message(
        role: .system,
        content: .text(agent.instructions)
      )
      updatedHistory.insert(systemMessage, at: 0)
    }
    
    let parameters = ChatCompletionParameters(
      messages: updatedHistory,
      model: modelOverride ?? agent.model,
      tools: agent.tools,
      parallelToolCalls: false)
    
    return try await client.startStreamedChat(parameters: parameters)
  }
  
  /// Handles tool calls within a response, transferring the context and updating the agent.
  ///
  /// This function processes tool calls, executes the necessary tools, and updates the agent and context variables.
  ///
  /// - Parameters:
  ///   - toolCalls: A list of tool calls made by the agent during the interaction.
  ///   - agent: The agent currently managing the conversation.
  ///   - contextVariables: The context variables associated with the conversation.
  /// - Returns: A `Response` object that includes the updated messages, agent, and context variables.
  private func handleToolCalls(
    _ toolCalls: [ToolCall],
    agent: Agent,
    contextVariables: [String: String])
  async throws -> Response
  {
    var partialResponse = Response(messages: [], agent: agent, contextVariables: contextVariables)
    
    debugPrint("Handling Tool Call for agent \(agent.name)")
    
    for toolCall in toolCalls {
      debugPrint("Handling Tool Call \(toolCall.function.name ?? "No name")")
      guard let tool = agent.tools.first(where: { $0.function.name == toolCall.function.name }) else {
        debugPrint("Tool not found:", toolCall.function.name ?? "no name")
        continue
      }
      
      let parameters = toolCall.function.arguments.toDictionary() ?? [:]
      let newAgent = toolResponseHandler.transferToAgent(parameters)
      let content = try await toolResponseHandler.handleToolResponseContent(parameters: parameters)
      
      if let newAgent = newAgent {
        partialResponse.agent = newAgent
        debugPrint("Handling Tool Call transferring to \(newAgent.name)")
      }
      let toolMessage = ChatCompletionParameters.Message(
        role: .tool,
        content: .text(content ?? ""),
        name: tool.function.name,
        toolCallID: toolCall.id
      )
      partialResponse.messages.append(toolMessage)
    }
    
    return partialResponse
  }
}
