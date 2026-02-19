import Foundation
import SwiftData

@Model
final class CopyEvent {
    var promptID: UUID
    var timestamp: Date

    init(promptID: UUID) {
        self.promptID = promptID
        self.timestamp = Date()
    }
}
