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

    // MARK: - suggest() Heuristic Paths

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

    // MARK: - Untested Heuristic Path: Task without Role

    @Test func suggest_whenTaskWithoutRole_suggestsRole() {
        let canvasCategories: [ConsolidatedBlockCategory] = [.task]

        let suggestion = BlockSuggestionEngine.suggest(canvasCategories: canvasCategories)

        #expect(suggestion != nil)
        #expect(suggestion?.suggestedCategories.contains(.role) == true)
        #expect(suggestion?.message.contains("Role") == true)
    }

    // MARK: - Untested Heuristic Path: 3+ categories without constraints

    @Test func suggest_whenThreeCategoriesNoConstraints_suggestsConstraints() {
        let canvasCategories: [ConsolidatedBlockCategory] = [.role, .task, .format]

        let suggestion = BlockSuggestionEngine.suggest(canvasCategories: canvasCategories)

        #expect(suggestion != nil)
        #expect(suggestion?.suggestedCategories.contains(.constraints) == true)
        #expect(suggestion?.message.contains("Constraints") == true)
    }

    // MARK: - Untested Heuristic Path: Default fallback suggests examples

    @Test func suggest_whenMissingExamples_suggestsExamples() {
        // Need a combination that doesn't match earlier rules but has no examples.
        // .constraints alone: not empty, no role+task combo, no task-without-role,
        // count < 3, so falls through to default.
        let canvasCategories: [ConsolidatedBlockCategory] = [.constraints]

        let suggestion = BlockSuggestionEngine.suggest(canvasCategories: canvasCategories)

        #expect(suggestion != nil)
        #expect(suggestion?.suggestedCategories.contains(.examples) == true)
        #expect(suggestion?.message.contains("Examples") == true)
    }

    // MARK: - Edge Case: Context only (no role, no task)

    @Test func suggest_whenContextOnly_suggestsExamplesOrRole() {
        let canvasCategories: [ConsolidatedBlockCategory] = [.context]

        let suggestion = BlockSuggestionEngine.suggest(canvasCategories: canvasCategories)

        // Context alone doesn't match role-only, task-without-role, or 3+ categories.
        // Falls to default: suggest examples if missing.
        #expect(suggestion != nil)
        #expect(suggestion?.suggestedCategories.contains(.examples) == true)
    }

    // MARK: - Edge Case: All 7 categories present

    @Test func suggest_whenAllSevenCategoriesPresent_returnsNil() {
        let canvasCategories: [ConsolidatedBlockCategory] = [
            .role, .context, .task, .format, .constraints, .examples, .meta
        ]

        let suggestion = BlockSuggestionEngine.suggest(canvasCategories: canvasCategories)

        #expect(suggestion == nil)
    }

    // MARK: - Edge Case: Duplicate categories on canvas

    @Test func suggest_withDuplicateCategories_handlesGracefully() {
        // Duplicates should be deduplicated by the Set internally
        let canvasCategories: [ConsolidatedBlockCategory] = [.role, .role, .task, .task]

        let suggestion = BlockSuggestionEngine.suggest(canvasCategories: canvasCategories)

        // role+task -> suggests format/constraints
        #expect(suggestion?.suggestedCategories.contains(.format) == true ||
                suggestion?.suggestedCategories.contains(.constraints) == true)
    }

    // MARK: - shouldShowTokenWarning

    @Test func shouldShowTokenWarning_belowThreshold_returnsNil() {
        let suggestion = BlockSuggestionEngine.shouldShowTokenWarning(tokenCount: 500)

        #expect(suggestion == nil)
    }

    @Test func shouldShowTokenWarning_aboveThreshold_returnsWarning() {
        let suggestion = BlockSuggestionEngine.shouldShowTokenWarning(tokenCount: 5000)

        #expect(suggestion != nil)
        #expect(suggestion?.message.contains("5000") == true)
        #expect(suggestion?.message.contains("long") == true)
    }

    @Test func shouldShowTokenWarning_atExactThreshold_returnsNil() {
        // Threshold is > 3000, so exactly 3000 should return nil
        let suggestion = BlockSuggestionEngine.shouldShowTokenWarning(tokenCount: 3000)

        #expect(suggestion == nil)
    }

    @Test func shouldShowTokenWarning_justAboveThreshold_returnsWarning() {
        let suggestion = BlockSuggestionEngine.shouldShowTokenWarning(tokenCount: 3001)

        #expect(suggestion != nil)
        #expect(suggestion?.message.contains("3001") == true)
    }

    @Test func shouldShowTokenWarning_atZero_returnsNil() {
        let suggestion = BlockSuggestionEngine.shouldShowTokenWarning(tokenCount: 0)

        #expect(suggestion == nil)
    }
}
