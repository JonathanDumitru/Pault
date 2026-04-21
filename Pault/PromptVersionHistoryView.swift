//
//  PromptVersionHistoryView.swift
//  Pault
//

import SwiftUI
import SwiftData
import os

private let historyLogger = Logger(subsystem: "com.pault.app", category: "VersionHistory")

// MARK: - VersionSourceBadge

struct VersionSourceBadge: View {
    let source: VersionSource

    private var badgeColor: Color {
        switch source {
        case .aiImprove, .aiVariableAccept, .aiAutoTag, .aiRefine: return .purple
        case .manual: return .blue
        case .restore: return .orange
        }
    }

    var body: some View {
        Text(source.badgeLabel)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundStyle(badgeColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(badgeColor.opacity(0.15))
            .clipShape(Capsule())
    }
}

// MARK: - PromptVersionHistoryView

struct PromptVersionHistoryView: View {
    @Bindable var prompt: Prompt
    @Environment(\.modelContext) private var modelContext

    @State private var selectedVersion: PromptVersion?
    @State private var searchText: String = ""
    @State private var compareMode: Bool = false
    @State private var compareSelections: Set<UUID> = []

    // V2V comparison: when two versions are selected, store the pair here.
    @State private var v2vOlder: PromptVersion?
    @State private var v2vNewer: PromptVersion?
    @State private var showV2VSheet: Bool = false

    private var versions: [PromptVersion] {
        var result = prompt.versions.sorted { $0.savedAt > $1.savedAt }
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                ($0.changeNote ?? "").lowercased().contains(query) ||
                $0.savedAt.formatted(date: .abbreviated, time: .shortened).lowercased().contains(query)
            }
        }
        return result
    }

    /// Ordered (label, [PromptVersion]) sections for the list.
    private var groupedVersions: [(label: String, versions: [PromptVersion])] {
        var groups: [(label: String, versions: [PromptVersion])] = []
        var labelToIndex: [String: Int] = [:]
        for version in versions {
            let label = sectionLabel(for: version.savedAt)
            if let idx = labelToIndex[label] {
                groups[idx].versions.append(version)
            } else {
                labelToIndex[label] = groups.count
                groups.append((label: label, versions: [version]))
            }
        }
        return groups
    }

    var body: some View {
        if prompt.versions.isEmpty {
            emptyState
        } else {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    TextField("Search versions\u{2026}", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.08))

                // Compare mode toolbar
                HStack {
                    if compareMode {
                        Button("Cancel") {
                            compareMode = false
                            compareSelections.removeAll()
                        }
                        .font(.caption)
                        Spacer()
                        Button("Compare (\(compareSelections.count)/2)") {
                            openComparison()
                        }
                        .font(.caption)
                        .disabled(compareSelections.count != 2)
                    } else {
                        Spacer()
                        Button {
                            compareMode = true
                        } label: {
                            Image(systemName: "arrow.left.and.right")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .help("Compare two versions")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)

                Divider()

                // Version list with date section headers
                versionList
            }
            // Version-vs-current sheet
            .sheet(item: $selectedVersion) { version in
                PromptDiffView(version: version, prompt: prompt)
            }
            // Version-to-version sheet
            .sheet(isPresented: $showV2VSheet, onDismiss: {
                v2vOlder = nil
                v2vNewer = nil
            }) {
                if let older = v2vOlder, let newer = v2vNewer {
                    PromptDiffView(
                        target: PromptDiffView.Target.versionToVersion(older: older, newer: newer),
                        prompt: prompt
                    )
                }
            }
        }
    }

    // MARK: - Version List

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No history yet")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var versionList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(groupedVersions, id: \.label) { group in
                    // Date section header
                    Text(group.label)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .padding(.bottom, 2)

                    ForEach(group.versions) { version in
                        HStack {
                            if compareMode {
                                Image(systemName: compareSelections.contains(version.id)
                                      ? "checkmark.circle.fill"
                                      : "circle")
                                    .foregroundStyle(compareSelections.contains(version.id) ? .blue : .secondary)
                                    .font(.caption)
                            }
                            VersionRow(version: version)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if compareMode {
                                toggleCompareSelection(version.id)
                            } else {
                                selectedVersion = version
                            }
                        }
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                deleteVersion(version)
                            }
                        }
                        Divider()
                    }
                }
            }
        }
    }

    // MARK: - Date Grouping

    private func sectionLabel(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            return "Today"
        } else if cal.isDateInYesterday(date) {
            return "Yesterday"
        } else if let days = cal.dateComponents([.day], from: date, to: Date()).day, days < 7 {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: date)
        }
    }

    // MARK: - Actions

    private func deleteVersion(_ version: PromptVersion) {
        compareSelections.remove(version.id)
        modelContext.delete(version)
        do {
            try modelContext.save()
        } catch {
            historyLogger.error("deleteVersion: Failed to save — \(error.localizedDescription)")
        }
    }

    private func toggleCompareSelection(_ id: UUID) {
        if compareSelections.contains(id) {
            compareSelections.remove(id)
        } else if compareSelections.count < 2 {
            compareSelections.insert(id)
        }
    }

    private func openComparison() {
        guard compareSelections.count == 2 else { return }
        let selected = versions.filter { compareSelections.contains($0.id) }
            .sorted { $0.savedAt < $1.savedAt }
        guard let older = selected.first, let newer = selected.last else { return }
        v2vOlder = older
        v2vNewer = newer
        compareMode = false
        compareSelections.removeAll()
        showV2VSheet = true
    }
}

// MARK: - VersionRow

private struct VersionRow: View {
    let version: PromptVersion

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(version.savedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.primary)
                    VersionSourceBadge(source: version.versionSource)
                }
                if let note = version.changeNote, !note.isEmpty {
                    Text(note)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
