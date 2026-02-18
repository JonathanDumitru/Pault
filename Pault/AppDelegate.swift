//
//  AppDelegate.swift
//  Pault
//

import SwiftUI
import AppKit
import SwiftData
import Carbon
import os

private let appDelegateLogger = Logger(subsystem: "com.pault.app", category: "AppDelegate")

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var popoverHostingController: NSHostingController<AnyView>?
    private var launcherController: HotkeyLauncherWindowController?
    var modelContainer: ModelContainer? {
        didSet {
            updatePopoverContent()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupGlobalHotkey()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "text.bubble", accessibilityDescription: "Pault")
            button.action = #selector(statusBarButtonClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover = NSPopover()
        popover?.contentSize = NSSize(width: 320, height: 480)
        popover?.behavior = .transient
        popover?.animates = true
    }

    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()

        let openItem = NSMenuItem(title: "Open Pault", action: #selector(openMainWindow), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())

        let prefsItem = NSMenuItem(title: "Preferences…", action: Selector(("showSettingsWindow:")), keyEquivalent: ",")
        menu.addItem(prefsItem)

        let aboutItem = NSMenuItem(title: "About Pault", action: #selector(openAboutWindow), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Pault", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        // Temporarily assign menu so performClick shows it, then clear so left-click still works
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first(where: { $0.identifier?.rawValue == "main" || $0.title.isEmpty == false && !$0.isKind(of: NSPanel.self) })?.makeKeyAndOrderFront(nil)
    }

    @objc private func openAboutWindow() {
        NotificationCenter.default.post(name: .openAboutWindow, object: nil)
    }

    private func setupGlobalHotkey() {
        let modifiers = UInt32(cmdKey | shiftKey)
        let keyCode: UInt32 = 0x23 // P key

        GlobalHotkeyManager.shared.register(keyCode: keyCode, modifiers: modifiers) { [weak self] in
            self?.toggleLauncher()
        }
    }

    private func updatePopoverContent() {
        guard let container = modelContainer else { return }
        let contentView = MenuBarContentView()
            .modelContainer(container)
        popoverHostingController = NSHostingController(rootView: AnyView(contentView))
        popover?.contentViewController = popoverHostingController
    }

    @objc private func togglePopover() {
        guard let popover = popover, let button = statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func toggleLauncher() {
        if launcherController == nil {
            launcherController = HotkeyLauncherWindowController(modelContainer: modelContainer)
        }
        launcherController?.toggle()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Flush any pending SwiftData saves before exit
        if let context = modelContainer?.mainContext {
            do {
                try context.save()
            } catch {
                appDelegateLogger.error("applicationWillTerminate: Failed to save — \(error.localizedDescription)")
            }
        }
    }

    func closePopover() {
        popover?.performClose(nil)
    }
}
