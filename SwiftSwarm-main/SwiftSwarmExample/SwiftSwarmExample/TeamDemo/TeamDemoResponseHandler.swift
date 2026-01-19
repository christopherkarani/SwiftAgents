//
//  TeamDemoResponseHandler.swift
//  SwiftSwarmExample
//
//  Created by James Rochabrun on 10/22/24.
//

import Foundation
import SwiftSwarm

struct TeamDemoResponseHandler: ToolResponseHandler {
   
   typealias AgentType = Team
   
   func handleToolResponseContent(
      parameters: [String: Any])
      async throws -> String?
   {
      return nil
   }
}
