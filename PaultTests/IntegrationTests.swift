//
//  IntegrationTests.swift
//  PaultTests
//

import Testing
import SwiftData
import AppKit
@testable import Pault

@MainActor
struct IntegrationTests {

    private func makeContext() throws -> ModelContext {
        try TestHelpers.makeTestModelContext()
    }

    // MARK: - Template Variables -> Copy

    @Test func templateVariablesResolveOnCopy() throws {
        let context = try makeContext()
        let service = PromptService(modelContext: context)

        let prompt = service.createPrompt(
            title: "Outreach",
            content: "Hi {{name}}, I work at {{company}}. Let's connect!"
        )

        TemplateEngine.syncVariables(for: prompt, in: context)
        #expect(prompt.templateVariables.count == 2)

        prompt.templateVariables.first(where: { $0.name == "name" })?.defaultValue = "Alice"
        prompt.templateVariables.first(where: { $0.name == "company" })?.defaultValue = "Acme"

        service.copyToClipboard(prompt)

        let text = NSPasteboard.general.string(forType: .string)
        #expect(text == "Hi Alice, I work at Acme. Let's connect!")
    }

    @Test func templateVariablesPartialFillLeavesMarkers() throws {
        let context = try makeContext()
        let service = PromptService(modelContext: context)

        let prompt = service.createPrompt(
            title: "Test",
            content: "{{greeting}} {{name}}"
        )
        TemplateEngine.syncVariables(for: prompt, in: context)

        prompt.templateVariables.first(where: { $0.name == "greeting" })?.defaultValue = "Hello"

        service.copyToClipboard(prompt)

        let text = NSPasteboard.general.string(forType: .string)
        #expect(text == "Hello {{name}}")
    }

    @Test func independentVariablesResolveOnCopy() throws {
        let context = try makeContext()
        let service = PromptService(modelContext: context)

        let prompt = service.createPrompt(
            title: "Meeting",
            content: "{{name}} met {{name}} at {{place}}"
        )
        TemplateEngine.syncVariables(for: prompt, in: context)

        #expect(prompt.templateVariables.count == 3)

        let sorted = prompt.templateVariables.sorted { $0.sortOrder < $1.sortOrder }
        sorted[0].defaultValue = "Alice"   // first {{name}}
        sorted[1].defaultValue = "Bob"     // second {{name}}
        sorted[2].defaultValue = "the park" // {{place}}

        service.copyToClipboard(prompt)

        let text = NSPasteboard.general.string(forType: .string)
        #expect(text == "Alice met Bob at the park")
    }

    // MARK: - Cascade Deletes

    @Test func deletePromptCascadesTemplateVariables() throws {
        let context = try makeContext()
        let service = PromptService(modelContext: context)

        let prompt = service.createPrompt(title: "Test", content: "{{var1}} {{var2}}")
        TemplateEngine.syncVariables(for: prompt, in: context)
        try context.save()

        #expect(prompt.templateVariables.count == 2)

        service.deletePrompt(prompt)

        let varDescriptor = FetchDescriptor<TemplateVariable>()
        let vars = try context.fetch(varDescriptor)
        #expect(vars.isEmpty)
    }

    // MARK: - Tag Filtering

    @Test func tagFilterFindTaggedPrompt() throws {
        let context = try makeContext()
        let service = PromptService(modelContext: context)

        let tag = service.createTag(name: "Urgent")
        let p1 = service.createPrompt(title: "Tagged", content: "")
        let p2 = service.createPrompt(title: "Untagged", content: "")
        service.addTag(tag, to: p1)

        let result = service.filterPrompts([p1, p2], tagFilter: tag)
        #expect(result.count == 1)
        #expect(result.first?.title == "Tagged")
    }

    // MARK: - Variable Sync Lifecycle

    @Test func variableSyncAddAndRemove() throws {
        let context = try makeContext()

        let prompt = Prompt(title: "Test", content: "{{name}} from {{company}}")
        context.insert(prompt)

        TemplateEngine.syncVariables(for: prompt, in: context)
        #expect(prompt.templateVariables.count == 2)

        prompt.templateVariables.first(where: { $0.name == "name" })?.defaultValue = "Bob"

        prompt.content = "Hello {{name}}!"
        TemplateEngine.syncVariables(for: prompt, in: context)

        #expect(prompt.templateVariables.count == 1)
        #expect(prompt.templateVariables.first?.name == "name")
        #expect(prompt.templateVariables.first?.defaultValue == "Bob")

        prompt.content = "Hello {{name}} at {{role}}!"
        TemplateEngine.syncVariables(for: prompt, in: context)

        #expect(prompt.templateVariables.count == 2)
        let roleVar = prompt.templateVariables.first(where: { $0.name == "role" })
        #expect(roleVar != nil)
        #expect(roleVar?.defaultValue == "")
    }

    // MARK: - Block Composition -> Compiled Preview Pipeline

    @Test func blockComposition_compilesToPreview() throws {
        let context = try makeContext()
        let prompt = Prompt(title: "Integration", content: "")
        context.insert(prompt)

        let model = PromptStudioModel(prompt: prompt)

        // Add blocks to canvas
        let roleBlock = Block(title: "Role", category: .rolePerspective, valueType: .string, snippet: "ROLE: {{role}}")
        let taskBlock = Block(title: "Task", category: .instructions, valueType: .string, snippet: "TASK: {{task}}")
        model.addToCanvas(roleBlock)
        model.addToCanvas(taskBlock)

        // Fill placeholders
        let b1 = model.canvasBlocks[0]
        let b2 = model.canvasBlocks[1]
        model.setBlockInput(blockID: b1.id, placeholder: "role", value: "engineer")
        model.setBlockInput(blockID: b2.id, placeholder: "task", value: "review code")

        // Compile and verify full pipeline
        model.compileNow()

        // Verify compiled output contains resolved values
        #expect(model.compiledTemplate.contains("ROLE: engineer"))
        #expect(model.compiledTemplate.contains("TASK: review code"))

        // Verify raw template preserves placeholder syntax
        #expect(model.rawTemplate.contains("{{role}}"))
        #expect(model.rawTemplate.contains("{{task}}"))

        // Verify saved to prompt
        #expect(prompt.content.contains("ROLE: engineer"))
        #expect(prompt.content.contains("TASK: review code"))

        // Verify block composition snapshot was persisted
        #expect(prompt.blockComposition != nil)
        #expect(prompt.blockComposition?.blocks.count == 2)

        // Verify sync state
        #expect(prompt.blockSyncState == .synced)
    }
}
