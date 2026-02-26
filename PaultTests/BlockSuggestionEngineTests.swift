//
//  BlockSuggestionEngineTests.swift
//  PaultTests
//
//  Tests for BlockSuggestionEngine which analyzes canvas blocks
//  and suggests what type of block to add next.
//

import Testing
@testable import Pault

struct BlockSuggestionEngineTests {

    @Test func suggest_whenEmpty_suggestsRoleOrTemplate() {
        let canvasCategories: [ConsolidatedBlockCategory] = []

        let suggestion = BlockSuggestionEngine.suggest(canvasCategories: canvasCategories)

        #expect(suggestion != nil)
        #expect(suggestion?.message.contains("Role") == true || suggestion?.message.contains("Template") == true)
    }

    @Test func suggest_whenRoleOnly_suggestsContextOrTask() {
        let canvasCategories: [ConsolidatedBlockCategory] = [.role]

        let suggestion = BlockSuggestionEngine.suggest(canvasCategories: canvasCategories)

        #expect(suggestion != nil)
        #expect(suggestion?.suggestedCategories.contains(.context) == true ||
                suggestion?.suggestedCategories.contains(.task) == true)
    }

    @Test func suggest_whenRoleAndTask_suggestsFormat() {
        let canvasCategories: [ConsolidatedBlockCategory] = [.role, .task]

        let suggestion = BlockSuggestionEngine.suggest(canvasCategories: canvasCategories)

        #expect(suggestion?.suggestedCategories.contains(.format) == true ||
                suggestion?.suggestedCategories.contains(.constraints) == true)
    }

    @Test func suggest_whenComplete_returnsNil() {
        let canvasCategories: [ConsolidatedBlockCategory] = [.role, .context, .task, .format, .constraints]

        let suggestion = BlockSuggestionEngine.suggest(canvasCategories: canvasCategories)

        #expect(suggestion == nil)
    }
}
