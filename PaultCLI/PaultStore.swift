// PaultCLI/PaultStore.swift
import Foundation
import SwiftData

/// Read-only access to the Pault SwiftData store from CLI context.
final class PaultStore {
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        let schema = Schema([Prompt.self, Tag.self, TemplateVariable.self,
                             Attachment.self, PromptRun.self, CopyEvent.self,
                             PromptVersion.self, SmartCollection.self])
        // Use the same default store location as the app (no explicit URL),
        // so SwiftData resolves the store from the bundle identifier automatically.
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    var prompts: [Prompt] {
        (try? context.fetch(FetchDescriptor<Prompt>())) ?? []
    }

    func findPrompt(title: String) -> Prompt? {
        prompts.first(where: { $0.title.localizedCaseInsensitiveContains(title) })
    }
}
