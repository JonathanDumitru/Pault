//
//  AnalyticsService.swift
//  Pault
//
//  Queries copy events and run history for usage analytics.
//

import Foundation
import SwiftData
import os

private let analyticsLogger = Logger(subsystem: "com.pault.app", category: "analytics")

@MainActor
final class AnalyticsService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Event Recording

    /// Records a lifecycle event for a prompt. All event types route through here.
    func recordEvent(_ type: UsageEventType, for promptID: UUID) {
        let event = CopyEvent(promptID: promptID, type: type)
        modelContext.insert(event)
    }

    /// Thin wrapper — preserves existing call sites unchanged.
    func recordCopy(for promptID: UUID) {
        recordEvent(.copy, for: promptID)
    }

    // MARK: - Copy Stats

    func copyCount(for promptID: UUID, since: Date? = nil) -> Int {
        let descriptor: FetchDescriptor<CopyEvent>
        if let since {
            descriptor = FetchDescriptor<CopyEvent>(
                predicate: #Predicate { $0.promptID == promptID && $0.timestamp >= since }
            )
        } else {
            descriptor = FetchDescriptor<CopyEvent>(
                predicate: #Predicate { $0.promptID == promptID }
            )
        }
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    func lastCopied(promptID: UUID) -> Date? {
        var descriptor = FetchDescriptor<CopyEvent>(
            predicate: #Predicate { $0.promptID == promptID },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor))?.first?.timestamp
    }

    // MARK: - Run Stats

    func runCount(for prompt: Prompt) -> Int {
        let id = prompt.id
        // Optional relationship traversal in #Predicate is unreliable in SwiftData;
        // filter in memory after fetching only the relationship id field.
        let descriptor = FetchDescriptor<PromptRun>()
        guard let runs = try? modelContext.fetch(descriptor) else { return 0 }
        return runs.filter { $0.prompt?.id == id }.count
    }

    /// Returns run counts for all prompts in one fetch (O(1) table scans).
    func allRunCounts() -> [UUID: Int] {
        let descriptor = FetchDescriptor<PromptRun>()
        guard let runs = try? modelContext.fetch(descriptor) else { return [:] }
        var counts: [UUID: Int] = [:]
        for run in runs {
            guard let id = run.prompt?.id else { continue }
            counts[id, default: 0] += 1
        }
        return counts
    }

    // MARK: - Aggregate

    func topPromptIDsByUsage(limit: Int = 20) -> [UUID] {
        guard let events = try? modelContext.fetch(FetchDescriptor<CopyEvent>()) else { return [] }
        var counts: [UUID: Int] = [:]
        for event in events {
            counts[event.promptID, default: 0] += 1
        }
        return counts.sorted { $0.value > $1.value }
            .prefix(limit)
            .map(\.key)
    }

    func dailyCopies(for promptID: UUID, days: Int = 30) -> [(date: Date, count: Int)] {
        let now = Date()
        let since = Calendar.current.date(byAdding: .day, value: -days, to: now) ?? now
        let descriptor = FetchDescriptor<CopyEvent>(
            predicate: #Predicate { $0.promptID == promptID && $0.timestamp >= since },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        guard let events = try? modelContext.fetch(descriptor) else { return [] }

        let calendar = Calendar.current
        var grouped: [Date: Int] = [:]
        for event in events {
            let day = calendar.startOfDay(for: event.timestamp)
            grouped[day, default: 0] += 1
        }

        var result: [(date: Date, count: Int)] = []
        for daysBack in (0..<days).reversed() {
            let day = calendar.startOfDay(
                for: calendar.date(byAdding: .day, value: -daysBack, to: now) ?? now
            )
            result.append((date: day, count: grouped[day] ?? 0))
        }
        return result
    }

    // MARK: - All-Event Daily Aggregation

    /// Aggregates ALL event types by day for the last N days.
    /// Returns an array sorted by date ascending, with zero-count days filled in.
    func dailyEvents(days: Int = 30) -> [(date: Date, count: Int)] {
        let now = Date()
        guard let since = Calendar.current.date(byAdding: .day, value: -days, to: now) else {
            return []
        }
        let descriptor = FetchDescriptor<CopyEvent>(
            predicate: #Predicate { $0.timestamp >= since },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        guard let events = try? modelContext.fetch(descriptor) else { return [] }

        let calendar = Calendar.current
        var grouped: [Date: Int] = [:]
        for event in events {
            let day = calendar.startOfDay(for: event.timestamp)
            grouped[day, default: 0] += 1
        }

        var result: [(date: Date, count: Int)] = []
        for daysBack in (0..<days).reversed() {
            let day = calendar.startOfDay(
                for: calendar.date(byAdding: .day, value: -daysBack, to: now) ?? now
            )
            result.append((date: day, count: grouped[day] ?? 0))
        }
        return result
    }

    // MARK: - Token Aggregation

    /// Aggregates input and output tokens from PromptRun records over the last N days.
    func tokenTotals(days: Int = 30) -> (input: Int, output: Int, hasPartialData: Bool) {
        let now = Date()
        guard let since = Calendar.current.date(byAdding: .day, value: -days, to: now) else {
            return (0, 0, false)
        }
        let descriptor = FetchDescriptor<PromptRun>(
            predicate: #Predicate { $0.createdAt >= since }
        )
        guard let runs = try? modelContext.fetch(descriptor) else {
            return (0, 0, false)
        }

        var totalInput = 0
        var totalOutput = 0
        var hasPartialData = false

        for run in runs {
            if let input = run.inputTokens {
                totalInput += input
            } else {
                hasPartialData = true
            }
            if let output = run.outputTokens {
                totalOutput += output
            } else {
                hasPartialData = true
            }
        }

        return (totalInput, totalOutput, hasPartialData)
    }

    // MARK: - Model Filter (used by Smart Collections)

    /// Returns the set of promptIDs that have been run with the specified model.
    func promptIDsRunWith(model: String) -> Set<UUID> {
        let descriptor = FetchDescriptor<PromptRun>(
            predicate: #Predicate { $0.model == model }
        )
        guard let runs = try? modelContext.fetch(descriptor) else { return [] }
        return Set(runs.compactMap { $0.prompt?.id })
    }
}
