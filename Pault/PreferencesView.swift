//
//  PreferencesView.swift
//  Pault
//

import SwiftUI
import SwiftData
import ServiceManagement
import Carbon
import os

private let prefsLogger = Logger(subsystem: "com.pault.app", category: "preferences")

struct PreferencesView: View {
    @AppStorage("globalHotkey") private var globalHotkey: String = "⌘⇧P"
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    @AppStorage("showDockIcon") private var showDockIcon: Bool = false
    @AppStorage("defaultAction") private var defaultAction: String = "showOptions"
    @AppStorage("versionHistoryLimit") private var versionHistoryLimit: Int = 50

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

            AISettingsTab()
                .tabItem {
                    Label("AI", systemImage: "sparkles")
                }
        }
        .frame(width: AppConstants.Windows.prefsDefault.width,
               height: AppConstants.Windows.prefsDefault.height)
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

            Stepper("Max versions per prompt: \(versionHistoryLimit)", value: $versionHistoryLimit, in: 5...200)
        }
        .padding()
    }

    private var hotkeyTab: some View {
        Form {
            HStack {
                Text("Global hotkey")
                Spacer()
                KeyRecorderView(displayString: $globalHotkey) { keyCode, modifiers in
                    UserDefaults.standard.set(Int(keyCode), forKey: "hotkeyKeyCode")
                    UserDefaults.standard.set(Int(modifiers), forKey: "hotkeyModifiers")
                    globalHotkey = KeyRecorderView.makeDisplayString(keyCode: keyCode, modifiers: modifiers)
                    GlobalHotkeyManager.shared.register(keyCode: keyCode, modifiers: modifiers) {
                        NotificationCenter.default.post(name: .toggleLauncher, object: nil)
                    }
                }
                .frame(width: 120, height: 28)
            }

            Button("Reset to Default (⌘⇧P)") {
                UserDefaults.standard.set(Int(AppConstants.Hotkey.defaultKeyCode), forKey: "hotkeyKeyCode")
                UserDefaults.standard.set(Int(AppConstants.Hotkey.defaultModifiers), forKey: "hotkeyModifiers")
                globalHotkey = "⌘⇧P"
                GlobalHotkeyManager.shared.register(keyCode: AppConstants.Hotkey.defaultKeyCode, modifiers: AppConstants.Hotkey.defaultModifiers) {
                    NotificationCenter.default.post(name: .toggleLauncher, object: nil)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .font(.caption)
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

// MARK: - AI Settings Tab

private struct AISettingsTab: View {
    private let keychain = KeychainService()

    @AppStorage("ai.model.claude") private var claudeModel: String = "claude-opus-4-6"
    @AppStorage("ai.model.openai") private var openAIModel: String = "gpt-4o"
    @AppStorage("ai.model.ollama") private var ollamaModel: String = "llama3"
    @AppStorage("ai.baseURL.ollama") private var ollamaBaseURL: String = "http://localhost:11434"

    @State private var claudeKey: String = ""
    @State private var openAIKey: String = ""

    @State private var claudeTestResult: TestResult? = nil
    @State private var openAITestResult: TestResult? = nil
    @State private var ollamaTestResult: TestResult? = nil

    enum TestResult: Equatable {
        case testing
        case ok
        case failed(String)
    }

    var body: some View {
        Form {
            // Claude
            Section("Claude") {
                HStack {
                    Text("API Key")
                    Spacer()
                    SecureField("sk-ant-…", text: $claudeKey)
                        .frame(width: 200)
                        .onSubmit { saveKey(claudeKey, for: "claude") }
                }
                HStack {
                    Text("Model")
                    Spacer()
                    TextField("claude-opus-4-6", text: $claudeModel)
                        .frame(width: 160)
                }
                testConnectionRow(result: claudeTestResult) {
                    testConnection(provider: "claude")
                }
            }

            // OpenAI
            Section("OpenAI") {
                HStack {
                    Text("API Key")
                    Spacer()
                    SecureField("sk-…", text: $openAIKey)
                        .frame(width: 200)
                        .onSubmit { saveKey(openAIKey, for: "openai") }
                }
                HStack {
                    Text("Model")
                    Spacer()
                    TextField("gpt-4o", text: $openAIModel)
                        .frame(width: 160)
                }
                testConnectionRow(result: openAITestResult) {
                    testConnection(provider: "openai")
                }
            }

            // Ollama
            Section("Ollama (Local)") {
                HStack {
                    Text("Base URL")
                    Spacer()
                    TextField("http://localhost:11434", text: $ollamaBaseURL)
                        .frame(width: 200)
                }
                HStack {
                    Text("Model")
                    Spacer()
                    TextField("llama3", text: $ollamaModel)
                        .frame(width: 160)
                }
                testConnectionRow(result: ollamaTestResult) {
                    testConnection(provider: "ollama")
                }
            }
        }
        .padding()
        .onAppear { loadKeys() }
        .onChange(of: claudeKey) { _, v in saveKey(v, for: "claude") }
        .onChange(of: openAIKey) { _, v in saveKey(v, for: "openai") }
    }

    @ViewBuilder
    private func testConnectionRow(result: TestResult?, action: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Button("Test Connection", action: action)
                .buttonStyle(.bordered)
                .disabled(result == .testing)

            switch result {
            case .testing:
                ProgressView().controlSize(.small)
            case .ok:
                Label("Connected", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            case .failed(let msg):
                Label(msg, systemImage: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(1)
            case nil:
                EmptyView()
            }
        }
    }

    private func loadKeys() {
        claudeKey = (try? keychain.load(key: "ai.apikey.claude")) ?? ""
        openAIKey = (try? keychain.load(key: "ai.apikey.openai")) ?? ""
    }

    private func saveKey(_ value: String, for provider: String) {
        guard !value.isEmpty else { return }
        try? keychain.save(key: "ai.apikey.\(provider)", value: value)
    }

    private func testConnection(provider: String) {
        let config: AIConfig
        switch provider {
        case "claude":
            claudeTestResult = .testing
            config = AIConfig(provider: .claude, model: claudeModel)
        case "openai":
            openAITestResult = .testing
            config = AIConfig(provider: .openai, model: openAIModel)
        default:
            ollamaTestResult = .testing
            config = AIConfig(provider: .ollama, model: ollamaModel, baseURL: ollamaBaseURL)
        }

        Task {
            do {
                _ = try await withThrowingTaskGroup(of: String.self) { group in
                    group.addTask {
                        try await AIService.shared.improve(prompt: "Hello", config: config)
                    }
                    group.addTask {
                        try await Task.sleep(for: .seconds(5))
                        throw AIError.missingAPIKey // timeout sentinel
                    }
                    let result = try await group.next()!
                    group.cancelAll()
                    return result
                }
                await setTestResult(.ok, for: provider)
            } catch {
                await setTestResult(.failed(error.localizedDescription), for: provider)
            }
        }
    }

    @MainActor
    private func setTestResult(_ result: TestResult, for provider: String) {
        switch provider {
        case "claude":  claudeTestResult = result
        case "openai":  openAITestResult = result
        default:        ollamaTestResult = result
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
            }

            Toggle("Compact mode", isOn: $useCompactMode)

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
            .accessibilityAddTraits(.isButton)
            .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            .accessibilityHint("Sets the app accent color")
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
    @State private var showExportError = false

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
                        } else {
                            showExportError = true
                        }
                    }
                    .alert("Export Failed", isPresented: $showExportError) {
                        Button("OK") { }
                    } message: {
                        Text("The prompts could not be saved. Check that you have write permission to the selected location.")
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
