//
//  ImportPreviewSheet.swift
//  Pault
//
//  Sheet view for previewing import candidates with per-prompt conflict resolution.
//  Shows duplicate badge, Skip/Overwrite/Keep Both pickers, expandable diff, and summary banner.
//

import SwiftUI
import SwiftData

// MARK: - ImportPreviewSheet

struct ImportPreviewSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Binding var session: ImportSession?
    var onComplete: ((ImportResult) -> Void)?

    @State private var localSession: ImportSession? = nil

    // MARK: - Computed

    private var records: [ImportCandidate] {
        localSession?.records ?? []
    }

    private var duplicateCount: Int {
        records.filter { $0.existing != nil }.count
    }

    private var importableCount: Int {
        records.filter { $0.resolution != .skip }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)

            Divider()

            // Prompt list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(records.indices, id: \.self) { index in
                        ImportCandidateRow(
                            candidate: candidateBinding(at: index),
                            existingContent: records[index].existing?.content ?? ""
                        )
                        if index < records.count - 1 {
                            Divider()
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(minHeight: 200)

            Divider()

            // Footer
            footerView
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
        }
        .frame(minWidth: 560, minHeight: 400)
        .onAppear {
            localSession = session
        }
        .accessibilityLabel("Import Prompts Preview")
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Import Prompts")
                .font(.title2)
                .fontWeight(.semibold)

            HStack(spacing: 16) {
                Label("\(records.count) prompts", systemImage: "doc.text")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if duplicateCount > 0 {
                    Label("\(duplicateCount) duplicate\(duplicateCount == 1 ? "" : "s")", systemImage: "exclamationmark.triangle")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                }
            }

            // "Apply to all duplicates" picker — only when duplicates exist
            if duplicateCount > 0 {
                HStack {
                    Text("Apply to all duplicates:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Picker("Apply to all duplicates", selection: globalResolutionBinding) {
                        Text("Mixed").tag(ConflictResolution?.none)
                        ForEach(ConflictResolution.allCases, id: \.self) { res in
                            Text(res.displayName).tag(Optional(res))
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .accessibilityLabel("Apply resolution to all duplicates")
                    .frame(width: 140)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            Button("Cancel") {
                dismiss()
                session = nil
            }
            .keyboardShortcut(.escape, modifiers: [])

            Spacer()

            Button("Import \(importableCount) Prompt\(importableCount == 1 ? "" : "s")") {
                performImport()
            }
            .keyboardShortcut(.return, modifiers: .command)
            .buttonStyle(.borderedProminent)
            .disabled(importableCount == 0)
        }
    }

    // MARK: - Actions

    private func performImport() {
        guard var currentSession = localSession else { return }

        // Apply global resolution to duplicates if set
        if let global = currentSession.globalResolution {
            for i in currentSession.records.indices {
                if currentSession.records[i].existing != nil {
                    currentSession.records[i].resolution = global
                }
            }
        }

        let service = PromptService(modelContext: modelContext)
        let result = ImportOrchestrator.applyImport(
            session: currentSession,
            context: modelContext,
            promptService: service
        )

        onComplete?(result)
        dismiss()
        session = nil
    }

    // MARK: - Bindings

    private func candidateBinding(at index: Int) -> Binding<ImportCandidate> {
        Binding(
            get: { localSession?.records[index] ?? records[index] },
            set: { newValue in
                localSession?.records[index] = newValue
            }
        )
    }

    private var globalResolutionBinding: Binding<ConflictResolution?> {
        Binding(
            get: { localSession?.globalResolution },
            set: { newValue in
                localSession?.globalResolution = newValue
                // Apply immediately to all duplicates when changed
                if let res = newValue {
                    for i in localSession?.records.indices ?? 0..<0 {
                        if localSession?.records[i].existing != nil {
                            localSession?.records[i].resolution = res
                        }
                    }
                }
            }
        )
    }
}

// MARK: - ImportCandidateRow

private struct ImportCandidateRow: View {
    @Binding var candidate: ImportCandidate
    let existingContent: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            HStack(alignment: .center, spacing: 12) {
                // Expand button (only for duplicates)
                if candidate.existing != nil {
                    Button(action: { candidate.isExpanded.toggle() }) {
                        Image(systemName: candidate.isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 16)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(candidate.isExpanded ? "Collapse diff" : "Expand diff")
                } else {
                    Spacer().frame(width: 16)
                }

                // Prompt info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(candidate.incoming.title.isEmpty ? "Untitled" : candidate.incoming.title)
                            .font(.body)
                            .fontWeight(.medium)
                            .lineLimit(1)

                        if candidate.existing != nil {
                            Text("Duplicate")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.15))
                                .foregroundStyle(.orange)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        } else {
                            Text("New")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.15))
                                .foregroundStyle(.green)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }

                    if !candidate.incoming.tags.isEmpty {
                        Text(candidate.incoming.tags.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel(accessibilityLabelText)

                // Resolution picker (only for duplicates)
                if candidate.existing != nil {
                    Picker("Resolution", selection: $candidate.resolution) {
                        ForEach(ConflictResolution.allCases, id: \.self) { res in
                            Text(res.displayName).tag(res)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 120)
                    .accessibilityLabel("Conflict resolution for \(candidate.incoming.title)")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // Expandable diff view
            if candidate.isExpanded && candidate.existing != nil {
                ImportDiffView(oldContent: existingContent, newContent: candidate.incoming.content)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
            }
        }
        .contentShape(Rectangle())
    }

    private var accessibilityLabelText: String {
        let base = "Prompt: \(candidate.incoming.title.isEmpty ? "Untitled" : candidate.incoming.title)"
        return candidate.existing != nil ? "\(base), duplicate" : "\(base), new"
    }
}

// MARK: - ImportDiffView

private struct ImportDiffView: View {
    let oldContent: String
    let newContent: String

    private var diffs: [DiffEngine.LineDiff] {
        DiffEngine.diff(old: oldContent, new: newContent)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(diffs) { diff in
                    DiffLineView(diff: diff)
                }
            }
        }
        .frame(maxHeight: 200)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

private struct DiffLineView: View {
    let diff: DiffEngine.LineDiff

    private var backgroundColor: Color {
        switch diff.kind {
        case .unchanged: return .clear
        case .removed: return Color.red.opacity(0.1)
        case .added: return Color.green.opacity(0.1)
        }
    }

    private var prefix: String {
        switch diff.kind {
        case .unchanged: return " "
        case .removed: return "-"
        case .added: return "+"
        }
    }

    private var textColor: Color {
        switch diff.kind {
        case .unchanged: return .primary
        case .removed: return .red
        case .added: return .green
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(prefix)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(textColor)
                .frame(width: 12, alignment: .leading)

            Text(diff.text)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 1)
        .background(backgroundColor)
    }
}

// MARK: - ConflictResolution display names

extension ConflictResolution {
    var displayName: String {
        switch self {
        case .skip: return "Skip"
        case .overwrite: return "Overwrite"
        case .keepBoth: return "Keep Both"
        }
    }
}
