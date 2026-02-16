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
            TemplateVariable(name: "name", defaultValue: "Alice", sortOrder: 0),
            TemplateVariable(name: "company", defaultValue: "Acme", sortOrder: 1),
        ]
        let result = TemplateEngine.resolve(
            content: "Hi {{name}} from {{company}}!",
            variables: vars
        )
        #expect(result == "Hi Alice from Acme!")
    }

    @Test func resolveLeavesEmptyVariablesAsMarkers() {
        let vars = [
            TemplateVariable(name: "name", defaultValue: "Alice", sortOrder: 0),
            TemplateVariable(name: "company", defaultValue: "", sortOrder: 1),
        ]
        let result = TemplateEngine.resolve(
            content: "Hi {{name}} from {{company}}",
            variables: vars
        )
        #expect(result == "Hi Alice from {{company}}")
    }

    @Test func resolveHandlesDuplicateMarkersIndependently() {
        let vars = [
            TemplateVariable(name: "name", defaultValue: "Alice", sortOrder: 0, occurrenceIndex: 0),
            TemplateVariable(name: "name", defaultValue: "Bob", sortOrder: 1, occurrenceIndex: 1),
        ]
        let result = TemplateEngine.resolve(
            content: "{{name}} met {{name}}",
            variables: vars
        )
        #expect(result == "Alice met Bob")
    }

    @Test func resolveHandlesDuplicatesSameValue() {
        let vars = [
            TemplateVariable(name: "name", defaultValue: "Bob", sortOrder: 0, occurrenceIndex: 0),
            TemplateVariable(name: "name", defaultValue: "Bob", sortOrder: 1, occurrenceIndex: 1),
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

    // MARK: - splitContent

    @Test func splitContentEmptyString() {
        let segments = TemplateEngine.splitContent("")
        #expect(segments.isEmpty)
    }

    @Test func splitContentNoVariables() {
        let segments = TemplateEngine.splitContent("Hello world")
        #expect(segments == [.text("Hello world")])
    }

    @Test func splitContentSingleVariable() {
        let segments = TemplateEngine.splitContent("Hi {{name}}!")
        #expect(segments == [.text("Hi "), .variable(name: "name"), .text("!")])
    }

    @Test func splitContentMultipleVariables() {
        let segments = TemplateEngine.splitContent("{{greeting}} {{name}} from {{company}}")
        #expect(segments == [
            .variable(name: "greeting"),
            .text(" "),
            .variable(name: "name"),
            .text(" from "),
            .variable(name: "company"),
        ])
    }

    @Test func splitContentConsecutiveVariables() {
        let segments = TemplateEngine.splitContent("{{a}}{{b}}")
        #expect(segments == [.variable(name: "a"), .variable(name: "b")])
    }

    @Test func splitContentVariableAtStart() {
        let segments = TemplateEngine.splitContent("{{name}} is here")
        #expect(segments == [.variable(name: "name"), .text(" is here")])
    }

    @Test func splitContentVariableAtEnd() {
        let segments = TemplateEngine.splitContent("Hello {{name}}")
        #expect(segments == [.text("Hello "), .variable(name: "name")])
    }

    @Test func splitContentWhitespaceInBraces() {
        let segments = TemplateEngine.splitContent("Hi {{ name }}!")
        #expect(segments == [.text("Hi "), .variable(name: "name"), .text("!")])
    }

    @Test func splitContentEmptyBracesPassthrough() {
        let segments = TemplateEngine.splitContent("Hello {{}} world")
        #expect(segments == [.text("Hello {{}} world")])
    }

    @Test func splitContentPreservesDuplicates() {
        let segments = TemplateEngine.splitContent("{{name}} and {{name}}")
        #expect(segments == [
            .variable(name: "name"),
            .text(" and "),
            .variable(name: "name"),
        ])
    }

    // MARK: - extractAllOccurrences

    @Test func extractAllOccurrencesEmpty() {
        let result = TemplateEngine.extractAllOccurrences(from: "Hello world")
        #expect(result.isEmpty)
    }

    @Test func extractAllOccurrencesBasic() {
        let result = TemplateEngine.extractAllOccurrences(from: "{{a}} and {{b}}")
        #expect(result.count == 2)
        #expect(result[0].name == "a")
        #expect(result[0].occurrenceIndex == 0)
        #expect(result[1].name == "b")
        #expect(result[1].occurrenceIndex == 0)
    }

    @Test func extractAllOccurrencesDuplicates() {
        let result = TemplateEngine.extractAllOccurrences(from: "{{a}} {{b}} {{a}}")
        #expect(result.count == 3)
        #expect(result[0] == (name: "a", occurrenceIndex: 0))
        #expect(result[1] == (name: "b", occurrenceIndex: 0))
        #expect(result[2] == (name: "a", occurrenceIndex: 1))
    }

    @Test func extractAllOccurrencesTripleDuplicate() {
        let result = TemplateEngine.extractAllOccurrences(from: "{{x}} {{x}} {{x}}")
        #expect(result.count == 3)
        #expect(result[0].occurrenceIndex == 0)
        #expect(result[1].occurrenceIndex == 1)
        #expect(result[2].occurrenceIndex == 2)
    }

    // MARK: - syncVariables (additional)

    @Test func syncHandlesNoVariables() async throws {
        let container = try ModelContainer(for: Prompt.self, TemplateVariable.self, Tag.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)

        let prompt = Prompt(title: "Test", content: "No variables here")
        context.insert(prompt)
        TemplateEngine.syncVariables(for: prompt, in: context)

        #expect(prompt.templateVariables.isEmpty)
    }

    @Test func syncCreatesPerOccurrenceVariables() async throws {
        let container = try ModelContainer(for: Prompt.self, TemplateVariable.self, Tag.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)

        let prompt = Prompt(title: "Test", content: "{{name}} met {{name}}")
        context.insert(prompt)
        TemplateEngine.syncVariables(for: prompt, in: context)

        #expect(prompt.templateVariables.count == 2)
        let sorted = prompt.templateVariables.sorted { $0.sortOrder < $1.sortOrder }
        #expect(sorted[0].name == "name")
        #expect(sorted[0].occurrenceIndex == 0)
        #expect(sorted[0].sortOrder == 0)
        #expect(sorted[1].name == "name")
        #expect(sorted[1].occurrenceIndex == 1)
        #expect(sorted[1].sortOrder == 1)
    }

    @Test func syncPreservesPerOccurrenceValues() async throws {
        let container = try ModelContainer(for: Prompt.self, TemplateVariable.self, Tag.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)

        let prompt = Prompt(title: "Test", content: "{{name}} met {{name}}")
        context.insert(prompt)
        TemplateEngine.syncVariables(for: prompt, in: context)

        // Fill in independent values
        let sorted = prompt.templateVariables.sorted { $0.sortOrder < $1.sortOrder }
        sorted[0].defaultValue = "Alice"
        sorted[1].defaultValue = "Bob"

        // Re-sync — values should be preserved
        TemplateEngine.syncVariables(for: prompt, in: context)

        let reSorted = prompt.templateVariables.sorted { $0.sortOrder < $1.sortOrder }
        #expect(reSorted.count == 2)
        #expect(reSorted[0].defaultValue == "Alice")
        #expect(reSorted[1].defaultValue == "Bob")
    }

    @Test func syncHandlesOccurrenceCountChange() async throws {
        let container = try ModelContainer(for: Prompt.self, TemplateVariable.self, Tag.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)

        let prompt = Prompt(title: "Test", content: "{{name}} met {{name}}")
        context.insert(prompt)
        TemplateEngine.syncVariables(for: prompt, in: context)
        #expect(prompt.templateVariables.count == 2)

        // Add a third occurrence
        prompt.content = "{{name}} met {{name}} and {{name}}"
        TemplateEngine.syncVariables(for: prompt, in: context)

        #expect(prompt.templateVariables.count == 3)
        let sorted = prompt.templateVariables.sorted { $0.sortOrder < $1.sortOrder }
        #expect(sorted[2].name == "name")
        #expect(sorted[2].occurrenceIndex == 2)
        #expect(sorted[2].defaultValue == "")  // New occurrence starts empty
    }

    @Test func syncRemovesDuplicateOccurrenceWhenReduced() async throws {
        let container = try ModelContainer(for: Prompt.self, TemplateVariable.self, Tag.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)

        let prompt = Prompt(title: "Test", content: "{{name}} met {{name}}")
        context.insert(prompt)
        TemplateEngine.syncVariables(for: prompt, in: context)

        let sorted = prompt.templateVariables.sorted { $0.sortOrder < $1.sortOrder }
        sorted[0].defaultValue = "Alice"
        sorted[1].defaultValue = "Bob"

        // Reduce to single occurrence
        prompt.content = "Hello {{name}}"
        TemplateEngine.syncVariables(for: prompt, in: context)

        #expect(prompt.templateVariables.count == 1)
        #expect(prompt.templateVariables.first?.name == "name")
        #expect(prompt.templateVariables.first?.occurrenceIndex == 0)
        #expect(prompt.templateVariables.first?.defaultValue == "Alice")  // First occurrence preserved
    }

    @Test func resolveWithThreeIndependentOccurrences() {
        let vars = [
            TemplateVariable(name: "item", defaultValue: "apples", sortOrder: 0, occurrenceIndex: 0),
            TemplateVariable(name: "item", defaultValue: "bananas", sortOrder: 1, occurrenceIndex: 1),
            TemplateVariable(name: "item", defaultValue: "cherries", sortOrder: 2, occurrenceIndex: 2),
        ]
        let result = TemplateEngine.resolve(
            content: "I like {{item}}, {{item}}, and {{item}}",
            variables: vars
        )
        #expect(result == "I like apples, bananas, and cherries")
    }

    @Test func resolveMixedUniqueAndDuplicateVariables() {
        let vars = [
            TemplateVariable(name: "greeting", defaultValue: "Hi", sortOrder: 0),
            TemplateVariable(name: "name", defaultValue: "Alice", sortOrder: 1, occurrenceIndex: 0),
            TemplateVariable(name: "name", defaultValue: "Bob", sortOrder: 2, occurrenceIndex: 1),
        ]
        let result = TemplateEngine.resolve(
            content: "{{greeting}} {{name}} and {{name}}",
            variables: vars
        )
        #expect(result == "Hi Alice and Bob")
    }
}
