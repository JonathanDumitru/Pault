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
    var createdAt: Date
    var updatedAt: Date
    var lastUsedAt: Date?

    init(id: UUID = UUID(), title: String, content: String, attributedContent: Data? = nil, isFavorite: Bool = false, isArchived: Bool = false, createdAt: Date = Date(), updatedAt: Date = Date(), tags: [Tag] = [], templateVariables: [TemplateVariable] = [], attachments: [Attachment] = [], lastUsedAt: Date? = nil) {
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
    }

    func markAsUsed() {
        lastUsedAt = Date()
    }
}
