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
        // Explicit URL required in CLI context: the app is sandboxed, so its SwiftData store
        // lives inside the sandbox container directory rather than the standard Library path.
        // Read the app's bundle ID from the CLI's Info.plist key "PaultAppBundleID" so this
        // doesn't break if the bundle identifier changes. Falls back to the production default.
        let appBundleID = Bundle.main.object(forInfoDictionaryKey: "PaultAppBundleID") as? String
            ?? "Jonathan-Hines-Dumitru.Pault"
        let storeURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/\(appBundleID)/Data/Library/Application Support/default.store")
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
