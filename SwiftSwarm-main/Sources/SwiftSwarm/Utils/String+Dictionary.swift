//
//  String+Dictionary.swift
//
//
//  Created by James Rochabrun on 10/22/24.
//

import Foundation

public extension String {
   
   /// Converts a JSON-formatted string into a dictionary. This is useful for `ToolCallDefinition` conformers
   /// to transform the LLM's argument response, which is a JSON string, into a dictionary for easier value retrieval.
   func toDictionary() -> [String: Any]? {
      guard let data = data(using: .utf8) else { return nil }
      return try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
   }
}
