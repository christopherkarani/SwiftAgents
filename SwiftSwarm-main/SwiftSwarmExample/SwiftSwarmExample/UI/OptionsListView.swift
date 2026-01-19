//
//  OptionsListView.swift
//  SwiftSwarmExample
//
//  Created by James Rochabrun on 10/22/24.
//

import Foundation
import SwiftSwarm
import SwiftOpenAI
import SwiftUI

struct OptionsListView: View {
   
   let openAIService: OpenAIService
   var options: [DemoOption]
   
   @State private var selection: DemoOption? = nil
   
   enum DemoOption: String, CaseIterable, Identifiable {
      case team = "Team"
      
      var id: String { rawValue }
   }
   
   var body: some View {
      List(options, id: \.self, selection: $selection) { option in
         HStack {
            Text(option.rawValue)
            Spacer()
            Image(systemName: "chevron.right")
         }
            .sheet(item: $selection) { selection in
               VStack {
                  Text(selection.rawValue)
                     .font(.largeTitle)
                     .padding()
                  switch selection {
                  case .team:
                     let swarm = Swarm(client: openAIService, toolResponseHandler: TeamDemoResponseHandler())
                     let viewModel = TeamDemoViewModel(swarm: swarm)
                     ChatScreen(viewModel: viewModel)
                        .frame(minWidth: 500, minHeight: 500)
                  }
               }
            }
      }
      .listStyle(.inset)
   }
}

