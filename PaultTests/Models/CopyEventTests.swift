import Foundation
import Testing
import SwiftData
@testable import Pault

struct CopyEventTests {
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([CopyEvent.self])
        return try ModelContainer(for: schema, configurations: [
            ModelConfiguration(isStoredInMemoryOnly: true)
        ])
    }

    @Test func init_setsPromptID() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let id = UUID()
        let before = Date()
        let event = CopyEvent(promptID: id)
        ctx.insert(event)
        try ctx.save()

        #expect(event.promptID == id)
        let after = Date()
        #expect(event.timestamp >= before)
        #expect(event.timestamp <= after)
    }

    @Test func init_generatesUniqueInstances() {
        let e1 = CopyEvent(promptID: UUID())
        let e2 = CopyEvent(promptID: UUID())
        // Both are distinct instances with different promptIDs
        #expect(e1.promptID != e2.promptID)
    }
}
