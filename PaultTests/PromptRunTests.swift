import Testing
import SwiftData
import AppKit
@testable import Pault

@MainActor
struct PromptRunTests {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Prompt.self, TemplateVariable.self, Pault.Tag.self, Attachment.self,
            PromptRun.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
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
}
