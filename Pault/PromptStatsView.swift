//
//  PromptStatsView.swift
//  Pault
//

import SwiftUI
import SwiftData

struct PromptStatsView: View {
    @Environment(\.modelContext) private var modelContext
    let prompt: Prompt

    private var service: AnalyticsService {
        AnalyticsService(modelContext: modelContext)
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
