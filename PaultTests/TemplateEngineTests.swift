//
//  TemplateEngineTests.swift
//  PaultTests
//

import Testing
import SwiftData
@testable import Pault

struct TemplateEngineTests {

    // MARK: - extractVariableNames

    @Test func extractNoVariables() {
        let names = TemplateEngine.extractVariableNames(from: "Hello, world!")
        #expect(names.isEmpty)
    }

    @Test func extractSingleVariable() {
        let names = TemplateEngine.extractVariableNames(from: "Hi {{name}}, welcome!")
        #expect(names == ["name"])
    }

    @Test func extractMultipleVariables() {
        let names = TemplateEngine.extractVariableNames(from: "{{greeting}} {{name}} from {{company}}")
        #expect(names == ["greeting", "name", "company"])
    }

    @Test func extractDeduplicates() {
        let names = TemplateEngine.extractVariableNames(from: "{{name}} and {{name}} again")
        #expect(names == ["name"])
    }

    @Test func extractPreservesFirstAppearanceOrder() {
        let names = TemplateEngine.extractVariableNames(from: "{{b}} then {{a}} then {{b}}")
        #expect(names == ["b", "a"])
    }

    @Test func extractIgnoresEmptyBraces() {
        let names = TemplateEngine.extractVariableNames(from: "Hello {{}} world")
        #expect(names.isEmpty)
    }

    @Test func extractIgnoresWhitespaceOnlyBraces() {
        let names = TemplateEngine.extractVariableNames(from: "Hello {{   }} world")
        #expect(names.isEmpty)
    }

    @Test func extractToleratesSpacesAroundVariableName() {
        let names = TemplateEngine.extractVariableNames(from: "{{ name }} and {{ company }}")
        #expect(names == ["name", "company"])
    }

    @Test func resolveToleratesSpacesAroundVariableName() {
        let vars = [
            TemplateVariable(name: "name", defaultValue: "Alice"),
        ]
        let result = TemplateEngine.resolve(
            content: "Hi {{ name }}, welcome!",
            variables: vars
        )
        #expect(result == "Hi Alice, welcome!")
    }

    @Test func extractHandlesUnderscores() {
        let names = TemplateEngine.extractVariableNames(from: "{{first_name}} {{last_name}}")
        #expect(names == ["first_name", "last_name"])
    }

    // MARK: - resolve

    @Test func resolveWithNoVariables() {
        let result = TemplateEngine.resolve(content: "Hello world", variables: [])
        #expect(result == "Hello world")
    }

    @Test func resolveSubstitutesFilledValues() {
        let vars = [
            TemplateVariable(name: "name", defaultValue: "Alice"),
            TemplateVariable(name: "company", defaultValue: "Acme"),
        ]
        let result = TemplateEngine.resolve(
            content: "Hi {{name}} from {{company}}!",
            variables: vars
        )
        #expect(result == "Hi Alice from Acme!")
    }

    @Test func resolveLeavesEmptyVariablesAsMarkers() {
        let vars = [
            TemplateVariable(name: "name", defaultValue: "Alice"),
            TemplateVariable(name: "company", defaultValue: ""),
        ]
        let result = TemplateEngine.resolve(
            content: "Hi {{name}} from {{company}}",
            variables: vars
        )
        #expect(result == "Hi Alice from {{company}}")
    }

    @Test func resolveHandlesDuplicateMarkers() {
        let vars = [
            TemplateVariable(name: "name", defaultValue: "Bob"),
        ]
        let result = TemplateEngine.resolve(
            content: "{{name}} met {{name}}",
            variables: vars
        )
        #expect(result == "Bob met Bob")
    }

    // MARK: - syncVariables

    @Test func syncCreatesNewVariables() async throws {
        let container = try ModelContainer(for: Prompt.self, TemplateVariable.self, Tag.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)

        let prompt = Prompt(title: "Test", content: "Hello {{name}} from {{company}}")
        context.insert(prompt)

        TemplateEngine.syncVariables(for: prompt, in: context)

        #expect(prompt.templateVariables.count == 2)
        let sorted = prompt.templateVariables.sorted { $0.sortOrder < $1.sortOrder }
        #expect(sorted[0].name == "name")
        #expect(sorted[1].name == "company")
        #expect(sorted[0].sortOrder == 0)
        #expect(sorted[1].sortOrder == 1)
    }

    @Test func syncRemovesStaleVariables() async throws {
        let container = try ModelContainer(for: Prompt.self, TemplateVariable.self, Tag.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)

        let prompt = Prompt(title: "Test", content: "{{name}} and {{company}}")
        context.insert(prompt)
        TemplateEngine.syncVariables(for: prompt, in: context)
        #expect(prompt.templateVariables.count == 2)

        // Remove {{company}} from content
        prompt.content = "Hello {{name}}"
        TemplateEngine.syncVariables(for: prompt, in: context)

        #expect(prompt.templateVariables.count == 1)
        #expect(prompt.templateVariables.first?.name == "name")
    }

    @Test func syncPreservesExistingValues() async throws {
        let container = try ModelContainer(for: Prompt.self, TemplateVariable.self, Tag.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)

        let prompt = Prompt(title: "Test", content: "{{name}} from {{company}}")
        context.insert(prompt)
        TemplateEngine.syncVariables(for: prompt, in: context)

        // Fill in a value
        prompt.templateVariables.first(where: { $0.name == "name" })?.defaultValue = "Alice"

        // Re-sync (e.g. user added another variable)
        prompt.content = "{{name}} from {{company}} in {{city}}"
        TemplateEngine.syncVariables(for: prompt, in: context)

        #expect(prompt.templateVariables.count == 3)
        let nameVar = prompt.templateVariables.first(where: { $0.name == "name" })
        #expect(nameVar?.defaultValue == "Alice")
    }

    @Test func syncHandlesNoVariables() async throws {
        let container = try ModelContainer(for: Prompt.self, TemplateVariable.self, Tag.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)

        let prompt = Prompt(title: "Test", content: "No variables here")
        context.insert(prompt)
        TemplateEngine.syncVariables(for: prompt, in: context)

        #expect(prompt.templateVariables.isEmpty)
    }
}
