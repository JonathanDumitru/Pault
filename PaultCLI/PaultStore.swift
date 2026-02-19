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
        // Explicit URL required in CLI context: the app (bundle ID Jonathan-Hines-Dumitru.Pault)
        // is sandboxed, so its SwiftData store lives inside its container directory, not the
        // standard ~/Library/Application Support/ path that a CLI binary would resolve.
        let storeURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/Jonathan-Hines-Dumitru.Pault/Data/Library/Application Support/default.store")
        let config = ModelConfiguration(schema: schema, url: storeURL, isStoredInMemoryOnly: false)
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
