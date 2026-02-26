//
//  PromptDetailView.swift
//  Pault
//
//  Created by Jonathan Hines Dumitru on 12/16/25.
//

import SwiftUI
import SwiftData
import os

#if os(macOS)
import AppKit
#endif

private let detailLogger = Logger(subsystem: "com.pault.app", category: "PromptDetail")

struct PromptDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var prompt: Prompt

    @Binding var showInspector: Bool

    private var service: PromptService { PromptService(modelContext: modelContext) }

    @State private var saveTask: Task<Void, Never>?
    @State private var syncTask: Task<Void, Never>?
    @State private var showResponsePanel: Bool = false
    @State private var showPaywall: Bool = false
    @State private var responseConfig: AIConfig = AIConfig.defaults[.claude] ?? AIConfig(provider: .claude, model: "claude-opus-4-6")
    @State private var showVariantB: Bool = false
    @State private var showABResult: Bool = false
    @State private var abRunA: PromptRun? = nil
    @State private var abRunB: PromptRun? = nil
    @State private var isRunningAB: Bool = false
    @State private var showAIPanel: Bool = false
    @State private var aiError: String? = nil
    @AppStorage("versionHistoryLimit") private var versionHistoryLimit: Int = 50
    @AppStorage("coachingDismissedVariables") private var coachingDismissedVariables = false
    @AppStorage("coachingDismissedTags") private var coachingDismissedTags = false
    @AppStorage("hasDiscoveredAIAssist") private var hasDiscoveredAIAssist = false
    @State private var showSaveAsTemplate = false
    @State private var templateName = ""
    @State private var templateCategory = "General"

    // Block Editor state
    @State private var showModeSwitchDialog = false
    @State private var showBlocksToTextWarning = false
    @State private var isParsingTextToBlocks = false

    private var coachingTip: (message: String, icon: String)? {
        if prompt.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !coachingDismissedVariables {
            return ("Use {{variable_name}} to create reusable placeholders", "lightbulb")
        }
        if !prompt.content.isEmpty
            && prompt.templateVariables.isEmpty
            && !coachingDismissedVariables {
            return ("Add {{variables}} to make this prompt reusable across different contexts", "lightbulb")
        }
        if !prompt.templateVariables.isEmpty
            && prompt.tags.isEmpty
            && !coachingDismissedTags {
            return ("Add tags to organize and find your prompts quickly", "tag")
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar with title and mode toggle
            promptToolbar

            Divider()

            // Content area - switches between text and blocks mode
            if prompt.editingMode == .blocks {
                BlockEditorView(prompt: prompt)
            } else {
                textEditorContent
            }
        }
        .overlay {
            // Parsing progress overlay
            if isParsingTextToBlocks {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)

                        Text("Analyzing prompt structure...")
                            .font(.headline)

                        Text("AI is parsing your text into blocks")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(32)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: prompt.editingMode)
        .animation(.easeInOut(duration: 0.3), value: isParsingTextToBlocks)
        .onChange(of: prompt.isFavorite) { _, _ in
            debouncedSave()
        }
        .onChange(of: prompt.isArchived) { _, _ in
            debouncedSave()
        }
        .onChange(of: prompt.tags) { _, _ in
            debouncedSave()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(featureName: "API Runner", featureDescription: "Run prompts directly against any LLM without leaving Pault.", featureIcon: "play.circle.fill")
        }
        .alert("AI Error", isPresented: Binding(
            get: { aiError != nil },
            set: { if !$0 { aiError = nil } }
        )) {
            Button("OK") { aiError = nil }
        } message: {
            if let msg = aiError { Text(msg) }
        }
        .sheet(isPresented: $showABResult) {
            if let a = abRunA, let b = abRunB {
                ABTestResultView(prompt: prompt, runA: a, runB: b)
            }
        }
        .sheet(isPresented: $showSaveAsTemplate) {
            SaveAsTemplateSheet(
                name: $templateName,
                category: $templateCategory,
                onSave: {
                    let template = PromptTemplate(
                        name: templateName,
                        content: prompt.content,
                        category: templateCategory
                    )
                    modelContext.insert(template)
                    try? modelContext.save()
                    showSaveAsTemplate = false
                },
                onCancel: { showSaveAsTemplate = false }
            )
        }
        .sheet(isPresented: $showModeSwitchDialog) {
            ModeSwitchDialogView(
                isPresented: $showModeSwitchDialog,
                hasExistingContent: !prompt.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                isPro: ProStatusManager.shared.isProUnlocked,
                onParse: switchToBlocksWithParse,
                onStartFresh: switchToBlocksStartFresh,
                onShowPaywall: { showPaywall = true }
            )
        }
        .sheet(isPresented: $showBlocksToTextWarning) {
            BlocksToTextWarningView(
                isPresented: $showBlocksToTextWarning,
                onConfirm: switchToText
            )
        }
    }

    // MARK: - Toolbar

    private var promptToolbar: some View {
        HStack(spacing: 12) {
            // Title field
            TextField("Untitled", text: $prompt.title)
                .font(.title2)
                .fontWeight(.semibold)
                .textFieldStyle(.plain)
                .onChange(of: prompt.title) { _, _ in
                    debouncedSave()
                }

            Spacer()

            // Mode toggle: Text | Blocks
            Picker("", selection: Binding(
                get: { prompt.editingMode },
                set: { newMode in handleModeChange(to: newMode) }
            )) {
                Label("Text", systemImage: "doc.text")
                    .tag(EditingMode.text)
                Label("Blocks", systemImage: "square.stack.3d.up")
                    .tag(EditingMode.blocks)
            }
            .pickerStyle(.segmented)
            .frame(width: 160)

            // Sync state indicator (when in blocks mode)
            if prompt.editingMode == .blocks, let syncState = prompt.blockSyncState {
                HStack(spacing: 4) {
                    Circle()
                        .fill(syncState == .synced ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                    Text(syncState == .synced ? "Synced" : "Diverged")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Text Editor Content

    private var textEditorContent: some View {
        HStack(spacing: 0) {
            // Main editor
            VStack(alignment: .leading, spacing: 0) {
                // Contextual coaching tip
                if let tip = coachingTip {
                    HStack(spacing: 8) {
                        Image(systemName: tip.icon)
                            .foregroundStyle(.blue)
                            .font(.caption)
                        Text(tip.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(action: dismissCurrentTip) {
                            Image(systemName: "xmark")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.05))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Content editor — switches to variantB when A/B mode is active
                RichTextEditor(
                    attributedContent: showVariantB ? .constant(nil) : $prompt.attributedContent,
                    plainContent: showVariantB ? Binding(
                        get: { prompt.variantB ?? "" },
                        set: { prompt.variantB = $0 }
                    ) : $prompt.content
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .onChange(of: prompt.content) { _, _ in
                    debouncedSave()
                    debouncedSyncVariables()
                }
                .onChange(of: prompt.attributedContent) { _, _ in
                    debouncedSave()
                }

                // Template variables (shown when {{variables}} exist in content)
                TemplateVariablesView(prompt: prompt)

                // Attachments strip
                AttachmentsStripView(prompt: prompt)

                // AI Assist panel (shown when sparkles button is active)
                if showAIPanel {
                    AIAssistPanel(prompt: prompt, config: responseConfig)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Streaming response panel (shown when run is active)
                if showResponsePanel {
                    ResponsePanel(prompt: prompt, config: responseConfig)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Inspector panel
            if showInspector {
                Divider()
                InspectorView(prompt: prompt)
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showInspector)
        .animation(.easeInOut(duration: 0.2), value: showResponsePanel)
        .animation(.easeInOut(duration: 0.2), value: showAIPanel)
        .overlay(alignment: .bottomTrailing) {
            textEditorToolbarOverlay
        }
    }

    // MARK: - Text Editor Toolbar Overlay

    private var textEditorToolbarOverlay: some View {
        HStack(spacing: 0) {
            // A/B variant A|B picker (only when variantB exists)
            if prompt.variantB != nil {
                Picker("", selection: $showVariantB) {
                    Text("A").tag(false)
                    Text("B").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 80)
                .padding(8)

                // Run A/B button
                if !isRunningAB {
                    Button(action: runABTest) {
                        Label("Run A/B", systemImage: "arrow.left.arrow.right")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .padding(.trailing, 4)
                } else {
                    ProgressView()
                        .controlSize(.small)
                        .padding(12)
                }
            }

            // A/B activate button
            Button(action: activateABMode) {
                Image(systemName: prompt.variantB != nil ? "a.square.fill" : "a.square")
                    .font(.title2)
                    .foregroundStyle(prompt.variantB != nil ? .purple : .secondary)
                    .padding(12)
            }
            .buttonStyle(.plain)
            .help(prompt.variantB != nil ? "A/B mode active — run test to compare" : "Create variant B for A/B testing (Pro)")

            // AI Assist button (Pro)
            Button(action: {
                guard ProStatusManager.shared.isProUnlocked else { showPaywall = true; return }
                showAIPanel.toggle()
                if !hasDiscoveredAIAssist { hasDiscoveredAIAssist = true }
            }) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundStyle(showAIPanel ? .blue : .secondary)
                        .padding(12)

                    if ProStatusManager.shared.isProUnlocked && !hasDiscoveredAIAssist {
                        Circle()
                            .fill(.blue)
                            .frame(width: 8, height: 8)
                            .offset(x: -4, y: 4)
                    }
                }
            }
            .buttonStyle(.plain)
            .help("AI Assist (Pro)")

            // Run button (Pro)
            Button(action: {
                guard ProStatusManager.shared.isProUnlocked else { showPaywall = true; return }
                showResponsePanel.toggle()
            }) {
                Image(systemName: showResponsePanel ? "play.circle.fill" : "play.circle")
                    .font(.title2)
                    .foregroundStyle(showResponsePanel ? .blue : .secondary)
                    .padding(12)
            }
            .buttonStyle(.plain)
            .help("Run prompt (Pro)")

            // Save as Template button
            Button(action: {
                templateName = prompt.title
                showSaveAsTemplate = true
            }) {
                Image(systemName: "rectangle.stack.badge.plus")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .padding(12)
            }
            .buttonStyle(.plain)
            .help("Save as Template")

            // Inspector toggle
            Button(action: { showInspector.toggle() }) {
                Image(systemName: "info.circle")
                    .font(.title2)
                    .foregroundStyle(showInspector ? .blue : .secondary)
                    .padding(12)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("i", modifiers: .command)
            .help("Toggle Inspector (⌘I)")
            .accessibilityLabel(showInspector ? "Hide inspector" : "Show inspector")
        }
    }

    // MARK: - Mode Switching

    private func handleModeChange(to newMode: EditingMode) {
        if newMode == .blocks && prompt.editingMode == .text {
            // Switching from Text to Blocks
            showModeSwitchDialog = true
        } else if newMode == .text && prompt.editingMode == .blocks {
            // Switching from Blocks to Text
            if prompt.blockSyncState == .diverged {
                showBlocksToTextWarning = true
            } else {
                prompt.editingMode = .text
            }
        }
    }

    private func switchToBlocksStartFresh() {
        prompt.editingMode = .blocks
        // Block composition stays as-is (or empty if none)
        prompt.blockSyncState = nil
    }

    private func switchToBlocksWithParse() {
        isParsingTextToBlocks = true

        Task { @MainActor in
            do {
                let snapshot = try await TextToBlocksService.shared.parseTextToBlocks(text: prompt.content)
                prompt.blockComposition = snapshot
                prompt.editingMode = .blocks
                prompt.blockSyncState = .synced
                isParsingTextToBlocks = false
            } catch {
                isParsingTextToBlocks = false
                aiError = error.localizedDescription
            }
        }
    }

    private func switchToText() {
        prompt.editingMode = .text
    }

    private func activateABMode() {
        guard ProStatusManager.shared.isProUnlocked else { showPaywall = true; return }
        if prompt.variantB == nil {
            prompt.variantB = prompt.content   // seed B from A
            showVariantB = true
        } else {
            prompt.variantB = nil              // deactivate
            showVariantB = false
        }
    }

    private func runABTest() {
        guard let variantB = prompt.variantB else { return }
        isRunningAB = true
        let configA = responseConfig
        let configB = responseConfig
        let vars: [String: String] = prompt.templateVariables.reduce(into: [:]) { $0[$1.name] = $1.defaultValue }
        let contentA = prompt.content
        let contentB = variantB
        let titleSnapshot = prompt.title

        Task {
            async let outputA = collectStream(prompt: contentA, variables: vars, config: configA)
            async let outputB = collectStream(prompt: contentB, variables: vars, config: configB)
            do {
                let (resultA, latA) = try await outputA
                let (resultB, latB) = try await outputB
                await MainActor.run {
                    let runA = PromptRun(promptTitle: titleSnapshot, resolvedInput: contentA,
                                         output: resultA, model: configA.model,
                                         provider: configA.provider.rawValue, latencyMs: latA,
                                         variantLabel: "A")
                    let runB = PromptRun(promptTitle: titleSnapshot, resolvedInput: contentB,
                                         output: resultB, model: configB.model,
                                         provider: configB.provider.rawValue, latencyMs: latB,
                                         variantLabel: "B")
                    runA.prompt = prompt
                    runB.prompt = prompt
                    modelContext.insert(runA)
                    modelContext.insert(runB)
                    try? modelContext.save()
                    abRunA = runA
                    abRunB = runB
                    isRunningAB = false
                    showABResult = true
                }
            } catch {
                await MainActor.run {
                    isRunningAB = false
                    aiError = error.localizedDescription
                }
            }
        }
    }

    private func collectStream(prompt: String, variables: [String: String], config: AIConfig) async throws -> (String, Int) {
        let start = Date()
        let stream = try await AIService.shared.streamRun(prompt: prompt, variables: variables, config: config)
        var result = ""
        for try await token in stream { result += token }
        return (result, Int(Date().timeIntervalSince(start) * 1000))
    }

    private func dismissCurrentTip() {
        withAnimation {
            if prompt.content.isEmpty || prompt.templateVariables.isEmpty {
                coachingDismissedVariables = true
            } else if prompt.tags.isEmpty {
                coachingDismissedTags = true
            }
        }
    }

    private func debouncedSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                prompt.updatedAt = Date()
                service.saveSnapshot(for: prompt, limit: versionHistoryLimit)
            }
        }
    }

    private func debouncedSyncVariables() {
        syncTask?.cancel()
        syncTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                TemplateEngine.syncVariables(for: prompt, in: modelContext)
            }
        }
    }
}

private struct SaveAsTemplateSheet: View {
    @Binding var name: String
    @Binding var category: String
    let onSave: () -> Void
    let onCancel: () -> Void

    private let categories = ["General", "Writing", "Engineering", "Productivity", "Analysis"]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Save as Template")
                    .font(.headline)
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            Form {
                TextField("Template Name", text: $name)
                Picker("Category", selection: $category) {
                    ForEach(categories, id: \.self) { cat in
                        Text(cat).tag(cat)
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("Save Template", action: onSave)
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .frame(width: 360, height: 240)
    }
}

struct EmptyDetailView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("Select a prompt or press ⌘N to create one")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
