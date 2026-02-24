//
//  PromptTemplate.swift
//  Pault
//

import Foundation
import SwiftData

@Model
final class PromptTemplate {
    var id: UUID
    var name: String
    var content: String
    var category: String
    var isBuiltIn: Bool
    var iconName: String
    var usageCount: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        name: String,
        content: String,
        category: String,
        isBuiltIn: Bool = false,
        iconName: String = "doc.text"
    ) {
        self.id = UUID()
        self.name = name
        self.content = content
        self.category = category
        self.isBuiltIn = isBuiltIn
        self.iconName = iconName
        self.usageCount = 0
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
