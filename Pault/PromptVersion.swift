import Foundation
import SwiftData

@Model
final class PromptVersion {
    var id: UUID
    @Relationship(deleteRule: .nullify) var prompt: Prompt?
    var title: String
    var content: String
    var savedAt: Date
    var changeNote: String?

    init(
        id: UUID = UUID(),
        prompt: Prompt? = nil,
        title: String,
        content: String,
        savedAt: Date = Date(),
        changeNote: String? = nil
    ) {
        self.id = id
        self.prompt = prompt
        self.title = title
        self.content = content
        self.savedAt = savedAt
        self.changeNote = changeNote
    }
}
