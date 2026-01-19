//
//  ContentType+String.swift
//
//
//  Created by James Rochabrun on 10/22/24.
//

import Foundation
import SwiftOpenAI

public extension ChatCompletionParameters.Message.ContentType {
   
   var text: String? {
      switch self {
      case .text(let string):
         return string
      default:
         return nil
      }
   }
}
