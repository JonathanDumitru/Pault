//
//  CustomBlock.swift
//  Pault
//
//  SwiftData model for user-created custom blocks (from Schemap)
//

import Foundation
import SwiftData

/// SwiftData model for user-created custom blocks
@Model
final class CustomBlock {
    @Attribute(.unique) var id: UUID
    var title: String
    var category: String // BlockCategory rawValue
    var valueType: String // BlockValueType rawValue
    var snippet: String
    var userCreated: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        category: String,
        valueType: String,
        snippet: String,
        userCreated: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.valueType = valueType
        self.snippet = snippet
        self.userCreated = userCreated
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Validate the custom block
    func validate() -> [String] {
        var errors: [String] = []

        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Block title is required")
        }

        if snippet.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Block snippet is required")
        }

        // Validate placeholder names in snippet
        let placeholders = InputValidator.extractPlaceholderNames(from: snippet)
        for placeholder in placeholders {
            let validation = InputValidator.validatePlaceholderName(placeholder)
            if !validation.isValid {
                errors.append("Invalid placeholder '\(placeholder)': \(validation.errorMessage ?? "invalid format")")
            }
        }

        return errors
    }
}
