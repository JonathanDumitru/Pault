import Foundation
import Testing
import SwiftData
@testable import Pault

struct PromptVersionTests {
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Prompt.self,
            TemplateVariable.self,
            Pault.Tag.self,
            Attachment.self,
            CopyEvent.self,
            PromptRun.self,
            PromptVersion.self,
        ])
        return try ModelContainer(for: schema, configurations: [
            ModelConfiguration(isStoredInMemoryOnly: true)
        ])
    }

    @Test func init_setsAllFields() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let fixedID = UUID()
        let fixedDate = Date()

        let version = PromptVersion(
            id: fixedID,
            title: "My Prompt",
            content: "Do the thing",
            savedAt: fixedDate,
            changeNote: "Added CoT reasoning"
        )
        ctx.insert(version)
        try ctx.save()

        #expect(version.id == fixedID)
        #expect(version.title == "My Prompt")
        #expect(version.content == "Do the thing")
        #expect(version.savedAt == fixedDate)
        #expect(version.changeNote == "Added CoT reasoning")
        #expect(version.prompt == nil)
    }

    @Test func init_defaultsChangeNoteToNil() {
        let version = PromptVersion(title: "Title", content: "Content")
        #expect(version.changeNote == nil)
    }

    @Test func savedAt_isWithinReasonableBounds() {
        let before = Date()
        let version = PromptVersion(title: "T", content: "C")
        let after = Date()

        #expect(version.savedAt >= before)
        #expect(version.savedAt <= after)
    }

    @Test func multipleVersions_canBeInserted() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let v1 = PromptVersion(title: "Draft", content: "First version")
        let v2 = PromptVersion(title: "Draft", content: "Second version", changeNote: "Refined tone")
        let v3 = PromptVersion(title: "Draft", content: "Third version", changeNote: "Added examples")
        ctx.insert(v1)
        ctx.insert(v2)
        ctx.insert(v3)
        try ctx.save()

        let descriptor = FetchDescriptor<PromptVersion>()
        let results = try ctx.fetch(descriptor)
        #expect(results.count == 3)
        #expect(v1.id != v2.id)
        #expect(v2.id != v3.id)
        #expect(v1.id != v3.id)
    }
}
