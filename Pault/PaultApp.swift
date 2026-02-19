//
//  PaultApp.swift
//  Pault
//
//  Created by Jonathan Hines Dumitru on 12/16/25.
//

import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: "com.pault.app", category: "lifecycle")

extension Notification.Name {
    static let createNewPrompt = Notification.Name("com.pault.createNewPrompt")
    static let promptCreated = Notification.Name("com.pault.promptCreated")
    static let insertInlineImage = Notification.Name("com.pault.insertInlineImage")
    static let openAboutWindow = Notification.Name("com.pault.openAboutWindow")
    static let toggleLauncher = Notification.Name("com.pault.toggleLauncher")
}

@main
struct PaultApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openWindow) private var openWindow
    @AppStorage("accentColorPreference") private var accentColorPreference: String = "blue"

    @State private var showDataError: Bool = false

    private var accentColor: Color {
        switch accentColorPreference {
        case "purple": return .purple
        case "pink":   return .pink
        case "red":    return .red
        case "orange": return .orange
        case "green":  return .green
        default:       return .blue
        }
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Prompt.self,
            Tag.self,
            TemplateVariable.self,
            Attachment.self,
            PromptRun.self,
            CopyEvent.self,
            PromptVersion.self,
        ])
        let persistentConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [persistentConfig])
        } catch {
            logger.error("SwiftData persistent store failed: \(error.localizedDescription). Falling back to in-memory store.")
            let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [memoryConfig])
            } catch {
                logger.fault("In-memory ModelContainer also failed: \(error.localizedDescription). Creating bare container.")
                // Last resort: bare container with no configuration — should never fail
                return try! ModelContainer(for: schema)
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(accentColor)
                .onReceive(NotificationCenter.default.publisher(for: .openAboutWindow)) { _ in
                    openWindow(id: "about")
                }
        }
        .windowResizability(.contentSize)
        .defaultSize(AppConstants.Windows.mainDefault)
        .modelContainer(sharedModelContainer)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Prompt") {
                    NotificationCenter.default.post(name: .createNewPrompt, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            CommandGroup(replacing: .appInfo) {
                Button("About Pault") {
                    openWindow(id: "about")
                }
            }
        }

        Settings {
            PreferencesView()
        }
        .modelContainer(sharedModelContainer)

        Window("About Pault", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
        .defaultSize(AppConstants.Windows.aboutDefault)

        Window("New Prompt", id: "new-prompt") {
            NewPromptView()
        }
        .windowResizability(.contentMinSize)
        .defaultSize(AppConstants.Windows.promptDefault)
        .modelContainer(sharedModelContainer)

        WindowGroup("Edit Prompt", for: UUID.self) { $promptID in
            if let promptID {
                EditPromptView(promptID: promptID)
            }
        }
        .windowResizability(.contentMinSize)
        .defaultSize(AppConstants.Windows.promptDefault)
        .modelContainer(sharedModelContainer)
    }

    init() {
        // Pass model container to AppDelegate synchronously to avoid race condition
        appDelegate.modelContainer = sharedModelContainer

        // One-time migration: "paste" action removed in 2.5B — fall back to "copy"
        if UserDefaults.standard.string(forKey: "defaultAction") == "paste" {
            UserDefaults.standard.set("copy", forKey: "defaultAction")
        }
    }
}
