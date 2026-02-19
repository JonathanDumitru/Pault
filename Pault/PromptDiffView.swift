//
//  PromptDiffView.swift
//  Pault
//

import SwiftUI
import SwiftData

struct PromptDiffView: View {
    let version: PromptVersion
    let prompt: Prompt

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private var service: PromptService { PromptService(modelContext: modelContext) }

    private var dateString: String {
        version.savedAt.formatted(date: .abbreviated, time: .shortened)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text("Version from \(dateString)")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            // Two-panel diff layout
            GeometryReader { geometry in
                HStack(alignment: .top, spacing: 0) {
                    // Left panel: snapshot content
                    VStack(alignment: .leading, spacing: 8) {
                        Label("This Version", systemImage: "clock.arrow.circlepath")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                            .padding(.top, 12)

                        Divider()

                        ScrollView {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(version.title)
                                    .font(.headline)
                                    .textSelection(.enabled)
                                Text(version.content)
                                    .font(.body)
                                    .textSelection(.enabled)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                        }
                    }
                    .frame(width: geometry.size.width / 2)

                    Divider()

                    // Right panel: current content
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Current Version", systemImage: "doc.text")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                            .padding(.top, 12)

                        Divider()

                        ScrollView {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(prompt.title)
                                    .font(.headline)
                                    .textSelection(.enabled)
                                Text(prompt.content)
                                    .font(.body)
                                    .textSelection(.enabled)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                        }
                    }
                    .frame(width: geometry.size.width / 2)
                }
            }

            Divider()

            // Bottom toolbar
            HStack {
                Spacer()
                Button("Restore This Version") {
                    restoreVersion()
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }
            .padding()
        }
        .frame(minWidth: 560, minHeight: 420)
    }

    private func restoreVersion() {
        prompt.title = version.title
        prompt.content = version.content
        prompt.updatedAt = Date()
        service.saveSnapshot(for: prompt, changeNote: "Restored from \(dateString)")
        dismiss()
    }
}
