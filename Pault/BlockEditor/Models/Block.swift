//
//  Block.swift
//  Pault
//
//  Block model for library and canvas (from Schemap)
//

import Foundation
import UniformTypeIdentifiers
import CoreTransferable

/// A block in the library or on the canvas
struct Block: Identifiable, Hashable {
    let id: UUID
    let title: String
    let category: BlockCategory
    let valueType: BlockValueType
    let snippet: String

    init(id: UUID = UUID(), title: String, category: BlockCategory, valueType: BlockValueType, snippet: String) {
        self.id = id
        self.title = title
        self.category = category
        self.valueType = valueType
        self.snippet = snippet
    }
}

/// Lightweight transferable wrapper for dragging Blocks across views
struct BlockDragItem: Codable, Hashable, Transferable {
    var id: UUID?
    var title: String
    var categoryRaw: String
    var valueTypeRaw: String
    var snippet: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: UTType.data)
    }

    init(block: Block) {
        self.id = block.id
        self.title = block.title
        self.categoryRaw = block.category.rawValue
        self.valueTypeRaw = block.valueType.rawValue
        self.snippet = block.snippet
    }

    init(libraryBlock block: Block) {
        self.id = nil
        self.title = block.title
        self.categoryRaw = block.category.rawValue
        self.valueTypeRaw = block.valueType.rawValue
        self.snippet = block.snippet
    }

    func toBlock() -> Block? {
        guard let cat = BlockCategory(rawValue: categoryRaw),
              let vt = BlockValueType(rawValue: valueTypeRaw) else { return nil }
        return Block(id: id ?? UUID(), title: title, category: cat, valueType: vt, snippet: snippet)
    }
}
