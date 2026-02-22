//
//  PromptDiffView.swift
//  Pault
//

import SwiftUI
import SwiftData

struct PromptDiffView: View {
    let version: PromptVersion
    @Bindable var prompt: Prompt

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @AppStorage("versionHistoryLimit") private var versionHistoryLimit: Int = 50

    @State private var diffMode: DiffMode = .sideBySide
    @State private var showRestorePreview = false
    @State private var restoreContent = true
    @State private var restoreTitle = true
    @State private var restoreTags = true
    @State private var restoreVariables = true
    @State private var restoreFavorite = true

    private var service: PromptService { PromptService(modelContext: modelContext) }

    private var dateString: String {
        version.savedAt.formatted(date: .abbreviated, time: .shortened)
    }

    private var diffs: [DiffEngine.LineDiff] {
        DiffEngine.diff(old: version.content, new: prompt.content)
    }

    enum DiffMode: String, CaseIterable {
        case inline = "Inline"
        case sideBySide = "Side by Side"
    }

    // MARK: - Metadata change detection

    private var titleChanged: Bool { version.title != prompt.title }
    private var contentChanged: Bool { version.content != prompt.content }
    private var favoriteChanged: Bool { version.isFavorite != prompt.isFavorite }

    private var tagsChanged: Bool {
        let versionTags = version.snapshot?.tags.map(\.name).sorted() ?? []
        let currentTags = prompt.tags.map(\.name).sorted()
        return versionTags != currentTags
    }

    private var variablesChanged: Bool {
        let versionVars = version.snapshot?.variables
            .sorted(by: { $0.occurrenceIndex < $1.occurrenceIndex })
            .map { "\($0.name)=\($0.defaultValue)" } ?? []
        let currentVars = prompt.templateVariables
            .sorted(by: { $0.sortOrder < $1.sortOrder })
            .map { "\($0.name)=\($0.defaultValue)" }
        return versionVars != currentVars
    }

