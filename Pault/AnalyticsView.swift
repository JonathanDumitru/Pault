//
//  AnalyticsView.swift
//  Pault
//
//  Top-level analytics sheet showing daily usage chart, token totals,
//  and top prompts ranked by combined usage.
//

import SwiftUI
import SwiftData
import Charts

// MARK: - AnalyticsView

struct AnalyticsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allPrompts: [Prompt]

    @State private var dateRange: Int = 30
    @State private var drilldownPromptID: UUID? = nil

    private let rangeOptions = [7, 30, 90]

    private struct AnalyticsEntry: Identifiable {
        let id: UUID
        let title: String
        let copyCount: Int
        let runCount: Int
        var total: Int { copyCount + runCount }
    }

    private var service: AnalyticsService {
        AnalyticsService(modelContext: modelContext)
    }

    private var topEntries: [AnalyticsEntry] {
        let svc = service
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
                if ProFeature.isUnlocked(.analytics) {
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
        .frame(width: 480, height: 560)
        .accessibilityIdentifier("analytics-view")
    }

    // MARK: - Analytics Content

    private var analyticsContent: some View {
        let entries = topEntries
        return VStack(spacing: 0) {
            // Date range picker
            Picker("Range", selection: $dateRange) {
                ForEach(rangeOptions, id: \.self) { days in
                    Text("\(days)d").tag(days)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 10)

            // Daily events chart
            dailyChart

            // Token consumption summary
            tokenSummary

            Divider()
                .padding(.top, 8)

            // Ranked prompt list
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
                            Button {
                                // Navigate to per-prompt drill-down
                                drilldownPromptID = entry.id
                            } label: {
                                HStack(spacing: 12) {
                                    Text("\(index + 1)")
                                        .font(.body.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                        .frame(width: 24, alignment: .trailing)

                                    Text(entry.title)
                                        .lineLimit(1)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .foregroundStyle(.primary)

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

                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.vertical, 2)
                            }
                            .buttonStyle(.plain)
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
                            Text("")
                                .frame(width: 12)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .listStyle(.inset)
            }
        }
        .sheet(isPresented: Binding(
            get: { drilldownPromptID != nil },
            set: { if !$0 { drilldownPromptID = nil } }
        )) {
            if let pid = drilldownPromptID,
               let prompt = allPrompts.first(where: { $0.id == pid }) {
                NavigationStack {
                    PromptStatsView(prompt: prompt)
                        .navigationTitle(prompt.title.isEmpty ? "Untitled" : prompt.title)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { drilldownPromptID = nil }
                            }
                        }
                }
                .frame(width: 360, height: 420)
            }
        }
    }

    // MARK: - Daily Chart

    private var dailyChart: some View {
        let data = service.dailyEvents(days: dateRange)
        let stride: Calendar.Component = dateRange == 7 ? .day : (dateRange == 30 ? .day : .weekOfYear)
        let strideCount = dateRange == 7 ? 1 : (dateRange == 30 ? 5 : 14)

        return Chart(data, id: \.date) { entry in
            AreaMark(
                x: .value("Date", entry.date),
                y: .value("Events", entry.count)
            )
            .foregroundStyle(Color.accentColor.opacity(0.10))
            .interpolationMethod(.catmullRom)

            LineMark(
                x: .value("Date", entry.date),
                y: .value("Events", entry.count)
            )
            .foregroundStyle(Color.accentColor)
            .interpolationMethod(.catmullRom)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: stride, count: strideCount)) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.month().day())
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .frame(height: 120)
        .padding(.horizontal)
        .padding(.bottom, 4)
    }

    // MARK: - Token Summary

    private var tokenSummary: some View {
        let totals = service.tokenTotals(days: dateRange)
        let prefix = totals.hasPartialData ? "~" : ""
        return HStack(spacing: 16) {
            Label {
                Text("\(prefix)\(formatTokenCount(totals.input)) input")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: "arrow.up.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Label {
                Text("\(prefix)\(formatTokenCount(totals.output)) output")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: "arrow.down.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.bottom, 6)
    }

    // MARK: - Upgrade Prompt

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

// MARK: - Preview

#Preview {
    AnalyticsView()
        .modelContainer(
            for: [Prompt.self, Tag.self, TemplateVariable.self, Attachment.self, PromptRun.self, CopyEvent.self],
            inMemory: true
        )
}
