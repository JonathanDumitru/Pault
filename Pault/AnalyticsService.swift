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
}
