//
//  TemplateVariableTests.swift
//  PaultTests
//

import Testing
import SwiftData
@testable import Pault

@MainActor
struct TemplateVariableTests {

    @Test func templateVariableInitializesWithDefaults() {
        let variable = TemplateVariable(name: "company")

        #expect(variable.name == "company")
        #expect(variable.defaultValue == "")
        #expect(variable.sortOrder == 0)
    }

    @Test func templateVariableInitializesWithCustomValues() {
        let variable = TemplateVariable(name: "role", defaultValue: "Engineer", sortOrder: 2)

        #expect(variable.name == "role")
        #expect(variable.defaultValue == "Engineer")
        #expect(variable.sortOrder == 2)
    }

    @Test func promptStartsWithNoTemplateVariables() {
        let prompt = Prompt(title: "Test", content: "Hello")

        #expect(prompt.templateVariables.isEmpty)
    }

    @Test func cascadeDeleteRemovesVariables() async throws {
        let container = try ModelContainer(for: Prompt.self, TemplateVariable.self, Tag.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)

        let prompt = Prompt(title: "Test", content: "{{name}}")
        context.insert(prompt)

        TemplateEngine.syncVariables(for: prompt, in: context)
        try context.save()

        #expect(prompt.templateVariables.count == 1)

        // Delete the prompt — cascade should remove the variable
        context.delete(prompt)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<TemplateVariable>())
        #expect(remaining.isEmpty)
    }
}
