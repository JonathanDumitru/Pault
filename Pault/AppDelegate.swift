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
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover = NSPopover()
        popover?.contentSize = NSSize(width: 320, height: 480)
        popover?.behavior = .transient
        popover?.animates = true
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
