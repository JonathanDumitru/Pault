//
//  BlockModifier.swift
//  Pault
//
//  Block modifier model for attaching modifiers to components (from Schemap)
//

import Foundation
import UniformTypeIdentifiers
import CoreTransferable

/// A modifier that can be attached to a block to modify its behavior
struct BlockModifier: Identifiable, Hashable {
    let id: UUID
    let name: String
    let category: ModifierCategory
    let snippet: String
    let description: String

    init(id: UUID = UUID(), name: String, category: ModifierCategory, snippet: String, description: String = "") {
        self.id = id
        self.name = name
        self.category = category
        self.snippet = snippet
        self.description = description
    }
}

/// Lightweight transferable wrapper for dragging modifiers
struct ModifierDragItem: Codable, Hashable, Transferable {
    var id: UUID?
    var name: String
    var categoryRaw: String
    var snippet: String
    var description: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: UTType.data)
    }

    init(modifier: BlockModifier) {
        self.id = modifier.id
        self.name = modifier.name
        self.categoryRaw = modifier.category.rawValue
        self.snippet = modifier.snippet
        self.description = modifier.description
    }

    init(libraryModifier modifier: BlockModifier) {
        self.id = nil
        self.name = modifier.name
        self.categoryRaw = modifier.category.rawValue
        self.snippet = modifier.snippet
        self.description = modifier.description
    }

    func toModifier() -> BlockModifier? {
        guard let cat = ModifierCategory(rawValue: categoryRaw) else { return nil }
        return BlockModifier(id: id ?? UUID(), name: name, category: cat, snippet: snippet, description: description)
    }
}

/// Represents a block on the canvas with its attached modifiers
struct CanvasBlockWithModifiers: Identifiable, Hashable {
    let id: UUID
    let block: Block
    var modifiers: [BlockModifier]

    init(id: UUID = UUID(), block: Block, modifiers: [BlockModifier] = []) {
        self.id = id
        self.block = block
        self.modifiers = modifiers
    }

    /// Add a modifier to this block
    mutating func addModifier(_ modifier: BlockModifier) {
        // Create new instance with unique ID
        let newModifier = BlockModifier(
            name: modifier.name,
            category: modifier.category,
            snippet: modifier.snippet,
            description: modifier.description
        )
        modifiers.append(newModifier)
    }

    /// Remove a modifier from this block
    mutating func removeModifier(at index: Int) {
        guard index < modifiers.count else { return }
        modifiers.remove(at: index)
    }

    /// Remove a modifier by ID
    mutating func removeModifier(withID id: UUID) {
        modifiers.removeAll { $0.id == id }
    }
}

/// Data structure for persisting modifiers
struct ModifierData: Codable, Hashable {
    let id: UUID
    let name: String
    let category: String
    let snippet: String
    let description: String

    init(from modifier: BlockModifier) {
        self.id = modifier.id
        self.name = modifier.name
        self.category = modifier.category.rawValue
        self.snippet = modifier.snippet
        self.description = modifier.description
    }

    func toModifier() -> BlockModifier? {
        guard let cat = ModifierCategory(rawValue: category) else { return nil }
        return BlockModifier(id: id, name: name, category: cat, snippet: snippet, description: description)
    }
}
