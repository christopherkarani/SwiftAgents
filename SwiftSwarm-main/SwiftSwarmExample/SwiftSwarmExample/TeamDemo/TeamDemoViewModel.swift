//
//  TeamDemoViewModel.swift
//  SwiftSwarmExample
//
//  Created by James Rochabrun on 10/22/24.
//

import Foundation
import SwiftSwarm
import SwiftOpenAI

@Observable
final class TeamDemoViewModel<T: ToolResponseHandler> {
   
   init(swarm: Swarm<T>) {
      self.swarm = swarm
   }
   
   // Swarm is stateless
   let swarm: Swarm<T>
   
   // Array to store the history of all messages
   var allMessages: [ChatCompletionParameters.Message] = []
   
   // Array for updating SwiftUI list of cells
   var cells: [CellViewModel] = []
   
   // Track the ID of the current cell being updated
   private var currentCellID: UUID? = nil
   
   // Track the current assistant (agent)
   var activeAgent: Agent? = nil
   
   func startOver() {
      cells = []
      allMessages = []
      activeAgent = nil
   }
   
   // Unified function to handle both initial and continued conversations
   @MainActor
   func handleConversation(
      newMessages: [ChatCompletionParameters.Message],
      initialAgent: Agent? = nil)
      async throws
   {
      // If there's no active agent, use the provided agent (for the first query), otherwise continue with the current agent
      let currentAgent = activeAgent ?? initialAgent
      
      guard let agent = currentAgent else {
         print("Error: No agent provided or available.")
         return
      }
      
      // Append new messages to the message history
      allMessages.append(contentsOf: newMessages)
      
      // First, add a new user cell for each new message
      for message in newMessages {
         let userCell = CellViewModel(content: message.content.text ?? "", role: .user, agentName: agent.name)
         cells.append(userCell)
      }
      
      // Run the stream with the updated message history and the current or provided agent
      let streamChunks = await swarm.runStream(agent: agent, messages: allMessages)
      
      for try await streamChunk in streamChunks {
         
         if let chunkContent = streamChunk.content {
            
            if let toolCall = streamChunk.toolCalls?.first,
               let name = toolCall.function.name,
                  let agent = Team(rawValue: name) {
               cells.append(CellViewModel(
                  content: "👤 Switching to \(agent.rawValue)",
                  role: .agent,
                  agentName: agent.rawValue
               ))
            }
            
            // Update or create a new cell with chunk content
            if let currentID = currentCellID, let index = cells.firstIndex(where: { $0.id == currentID }) {
               cells[index].content += chunkContent
            } else {
               let newCell = CellViewModel(content: chunkContent, role: .agent, agentName: currentAgent?.name ?? "")
               cells.append(newCell)
               currentCellID = newCell.id
            }
         }
         
         // Check if there's a response from the agent
         if let response = streamChunk.response {
            // Store the returned messages in the message history
            allMessages.append(contentsOf: response.messages)
            let newAgent = response.agent
            if  newAgent.name != currentAgent?.name {
               activeAgent = newAgent
            }
            
            // Lastly we need to update the last visible cell.
            if let currentID = currentCellID, let index = cells.firstIndex(where: { $0.id == currentID }) {
               var cellViewModel = cells[index]
               cellViewModel.agentName = activeAgent?.name ?? agent.name
               cells[index] = cellViewModel
            }
            
            currentCellID = nil
         }
      }
   }
}
