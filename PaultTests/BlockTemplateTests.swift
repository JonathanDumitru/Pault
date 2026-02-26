//
//  BlockTemplateTests.swift
//  PaultTests
//
//  Tests for BlockTemplate model with built-in templates.
//

import Testing
@testable import Pault

struct BlockTemplateTests {

    @Test func builtInTemplates_includesCodeReview() {
        let templates = BlockTemplate.builtIn

        let codeReview = templates.first { $0.id == "code-review" }
        #expect(codeReview != nil)
        #expect(codeReview?.blocks.count == 5)
    }

    @Test func estimatedTokens_calculatesFromBlocks() {
        let template = BlockTemplate(
            id: "test",
            name: "Test",
            description: "Test template",
            blocks: [
                .init(title: "A", categoryRaw: "Role & Perspective", valueTypeRaw: "string", snippet: "Hello world")
            ]
        )

        // ~2 tokens for "Hello world"
        #expect(template.estimatedTokens > 0)
    }
}
