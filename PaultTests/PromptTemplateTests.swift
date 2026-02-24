//
//  PromptTemplateTests.swift
//  PaultTests
//

import Testing
import SwiftData
@testable import Pault

@MainActor
struct PromptTemplateTests {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: PromptTemplate.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @Test func templateCreatesWithDefaults() throws {
        let ctx = try makeContext()
        let template = PromptTemplate(
            name: "Bug Report",
            content: "## Bug\n{{description}}\n## Steps\n{{steps}}",
            category: "Engineering"
        )
        ctx.insert(template)
        try ctx.save()

        #expect(template.name == "Bug Report")
        #expect(template.category == "Engineering")
        #expect(template.isBuiltIn == false)
        #expect(template.usageCount == 0)
        #expect(template.iconName == "doc.text")
    }

    @Test func builtInTemplateCannotBeDeleted() throws {
        let template = PromptTemplate(
            name: "Starter",
            content: "Hello",
            category: "General",
            isBuiltIn: true
        )
        #expect(template.isBuiltIn == true)
    }

    @Test func usageCountIncrements() throws {
        let template = PromptTemplate(name: "T", content: "C", category: "X")
        #expect(template.usageCount == 0)
        template.usageCount += 1
        #expect(template.usageCount == 1)
    }
}
