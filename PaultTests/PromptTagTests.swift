//
//  PromptTagTests.swift
//  PaultTests
//

import Testing
import SwiftData
@testable import Pault

struct PromptTagTests {

    @Test func promptCanHaveMultipleTags() async throws {
        let prompt = Prompt(title: "Test", content: "Content")
        let tag1 = Tag(name: "work")
        let tag2 = Tag(name: "email")

        prompt.tags = [tag1, tag2]

        #expect(prompt.tags?.count == 2)
        #expect(prompt.tags?.contains(where: { $0.name == "work" }) == true)
        #expect(prompt.tags?.contains(where: { $0.name == "email" }) == true)
    }

    @Test func promptStartsWithNoTags() async throws {
        let prompt = Prompt(title: "Test", content: "Content")

        #expect(prompt.tags == nil || prompt.tags?.isEmpty == true)
    }
}
