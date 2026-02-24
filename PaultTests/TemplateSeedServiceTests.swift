//
//  TemplateSeedServiceTests.swift
//  PaultTests
//

import Testing
import SwiftData
@testable import Pault

@MainActor
struct TemplateSeedServiceTests {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: PromptTemplate.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @Test func seedCreatesBuiltInTemplates() throws {
        let ctx = try makeContext()
        TemplateSeedService.seed(into: ctx)

        let descriptor = FetchDescriptor<PromptTemplate>()
        let templates = try ctx.fetch(descriptor)

        #expect(templates.count >= 6)
        #expect(templates.allSatisfy(\.isBuiltIn))
        #expect(templates.contains(where: { $0.category == "Writing" }))
        #expect(templates.contains(where: { $0.category == "Engineering" }))
    }

    @Test func seedIsIdempotent() throws {
        let ctx = try makeContext()
        TemplateSeedService.seed(into: ctx)
        let countAfterFirst = try ctx.fetch(FetchDescriptor<PromptTemplate>()).count

        TemplateSeedService.seed(into: ctx)
        let countAfterSecond = try ctx.fetch(FetchDescriptor<PromptTemplate>()).count

        #expect(countAfterFirst == countAfterSecond)
    }

    @Test func seedTemplatesContainVariables() throws {
        let ctx = try makeContext()
        TemplateSeedService.seed(into: ctx)

        let templates = try ctx.fetch(FetchDescriptor<PromptTemplate>())
        let withVars = templates.filter { $0.content.contains("{{") }
        #expect(withVars.count >= 3, "At least 3 bundled templates should use {{variables}}")
    }
}
