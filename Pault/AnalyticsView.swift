//
//  AnalyticsView.swift
//  Pault
//
//  Top-level analytics sheet showing top prompts ranked by combined usage.
//

import SwiftUI
import SwiftData

struct AnalyticsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allPrompts: [Prompt]

    private struct AnalyticsEntry: Identifiable {
        let id: UUID
        let title: String
        let copyCount: Int
        let runCount: Int
        var total: Int { copyCount + runCount }
    }

    private var topEntries: [AnalyticsEntry] {
        let svc = AnalyticsService(modelContext: modelContext)
        let runCounts = svc.allRunCounts()   // single PromptRun table scan
        return allPrompts
            .map { prompt in
                AnalyticsEntry(
                    id: prompt.id,
                    title: prompt.title.isEmpty ? "Untitled" : prompt.title,
                    copyCount: svc.copyCount(for: prompt.id),
                    runCount: runCounts[prompt.id] ?? 0
                )
            }
            .filter { $0.total > 0 }
            .sorted { $0.total > $1.total }
            .prefix(20)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            Group {
                if ProStatusManager.shared.isProUnlocked {
                    analyticsContent
                } else {
                    upgradePrompt
                }
            }
            .navigationTitle("Analytics")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 480, height: 420)
    }

    private var analyticsContent: some View {
        let entries = topEntries   // compute once to avoid double evaluation
        return Group {
            if entries.isEmpty {
                ContentUnavailableView {
                    Label("No Usage Data", systemImage: "chart.bar")
                } description: {
                    Text("Copy or run prompts to start tracking usage.")
                }
            } else {
                List {
                    Section {
                        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                            HStack(spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.body.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 24, alignment: .trailing)

                                Text(entry.title)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                HStack(spacing: 4) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("\(entry.copyCount)")
                                        .font(.body.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                .frame(width: 52, alignment: .trailing)

                                HStack(spacing: 4) {
                                    Image(systemName: "play.circle")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("\(entry.runCount)")
                                        .font(.body.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                .frame(width: 52, alignment: .trailing)
                            }
                            .padding(.vertical, 2)
                        }
                    } header: {
                        HStack(spacing: 12) {
                            Text("#")
                                .frame(width: 24, alignment: .trailing)
                            Text("Prompt")
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("Copies")
                                .frame(width: 52, alignment: .trailing)
                            Text("Runs")
                                .frame(width: 52, alignment: .trailing)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    private var upgradePrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(colors: [.purple, .blue], startPoint: .top, endPoint: .bottom)
                )

            HStack(spacing: 8) {
                Text("Analytics")
                    .font(.title2)
                    .fontWeight(.bold)
                ProBadge()
            }

            Text("See your top prompts ranked by copy and run count.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)

            Button("Learn More") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    AnalyticsView()
        .modelContainer(
            for: [Prompt.self, Tag.self, TemplateVariable.self, Attachment.self, PromptRun.self, CopyEvent.self],
            inMemory: true
        )
}
