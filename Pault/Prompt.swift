//
//  Prompt.swift
//  Pault
//
//  Created by Jonathan Hines Dumitru on 12/16/25.
//

import Foundation
import SwiftData

@Model
final class Prompt {
    var id: UUID
    var title: String
    var content: String
    var attributedContent: Data?
    var isFavorite: Bool
    var isArchived: Bool
    @Relationship(deleteRule: .nullify) var tags: [Tag]
    @Relationship(deleteRule: .cascade, inverse: \TemplateVariable.prompt) var templateVariables: [TemplateVariable]
    @Relationship(deleteRule: .cascade, inverse: \Attachment.prompt) var attachments: [Attachment]
    @Relationship(deleteRule: .cascade, inverse: \PromptVersion.prompt) var versions: [PromptVersion] = []
    var createdAt: Date
    var updatedAt: Date
    var lastUsedAt: Date?
    var variantB: String?    // A/B testing: alternate prompt content; nil = no variant active

    // MARK: - Block Editor Properties

    /// Serialised JSON representation of the block canvas composition
    var blockCompositionData: Data?
    /// Raw string backing for EditingMode enum
    var editingModeRaw: String?
    /// Raw string backing for BlockSyncState enum
    var blockSyncStateRaw: String?

    // MARK: - Init

    init(id: UUID = UUID(), title: String, content: String, attributedContent: Data? = nil, isFavorite: Bool = false, isArchived: Bool = false, createdAt: Date = Date(), updatedAt: Date = Date(), tags: [Tag] = [], templateVariables: [TemplateVariable] = [], attachments: [Attachment] = [], lastUsedAt: Date? = nil, blockCompositionData: Data? = nil, editingModeRaw: String? = nil, blockSyncStateRaw: String? = nil) {
        self.id = id
        self.title = title
        self.content = content
        self.attributedContent = attributedContent
        self.isFavorite = isFavorite
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.tags = tags
        self.templateVariables = templateVariables
        self.attachments = attachments
        self.lastUsedAt = lastUsedAt
        self.blockCompositionData = blockCompositionData
        self.editingModeRaw = editingModeRaw
        self.blockSyncStateRaw = blockSyncStateRaw
    }

    // MARK: - Computed Accessors

    /// The current editing mode; defaults to `.text` when no raw value is stored.
    var editingMode: EditingMode {
        get { EditingMode(rawValue: editingModeRaw ?? "") ?? .text }
        set { editingModeRaw = newValue.rawValue }
    }

    /// The block sync state; nil when no block data has ever been stored.
    var blockSyncState: BlockSyncState? {
        get {
            guard let raw = blockSyncStateRaw else { return nil }
            return BlockSyncState(rawValue: raw)
        }
        set { blockSyncStateRaw = newValue?.rawValue }
    }

    /// Decoded/encoded block composition snapshot.
    var blockComposition: BlockCompositionSnapshot? {
        get {
            guard let data = blockCompositionData else { return nil }
            return try? JSONDecoder().decode(BlockCompositionSnapshot.self, from: data)
        }
        set {
            if let value = newValue {
                blockCompositionData = try? JSONEncoder().encode(value)
            } else {
                blockCompositionData = nil
            }
        }
    }

    // MARK: - Helpers

    func markAsUsed() {
        lastUsedAt = Date()
    }
}
