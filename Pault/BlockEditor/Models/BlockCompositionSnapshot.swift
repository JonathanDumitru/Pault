//
//  BlockCompositionSnapshot.swift
//  Pault
//
//  Codable snapshot of a block canvas composition for persistence
//

import Foundation

/// A Codable snapshot that captures the full state of a block canvas composition.
/// Designed to round-trip encode/decode and convert to/from live Block/BlockModifier types.
struct BlockCompositionSnapshot: Codable, Equatable {
    var blocks: [BlockSnapshot]
    var blockInputs: [String: [String: String]]  // UUID string keys for Codable
    var blockModifiers: [String: [BlockModifierSnapshot]]  // UUID string keys for Codable
    var lastCompiledHash: String?

    init(
        blocks: [BlockSnapshot] = [],
        blockInputs: [String: [String: String]] = [:],
        blockModifiers: [String: [BlockModifierSnapshot]] = [:],
        lastCompiledHash: String? = nil
    ) {
        self.blocks = blocks
        self.blockInputs = blockInputs
        self.blockModifiers = blockModifiers
        self.lastCompiledHash = lastCompiledHash
    }

    // MARK: - BlockSnapshot

    struct BlockSnapshot: Codable, Equatable {
        var id: UUID
        var title: String
        var categoryRaw: String
        var valueTypeRaw: String
        var snippet: String

        /// Create a snapshot from a live Block
        init(block: Block) {
            self.id = block.id
            self.title = block.title
            self.categoryRaw = block.category.rawValue
            self.valueTypeRaw = block.valueType.rawValue
            self.snippet = block.snippet
        }

        /// Memberwise init for testing and direct construction
        init(id: UUID = UUID(), title: String, categoryRaw: String, valueTypeRaw: String, snippet: String) {
            self.id = id
            self.title = title
            self.categoryRaw = categoryRaw
            self.valueTypeRaw = valueTypeRaw
            self.snippet = snippet
        }

        /// Convert back to a live Block, returning nil if category or valueType raw values are invalid
        func toBlock() -> Block? {
            guard let category = BlockCategory(rawValue: categoryRaw),
                  let valueType = BlockValueType(rawValue: valueTypeRaw) else {
                return nil
            }
            return Block(id: id, title: title, category: category, valueType: valueType, snippet: snippet)
        }
    }

    // MARK: - BlockModifierSnapshot

    struct BlockModifierSnapshot: Codable, Equatable {
        var id: UUID
        var name: String
        var categoryRaw: String
        var snippet: String
        var description: String

        /// Create a snapshot from a live BlockModifier
        init(modifier: BlockModifier) {
            self.id = modifier.id
            self.name = modifier.name
            self.categoryRaw = modifier.category.rawValue
            self.snippet = modifier.snippet
            self.description = modifier.description
        }

        /// Memberwise init for testing and direct construction
        init(id: UUID = UUID(), name: String, categoryRaw: String, snippet: String, description: String = "") {
            self.id = id
            self.name = name
            self.categoryRaw = categoryRaw
            self.snippet = snippet
            self.description = description
        }

        /// Convert back to a live BlockModifier, returning nil if category raw value is invalid
        func toModifier() -> BlockModifier? {
            guard let category = ModifierCategory(rawValue: categoryRaw) else {
                return nil
            }
            return BlockModifier(id: id, name: name, category: category, snippet: snippet, description: description)
        }
    }
}
