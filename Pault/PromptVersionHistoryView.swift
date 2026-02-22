//
//  PromptVersionHistoryView.swift
//  Pault
//

import SwiftUI
import SwiftData

struct PromptVersionHistoryView: View {
    @Bindable var prompt: Prompt
    @Environment(\.modelContext) private var modelContext
    @State private var selectedVersion: PromptVersion?
    @State private var searchText: String = ""
    @State private var compareMode: Bool = false
    @State private var compareSelections: Set<UUID> = []

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

                // Compare mode toggle
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

                // Version list
                versionList
            }
            .sheet(item: $selectedVersion) { version in
                PromptDiffView(version: version, prompt: prompt)
            }
        }
    }

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
                ForEach(versions) { version in
                    HStack {
                        if compareMode {
                            Image(systemName: compareSelections.contains(version.id) ? "checkmark.circle.fill" : "circle")
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

    private func deleteVersion(_ version: PromptVersion) {
        compareSelections.remove(version.id)
        modelContext.delete(version)
        do {
            try modelContext.save()
        } catch {
            print("[PromptVersionHistoryView] Failed to save after deleting version: \(error)")
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
        // Will be wired in Task 7/8 when PromptDiffView supports two-version comparison
        guard compareSelections.count == 2 else { return }
        let selected = versions.filter { compareSelections.contains($0.id) }
            .sorted { $0.savedAt < $1.savedAt }
        if let older = selected.first {
            selectedVersion = older // For now, open the older version in diff view
        }
    }
}

// MARK: - VersionRow

private struct VersionRow: View {
    let version: PromptVersion

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(version.savedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.primary)
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
