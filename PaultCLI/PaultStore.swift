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
        // Explicit URL required in CLI context: standalone binaries have no bundle identifier,
        // so SwiftData's default store resolution would create a different file than the app uses.
        // The app (bundle ID com.pault.app) stores its database at this path.
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let storeURL = appSupport.appendingPathComponent("com.pault.app/default.store")
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
