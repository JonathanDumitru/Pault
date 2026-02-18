//
//  PreferencesView.swift
//  Pault
//

import SwiftUI
import SwiftData
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

            AppearanceTab()
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }

            DataTab()
                .tabItem {
                    Label("Data", systemImage: "externaldrive")
                }
        }
        .frame(width: 450, height: 320)
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

// MARK: - Appearance Tab

private struct AppearanceTab: View {
    @AppStorage("fontSizePreference") private var fontSizePreference: String = "medium"
    @AppStorage("useCompactMode") private var useCompactMode: Bool = false
    @AppStorage("accentColorPreference") private var accentColorPreference: String = "blue"

    private let accentOptions: [(label: String, key: String, color: Color)] = [
        ("Blue", "blue", .blue),
        ("Purple", "purple", .purple),
        ("Pink", "pink", .pink),
        ("Red", "red", .red),
        ("Orange", "orange", .orange),
        ("Green", "green", .green),
    ]

    var body: some View {
        Form {
            VStack(alignment: .leading, spacing: 4) {
                Picker("Font size", selection: $fontSizePreference) {
                    Text("Small").tag("small")
                    Text("Medium").tag("medium")
                    Text("Large").tag("large")
                }
                .pickerStyle(.segmented)
                .disabled(true)

                Text("Coming in a future update.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Toggle("Compact mode", isOn: $useCompactMode)
                    .disabled(true)

                Text("Coming in a future update.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Accent color")
                HStack(spacing: 10) {
                    ForEach(accentOptions, id: \.key) { option in
                        accentSwatch(option: option)
                    }
                }
            }
        }
        .padding()
    }

    private func accentSwatch(option: (label: String, key: String, color: Color)) -> some View {
        let isSelected = accentColorPreference == option.key
        return Circle()
            .fill(option.color)
            .frame(width: 22, height: 22)
            .overlay(
                Circle()
                    .strokeBorder(Color.primary.opacity(isSelected ? 0.8 : 0), lineWidth: 2)
                    .padding(2)
            )
            .onTapGesture {
                accentColorPreference = option.key
            }
            .accessibilityLabel(option.label)
            .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Data Tab

private struct DataTab: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var prompts: [Prompt]
    @Query private var tags: [Tag]

    @State private var showClearConfirm = false
    @State private var importResult: String? = nil
    @State private var showImportResult = false
    @State private var importError: String? = nil
    @State private var showImportError = false
    @State private var exportSuccess = false

    var body: some View {
        Form {
            Section("Storage") {
                LabeledContent("Prompts", value: "\(prompts.count)")
                LabeledContent("Tags", value: "\(tags.count)")
            }

            Section("Backup") {
                VStack(alignment: .leading, spacing: 6) {
                    Button("Export All Prompts…") {
                        let success = ExportService.exportAll(prompts: prompts)
                        if success {
                            exportSuccess = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                exportSuccess = false
                            }
                        }
                    }

                    if exportSuccess {
                        Label("Exported successfully", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                Button("Import Prompts…") {
                    if let count = ExportService.importPrompts(into: modelContext) {
                        importResult = count == 0
                            ? "No new prompts to import (all already exist)."
                            : "Imported \(count) prompt\(count == 1 ? "" : "s")."
                        showImportResult = true
                    } else {
                        importError = "The selected file could not be imported. It may be corrupted or in an unsupported format."
                        showImportError = true
                    }
                }
                .alert("Import Complete", isPresented: $showImportResult, presenting: importResult) { _ in
                    Button("OK") { }
                } message: { result in
                    Text(result)
                }
                .alert("Import Failed", isPresented: $showImportError, presenting: importError) { _ in
                    Button("OK") { }
                } message: { msg in
                    Text(msg)
                }

                Text("Exports include plain text only. Rich text formatting and inline images are not preserved.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Danger Zone") {
                Button("Clear All Data…", role: .destructive) {
                    showClearConfirm = true
                }
                .confirmationDialog(
                    "Delete all prompts and tags?",
                    isPresented: $showClearConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Delete Everything", role: .destructive) {
                        clearAllData()
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("This cannot be undone.")
                }
            }
        }
        .padding()
    }

    private func clearAllData() {
        do {
            for prompt in prompts { modelContext.delete(prompt) }
            for tag in tags { modelContext.delete(tag) }
            try modelContext.save()
        } catch {
            prefsLogger.error("clearAllData: \(error.localizedDescription)")
        }
    }
}

#Preview {
    PreferencesView()
}
