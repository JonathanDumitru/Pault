//
//  PreferencesView.swift
//  Pault
//

import SwiftUI
import ServiceManagement
import os

private let prefsLogger = Logger(subsystem: "com.pault.app", category: "preferences")

struct PreferencesView: View {
    @AppStorage("globalHotkey") private var globalHotkey: String = "⌘⇧P"
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    @AppStorage("showDockIcon") private var showDockIcon: Bool = false
    @AppStorage("defaultAction") private var defaultAction: String = "showOptions"

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            hotkeyTab
                .tabItem {
                    Label("Hotkey", systemImage: "keyboard")
                }
        }
        .frame(width: 450, height: 250)
    }

    private var generalTab: some View {
        Form {
            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    setLaunchAtLogin(newValue)
                }

            Toggle("Show dock icon", isOn: $showDockIcon)
                .onChange(of: showDockIcon) { _, newValue in
                    setDockIconVisibility(newValue)
                }

            Picker("Default action", selection: $defaultAction) {
                Text("Show options").tag("showOptions")
                Text("Copy to clipboard").tag("copy")
            }
        }
        .padding()
    }

    private var hotkeyTab: some View {
        Form {
            HStack {
                Text("Global hotkey")
                Spacer()
                Text(globalHotkey)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Text("Press ⌘⇧P from anywhere to open the quick launcher.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            prefsLogger.error("Failed to set launch at login: \(error.localizedDescription)")
        }
    }

    private func setDockIconVisibility(_ visible: Bool) {
        if visible {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

#Preview {
    PreferencesView()
}
