import Foundation
import SwiftData

// MARK: - UsageEventType

enum UsageEventType: String, CaseIterable {
    case copy = "copy"
    case created = "created"
    case edited = "edited"
    case deleted = "deleted"
}

// MARK: - CopyEvent

@Model
final class CopyEvent {
    var promptID: UUID
    var timestamp: Date
    /// Raw backing field — default "copy" preserves backward compatibility for existing rows.
    var eventType: String = "copy"

    // MARK: Computed type accessor (mirrors editingModeRaw/editingMode pattern)

    var type: UsageEventType {
        get { UsageEventType(rawValue: eventType) ?? .copy }
        set { eventType = newValue.rawValue }
    }

    // MARK: Inits

    /// Legacy init — still works for all existing call sites.
    init(promptID: UUID) {
        self.promptID = promptID
        self.timestamp = Date()
        self.eventType = UsageEventType.copy.rawValue
    }

    /// Convenience init used by AnalyticsService.recordEvent.
    init(promptID: UUID, type: UsageEventType) {
        self.promptID = promptID
        self.timestamp = Date()
        self.eventType = type.rawValue
    }
}
