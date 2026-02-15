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
        let container = try ModelContainer(
            for: Prompt.self, TemplateVariable.self, Pault.Tag.self, Attachment.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
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
}
