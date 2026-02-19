//
//  AnalyticsServiceTests.swift
//  PaultTests
//

import Testing
import Foundation
import SwiftData
@testable import Pault

@MainActor
struct AnalyticsServiceTests {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([Prompt.self, Tag.self, TemplateVariable.self,
                             Attachment.self, PromptRun.self, CopyEvent.self])
        let container = try ModelContainer(for: schema, configurations: [
            ModelConfiguration(isStoredInMemoryOnly: true)
        ])
        return ModelContext(container)
    }

    @Test func copyCount_returnsCorrectCount() throws {
        let ctx = try makeContext()
        let id = UUID()
        for _ in 0..<5 {
            ctx.insert(CopyEvent(promptID: id))
        }
        try ctx.save()

        let service = AnalyticsService(modelContext: ctx)
        #expect(service.copyCount(for: id) == 5)
    }

    @Test func copyCount_excludesOtherPrompts() throws {
        let ctx = try makeContext()
        let id1 = UUID()
        let id2 = UUID()
        ctx.insert(CopyEvent(promptID: id1))
        ctx.insert(CopyEvent(promptID: id1))
        ctx.insert(CopyEvent(promptID: id2))
        try ctx.save()

        let service = AnalyticsService(modelContext: ctx)
        #expect(service.copyCount(for: id1) == 2)
        #expect(service.copyCount(for: id2) == 1)
    }

    @Test func topPromptIDsByUsage_sortsByTotalUsage() throws {
        let ctx = try makeContext()
        let id1 = UUID()
        let id2 = UUID()
        for _ in 0..<3 { ctx.insert(CopyEvent(promptID: id1)) }
        for _ in 0..<5 { ctx.insert(CopyEvent(promptID: id2)) }
        try ctx.save()

        let service = AnalyticsService(modelContext: ctx)
        let top = service.topPromptIDsByUsage(limit: 10)
        #expect(top.first == id2)
        #expect(top.last == id1)
    }

    @Test func lastCopied_returnsMaxTimestamp() throws {
        let ctx = try makeContext()
        let id = UUID()
        let early = CopyEvent(promptID: id)
        early.timestamp = Date(timeIntervalSinceNow: -3600)
        let recent = CopyEvent(promptID: id)
        // recent.timestamp stays as Date()
        ctx.insert(early)
        ctx.insert(recent)
        try ctx.save()

        let service = AnalyticsService(modelContext: ctx)
        let last = service.lastCopied(promptID: id)
        let unwrapped = try #require(last)
        #expect(abs(unwrapped.timeIntervalSince(recent.timestamp)) < 1)
    }
}
