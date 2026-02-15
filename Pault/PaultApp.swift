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
}

@main
struct PaultApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var showDataError: Bool = false

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Prompt.self,
            Tag.self,
            TemplateVariable.self,
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
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 900, height: 600)
        .modelContainer(sharedModelContainer)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Prompt") {
                    NotificationCenter.default.post(name: .createNewPrompt, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }

        Settings {
            PreferencesView()
        }

        Window("New Prompt", id: "new-prompt") {
            NewPromptView()
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 600, height: 500)
        .modelContainer(sharedModelContainer)
    }

    init() {
        // Pass model container to AppDelegate synchronously to avoid race condition
        appDelegate.modelContainer = sharedModelContainer
    }
}
