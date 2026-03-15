//
//  TestHelpers.swift
//  PaultTests
//
//  Shared test infrastructure: single source of truth for
//  in-memory ModelContainer creation listing all 7 model types.
//

import SwiftData
@testable import Pault

enum TestHelpers {
    @MainActor
    static func makeTestModelContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Prompt.self, TemplateVariable.self, Pault.Tag.self,
                 Attachment.self, CopyEvent.self, PromptRun.self, PromptVersion.self,
                 SmartCollection.self, PromptTemplate.self, CustomBlock.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @MainActor
    static func makeTestModelContext() throws -> ModelContext {
        ModelContext(try makeTestModelContainer())
    }
}
