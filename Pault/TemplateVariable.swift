//
//  TemplateVariable.swift
//  Pault
//

import Foundation
import SwiftData

@Model
final class TemplateVariable {
    var id: UUID
    var name: String
    var defaultValue: String
    var sortOrder: Int           // Global position among all variables in the content (0, 1, 2, ...)
    var occurrenceIndex: Int     // 0-based index among same-name occurrences (e.g. first {{name}} = 0, second = 1)
    @Relationship var prompt: Prompt?

    init(id: UUID = UUID(), name: String, defaultValue: String = "", sortOrder: Int = 0, occurrenceIndex: Int = 0) {
        self.id = id
        self.name = name
        self.defaultValue = defaultValue
        self.sortOrder = sortOrder
        self.occurrenceIndex = occurrenceIndex
    }
}
