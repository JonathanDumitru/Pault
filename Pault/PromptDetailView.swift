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
    @State private var saveTask: Task<Void, Never>?
    @State private var syncTask: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 0) {
            // Main editor
            VStack(alignment: .leading, spacing: 0) {
                // Title field
                TextField("Untitled", text: $prompt.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 12)
                    .onChange(of: prompt.title) { _, _ in
                        debouncedSave()
                    }

                // Content editor
                RichTextEditor(
                    attributedContent: $prompt.attributedContent,
                    plainContent: $prompt.content
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
        .overlay(alignment: .bottomTrailing) {
            Button(action: { showInspector.toggle() }) {
                Image(systemName: "info.circle")
                    .font(.title2)
                    .foregroundStyle(showInspector ? .blue : .secondary)
                    .padding(12)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("i", modifiers: .command)
            .help("Toggle Inspector (⌘I)")
        }
        .onChange(of: prompt.isFavorite) { _, _ in
            debouncedSave()
        }
        .onChange(of: prompt.isArchived) { _, _ in
            debouncedSave()
        }
        .onChange(of: prompt.tags) { _, _ in
            debouncedSave()
        }
    }

    private func debouncedSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                prompt.updatedAt = Date()
                do {
                    try modelContext.save()
                } catch {
                    detailLogger.error("debouncedSave: Failed — \(error.localizedDescription)")
                }
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
