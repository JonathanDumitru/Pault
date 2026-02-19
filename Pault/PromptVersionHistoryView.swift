//
//  PromptVersionHistoryView.swift
//  Pault
//

import SwiftUI
import SwiftData

struct PromptVersionHistoryView: View {
    @Bindable var prompt: Prompt
    @State private var selectedVersion: PromptVersion?

    private var versions: [PromptVersion] {
        prompt.versions.sorted { $0.savedAt > $1.savedAt }
    }

    var body: some View {
        if versions.isEmpty {
            emptyState
        } else {
            versionList
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
                    VersionRow(version: version)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedVersion = version
                        }
                    Divider()
                }
            }
        }
        .sheet(item: $selectedVersion) { version in
            PromptDiffView(version: version, prompt: prompt)
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
