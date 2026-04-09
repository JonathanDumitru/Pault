//
//  PromptStatsView.swift
//  Pault
//

import SwiftUI
import SwiftData

// MARK: - Token formatting (shared with AnalyticsView)

func formatTokenCount(_ count: Int) -> String {
    count >= 1000 ? String(format: "%.1fK", Double(count) / 1000.0) : "\(count)"
}

// MARK: - PromptStatsView

struct PromptStatsView: View {
    @Environment(\.modelContext) private var modelContext
    let prompt: Prompt

    private var service: AnalyticsService {
        AnalyticsService(modelContext: modelContext)
    }

    /// Totals all PromptRun tokens for this prompt.
    private var tokenBreakdown: (input: Int, output: Int, hasRuns: Bool, hasPartialData: Bool) {
        let descriptor = FetchDescriptor<PromptRun>()
        guard let runs = try? modelContext.fetch(descriptor) else {
            return (0, 0, false, false)
        }
        let promptRuns = runs.filter { $0.prompt?.id == prompt.id }
        guard !promptRuns.isEmpty else { return (0, 0, false, false) }
        var totalInput = 0
        var totalOutput = 0
        var hasPartialData = false
        for run in promptRuns {
            if let input = run.inputTokens { totalInput += input } else { hasPartialData = true }
            if let output = run.outputTokens { totalOutput += output } else { hasPartialData = true }
        }
        return (totalInput, totalOutput, true, hasPartialData)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                statRow(
                    icon: "doc.on.doc",
                    label: "Copies",
                    value: "\(service.copyCount(for: prompt.id))"
                )
                statRow(
                    icon: "play.circle",
                    label: "Runs",
                    value: "\(service.runCount(for: prompt))"
                )
                statRow(
                    icon: "clock",
                    label: "Last Copied",
                    value: service.lastCopied(promptID: prompt.id).map {
                        $0.formatted(date: .abbreviated, time: .shortened)
                    } ?? "Never"
                )
                statRow(
                    icon: "clock.badge.checkmark",
                    label: "Last Used",
                    value: prompt.lastUsedAt.map {
                        $0.formatted(date: .abbreviated, time: .shortened)
                    } ?? "Never"
                )

                // Token breakdown (only shown when runs exist with token data)
                let tokens = tokenBreakdown
                if tokens.hasRuns {
                    Divider()
                    Text("Token Usage")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    let prefix = tokens.hasPartialData ? "~" : ""
                    statRow(
                        icon: "arrow.up.circle",
                        label: "Input Tokens",
                        value: "\(prefix)\(formatTokenCount(tokens.input))"
                    )
                    statRow(
                        icon: "arrow.down.circle",
                        label: "Output Tokens",
                        value: "\(prefix)\(formatTokenCount(tokens.output))"
                    )
                }

                Divider()

                Text("Last 30 Days")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                let daily = service.dailyCopies(for: prompt.id, days: 30)
                let visible = Array(daily.suffix(14))
                let maxCount = visible.map(\.count).max() ?? 1
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(visible, id: \.date) { entry in
                        Rectangle()
                            .fill(entry.count > 0 ? Color.accentColor : Color.secondary.opacity(0.2))
                            .frame(width: 8, height: maxCount > 0 ? CGFloat(entry.count) / CGFloat(maxCount) * 40 + 2 : 2)
                    }
                }
                .frame(height: 44)
            }
            .padding()
        }
    }

    private func statRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.callout)
                .monospacedDigit()
        }
    }
}
