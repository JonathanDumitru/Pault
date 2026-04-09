//
//  PromptDiffView.swift
//  Pault
//

import SwiftUI
import SwiftData

struct PromptDiffView: View {

    // MARK: - Target enum for version-vs-current vs version-to-version

    enum Target {
        /// Compare a historical version against the current prompt state.
        case versionToCurrent(PromptVersion)
        /// Compare two historical versions against each other (older left, newer right).
        case versionToVersion(older: PromptVersion, newer: PromptVersion)
    }

    // MARK: - Init

    /// Version-vs-current (existing convenience init).
    init(version: PromptVersion, prompt: Prompt) {
        self._prompt = Bindable(wrappedValue: prompt)
        self.target = .versionToCurrent(version)
    }

    /// Target-based init used by PromptVersionHistoryView compare mode.
    init(target: Target, prompt: Prompt) {
        self._prompt = Bindable(wrappedValue: prompt)
        self.target = target
    }

    let target: Target
    @Bindable var prompt: Prompt

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @AppStorage("versionHistoryLimit") private var versionHistoryLimit: Int = 50

    @State private var diffMode: DiffMode = .sideBySide

    // Restore state — V2C uses a single preview sheet, V2V uses left (older) and right (newer).
    @State private var showRestorePreview = false
    @State private var showRestorePreviewRight = false
    @State private var restoreContent = true
    @State private var restoreTitle = true
    @State private var restoreTags = true
    @State private var restoreVariables = true
    @State private var restoreFavorite = true
    /// The version selected for restore (set before showing the preview sheet).
    @State private var pendingRestoreVersion: PromptVersion?

    /// Cached diff result.
    @State private var diffs: [DiffEngine.LineDiff] = []

    /// Cached decoded snapshot to avoid repeated JSON decoding per render.
    @State private var cachedSnapshot: VersionSnapshot?

    /// Snapshot for the "newer" side in V2V mode.
    @State private var cachedSnapshotNewer: VersionSnapshot?

    private var service: PromptService { PromptService(modelContext: modelContext) }

    // MARK: - Computed helpers

    /// The primary / older version being inspected.
    private var version: PromptVersion {
        switch target {
        case .versionToCurrent(let v): return v
        case .versionToVersion(let older, _): return older
        }
    }

    /// The "new" content for diffing: current prompt content for V2C, newer version content for V2V.
    private var newContent: String {
        switch target {
        case .versionToCurrent: return prompt.content
        case .versionToVersion(_, let newer): return newer.content
        }
    }

    private var isVersionToVersion: Bool {
        if case .versionToVersion = target { return true }
        return false
    }

    private var dateString: String {
        version.savedAt.formatted(date: .abbreviated, time: .shortened)
    }

    private var leftPanelLabel: String {
        switch target {
        case .versionToCurrent(let v):
            return "Version from \(v.savedAt.formatted(date: .abbreviated, time: .shortened))"
        case .versionToVersion(let older, _):
            return "Version A (\(older.savedAt.formatted(date: .abbreviated, time: .omitted)))"
        }
    }

    private var rightPanelLabel: String {
        switch target {
        case .versionToCurrent: return "Current Version"
        case .versionToVersion(_, let newer):
            return "Version B (\(newer.savedAt.formatted(date: .abbreviated, time: .omitted)))"
        }
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
        let leftTags = cachedSnapshot?.tags.map(\.name).sorted() ?? []
        let rightTags: [String]
        switch target {
        case .versionToCurrent: rightTags = prompt.tags.map(\.name).sorted()
        case .versionToVersion: rightTags = cachedSnapshotNewer?.tags.map(\.name).sorted() ?? []
        }
        return leftTags != rightTags
    }

    private var variablesChanged: Bool {
        let leftVars = cachedSnapshot?.variables
            .sorted(by: { $0.occurrenceIndex < $1.occurrenceIndex })
            .map { "\($0.name)=\($0.defaultValue)" } ?? []
        let rightVars: [String]
        switch target {
        case .versionToCurrent:
            rightVars = prompt.templateVariables
                .sorted(by: { $0.sortOrder < $1.sortOrder })
                .map { "\($0.name)=\($0.defaultValue)" }
        case .versionToVersion:
            rightVars = cachedSnapshotNewer?.variables
                .sorted(by: { $0.occurrenceIndex < $1.occurrenceIndex })
                .map { "\($0.name)=\($0.defaultValue)" } ?? []
        }
        return leftVars != rightVars
    }

