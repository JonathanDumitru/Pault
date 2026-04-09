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

// MARK: - VersionSource

/// Tracks how a version was created.
/// Raw values match the source strings used in change notes and stored in the DB.
enum VersionSource: String {
    case manual             = "manual"
    case aiImprove          = "ai-improve"
    case aiVariableAccept   = "ai-variable-accept"
    case aiAutoTag          = "ai-auto-tag"
    case restore            = "restore"

    /// Returns true for any AI-originated source.
    var isAI: Bool {
        switch self {
        case .aiImprove, .aiVariableAccept, .aiAutoTag: return true
        case .manual, .restore: return false
        }
    }

    /// Human-readable badge label.
    var badgeLabel: String {
        switch self {
        case .aiImprove, .aiVariableAccept, .aiAutoTag: return "AI"
        case .manual: return "Manual"
        case .restore: return "Restore"
        }
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

    /// Stored raw source string. Defaults to "manual" for backward compat with existing rows.
    var source: String = "manual"

    /// Typed accessor over `source`. Follows the editingModeRaw/editingMode pattern.
    var versionSource: VersionSource {
        get { VersionSource(rawValue: source) ?? .manual }
        set { source = newValue.rawValue }
    }

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
        snapshotData: Data? = nil,
        source: VersionSource = .manual
    ) {
        self.id = id
        self.prompt = prompt
        self.title = title
        self.content = content
        self.savedAt = savedAt
        self.changeNote = changeNote
        self.isFavorite = isFavorite
        self.snapshotData = snapshotData
        self.source = source.rawValue
    }
}
