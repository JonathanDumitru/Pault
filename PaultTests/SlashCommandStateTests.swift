//
//  SlashCommandStateTests.swift
//  PaultTests
//
//  Tests for SlashCommandState: filtering, visibility, selection, and recent blocks.
//

import Testing
@testable import Pault

struct SlashCommandStateTests {

    // MARK: - filterBlocks (existing)

    @Test func filterBlocks_returnsAllWhenQueryEmpty() {
        let blocks = [
            Block(title: "Expert", category: .rolePerspective, valueType: .string, snippet: ""),
            Block(title: "Task", category: .instructions, valueType: .string, snippet: "")
        ]

        let results = SlashCommandState.filterBlocks(blocks, query: "")

        #expect(results.count == 2)
    }

    @Test func filterBlocks_fuzzyMatchesByTitle() {
        let blocks = [
            Block(title: "Expert Advisor", category: .rolePerspective, valueType: .string, snippet: ""),
            Block(title: "Task Definition", category: .instructions, valueType: .string, snippet: "")
        ]

        let results = SlashCommandState.filterBlocks(blocks, query: "exp")

        #expect(results.count == 1)
        #expect(results.first?.title == "Expert Advisor")
    }

    @Test func filterBlocks_matchesByCategory() {
        let blocks = [
            Block(title: "Expert", category: .rolePerspective, valueType: .string, snippet: ""),
            Block(title: "Task", category: .instructions, valueType: .string, snippet: "")
        ]

        let results = SlashCommandState.filterBlocks(blocks, query: "role")

        #expect(results.count == 1)
        #expect(results.first?.title == "Expert")
    }

    @Test func filterBlocks_caseInsensitiveMatch() {
        let blocks = [
            Block(title: "Expert Advisor", category: .rolePerspective, valueType: .string, snippet: ""),
            Block(title: "Task Definition", category: .instructions, valueType: .string, snippet: "")
        ]

        let results = SlashCommandState.filterBlocks(blocks, query: "EXPERT")

        #expect(results.count == 1)
        #expect(results.first?.title == "Expert Advisor")
    }

    // MARK: - filterBlocks (new gap coverage)

    @Test func filterBlocks_noMatchingResults_returnsEmpty() {
        let blocks = [
            Block(title: "Expert", category: .rolePerspective, valueType: .string, snippet: ""),
            Block(title: "Task", category: .instructions, valueType: .string, snippet: "")
        ]

        let results = SlashCommandState.filterBlocks(blocks, query: "zzzznonexistent")

        #expect(results.isEmpty)
    }

    @Test func filterBlocks_specialCharactersInQuery_handlesGracefully() {
        let blocks = [
            Block(title: "Expert Advisor", category: .rolePerspective, valueType: .string, snippet: ""),
            Block(title: "Task Definition", category: .instructions, valueType: .string, snippet: "")
        ]

        // Special characters should not crash -- just return no matches
        let results1 = SlashCommandState.filterBlocks(blocks, query: "{{")
        #expect(results1.isEmpty)

        let results2 = SlashCommandState.filterBlocks(blocks, query: "!@#$%")
        #expect(results2.isEmpty)

        let results3 = SlashCommandState.filterBlocks(blocks, query: "\\")
        #expect(results3.isEmpty)
    }

    @Test func filterBlocks_emptyBlockList_returnsEmpty() {
        let results = SlashCommandState.filterBlocks([], query: "anything")
        #expect(results.isEmpty)
    }

    // MARK: - show/hide (existing)

    @Test @MainActor func show_setsVisibleAndResetsState() {
        let state = SlashCommandState()
        state.query = "old query"
        state.selectedIndex = 5

        state.show()

        #expect(state.isVisible == true)
        #expect(state.query == "")
        #expect(state.selectedIndex == 0)
    }

    @Test @MainActor func hide_clearsVisibilityAndQuery() {
        let state = SlashCommandState()
        state.isVisible = true
        state.query = "some query"

        state.hide()

        #expect(state.isVisible == false)
        #expect(state.query == "")
    }

    // MARK: - show() gap coverage

