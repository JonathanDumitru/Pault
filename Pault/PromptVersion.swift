import Foundation
import SwiftData

/// Codable snapshot of prompt metadata captured at version-save time.
struct VersionSnapshot: Codable, Equatable {
    var tags: [TagSnapshot]
    var variables: [VariableSnapshot]

    struct TagSnapshot: Codable, Equatable {
        var name: String
        var color: String
    }

    struct VariableSnapshot: Codable, Equatable {
        var name: String
        var defaultValue: String
        var occurrenceIndex: Int
    }
}

@Model
final class PromptVersion {
    var id: UUID
    @Relationship(deleteRule: .nullify) var prompt: Prompt?
    var title: String
    var content: String
    var savedAt: Date
    var changeNote: String?
    var isFavorite: Bool
    var snapshotData: Data?

    /// Convenience computed property to encode/decode the VersionSnapshot.
    var snapshot: VersionSnapshot? {
        get {
            guard let data = snapshotData else { return nil }
            return try? JSONDecoder().decode(VersionSnapshot.self, from: data)
        }
        set {
            snapshotData = newValue.flatMap { try? JSONEncoder().encode($0) }
        }
    }

    init(
        id: UUID = UUID(),
        prompt: Prompt? = nil,
        title: String,
        content: String,
        savedAt: Date = Date(),
        changeNote: String? = nil,
        isFavorite: Bool = false,
        snapshotData: Data? = nil
    ) {
        self.id = id
        self.prompt = prompt
        self.title = title
        self.content = content
        self.savedAt = savedAt
        self.changeNote = changeNote
        self.isFavorite = isFavorite
        self.snapshotData = snapshotData
    }
}