    private var hasMetadataChanges: Bool {
        titleChanged || favoriteChanged || tagsChanged || variablesChanged
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Group {
                    switch target {
                    case .versionToCurrent:
                        Text("Version from \(dateString)")
                    case .versionToVersion(let older, let newer):
                        Text("Compare: \(older.savedAt.formatted(date: .abbreviated, time: .omitted)) vs \(newer.savedAt.formatted(date: .abbreviated, time: .omitted))")
                    }
                }
                .font(.headline)
                Spacer()

                Picker("Diff mode", selection: $diffMode) {
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
            bottomToolbar
        }
        .frame(minWidth: 600, minHeight: 480)
        .onAppear {
            diffs = DiffEngine.diff(old: version.content, new: newContent)
            cachedSnapshot = version.snapshot
            if case .versionToVersion(_, let newer) = target {
                cachedSnapshotNewer = newer.snapshot
            }
        }
        // V2C / V2V-left restore preview
        .sheet(isPresented: $showRestorePreview) {
            if let v = pendingRestoreVersion {
                restorePreviewSheet(for: v)
            }
        }
        // V2V-right restore preview (newer version)
        .sheet(isPresented: $showRestorePreviewRight) {
            if let v = pendingRestoreVersion {
                restorePreviewSheet(for: v)
            }
        }
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        HStack {
            Spacer()
            switch target {
            case .versionToCurrent(let v):
                Button("Restore This Version") {
                    pendingRestoreVersion = v
                    resetRestoreToggles()
                    showRestorePreview = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)

            case .versionToVersion(let older, let newer):
                HStack(spacing: 12) {
                    Button("Restore Version A") {
                        pendingRestoreVersion = older
                        resetRestoreToggles()
                        showRestorePreview = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)

                    Button("Restore Version B") {
                        pendingRestoreVersion = newer
                        resetRestoreToggles()
                        showRestorePreviewRight = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
            }
        }
        .padding()
    }

    private func resetRestoreToggles() {
        restoreTitle = true
        restoreContent = true
        restoreTags = true
        restoreVariables = true
        restoreFavorite = true
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

    @State private var syncScrollID: Int = 0

    private var sideBySideDiffView: some View {
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: 0) {
                // Left panel: version content
                VStack(alignment: .leading, spacing: 4) {
                    Label(leftPanelLabel, systemImage: "clock.arrow.circlepath")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    Divider()
                    leftScrollView
                }
                .frame(width: geometry.size.width / 2)

                Divider()

                // Right panel
                VStack(alignment: .leading, spacing: 4) {
                    Label(rightPanelLabel, systemImage: isVersionToVersion ? "clock" : "doc.text")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    Divider()
                    rightScrollView
                }
                .frame(width: geometry.size.width / 2)
            }
        }
    }

    @ViewBuilder
    private var leftScrollView: some View {
        let leftDiffs = diffs.filter { $0.kind != .added }
        if #available(macOS 15, *) {
            SyncedScrollPanel(diffs: leftDiffs, syncID: $syncScrollID)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(leftDiffs) { lineDiff in
                        sideBySideLine(lineDiff: lineDiff)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    @ViewBuilder
    private var rightScrollView: some View {
        let rightDiffs = diffs.filter { $0.kind != .removed }
        if #available(macOS 15, *) {
            SyncedScrollPanel(diffs: rightDiffs, syncID: $syncScrollID)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(rightDiffs) { lineDiff in
                        sideBySideLine(lineDiff: lineDiff)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    @ViewBuilder
    private func sideBySideLine(lineDiff: DiffEngine.LineDiff) -> some View {
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

    private var rightTitle: String {
        switch target {
        case .versionToCurrent: return prompt.title
        case .versionToVersion(_, let newer): return newer.title
        }
    }

    private var rightFavorite: Bool {
        switch target {
        case .versionToCurrent: return prompt.isFavorite
        case .versionToVersion(_, let newer): return newer.isFavorite
        }
    }

    private var rightTagNames: [String] {
        switch target {
        case .versionToCurrent: return prompt.tags.map(\.name).sorted()
        case .versionToVersion: return cachedSnapshotNewer?.tags.map(\.name).sorted() ?? []
        }
    }

    private var leftTagNames: [String] {
        cachedSnapshot?.tags.map(\.name).sorted() ?? []
    }

    private var metadataChangesSection: some View {
        DisclosureGroup("Metadata Changes") {
            VStack(alignment: .leading, spacing: 6) {
                if titleChanged {
                    metadataRow(label: "Title", from: version.title, to: rightTitle)
                }
                if favoriteChanged {
                    metadataRow(label: "Favorite",
                                from: version.isFavorite ? "Yes" : "No",
                                to: rightFavorite ? "Yes" : "No")
                }
                if tagsChanged {
                    let added = Set(rightTagNames).subtracting(leftTagNames)
                    let removed = Set(leftTagNames).subtracting(rightTagNames)
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

    @ViewBuilder
    private func restorePreviewSheet(for restoreVer: PromptVersion) -> some View {
        let snap = restoreVer.snapshot
        let vTitleChanged = restoreVer.title != prompt.title
        let vContentChanged = restoreVer.content != prompt.content
        let vFavChanged = restoreVer.isFavorite != prompt.isFavorite
        let vTagsChanged = (snap?.tags.map(\.name).sorted() ?? []) != prompt.tags.map(\.name).sorted()
        let restoreDiffs = DiffEngine.diff(old: prompt.content, new: restoreVer.content)

        VStack(spacing: 0) {
            HStack {
                Text("Restore Preview")
                    .font(.headline)
                Spacer()
                Button("Cancel") {
                    showRestorePreview = false
                    showRestorePreviewRight = false
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            Form {
                Section("Select fields to restore") {
                    Toggle("Title", isOn: $restoreTitle)
                        .disabled(!vTitleChanged)
                    Toggle("Content", isOn: $restoreContent)
                        .disabled(!vContentChanged)
                    Toggle("Favorite", isOn: $restoreFavorite)
                        .disabled(!vFavChanged)
                    Toggle("Tags", isOn: $restoreTags)
                        .disabled(!vTagsChanged)
                    Toggle("Variables", isOn: $restoreVariables)
                }

                if vTitleChanged {
                    Section("Title Change") {
                        metadataRow(label: "Title", from: prompt.title, to: restoreVer.title)
                    }
                }

                if vContentChanged {
                    Section("Content Diff") {
                        Text("\(restoreDiffs.filter { $0.kind == .removed }.count) lines removed, \(restoreDiffs.filter { $0.kind == .added }.count) lines added")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("Confirm Restore") {
                    performRestore(version: restoreVer)
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

    private func performRestore(version restoreVer: PromptVersion) {
        let snap = restoreVer.snapshot
        let versionDateString = restoreVer.savedAt.formatted(date: .abbreviated, time: .shortened)

        service.saveSnapshot(
            for: prompt,
            changeNote: "Before restore from \(versionDateString)",
            source: .restore,
            limit: versionHistoryLimit
        )

        if restoreTitle { prompt.title = restoreVer.title }
        if restoreContent {
            prompt.content = restoreVer.content
            prompt.attributedContent = nil
        }
        if restoreFavorite { prompt.isFavorite = restoreVer.isFavorite }
        if restoreTags, let snap {
            prompt.tags.removeAll()
            for tagSnap in snap.tags {
                let tag = service.createTag(name: tagSnap.name, color: tagSnap.color)
                service.addTag(tag, to: prompt)
            }
        }
        if restoreVariables, let snap {
            if restoreContent {
                TemplateEngine.syncVariables(for: prompt, in: modelContext)
            }
            for varSnap in snap.variables {
                if let existing = prompt.templateVariables.first(where: {
                    $0.name == varSnap.name && $0.occurrenceIndex == varSnap.occurrenceIndex
                }) {
                    existing.defaultValue = varSnap.defaultValue
                }
            }
        }

        prompt.updatedAt = Date()
        service.saveSnapshot(
            for: prompt,
            changeNote: "Restored from \(versionDateString)",
            source: .restore,
            limit: versionHistoryLimit
        )

        showRestorePreview = false
        showRestorePreviewRight = false
        pendingRestoreVersion = nil
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

// MARK: - Synchronized Scroll Panel (macOS 15+)

@available(macOS 15, *)
private struct SyncedScrollPanel: View {
    let diffs: [DiffEngine.LineDiff]
    @Binding var syncID: Int

    @State private var scrollPosition = ScrollPosition(idType: Int.self)
    @State private var isSelfScrolling = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(diffs.enumerated()), id: \.offset) { idx, lineDiff in
                    diffLine(lineDiff: lineDiff)
                        .id(idx)
                }
            }
            .padding(.vertical, 8)
        }
        .scrollPosition($scrollPosition)
        .onChange(of: syncID) { _, newID in
            guard !isSelfScrolling else { return }
            scrollPosition.scrollTo(id: newID)
        }
        .onScrollPhaseChange { _, newPhase in
            if newPhase == .interacting {
                isSelfScrolling = true
                if let id = scrollPosition.viewID(type: Int.self) {
                    syncID = id
                }
            } else {
                isSelfScrolling = false
            }
        }
    }

    @ViewBuilder
    private func diffLine(lineDiff: DiffEngine.LineDiff) -> some View {
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

    private func lineBackground(for kind: DiffEngine.DiffKind) -> Color {
        switch kind {
        case .unchanged: return .clear
        case .removed: return .red.opacity(0.15)
        case .added: return .green.opacity(0.15)
        }
    }
}
