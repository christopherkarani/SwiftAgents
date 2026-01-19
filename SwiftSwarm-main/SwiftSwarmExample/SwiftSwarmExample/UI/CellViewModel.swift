//
//  CellViewModel.swift
//  SwiftSwarmExample
//
//  Created by James Rochabrun on 10/22/24.
//

import Foundation

struct CellViewModel: Identifiable {
   let id = UUID()
   var content: String
   var role: Role
   var agentName: String
   
   enum Role {
      case user
      case agent
      case tool
   }
}
