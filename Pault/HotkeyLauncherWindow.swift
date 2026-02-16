//
//  HotkeyLauncherWindow.swift
//  Pault
//

import SwiftUI
import AppKit
import SwiftData

class HotkeyLauncherWindowController {
    private var window: NSPanel?
    private var modelContainer: ModelContainer?

    init(modelContainer: ModelContainer?) {
        self.modelContainer = modelContainer
    }

    func show() {
        if window == nil {
            createWindow()
        }

        guard let window = window else { return }

        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        window?.orderOut(nil)
    }

    func toggle() {
        if window?.isVisible == true {
            hide()
        } else {
            show()
        }
    }

    private func createWindow() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 320),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true

        if let container = modelContainer {
            let contentView = HotkeyLauncherView(onDismiss: { [weak self] in
                self?.hide()
            })
            .modelContainer(container)

            panel.contentView = NSHostingView(rootView: contentView)
        }

        self.window = panel
    }
}
