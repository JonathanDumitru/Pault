//
//  Tag.swift
//  Pault
//

import Foundation
import SwiftData

@Model
final class Tag {
    var id: UUID
    var name: String
    var color: String
    var createdAt: Date
    @Relationship(deleteRule: .nullify, inverse: \Prompt.tags) var prompts: [Prompt]

    init(id: UUID = UUID(), name: String, color: String = "blue", createdAt: Date = Date(), prompts: [Prompt] = []) {
        self.id = id
        self.name = name
        self.color = color
        self.createdAt = createdAt
        self.prompts = prompts
    }
}
