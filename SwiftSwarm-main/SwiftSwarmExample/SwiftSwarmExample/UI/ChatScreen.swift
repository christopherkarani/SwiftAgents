//
//  ChatScreen.swift
//  SwiftSwarmExample
//
//  Created by James Rochabrun on 10/22/24.
//

import Foundation
import SwiftOpenAI
import SwiftUI
import SwiftSwarm

struct ChatScreen: View {
   
   let viewModel: TeamDemoViewModel<TeamDemoResponseHandler>
   
   @State private var isProcessing = false
   @State private var prompt: String = ""
   @Environment(\.dismiss) private var dismiss
   
   var body: some View {
      VStack {
         clearButton
         List(viewModel.cells) { cell in
            VStack(alignment: .leading, spacing: 4) {
               if cell.role == .agent {
                  Text(cell.agentName)
                     .font(.caption)
                     .foregroundColor(.blue)
               }
               Text(cell.content)
            }
            .padding()
         }
         .safeAreaInset(edge: .bottom) {
            textArea
         }
         .listStyle(.plain)
      }
   }
   
   var clearButton: some View {
      HStack {
         Spacer()
         Button {
            Task {
               viewModel.startOver()
               prompt = ""
            }
         } label: {
            Image(systemName: "trash")
         }
         Button {
            Task {
               dismiss()
            }
         } label: {
            Image(systemName: "xmark")
         }
      }
      .padding(.horizontal)
   }
   
   var textArea: some View {
      HStack {
         TextField(text: $prompt) {
            Text("placeholder")
         }
         Button {
            Task {
               let message = ChatCompletionParameters.Message(role: .user, content: .text(prompt))
               let agent: Agent = Team.engineer.agent
               try await viewModel.handleConversation(
                  newMessages: [message],
                  initialAgent: agent)
               prompt = ""
            }
            
         } label: {
            Text("Send")
         }
         .disabled(isProcessing)
      }
      .padding()
      .background(.ultraThickMaterial)
   }
}