    @Test @MainActor func show_resetsSelectedIndexWhenCalledWhileVisible() {
        let state = SlashCommandState()

        // First show
        state.show()
        state.selectedIndex = 3
        state.query = "partial"

        // Call show() again while already visible
        state.show()

        #expect(state.isVisible == true)
        #expect(state.selectedIndex == 0)
        #expect(state.query == "")
    }

    // MARK: - moveSelection (existing)

    @Test @MainActor func moveSelection_incrementsWithinBounds() {
        let state = SlashCommandState()
        state.selectedIndex = 2

        state.moveSelection(by: 1, maxIndex: 10)

        #expect(state.selectedIndex == 3)
    }

    @Test @MainActor func moveSelection_decrementsWithinBounds() {
        let state = SlashCommandState()
        state.selectedIndex = 5

        state.moveSelection(by: -1, maxIndex: 10)

        #expect(state.selectedIndex == 4)
    }

    @Test @MainActor func moveSelection_clampsToZero() {
        let state = SlashCommandState()
        state.selectedIndex = 0

        state.moveSelection(by: -5, maxIndex: 10)

        #expect(state.selectedIndex == 0)
    }

    @Test @MainActor func moveSelection_clampsToMaxIndexMinusOne() {
        let state = SlashCommandState()
        state.selectedIndex = 8

        state.moveSelection(by: 5, maxIndex: 10)

        #expect(state.selectedIndex == 9)
    }

    // MARK: - moveSelection gap coverage

    @Test @MainActor func moveSelection_withMaxIndexZero_staysAtNegativeOne() {
        let state = SlashCommandState()
        state.selectedIndex = 0

        // maxIndex 0 means min(0-1, newIndex) = min(-1, 1) = -1, then max(0, -1) = 0
        state.moveSelection(by: 1, maxIndex: 0)

        // max(0, min(-1, 1)) = max(0, -1) = 0
        #expect(state.selectedIndex == 0)
    }

    @Test @MainActor func moveSelection_withMaxIndexOne_clampsToZero() {
        let state = SlashCommandState()
        state.selectedIndex = 0

        // maxIndex 1: min(0, 1) = 0, max(0, 0) = 0
        state.moveSelection(by: 1, maxIndex: 1)

        #expect(state.selectedIndex == 0)
    }

    @Test @MainActor func moveSelection_withMaxIndexOne_downFromZero_staysAtZero() {
        let state = SlashCommandState()
        state.selectedIndex = 0

        state.moveSelection(by: -1, maxIndex: 1)

        #expect(state.selectedIndex == 0)
    }

    // MARK: - recordUsage (existing)

    @Test @MainActor func recordUsage_addsBlockToRecent() {
        let state = SlashCommandState()
        let block = Block(title: "Test Block", category: .instructions, valueType: .string, snippet: "")

        state.recordUsage(block: block)

        #expect(state.recentBlockTitles.contains("Test Block"))
    }

    @Test @MainActor func recordUsage_movesExistingToFront() {
        let state = SlashCommandState()
        let block1 = Block(title: "First", category: .instructions, valueType: .string, snippet: "")
        let block2 = Block(title: "Second", category: .instructions, valueType: .string, snippet: "")

        state.recordUsage(block: block1)
        state.recordUsage(block: block2)
        state.recordUsage(block: block1)  // Use first again

        #expect(state.recentBlockTitles.first == "First")
    }

    @Test @MainActor func recordUsage_limitsToFiveRecent() {
        let state = SlashCommandState()

        for i in 1...7 {
            let block = Block(title: "Block \(i)", category: .instructions, valueType: .string, snippet: "")
            state.recordUsage(block: block)
        }

        #expect(state.recentBlockTitles.count == 5)
        #expect(state.recentBlockTitles.first == "Block 7")
    }

    // MARK: - recordUsage gap coverage

    @Test @MainActor func recordUsage_deduplication_sameBlockTwice() {
        let state = SlashCommandState()
        let block = Block(title: "Same Block", category: .instructions, valueType: .string, snippet: "")

        state.recordUsage(block: block)
        state.recordUsage(block: block)

        // Should only appear once (deduplication removes first, re-inserts at front)
        let matchCount = state.recentBlockTitles.filter { $0 == "Same Block" }.count
        #expect(matchCount == 1)
    }
}
