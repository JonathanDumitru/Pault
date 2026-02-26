//
//  BlockData.swift
//  Pault
//
//  Codable representation of a block for persistence (from Schemap)
//

import Foundation

/// Codable struct representing a block's data for persistence
struct BlockData: Codable, Equatable, Identifiable {
    let id: UUID
    let title: String
    let category: String // BlockCategory rawValue
    let valueType: String // BlockValueType rawValue
    let snippet: String

    init(id: UUID = UUID(), title: String, category: String, valueType: String, snippet: String) {
        self.id = id
        self.title = title
        self.category = category
        self.valueType = valueType
        self.snippet = snippet
    }
}