    private var hasMetadataChanges: Bool {
        titleChanged || favoriteChanged || tagsChanged || variablesChanged
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text("Version from \(dateString)")
                    .font(.headline)
                Spacer()

                Picker("", selection: $diffMode) {
                    ForEach(DiffMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)

                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            // Diff content
            switch diffMode {
            case .inline:
                inlineDiffView
            case .sideBySide:
                sideBySideDiffView
            }

            // Metadata changes
            if hasMetadataChanges {
                metadataChangesSection
            }

            Divider()

            // Bottom toolbar
            HStack {
                Spacer()
                Button("Restore This Version") {
                    showRestorePreview = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 480)
        .sheet(isPresented: $showRestorePreview) {
            restorePreviewSheet
        }
    }

    // MARK: - Inline Diff View

    private var inlineDiffView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(diffs) { lineDiff in
                    HStack(spacing: 0) {
                        if let charDiffs = lineDiff.characterDiffs {
                            charDiffs.reduce(Text("")) { partial, cd in
                                switch cd.kind {
                                case .unchanged: partial + Text(cd.text)
                                case .removed: partial + Text(cd.text).fontWeight(.bold).foregroundStyle(.red)
                                case .added: partial + Text(cd.text).fontWeight(.bold).foregroundStyle(.green)
                                }
                            }
                            .font(.system(.body, design: .monospaced))
                        } else {
                            Text(lineDiff.text.isEmpty ? " " : lineDiff.text)
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 2)
                    .padding(.horizontal, 8)
                    .background(lineBackground(for: lineDiff.kind))
                }
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Side-by-Side Diff View

    private var sideBySideDiffView: some View {
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: 0) {
                // Left panel: version content
                VStack(alignment: .leading, spacing: 4) {
                    Label("This Version", systemImage: "clock.arrow.circlepath")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    Divider()
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(diffs.filter { $0.kind != .added }) { lineDiff in
                                sideBySideLine(lineDiff: lineDiff, side: .removed)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                .frame(width: geometry.size.width / 2)

                Divider()

                // Right panel: current content
                VStack(alignment: .leading, spacing: 4) {
                    Label("Current Version", systemImage: "doc.text")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    Divider()
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(diffs.filter { $0.kind != .removed }) { lineDiff in
                                sideBySideLine(lineDiff: lineDiff, side: .added)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                .frame(width: geometry.size.width / 2)
            }
        }
    }

    @ViewBuilder
    private func sideBySideLine(lineDiff: DiffEngine.LineDiff, side: DiffEngine.DiffKind) -> some View {
        HStack(spacing: 0) {
            if let charDiffs = lineDiff.characterDiffs {
                charDiffs.reduce(Text("")) { partial, cd in
                    switch cd.kind {
                    case .unchanged: partial + Text(cd.text)
                    case .removed: partial + Text(cd.text).fontWeight(.bold).foregroundStyle(.red)
                    case .added: partial + Text(cd.text).fontWeight(.bold).foregroundStyle(.green)
                    }
                }
                .font(.system(.body, design: .monospaced))
            } else {
                Text(lineDiff.text.isEmpty ? " " : lineDiff.text)
                    .font(.system(.body, design: .monospaced))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
        .padding(.horizontal, 8)
        .background(lineBackground(for: lineDiff.kind))
    }

    // MARK: - Metadata Changes

    private var metadataChangesSection: some View {
        DisclosureGroup("Metadata Changes") {
            VStack(alignment: .leading, spacing: 6) {
                if titleChanged {
                    metadataRow(label: "Title", from: version.title, to: prompt.title)
                }
                if favoriteChanged {
                    metadataRow(label: "Favorite",
                                from: version.isFavorite ? "Yes" : "No",
                                to: prompt.isFavorite ? "Yes" : "No")
                }
                if tagsChanged {
                    let versionTags = version.snapshot?.tags.map(\.name).sorted() ?? []
                    let currentTags = prompt.tags.map(\.name).sorted()
                    let added = Set(currentTags).subtracting(versionTags)
                    let removed = Set(versionTags).subtracting(currentTags)
                    if !added.isEmpty {
                        HStack(spacing: 4) {
                            Text("Tags added:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(added.sorted().joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                    if !removed.isEmpty {
                        HStack(spacing: 4) {
                            Text("Tags removed:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(removed.sorted().joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
                if variablesChanged {
                    HStack(spacing: 4) {
                        Text("Variables:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Changed")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }

    private func metadataRow(label: String, from: String, to: String) -> some View {
        HStack(spacing: 4) {
            Text("\(label):")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(from)
                .font(.caption)
                .strikethrough()
                .foregroundStyle(.red)
            Image(systemName: "arrow.right")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(to)
                .font(.caption)
                .foregroundStyle(.green)
        }
    }

    // MARK: - Restore Preview Sheet

    private var restorePreviewSheet: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Restore Preview")
                    .font(.headline)
                Spacer()
                Button("Cancel") { showRestorePreview = false }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            // Field selection
            Form {
                Section("Select fields to restore") {
                    Toggle("Title", isOn: $restoreTitle)
                        .disabled(!titleChanged)
                    Toggle("Content", isOn: $restoreContent)
                        .disabled(!contentChanged)
                    Toggle("Favorite", isOn: $restoreFavorite)
                        .disabled(!favoriteChanged)
                    Toggle("Tags", isOn: $restoreTags)
                        .disabled(!tagsChanged)
                    Toggle("Variables", isOn: $restoreVariables)
                        .disabled(!variablesChanged)
                }

                if titleChanged {
                    Section("Title Change") {
                        metadataRow(label: "Title", from: prompt.title, to: version.title)
                    }
                }

                if contentChanged {
                    Section("Content Diff") {
                        Text("\(diffs.filter { $0.kind == .removed }.count) lines removed, \(diffs.filter { $0.kind == .added }.count) lines added")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            // Confirm button
            HStack {
                Spacer()
                Button("Confirm Restore") {
                    performRestore()
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(!restoreTitle && !restoreContent && !restoreFavorite && !restoreTags && !restoreVariables)
            }
            .padding()
        }
        .frame(width: 400, height: 420)
    }

    // MARK: - Restore Logic

    private func performRestore() {
        // Snapshot current state before restore
        service.saveSnapshot(for: prompt, changeNote: "Before restore from \(dateString)", limit: versionHistoryLimit)

        if restoreTitle { prompt.title = version.title }
        if restoreContent {
            prompt.content = version.content
            prompt.attributedContent = nil
        }
        if restoreFavorite { prompt.isFavorite = version.isFavorite }
        if restoreTags, let snap = version.snapshot {
            // Remove current tags
            prompt.tags.removeAll()
            // Re-add from snapshot using createTag for dedup
            for tagSnap in snap.tags {
                let tag = service.createTag(name: tagSnap.name, color: tagSnap.color)
                service.addTag(tag, to: prompt)
            }
        }
        if restoreVariables, let snap = version.snapshot {
            // Sync variables from content first (if content was also restored)
            if restoreContent {
                TemplateEngine.syncVariables(for: prompt, in: modelContext)
            }
            // Overlay snapshot defaults
            for varSnap in snap.variables {
                if let existing = prompt.templateVariables.first(where: {
                    $0.name == varSnap.name && $0.occurrenceIndex == varSnap.occurrenceIndex
                }) {
                    existing.defaultValue = varSnap.defaultValue
                }
            }
        }

        prompt.updatedAt = Date()
        service.saveSnapshot(for: prompt, changeNote: "Restored from \(dateString)", limit: versionHistoryLimit)
        showRestorePreview = false
        dismiss()
    }

    // MARK: - Helpers

    private func lineBackground(for kind: DiffEngine.DiffKind) -> Color {
        switch kind {
        case .unchanged: return .clear
        case .removed: return .red.opacity(0.15)
        case .added: return .green.opacity(0.15)
        }
    }
}
