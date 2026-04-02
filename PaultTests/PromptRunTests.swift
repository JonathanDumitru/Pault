import Testing
import SwiftData
import AppKit
@testable import Pault

@MainActor
struct PromptRunTests {

    private func makeContext() throws -> ModelContext {
        try TestHelpers.makeTestModelContext()
    }

    @Test func promptRunPersistsWithRequiredFields() throws {
        let context = try makeContext()
        let run = PromptRun(
            promptTitle: "Test prompt",
            resolvedInput: "Hello world",
            output: "Response text",
            model: "claude-opus-4-6",
            provider: "claude",
            latencyMs: 1200
        )
        context.insert(run)
        try context.save()

        let descriptor = FetchDescriptor<PromptRun>()
        let results = try context.fetch(descriptor)
        #expect(results.count == 1)
        #expect(results[0].promptTitle == "Test prompt")
        #expect(results[0].variantLabel == nil)
        #expect(results[0].userRating == nil)
    }

    @Test func promptRunVariantLabelStoredCorrectly() throws {
        let context = try makeContext()
        let runA = PromptRun(
            promptTitle: "T", resolvedInput: "i", output: "o",
            model: "gpt-4o", provider: "openai", latencyMs: 500,
            variantLabel: "A"
        )
        let runB = PromptRun(
            promptTitle: "T", resolvedInput: "i", output: "o",
            model: "gpt-4o", provider: "openai", latencyMs: 600,
            variantLabel: "B"
        )
        context.insert(runA)
        context.insert(runB)
        try context.save()

        let descriptor = FetchDescriptor<PromptRun>(sortBy: [SortDescriptor(\.latencyMs)])
        let results = try context.fetch(descriptor)
        #expect(results[0].variantLabel == "A")
        #expect(results[1].variantLabel == "B")
    }

    // 1. test_promptRunPersistsWithTokenMetadata -- Verifies PromptRun stores inputTokens and outputTokens from proxy metadata (R5.2)
    @Test func promptRunPersistsWithTokenMetadata() throws {
        Issue.record("Wave 0 stub -- implement in Plan 04-03")
    }

    // 2. test_promptRunStarRating_persistsOnReload -- Verifies userRating persists across model context save/load (R5.2)
    @Test func promptRunStarRating_persistsOnReload() throws {
        Issue.record("Wave 0 stub -- implement in Plan 04-03")
    }
}
